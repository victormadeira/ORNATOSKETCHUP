# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# recipes/gaveteiro.rb — Receita: Gaveteiro
#
# Módulo com gavetas empilhadas:
#   - 2 laterais + base + topo
#   - Fundo encaixado
#   - N vãos horizontais divididos igualmente
#   - Cada vão recebe uma gaveta
#
# Parâmetros extras:
#   - drawer_count: número de gavetas (2-8)
#   - slide_type: tipo de corrediça (:telescopica, :oculta, :tandembox, :roller)
#   - front_heights: array opcional de alturas customizadas (mm) para cada frente

module Ornato
  module Recipes
    class Gaveteiro < RecipeBase
      def module_type; :gaveteiro; end
      def name; 'Gaveteiro'; end
      def description; 'Módulo com gavetas empilhadas'; end
      def version; 1; end

      def extra_parameters
        {
          drawer_count: { default: 4, min: 2, max: 8, type: Integer },
          slide_type:   { default: :telescopica, type: Symbol },
          front_heights: { default: nil, type: Array }
        }
      end

      protected

      def build_structural_parts(mod, params, ruleset)
        make_lateral(mod, :left, params, ruleset)
        make_lateral(mod, :right, params, ruleset)
        make_horizontal(mod, :base, params, ruleset)
        make_horizontal(mod, :topo, params, ruleset)
        make_back_panel(mod) unless mod.back_type == :nenhum
      end

      def build_openings(mod, params, ruleset)
        root = make_root_opening(mod)
        count = params[:drawer_count] || 4

        if count > 1
          # Dividir vão principal horizontalmente em N partes iguais
          remaining = root
          (count - 1).times do |i|
            height_each = remaining.height_mm / (count - i)
            top, remaining = remaining.divide_horizontal(height_each)
            top.name = "Vão Gaveta #{i + 1}"
          end
          remaining.name = "Vão Gaveta #{count}"
        else
          root.name = 'Vão Gaveta 1'
        end
      end

      def apply_default_aggregates(mod, params, ruleset)
        slide_type = params[:slide_type] || :telescopica
        front_heights = params[:front_heights]

        # Percorre todos os vãos folha e adiciona gaveta
        leaf_openings = collect_leaf_openings(mod)
        leaf_openings.each_with_index do |opening, idx|
          gaveta = Domain::Aggregate.new(
            module_id: mod.ornato_id,
            opening_id: opening.ornato_id,
            aggregate_type: :gaveta,
            material_id: mod.front_material_id,
            thickness_nominal: ruleset.rule(:front, :thickness, fallback: 18),
            properties: { slide_type: slide_type }
          )

          if front_heights && front_heights[idx]
            gaveta.height_mm = front_heights[idx].to_f
          end

          opening.aggregates << gaveta
        end
      end

      private

      def collect_leaf_openings(mod)
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
