# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# core/errors.rb — Hierarquia de erros tipados
#
# Todos os erros do sistema herdam de OrnatoError.
# Cada subsistema tem sua família de erros para captura granular.

module Ornato
  module Core
    # Erro base — todos os erros Ornato herdam deste.
    # Carrega code (para serialização/UI) e context (hash de dados extras).
    class OrnatoError < StandardError
      attr_reader :code, :context

      def initialize(message, code: nil, context: {})
        @code = code
        @context = context
        super(message)
      end

      def to_hash
        {
          error_class: self.class.name,
          message: message,
          code: @code,
          context: @context
        }
      end
    end

    # ── Erros de domínio (regras de negócio violadas) ─────────────────

    class DomainError < OrnatoError; end

    class InvalidStateTransition < DomainError; end

    class RecipeNotFound < DomainError; end

    class RuleSetNotFound < DomainError; end

    class AggregateConflict < DomainError; end

    class PartGenerationError < DomainError; end

    class DimensionOutOfRange < DomainError; end

    class OpeningNotFound < DomainError; end

    class ModuleNotFound < DomainError; end

    # ── Erros de identidade ───────────────────────────────────────────

    class IdentityError < OrnatoError; end

    class OrphanEntity < IdentityError; end

    class DuplicateId < IdentityError; end

    class ReconciliationFailed < IdentityError; end

    # ── Erros de rebuild ──────────────────────────────────────────────

    class RebuildError < OrnatoError; end

    class PatchInvalid < RebuildError; end

    class RebuildTimeout < RebuildError; end

    class TransactionFailed < RebuildError; end

    # ── Erros de validação (com nível) ────────────────────────────────

    class ValidationError < OrnatoError
      attr_reader :level, :entity_id

      # @param level [Symbol] :blocking, :warning, :suggestion
      # @param entity_id [String, nil] ornato_id da entidade afetada
      def initialize(message, level: :blocking, entity_id: nil, **kwargs)
        @level = level
        @entity_id = entity_id
        super(message, **kwargs)
      end

      def blocking?
        @level == :blocking
      end

      def to_hash
        super.merge(level: @level, entity_id: @entity_id)
      end
    end

    # ── Erros de exportação ───────────────────────────────────────────

    class ExportError < OrnatoError; end

    class SchemaVersionMismatch < ExportError; end

    class CatalogSnapshotStale < ExportError; end

    class ExportIntegrityError < ExportError; end

    # ── Erros de catálogo ─────────────────────────────────────────────

    class CatalogError < OrnatoError; end

    class MaterialNotFound < CatalogError; end

    class HardwareNotFound < CatalogError; end

    class EdgebandNotFound < CatalogError; end

    class SyncFailed < CatalogError; end
  end
end
