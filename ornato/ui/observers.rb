# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# ui/observers.rb — Observers SketchUp
#
# Monitora eventos do SketchUp para manter o plugin sincronizado:
#   - SelectionObserver: detecta nível hierárquico e atualiza painel
#   - ModelObserver: detecta salvamento, abertura de modelo
#   - EntitiesObserver: detecta exclusão/modificação de entities

module Ornato
  module UI
    # Observer de seleção: detecta nível e atualiza painel adaptativo.
    class SelectionObserver < Sketchup::SelectionObserver
      DEBOUNCE_MS = 50  # Evitar excesso de recalculos durante selecao rapida

      def initialize
        super
        @last_change = 0
        @pending_timer_id = nil
      end

      def onSelectionBulkChange(selection)
        now = Time.now.to_f * 1000
        # Sempre limpar timer anterior para evitar acumulo (memory leak fix)
        ::UI.stop_timer(@pending_timer_id) if @pending_timer_id
        @pending_timer_id = nil

        if now - @last_change < DEBOUNCE_MS
          # Agendar para depois do debounce
          @pending_timer_id = ::UI.start_timer(DEBOUNCE_MS / 1000.0, false) do
            @pending_timer_id = nil
            handle_selection_change(selection)
          end
        else
          handle_selection_change(selection)
        end
        @last_change = now
      end

      def onSelectionCleared(selection)
        ::UI.stop_timer(@pending_timer_id) if @pending_timer_id
        @pending_timer_id = nil
        Core.events.emit(:selection_changed, entity_ids: [])
        push_nivel_to_panel(LevelDetector.detectar(selection))
      end

      private

      def handle_selection_change(selection)
        return if selection.empty?

        # Detectar nível hierárquico
        nivel_info = LevelDetector.detectar(selection)

        # Atualizar status bar com resumo
        update_status_bar(nivel_info)

        # Enviar para o painel
        push_nivel_to_panel(nivel_info)
      end

      def update_status_bar(info)
        case info[:nivel]
        when :projeto
          n = info[:data][:total_modulos]
          Sketchup.status_text = "ORNATO | Projeto: #{n} modulo(s)"
        when :modulo
          d = info[:data]
          peso = d[:peso_kg] ? " | #{d[:peso_kg]}kg" : ''
          area = d[:area_m2] ? " | #{d[:area_m2]}m²" : ''
          Sketchup.status_text = "ORNATO | #{d[:nome]} (#{d[:tipo]}) | #{d[:largura_mm]}x#{d[:profundidade_mm]}x#{d[:altura_mm]}mm | #{d[:total_pecas]}p#{peso}#{area}"
        when :peca
          d = info[:data]
          mat = d[:material].to_s.empty? ? '' : " | #{d[:material]}"
          Sketchup.status_text = "ORNATO | #{d[:nome]} (#{d[:tipo]}) | #{d[:comp_mm].round}x#{d[:larg_mm].round}x#{d[:espessura_mm].round}mm#{mat}"
        when :operacao
          d = info[:data]
          extra = d[:diametro].to_f > 0 ? " | ø#{d[:diametro].round(1)}mm" : ''
          Sketchup.status_text = "ORNATO | #{d[:nome]} (#{d[:subtipo]})#{extra}"
        end
      rescue => e
        # Nunca crashar o observer
      end

      def push_nivel_to_panel(info)
        panel = MainPanel.instance
        return unless panel.visible? && panel.bridge

        # Delegar serialização ao MainPanel para evitar duplicação
        panel.push_nivel(info)
      rescue => e
        # Nunca crashar o observer
      end
    end

    # Observer de modelo: detecta eventos de arquivo.
    class ModelObserver < Sketchup::ModelObserver
      def onNewModel(model)
        Core.logger.info('Novo modelo criado')
        # Limpar cache do bridge ao trocar de modelo
        clear_bridge_cache
        ObserverManager.attach(model)
        Core.events.emit(:model_new, model: model)
      end

      def onOpenModel(model)
        Core.logger.info('Modelo aberto')
        # Limpar cache do bridge ao abrir novo modelo
        clear_bridge_cache
        ObserverManager.attach(model)
        Core.events.emit(:model_opened, model: model)
      end

      def onPreSaveModel(model)
        Core.logger.info('Salvando modelo...')
      end

      def onPostSaveModel(model)
        Core.logger.info('Modelo salvo')
      end

      def onDeleteModel(model)
        Core.logger.info('Modelo fechado')
        clear_bridge_cache
      end

      private

      def clear_bridge_cache
        panel = MainPanel.instance
        panel.bridge&.clear_cache if panel.visible? && panel.bridge
      rescue => e
        # Nunca crashar o observer
      end
    end

    # Observer de entities: detecta quando groups/components são apagados.
    class EntitiesObserver < Sketchup::EntitiesObserver
      def onElementRemoved(entities, entity)
        return unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

        if Core::Attributes.ornato_entity?(entity)
          ornato_id = Core::Attributes.ornato_id(entity)
          Core.events.emit(:module_deleted, module_id: ornato_id)
          Core.logger.info("Entity Ornato removida: #{ornato_id}")
        end
      rescue => e
        Core.logger.warn("Observer: erro ao processar remoção: #{e.message}")
      end

      def onElementModified(entities, entity)
        return unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

        if Core::Attributes.ornato_entity?(entity)
          ornato_id = Core::Attributes.ornato_id(entity)
          Core.events.emit(:module_updated, module_id: ornato_id, patches: [])
        end
      rescue => e
        Core.logger.warn("Observer: erro ao processar modificação: #{e.message}")
      end
    end

    # Módulo para registrar/remover observers.
    module ObserverManager
      @selection_observer = nil
      @model_observer = nil
      @entities_observer = nil

      # Registra todos os observers no modelo ativo.
      def self.attach(model)
        detach(model) # Limpar observers anteriores

        @selection_observer = SelectionObserver.new
        model.selection.add_observer(@selection_observer)

        @model_observer = ModelObserver.new
        model.add_observer(@model_observer)

        @entities_observer = EntitiesObserver.new
        model.entities.add_observer(@entities_observer)

        Core.logger.info('Observers registrados')
      end

      # Remove todos os observers.
      def self.detach(model)
        model.selection.remove_observer(@selection_observer) if @selection_observer
        model.remove_observer(@model_observer) if @model_observer
        model.entities.remove_observer(@entities_observer) if @entities_observer

        @selection_observer = nil
        @model_observer = nil
        @entities_observer = nil
      end
    end
  end
end
