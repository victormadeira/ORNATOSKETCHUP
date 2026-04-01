# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# domain/ruleset.rb — Sistema construtivo versionado
#
# RuleSets definem como módulos são construídos: espessuras, folgas,
# materiais padrão, ferragens, regras de furação, regras de exportação.
# São versionados e imutáveis após publicação (version > 0).
# Projetos antigos continuam reproduzíveis com seu RuleSet original.

module Ornato
  module Domain
    class RuleSet
      include EntityContract

      attr_accessor :ornato_id, :name, :version, :description,
                    :target_types, :rules

      def initialize
        @ornato_id = Core::Ids.generate
        @name = ''
        @version = 0  # 0 = rascunho, >= 1 = publicado e imutável
        @description = ''
        @target_types = []
        @rules = {}
      end

      def entity_type; :ruleset; end
      def schema_version; 1; end

      # Acessa regra com path seguro (sem exceção se caminho não existir).
      # @param path [Array<Symbol>] caminho no hash de regras
      # @param fallback [Object] valor padrão se não encontrar
      # @return [Object]
      #
      # Exemplo: rule(:thicknesses, :body, fallback: 18) → 18
      def rule(*path, fallback: nil)
        result = path.reduce(@rules) do |hash, key|
          break nil unless hash.is_a?(Hash)
          hash[key]
        end
        result.nil? ? fallback : result
      end

      # RuleSets publicados (version >= 1) são imutáveis.
      def published?
        @version >= 1
      end

      # Verifica se suporta determinado tipo de módulo.
      def supports_type?(module_type)
        @target_types.include?(module_type.to_sym)
      end

      def validate_schema
        errors = super
        errors << { field: :name, msg: 'ausente' } if @name.nil? || @name.empty?
        errors << { field: :rules, msg: 'vazio' } if @rules.empty?
        errors
      end

      def to_hash
        {
          ornato_id: @ornato_id, name: @name, version: @version,
          description: @description, target_types: @target_types,
          rules: @rules, schema_version: schema_version
        }
      end

      def self.from_hash(data)
        rs = new
        rs.instance_variable_set(:@ornato_id, data[:ornato_id]) if data[:ornato_id]
        rs.name = data[:name] || ''
        rs.version = data[:version] || 0
        rs.description = data[:description] || ''
        rs.target_types = data[:target_types] || []
        rs.rules = data[:rules] || {}
        rs
      end
    end
  end
end
