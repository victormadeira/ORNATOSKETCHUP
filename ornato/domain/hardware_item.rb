# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# domain/hardware_item.rb — Ferragem aplicada, sugerida ou derivada
#
# Representa qualquer ferragem vinculada a um modulo ou peca:
#   - Dobradicas (dobradicca) — vinculadas a portas
#   - Corredicas (corredicca) — vinculadas a gavetas
#   - Puxadores — vinculados a frentes (porta ou gaveta)
#   - Conectores (minifix, cavilha, parafuso) — juncao estrutural
#   - Suportes, amortecedores, perfis, trilhos, acessorios
#
# Ferragens podem ser:
#   - Geradas automaticamente por receitas (ConsequenceGenerator)
#   - Adicionadas manualmente pelo projetista
#   - Vinculadas a um catalogo ERP (catalog_id)
#
# O campo properties armazena parametros especificos por tipo:
#   - Dobradicca: { abertura_graus: 110, copo: 35, calco: 0 }
#   - Corredicca: { comprimento_mm: 450, tipo: 'oculta', extracao: 'total' }
#   - Puxador:    { comprimento_mm: 160, furo_a_furo: 128 }

module Ornato
  module Domain
    class HardwareItem
      include EntityContract

      attr_accessor :ornato_id,    # [String] identidade unica de dominio
                    :parent_id,    # [String] ornato_id do modulo ou peca pai
                    :code,         # [String] codigo da ferragem (ex: 'DOB_110_35')
                    :name,         # [String] nome legivel (ex: 'Dobradicca 110 graus')
                    :hardware_type,# [Symbol] tipo (ver Core::Constants::HARDWARE_TYPES)
                    :brand,        # [String] marca do fabricante
                    :model,        # [String] modelo do fabricante
                    :quantity,     # [Integer] quantidade
                    :catalog_id,   # [String, nil] identificador no catalogo ERP
                    :properties,   # [Hash] parametros especificos do tipo
                    :created_at    # [String] ISO8601 timestamp de criacao

      # Cria nova HardwareItem.
      #
      # @param parent_id [String] ornato_id do modulo ou peca pai
      # @param code [String] codigo da ferragem
      # @param name [String] nome legivel
      # @param hardware_type [Symbol, String] tipo da ferragem
      # @param brand [String] marca (default: '')
      # @param model [String] modelo (default: '')
      # @param quantity [Integer] quantidade (default: 1)
      # @raise [Core::DomainError] se hardware_type invalido
      def initialize(parent_id:, code:, name:, hardware_type:, brand: '', model: '', quantity: 1)
        type_sym = hardware_type.to_sym
        unless Core::Constants::HARDWARE_TYPES.include?(type_sym)
          raise Core::DomainError, "Tipo de ferragem invalido: #{hardware_type}. " \
                                   "Validos: #{Core::Constants::HARDWARE_TYPES.join(', ')}"
        end

        @ornato_id     = Core::Ids.generate
        @parent_id     = parent_id
        @code          = code
        @name          = name
        @hardware_type = type_sym
        @brand         = brand
        @model         = model
        @quantity      = [quantity.to_i, 1].max
        @catalog_id    = nil
        @properties    = {}
        @created_at    = Time.now.iso8601
      end

      # ── EntityContract ────────────────────────────────────────────

      # Tipo de entidade de dominio.
      # @return [Symbol]
      def entity_type
        :hardware_item
      end

      # Versao do schema desta entidade.
      # @return [Integer]
      def schema_version
        1
      end

      # ── Consultas de tipo ─────────────────────────────────────────

      # Verifica se eh dobradicca.
      # @return [Boolean]
      def hinge?
        @hardware_type == :dobradiça
      end

      # Verifica se eh corredicca.
      # @return [Boolean]
      def slide?
        @hardware_type == :corrediça
      end

      # Verifica se eh puxador.
      # @return [Boolean]
      def handle?
        @hardware_type == :puxador
      end

      # Verifica se eh conector estrutural (minifix, cavilha, parafuso, conector).
      # @return [Boolean]
      def connector?
        %i[minifix cavilha parafuso conector].include?(@hardware_type)
      end

      # Verifica se eh suporte de prateleira.
      # @return [Boolean]
      def shelf_support?
        @hardware_type == :suporte
      end

      # Verifica se eh amortecedor.
      # @return [Boolean]
      def damper?
        @hardware_type == :amortecedor
      end

      # ── Validacao ─────────────────────────────────────────────────

      # Valida schema da HardwareItem.
      # @return [Array<Hash>] lista de erros { field:, msg: }
      def validate_schema
        errors = super
        errors << { field: :code, msg: 'ausente' }          if @code.nil? || @code.empty?
        errors << { field: :name, msg: 'ausente' }          if @name.nil? || @name.empty?
        errors << { field: :quantity, msg: 'deve ser >= 1' } unless @quantity >= 1
        errors << { field: :parent_id, msg: 'ausente' }     if @parent_id.nil? || @parent_id.to_s.empty?
        errors << { field: :hardware_type, msg: 'invalido' } unless Core::Constants::HARDWARE_TYPES.include?(@hardware_type)
        errors
      end

      # ── Serializacao ──────────────────────────────────────────────

      # Serializa HardwareItem para Hash.
      # @return [Hash]
      def to_hash
        {
          ornato_id: @ornato_id,
          parent_id: @parent_id,
          code: @code,
          name: @name,
          hardware_type: @hardware_type,
          brand: @brand,
          model: @model,
          quantity: @quantity,
          catalog_id: @catalog_id,
          properties: @properties.dup,
          created_at: @created_at,
          schema_version: schema_version
        }
      end

      # Reconstroi HardwareItem a partir de Hash (deserializacao).
      # @param data [Hash] dados serializados (chaves Symbol)
      # @return [HardwareItem]
      def self.from_hash(data)
        hw = new(
          parent_id:     data[:parent_id],
          code:          data[:code],
          name:          data[:name],
          hardware_type: data[:hardware_type],
          brand:         data[:brand] || '',
          model:         data[:model] || '',
          quantity:      data[:quantity] || 1
        )

        # Restaurar ornato_id original (nao gerar novo)
        hw.instance_variable_set(:@ornato_id, data[:ornato_id]) if data[:ornato_id]

        # Restaurar campos opcionais
        hw.catalog_id  = data[:catalog_id]
        hw.properties  = data[:properties] || {}
        hw.instance_variable_set(:@created_at, data[:created_at]) if data[:created_at]

        hw
      end
    end
  end
end
