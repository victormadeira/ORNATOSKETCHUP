# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# domain/project.rb — Entidade raiz: projeto inteiro
#
# Um Project contém Environments, que contêm Modules.
# O Project controla revisões e estado global.

module Ornato
  module Domain
    class Project
      include EntityContract

      attr_accessor :ornato_id, :name, :client_name, :client_document,
                    :client_contact, :address, :state, :environments,
                    :revisions, :current_revision_id, :active_machine_profile_id,
                    :created_at, :updated_at, :created_by

      def initialize(name:, client_name: '', created_by: 'plugin')
        @ornato_id = Core::Ids.generate
        @name = name
        @client_name = client_name
        @client_document = ''
        @client_contact = ''
        @address = ''
        @state = :draft
        @environments = []
        @revisions = []
        @current_revision_id = nil
        @active_machine_profile_id = nil
        @created_at = Time.now.iso8601
        @updated_at = @created_at
        @created_by = created_by
      end

      def entity_type; :project; end
      def schema_version; 1; end

      # Transição de estado com validação formal.
      # @param new_state [Symbol]
      # @raise [Core::InvalidStateTransition] se transição não permitida
      def transition_to!(new_state)
        new_state = new_state.to_sym
        allowed = Core::Constants::PROJECT_TRANSITIONS[@state]
        unless allowed&.include?(new_state)
          raise Core::InvalidStateTransition,
            "Transição inválida: #{@state} → #{new_state}. Permitidas: #{allowed}",
            code: 'INVALID_TRANSITION',
            context: { from: @state, to: new_state, allowed: allowed }
        end
        old_state = @state
        @state = new_state
        @updated_at = Time.now.iso8601
        Core.events.emit(:project_state_changed,
          project_id: @ornato_id, from: old_state, to: new_state)
      end

      # Projeto pode ser editado estruturalmente?
      def editable?
        %i[draft validated].include?(@state)
      end

      # Projeto está congelado para fábrica?
      def frozen?
        %i[factory_frozen in_production completed].include?(@state)
      end

      def find_environment(env_id)
        @environments.find { |e| e.ornato_id == env_id }
      end

      def add_environment(env)
        env.project_id = @ornato_id
        @environments << env
        @updated_at = Time.now.iso8601
        env
      end

      def all_modules
        @environments.flat_map(&:modules)
      end

      def all_parts
        all_modules.flat_map(&:parts)
      end

      def all_hardware
        all_modules.flat_map(&:hardware_items)
      end

      def all_operations
        all_modules.flat_map(&:operations)
      end

      def find_module(module_id)
        all_modules.find { |m| m.ornato_id == module_id }
      end

      # Cria revisão imutável com hash do estado atual.
      def create_revision(notes: '', created_by: nil)
        rev_number = @revisions.length + 1
        revision = Revision.new(
          project_id: @ornato_id,
          number: rev_number,
          state: @state,
          notes: notes,
          created_by: created_by || @created_by,
          previous_revision_id: @current_revision_id,
          project_hash: compute_hash
        )
        # Gravar hash de cada módulo
        all_modules.each do |mod|
          revision.add_module_hash(mod.ornato_id, mod.compute_hash)
        end
        @revisions << revision
        @current_revision_id = revision.ornato_id
        @updated_at = Time.now.iso8601
        Core.events.emit(:revision_created,
          project_id: @ornato_id, revision_id: revision.ornato_id, number: rev_number)
        revision
      end

      # Encontra revisão por ID.
      def find_revision(revision_id)
        @revisions.find { |r| r.ornato_id == revision_id }
      end

      def to_hash
        {
          ornato_id: @ornato_id, name: @name,
          client_name: @client_name, client_document: @client_document,
          client_contact: @client_contact, address: @address,
          state: @state,
          environment_ids: @environments.map(&:ornato_id),
          environment_count: @environments.length,
          module_count: all_modules.length,
          current_revision_id: @current_revision_id,
          revision_count: @revisions.length,
          active_machine_profile_id: @active_machine_profile_id,
          created_at: @created_at, updated_at: @updated_at,
          created_by: @created_by,
          schema_version: schema_version
        }
      end
    end
  end
end
