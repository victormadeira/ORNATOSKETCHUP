# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# core/attributes.rb — Camada de abstração para persistência no SketchUp
#
# Toda leitura/escrita de atributos em entidades SketchUp passa por aqui.
# Benefícios:
#   - Ponto único para logging de persistência
#   - Serialização/deserialização automática (Hash→JSON, Symbol→String)
#   - Preparação para migração de schema futura
#   - Validação de tipos antes de gravar
#
# Dicionários:
#   ornato.identity      — ornato_id, tipo, schema_version, timestamps
#   ornato.design        — dimensões, posição, rotação, nome
#   ornato.engineering   — ruleset, montagem, fundo, base
#   ornato.manufacturing — material, fita, operações, CNC
#   ornato.sync          — hashes, status de export, vínculo ERP
#   ornato.audit         — criado_por, notas de revisão

require 'json'

module Ornato
  module Core
    module Attributes
      # ── Escrita ────────────────────────────────────────────────────

      # Escreve um hash inteiro de atributos em um dicionário.
      # @param entity [Sketchup::Entity] grupo ou componente
      # @param dict [String] nome do dicionário (ex: 'ornato.identity')
      # @param data [Hash] chave→valor
      def self.write(entity, dict, data)
        data.each do |key, value|
          serialized = serialize(value)
          entity.set_attribute(dict, key.to_s, serialized)
        end
      end

      # Escreve um atributo individual.
      # @param entity [Sketchup::Entity]
      # @param dict [String]
      # @param key [String, Symbol]
      # @param value [Object]
      def self.write_one(entity, dict, key, value)
        entity.set_attribute(dict, key.to_s, serialize(value))
      end

      # ── Leitura ────────────────────────────────────────────────────

      # Lê todos os atributos de um dicionário.
      # @param entity [Sketchup::Entity]
      # @param dict [String]
      # @return [Hash<Symbol, Object>] chave→valor deserializado
      def self.read_all(entity, dict)
        ad = entity.attribute_dictionary(dict)
        return {} unless ad
        result = {}
        ad.each_pair { |key, value| result[key.to_sym] = deserialize(value) }
        result
      end

      # Lê um atributo específico.
      # @param entity [Sketchup::Entity]
      # @param dict [String]
      # @param key [String, Symbol]
      # @param default [Object] valor padrão se não encontrado
      # @return [Object]
      def self.read(entity, dict, key, default = nil)
        value = entity.get_attribute(dict, key.to_s)
        value.nil? ? default : deserialize(value)
      end

      # ── Remoção ────────────────────────────────────────────────────

      # Remove um atributo individual.
      def self.delete(entity, dict, key)
        ad = entity.attribute_dictionary(dict)
        ad&.delete_key(key.to_s)
      end

      # Remove dicionário inteiro de uma entity.
      def self.clear_dict(entity, dict)
        dicts = entity.attribute_dictionaries
        dicts&.delete(dict)
      end

      # Remove todos os dicionários Ornato de uma entity.
      def self.clear_all(entity)
        Config::ALL_DICTS.each { |dict| clear_dict(entity, dict) }
      end

      # ── Consultas ──────────────────────────────────────────────────

      # Verifica se entity é uma entidade Ornato (tem ornato_id).
      # @param entity [Sketchup::Entity]
      # @return [Boolean]
      def self.ornato_entity?(entity)
        return false unless entity.respond_to?(:get_attribute)
        !entity.get_attribute(Config::DICT_IDENTITY, 'ornato_id').nil?
      end

      # Retorna o ornato_id de uma entity.
      # @param entity [Sketchup::Entity]
      # @return [String, nil]
      def self.ornato_id(entity)
        read(entity, Config::DICT_IDENTITY, 'ornato_id')
      end

      # Retorna o tipo Ornato de uma entity.
      # @param entity [Sketchup::Entity]
      # @return [Symbol, nil]
      def self.entity_type(entity)
        tipo = read(entity, Config::DICT_IDENTITY, 'tipo')
        tipo&.to_sym
      end

      # Retorna o schema_version de uma entity.
      # @param entity [Sketchup::Entity]
      # @return [Integer, nil]
      def self.schema_version(entity)
        read(entity, Config::DICT_IDENTITY, 'schema_version')
      end

      # ── Persistência de alto nível ─────────────────────────────────

      # Persiste uma entidade de domínio completa nos dicionários corretos.
      # Distribui automaticamente cada campo para o dicionário apropriado.
      #
      # @param entity [Sketchup::Entity] grupo ou componente SketchUp
      # @param domain_obj [Object] objeto de domínio que responde a #to_hash e #entity_type
      def self.persist_domain_entity(entity, domain_obj)
        hash = domain_obj.to_hash

        # Campos que vão para cada dicionário
        identity_fields = %i[ornato_id schema_version recipe_id revision_id created_at updated_at]
        design_fields = %i[name module_type width_mm height_mm depth_mm position rotation_deg mirrored]
        engineering_fields = %i[ruleset_id ruleset_version assembly_type back_type back_thickness base_type base_height_mm body_thickness]
        manufacturing_fields = %i[body_material_id front_material_id back_material_id edges cnc_orientation grain_direction code part_type]
        sync_fields = %i[export_hash persistent_id pid_path state]

        write(entity, Config::DICT_IDENTITY, hash.select { |k, _| identity_fields.include?(k) })
        write(entity, Config::DICT_DESIGN, hash.select { |k, _| design_fields.include?(k) })
        write(entity, Config::DICT_ENGINEERING, hash.select { |k, _| engineering_fields.include?(k) })
        write(entity, Config::DICT_MANUFACTURING, hash.select { |k, _| manufacturing_fields.include?(k) })
        write(entity, Config::DICT_SYNC, hash.select { |k, _| sync_fields.include?(k) })

        # Tipo sempre gravado na identity para busca rápida
        write_one(entity, Config::DICT_IDENTITY, 'tipo', domain_obj.entity_type.to_s)
      end

      # Carrega todos os dados Ornato de uma entity SketchUp.
      # @param entity [Sketchup::Entity]
      # @return [Hash<Symbol, Object>] merge de todos os dicionários
      def self.load_domain_data(entity)
        data = {}
        Config::ALL_DICTS.each do |dict|
          data.merge!(read_all(entity, dict))
        end
        data
      end

      # ── Busca por ornato_id ──────────────────────────────────────────

      # Encontra uma entity SketchUp pelo seu ornato_id.
      # @param ornato_id [String] ID do objeto de domínio
      # @param model [Sketchup::Model, nil] modelo ativo (default: active_model)
      # @return [Sketchup::Entity, nil]
      def self.find_entity_by_ornato_id(ornato_id, model = nil)
        return nil unless ornato_id
        model ||= Sketchup.active_model
        return nil unless model
        search_entity_by_id(model.entities, ornato_id)
      end

      # ── Busca em massa ─────────────────────────────────────────────

      # Encontra todas as entities Ornato no modelo ativo.
      # @param type_filter [Symbol, nil] filtrar por tipo (ex: :module, :part)
      # @return [Array<Sketchup::Entity>]
      def self.find_all_ornato_entities(model = nil, type_filter: nil)
        model ||= Sketchup.active_model
        results = []
        scan_entities(model.entities, results, type_filter)
        results
      end

      # ── Serialização ───────────────────────────────────────────────
      # SketchUp armazena nativamente: String, Integer, Float, Boolean, Array.
      # Precisamos converter: Hash (→JSON string), Symbol, Time, nil.

      private

      SERIALIZE_PREFIX_JSON = '__J__'.freeze
      SERIALIZE_PREFIX_SYM  = '__S__'.freeze
      SERIALIZE_PREFIX_TIME = '__T__'.freeze
      SERIALIZE_PREFIX_NIL  = '__N__'.freeze

      def self.serialize(value)
        case value
        when Hash
          "#{SERIALIZE_PREFIX_JSON}#{value.to_json}"
        when Symbol
          "#{SERIALIZE_PREFIX_SYM}#{value}"
        when Time
          "#{SERIALIZE_PREFIX_TIME}#{value.iso8601}"
        when NilClass
          SERIALIZE_PREFIX_NIL
        when Array
          # Arrays de tipos simples o SketchUp lida nativamente.
          # Arrays com hashes precisam de serialização individual.
          value.map { |v| serialize(v) }
        else
          value
        end
      end

      def self.deserialize(value)
        case value
        when String
          if value.start_with?(SERIALIZE_PREFIX_JSON)
            JSON.parse(value.sub(SERIALIZE_PREFIX_JSON, ''), symbolize_names: true)
          elsif value.start_with?(SERIALIZE_PREFIX_SYM)
            value.sub(SERIALIZE_PREFIX_SYM, '').to_sym
          elsif value.start_with?(SERIALIZE_PREFIX_TIME)
            value.sub(SERIALIZE_PREFIX_TIME, '')
          elsif value == SERIALIZE_PREFIX_NIL
            nil
          else
            value
          end
        when Array
          value.map { |v| deserialize(v) }
        else
          value
        end
      end

      def self.scan_entities(entities, results, type_filter)
        entities.each do |entity|
          next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

          if ornato_entity?(entity)
            if type_filter.nil? || entity_type(entity) == type_filter
              results << entity
            end
          end

          # Recursão em sub-entities
          sub = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
          scan_entities(sub, results, type_filter)
        end
      end

      # Busca recursiva por ornato_id.
      def self.search_entity_by_id(entities, target_id)
        entities.each do |entity|
          next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

          oid = entity.get_attribute(Config::DICT_IDENTITY, 'ornato_id')
          return entity if oid == target_id

          sub = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
          found = search_entity_by_id(sub, target_id)
          return found if found
        end
        nil
      end
    end
  end
end
