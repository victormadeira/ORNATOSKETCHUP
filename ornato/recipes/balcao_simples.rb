# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# recipes/balcao_simples.rb — Receita: Balcão Simples
#
# Balcão de cozinha/banheiro com:
#   - 2 laterais + base + topo
#   - 1 vão principal
#   - Fundo encaixado (padrão)
#   - Rodapé recuado
#
# Parâmetros extras: nenhum (usa defaults da cozinha)

module Ornato
  module Recipes
    class BalcaoSimples < RecipeBase
      def module_type; :balcao; end
      def name; 'Balcão Simples'; end
      def description; 'Balcão de cozinha ou banheiro com vão único'; end
      def version; 1; end

      protected

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
    end
  end
end
