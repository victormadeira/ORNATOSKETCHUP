# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# engineering/validator.rb — Validador de módulos
#
# Realiza validações em 3 níveis:
#   :blocking — impede exportação/produção
#   :warning — alerta que pode ser ignorado
#   :suggestion — sugestão de melhoria
#
# Validações:
#   - Dimensões dentro dos limites
#   - Peças com material atribuído
#   - Fita de borda completa
#   - Operações com ferramenta válida
#   - Conflitos de agregados
#   - Vãos vazios (sem agregado)

module Ornato
  module Engineering
    class Validator
      # Resultado individual de validação.
      ValidationIssue = Struct.new(
        :level,        # Symbol: :blocking, :warning, :suggestion
        :category,     # Symbol: :dimension, :material, :edging, :operation, :aggregate, :opening
        :message,      # String: descrição do problema
        :target_id,    # String: ornato_id do alvo
        :target_name,  # String: nome do alvo
        keyword_init: true
      )

      # Resultado completo de validação.
      ValidationResult = Struct.new(
        :valid,          # Boolean: sem erros blocking
        :issues,         # Array<ValidationIssue>
        :blocking_count, # Integer
        :warning_count,  # Integer
        :suggestion_count, # Integer
        :duration_ms,    # Float
        keyword_init: true
      ) do
        def valid?; valid; end
        def blocking; issues.select { |i| i.level == :blocking }; end
        def warnings; issues.select { |i| i.level == :warning }; end
        def suggestions; issues.select { |i| i.level == :suggestion }; end
      end

      # Valida um módulo completo.
      # @param mod [Domain::ModEntity]
      # @param machine_profile [Domain::MachineProfile, nil]
      # @return [ValidationResult]
      def validate(mod, machine_profile: nil)
        start_time = Time.now
        issues = []

        validate_dimensions(mod, issues)
        validate_materials(mod, issues)
        validate_edging(mod, issues)
        validate_operations(mod, issues)
        validate_aggregates(mod, issues)
        validate_openings(mod, issues)
        validate_machine_compatibility(mod, machine_profile, issues) if machine_profile

        blocking = issues.count { |i| i.level == :blocking }
        warnings = issues.count { |i| i.level == :warning }
        suggestions = issues.count { |i| i.level == :suggestion }
        duration = ((Time.now - start_time) * 1000).round(1)

        result = ValidationResult.new(
          valid: blocking == 0,
          issues: issues,
          blocking_count: blocking,
          warning_count: warnings,
          suggestion_count: suggestions,
          duration_ms: duration
        )

        Core.events.emit(:validation_completed, module_id: mod.ornato_id, result: result)
        result
      end

      private

      def validate_dimensions(mod, issues)
        if mod.width_mm <= 0 || mod.height_mm <= 0 || mod.depth_mm <= 0
          issues << ValidationIssue.new(
            level: :blocking, category: :dimension,
            message: "Dimensões do módulo devem ser > 0",
            target_id: mod.ornato_id, target_name: mod.name
          )
        end

        if mod.width_mm > 4000
          issues << ValidationIssue.new(
            level: :warning, category: :dimension,
            message: "Largura #{mod.width_mm}mm acima do recomendado (4000mm)",
            target_id: mod.ornato_id, target_name: mod.name
          )
        end

        if mod.height_mm > 2700
          issues << ValidationIssue.new(
            level: :warning, category: :dimension,
            message: "Altura #{mod.height_mm}mm acima do recomendado (2700mm)",
            target_id: mod.ornato_id, target_name: mod.name
          )
        end

        # Verificar peças que excedem chapa padrão
        mod.parts.each do |part|
          sheet_w = Core::Config::SHEET[:width_mm]
          sheet_h = Core::Config::SHEET[:height_mm]
          refilo = Core::Config::SHEET[:refilo_mm]
          max_w = sheet_w - 2 * refilo
          max_h = sheet_h - 2 * refilo

          if part.cut_length > max_w && part.cut_length > max_h
            issues << ValidationIssue.new(
              level: :blocking, category: :dimension,
              message: "Peça #{part.name} (#{part.cut_length}mm) excede chapa (#{max_w}x#{max_h}mm)",
              target_id: part.ornato_id, target_name: part.name
            )
          end
        end
      end

      def validate_materials(mod, issues)
        mod.parts.each do |part|
          unless part.material_id
            issues << ValidationIssue.new(
              level: :warning, category: :material,
              message: "Peça #{part.name} sem material atribuído",
              target_id: part.ornato_id, target_name: part.name
            )
          end
        end

        unless mod.body_material_id
          issues << ValidationIssue.new(
            level: :warning, category: :material,
            message: "Módulo sem material de corpo definido",
            target_id: mod.ornato_id, target_name: mod.name
          )
        end
      end

      def validate_edging(mod, issues)
        mod.parts.each do |part|
          next if part.code == 'CM_FUN' || part.code == 'CM_FUN_GAV_VER'
          next if part.code =~ /^CM_LAT_GAV|CM_TRA_GAV/

          # Peças visíveis devem ter fita na frente
          visible_codes = %w[CM_LAT_ESQ CM_LAT_DIR CM_BAS CM_REG CM_PRA CM_PRA_FIX CM_PRA_REG CM_DIV]
          if visible_codes.include?(part.code) && !part.edge_front
            issues << ValidationIssue.new(
              level: :suggestion, category: :edging,
              message: "Peça #{part.name} sem fita de borda frontal",
              target_id: part.ornato_id, target_name: part.name
            )
          end

          # Portas e frentes de gaveta: idealmente 4 lados
          if part.code =~ /^CM_POR|CM_FRE_GAV/
            sides = [part.edge_front, part.edge_back, part.edge_left, part.edge_right].compact.length
            if sides < 4
              issues << ValidationIssue.new(
                level: :warning, category: :edging,
                message: "#{part.name}: #{sides}/4 lados com fita (recomendado: 4)",
                target_id: part.ornato_id, target_name: part.name
              )
            end
          end
        end
      end

      def validate_operations(mod, issues)
        mod.operations.each do |op|
          if op.depth_mm <= 0
            issues << ValidationIssue.new(
              level: :blocking, category: :operation,
              message: "Operação #{op.name}: profundidade deve ser > 0",
              target_id: op.ornato_id, target_name: op.name
            )
          end

          if op.tool_diameter_mm <= 0
            issues << ValidationIssue.new(
              level: :blocking, category: :operation,
              message: "Operação #{op.name}: diâmetro da ferramenta deve ser > 0",
              target_id: op.ornato_id, target_name: op.name
            )
          end

          # Verificar se a profundidade não excede a espessura da peça
          part = mod.find_part(op.part_id)
          if part && op.depth_mm > part.thickness_real
            issues << ValidationIssue.new(
              level: :blocking, category: :operation,
              message: "Operação #{op.name}: profundidade #{op.depth_mm}mm excede espessura da peça #{part.thickness_real}mm",
              target_id: op.ornato_id, target_name: op.name
            )
          end
        end
      end

      def validate_aggregates(mod, issues)
        aggregate_engine = Components::AggregateEngine.new

        mod.all_aggregates.each do |agg|
          opening = mod.find_opening(agg.opening_id)
          next unless opening

          result = aggregate_engine.validate_placement(agg.aggregate_type, opening)
          result[:errors].each do |err|
            issues << ValidationIssue.new(
              level: :blocking, category: :aggregate,
              message: err,
              target_id: agg.ornato_id, target_name: agg.name
            )
          end
          result[:warnings].each do |warn|
            issues << ValidationIssue.new(
              level: :warning, category: :aggregate,
              message: warn,
              target_id: agg.ornato_id, target_name: agg.name
            )
          end
        end
      end

      def validate_openings(mod, issues)
        leaves = collect_leaves(mod)
        empty_leaves = leaves.select { |o| o.aggregates.empty? }

        empty_leaves.each do |opening|
          issues << ValidationIssue.new(
            level: :suggestion, category: :opening,
            message: "Vão '#{opening.name}' está vazio (sem agregado)",
            target_id: opening.ornato_id, target_name: opening.name
          )
        end
      end

      def validate_machine_compatibility(mod, machine, issues)
        # Verificar dimensões das peças contra área de trabalho
        mod.parts.each do |part|
          dim_errors = machine.validate_part_dimensions(part)
          dim_errors.each do |err|
            issues << ValidationIssue.new(
              level: :blocking, category: :dimension,
              message: err,
              target_id: part.ornato_id, target_name: part.name
            )
          end
        end

        # Verificar operações contra ferramentas disponíveis
        mod.operations.each do |op|
          op_errors = machine.validate_operation(op)
          op_errors.each do |err|
            issues << ValidationIssue.new(
              level: :warning, category: :operation,
              message: err,
              target_id: op.ornato_id, target_name: op.name
            )
          end
        end
      end

      def collect_leaves(mod)
        leaves = []
        mod.openings.each { |o| walk_leaves(o, leaves) }
        leaves
      end

      def walk_leaves(opening, leaves)
        if opening.leaf?
          leaves << opening
        else
          opening.sub_openings.each { |sub| walk_leaves(sub, leaves) }
        end
      end
    end
  end
end
