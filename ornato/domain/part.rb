# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# domain/part.rb — Peca individual: painel, frente, fundo, prateleira, etc.
#
# Part e a unidade atomica de fabricacao. Cada Part pertence a um modulo
# (via parent_id) e carrega todas as informacoes necessarias para:
#   - Plano de corte (dimensoes reais, grao, material)
#   - Fita de borda (4 lados, com material/largura/espessura/acabamento)
#   - Exportacao JSON compativel UpMobb (export_code, export_orientation)
#   - Rastreabilidade (ornato_id, timestamps, schema_version)
#
# EdgeSpec e um Struct que descreve a fita de borda de um lado da peca.
# Cada Part tem 4 EdgeSpecs (:top, :bottom, :left, :right).
#
# Codigos de acabamento de fita:
#   SEM_FITA  — nenhum lado com fita
#   1C        — 1 comprimento (top ou bottom)
#   1C+1L     — 1 comprimento + 1 largura
#   1C+2L     — 1 comprimento + 2 larguras
#   2C        — 2 comprimentos (top + bottom)
#   2C+1L     — 2 comprimentos + 1 largura
#   2C+2L     — 2 comprimentos + 2 larguras (= 4Lados)
#   4Lados    — alias para 2C+2L
#
# Codigos de exportacao UpMobb:
#   Fita: CMBOR{largura}x{espessura*10 com 3 digitos}{acabamento}
#   Ex:   CMBOR22x045BRANCO_TX

module Ornato
  module Domain
    # ================================================================
    # EdgeSpec — Descricao da fita de borda para um lado da peca
    # ================================================================
    EdgeSpec = Struct.new(
      :applied,       # [Boolean] fita aplicada neste lado?
      :material_id,   # [String, nil] ornato_id ou codigo do material da fita
      :width_mm,      # [Numeric] largura da fita em mm (ex: 22, 45)
      :thickness_mm,  # [Numeric] espessura da fita em mm (ex: 0.45, 1.0, 2.0)
      :finish,        # [String, nil] acabamento (ex: 'BRANCO_TX', 'CARVALHO')
      keyword_init: true
    ) do
      # Converte EdgeSpec para Hash serializavel.
      # @return [Hash]
      def to_hash
        {
          applied: applied,
          material_id: material_id,
          width_mm: width_mm,
          thickness_mm: thickness_mm,
          finish: finish
        }
      end

      # EdgeSpec sem fita aplicada (factory method).
      # @return [EdgeSpec]
      def self.none
        new(applied: false, material_id: nil, width_mm: 0, thickness_mm: 0, finish: nil)
      end

      # EdgeSpec padrao com fita aplicada (factory method).
      # @param material_id [String] identificador do material da fita
      # @param width [Numeric] largura em mm (default: 22)
      # @param thickness [Numeric] espessura em mm (default: 1.0)
      # @param finish [String] acabamento (default: 'BRANCO_TX')
      # @return [EdgeSpec]
      def self.standard(material_id, width: 22, thickness: 1.0, finish: 'BRANCO_TX')
        new(applied: true, material_id: material_id, width_mm: width, thickness_mm: thickness, finish: finish)
      end

      # Gera codigo de exportacao UpMobb para a fita.
      # Formato: CMBOR{largura}x{espessura*10 formatada 3 digitos}{acabamento}
      # Ex: CMBOR22x045BRANCO_TX (largura 22mm, espessura 0.45mm)
      # Ex: CMBOR22x010BRANCO_TX (largura 22mm, espessura 1.0mm)
      # @return [String, nil] nil se fita nao aplicada
      def export_code
        return nil unless applied

        thickness_code = format('%03d', (thickness_mm * 10).round)
        "CMBOR#{width_mm.to_i}x#{thickness_code}#{finish}"
      end
    end

    # ================================================================
    # Part — Peca individual de marcenaria
    # ================================================================
    class Part
      include EntityContract

      # Tipos de peca validos.
      PART_TYPES = %i[structural front drawer back shelf divider loose accessory].freeze

      # Direcoes de grao validas.
      GRAIN_DIRECTIONS = %i[length width none].freeze

      attr_accessor :ornato_id,          # [String] identidade unica de dominio
                    :parent_id,          # [String] ornato_id do modulo pai
                    :code,               # [String] codigo UpMobb (ex: 'CM_LAT_DIR')
                    :name,               # [String] nome legivel (ex: 'Lateral Direita')
                    :part_type,          # [Symbol] tipo da peca (ver PART_TYPES)
                    :length_mm,          # [Float] comprimento em mm (maior dimensao)
                    :width_mm,           # [Float] largura em mm (menor dimensao)
                    :thickness_nominal,  # [Float] espessura nominal em mm (ex: 18)
                    :thickness_real,     # [Float] espessura real em mm (ex: 18.5)
                    :material_id,        # [String] ornato_id ou codigo do material
                    :grain_direction,    # [Symbol] direcao do grao (ver GRAIN_DIRECTIONS)
                    :quantity,           # [Integer] quantidade de pecas iguais
                    :edges,              # [Hash<Symbol, EdgeSpec>] :top, :bottom, :left, :right
                    :operation_ids,      # [Array<String>] ornato_ids das operacoes CNC
                    :hardware_ids,       # [Array<String>] ornato_ids das ferragens
                    :cnc_orientation,    # [String, nil] orientacao CNC na maquina
                    :machine_constraints,# [Hash] restricoes de maquina (ex: { max_length: 2700 })
                    :export_code,        # [String, nil] codigo UpMobb da peca (ex: 'CM_LAT_DIR')
                    :export_orientation, # [String, nil] codigo de orientacao UpMobb (ex: 'FTE1x2')
                    :created_at,         # [String] ISO8601 timestamp de criacao
                    :updated_at          # [String] ISO8601 timestamp de ultima alteracao

      # Cria nova Part.
      #
      # @param parent_id [String] ornato_id do modulo pai
      # @param code [String] codigo da peca (ex: 'CM_LAT_DIR')
      # @param name [String] nome legivel
      # @param part_type [Symbol, String] tipo da peca
      # @param length_mm [Numeric] comprimento em mm
      # @param width_mm [Numeric] largura em mm
      # @param thickness_nominal [Numeric] espessura nominal em mm
      # @param material_id [String] identificador do material
      # @param grain_direction [Symbol, String] direcao do grao (default: :length)
      # @param quantity [Integer] quantidade (default: 1)
      # @raise [Core::DomainError] se part_type invalido
      def initialize(parent_id:, code:, name:, part_type:, length_mm:, width_mm:,
                     thickness_nominal:, material_id:, grain_direction: :length,
                     quantity: 1)
        type_sym = part_type.to_sym
        unless PART_TYPES.include?(type_sym)
          raise Core::DomainError, "Tipo de peca invalido: #{part_type}. Validos: #{PART_TYPES.join(', ')}"
        end
        grain_sym = grain_direction.to_sym
        unless GRAIN_DIRECTIONS.include?(grain_sym)
          raise Core::DomainError, "Direcao de grao invalida: #{grain_direction}. Validos: #{GRAIN_DIRECTIONS.join(', ')}"
        end

        @ornato_id          = Core::Ids.generate
        @parent_id          = parent_id
        @code               = code
        @name               = name
        @part_type          = type_sym
        @length_mm          = length_mm.to_f
        @width_mm           = width_mm.to_f
        @thickness_nominal  = thickness_nominal.to_f
        @thickness_real     = Core::Config.real_thickness(@thickness_nominal)
        @material_id        = material_id
        @grain_direction    = grain_sym
        @quantity           = [quantity.to_i, 1].max
        @edges              = {
          top:    EdgeSpec.none,
          bottom: EdgeSpec.none,
          left:   EdgeSpec.none,
          right:  EdgeSpec.none
        }
        @operation_ids      = []
        @hardware_ids       = []
        @cnc_orientation    = nil
        @machine_constraints = {}
        @export_code        = code
        @export_orientation = nil
        @created_at         = Time.now.iso8601
        @updated_at         = @created_at
      end

      # ── EntityContract ────────────────────────────────────────────

      # Tipo de entidade de dominio.
      # @return [Symbol]
      def entity_type
        :part
      end

      # Versao do schema desta entidade.
      # @return [Integer]
      def schema_version
        1
      end

      # ── Aliases de conveniência ─────────────────────────────────────
      # Usados extensivamente pelo engineering layer (edging_engine,
      # machining_engine, drilling_engine, export_engine, etc.)

      alias_method :module_id, :parent_id
      alias_method :module_id=, :parent_id=

      # Predicados de tipo
      def structural?; @part_type == :structural; end
      def front?;      @part_type == :front; end
      def drawer?;     @part_type == :drawer; end
      def back?;       @part_type == :back; end
      def shelf?;      @part_type == :shelf; end

      # Accessors de borda por nome (mapeiam para edges hash)
      # :top = comprimento frontal, :bottom = comprimento traseiro,
      # :left = largura esquerda, :right = largura direita
      def edge_front;        @edges[:top]; end
      def edge_front=(spec); @edges[:top] = spec; end
      def edge_back;         @edges[:bottom]; end
      def edge_back=(spec);  @edges[:bottom] = spec; end
      def edge_left;         @edges[:left]; end
      def edge_left=(spec);  @edges[:left] = spec; end
      def edge_right;        @edges[:right]; end
      def edge_right=(spec); @edges[:right] = spec; end

      # ── Dimensoes de corte ────────────────────────────────────────

      # Dimensao de corte no sentido do comprimento (a maior entre length e width).
      # Usada no plano de corte para posicionamento otimo na chapa.
      # @return [Float] mm
      def cut_length
        [@length_mm, @width_mm].max
      end

      # Dimensao de corte no sentido da largura (a menor entre length e width).
      # @return [Float] mm
      def cut_width
        [@length_mm, @width_mm].min
      end

      # Area de uma unica peca em metros quadrados.
      # @return [Float] m2
      def area_m2
        (@length_mm * @width_mm) / 1_000_000.0
      end

      # Area total considerando quantidade (area unitaria * quantidade).
      # @return [Float] m2
      def total_area_m2
        area_m2 * @quantity
      end

      # ── Fita de borda ─────────────────────────────────────────────

      # Metragem linear total de fita de borda para uma unica peca.
      # Soma comprimentos de todos os lados que tem fita aplicada.
      # Lados :top e :bottom usam length_mm, :left e :right usam width_mm.
      # @return [Float] metros lineares
      def edgeband_meters
        total_mm = 0.0
        total_mm += @length_mm if @edges[:top]&.applied
        total_mm += @length_mm if @edges[:bottom]&.applied
        total_mm += @width_mm  if @edges[:left]&.applied
        total_mm += @width_mm  if @edges[:right]&.applied
        total_mm / 1000.0
      end

      # Codigo de acabamento de fita para exportacao.
      # Conta comprimentos (C = :top/:bottom) e larguras (L = :left/:right).
      #
      # Retorna um dos codigos:
      #   SEM_FITA, 1C, 1C+1L, 1C+2L, 2C, 2C+1L, 2C+2L, 4Lados
      #
      # @return [String]
      def edgeband_finish_code
        comprimentos = 0
        larguras = 0
        comprimentos += 1 if @edges[:top]&.applied
        comprimentos += 1 if @edges[:bottom]&.applied
        larguras += 1     if @edges[:left]&.applied
        larguras += 1     if @edges[:right]&.applied

        total = comprimentos + larguras
        return 'SEM_FITA' if total.zero?
        return '4Lados'   if total == 4

        parts = []
        parts << "#{comprimentos}C" if comprimentos > 0
        parts << "#{larguras}L" if larguras > 0
        parts.join('+')
      end

      # Array com codigos de exportacao UpMobb de cada lado com fita.
      # Ordem: top, bottom, left, right (somente lados com fita aplicada).
      # @return [Array<String>]
      def edge_codes_array
        codes = []
        %i[top bottom left right].each do |side|
          spec = @edges[side]
          code = spec&.export_code
          codes << code if code
        end
        codes
      end

      # ── Validacao ─────────────────────────────────────────────────

      # Valida schema da Part.
      # Verifica: ornato_id valido, dimensoes > 0, material presente, tipo valido.
      # @return [Array<Hash>] lista de erros { field:, msg: }
      def validate_schema
        errors = super
        errors << { field: :length_mm, msg: 'deve ser > 0' }          unless @length_mm > 0
        errors << { field: :width_mm, msg: 'deve ser > 0' }           unless @width_mm > 0
        errors << { field: :thickness_nominal, msg: 'deve ser > 0' }  unless @thickness_nominal > 0
        errors << { field: :material_id, msg: 'ausente' }             if @material_id.nil? || @material_id.to_s.empty?
        errors << { field: :part_type, msg: 'invalido' }              unless PART_TYPES.include?(@part_type)
        errors << { field: :grain_direction, msg: 'invalido' }        unless GRAIN_DIRECTIONS.include?(@grain_direction)
        errors << { field: :quantity, msg: 'deve ser >= 1' }          unless @quantity >= 1
        errors << { field: :parent_id, msg: 'ausente' }               if @parent_id.nil? || @parent_id.to_s.empty?
        errors
      end

      # ── Serializacao ──────────────────────────────────────────────

      # Serializa Part para Hash.
      # @return [Hash]
      def to_hash
        {
          ornato_id: @ornato_id,
          parent_id: @parent_id,
          code: @code,
          name: @name,
          part_type: @part_type,
          length_mm: @length_mm,
          width_mm: @width_mm,
          thickness_nominal: @thickness_nominal,
          thickness_real: @thickness_real,
          material_id: @material_id,
          grain_direction: @grain_direction,
          quantity: @quantity,
          edges: {
            top:    @edges[:top].to_hash,
            bottom: @edges[:bottom].to_hash,
            left:   @edges[:left].to_hash,
            right:  @edges[:right].to_hash
          },
          operation_ids: @operation_ids.dup,
          hardware_ids: @hardware_ids.dup,
          cnc_orientation: @cnc_orientation,
          machine_constraints: @machine_constraints.dup,
          export_code: @export_code,
          export_orientation: @export_orientation,
          created_at: @created_at,
          updated_at: @updated_at,
          schema_version: schema_version
        }
      end

      # Reconstroi Part a partir de Hash (deserializacao).
      # @param data [Hash] dados serializados (chaves Symbol)
      # @return [Part]
      def self.from_hash(data)
        part = new(
          parent_id:          data[:parent_id],
          code:               data[:code],
          name:               data[:name],
          part_type:          data[:part_type],
          length_mm:          data[:length_mm],
          width_mm:           data[:width_mm],
          thickness_nominal:  data[:thickness_nominal],
          material_id:        data[:material_id],
          grain_direction:    data[:grain_direction] || :length,
          quantity:           data[:quantity] || 1
        )

        # Restaurar ornato_id original (nao gerar novo)
        part.instance_variable_set(:@ornato_id, data[:ornato_id]) if data[:ornato_id]

        # Restaurar espessura real (pode ter sido override)
        part.thickness_real = data[:thickness_real] if data[:thickness_real]

        # Restaurar edges
        if data[:edges].is_a?(Hash)
          %i[top bottom left right].each do |side|
            edge_data = data[:edges][side]
            next unless edge_data.is_a?(Hash)

            part.edges[side] = EdgeSpec.new(
              applied:      edge_data[:applied] || false,
              material_id:  edge_data[:material_id],
              width_mm:     edge_data[:width_mm] || 0,
              thickness_mm: edge_data[:thickness_mm] || 0,
              finish:       edge_data[:finish]
            )
          end
        end

        # Restaurar arrays e campos opcionais
        part.operation_ids      = data[:operation_ids] || []
        part.hardware_ids       = data[:hardware_ids] || []
        part.cnc_orientation    = data[:cnc_orientation]
        part.machine_constraints = data[:machine_constraints] || {}
        part.export_code        = data[:export_code]
        part.export_orientation = data[:export_orientation]
        part.instance_variable_set(:@created_at, data[:created_at]) if data[:created_at]
        part.instance_variable_set(:@updated_at, data[:updated_at]) if data[:updated_at]

        part
      end
    end
  end
end
