# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# components/state_bridge.rb — Ponte de estado entre Ruby e HtmlDialog
#
# O StateBridge é o mediador entre a UI (JavaScript no HtmlDialog) e o
# domínio Ruby. Toda comunicação UI→Ruby passa por aqui.
#
# Responsabilidades:
#   - Consolidar estado do módulo selecionado em um payload JSON
#   - Despachar ações vindas da UI para os componentes corretos
#   - Emitir atualizações de volta para o JavaScript via execute_script
#   - Debounce de atualizações para performance
#
# Protocolo:
#   JS → Ruby: dialog.add_action_callback("ornato_action") { |action_context, payload| ... }
#   Ruby → JS: dialog.execute_script("ornatoReceiveState(#{json})")

module Ornato
  module Components
    class StateBridge
      # Ações suportadas pela bridge.
      ACTIONS = %i[
        select_module deselect_module
        resize_module change_material change_thickness
        change_assembly change_back_type
        add_aggregate remove_aggregate update_aggregate
        divide_horizontal divide_vertical
        request_state request_recipes request_materials
        set_feature_flag
        export_project create_revision
      ].freeze

      attr_reader :dialog, :current_module_id

      def initialize(dialog)
        @dialog = dialog
        @updater = ModuleUpdater.new
        @factory = ModuleFactory.new
        @aggregate_engine = AggregateEngine.new
        @current_module_id = nil
        @modules = {}   # ornato_id → ModEntity cache
        @rulesets = {}   # ruleset_id → Ruleset cache
        @debounce_timer = nil

        register_callbacks
      end

      # ── Envio de estado para o JS ─────────────────────────────────

      # Envia estado completo do módulo selecionado para o JS.
      def push_state(mod = nil)
        mod ||= @modules[@current_module_id]
        return push_empty_state unless mod

        payload = build_state_payload(mod)
        send_to_js('ornatoReceiveState', payload)
      end

      # Envia apenas uma atualização parcial.
      def push_partial_update(key, data)
        send_to_js('ornatoReceivePartial', { key: key, data: data })
      end

      # Notifica erro para o JS.
      def push_error(message, details = nil)
        send_to_js('ornatoReceiveError', { message: message, details: details })
      end

      # Notifica sucesso para o JS.
      def push_success(message)
        send_to_js('ornatoReceiveSuccess', { message: message })
      end

      # ── Registro de módulos ───────────────────────────────────────

      # Registra um módulo no cache da bridge.
      def register_module(mod)
        @modules[mod.ornato_id] = mod
      end

      # Remove módulo do cache.
      def unregister_module(module_id)
        @modules.delete(module_id)
        @current_module_id = nil if @current_module_id == module_id
      end

      # Registra ruleset no cache.
      def register_ruleset(ruleset)
        @rulesets[ruleset.ornato_id] = ruleset
      end

      # Limpa todos os caches (chamar ao fechar modelo ou trocar de projeto).
      def clear_cache
        @modules.clear
        @rulesets.clear
        @current_module_id = nil
      end

      private

      # ── Callbacks de ações ────────────────────────────────────────

      def register_callbacks
        # NOTA: O callback 'ornato_action' é registrado pelo MainPanel (main_panel.rb)
        # que atua como dispatcher principal. O StateBridge é usado apenas para
        # comunicação Ruby→JS (send_to_js) e gerenciamento de cache de módulos.
        # Registrar aqui causaria conflito (último callback sobrescreve o anterior).
      end

      def dispatch_action(data)
        action = data[:action]&.to_sym
        payload = data[:payload] || {}

        unless ACTIONS.include?(action)
          push_error("Ação desconhecida: #{action}")
          return
        end

        Core.logger.info("StateBridge: #{action}")

        case action
        when :select_module
          handle_select_module(payload)
        when :deselect_module
          handle_deselect_module
        when :resize_module
          handle_resize(payload)
        when :change_material
          handle_change_material(payload)
        when :change_thickness
          handle_change_thickness(payload)
        when :change_assembly
          handle_change_assembly(payload)
        when :change_back_type
          handle_change_back_type(payload)
        when :add_aggregate
          handle_add_aggregate(payload)
        when :remove_aggregate
          handle_remove_aggregate(payload)
        when :update_aggregate
          handle_update_aggregate(payload)
        when :divide_horizontal
          handle_divide_horizontal(payload)
        when :divide_vertical
          handle_divide_vertical(payload)
        when :request_state
          push_state
        when :request_recipes
          handle_request_recipes
        when :request_materials
          handle_request_materials
        when :set_feature_flag
          handle_set_feature_flag(payload)
        when :export_project
          handle_export_project(payload)
        when :create_revision
          handle_create_revision(payload)
        end
      end

      # ── Handlers ──────────────────────────────────────────────────

      def handle_select_module(payload)
        mod_id = payload[:module_id]
        mod = @modules[mod_id]
        unless mod
          push_error("Módulo não encontrado: #{mod_id}")
          return
        end
        @current_module_id = mod_id
        push_state(mod)
      end

      def handle_deselect_module
        @current_module_id = nil
        push_empty_state
      end

      def handle_resize(payload)
        mod = current_module
        return unless mod

        result = @updater.resize(
          mod, current_ruleset,
          width: payload[:width]&.to_f,
          height: payload[:height]&.to_f,
          depth: payload[:depth]&.to_f
        )

        handle_rebuild_result(result)
      end

      def handle_change_material(payload)
        mod = current_module
        return unless mod

        target = payload[:target]&.to_sym  # :body ou :front
        material_id = payload[:material_id]

        result = if target == :front
                   @updater.change_front_material(mod, material_id, current_ruleset)
                 else
                   @updater.change_body_material(mod, material_id, current_ruleset)
                 end

        handle_rebuild_result(result)
      end

      def handle_change_thickness(payload)
        mod = current_module
        return unless mod

        result = @updater.change_body_thickness(mod, payload[:thickness], current_ruleset)
        handle_rebuild_result(result)
      end

      def handle_change_assembly(payload)
        mod = current_module
        return unless mod

        result = @updater.change_assembly_type(mod, payload[:assembly_type], current_ruleset)
        handle_rebuild_result(result)
      end

      def handle_change_back_type(payload)
        mod = current_module
        return unless mod

        result = @updater.change_back_type(mod, payload[:back_type], current_ruleset)
        handle_rebuild_result(result)
      end

      def handle_add_aggregate(payload)
        mod = current_module
        return unless mod

        opening_id = payload[:opening_id]
        aggregate = Domain::Aggregate.new(
          name: payload[:name] || 'Novo Agregado',
          aggregate_type: payload[:aggregate_type].to_sym
        )

        # Validar compatibilidade
        opening = mod.find_opening(opening_id)
        if opening
          validation = @aggregate_engine.validate_placement(aggregate.aggregate_type, opening)
          unless validation[:valid]
            push_error("Agregado incompatível: #{validation[:errors].join(', ')}")
            return
          end
        end

        # Configurar agregado
        aggregate.door_subtype = payload[:door_subtype]&.to_sym if payload[:door_subtype]
        aggregate.overlap = payload[:overlap]&.to_sym if payload[:overlap]
        aggregate.slide_type = payload[:slide_type]&.to_sym if payload[:slide_type]
        aggregate.material_id = payload[:material_id] || mod.front_material_id
        aggregate.thickness = payload[:thickness] || current_ruleset.rule(:front, :thickness, fallback: 18)

        result = @updater.add_aggregate(mod, opening_id, aggregate, current_ruleset)
        handle_rebuild_result(result)
      end

      def handle_remove_aggregate(payload)
        mod = current_module
        return unless mod

        result = @updater.remove_aggregate(mod, payload[:aggregate_id], current_ruleset)
        handle_rebuild_result(result)
      end

      def handle_update_aggregate(payload)
        mod = current_module
        return unless mod

        result = @updater.update_aggregate(
          mod, payload[:aggregate_id],
          payload[:field].to_sym, payload[:value],
          current_ruleset
        )
        handle_rebuild_result(result)
      end

      def handle_divide_horizontal(payload)
        mod = current_module
        return unless mod

        result = @updater.divide_horizontal(
          mod, payload[:opening_id], payload[:height].to_f, current_ruleset
        )
        handle_rebuild_result(result)
      end

      def handle_divide_vertical(payload)
        mod = current_module
        return unless mod

        result = @updater.divide_vertical(
          mod, payload[:opening_id], payload[:width].to_f, current_ruleset
        )
        handle_rebuild_result(result)
      end

      def handle_request_recipes
        recipes = @factory.available_recipes
        push_partial_update(:recipes, recipes)
      end

      def handle_request_materials
        catalog = Core.catalog rescue nil
        if catalog && catalog.materials.any?
          push_partial_update(:materials, catalog.materials)
        else
          push_partial_update(:materials, [])
        end
      end

      def handle_set_feature_flag(payload)
        flag = payload[:flag]&.to_sym
        enabled = payload[:enabled]
        if enabled
          Core::FeatureFlags.enable(flag)
        else
          Core::FeatureFlags.disable(flag)
        end
        push_partial_update(:feature_flags, Core::FeatureFlags.all)
      end

      def handle_export_project(payload)
        # Delegado ao ExportEngine (será criado em export/)
        push_success('Exportação solicitada')
        Core.events.emit(:export_started, project_id: payload[:project_id])
      end

      def handle_create_revision(payload)
        push_success('Revisão criada')
      end

      # ── Helpers ───────────────────────────────────────────────────

      def current_module
        mod = @modules[@current_module_id]
        push_error("Nenhum módulo selecionado") unless mod
        mod
      end

      def current_ruleset
        mod = @modules[@current_module_id]
        return default_ruleset unless mod && mod.ruleset_id
        @rulesets[mod.ruleset_id] || default_ruleset
      end

      def default_ruleset
        @default_ruleset ||= Domain::Ruleset.new(
          name: 'Padrão',
          rules: {
            construction: {
              assembly_type: :brasil,
              back_type: :encaixado,
              back_thickness: 3,
              base_type: :rodape,
              base_height_mm: 100.0,
              back_groove_depth: 8.0
            },
            edging: {
              default_thickness: 1.0,
              default_width: 22.0
            },
            front: {
              thickness: 18
            }
          }
        )
      end

      def handle_rebuild_result(result)
        if result.success?
          push_state(result.module_entity)
          if result.warnings.any?
            push_partial_update(:warnings, result.warnings)
          end
        else
          push_error(
            "Rebuild falhou: #{result.errors.join(', ')}",
            { patches: result.patches_applied.map(&:to_s) }
          )
        end
      end

      def build_state_payload(mod)
        {
          module: mod.to_hash,
          openings: build_opening_tree(mod),
          aggregates: mod.all_aggregates.map(&:to_hash),
          parts_summary: {
            total: mod.parts.length,
            structural: mod.structural_parts.length,
            front: mod.front_parts.length,
            area_m2: mod.total_area_m2.round(3),
            edgeband_m: mod.total_edgeband_meters.round(2)
          },
          hardware_count: mod.hardware_items.length,
          operations_count: mod.operations.length,
          compatible_aggregates: {},
          feature_flags: Core::FeatureFlags.all
        }
      end

      def build_opening_tree(mod)
        mod.openings.map { |o| opening_to_hash(o) }
      end

      def opening_to_hash(opening)
        {
          ornato_id: opening.ornato_id,
          name: "Vão #{opening.width_mm.round}x#{opening.height_mm.round}mm",
          width_mm: opening.width_mm,
          height_mm: opening.height_mm,
          depth_mm: opening.depth_mm,
          aggregates: opening.aggregates.map(&:to_hash),
          sub_openings: opening.sub_openings.map { |sub| opening_to_hash(sub) },
          compatible: @aggregate_engine.suggest_aggregates(opening)
        }
      end

      def push_empty_state
        send_to_js('ornatoReceiveState', { module: nil })
      end

      public

      def send_to_js(function, data)
        return unless @dialog

        json = data.to_json
        @dialog.execute_script("#{function}(#{json})")
      rescue => e
        Core.logger.error("StateBridge: falha ao enviar para JS", error: e.message)
      end
    end
  end
end
