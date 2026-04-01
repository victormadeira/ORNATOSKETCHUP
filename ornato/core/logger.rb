# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# core/logger.rb — Log estruturado com métricas de performance
#
# Uso:
#   Ornato::Core.logger.info("Módulo criado", name: "Balcão 600", parts: 5)
#   Ornato::Core.logger.measure("rebuild") { rebuild_module(mod) }
#   Ornato::Core.logger.metrics_summary  # => { "rebuild" => { count: 3, avg_ms: 245.2 } }

module Ornato
  module Core
    class Logger
      LEVELS = {
        debug: 0,
        info:  1,
        warn:  2,
        error: 3,
        fatal: 4
      }.freeze

      LEVEL_TAGS = {
        debug: 'DBG',
        info:  'INF',
        warn:  'WRN',
        error: 'ERR',
        fatal: 'FTL'
      }.freeze

      attr_accessor :level

      def initialize(level: :info)
        @level = level
        @metrics = {}
      end

      # Métodos de conveniência: debug, info, warn, error, fatal
      LEVELS.each_key do |lvl|
        define_method(lvl) do |message, **context|
          log(lvl, message, **context)
        end
      end

      # Log estruturado com contexto.
      # @param level [Symbol] :debug, :info, :warn, :error, :fatal
      # @param message [String] mensagem principal
      # @param context [Hash] dados adicionais (key=value no output)
      def log(level, message, **context)
        return unless should_log?(level)

        timestamp = Time.now.strftime('%H:%M:%S.%L')
        tag = LEVEL_TAGS[level]
        ctx_str = format_context(context)
        output = "[Ornato][#{tag}][#{timestamp}] #{message}#{ctx_str}"

        # SketchUp: warn vai para Ruby Console, puts também
        if level == :error || level == :fatal
          warn output
        else
          puts output
        end
      end

      # Mede tempo de execução de um bloco e registra como métrica.
      # @param label [String] nome da operação
      # @return [Object] resultado do bloco
      def measure(label)
        start = monotonic_time
        result = yield
        elapsed_ms = ((monotonic_time - start) * 1000).round(1)

        @metrics[label] ||= []
        @metrics[label] << elapsed_ms

        info("#{label} completado", duration_ms: elapsed_ms)
        result
      end

      # Resumo de métricas coletadas.
      # @return [Hash] { label => { count:, avg_ms:, min_ms:, max_ms:, total_ms: } }
      def metrics_summary
        @metrics.transform_values do |times|
          {
            count: times.length,
            avg_ms: (times.sum / times.length.to_f).round(1),
            min_ms: times.min.round(1),
            max_ms: times.max.round(1),
            total_ms: times.sum.round(1)
          }
        end
      end

      # Limpa métricas acumuladas.
      def reset_metrics
        @metrics.clear
      end

      # Retorna métricas de uma operação específica.
      # @param label [String]
      # @return [Hash, nil]
      def metric(label)
        times = @metrics[label]
        return nil unless times && !times.empty?
        {
          count: times.length,
          avg_ms: (times.sum / times.length.to_f).round(1),
          last_ms: times.last.round(1)
        }
      end

      private

      def should_log?(level)
        LEVELS[level] >= LEVELS[@level]
      end

      def format_context(context)
        return '' if context.empty?
        pairs = context.map do |k, v|
          value = case v
                  when Array then v.first(3).join(', ') + (v.length > 3 ? '...' : '')
                  when Hash then "{#{v.first(3).map { |kk, vv| "#{kk}:#{vv}" }.join(', ')}}"
                  else v.to_s
                  end
          "#{k}=#{value}"
        end
        " | #{pairs.join(' ')}"
      end

      def monotonic_time
        if defined?(Process::CLOCK_MONOTONIC)
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        else
          Time.now.to_f
        end
      end
    end

    # Singleton global — único ponto de log do plugin.
    # Acesso: Ornato::Core.logger
    def self.logger
      @logger ||= Logger.new(level: :info)
    end
  end
end
