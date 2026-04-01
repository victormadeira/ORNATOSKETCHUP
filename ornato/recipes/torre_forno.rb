# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# recipes/torre_forno.rb — Receita: Torre de Forno
#
# Torre alta com vão para forno/micro-ondas embutido:
#   - 2 laterais + base + topo
#   - Vão do forno (sem porta)
#   - Vãos superior e inferior para armários/gavetas
#   - Altura padrão: 2100mm (torre)
#   - Profundidade padrão: 600mm
#
# Parâmetros extras:
#   - oven_height_mm: altura do nicho do forno (padrão 600mm)
#   - oven_position_mm: altura da base do nicho do forno (padrão 800mm)
#   - upper_doors: se coloca porta no vão superior (default: true)
#   - lower_doors: se coloca porta/gavetas no vão inferior (default: true)

module Ornato
  module Recipes
    class TorreForno < RecipeBase
      def module_type; :torre; end
      def name; 'Torre de Forno'; end
      def description; 'Torre alta com nicho para forno ou micro-ondas embutido'; end
      def version; 1; end

      def parameters
        super.merge(
          width_mm:  { default: 600.0,  min: 500.0, max: 900.0,  type: Float },
          height_mm: { default: 2100.0, min: 1800.0, max: 2700.0, type: Float },
          depth_mm:  { default: 600.0,  min: 400.0, max: 800.0,  type: Float }
        )
      end

      def extra_parameters
        {
          oven_height_mm:   { default: 600.0,  min: 400.0, max: 900.0, type: Float },
          oven_position_mm: { default: 800.0,  min: 400.0, max: 1400.0, type: Float },
          upper_doors:      { default: true, type: nil },
          lower_doors:      { default: true, type: nil }
        }
      end

      protected

      def build_structural_parts(mod, params, ruleset)
        make_lateral(mod, :left, params, ruleset)
        make_lateral(mod, :right, params, ruleset)
        make_horizontal(mod, :base, params, ruleset)
        make_horizontal(mod, :topo, params, ruleset)
        make_back_panel(mod) unless mod.back_type == :nenhum

        # Prateleira fixa abaixo do forno
        make_structural_part(mod,
          code: 'CM_PRA_FIX', name: 'Base do Forno',
          length: mod.internal_width_mm,
          width: mod.depth_mm,
          thickness: mod.body_thickness, grain: :width
        )

        # Prateleira fixa acima do forno
        make_structural_part(mod,
          code: 'CM_PRA_FIX', name: 'Topo do Forno',
          length: mod.internal_width_mm,
          width: mod.depth_mm,
          thickness: mod.body_thickness, grain: :width
        )
      end

      def build_openings(mod, params, ruleset)
        root = make_root_opening(mod)
        oven_pos = params[:oven_position_mm] || 800.0
        oven_height = params[:oven_height_mm] || 600.0

        internal_h = mod.internal_height_mm
        base_offset = mod.base_type == :rodape ? mod.base_height_mm : 0.0

        # Altura relativa ao vão interno
        lower_h = oven_pos - base_offset - Core::Config.real_thickness(mod.body_thickness)
        upper_h = internal_h - lower_h - oven_height - (2 * Core::Config.real_thickness(mod.body_thickness))

        # Dividir: inferior, forno, superior
        if lower_h > 0 && upper_h > 0
          lower, remaining = root.divide_horizontal(lower_h)
          lower.name = 'Vão Inferior'

          oven, upper = remaining.divide_horizontal(oven_height)
          oven.name = 'Nicho Forno'
          upper.name = 'Vão Superior'
        elsif lower_h > 0
          lower, oven = root.divide_horizontal(lower_h)
          lower.name = 'Vão Inferior'
          oven.name = 'Nicho Forno'
        else
          root.name = 'Nicho Forno'
        end
      end

      def apply_default_aggregates(mod, params, ruleset)
        mod.openings.each do |op|
          apply_to_leaves(op, params, ruleset, mod)
        end
      end

      private

      def apply_to_leaves(opening, params, ruleset, mod)
        if opening.leaf?
          case opening.name
          when /Inferior/
            if params[:lower_doors]
              porta = Domain::Aggregate.new(
                module_id: mod.ornato_id,
                opening_id: opening.ornato_id,
                aggregate_type: :porta_abrir,
                subtype: :lisa,
                overlap: :total,
                material_id: mod.front_material_id,
                thickness_nominal: ruleset.rule(:front, :thickness, fallback: 18)
              )
              opening.aggregates << porta
            end
          when /Superior/
            if params[:upper_doors]
              porta = Domain::Aggregate.new(
                module_id: mod.ornato_id,
                opening_id: opening.ornato_id,
                aggregate_type: :porta_abrir,
                subtype: :lisa,
                overlap: :total,
                material_id: mod.front_material_id,
                thickness_nominal: ruleset.rule(:front, :thickness, fallback: 18)
              )
              opening.aggregates << porta
            end
          # Nicho do forno: não adiciona porta
          end
        else
          opening.sub_openings.each { |sub| apply_to_leaves(sub, params, ruleset, mod) }
        end
      end
    end
  end
end
