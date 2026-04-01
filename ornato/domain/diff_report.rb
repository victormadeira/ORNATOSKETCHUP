# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# domain/diff_report.rb — Diferenças entre revisões/exportações
#
# Compara duas coleções de entidades e produz relatório detalhado
# de adições, remoções e modificações campo a campo.

module Ornato
  module Domain
    class DiffReport
      include EntityContract

      attr_reader :ornato_id, :project_id, :revision_from, :revision_to,
                  :changes, :created_at

      def initialize(project_id:, revision_from:, revision_to:)
        @ornato_id = Core::Ids.generate
        @project_id = project_id
        @revision_from = revision_from
        @revision_to = revision_to
        @changes = {
          modules:    { added: [], removed: [], modified: [] },
          parts:      { added: [], removed: [], modified: [] },
          hardware:   { added: [], removed: [], modified: [] },
          operations: { added: [], removed: [], modified: [] }
        }
        @created_at = Time.now.iso8601
      end

      def entity_type; :diff_report; end
      def schema_version; 1; end

      def empty?
        @changes.all? do |_, section|
          section[:added].empty? && section[:removed].empty? && section[:modified].empty?
        end
      end

      # Resumo com contagens por domínio.
      def summary
        counts = {}
        @changes.each do |domain, section|
          total = section[:added].length + section[:removed].length + section[:modified].length
          counts[domain] = { added: section[:added].length, removed: section[:removed].length,
                             modified: section[:modified].length, total: total } if total > 0
        end
        counts
      end

      # Compara duas coleções de entidades e popula changes.
      # @param domain_key [Symbol] :modules, :parts, :hardware, :operations
      # @param old_entities [Array] entidades da revisão antiga
      # @param new_entities [Array] entidades da revisão nova
      def compute(domain_key, old_entities, new_entities)
        old_by_id = old_entities.each_with_object({}) { |e, h| h[e.ornato_id] = e }
        new_by_id = new_entities.each_with_object({}) { |e, h| h[e.ornato_id] = e }

        # Adicionados
        (new_by_id.keys - old_by_id.keys).each do |id|
          entity = new_by_id[id]
          @changes[domain_key][:added] << {
            ornato_id: id,
            name: entity.respond_to?(:name) ? entity.name : id
          }
        end

        # Removidos
        (old_by_id.keys - new_by_id.keys).each do |id|
          entity = old_by_id[id]
          @changes[domain_key][:removed] << {
            ornato_id: id,
            name: entity.respond_to?(:name) ? entity.name : id
          }
        end

        # Modificados (hash diferente)
        (old_by_id.keys & new_by_id.keys).each do |id|
          old_hash = old_by_id[id].compute_hash
          new_hash = new_by_id[id].compute_hash
          next if old_hash == new_hash

          field_changes = compute_field_diff(old_by_id[id].to_hash, new_by_id[id].to_hash)
          @changes[domain_key][:modified] << {
            ornato_id: id,
            field_changes: field_changes
          }
        end
      end

      def to_hash
        {
          ornato_id: @ornato_id, project_id: @project_id,
          revision_from: @revision_from, revision_to: @revision_to,
          changes: @changes, summary: summary,
          created_at: @created_at, schema_version: schema_version
        }
      end

      private

      # Compara dois hashes campo a campo, retornando { field => { from:, to: } }
      def compute_field_diff(old_hash, new_hash)
        skip_keys = %i[ornato_id created_at updated_at]
        diffs = {}
        all_keys = (old_hash.keys + new_hash.keys).uniq - skip_keys
        all_keys.each do |key|
          old_val = old_hash[key]
          new_val = new_hash[key]
          if old_val != new_val
            diffs[key] = { from: old_val, to: new_val }
          end
        end
        diffs
      end
    end
  end
end
