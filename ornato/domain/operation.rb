# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# domain/operation.rb — Operacao CNC aplicada a uma peca
#
# Representa uma usinagem individual sobre um Part:
#   - furacao     — furo simples (broca, cavilha, minifix, dobradicca)
#   - canal       — rasgo retangular passante ou cego (fundo encaixado)
#   - rebaixo     — rebaixamento parcial de face (cava de fundo)
#   - fresagem    — contorno/perfil com fresa (gola, perfil decorativo)
#   - pocket      — escavacao de area fechada (nicho embutido)
#   - rasgo       — corte estreito (passagem de fio, canal luminotecnico)
#   - cava        — recorte em borda (perfil cava de puxador)
#   - corte_especial — corte CNC nao padrao (angulo, curva)
#
# Cada operacao pertence a exatamente um Part (via parent_part_id).
# Operacoes sao geradas automaticamente por receitas ou adicionadas
# manualmente pelo projetista.
#
# Posicionamento (x_mm, y_mm) referenciado a partir do canto inferior
# esquerdo da peca, com a face selecionada voltada para o operador.
#
# Codigos de exportacao UpMobb:
#   CM_USI_FUR, CM_USI_CAN, CM_USI_REB, CM_USI_FRE,
#   CM_USI_POC, CM_USI_RAS, CM_USI_CAV, CM_USI_CES
#
# Ferramentas CNC comuns (tool_id):
#   f_5mm_broca   — broca sistema 32
#   f_8mm_cavilha — broca para cavilha
#   f_15mm_tambor_min — fresa 15mm minifix
#   f_35mm_dob    — broca copo 35mm dobradicca
#   r_f           — fresa reta (canal/rebaixo)

module Ornato
  module Domain
    class Operation
      include EntityContract

      # Tipos de operacao CNC validos.
      TYPES = %i[furacao canal rebaixo fresagem pocket rasgo cava corte_especial].freeze

      # Faces validas para aplicacao da operacao.
      FACES = %i[top bottom front back left right].freeze

      attr_accessor :ornato_id,         # [String] identidade unica de dominio
                    :parent_part_id,    # [String] ornato_id da peca pai
                    :operation_type,    # [Symbol] tipo da operacao (ver TYPES)
                    :face,              # [Symbol] face da peca (ver FACES)
                    :x_mm,              # [Float] posicao X em mm (ref: canto inferior esquerdo)
                    :y_mm,              # [Float] posicao Y em mm (ref: canto inferior esquerdo)
                    :length_mm,         # [Float, nil] comprimento da operacao em mm (nil para furos)
                    :width_mm,          # [Float, nil] largura da operacao em mm (nil para furos)
                    :depth_mm,          # [Float] profundidade em mm
                    :tool_diameter_mm,  # [Float] diametro da ferramenta em mm
                    :tool_id,           # [String, nil] identificador da ferramenta CNC
                    :rpm,               # [Integer, nil] rotacao por minuto
                    :feed_rate,         # [Float, nil] avanco em mm/min
                    :depth_per_pass,    # [Float, nil] profundidade por passada em mm
                    :through,           # [Boolean] operacao passante (atravessa a peca)?
                    :description,       # [String] descricao legivel da operacao
                    :machine_eligible,  # [Array<Symbol>] maquinas compativeis (ex: [:cnc, :tupia])
                    :export_code,       # [String, nil] codigo UpMobb (ex: 'CM_USI_FUR')
                    :created_at         # [String] ISO8601 timestamp de criacao

      # ── Aliases de conveniencia (Engineering layer usa part_id) ────
      alias_method :part_id, :parent_part_id
      alias_method :part_id=, :parent_part_id=

      # module_id: usado por export_engine e rebuild_orchestrator
      # para agrupar operacoes por modulo. Armazenado separadamente
      # porque a relacao Operation→Part→Module e indireta.
      attr_accessor :module_id

      # Alias name → description (Engineering layer usa op.name)
      alias_method :name, :description
      alias_method :name=, :description=

      # Cria nova Operation.
      #
      # @param parent_part_id [String] ornato_id da peca pai
      # @param operation_type [Symbol, String] tipo da operacao
      # @param face [Symbol, String] face de aplicacao
      # @param x_mm [Numeric] posicao X em mm
      # @param y_mm [Numeric] posicao Y em mm
      # @param depth_mm [Numeric] profundidade em mm
      # @param tool_diameter_mm [Numeric] diametro da ferramenta em mm
      # @param length_mm [Numeric, nil] comprimento (nil para furos simples)
      # @param width_mm [Numeric, nil] largura (nil para furos simples)
      # @param tool_id [String, nil] identificador da ferramenta
      # @param rpm [Integer, nil] rotacao por minuto
      # @param feed_rate [Numeric, nil] avanco em mm/min
      # @param depth_per_pass [Numeric, nil] profundidade por passada
      # @param through [Boolean] operacao passante? (default: false)
      # @param description [String] descricao legivel (default: '')
      # @param machine_eligible [Array<Symbol>] maquinas compativeis (default: [:cnc])
      # @raise [Core::DomainError] se operation_type ou face invalido
      def initialize(parent_part_id:, operation_type:, face:, x_mm:, y_mm:,
                     depth_mm:, tool_diameter_mm:, length_mm: nil, width_mm: nil,
                     tool_id: nil, rpm: nil, feed_rate: nil, depth_per_pass: nil,
                     through: false, description: '', machine_eligible: [:cnc])
        type_sym = operation_type.to_sym
        unless TYPES.include?(type_sym)
          raise Core::DomainError, "Tipo de operacao invalido: #{operation_type}. " \
                                   "Validos: #{TYPES.join(', ')}"
        end
        face_sym = face.to_sym
        unless FACES.include?(face_sym)
          raise Core::DomainError, "Face invalida: #{face}. Validas: #{FACES.join(', ')}"
        end

        @ornato_id        = Core::Ids.generate
        @parent_part_id   = parent_part_id
        @operation_type   = type_sym
        @face             = face_sym
        @x_mm             = x_mm.to_f
        @y_mm             = y_mm.to_f
        @length_mm        = length_mm&.to_f
        @width_mm         = width_mm&.to_f
        @depth_mm         = depth_mm.to_f
        @tool_diameter_mm = tool_diameter_mm.to_f
        @tool_id          = tool_id
        @rpm              = rpm&.to_i
        @feed_rate        = feed_rate&.to_f
        @depth_per_pass   = depth_per_pass&.to_f
        @through          = through
        @description      = description
        @machine_eligible = Array(machine_eligible).map(&:to_sym)
        @export_code      = derive_export_code
        @created_at       = Time.now.iso8601
      end

      # ── EntityContract ────────────────────────────────────────────

      # Tipo de entidade de dominio.
      # @return [Symbol]
      def entity_type
        :operation
      end

      # Versao do schema desta entidade.
      # @return [Integer]
      def schema_version
        1
      end

      # ── Consultas ─────────────────────────────────────────────────

      # Verifica se eh operacao de furacao simples (broca vertical).
      # Furacoes nao tem comprimento/largura — sao definidas apenas
      # por posicao (x, y), profundidade e diametro da ferramenta.
      # @return [Boolean]
      def drilling?
        @operation_type == :furacao
      end

      # Verifica se operacao requer maquina CNC.
      # Operacoes que podem ser feitas manualmente (furacao simples com
      # gabarito, por exemplo) nao exigem CNC. Operacoes complexas
      # como pocket, fresagem e corte_especial sempre exigem.
      # @return [Boolean]
      def cnc_required?
        %i[fresagem pocket corte_especial cava].include?(@operation_type) ||
          (!drilling? && @length_mm && @length_mm > 0)
      end

      # Verifica se eh operacao passante (atravessa toda a espessura).
      # @return [Boolean]
      def through?
        @through
      end

      # Verifica se eh canal (rasgo retangular).
      # @return [Boolean]
      def channel?
        @operation_type == :canal
      end

      # Verifica se eh rebaixo.
      # @return [Boolean]
      def rabbet?
        @operation_type == :rebaixo
      end

      # ── Validacao ─────────────────────────────────────────────────

      # Valida schema da Operation.
      # @return [Array<Hash>] lista de erros { field:, msg: }
      def validate_schema
        errors = super
        errors << { field: :parent_part_id, msg: 'ausente' }  if @parent_part_id.nil? || @parent_part_id.to_s.empty?
        errors << { field: :operation_type, msg: 'invalido' }  unless TYPES.include?(@operation_type)
        errors << { field: :face, msg: 'invalida' }            unless FACES.include?(@face)
        errors << { field: :depth_mm, msg: 'deve ser > 0' }    unless @depth_mm > 0
        errors << { field: :tool_diameter_mm, msg: 'deve ser > 0' } unless @tool_diameter_mm > 0
        errors << { field: :x_mm, msg: 'deve ser >= 0' }       if @x_mm < 0
        errors << { field: :y_mm, msg: 'deve ser >= 0' }       if @y_mm < 0

        # Operacoes nao-furacao devem ter comprimento ou largura definidos
        unless drilling?
          if @length_mm.nil? || @length_mm <= 0
            errors << { field: :length_mm, msg: 'deve ser > 0 para operacao nao-furacao' }
          end
        end

        errors
      end

      # ── Serializacao ──────────────────────────────────────────────

      # Serializa Operation para Hash.
      # @return [Hash]
      def to_hash
        {
          ornato_id: @ornato_id,
          parent_part_id: @parent_part_id,
          operation_type: @operation_type,
          face: @face,
          x_mm: @x_mm,
          y_mm: @y_mm,
          length_mm: @length_mm,
          width_mm: @width_mm,
          depth_mm: @depth_mm,
          tool_diameter_mm: @tool_diameter_mm,
          tool_id: @tool_id,
          rpm: @rpm,
          feed_rate: @feed_rate,
          depth_per_pass: @depth_per_pass,
          through: @through,
          description: @description,
          machine_eligible: @machine_eligible,
          export_code: @export_code,
          created_at: @created_at,
          schema_version: schema_version
        }
      end

      # Reconstroi Operation a partir de Hash (deserializacao).
      # @param data [Hash] dados serializados (chaves Symbol)
      # @return [Operation]
      def self.from_hash(data)
        op = new(
          parent_part_id:   data[:parent_part_id],
          operation_type:   data[:operation_type],
          face:             data[:face],
          x_mm:             data[:x_mm],
          y_mm:             data[:y_mm],
          depth_mm:         data[:depth_mm],
          tool_diameter_mm: data[:tool_diameter_mm],
          length_mm:        data[:length_mm],
          width_mm:         data[:width_mm],
          tool_id:          data[:tool_id],
          rpm:              data[:rpm],
          feed_rate:        data[:feed_rate],
          depth_per_pass:   data[:depth_per_pass],
          through:          data[:through] || false,
          description:      data[:description] || '',
          machine_eligible: data[:machine_eligible] || [:cnc]
        )

        # Restaurar ornato_id original (nao gerar novo)
        op.instance_variable_set(:@ornato_id, data[:ornato_id]) if data[:ornato_id]

        # Restaurar export_code se fornecido (pode ter sido customizado)
        op.export_code = data[:export_code] if data[:export_code]

        # Restaurar timestamp original
        op.instance_variable_set(:@created_at, data[:created_at]) if data[:created_at]

        op
      end

      private

      # Deriva codigo de exportacao UpMobb a partir do tipo de operacao.
      # Usa o mapeamento definido em Core::Constants::OPERATION_CODES.
      #
      # @return [String, nil] codigo de exportacao ou nil se tipo desconhecido
      def derive_export_code
        Core::Constants::OPERATION_CODES[@operation_type]
      end
    end
  end
end
