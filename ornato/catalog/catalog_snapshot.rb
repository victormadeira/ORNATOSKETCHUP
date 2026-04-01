# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# catalog/catalog_snapshot.rb — Snapshot de catalogo para uso offline
#
# Gerencia a persistencia local do catalogo.
# O snapshot e um JSON salvo na pasta data/ do plugin.

require 'json'
require 'fileutils'

module Ornato
  module Catalog
    class CatalogSnapshot
      SNAPSHOT_FILENAME = 'catalog_snapshot.json'.freeze

      # Caminho padrao do snapshot.
      def self.default_path
        data_dir = File.join(File.dirname(__FILE__), '..', 'data')
        FileUtils.mkdir_p(data_dir)
        File.join(data_dir, SNAPSHOT_FILENAME)
      end

      # Salva estado do CatalogManager em disco.
      # @param manager [CatalogManager]
      # @param path [String, nil] caminho do arquivo (default: pasta data/)
      def self.save(manager, path = nil)
        path ||= default_path
        data = {
          schema: 'ornato.catalog.v1',
          version: manager.version,
          saved_at: Time.now.iso8601,
          materials_count: manager.materials.length,
          edgebands_count: manager.edgebands.length,
          hardware_count: manager.hardware.length,
          materials: manager.materials,
          edgebands: manager.edgebands,
          hardware: manager.hardware
        }
        File.write(path, JSON.pretty_generate(data))
        Core.logger.info("Snapshot salvo: #{path} (v#{manager.version})")
        path
      end

      # Carrega snapshot de disco para o CatalogManager.
      # @param manager [CatalogManager]
      # @param path [String, nil]
      # @return [Boolean] true se carregou com sucesso
      def self.load(manager, path = nil)
        path ||= default_path
        return false unless File.exist?(path)

        begin
          data = JSON.parse(File.read(path), symbolize_names: true)

          # Verificar schema
          schema = data[:schema] || 'unknown'
          unless schema == 'ornato.catalog.v1'
            Core.logger.warn("Snapshot com schema desconhecido: #{schema}")
          end

          manager.instance_variable_set(:@materials, data[:materials] || [])
          manager.instance_variable_set(:@edgebands, data[:edgebands] || [])
          manager.instance_variable_set(:@hardware, data[:hardware] || [])
          manager.instance_variable_set(:@version, data[:version] || 0)
          manager.instance_variable_set(:@loaded_at, Time.now.iso8601)

          Core.logger.info("Snapshot carregado: #{path} (v#{data[:version]})")
          true
        rescue => e
          Core.logger.error("Falha ao carregar snapshot: #{e.message}")
          false
        end
      end

      # Verifica se existe snapshot salvo.
      def self.exists?(path = nil)
        File.exist?(path || default_path)
      end

      # Retorna info sobre o snapshot sem carregar todos os dados.
      def self.info(path = nil)
        path ||= default_path
        return nil unless File.exist?(path)

        data = JSON.parse(File.read(path), symbolize_names: true)
        {
          version: data[:version],
          saved_at: data[:saved_at],
          materials_count: data[:materials_count],
          edgebands_count: data[:edgebands_count],
          hardware_count: data[:hardware_count],
          file_size: File.size(path)
        }
      rescue => e
        Core.logger.error("Falha ao ler info do snapshot: #{e.message}")
        nil
      end

      # Remove snapshot de disco.
      def self.delete(path = nil)
        path ||= default_path
        return false unless File.exist?(path)
        File.delete(path)
        Core.logger.info("Snapshot removido: #{path}")
        true
      end
    end
  end
end
