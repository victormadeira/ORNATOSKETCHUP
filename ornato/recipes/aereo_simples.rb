# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# recipes/aereo_simples.rb — Receita: Aéreo Simples
#
# Armário aéreo de cozinha/lavanderia:
#   - 2 laterais + base + topo
#   - 1 vão principal
#   - Fundo encaixado
#   - Sem rodapé (base_type: :direto)
#   - Altura padrão menor (700mm)
#   - Profundidade padrão menor (330mm)

module Ornato
  module Recipes
    class AereoSimples < RecipeBase
      def module_type; :aereo; end
      def name; 'Aéreo Simples'; end
      def description; 'Armário aéreo de cozinha ou lavanderia'; end
      def version; 1; end

      def parameters
        super.merge(
          height_mm: { default: 700.0, min: 300.0, max: 1500.0, type: Float },
          depth_mm:  { default: 330.0, min: 200.0, max: 600.0, type: Float }
        )
      end

      protected

      def create_module(params, ruleset)
        mod = super
        mod.base_type = :direto
        mod.base_height_mm = 0.0
        mod
      end

      def build_structural_parts(mod, params, ruleset)
        make_lateral(mod, :left, params, ruleset)
        make_lateral(mod, :right, params, ruleset)
        make_horizontal(mod, :base, params, ruleset)
        make_horizontal(mod, :topo, params, ruleset)
        make_back_panel(mod) unless mod.back_type == :nenhum
      end

      def build_openings(mod, params, ruleset)
        make_root_opening(mod)
      end

      def apply_default_aggregates(mod, params, ruleset)
        # Aéreos tipicamente têm porta de abrir
        opening = mod.openings.first
        return unless opening

        door = Domain::Aggregate.new(
          module_id: mod.ornato_id,
          opening_id: opening.ornato_id,
          aggregate_type: :porta_abrir,
          subtype: :lisa,
          overlap: :total,
          material_id: mod.front_material_id,
          thickness_nominal: ruleset.rule(:front, :thickness, fallback: 18)
        )
        opening.aggregates << door
      end
    end
  end
end
