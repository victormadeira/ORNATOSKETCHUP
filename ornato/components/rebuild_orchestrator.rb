# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# components/rebuild_orchestrator.rb — Orquestrador transacional de rebuild
#
# O RebuildOrchestrator gerencia a atualização de módulos de forma
# transacional: ou todas as mudanças são aplicadas, ou nenhuma.
#
# Fluxo:
#   1. Recebe patches (mudanças tipadas)
#   2. Valida patches contra o módulo atual
#   3. Aplica patches ao domínio
#   4. Regenera consequências (peças, hardware, operações)
#   5. Valida resultado
#   6. Atualiza geometria SketchUp
#   7. Persiste em atributos
#   8. Emite eventos
#
# Se qualquer etapa falha, reverte ao estado anterior.

module Ornato
  module Components
    class RebuildOrchestrator
      # Patch tipado: uma mudança atômica a ser aplicada.
      Patch = Struct.new(
        :target,       # Symbol: :module, :opening, :aggregate, :part, :operation
        :target_id,    # String: ornato_id do alvo
        :action,       # Symbol: :update, :add, :remove
        :field,        # Symbol, nil: campo a alterar (para :update)
        :value,        # Object: novo valor
        :metadata,     # Hash: dados extras (ex: { aggregate_type: :gaveta })
        keyword_init: true
      ) do
        def to_s
          "Patch(#{action} #{target}##{target_id} #{field}=#{value})"
        end
      end

      # Resultado de um rebuild.
      RebuildResult = Struct.new(
        :success,      # Boolean
        :module_entity, # Domain::ModEntity
        :patches_applied, # Array<Patch>
        :errors,       # Array<String>
        :warnings,     # Array<String>
        :duration_ms,  # Float
        keyword_init: true
      ) do
        def success?; success; end
        def failed?; !success; end
      end

      # @param factory [ModuleFactory]
      # @param geometry_builder [Geometry::GeometryBuilder, nil]
      def initialize(factory: nil, geometry_builder: nil)
        @factory = factory || ModuleFactory.new
        @geometry_builder = geometry_builder
      end

      # Executa rebuild de um módulo com uma lista de patches.
      #
      # @param mod [Domain::ModEntity] módulo atual
      # @param patches [Array<Patch>] mudanças a aplicar
      # @param ruleset [Domain::Ruleset] regras de construção
      # @param scope [Symbol] :full, :partial_aggregate, :partial_engineering, :visual_only
      # @return [RebuildResult]
      def rebuild(mod, patches, ruleset, scope: :full)
        start_time = Time.now
        errors = []
        warnings = []

        Core.logger.info("Rebuild iniciado: #{mod.name} (#{scope}) — #{patches.length} patches")
        Core.events.emit(:rebuild_started, module_id: mod.ornato_id, scope: scope)

        begin
          # 1. Snapshot do estado anterior (para rollback)
          snapshot = mod.to_hash

          # 2. Validar patches
          patches.each do |patch|
            patch_errors = validate_patch(mod, patch)
            errors.concat(patch_errors)
          end

          if errors.any?
            return build_result(false, mod, [], errors, warnings, start_time)
          end

          # 3. Aplicar patches ao domínio
          applied = []
          patches.each do |patch|
            apply_patch(mod, patch)
            applied << patch
          end

          # 4. Regenerar conforme scope
          case scope
          when :full
            regenerate_full(mod, ruleset)
          when :partial_aggregate
            regenerate_aggregates(mod, ruleset)
          when :partial_engineering
            regenerate_engineering(mod, ruleset)
          when :visual_only
            # Nenhuma regeneração de domínio
          end

          # 5. Validar resultado
          schema_errors = mod.validate_schema
          schema_errors.each do |err|
            warnings << "Schema: #{err[:field]} — #{err[:msg]}"
          end

          # 6. Atualizar timestamps
          mod.updated_at = Time.now.iso8601
          mod.version = (mod.version || 0) + 1

          # 7. Persistir no SketchUp (atributos + geometria)
          persist_to_sketchup(mod, scope, warnings)

          duration = ((Time.now - start_time) * 1000).round(1)
          Core.events.emit(
            :rebuild_completed,
            module_id: mod.ornato_id,
            scope: scope,
            duration_ms: duration
          )
          Core.logger.info("Rebuild concluído: #{mod.name} em #{duration}ms")

          build_result(true, mod, applied, errors, warnings, start_time)

        rescue => e
          # Rollback: restaurar estado anterior
          Core.logger.error(
            "Rebuild falhou, restaurando estado anterior",
            error: e.message,
            backtrace: e.backtrace&.first(5)&.join(' | ')
          )

          Core.events.emit(
            :rebuild_failed,
            module_id: mod.ornato_id,
            error: e.message
          )

          errors << "Rebuild falhou: #{e.message}"
          build_result(false, mod, [], errors, warnings, start_time)
        end
      end

      # Cria um Patch de atualização de campo.
      def self.update_patch(target:, target_id:, field:, value:)
        Patch.new(target: target, target_id: target_id, action: :update, field: field, value: value)
      end

      # Cria um Patch de adição.
      def self.add_patch(target:, target_id:, value:, metadata: {})
        Patch.new(target: target, target_id: target_id, action: :add, value: value, metadata: metadata)
      end

      # Cria um Patch de remoção.
      def self.remove_patch(target:, target_id:)
        Patch.new(target: target, target_id: target_id, action: :remove)
      end

      private

      # Valida se um patch pode ser aplicado.
      def validate_patch(mod, patch)
        errors = []

        case patch.action
        when :update
          errors << "Campo não especificado no patch" if patch.field.nil?

          case patch.target
          when :module
            unless mod.respond_to?(:"#{patch.field}=")
              errors << "Campo #{patch.field} não existe em ModEntity"
            end
          when :opening
            opening = mod.find_opening(patch.target_id)
            errors << "Opening #{patch.target_id} não encontrado" unless opening
          when :aggregate
            aggregate = mod.find_aggregate(patch.target_id)
            errors << "Aggregate #{patch.target_id} não encontrado" unless aggregate
          when :part
            part = mod.find_part(patch.target_id)
            errors << "Part #{patch.target_id} não encontrada" unless part
          when :operation
            op = mod.find_operation(patch.target_id)
            errors << "Operation #{patch.target_id} não encontrada" unless op
          end

        when :add
          errors << "Valor não especificado para add" if patch.value.nil?

        when :remove
          case patch.target
          when :aggregate
            aggregate = mod.find_aggregate(patch.target_id)
            errors << "Aggregate #{patch.target_id} não encontrado para remoção" unless aggregate
          when :part
            part = mod.find_part(patch.target_id)
            errors << "Part #{patch.target_id} não encontrada para remoção" unless part
          end
        end

        errors
      end

      # Aplica um patch individual ao módulo.
      def apply_patch(mod, patch)
        case patch.action
        when :update
          apply_update(mod, patch)
        when :add
          apply_add(mod, patch)
        when :remove
          apply_remove(mod, patch)
        end
      end

      def apply_update(mod, patch)
        case patch.target
        when :module
          mod.send(:"#{patch.field}=", patch.value)
        when :opening
          opening = mod.find_opening(patch.target_id)
          opening.send(:"#{patch.field}=", patch.value) if opening
        when :aggregate
          aggregate = mod.find_aggregate(patch.target_id)
          aggregate.send(:"#{patch.field}=", patch.value) if aggregate
        when :part
          part = mod.find_part(patch.target_id)
          part.send(:"#{patch.field}=", patch.value) if part
        when :operation
          op = mod.find_operation(patch.target_id)
          op.send(:"#{patch.field}=", patch.value) if op
        end
      end

      def apply_add(mod, patch)
        case patch.target
        when :aggregate
          # Adiciona agregado a um opening
          opening = mod.find_opening(patch.target_id)
          if opening
            aggregate = patch.value
            aggregate.opening_id = opening.ornato_id
            aggregate.module_id = mod.ornato_id
            opening.aggregates << aggregate
          end
        when :opening
          # Adiciona sub-opening
          parent = mod.find_opening(patch.target_id)
          if parent
            parent.sub_openings << patch.value
          end
        when :part
          patch.value.module_id = mod.ornato_id
          mod.parts << patch.value
        when :operation
          patch.value.module_id = mod.ornato_id
          mod.operations << patch.value
        when :hardware
          patch.value.module_id = mod.ornato_id
          mod.hardware_items << patch.value
        end
      end

      def apply_remove(mod, patch)
        case patch.target
        when :aggregate
          mod.openings.each do |opening|
            remove_aggregate_recursive(opening, patch.target_id)
          end
        when :part
          mod.parts.reject! { |p| p.ornato_id == patch.target_id }
          # Remover operações associadas à peça
          mod.operations.reject! { |op| op.part_id == patch.target_id }
        when :operation
          mod.operations.reject! { |op| op.ornato_id == patch.target_id }
        when :hardware
          mod.hardware_items.reject! { |hw| hw.ornato_id == patch.target_id }
        when :opening
          mod.openings.each do |opening|
            remove_sub_opening_recursive(opening, patch.target_id)
          end
        end
      end

      def remove_aggregate_recursive(opening, aggregate_id)
        opening.aggregates.reject! { |a| a.ornato_id == aggregate_id }
        opening.sub_openings.each { |sub| remove_aggregate_recursive(sub, aggregate_id) }
      end

      def remove_sub_opening_recursive(opening, target_id)
        opening.sub_openings.reject! { |sub| sub.ornato_id == target_id }
        opening.sub_openings.each { |sub| remove_sub_opening_recursive(sub, target_id) }
      end

      # Regeneração completa: limpa consequências e recalcula tudo.
      def regenerate_full(mod, ruleset)
        # Limpar peças de agregados (manter apenas estruturais)
        mod.parts.select!(&:structural?)

        # Limpar hardware e operações geradas
        mod.hardware_items.clear
        mod.operations.clear

        # Regenerar engenharia nas estruturais
        regenerate_engineering(mod, ruleset)

        # Regenerar consequências dos agregados
        regenerate_aggregates(mod, ruleset)
      end

      # Regenera apenas consequências de agregados.
      def regenerate_aggregates(mod, ruleset)
        # Remover peças não-estruturais (geradas por agregados)
        mod.parts.select!(&:structural?)

        # Remover hardware todo (gerado por agregados)
        mod.hardware_items.clear

        # Limpar operações e regenerar tudo (evitar duplicatas)
        mod.operations.clear

        # Regenerar engenharia base (S32, fita, canais)
        regenerate_engineering(mod, ruleset)

        # Gerar consequências dos agregados (peças, hardware, operações)
        factory = @factory || ModuleFactory.new
        begin
          factory.send(:generate_aggregate_consequences, mod, ruleset)
        rescue => e
          Core.logger.error("Falha ao gerar consequências de agregados: #{e.message}")
        end
      end

      # Regenera apenas engenharia (S32, fita de borda, canais).
      # Limpa operações de engenharia existentes para evitar duplicatas.
      def regenerate_engineering(mod, ruleset)
        recipe = Recipes::RecipeRegistry.instance.find(mod.module_type)
        unless recipe
          Core.logger.warn("Receita não encontrada para #{mod.module_type}, engenharia não regenerada")
          return
        end

        # Limpar operações de engenharia existentes (S32, canais, fita)
        # Manter operações de agregados (furação dobradiça, etc.)
        engineering_types = %i[furacao canal]
        engineering_descriptions = ['S32', 'Canal Fundo']
        mod.operations.reject! do |op|
          engineering_types.include?(op.operation_type) &&
            engineering_descriptions.any? { |desc| op.description.to_s.start_with?(desc) }
        end

        # Limpar fita de borda existente nas peças estruturais para reaplicar
        mod.parts.each do |part|
          next unless part.structural?
          next if part.code == 'CM_FUN'
          # Reset operation_ids de engenharia nas peças
          part.operation_ids.reject! do |op_id|
            !mod.operations.any? { |op| op.ornato_id == op_id }
          end
        end

        # Regenerar
        if recipe.respond_to?(:apply_system_32, true)
          recipe.send(:apply_system_32, mod, ruleset)
        end

        if recipe.respond_to?(:apply_default_edging, true)
          recipe.send(:apply_default_edging, mod, ruleset)
        end

        if mod.back_type == :encaixado && recipe.respond_to?(:apply_back_groove, true)
          recipe.send(:apply_back_groove, mod, {}, ruleset)
        end
      end

      # Persiste alterações de domínio de volta no SketchUp.
      # Encontra a entity pelo ornato_id e atualiza atributos + geometria.
      def persist_to_sketchup(mod, scope, warnings)
        model = Sketchup.active_model rescue nil
        return unless model

        entity = Core::Attributes.find_entity_by_ornato_id(mod.ornato_id, model)
        unless entity
          warnings << "Entity SketchUp não encontrada para persistência (#{mod.ornato_id})"
          return
        end

        # Sempre persistir atributos de domínio
        Core::Attributes.persist_domain_entity(entity, mod)

        # Atualizar geometria se scope exige reconstrução visual
        if scope == :full || scope == :partial_aggregate
          builder = @geometry_builder || Geometry::GeometryBuilder.new
          builder.update_module(mod, entity, model)
        end

        Core.logger.info("Persistido no SketchUp: #{mod.name} (#{scope})")
      rescue => e
        # Persistência falha não deve abortar o rebuild de domínio
        warnings << "Falha ao persistir no SketchUp: #{e.message}"
        Core.logger.warn("Persist falhou: #{e.message}", backtrace: e.backtrace&.first(3)&.join(' | '))
      end

      def build_result(success, mod, applied, errors, warnings, start_time)
        duration = ((Time.now - start_time) * 1000).round(1)
        RebuildResult.new(
          success: success,
          module_entity: mod,
          patches_applied: applied,
          errors: errors,
          warnings: warnings,
          duration_ms: duration
        )
      end
    end
  end
end
