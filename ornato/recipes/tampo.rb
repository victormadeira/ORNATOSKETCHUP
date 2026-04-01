# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# recipes/tampo.rb — Receita: Tampo
#
# Tampo de bancada, mesa ou balcao:
#   - Peca unica sem estrutura caixa
#   - Fita de borda na frente (e opcionalmente nas laterais)
#   - Pode ter furacao para fixacao por baixo
#   - Espessura padrao: 25mm (tampos mais robustos)
#
# Parametros extras:
#   - edge_front_only: se aplica fita apenas na frente (default: true)
#   - add_mounting_holes: se adiciona furacao de fixacao (default: false)

module Ornato
  module Recipes
    class Tampo < RecipeBase
      def module_type; :tampo; end
      def name; 'Tampo'; end
      def description; 'Tampo de bancada, mesa ou balcao'; end
      def version; 1; end

      def parameters
        super.merge(
          width_mm:  { default: 1200.0, min: 300.0, max: 4000.0, type: Float },
          height_mm: { default: 25.0,   min: 15.0,  max: 50.0,   type: Float },
          depth_mm:  { default: 600.0,  min: 200.0, max: 1200.0, type: Float },
          body_thickness: { default: 25, min: 15, max: 50, type: Integer }
        )
      end

      def extra_parameters
        {
          edge_front_only:    { default: true, type: nil },
          add_mounting_holes: { default: false, type: nil }
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
          code: 'CM_TAM', name: 'Tampo',
          length: params[:width_mm], width: params[:depth_mm],
          thickness: params[:body_thickness], grain: :length
        )

        # Fita de borda — tampo usa fita mais grossa (45mm x 2mm)
        edge_spec = Domain::EdgeSpec.standard(nil, width: 45.0, thickness: 2.0)
        part.edges[:top] = edge_spec

        unless params[:edge_front_only]
          part.edges[:left] = edge_spec
          part.edges[:right] = edge_spec
        end
      end

      def build_openings(mod, params, ruleset)
        # Tampo nao tem vaos
      end

      def apply_engineering_rules(mod, params, ruleset)
        # Sem sistema 32, sem canal de fundo
        if params[:add_mounting_holes]
          add_mounting_operations(mod, params)
        end
      end

      private

      def add_mounting_operations(mod, params)
        part = mod.parts.first
        return unless part

        # Furos de fixacao por baixo: 4 cantos + intervalos
        setback = 50.0
        positions = [
          { x: setback, y: setback },
          { x: part.length_mm - setback, y: setback },
          { x: setback, y: part.width_mm - setback },
          { x: part.length_mm - setback, y: part.width_mm - setback }
        ]

        # Furos intermediarios a cada ~500mm
        n_intermediate = [(part.length_mm / 500.0).floor - 1, 0].max
        n_intermediate.times do |i|
          x = setback + ((i + 1) * (part.length_mm - 2 * setback) / (n_intermediate + 1))
          positions << { x: x, y: setback }
          positions << { x: x, y: part.width_mm - setback }
        end

        positions.each_with_index do |pos, idx|
          op = Domain::Operation.new(
            parent_part_id: part.ornato_id,
            operation_type: :furacao,
            face: :bottom,
            x_mm: pos[:x],
            y_mm: pos[:y],
            depth_mm: 12.0,
            tool_diameter_mm: 5.0,
            tool_id: 'f_5mm',
            description: "Fixacao #{idx + 1}"
          )
          part.operation_ids << op.ornato_id
          mod.operations << op
        end
      end
    end
  end
end
