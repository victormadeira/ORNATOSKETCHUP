# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# recipes/nicho.rb — Receita: Nicho
#
# Nicho aberto (sem porta):
#   - 2 laterais + base + topo
#   - Fundo obrigatorio (encaixado ou sobreposto)
#   - Sem porta, sem gaveta
#   - Pode ter prateleiras regulaveis
#   - Sem rodape (direto na parede)
#
# Parametros extras:
#   - shelf_count: numero de prateleiras internas (0-6)

module Ornato
  module Recipes
    class Nicho < RecipeBase
      def module_type; :nicho; end
      def name; 'Nicho'; end
      def description; 'Nicho aberto sem porta, com prateleiras opcionais'; end
      def version; 1; end

      def parameters
        super.merge(
          width_mm:  { default: 400.0, min: 200.0, max: 1200.0, type: Float },
          height_mm: { default: 400.0, min: 200.0, max: 1200.0, type: Float },
          depth_mm:  { default: 300.0, min: 150.0, max: 600.0,  type: Float }
        )
      end

      def extra_parameters
        {
          shelf_count: { default: 1, min: 0, max: 6, type: Integer }
        }
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
        make_back_panel(mod)  # nicho sempre tem fundo
      end

      def build_openings(mod, params, ruleset)
        root = make_root_opening(mod)
        shelf_count = params[:shelf_count] || 1

        if shelf_count > 0
          remaining = root
          shelf_count.times do |i|
            h = remaining.height_mm / (shelf_count - i + 1)
            top_opening, remaining = remaining.divide_horizontal(h)
            top_opening.name = "Secao #{i + 1}"
          end
          remaining.name = "Secao #{shelf_count + 1}"
        else
          root.name = 'Vao Unico'
        end
      end

      def apply_default_aggregates(mod, params, ruleset)
        shelf_count = params[:shelf_count] || 1
        return if shelf_count == 0

        # Cada divisao de secao implica uma prateleira fixa
        mod.openings.each do |op|
          add_shelves_to_intermediate(op, mod, ruleset)
        end
      end

      private

      def add_shelves_to_intermediate(opening, mod, ruleset)
        # Prateleiras fixas nos pontos de divisao
        opening.sub_openings.each_with_index do |sub, idx|
          if idx > 0 || !opening.leaf?
            prat = Domain::Aggregate.new(
              module_id: mod.ornato_id,
              opening_id: sub.ornato_id,
              aggregate_type: :prateleira_fixa,
              material_id: mod.body_material_id,
              thickness_nominal: mod.body_thickness
            )
            sub.aggregates << prat
          end
          add_shelves_to_intermediate(sub, mod, ruleset)
        end
      end
    end
  end
end
