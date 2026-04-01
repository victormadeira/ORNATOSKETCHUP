# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# components/aggregate_engine.rb — Motor de agregados com smart targeting
#
# O AggregateEngine gerencia a inteligência de posicionamento e
# compatibilidade de agregados nos vãos de um módulo.
#
# Smart Targeting:
#   - Validação de compatibilidade (ex: porta não cabe em vão muito pequeno)
#   - Regras de exclusão mútua (ex: porta + porta no mesmo vão)
#   - Cálculo de espaço disponível
#   - Sugestão de agregados compatíveis
#
# Cada tipo de agregado tem regras de:
#   - Dimensões mínimas/máximas
#   - Incompatibilidades com outros tipos
#   - Ocupação de altura (prateleiras vs. portas)

module Ornato
  module Components
    class AggregateEngine
      # Regras de compatibilidade por tipo de agregado.
      COMPATIBILITY_RULES = {
        porta_abrir: {
          min_width: 200.0, max_width: 900.0,
          min_height: 200.0, max_height: 2400.0,
          conflicts_with: [:porta_correr, :porta_basculante],
          occupies_full_height: true
        },
        porta_basculante: {
          min_width: 300.0, max_width: 1200.0,
          min_height: 200.0, max_height: 600.0,
          conflicts_with: [:porta_abrir, :porta_correr],
          occupies_full_height: true
        },
        porta_correr: {
          min_width: 600.0, max_width: 4000.0,
          min_height: 300.0, max_height: 2700.0,
          conflicts_with: [:porta_abrir, :porta_basculante],
          occupies_full_height: true
        },
        gaveta: {
          min_width: 250.0, max_width: 1200.0,
          min_height: 80.0, max_height: 400.0,
          conflicts_with: [:gavetao, :porta_abrir, :porta_correr],
          occupies_full_height: true
        },
        gavetao: {
          min_width: 250.0, max_width: 1200.0,
          min_height: 200.0, max_height: 600.0,
          conflicts_with: [:gaveta, :porta_abrir, :porta_correr],
          occupies_full_height: true
        },
        prateleira_fixa: {
          min_width: 150.0, max_width: 2000.0,
          min_height: 0.0, max_height: 0.0,
          conflicts_with: [],
          occupies_full_height: false
        },
        prateleira_regulavel: {
          min_width: 150.0, max_width: 2000.0,
          min_height: 0.0, max_height: 0.0,
          conflicts_with: [],
          occupies_full_height: false
        },
        divisoria_vertical: {
          min_width: 0.0, max_width: 0.0,
          min_height: 150.0, max_height: 3000.0,
          conflicts_with: [],
          occupies_full_height: false
        },
        fundo: {
          min_width: 100.0, max_width: 6000.0,
          min_height: 100.0, max_height: 3000.0,
          conflicts_with: [],
          occupies_full_height: false
        }
      }.freeze

      # Valida se um agregado pode ser adicionado a um vão.
      #
      # @param aggregate_type [Symbol] tipo do agregado
      # @param opening [Domain::Opening] vão alvo
      # @return [Hash] { valid: Boolean, errors: [], warnings: [] }
      def validate_placement(aggregate_type, opening)
        errors = []
        warnings = []
        rules = COMPATIBILITY_RULES[aggregate_type]

        unless rules
          return { valid: true, errors: [], warnings: ["Sem regras definidas para #{aggregate_type}"] }
        end

        # Verificar dimensões mínimas
        if rules[:min_width] > 0 && opening.width_mm < rules[:min_width]
          errors << "Largura do vão (#{opening.width_mm}mm) menor que mínimo para #{aggregate_type} (#{rules[:min_width]}mm)"
        end

        if rules[:min_height] > 0 && opening.height_mm < rules[:min_height]
          errors << "Altura do vão (#{opening.height_mm}mm) menor que mínimo para #{aggregate_type} (#{rules[:min_height]}mm)"
        end

        # Verificar dimensões máximas
        if rules[:max_width] > 0 && opening.width_mm > rules[:max_width]
          warnings << "Largura do vão (#{opening.width_mm}mm) maior que máximo recomendado para #{aggregate_type} (#{rules[:max_width]}mm)"
        end

        if rules[:max_height] > 0 && opening.height_mm > rules[:max_height]
          warnings << "Altura do vão (#{opening.height_mm}mm) maior que máximo recomendado para #{aggregate_type} (#{rules[:max_height]}mm)"
        end

        # Verificar conflitos com agregados existentes
        existing_types = opening.aggregates.map(&:aggregate_type)
        conflicts = rules[:conflicts_with] & existing_types
        if conflicts.any?
          errors << "#{aggregate_type} conflita com #{conflicts.join(', ')} já existente(s) no vão"
        end

        # Verificar ocupação de altura se o vão já tem agregado que ocupa toda a altura
        if rules[:occupies_full_height]
          existing_full = opening.aggregates.select do |a|
            r = COMPATIBILITY_RULES[a.aggregate_type]
            r && r[:occupies_full_height]
          end
          if existing_full.any?
            errors << "Vão já tem #{existing_full.first.aggregate_type} que ocupa toda a altura"
          end
        end

        { valid: errors.empty?, errors: errors, warnings: warnings }
      end

      # Sugere agregados compatíveis com um vão.
      #
      # @param opening [Domain::Opening] vão alvo
      # @return [Array<Symbol>] tipos de agregados compatíveis
      def suggest_aggregates(opening)
        compatible = []

        COMPATIBILITY_RULES.each do |type, rules|
          result = validate_placement(type, opening)
          compatible << type if result[:valid]
        end

        compatible
      end

      # Calcula espaço livre em um vão após considerar agregados existentes.
      #
      # @param opening [Domain::Opening] vão
      # @return [Hash] { free_width_mm: Float, free_height_mm: Float, occupied_height_mm: Float }
      def calculate_free_space(opening)
        occupied_height = 0.0

        opening.aggregates.each do |agg|
          if agg.respond_to?(:occupies_height?) && agg.occupies_height?
            occupied_height += agg.respond_to?(:occupied_height_mm) ? agg.occupied_height_mm : opening.height_mm
          end
        end

        {
          free_width_mm: opening.width_mm,
          free_height_mm: [opening.height_mm - occupied_height, 0.0].max,
          occupied_height_mm: occupied_height
        }
      end

      # Avalia a completude dos agregados de um módulo.
      # Retorna sugestões de preenchimento.
      #
      # @param mod [Domain::ModEntity]
      # @return [Array<Hash>] sugestões { opening_id:, opening_name:, suggestions: [] }
      def evaluate_completeness(mod)
        suggestions = []

        all_leaves = collect_all_leaves(mod)
        all_leaves.each do |opening|
          if opening.aggregates.empty?
            compatible = suggest_aggregates(opening)
            unless compatible.empty?
              suggestions << {
                opening_id: opening.ornato_id,
                opening_name: opening.name,
                status: :empty,
                suggestions: compatible
              }
            end
          end
        end

        suggestions
      end

      # Conta agregados por tipo em um módulo.
      #
      # @param mod [Domain::ModEntity]
      # @return [Hash<Symbol, Integer>]
      def aggregate_counts(mod)
        counts = Hash.new(0)
        mod.all_aggregates.each { |a| counts[a.aggregate_type] += 1 }
        counts
      end

      private

      def collect_all_leaves(mod)
        leaves = []
        mod.openings.each { |o| collect_leaves(o, leaves) }
        leaves
      end

      def collect_leaves(opening, leaves)
        if opening.leaf?
          leaves << opening
        else
          opening.sub_openings.each { |sub| collect_leaves(sub, leaves) }
        end
      end
    end
  end
end
