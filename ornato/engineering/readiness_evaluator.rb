# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# engineering/readiness_evaluator.rb — Avaliador de prontidão para produção
#
# Avalia se um módulo está pronto para exportação e produção.
# Combina validação, completude de agregados e compatibilidade CAM.

module Ornato
  module Engineering
    class ReadinessEvaluator
      def initialize
        @validator = Validator.new
        @aggregate_engine = Components::AggregateEngine.new
      end

      # Avalia prontidão completa de um módulo.
      # @param mod [Domain::ModEntity]
      # @param machine_profile [Domain::MachineProfile, nil]
      # @return [Hash] relatório completo
      def evaluate(mod, machine_profile: nil)
        validation = @validator.validate(mod, machine_profile: machine_profile)
        completeness = @aggregate_engine.evaluate_completeness(mod)
        cam_result = machine_profile ? machine_profile.evaluate_cam_readiness(mod, mod.operations) : nil

        ready = validation.valid? &&
                completeness.empty? &&
                (cam_result.nil? || cam_result[:eligible])

        {
          ready: ready,
          state: ready ? :ready_for_export : :needs_attention,
          validation: {
            valid: validation.valid?,
            blocking: validation.blocking_count,
            warnings: validation.warning_count,
            suggestions: validation.suggestion_count
          },
          completeness: {
            complete: completeness.empty?,
            empty_openings: completeness.length
          },
          cam: cam_result ? {
            eligible: cam_result[:eligible],
            errors: cam_result[:errors].length,
            warnings: cam_result[:warnings].length
          } : nil,
          summary: build_summary(mod, validation, completeness, cam_result)
        }
      end

      # Avaliação rápida (sem CAM).
      def quick_evaluate(mod)
        evaluate(mod, machine_profile: nil)
      end

      private

      def build_summary(mod, validation, completeness, cam_result)
        lines = []

        lines << "#{mod.name} (#{mod.module_type})"
        lines << "#{mod.parts.length} peças, #{mod.all_aggregates.length} agregados"
        lines << "Área: #{mod.total_area_m2.round(3)} m², Fita: #{mod.total_edgeband_meters.round(2)} m"

        if validation.valid?
          lines << 'Validação OK'
        else
          lines << "#{validation.blocking_count} erros bloqueantes"
        end

        if validation.warning_count > 0
          lines << "#{validation.warning_count} avisos"
        end

        if completeness.empty?
          lines << 'Todos os vãos preenchidos'
        else
          lines << "#{completeness.length} vãos vazios"
        end

        if cam_result
          if cam_result[:eligible]
            lines << 'CAM elegível'
          else
            lines << "CAM: #{cam_result[:errors].length} incompatibilidades"
          end
        end

        lines.join("\n")
      end
    end
  end
end
