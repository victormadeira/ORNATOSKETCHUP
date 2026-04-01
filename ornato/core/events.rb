# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# core/events.rb — EventBus desacoplado para comunicação entre subsistemas
#
# O EventBus permite que subsistemas reajam a mudanças sem dependências diretas.
# Eventos são disparados com payload (Hash) e consumidos por handlers (blocos).
#
# Eventos definidos no sistema:
#
#   MÓDULOS:
#     :module_created       { module_id: }
#     :module_updated       { module_id:, patches: }
#     :module_deleted       { module_id: }
#
#   AGREGADOS:
#     :aggregate_added      { module_id:, opening_id:, aggregate_id:, type: }
#     :aggregate_removed    { module_id:, opening_id:, aggregate_id: }
#
#   REBUILD:
#     :rebuild_started      { module_id:, scope: }
#     :rebuild_completed    { module_id:, scope:, duration_ms: }
#     :rebuild_failed       { module_id:, error: }
#
#   VALIDAÇÃO:
#     :validation_completed { module_id:, result: }
#
#   EXPORTAÇÃO:
#     :export_started       { project_id: }
#     :export_completed     { project_id:, export_id:, path: }
#     :export_failed        { project_id:, error: }
#
#   CATÁLOGO:
#     :catalog_synced       { version: }
#
#   REVISÃO:
#     :revision_created     { project_id:, revision_id:, number: }
#     :project_state_changed { project_id:, from:, to: }
#
#   IDENTIDADE:
#     :identity_reconciled  { report: }
#
#   UI:
#     :selection_changed    { entity_ids: }
#     :state_bridge_update  { payload: }

module Ornato
  module Core
    class EventBus
      def initialize
        @subscribers = Hash.new { |h, k| h[k] = [] }
        @once_subscribers = Hash.new { |h, k| h[k] = [] }
      end

      # Registra listener permanente para um evento.
      #
      # @param event [Symbol] nome do evento (ex: :module_created)
      # @yield [Hash] payload do evento
      # @return [Proc] o handler registrado (para poder remover via #off)
      #
      # Exemplo:
      #   handler = events.on(:module_created) { |p| puts p[:module_id] }
      def on(event, &handler)
        raise ArgumentError, 'Bloco obrigatório para on()' unless block_given?
        @subscribers[event] << handler
        handler
      end

      # Registra listener que dispara apenas uma vez e se auto-remove.
      #
      # @param event [Symbol]
      # @yield [Hash] payload
      # @return [Proc]
      def once(event, &handler)
        raise ArgumentError, 'Bloco obrigatório para once()' unless block_given?
        @once_subscribers[event] << handler
        handler
      end

      # Dispara evento com payload para todos os subscribers.
      # Handlers que falharem são logados mas não interrompem outros handlers.
      #
      # @param event [Symbol]
      # @param payload [Hash] dados do evento (expandidos como keyword args)
      def emit(event, **payload)
        payload[:event] = event
        payload[:timestamp] = Time.now.iso8601

        # Subscribers permanentes
        @subscribers[event].each do |handler|
          safe_call(handler, event, payload)
        end

        # Subscribers de uso único (removidos após disparo)
        once_list = @once_subscribers.delete(event) || []
        once_list.each do |handler|
          safe_call(handler, event, payload)
        end
      end

      # Remove um handler específico de um evento.
      #
      # @param event [Symbol]
      # @param handler [Proc] o handler retornado por #on
      def off(event, handler)
        @subscribers[event].delete(handler)
      end

      # Remove todos os handlers de um evento (ou todos se event=nil).
      #
      # @param event [Symbol, nil]
      def clear(event = nil)
        if event
          @subscribers.delete(event)
          @once_subscribers.delete(event)
        else
          @subscribers.clear
          @once_subscribers.clear
        end
      end

      # Conta handlers registrados para um evento.
      # @param event [Symbol]
      # @return [Integer]
      def subscriber_count(event)
        (@subscribers[event]&.length || 0) + (@once_subscribers[event]&.length || 0)
      end

      # Lista todos os eventos que têm subscribers.
      # @return [Array<Symbol>]
      def active_events
        (@subscribers.keys + @once_subscribers.keys).uniq.sort
      end

      private

      def safe_call(handler, event, payload)
        handler.call(payload)
      rescue => e
        # Nunca deixar um handler falho derrubar o sistema
        Core.logger.error(
          "EventBus: handler falhou para #{event}",
          error: e.message,
          backtrace: e.backtrace&.first(3)&.join(' | ')
        )
      end
    end

    # Singleton global — único EventBus do plugin.
    # Acesso: Ornato::Core.events
    def self.events
      @events ||= EventBus.new
    end

    # Singleton global — catálogo de materiais/fitas/ferragens.
    # Acesso: Ornato::Core.catalog
    def self.catalog
      @catalog
    end

    def self.catalog=(cat)
      @catalog = cat
    end
  end
end
