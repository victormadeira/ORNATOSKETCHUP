# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# recipes/canto.rb — Receita: Modulo de Canto
#
# Modulo de canto (L) para juncao entre dois alinhamentos:
#   - 2 laterais (uma para cada alinhamento)
#   - Base + topo com recorte em L
#   - Fundo em L
#   - Vao interno em L (acessado pela frente diagonal ou giratoria)
#
# Parametros extras:
#   - wing_a_mm: comprimento do braco A (default: 600mm)
#   - wing_b_mm: comprimento do braco B (default: 600mm)
#   - corner_type: :reto (90) ou :diagonal (45)

module Ornato
  module Recipes
    class Canto < RecipeBase
      def module_type; :canto; end
      def name; 'Modulo de Canto'; end
      def description; 'Modulo de canto (L) para juncao entre alinhamentos'; end
      def version; 1; end

      def parameters
        super.merge(
          width_mm:  { default: 900.0,  min: 600.0, max: 1200.0, type: Float },
          depth_mm:  { default: 560.0,  min: 400.0, max: 800.0,  type: Float }
        )
      end

      def extra_parameters
        {
          wing_a_mm:   { default: 600.0, min: 300.0, max: 900.0, type: Float },
          wing_b_mm:   { default: 600.0, min: 300.0, max: 900.0, type: Float },
          corner_type: { default: :reto, type: Symbol }
        }
      end

      protected

      def build_structural_parts(mod, params, ruleset)
        wing_a = params[:wing_a_mm] || 600.0
        wing_b = params[:wing_b_mm] || 600.0
        bt = Core::Config.real_thickness(mod.body_thickness)

        # Lateral A (braco A)
        make_lateral(mod, :left, params, ruleset)

        # Lateral B (braco B)
        make_lateral(mod, :right, params, ruleset)

        # Base — peca em L composta por 2 sub-pecas
        make_structural_part(mod,
          code: 'CM_BAS', name: 'Base Braco A',
          length: wing_a, width: mod.depth_mm,
          thickness: mod.body_thickness, grain: :width
        )
        make_structural_part(mod,
          code: 'CM_BAS', name: 'Base Braco B',
          length: wing_b - bt, width: mod.depth_mm,
          thickness: mod.body_thickness, grain: :width
        )

        # Topo — mesmo esquema
        make_structural_part(mod,
          code: 'CM_REG', name: 'Topo Braco A',
          length: wing_a, width: mod.depth_mm,
          thickness: mod.body_thickness, grain: :width
        )
        make_structural_part(mod,
          code: 'CM_REG', name: 'Topo Braco B',
          length: wing_b - bt, width: mod.depth_mm,
          thickness: mod.body_thickness, grain: :width
        )

        # Fundo
        make_back_panel(mod) unless mod.back_type == :nenhum
      end

      def build_openings(mod, params, ruleset)
        # Modulo de canto tem vao unico em L
        # Representado como 2 vaos conectados
        wing_a = params[:wing_a_mm] || 600.0
        wing_b = params[:wing_b_mm] || 600.0
        bt = Core::Config.real_thickness(mod.body_thickness)

        real_body = Core::Config.real_thickness(mod.body_thickness)

        opening_a = Domain::Opening.new(
          parent_id: mod.ornato_id,
          x_mm: real_body,
          y_mm: real_body,
          z_mm: 0.0,
          width_mm: wing_a - (2 * bt),
          height_mm: mod.internal_height_mm,
          depth_mm: mod.internal_depth_mm
        )
        mod.openings << opening_a

        opening_b = Domain::Opening.new(
          parent_id: mod.ornato_id,
          x_mm: wing_a,
          y_mm: real_body,
          z_mm: 0.0,
          width_mm: wing_b - (2 * bt),
          height_mm: mod.internal_height_mm,
          depth_mm: mod.internal_depth_mm
        )
        mod.openings << opening_b
      end

      def apply_default_aggregates(mod, params, ruleset)
        # Canto tipicamente usa prateleira giratoria — apenas prateleiras fixas aqui
        mod.openings.each do |opening|
          prat = Domain::Aggregate.new(
            module_id: mod.ornato_id,
            opening_id: opening.ornato_id,
            aggregate_type: :prateleira_fixa,
            material_id: mod.body_material_id,
            thickness_nominal: mod.body_thickness
          )
          opening.aggregates << prat
        end
      end
    end
  end
end
