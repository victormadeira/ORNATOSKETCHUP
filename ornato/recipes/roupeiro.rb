# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# recipes/roupeiro.rb — Receita: Roupeiro / Guarda-Roupa
#
# Roupeiro / armario de quarto ou closet:
#   - 2 laterais + base + topo
#   - Altura padrao: 2100mm (piso ao teto)
#   - Profundidade padrao: 600mm (cabides)
#   - Vao principal dividido verticalmente (1, 2 ou 3 compartimentos)
#   - Cada compartimento pode ter porta, gavetas, prateleiras
#
# Parametros extras:
#   - compartments: numero de divisoes verticais (1-4)
#   - compartment_widths: array de larguras (mm) — se nil, divide igualmente

module Ornato
  module Recipes
    class Roupeiro < RecipeBase
      def module_type; :roupeiro; end
      def name; 'Roupeiro'; end
      def description; 'Guarda-roupa com compartimentos verticais'; end
      def version; 1; end

      def parameters
        super.merge(
          width_mm:  { default: 1800.0, min: 600.0, max: 4000.0, type: Float },
          height_mm: { default: 2100.0, min: 1500.0, max: 2700.0, type: Float },
          depth_mm:  { default: 600.0,  min: 400.0, max: 800.0,  type: Float }
        )
      end

      def extra_parameters
        {
          compartments:      { default: 2,   min: 1, max: 4, type: Integer },
          compartment_widths: { default: nil, type: Array }
        }
      end

      protected

      def build_structural_parts(mod, params, ruleset)
        make_lateral(mod, :left, params, ruleset)
        make_lateral(mod, :right, params, ruleset)
        make_horizontal(mod, :base, params, ruleset)
        make_horizontal(mod, :topo, params, ruleset)
        make_back_panel(mod) unless mod.back_type == :nenhum

        # Divisorias verticais entre compartimentos
        n_compartments = params[:compartments] || 2
        if n_compartments > 1
          (n_compartments - 1).times do |i|
            make_structural_part(mod,
              code: 'CM_DIV', name: "Divisoria #{i + 1}",
              length: mod.internal_height_mm,
              width: mod.depth_mm,
              thickness: mod.body_thickness, grain: :length
            )
          end
        end
      end

      def build_openings(mod, params, ruleset)
        root = make_root_opening(mod)
        n_compartments = params[:compartments] || 2
        custom_widths = params[:compartment_widths]

        if n_compartments > 1
          remaining = root
          (n_compartments - 1).times do |i|
            if custom_widths && custom_widths[i]
              w = custom_widths[i].to_f
            else
              w = remaining.width_mm / (n_compartments - i)
            end

            left_opening, remaining = remaining.divide_vertical(w)
            left_opening.name = "Compartimento #{i + 1}"
          end
          remaining.name = "Compartimento #{n_compartments}"
        else
          root.name = 'Compartimento 1'
        end
      end

      def apply_default_aggregates(mod, params, ruleset)
        # Cada compartimento recebe porta e 2 prateleiras regulaveis
        mod.openings.each do |op|
          add_aggregates_to_leaves(op, mod, ruleset)
        end
      end

      private

      def add_aggregates_to_leaves(opening, mod, ruleset)
        if opening.leaf?
          # Porta
          porta = Domain::Aggregate.new(
            module_id: mod.ornato_id,
            opening_id: opening.ornato_id,
            aggregate_type: :porta_abrir,
            subtype: :lisa,
            overlap: :meia,
            material_id: mod.front_material_id,
            thickness_nominal: ruleset.rule(:front, :thickness, fallback: 18)
          )
          opening.aggregates << porta

          # 2 prateleiras regulaveis
          2.times do |i|
            prat = Domain::Aggregate.new(
              module_id: mod.ornato_id,
              opening_id: opening.ornato_id,
              aggregate_type: :prateleira_regulavel,
              material_id: mod.body_material_id,
              thickness_nominal: mod.body_thickness
            )
            opening.aggregates << prat
          end
        else
          opening.sub_openings.each { |sub| add_aggregates_to_leaves(sub, mod, ruleset) }
        end
      end
    end
  end
end
