# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# components/module_updater.rb — Atualização de módulos via patches
#
# O ModuleUpdater é a interface de alto nível para modificar módulos.
# Recebe comandos do UI (StateBridge) e traduz em patches para o
# RebuildOrchestrator.
#
# Responsabilidades:
#   - Traduzir ações do usuário em patches tipados
#   - Determinar o scope correto de rebuild
#   - Coordenar com a geometria SketchUp

module Ornato
  module Components
    class ModuleUpdater
      def initialize
        @orchestrator = RebuildOrchestrator.new
      end

      # ── Ações de módulo ───────────────────────────────────────────

      # Atualiza dimensões do módulo.
      # @param mod [Domain::ModEntity]
      # @param width: [Float, nil], height: [Float, nil], depth: [Float, nil]
      # @param ruleset [Domain::Ruleset]
      # @return [RebuildOrchestrator::RebuildResult]
      def resize(mod, ruleset, width: nil, height: nil, depth: nil)
        patches = []

        if width && width != mod.width_mm
          patches << RebuildOrchestrator.update_patch(
            target: :module, target_id: mod.ornato_id,
            field: :width_mm, value: width.to_f
          )
        end

        if height && height != mod.height_mm
          patches << RebuildOrchestrator.update_patch(
            target: :module, target_id: mod.ornato_id,
            field: :height_mm, value: height.to_f
          )
        end

        if depth && depth != mod.depth_mm
          patches << RebuildOrchestrator.update_patch(
            target: :module, target_id: mod.ornato_id,
            field: :depth_mm, value: depth.to_f
          )
        end

        return empty_result(mod) if patches.empty?

        @orchestrator.rebuild(mod, patches, ruleset, scope: :full)
      end

      # Altera material do corpo.
      # @param mod [Domain::ModEntity]
      # @param material_id [String]
      # @param ruleset [Domain::Ruleset]
      # @return [RebuildOrchestrator::RebuildResult]
      def change_body_material(mod, material_id, ruleset)
        patches = [
          RebuildOrchestrator.update_patch(
            target: :module, target_id: mod.ornato_id,
            field: :body_material_id, value: material_id
          )
        ]
        @orchestrator.rebuild(mod, patches, ruleset, scope: :full)
      end

      # Altera material da frente.
      def change_front_material(mod, material_id, ruleset)
        patches = [
          RebuildOrchestrator.update_patch(
            target: :module, target_id: mod.ornato_id,
            field: :front_material_id, value: material_id
          )
        ]
        @orchestrator.rebuild(mod, patches, ruleset, scope: :partial_aggregate)
      end

      # Altera espessura do corpo.
      def change_body_thickness(mod, thickness, ruleset)
        patches = [
          RebuildOrchestrator.update_patch(
            target: :module, target_id: mod.ornato_id,
            field: :body_thickness, value: thickness.to_i
          )
        ]
        @orchestrator.rebuild(mod, patches, ruleset, scope: :full)
      end

      # Altera tipo de montagem.
      def change_assembly_type(mod, assembly_type, ruleset)
        patches = [
          RebuildOrchestrator.update_patch(
            target: :module, target_id: mod.ornato_id,
            field: :assembly_type, value: assembly_type.to_sym
          )
        ]
        @orchestrator.rebuild(mod, patches, ruleset, scope: :full)
      end

      # Altera tipo de fundo.
      def change_back_type(mod, back_type, ruleset)
        patches = [
          RebuildOrchestrator.update_patch(
            target: :module, target_id: mod.ornato_id,
            field: :back_type, value: back_type.to_sym
          )
        ]
        @orchestrator.rebuild(mod, patches, ruleset, scope: :full)
      end

      # ── Ações de agregados ────────────────────────────────────────

      # Adiciona agregado a um vão.
      # @param mod [Domain::ModEntity]
      # @param opening_id [String] ornato_id do vão
      # @param aggregate [Domain::Aggregate] agregado a adicionar
      # @param ruleset [Domain::Ruleset]
      # @return [RebuildOrchestrator::RebuildResult]
      def add_aggregate(mod, opening_id, aggregate, ruleset)
        patches = [
          RebuildOrchestrator.add_patch(
            target: :aggregate, target_id: opening_id,
            value: aggregate
          )
        ]
        @orchestrator.rebuild(mod, patches, ruleset, scope: :partial_aggregate)
      end

      # Remove agregado de um vão.
      def remove_aggregate(mod, aggregate_id, ruleset)
        patches = [
          RebuildOrchestrator.remove_patch(
            target: :aggregate, target_id: aggregate_id
          )
        ]
        @orchestrator.rebuild(mod, patches, ruleset, scope: :partial_aggregate)
      end

      # Atualiza propriedade de um agregado.
      def update_aggregate(mod, aggregate_id, field, value, ruleset)
        patches = [
          RebuildOrchestrator.update_patch(
            target: :aggregate, target_id: aggregate_id,
            field: field, value: value
          )
        ]
        @orchestrator.rebuild(mod, patches, ruleset, scope: :partial_aggregate)
      end

      # ── Ações de vão ──────────────────────────────────────────────

      # Divide vão horizontalmente (cria prateleira).
      def divide_horizontal(mod, opening_id, height_mm, ruleset)
        opening = mod.find_opening(opening_id)
        return empty_result(mod) unless opening

        top, _bottom = opening.divide_horizontal(height_mm)

        # Adiciona prateleira fixa no ponto de divisão
        shelf = Domain::Aggregate.new(
          name: 'Prateleira Fixa',
          aggregate_type: :prateleira_fixa
        )
        shelf.material_id = mod.body_material_id
        shelf.thickness = mod.body_thickness

        patches = [
          RebuildOrchestrator.add_patch(
            target: :aggregate, target_id: top.ornato_id,
            value: shelf
          )
        ]
        @orchestrator.rebuild(mod, patches, ruleset, scope: :partial_aggregate)
      end

      # Divide vão verticalmente (cria divisória).
      def divide_vertical(mod, opening_id, width_mm, ruleset)
        opening = mod.find_opening(opening_id)
        return empty_result(mod) unless opening

        left, _right = opening.divide_vertical(width_mm)

        # Adiciona divisória no ponto de divisão
        divider = Domain::Aggregate.new(
          name: 'Divisória',
          aggregate_type: :divisoria_vertical
        )
        divider.material_id = mod.body_material_id
        divider.thickness = mod.body_thickness

        patches = [
          RebuildOrchestrator.add_patch(
            target: :aggregate, target_id: left.ornato_id,
            value: divider
          )
        ]
        @orchestrator.rebuild(mod, patches, ruleset, scope: :partial_aggregate)
      end

      # ── Batch ─────────────────────────────────────────────────────

      # Aplica múltiplas mudanças de uma vez (batch).
      # @param mod [Domain::ModEntity]
      # @param patches [Array<RebuildOrchestrator::Patch>]
      # @param ruleset [Domain::Ruleset]
      # @param scope [Symbol]
      # @return [RebuildOrchestrator::RebuildResult]
      def apply_patches(mod, patches, ruleset, scope: :full)
        @orchestrator.rebuild(mod, patches, ruleset, scope: scope)
      end

      private

      def empty_result(mod)
        RebuildOrchestrator::RebuildResult.new(
          success: true,
          module_entity: mod,
          patches_applied: [],
          errors: [],
          warnings: ['Nenhuma alteração aplicada'],
          duration_ms: 0.0
        )
      end
    end
  end
end
