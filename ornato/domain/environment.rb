# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# domain/environment.rb — Ambiente do projeto (cozinha, quarto, etc.)

module Ornato
  module Domain
    class Environment
      include EntityContract

      attr_accessor :ornato_id, :project_id, :name, :env_type, :modules,
                    :created_at, :updated_at

      def initialize(project_id:, name:, env_type:)
        unless Core::Constants::ENVIRONMENT_TYPES.include?(env_type.to_sym)
          raise Core::DomainError, "Tipo de ambiente inválido: #{env_type}. Válidos: #{Core::Constants::ENVIRONMENT_TYPES.join(', ')}"
        end
        @ornato_id = Core::Ids.generate
        @project_id = project_id
        @name = name
        @env_type = env_type.to_sym
        @modules = []
        @created_at = Time.now.iso8601
        @updated_at = @created_at
      end

      def entity_type; :environment; end
      def schema_version; 1; end

      def add_module(mod_entity)
        mod_entity.environment_id = @ornato_id
        @modules << mod_entity
        @updated_at = Time.now.iso8601
        mod_entity
      end

      def remove_module(module_id)
        removed = @modules.reject! { |m| m.ornato_id == module_id }
        @updated_at = Time.now.iso8601 if removed
      end

      def find_module(module_id)
        @modules.find { |m| m.ornato_id == module_id }
      end

      def module_count
        @modules.length
      end

      def total_parts_count
        @modules.sum { |m| m.parts.length }
      end

      def to_hash
        {
          ornato_id: @ornato_id, project_id: @project_id,
          name: @name, env_type: @env_type,
          module_ids: @modules.map(&:ornato_id),
          module_count: @modules.length,
          created_at: @created_at, updated_at: @updated_at,
          schema_version: schema_version
        }
      end
    end
  end
end
