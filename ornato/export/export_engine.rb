# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# export/export_engine.rb — Motor de exportação JSON
#
# Exporta projeto completo no formato ornato.project.v1,
# compatível com UpMobb e plataformas de produção.
#
# Estrutura JSON:
#   {
#     schema: "ornato.project.v1",
#     exported_at: ISO8601,
#     project: { ... },
#     environments: [ ... ],
#     modules: [ ... ],
#     parts: [ ... ],
#     hardware: [ ... ],
#     operations: [ ... ],
#     catalog_snapshot: { ... },
#     hashes: { entity_id: hash, ... }
#   }

require 'json'
require 'digest'

module Ornato
  module Export
    class ExportEngine
      # Exporta projeto completo para JSON.
      #
      # @param project [Domain::Project] projeto a exportar
      # @param modules [Array<Domain::ModEntity>] módulos do projeto
      # @param catalog [Catalog::CatalogManager, nil] catálogo
      # @param options [Hash] opções de exportação
      # @return [Hash] dados exportados
      def export(project, modules, catalog: nil, **options)
        Core.logger.measure('ExportEngine.export') do
          Core.events.emit(:export_started, project_id: project.ornato_id)

          data = build_export_data(project, modules, catalog, options)

          Core.events.emit(
            :export_completed,
            project_id: project.ornato_id,
            export_id: data[:export_id]
          )

          data
        end
      end

      # Exporta para arquivo JSON.
      #
      # @param project [Domain::Project]
      # @param modules [Array<Domain::ModEntity>]
      # @param path [String] caminho do arquivo
      # @param options [Hash]
      # @return [String] caminho do arquivo gerado
      def export_to_file(project, modules, path, **options)
        data = export(project, modules, **options)
        json = JSON.pretty_generate(data)
        File.write(path, json)
        Core.logger.info("Exportação salva: #{path} (#{(json.length / 1024.0).round(1)} KB)")
        path
      end

      # Gera diff entre duas exportações.
      #
      # @param export_a [Hash] exportação anterior
      # @param export_b [Hash] exportação atual
      # @return [Hash] relatório de diferenças
      def diff(export_a, export_b)
        return nil unless export_a && export_b

        hashes_a = export_a[:hashes] || {}
        hashes_b = export_b[:hashes] || {}

        added = (hashes_b.keys - hashes_a.keys)
        removed = (hashes_a.keys - hashes_b.keys)
        modified = (hashes_a.keys & hashes_b.keys).select { |k| hashes_a[k] != hashes_b[k] }
        unchanged = (hashes_a.keys & hashes_b.keys).select { |k| hashes_a[k] == hashes_b[k] }

        {
          added: added,
          removed: removed,
          modified: modified,
          unchanged_count: unchanged.length,
          total_changes: added.length + removed.length + modified.length
        }
      end

      private

      def build_export_data(project, modules, catalog, options)
        export_id = Core::Ids.generate
        all_parts = []
        all_hardware = []
        all_operations = []
        all_environments = []
        hashes = {}

        # Exportar módulos
        module_exports = modules.map do |mod|
          # Coletar peças, hardware e operações
          mod.parts.each do |part|
            part_export = export_part(part, mod)
            all_parts << part_export
            hashes[part.ornato_id] = Core::Ids.content_hash(part_export)
          end

          mod.hardware_items.each do |hw|
            hw_export = export_hardware(hw, mod)
            all_hardware << hw_export
          end

          mod.operations.each do |op|
            op_export = export_operation(op, mod)
            all_operations << op_export
          end

          mod_export = export_module(mod)
          hashes[mod.ornato_id] = Core::Ids.content_hash(mod_export)
          mod_export
        end

        # Exportar ambientes do projeto
        if project.respond_to?(:environments)
          project.environments.each do |env|
            all_environments << export_environment(env)
          end
        end

        # Hash do projeto
        project_export = export_project(project)
        hashes[project.ornato_id] = Core::Ids.content_hash(project_export)

        {
          schema: 'ornato.project.v1',
          export_id: export_id,
          exported_at: Time.now.iso8601,
          ornato_version: Core::Config::VERSION,
          project: project_export,
          environments: all_environments,
          modules: module_exports,
          parts: all_parts,
          hardware: all_hardware,
          operations: all_operations,
          summary: build_summary(modules, all_parts, all_hardware, all_operations),
          catalog_snapshot: options[:include_catalog] && catalog ? export_catalog_snapshot(catalog) : nil,
          hashes: hashes
        }
      end

      def export_project(project)
        {
          ornato_id: project.ornato_id,
          name: project.name,
          client: project.client,
          state: project.state,
          revision_count: project.revisions.length,
          created_at: project.created_at,
          updated_at: project.updated_at
        }
      end

      def export_environment(env)
        {
          ornato_id: env.ornato_id,
          name: env.name,
          env_type: env.env_type,
          module_count: env.modules.length
        }
      end

      def export_module(mod)
        {
          ornato_id: mod.ornato_id,
          name: mod.name,
          module_type: mod.module_type,
          width_mm: mod.width_mm,
          height_mm: mod.height_mm,
          depth_mm: mod.depth_mm,
          body_thickness: mod.body_thickness,
          assembly_type: mod.assembly_type,
          back_type: mod.back_type,
          back_thickness: mod.back_thickness,
          base_type: mod.base_type,
          base_height_mm: mod.base_height_mm,
          body_material_id: mod.body_material_id,
          front_material_id: mod.front_material_id,
          internal_width: mod.internal_width_mm,
          internal_height: mod.internal_height_mm,
          internal_depth: mod.internal_depth_mm,
          parts_count: mod.parts.length,
          aggregates_count: mod.all_aggregates.length,
          operations_count: mod.operations.length,
          area_m2: mod.total_area_m2.round(4),
          edgeband_m: mod.total_edgeband_meters.round(3),
          state: mod.state,
          ruleset_id: mod.ruleset_id,
          version: mod.version
        }
      end

      def export_part(part, mod)
        {
          ornato_id: part.ornato_id,
          module_id: mod.ornato_id,
          name: part.name,
          code: part.code,
          upmcode: part.code,  # UpMobb compatibility
          part_type: part.part_type,
          quantity: part.quantity,
          length_mm: part.length_mm,
          width_mm: part.width_mm,
          cut_length: part.cut_length,
          cut_width: part.cut_width,
          thickness_nominal: part.thickness_nominal,
          thickness_real: part.thickness_real,
          material_id: part.material_id,
          grain_direction: part.grain_direction,
          edge_front: part.edge_front ? edge_to_hash(part.edge_front) : nil,
          edge_back: part.edge_back ? edge_to_hash(part.edge_back) : nil,
          edge_left: part.edge_left ? edge_to_hash(part.edge_left) : nil,
          edge_right: part.edge_right ? edge_to_hash(part.edge_right) : nil,
          edgeband_finish: part.respond_to?(:edgeband_finish_code) ? part.edgeband_finish_code : nil,
          area_m2: part.area_m2.round(6)
        }
      end

      def export_hardware(hw, mod)
        {
          ornato_id: hw.ornato_id,
          module_id: mod.ornato_id,
          name: hw.name,
          hardware_type: hw.hardware_type,
          catalog_id: hw.catalog_id,
          quantity: hw.quantity,
          properties: hw.properties
        }
      end

      def export_operation(op, mod)
        {
          ornato_id: op.ornato_id,
          module_id: mod.ornato_id,
          part_id: op.part_id,
          name: op.name,
          operation_type: op.operation_type,
          export_code: op.export_code,
          face: op.face,
          x_mm: op.x_mm,
          y_mm: op.y_mm,
          depth_mm: op.depth_mm,
          tool_diameter_mm: op.tool_diameter_mm,
          tool_id: op.tool_id,
          length_mm: op.respond_to?(:length_mm) ? op.length_mm : nil,
          width_mm: op.respond_to?(:width_mm) ? op.width_mm : nil
        }
      end

      def edge_to_hash(edge)
        {
          thickness_mm: edge.thickness_mm,
          width_mm: edge.width_mm,
          material_id: edge.material_id,
          export_code: edge.respond_to?(:export_code) ? edge.export_code : nil
        }
      end

      def build_summary(modules, parts, hardware, operations)
        {
          module_count: modules.length,
          parts_count: parts.length,
          hardware_count: hardware.length,
          operations_count: operations.length,
          total_area_m2: parts.sum { |p| p[:area_m2] || 0.0 }.round(3),
          unique_materials: parts.map { |p| p[:material_id] }.compact.uniq.length,
          unique_thicknesses: parts.map { |p| p[:thickness_nominal] }.compact.uniq.sort
        }
      end

      def export_catalog_snapshot(catalog)
        {
          version: catalog.version,
          materials_count: catalog.materials.length,
          edgebands_count: catalog.edgebands.length,
          hardware_count: catalog.hardware.length
        }
      end
    end
  end
end
