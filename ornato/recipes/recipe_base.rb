# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# recipes/recipe_base.rb — Classe base para receitas de módulos
#
# Uma receita define a "fórmula" de construção de um tipo de módulo.
# Usa o padrão Template Method: subclasses implementam os passos,
# RecipeBase orquestra a sequência.
#
# Sequência de execução:
#   1. validate_parameters  — valida parâmetros de entrada
#   2. build_structural_parts — gera peças estruturais (laterais, base, topo)
#   3. build_openings — cria árvore de vãos
#   4. apply_default_aggregates — agrega componentes padrão
#   5. apply_engineering_rules — furação, fita de borda, usinagem
#   6. finalize — metadata, hash, validação final

module Ornato
  module Recipes
    class RecipeBase
      # ── Metadata ──────────────────────────────────────────────────
      # Subclasses DEVEM sobrescrever estes métodos.

      def module_type
        raise NotImplementedError, "#{self.class}#module_type"
      end

      def name
        raise NotImplementedError, "#{self.class}#name"
      end

      def description
        ''
      end

      def version
        1
      end

      # ── Parâmetros ────────────────────────────────────────────────
      # Retorna hash de parâmetros com defaults e constraints.
      # Formato: { param_name: { default: value, min: n, max: n, type: Class } }

      def parameters
        {
          width_mm:  { default: 600.0,  min: 200.0, max: 6000.0, type: Float },
          height_mm: { default: 720.0,  min: 100.0, max: 3000.0, type: Float },
          depth_mm:  { default: 560.0,  min: 150.0, max: 1200.0, type: Float },
          body_thickness: { default: 18, min: 9, max: 25, type: Integer },
          body_material_id: { default: nil, type: String },
          front_material_id: { default: nil, type: String }
        }
      end

      # Parâmetros opcionais extras que a receita aceita.
      # Subclasses podem sobrescrever para adicionar.
      def extra_parameters
        {}
      end

      # Todos os parâmetros combinados.
      def all_parameters
        parameters.merge(extra_parameters)
      end

      # ── Execução ──────────────────────────────────────────────────
      # Método principal: cria e configura um módulo a partir de parâmetros.
      #
      # @param params [Hash] parâmetros do módulo
      # @param ruleset [Ruleset] regras de construção
      # @return [Domain::ModEntity] módulo completo
      def execute(params, ruleset)
        resolved = resolve_parameters(params)
        validate_parameters(resolved)

        mod = create_module(resolved, ruleset)
        build_structural_parts(mod, resolved, ruleset)
        build_openings(mod, resolved, ruleset)
        apply_default_aggregates(mod, resolved, ruleset)
        apply_engineering_rules(mod, resolved, ruleset)
        finalize(mod, resolved, ruleset)

        Core.events.emit(:module_created, module_id: mod.ornato_id)
        Core.logger.info("Receita #{name} executada: #{mod.name} (#{mod.ornato_id})")

        mod
      end

      protected

      # ── Template Methods ──────────────────────────────────────────
      # Subclasses implementam estes métodos conforme o tipo de módulo.

      # Cria o ModEntity base.
      def create_module(params, ruleset)
        mod = Domain::ModEntity.new(
          name: params[:name] || "#{name} #{params[:width_mm].to_i}",
          module_type: module_type,
          width_mm: params[:width_mm],
          height_mm: params[:height_mm],
          depth_mm: params[:depth_mm]
        )
        mod.body_thickness = params[:body_thickness]
        mod.body_material_id = params[:body_material_id]
        mod.front_material_id = params[:front_material_id]
        mod.ruleset_id = ruleset.ornato_id
        mod.ruleset_version = ruleset.version

        # Regras de construção do ruleset
        mod.assembly_type = ruleset.rule(:construction, :assembly_type, fallback: :brasil)
        mod.back_type = ruleset.rule(:construction, :back_type, fallback: :encaixado)
        mod.back_thickness = ruleset.rule(:construction, :back_thickness, fallback: 3)
        mod.base_type = ruleset.rule(:construction, :base_type, fallback: :rodape)
        mod.base_height_mm = ruleset.rule(:construction, :base_height_mm, fallback: 100.0)

        mod
      end

      # Gera peças estruturais (laterais, base, topo).
      # Subclasses DEVEM implementar.
      def build_structural_parts(mod, params, ruleset)
        raise NotImplementedError, "#{self.class}#build_structural_parts"
      end

      # Cria árvore de vãos internos.
      # Subclasses DEVEM implementar.
      def build_openings(mod, params, ruleset)
        raise NotImplementedError, "#{self.class}#build_openings"
      end

      # Aplica agregados padrão (portas, prateleiras, etc.).
      # Default: não faz nada. Subclasses sobrescrevem se necessário.
      def apply_default_aggregates(mod, params, ruleset)
        # Noop — subclasses adicionam agregados conforme necessidade
      end

      # Aplica regras de engenharia (furação, fita de borda, usinagem).
      # Default: aplica Sistema 32 e fita padrão.
      def apply_engineering_rules(mod, params, ruleset)
        apply_system_32(mod, ruleset)
        apply_default_edging(mod, ruleset)
        apply_back_groove(mod, params, ruleset) if mod.back_type == :encaixado
      end

      # Finalização: valida, calcula hash, atualiza timestamps.
      def finalize(mod, params, ruleset)
        mod.updated_at = Time.now.iso8601
        mod
      end

      # ── Helpers para subclasses ───────────────────────────────────

      # Cria uma peça estrutural padrão.
      # @return [Domain::Part]
      def make_structural_part(mod, code:, name:, length:, width:, thickness:, grain: :length)
        part = Domain::Part.new(
          parent_id: mod.ornato_id,
          code: code,
          name: name,
          part_type: :structural,
          length_mm: length,
          width_mm: width,
          thickness_nominal: thickness,
          material_id: mod.body_material_id,
          grain_direction: grain
        )
        mod.parts << part
        part
      end

      # Cria vão raiz do módulo.
      def make_root_opening(mod)
        real_body = Core::Config.real_thickness(mod.body_thickness)
        y_base = mod.base_type == :rodape ? mod.base_height_mm + real_body : real_body
        z_base = mod.back_type == :encaixado ? Core::Config.real_thickness(mod.back_thickness) : 0.0

        opening = Domain::Opening.new(
          parent_id: mod.ornato_id,
          x_mm: real_body,
          y_mm: y_base,
          z_mm: z_base,
          width_mm: mod.internal_width_mm,
          height_mm: mod.internal_height_mm,
          depth_mm: mod.internal_depth_mm
        )
        mod.openings << opening
        opening
      end

      # Cria peça lateral (esquerda ou direita).
      def make_lateral(mod, side, params, ruleset)
        code = side == :left ? 'CM_LAT_ESQ' : 'CM_LAT_DIR'
        nome = side == :left ? 'Lateral Esquerda' : 'Lateral Direita'

        case mod.assembly_type
        when :brasil
          # Brasil: laterais ENTRE base e topo
          height = mod.height_mm - (2 * Core::Config.real_thickness(mod.body_thickness))
          height -= mod.base_height_mm if mod.base_type == :rodape
        when :europa
          # Europa: base e topo ENTRE laterais
          height = mod.height_mm
          height -= mod.base_height_mm if mod.base_type == :rodape
        else
          height = mod.height_mm
        end

        make_structural_part(mod,
          code: code, name: nome,
          length: height, width: mod.depth_mm,
          thickness: mod.body_thickness, grain: :length
        )
      end

      # Cria peça base ou topo.
      def make_horizontal(mod, position, params, ruleset)
        code = position == :base ? 'CM_BAS' : 'CM_REG'
        nome = position == :base ? 'Base' : 'Topo'

        case mod.assembly_type
        when :brasil
          # Brasil: base/topo = largura total
          width = mod.width_mm
        when :europa
          # Europa: base/topo ENTRE laterais
          width = mod.width_mm - (2 * Core::Config.real_thickness(mod.body_thickness))
        else
          width = mod.width_mm
        end

        make_structural_part(mod,
          code: code, name: nome,
          length: width, width: mod.depth_mm,
          thickness: mod.body_thickness, grain: :width
        )
      end

      # Cria peça de fundo.
      def make_back_panel(mod)
        make_structural_part(mod,
          code: 'CM_FUN', name: 'Fundo',
          length: mod.width_mm - (2 * Core::Config.real_thickness(mod.body_thickness)) + (mod.back_type == :encaixado ? 16.0 : 0.0),
          width: mod.height_mm - (2 * Core::Config.real_thickness(mod.body_thickness)) + (mod.back_type == :encaixado ? 16.0 : 0.0),
          thickness: mod.back_thickness, grain: :none
        )
      end

      # Aplica furação Sistema 32 nas laterais.
      def apply_system_32(mod, ruleset)
        s32 = Core::Config::SYSTEM_32
        laterais = mod.parts.select { |p| p.code == 'CM_LAT_ESQ' || p.code == 'CM_LAT_DIR' }

        laterais.each do |lateral|
          n_furos = ((lateral.length_mm - 2 * s32[:start_mm]) / s32[:pitch_mm]).floor + 1
          next unless n_furos > 0

          # Linha frontal
          n_furos.times do |i|
            y = s32[:start_mm] + (i * s32[:pitch_mm])
            op = Domain::Operation.new(
              parent_part_id: lateral.ornato_id,
              operation_type: :furacao,
              face: :left,
              x_mm: s32[:setback_mm],
              y_mm: y,
              depth_mm: s32[:hole_depth_mm],
              tool_diameter_mm: s32[:hole_dia_mm],
              tool_id: 'f_5mm',
              description: "S32 L#{i + 1}F"
            )
            lateral.operation_ids << op.ornato_id
            mod.operations << op
          end

          # Linha traseira
          n_furos.times do |i|
            y = s32[:start_mm] + (i * s32[:pitch_mm])
            op = Domain::Operation.new(
              parent_part_id: lateral.ornato_id,
              operation_type: :furacao,
              face: :left,
              x_mm: lateral.width_mm - s32[:setback_mm],
              y_mm: y,
              depth_mm: s32[:hole_depth_mm],
              tool_diameter_mm: s32[:hole_dia_mm],
              tool_id: 'f_5mm',
              description: "S32 L#{i + 1}T"
            )
            lateral.operation_ids << op.ornato_id
            mod.operations << op
          end
        end
      end

      # Aplica fita de borda padrão nas peças estruturais.
      def apply_default_edging(mod, ruleset)
        edge_thickness = ruleset.rule(:edging, :default_thickness, fallback: 1.0)
        edge_width = ruleset.rule(:edging, :default_width, fallback: 22.0)

        mod.parts.each do |part|
          next unless part.part_type == :structural
          next if part.code == 'CM_FUN'  # fundo não leva fita

          # Borda frontal (:top = comprimento) sempre leva fita
          unless part.edges[:top]&.applied
            part.edges[:top] = Domain::EdgeSpec.standard(
              nil,
              width: edge_width,
              thickness: edge_thickness,
              finish: 'BRANCO_TX'
            )
          end
        end
      end

      # Cria canal para fundo encaixado.
      def apply_back_groove(mod, params, ruleset)
        groove_depth = ruleset.rule(:construction, :back_groove_depth, fallback: 8.0)
        groove_width = Core::Config.real_thickness(mod.back_thickness) + 0.5 # folga

        # Canal nas laterais
        laterais = mod.parts.select { |p| p.code == 'CM_LAT_ESQ' || p.code == 'CM_LAT_DIR' }
        laterais.each do |lateral|
          op = Domain::Operation.new(
            parent_part_id: lateral.ornato_id,
            operation_type: :canal,
            face: :back,
            x_mm: lateral.width_mm - groove_depth,
            y_mm: 0.0,
            depth_mm: groove_depth,
            tool_diameter_mm: groove_width,
            tool_id: 'f_3mm_canal',
            length_mm: lateral.length_mm,
            description: "Canal Fundo #{lateral.name}"
          )
          lateral.operation_ids << op.ornato_id
          mod.operations << op
        end

        # Canal na base
        base = mod.parts.find { |p| p.code == 'CM_BAS' }
        if base
          op = Domain::Operation.new(
            parent_part_id: base.ornato_id,
            operation_type: :canal,
            face: :back,
            x_mm: base.width_mm - groove_depth,
            y_mm: 0.0,
            depth_mm: groove_depth,
            tool_diameter_mm: groove_width,
            tool_id: 'f_3mm_canal',
            length_mm: base.length_mm,
            description: 'Canal Fundo Base'
          )
          base.operation_ids << op.ornato_id
          mod.operations << op
        end
      end

      private

      # Resolve parâmetros: aplica defaults e converte tipos.
      def resolve_parameters(params)
        resolved = {}
        all_parameters.each do |key, spec|
          value = params.key?(key) ? params[key] : spec[:default]
          resolved[key] = coerce_value(value, spec[:type]) unless value.nil?
        end
        # Manter params extras não definidos nos parâmetros
        params.each { |k, v| resolved[k] = v unless resolved.key?(k) }
        resolved
      end

      # Valida parâmetros contra constraints.
      def validate_parameters(params)
        all_parameters.each do |key, spec|
          value = params[key]
          next if value.nil? && spec[:default].nil?

          if spec[:min] && value && value < spec[:min]
            raise Core::DomainError.new(
              "#{key} (#{value}) abaixo do mínimo (#{spec[:min]})",
              code: :param_below_min
            )
          end

          if spec[:max] && value && value > spec[:max]
            raise Core::DomainError.new(
              "#{key} (#{value}) acima do máximo (#{spec[:max]})",
              code: :param_above_max
            )
          end
        end
      end

      def coerce_value(value, type)
        return value if type.nil? || value.nil?
        case type.name
        when 'Float' then value.to_f
        when 'Integer' then value.to_i
        when 'String' then value.to_s
        else value
        end
      end
    end
  end
end
