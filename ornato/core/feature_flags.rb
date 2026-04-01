# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# core/feature_flags.rb — Sistema de flags para ativar/desativar subsistemas
#
# Feature flags permitem:
#   - Desabilitar subsistemas instáveis durante desenvolvimento
#   - A/B testing de funcionalidades
#   - Controle de features por licença (trial vs full)
#   - Desligar features pesadas em máquinas lentas

module Ornato
  module Core
    module FeatureFlags
      # Flags disponíveis com defaults.
      # true = ativo, false = desativado.
      DEFAULTS = {
        # Subsistemas core
        catalog_sync:        true,   # Sincronização com ERP
        auto_validation:     true,   # Validar automaticamente após rebuild
        auto_edging:         true,   # Aplicar fita de borda automaticamente
        auto_drilling:       true,   # Gerar furação automaticamente

        # Visualização
        drill_markers:       true,   # Mostrar marcadores de furação 3D
        part_labels:         true,   # Mostrar labels de peças
        warnings_overlay:    true,   # Mostrar overlay de alertas
        state_overlay:       false,  # Mostrar overlay de estado (debug)

        # Performance
        geometry_lod:        true,   # Level of Detail automático
        deferred_rebuild:    false,  # Agrupar rebuilds (experimental)

        # Export
        export_machining:    true,   # Incluir usinagem na exportação
        export_diff:         true,   # Calcular diff entre exportações
        export_snapshot:     true,   # Incluir snapshot de catálogo

        # Debug
        debug_logging:       false,  # Logs de debug no console
        debug_overlay:       false,  # Overlay de debug no viewport
        performance_metrics: true    # Coletar métricas de performance
      }.freeze

      @flags = DEFAULTS.dup

      # Verifica se uma feature está ativa.
      # @param flag [Symbol]
      # @return [Boolean]
      def self.enabled?(flag)
        @flags.fetch(flag, false)
      end

      # Ativa uma feature.
      # @param flag [Symbol]
      def self.enable(flag)
        validate_flag!(flag)
        @flags[flag] = true
        Core.logger.info("Feature ativada: #{flag}")
      end

      # Desativa uma feature.
      # @param flag [Symbol]
      def self.disable(flag)
        validate_flag!(flag)
        @flags[flag] = false
        Core.logger.info("Feature desativada: #{flag}")
      end

      # Toggle de feature.
      # @param flag [Symbol]
      # @return [Boolean] novo estado
      def self.toggle(flag)
        validate_flag!(flag)
        @flags[flag] = !@flags[flag]
        Core.logger.info("Feature toggled: #{flag} → #{@flags[flag]}")
        @flags[flag]
      end

      # Retorna todas as flags e seus estados.
      # @return [Hash<Symbol, Boolean>]
      def self.all
        @flags.dup
      end

      # Reseta para defaults.
      def self.reset
        @flags = DEFAULTS.dup
      end

      # Ativa modo debug (ativa todas as flags de debug).
      def self.enable_debug_mode
        enable(:debug_logging)
        enable(:debug_overlay)
        enable(:state_overlay)
        Core.logger.level = :debug
        Core.logger.info('Modo debug ativado')
      end

      # Desativa modo debug.
      def self.disable_debug_mode
        disable(:debug_logging)
        disable(:debug_overlay)
        disable(:state_overlay)
        Core.logger.level = :info
        Core.logger.info('Modo debug desativado')
      end

      private

      def self.validate_flag!(flag)
        unless DEFAULTS.key?(flag)
          raise ArgumentError, "Feature flag desconhecida: #{flag}. Disponíveis: #{DEFAULTS.keys.join(', ')}"
        end
      end
    end
  end
end
