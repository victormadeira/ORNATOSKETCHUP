# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# catalog/catalog_manager.rb — Gerenciador central de catalogo
#
# Gerencia materiais, fitas de borda e ferragens.
# Fontes de dados (em ordem de prioridade):
#   1. Snapshot local (JSON salvo na pasta do plugin)
#   2. Defaults hardcoded (para primeiro uso)
#   3. Sincronizacao com ERP (futuro)

require 'json'

module Ornato
  module Catalog
    class CatalogManager
      attr_reader :materials, :edgebands, :hardware, :version, :loaded_at

      def initialize
        @materials = []
        @edgebands = []
        @hardware = []
        @version = 0
        @loaded_at = nil
      end

      # Carrega catalogo de snapshot local ou gera defaults.
      def load(snapshot_path = nil)
        if snapshot_path && File.exist?(snapshot_path)
          load_from_file(snapshot_path)
        else
          load_defaults
        end
        @loaded_at = Time.now.iso8601
        Core.logger.info("Catalogo carregado: #{@materials.length} materiais, #{@edgebands.length} fitas, #{@hardware.length} ferragens")
        Core.events.emit(:catalog_synced, version: @version)
      end

      # Salva snapshot local em JSON.
      def save_snapshot(path)
        data = {
          version: @version,
          saved_at: Time.now.iso8601,
          materials: @materials,
          edgebands: @edgebands,
          hardware: @hardware
        }
        tmp = "#{path}.tmp"
        File.write(tmp, JSON.pretty_generate(data), encoding: 'UTF-8')
        File.rename(tmp, path)
        Core.logger.info("Snapshot do catalogo salvo: #{path}")
      rescue Errno::EACCES, Errno::ENOSPC, IOError => e
        File.delete(tmp) rescue nil
        Core.logger.error("Falha ao salvar snapshot: #{e.message}")
      end

      # -- Busca de materiais -------------------------------------------------

      def find_material(id)
        @materials.find { |m| m[:id] == id }
      end

      def find_material_by_code(code)
        @materials.find { |m| m[:code] == code }
      end

      def materials_by_type(type)
        @materials.select { |m| m[:type] == type.to_s }
      end

      def materials_by_thickness(thickness)
        @materials.select { |m| m[:thickness_nominal] == thickness }
      end

      # -- Busca de fitas -----------------------------------------------------

      def find_edgeband(id)
        @edgebands.find { |e| e[:id] == id }
      end

      def edgebands_for_material(material_id)
        mat = find_material(material_id)
        return [] unless mat
        @edgebands.select { |e| e[:color_group] == mat[:color_group] }
      end

      # -- Busca de ferragens -------------------------------------------------

      def find_hardware(id)
        @hardware.find { |h| h[:id] == id }
      end

      def hardware_by_type(type)
        @hardware.select { |h| h[:type] == type.to_s }
      end

      private

      def load_from_file(path)
        data = JSON.parse(File.read(path, encoding: 'UTF-8'), symbolize_names: true)
        @materials = data[:materials] || []
        @edgebands = data[:edgebands] || []
        @hardware = data[:hardware] || []
        @version = data[:version] || 0
        Core.logger.info("Catalogo carregado de snapshot: #{path}")
      rescue => e
        Core.logger.error("Falha ao carregar snapshot: #{e.message}")
        load_defaults
      end

      def load_defaults
        @materials = DefaultCatalog.materials
        @edgebands = DefaultCatalog.edgebands
        @hardware = DefaultCatalog.hardware
        @version = 1
      end
    end
  end
end
