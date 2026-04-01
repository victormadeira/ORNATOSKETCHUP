# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# domain/revision.rb — Revisao imutavel e rastreavel do projeto
#
# Revisoes sao IMUTAVEIS apos criacao. Cada revisao grava o hash do
# projeto e de cada modulo no momento da criacao, permitindo diff
# entre revisoes e reprodutibilidade.
#
# Fluxo de vida:
#   1. Projeto passa por validacao completa
#   2. Nova Revision e criada com project_hash e module_hashes
#   3. Revisao pode ser congelada (freeze!) quando enviada para fabrica
#   4. Revisao congelada nao pode mais ser alterada
#   5. Para modificar projeto apos congelamento, nova revisao deve ser criada
#
# Rastreabilidade:
#   - Cada revisao armazena o hash SHA256 do projeto e de cada modulo
#   - module_changed? compara hash atual com hash armazenado
#   - previous_revision_id permite navegacao no historico
#   - frozen_at marca o momento exato do congelamento
#
# Estados do projeto (Core::Constants::PROJECT_STATES):
#   draft -> validated -> commercial_approved -> production_approved ->
#   factory_frozen -> in_production -> completed

module Ornato
  module Domain
    class Revision
      include EntityContract

      attr_reader :ornato_id,            # [String] identidade unica (formato rev_xxxxxxxxxxxx)
                  :project_id,           # [String] ornato_id do projeto
                  :number,               # [Integer] numero sequencial da revisao (>= 1)
                  :state,                # [Symbol] estado do projeto nesta revisao
                  :notes,                # [String] notas/comentarios do projetista
                  :created_by,           # [String] autor da revisao (ex: 'plugin', 'erp', nome)
                  :created_at,           # [String] ISO8601 timestamp de criacao
                  :previous_revision_id, # [String, nil] ornato_id da revisao anterior
                  :project_hash,         # [String] hash SHA256 do projeto no momento da revisao
                  :module_hashes,        # [Hash<String, String>] { module_id => hash_sha256 }
                  :frozen_at             # [String, nil] ISO8601 timestamp de congelamento

      # Cria nova Revision.
      #
      # @param project_id [String] ornato_id do projeto
      # @param number [Integer] numero sequencial da revisao
      # @param state [Symbol, String] estado do projeto nesta revisao
      # @param notes [String] notas do projetista (default: '')
      # @param created_by [String] autor da revisao (default: 'plugin')
      # @param previous_revision_id [String, nil] revisao anterior
      # @param project_hash [String] hash do projeto (default: '')
      def initialize(project_id:, number:, state:, notes: '',
                     created_by: 'plugin', previous_revision_id: nil, project_hash: '')
        @ornato_id            = Core::Ids.generate_revision_id
        @project_id           = project_id
        @number               = number.to_i
        @state                = state.to_sym
        @notes                = notes
        @created_by           = created_by
        @created_at           = Time.now.iso8601
        @previous_revision_id = previous_revision_id
        @project_hash         = project_hash
        @module_hashes        = {}
        @frozen_at            = nil
      end

      # ── EntityContract ────────────────────────────────────────────

      # Tipo de entidade de dominio.
      # @return [Symbol]
      def entity_type
        :revision
      end

      # Versao do schema desta entidade.
      # @return [Integer]
      def schema_version
        1
      end

      # ── Congelamento ──────────────────────────────────────────────

      # Congela revisao (marca como enviada para fabrica).
      # Apos congelamento, nenhuma alteracao e permitida no projeto
      # sem criar nova revisao. O timestamp de congelamento e gravado.
      # @return [String] timestamp ISO8601 do congelamento
      def freeze!
        @frozen_at = Time.now.iso8601
      end

      # Verifica se revisao esta congelada (enviada para fabrica).
      # @return [Boolean]
      def frozen?
        !@frozen_at.nil?
      end

      # ── Hashes de modulo ──────────────────────────────────────────

      # Registra hash de modulo para rastreabilidade.
      # Usado durante criacao da revisao para gravar o estado
      # de cada modulo no momento exato.
      #
      # @param module_id [String] ornato_id do modulo
      # @param hash [String] hash SHA256 do modulo (ex: "sha256:a1b2c3d4...")
      # @return [void]
      def add_module_hash(module_id, hash)
        @module_hashes[module_id] = hash
      end

      # Verifica se modulo mudou desde esta revisao.
      # Compara o hash atual do modulo com o hash armazenado.
      # Retorna true se o modulo nao existia na revisao ou se mudou.
      #
      # @param module_id [String] ornato_id do modulo
      # @param current_hash [String] hash SHA256 atual do modulo
      # @return [Boolean] true se mudou ou nao existia
      def module_changed?(module_id, current_hash)
        stored = @module_hashes[module_id]
        stored.nil? || stored != current_hash
      end

      # Retorna lista de modulos que mudaram desde esta revisao.
      # Recebe hash atual de cada modulo e compara com armazenado.
      #
      # @param current_hashes [Hash<String, String>] { module_id => hash_atual }
      # @return [Array<String>] lista de module_ids que mudaram
      def changed_modules(current_hashes)
        changed = []
        current_hashes.each do |module_id, current_hash|
          changed << module_id if module_changed?(module_id, current_hash)
        end
        # Modulos removidos (existiam na revisao mas nao no hash atual)
        @module_hashes.each_key do |module_id|
          changed << module_id unless current_hashes.key?(module_id)
        end
        changed.uniq
      end

      # Numero total de modulos gravados nesta revisao.
      # @return [Integer]
      def module_count
        @module_hashes.size
      end

      # ── Validacao ─────────────────────────────────────────────────

      # Valida schema da Revision.
      # @return [Array<Hash>] lista de erros { field:, msg: }
      def validate_schema
        errors = super
        errors << { field: :number, msg: 'deve ser >= 1' }      unless @number >= 1
        errors << { field: :project_id, msg: 'ausente' }        if @project_id.nil? || @project_id.to_s.empty?
        errors << { field: :state, msg: 'invalido' }            unless Core::Constants::PROJECT_STATES.include?(@state)
        errors << { field: :created_by, msg: 'ausente' }        if @created_by.nil? || @created_by.to_s.empty?
        errors
      end

      # ── Serializacao ──────────────────────────────────────────────

      # Serializa Revision para Hash.
      # @return [Hash]
      def to_hash
        {
          ornato_id: @ornato_id,
          project_id: @project_id,
          number: @number,
          state: @state,
          notes: @notes,
          created_by: @created_by,
          created_at: @created_at,
          previous_revision_id: @previous_revision_id,
          project_hash: @project_hash,
          module_hashes: @module_hashes.dup,
          frozen_at: @frozen_at,
          schema_version: schema_version
        }
      end

      # Reconstroi Revision a partir de Hash (deserializacao).
      # @param data [Hash] dados serializados (chaves Symbol)
      # @return [Revision]
      def self.from_hash(data)
        rev = new(
          project_id:           data[:project_id],
          number:               data[:number],
          state:                data[:state],
          notes:                data[:notes] || '',
          created_by:           data[:created_by] || 'plugin',
          previous_revision_id: data[:previous_revision_id],
          project_hash:         data[:project_hash] || ''
        )

        # Restaurar ornato_id original (nao gerar novo)
        rev.instance_variable_set(:@ornato_id, data[:ornato_id]) if data[:ornato_id]

        # Restaurar module_hashes
        if data[:module_hashes].is_a?(Hash)
          data[:module_hashes].each do |mod_id, hash_val|
            rev.add_module_hash(mod_id.to_s, hash_val)
          end
        end

        # Restaurar frozen_at
        rev.instance_variable_set(:@frozen_at, data[:frozen_at]) if data[:frozen_at]

        # Restaurar timestamp original
        rev.instance_variable_set(:@created_at, data[:created_at]) if data[:created_at]

        rev
      end
    end
  end
end
