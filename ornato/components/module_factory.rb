# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# components/module_factory.rb — Fábrica de módulos paramétricos
#
# O ModuleFactory é o ponto de entrada para criação de módulos.
# Ele conecta a receita ao ruleset e executa a criação completa.
#
# Responsabilidades:
#   - Resolve receita por tipo de módulo
#   - Aplica ruleset (regras de construção)
#   - Delega a execução ao RecipeBase
#   - Persiste nos atributos SketchUp via Attributes
#   - Emite eventos de ciclo de vida
#
# Uso:
#   factory = Ornato::Components::ModuleFactory.new
#   mod = factory.create(:balcao, { width_mm: 800 }, ruleset)

module Ornato
  module Components
    class ModuleFactory
      def initialize
        @registry = Recipes::RecipeRegistry.instance
      end

      # Resultado de criação de módulo.
      CreationResult = Struct.new(
        :success,       # Boolean
        :module_entity, # Domain::ModEntity
        :errors,        # Array<String>
        :warnings,      # Array<String>
        keyword_init: true
      ) do
        def success?; success; end
        def failed?; !success; end
      end

      # Cria um módulo a partir de tipo, parâmetros e ruleset.
      #
      # @param module_type [Symbol] tipo do módulo (:balcao, :aereo, etc.)
      # @param params [Hash] parâmetros dimensionais e de configuração
      # @param ruleset [Domain::Ruleset] regras de construção
      # @param options [Hash] opções extras
      # @option options [Boolean] :skip_geometry (false) não gerar geometria SketchUp
      # @option options [Boolean] :skip_persist (false) não persistir em atributos
      # @option options [Boolean] :strict (false) falhar em erros de validação
      # @return [Domain::ModEntity] módulo completo (ou CreationResult se :strict)
      def create(module_type, params, ruleset, **options)
        Core.logger.measure('ModuleFactory.create') do
          warnings = []
          recipe = @registry.find!(module_type)

          # Executar receita (cria domínio completo)
          mod = recipe.execute(params, ruleset)

          # Gerar consequências dos agregados
          generate_aggregate_consequences(mod, ruleset)

          # Validar resultado
          schema_errors = mod.validate_schema
          if schema_errors.any?
            error_msgs = schema_errors.map { |e| "#{e[:field]}: #{e[:msg]}" }

            # Separar erros críticos (dimensões inválidas) de avisos
            blocking = schema_errors.select { |e| e[:level] == :error || e[:field].to_s.include?('mm') }
            non_blocking = schema_errors - blocking

            if blocking.any? && options[:strict]
              Core.logger.error("Módulo rejeitado por validação: #{error_msgs.join(', ')}")
              return CreationResult.new(
                success: false,
                module_entity: nil,
                errors: blocking.map { |e| "#{e[:field]}: #{e[:msg]}" },
                warnings: non_blocking.map { |e| "#{e[:field]}: #{e[:msg]}" }
              )
            end

            if blocking.any?
              Core.logger.warn("Módulo criado com erros de schema: #{error_msgs.join(', ')}")
              warnings.concat(error_msgs)
            end
          end

          Core.logger.info(
            "Módulo criado: #{mod.name} (#{mod.module_type}) — " \
            "#{mod.parts.length} peças, #{mod.all_aggregates.length} agregados, " \
            "#{mod.operations.length} operações"
          )

          if options[:strict]
            CreationResult.new(
              success: true,
              module_entity: mod,
              errors: [],
              warnings: warnings
            )
          else
            mod
          end
        end
      end

      # Recria um módulo existente a partir de seus atributos persistidos.
      # Usado para carregar módulos ao abrir um arquivo .skp.
      #
      # @param entity [Sketchup::Entity] grupo/componente SketchUp
      # @return [Domain::ModEntity, nil]
      def load_from_entity(entity)
        return nil unless Core::Attributes.ornato_entity?(entity)
        return nil unless Core::Attributes.entity_type(entity) == :module

        data = Core::Attributes.load_domain_data(entity)
        Domain::ModEntity.from_hash(data)
      rescue => e
        Core.logger.error(
          "Falha ao carregar módulo de entity",
          error: e.message,
          entity_id: entity.respond_to?(:entityID) ? entity.entityID : 'unknown'
        )
        nil
      end

      # Lista receitas disponíveis com metadata.
      # @return [Array<Hash>]
      def available_recipes
        @registry.catalog
      end

      # Verifica se um tipo de módulo tem receita registrada.
      # @param module_type [Symbol]
      # @return [Boolean]
      def recipe_available?(module_type)
        @registry.registered?(module_type)
      end

      private

      # Gera peças, hardware e operações a partir dos agregados do módulo.
      def generate_aggregate_consequences(mod, ruleset)
        aggregates = mod.all_aggregates
        return if aggregates.empty?

        aggregates.each do |aggregate|
          # Encontrar o opening que contém este agregado
          opening = find_opening_for_aggregate(mod, aggregate)
          unless opening
            Core.logger.warn(
              "Opening não encontrado para agregado #{aggregate.ornato_id} " \
              "(opening_id: #{aggregate.opening_id}), pulando geração de consequências"
            )
            next
          end

          context = build_aggregate_context(mod, opening, aggregate, ruleset)

          # Gerar peças (com verificação nil/empty)
          if aggregate.respond_to?(:generate_parts)
            begin
              parts = aggregate.generate_parts(context) || []
              parts.each do |part|
                next unless part # Ignorar nils
                part.module_id = mod.ornato_id
                mod.parts << part
              end
            rescue => e
              Core.logger.warn("Falha ao gerar peças do agregado #{aggregate.ornato_id}: #{e.message}")
            end
          end

          # Gerar hardware (com verificação nil/empty)
          if aggregate.respond_to?(:generate_hardware)
            begin
              hardware = aggregate.generate_hardware(context) || []
              hardware.each do |hw|
                next unless hw
                hw.module_id = mod.ornato_id
                mod.hardware_items << hw
              end
            rescue => e
              Core.logger.warn("Falha ao gerar hardware do agregado #{aggregate.ornato_id}: #{e.message}")
            end
          end

          # Gerar operações (com verificação nil/empty)
          if aggregate.respond_to?(:generate_operations)
            begin
              operations = aggregate.generate_operations(context) || []
              operations.each do |op|
                next unless op
                op.module_id = mod.ornato_id
                mod.operations << op
              end
            rescue => e
              Core.logger.warn("Falha ao gerar operações do agregado #{aggregate.ornato_id}: #{e.message}")
            end
          end
        end
      end

      # Encontra o opening que contém um agregado.
      def find_opening_for_aggregate(mod, aggregate)
        mod.openings.each do |opening|
          result = search_opening(opening, aggregate.opening_id)
          return result if result
        end
        nil
      end

      def search_opening(opening, target_id)
        return opening if opening.ornato_id == target_id
        opening.sub_openings.each do |sub|
          result = search_opening(sub, target_id)
          return result if result
        end
        nil
      end

      # Constrói contexto para geração de consequências do agregado.
      def build_aggregate_context(mod, opening, aggregate, ruleset)
        {
          module_entity: mod,
          opening: opening,
          aggregate: aggregate,
          ruleset: ruleset,
          body_thickness: mod.body_thickness,
          body_material_id: mod.body_material_id,
          front_material_id: mod.front_material_id,
          opening_width: opening.width_mm,
          opening_height: opening.height_mm,
          opening_depth: opening.depth_mm
        }
      end
    end
  end
end
