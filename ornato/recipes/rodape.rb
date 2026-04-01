# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# recipes/rodape.rb — Receita: Rodape
#
# Rodape / saia do modulo:
#   - Peca unica linear
#   - Fita de borda na face superior e frontal
#   - Sem vaos, sem agregados
#   - Espessura padrao: 18mm
#   - Altura padrao: 100mm (recuo: 50mm)
#
# Parametros extras:
#   - recuo_mm: recuo do rodape em relacao a frente (default: 50mm)

module Ornato
  module Recipes
    class Rodape < RecipeBase
      def module_type; :rodape; end
      def name; 'Rodape'; end
      def description; 'Rodape / saia de modulo'; end
      def version; 1; end

      def parameters
        super.merge(
          width_mm:  { default: 600.0,  min: 200.0, max: 6000.0, type: Float },
          height_mm: { default: 100.0,  min: 50.0,  max: 250.0,  type: Float },
          depth_mm:  { default: 18.0,   min: 9.0,   max: 25.0,   type: Float }
        )
      end

      def extra_parameters
        {
          recuo_mm: { default: 50.0, min: 20.0, max: 100.0, type: Float }
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
          code: 'CM_RDP', name: 'Rodape',
          length: params[:width_mm], width: params[:height_mm],
          thickness: params[:body_thickness], grain: :length
        )

        # Fita na frente (face visível)
        part.edges[:top] = Domain::EdgeSpec.standard(nil, width: 22.0, thickness: 1.0)
      end

      def build_openings(mod, params, ruleset)
        # Rodape nao tem vaos
      end

      def apply_engineering_rules(mod, params, ruleset)
        # Sem sistema 32, sem canal de fundo — peca simples
      end
    end
  end
end
