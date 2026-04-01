# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# domain/contracts.rb — Interfaces formais (duck typing documentado)
#
# Contratos que todas as entidades de domínio DEVEM implementar.
# Validados por testes de regressão.

require 'digest'

module Ornato
  module Domain
    # Contrato base: toda entidade de domínio DEVE implementar.
    module EntityContract
      def ornato_id
        raise NotImplementedError, "#{self.class}#ornato_id não implementado"
      end

      def entity_type
        raise NotImplementedError, "#{self.class}#entity_type não implementado"
      end

      def schema_version
        raise NotImplementedError, "#{self.class}#schema_version não implementado"
      end

      def to_hash
        raise NotImplementedError, "#{self.class}#to_hash não implementado"
      end

      # Hash SHA256 determinístico para diff/rastreabilidade.
      # Exclui campos voláteis (timestamps) para estabilidade.
      def compute_hash
        relevant = to_hash.reject { |k, _| %i[created_at updated_at].include?(k) }
        Core::Ids.content_hash(relevant)
      end

      # Valida forma/schema da entidade (não regras de negócio).
      # @return [Array<Hash>] lista de erros { field:, msg: }
      def validate_schema
        errors = []
        errors << { field: :ornato_id, msg: 'ausente ou inválido' } unless Core::Ids.valid?(ornato_id)
        errors
      end
    end

    # Contrato para entidades que geram consequências técnicas.
    module ConsequenceGenerator
      # @param context [Hash] { ruleset:, opening:, module_entity:, catalog: }
      # @return [Array<Part>]
      def generate_parts(context)
        raise NotImplementedError, "#{self.class}#generate_parts não implementado"
      end

      # @param context [Hash]
      # @return [Array<HardwareItem>]
      def generate_hardware(context)
        raise NotImplementedError, "#{self.class}#generate_hardware não implementado"
      end

      # @param context [Hash]
      # @return [Array<Operation>]
      def generate_operations(context)
        raise NotImplementedError, "#{self.class}#generate_operations não implementado"
      end
    end

    # Contrato para receitas de módulos (RecipeBase deve implementar).
    module RecipeContract
      def metadata; raise NotImplementedError; end
      def parameters; raise NotImplementedError; end
      def constraints; raise NotImplementedError; end
      def opening_rules; raise NotImplementedError; end
      def aggregate_rules; raise NotImplementedError; end
      def structural_part_rules; raise NotImplementedError; end
      def default_hardware_rules; raise NotImplementedError; end
      def default_operation_rules; raise NotImplementedError; end
      def validations; raise NotImplementedError; end
    end
  end
end
