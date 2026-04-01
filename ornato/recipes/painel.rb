# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# recipes/painel.rb — Receita: Painel
#
# Painel decorativo ou lateral de acabamento:
#   - Peca unica sem estrutura caixa
#   - Apenas 1 part (o painel em si)
#   - Fita de borda configuravel nos 4 lados
#   - Sem vaos, sem agregados
#
# Parametros extras:
#   - edge_all_sides: se aplica fita nos 4 lados (default: false)

module Ornato
  module Recipes
    class Painel < RecipeBase
      def module_type; :painel; end
      def name; 'Painel'; end
      def description; 'Painel decorativo ou lateral de acabamento'; end
      def version; 1; end

      def parameters
        super.merge(
          width_mm:  { default: 600.0,  min: 100.0, max: 3000.0, type: Float },
          height_mm: { default: 2100.0, min: 100.0, max: 3000.0, type: Float },
          depth_mm:  { default: 18.0,   min: 6.0,   max: 50.0,   type: Float }
        )
      end

      def extra_parameters
        {
          edge_all_sides: { default: false, type: nil }
        }
      end

      protected

      def create_module(params, ruleset)
        mod = super
        mod.base_type = :direto
        mod.base_height_mm = 0.0
        mod.back_type = :nenhum
        mod
      end

      def build_structural_parts(mod, params, ruleset)
        part = make_structural_part(mod,
          code: 'CM_PNL', name: 'Painel',
          length: params[:height_mm], width: params[:width_mm],
          thickness: params[:body_thickness], grain: :length
        )

        # Fita de borda
        edge_spec = Domain::EdgeSpec.standard(nil, width: 22.0, thickness: 1.0)

        part.edges[:top] = edge_spec
        if params[:edge_all_sides]
          part.edges[:bottom] = edge_spec
          part.edges[:left] = edge_spec
          part.edges[:right] = edge_spec
        end
      end

      def build_openings(mod, params, ruleset)
        # Painel nao tem vaos
      end

      # Sem sistema 32, sem canal de fundo
      def apply_engineering_rules(mod, params, ruleset)
        # Noop — painel e peca unica sem usinagem
      end
    end
  end
end
