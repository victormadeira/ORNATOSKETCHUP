# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# domain/aggregate.rb — Agregado paramétrico (porta, gaveta, prateleira, etc.)
#
# Agregados são entidades que preenchem aberturas (openings) de um módulo.
# Cada agregado sabe gerar suas próprias peças, ferragens e operações CNC
# com base no RuleSet ativo e nas dimensões da abertura em que reside.
#
# Fluxo: Opening → Aggregate → generate_parts / generate_hardware / generate_operations
#
# Tipos suportados (Core::Constants::AGGREGATE_TYPES):
#   :prateleira_fixa, :prateleira_regulavel, :divisoria_vertical,
#   :fundo, :porta_abrir, :porta_basculante, :porta_correr,
#   :gaveta, :gavetao, :puxador, :perfil_cava, :acessorio
#
# Subtipos de porta (Core::Constants::DOOR_SUBTYPES):
#   :lisa, :provencal, :almofadada, :vidro, :vidro_inteiro,
#   :perfil_aluminio, :veneziana, :ripada, :cego
#
# Sobreposições (Core::Constants::OVERLAP_TYPES):
#   :total  — porta cobre laterais inteiras
#   :meia   — porta cobre metade da espessura lateral
#   :interna — porta cabe dentro do vão
#
# Corrediças para gavetas (Core::Constants::SLIDE_DEDUCTIONS):
#   telescopica: 25.4mm, oculta: 42.0mm, tandembox: 75.0mm, roller: 25.0mm

module Ornato
  module Domain
    class Aggregate
      include EntityContract
      include ConsequenceGenerator

      # ── Constantes reexportadas para conveniência ─────────────────────

      TYPES          = Core::Constants::AGGREGATE_TYPES
      DOOR_SUBTYPES  = Core::Constants::DOOR_SUBTYPES
      OVERLAP_TYPES  = Core::Constants::OVERLAP_TYPES

      # Tipos que ocupam altura vertical no vão (relevante para empilhamento)
      HEIGHT_OCCUPYING_TYPES = %i[
        gaveta gavetao porta_abrir porta_basculante porta_correr
        prateleira_fixa prateleira_regulavel divisoria_vertical fundo
      ].freeze

      # Tipos considerados "porta" para lógica de dobradiça/overlap
      DOOR_TYPES = %i[porta_abrir porta_basculante].freeze

      # Tipos considerados "gaveta" para lógica de corrediça
      DRAWER_TYPES = %i[gaveta gavetao].freeze

      # Tipos fixos (conectados por minifix/cavilha, não removíveis)
      FIXED_TYPES = %i[prateleira_fixa divisoria_vertical fundo].freeze

      # ── Atributos ────────────────────────────────────────────────────

      attr_accessor :ornato_id, :module_id, :opening_id,
                    :aggregate_type, :subtype,
                    :position_mm, :width_mm, :height_mm, :depth_mm,
                    :overlap, :side,
                    :material_id, :thickness_nominal,
                    :generated_part_ids, :generated_hardware_ids,
                    :generated_operation_ids,
                    :properties,
                    :created_at, :updated_at

      # Cria um novo agregado.
      #
      # @param module_id [String] ornato_id do módulo pai
      # @param opening_id [String] ornato_id da abertura que contém este agregado
      # @param aggregate_type [Symbol] tipo do agregado (ver TYPES)
      # @param subtype [Symbol, nil] subtipo (ex: :lisa para portas)
      # @param position_mm [Float] posição vertical dentro da abertura (mm da base)
      # @param width_mm [Float] largura do agregado em mm (0 = calculado pela abertura)
      # @param height_mm [Float] altura do agregado em mm (0 = calculado pela abertura)
      # @param depth_mm [Float] profundidade do agregado em mm (0 = calculado pela abertura)
      # @param overlap [Symbol] tipo de sobreposição para portas (:total, :meia, :interna)
      # @param side [Symbol, nil] lado de abertura (:esquerda, :direita, nil)
      # @param material_id [String, nil] ornato_id do material (nil = herda do módulo)
      # @param thickness_nominal [Numeric, nil] espessura nominal em mm (nil = herda do módulo)
      # @param properties [Hash] propriedades extras específicas do tipo
      def initialize(module_id:, opening_id:, aggregate_type:,
                     subtype: nil, position_mm: 0.0,
                     width_mm: 0.0, height_mm: 0.0, depth_mm: 0.0,
                     overlap: :total, side: nil,
                     material_id: nil, thickness_nominal: nil,
                     properties: {})
        unless TYPES.include?(aggregate_type.to_sym)
          raise Core::DomainError,
            "Tipo de agregado inválido: #{aggregate_type}. Válidos: #{TYPES.join(', ')}",
            code: 'INVALID_AGGREGATE_TYPE',
            context: { given: aggregate_type, valid: TYPES }
        end

        @ornato_id            = Core::Ids.generate
        @module_id            = module_id
        @opening_id           = opening_id
        @aggregate_type       = aggregate_type.to_sym
        @subtype              = subtype&.to_sym
        @position_mm          = position_mm.to_f
        @width_mm             = width_mm.to_f
        @height_mm            = height_mm.to_f
        @depth_mm             = depth_mm.to_f
        @overlap              = overlap.to_sym
        @side                 = side&.to_sym
        @material_id          = material_id
        @thickness_nominal    = thickness_nominal
        @generated_part_ids      = []
        @generated_hardware_ids  = []
        @generated_operation_ids = []
        @properties           = properties
        @created_at           = Time.now.iso8601
        @updated_at           = @created_at
      end

      # ── EntityContract ───────────────────────────────────────────────

      def entity_type; :aggregate; end
      def schema_version; 1; end

      # ── Predicados de tipo ───────────────────────────────────────────

      # Este agregado e uma porta (abrir ou basculante)?
      # @return [Boolean]
      def door?
        DOOR_TYPES.include?(@aggregate_type)
      end

      # Este agregado e um conjunto de gaveta?
      # @return [Boolean]
      def drawer?
        DRAWER_TYPES.include?(@aggregate_type)
      end

      # Este agregado e uma prateleira (fixa ou regulavel)?
      # @return [Boolean]
      def shelf?
        %i[prateleira_fixa prateleira_regulavel].include?(@aggregate_type)
      end

      # Este agregado e uma divisoria vertical?
      # @return [Boolean]
      def divider?
        @aggregate_type == :divisoria_vertical
      end

      # Este agregado e uma porta de correr?
      # @return [Boolean]
      def sliding_door?
        @aggregate_type == :porta_correr
      end

      # Este agregado e um fundo?
      # @return [Boolean]
      def back?
        @aggregate_type == :fundo
      end

      # Este agregado e fixo (minifix/cavilha)?
      # @return [Boolean]
      def fixed?
        FIXED_TYPES.include?(@aggregate_type)
      end

      # Tipo que ocupa altura vertical no vao?
      # @return [Boolean]
      def occupies_height?
        HEIGHT_OCCUPYING_TYPES.include?(@aggregate_type)
      end

      # Altura ocupada por este agregado no vao (mm).
      # Para agregados que nao ocupam altura, retorna 0.
      # @return [Float]
      def occupied_height_mm
        return 0.0 unless occupies_height?
        @height_mm
      end

      # ── ConsequenceGenerator: Geração de peças ──────────────────────

      # Gera peças de corte para este agregado.
      #
      # @param context [Hash] { ruleset:, opening:, module_entity:, catalog: }
      #   - ruleset [RuleSet] regras construtivas ativas
      #   - opening [Opening] abertura que contém este agregado
      #   - module_entity [ModEntity] módulo pai
      #   - catalog [Hash, nil] catálogo de materiais (opcional)
      # @return [Array<Hash>] peças geradas (hashes com dados para Part.new)
      def generate_parts(context)
        opening = context[:opening]
        mod     = context[:module_entity]
        ruleset = context[:ruleset]

        parts = case @aggregate_type
                when :porta_abrir, :porta_basculante
                  generate_door_parts(opening, mod, ruleset)
                when :porta_correr
                  generate_sliding_door_parts(opening, mod, ruleset)
                when :gaveta, :gavetao
                  generate_drawer_parts(opening, mod, ruleset)
                when :prateleira_fixa, :prateleira_regulavel
                  generate_shelf_parts(opening, mod, ruleset)
                when :divisoria_vertical
                  generate_divider_parts(opening, mod, ruleset)
                when :fundo
                  generate_back_parts(opening, mod, ruleset)
                else
                  []
                end

        @generated_part_ids = parts.map { |p| p[:ornato_id] }
        @updated_at = Time.now.iso8601
        parts
      end

      # Gera ferragens necessárias para este agregado.
      #
      # @param context [Hash] { ruleset:, opening:, module_entity:, catalog: }
      # @return [Array<Hash>] ferragens geradas (hashes com dados para HardwareItem)
      def generate_hardware(context)
        hardware = case @aggregate_type
                   when :porta_abrir, :porta_basculante
                     generate_door_hardware(context)
                   when :porta_correr
                     generate_sliding_door_hardware(context)
                   when :gaveta, :gavetao
                     generate_drawer_hardware(context)
                   when :prateleira_regulavel
                     generate_shelf_hardware(context)
                   when :prateleira_fixa, :divisoria_vertical, :fundo
                     generate_fixed_hardware(context)
                   else
                     []
                   end

        @generated_hardware_ids = hardware.map { |h| h[:ornato_id] }
        @updated_at = Time.now.iso8601
        hardware
      end

      # Gera operações CNC necessárias para este agregado.
      #
      # @param context [Hash] { ruleset:, opening:, module_entity:, catalog: }
      # @return [Array<Hash>] operações geradas (hashes com dados para Operation)
      def generate_operations(context)
        operations = case @aggregate_type
                     when :porta_abrir, :porta_basculante
                       generate_door_operations(context)
                     when :gaveta, :gavetao
                       generate_drawer_operations(context)
                     when :prateleira_fixa, :divisoria_vertical
                       generate_fixed_operations(context)
                     else
                       []
                     end

        @generated_operation_ids = operations.map { |o| o[:ornato_id] }
        @updated_at = Time.now.iso8601
        operations
      end

      # ── Códigos de exportação ────────────────────────────────────────

      # Retorna o código UpMobb para o subtipo de porta.
      #
      # @return [String] código CM_POR_xxx
      def door_code
        case @subtype
        when :lisa           then Core::Constants::PART_CODES[:porta_lisa]
        when :provencal      then Core::Constants::PART_CODES[:porta_provencal]
        when :almofadada     then Core::Constants::PART_CODES[:porta_almofadada]
        when :vidro          then Core::Constants::PART_CODES[:porta_vidro]
        when :vidro_inteiro  then Core::Constants::PART_CODES[:porta_vidro]
        when :veneziana      then Core::Constants::PART_CODES[:porta_veneziana]
        when :perfil_aluminio then 'CM_POR_ALU'
        when :ripada         then 'CM_POR_RIP'
        when :cego           then 'CM_POR_CEG'
        else
          Core::Constants::PART_CODES[:porta_lisa]
        end
      end

      # ── Cálculos de dobradiças ───────────────────────────────────────

      # Calcula a quantidade de dobradiças necessárias pela altura da porta.
      #
      # Regra industrial brasileira:
      #   <= 600mm → 2 dobradiças
      #   <= 900mm → 3 dobradiças
      #   <= 1200mm → 4 dobradiças
      #   <= 1600mm → 5 dobradiças
      #   > 1600mm → 5 + 1 a cada 400mm adicionais
      #
      # @param height_mm [Numeric] altura da porta em mm
      # @return [Integer]
      def calculate_hinge_count(height_mm)
        h = height_mm.to_f
        return 2 if h <= 600.0
        return 3 if h <= 900.0
        return 4 if h <= 1200.0
        return 5 if h <= 1600.0

        5 + ((h - 1600.0) / 400.0).ceil
      end

      # Calcula posições das dobradiças ao longo da altura da porta.
      # Primeira dobradiça a 80mm do topo, última a 80mm da base,
      # intermediárias distribuídas uniformemente.
      #
      # @param height_mm [Numeric] altura da porta em mm
      # @param count [Integer] quantidade de dobradiças
      # @return [Array<Float>] posições em mm a partir da base
      def calculate_hinge_positions(height_mm, count)
        h = height_mm.to_f
        margin = 80.0
        return [margin] if count == 1

        top_pos    = h - margin  # posição da dobradiça de cima (a partir da base)
        bottom_pos = margin      # posição da dobradiça de baixo (a partir da base)

        return [bottom_pos, top_pos] if count == 2

        # Intermediárias distribuídas uniformemente entre top e bottom
        spacing = (top_pos - bottom_pos) / (count - 1).to_f
        (0...count).map { |i| (bottom_pos + (i * spacing)).round(1) }
      end

      # ── Validação ───────────────────────────────────────────────────

      def validate_schema
        errors = super
        errors << { field: :module_id, msg: 'ausente' } unless Core::Ids.valid?(@module_id)
        errors << { field: :opening_id, msg: 'ausente' } unless Core::Ids.valid?(@opening_id)
        errors << { field: :aggregate_type, msg: 'inválido' } unless TYPES.include?(@aggregate_type)
        if door? && @subtype && !DOOR_SUBTYPES.include?(@subtype)
          errors << { field: :subtype, msg: "subtipo de porta inválido: #{@subtype}" }
        end
        if door? && !OVERLAP_TYPES.include?(@overlap)
          errors << { field: :overlap, msg: "sobreposição inválida: #{@overlap}" }
        end
        errors
      end

      # ── Serialização ────────────────────────────────────────────────

      def to_hash
        {
          ornato_id:               @ornato_id,
          module_id:               @module_id,
          opening_id:              @opening_id,
          aggregate_type:          @aggregate_type,
          subtype:                 @subtype,
          position_mm:             @position_mm,
          width_mm:                @width_mm,
          height_mm:               @height_mm,
          depth_mm:                @depth_mm,
          overlap:                 @overlap,
          side:                    @side,
          material_id:             @material_id,
          thickness_nominal:       @thickness_nominal,
          generated_part_ids:      @generated_part_ids,
          generated_hardware_ids:  @generated_hardware_ids,
          generated_operation_ids: @generated_operation_ids,
          properties:              @properties,
          created_at:              @created_at,
          updated_at:              @updated_at,
          schema_version:          schema_version
        }
      end

      # Reconstrói um Aggregate a partir de hash serializado.
      #
      # @param data [Hash] dados serializados
      # @return [Aggregate]
      def self.from_hash(data)
        agg = allocate
        agg.instance_variable_set(:@ornato_id,               data[:ornato_id])
        agg.instance_variable_set(:@module_id,               data[:module_id])
        agg.instance_variable_set(:@opening_id,              data[:opening_id])
        agg.instance_variable_set(:@aggregate_type,          data[:aggregate_type]&.to_sym)
        agg.instance_variable_set(:@subtype,                 data[:subtype]&.to_sym)
        agg.instance_variable_set(:@position_mm,             data[:position_mm].to_f)
        agg.instance_variable_set(:@width_mm,                data[:width_mm].to_f)
        agg.instance_variable_set(:@height_mm,               data[:height_mm].to_f)
        agg.instance_variable_set(:@depth_mm,                data[:depth_mm].to_f)
        agg.instance_variable_set(:@overlap,                 (data[:overlap] || :total).to_sym)
        agg.instance_variable_set(:@side,                    data[:side]&.to_sym)
        agg.instance_variable_set(:@material_id,             data[:material_id])
        agg.instance_variable_set(:@thickness_nominal,       data[:thickness_nominal])
        agg.instance_variable_set(:@generated_part_ids,      data[:generated_part_ids] || [])
        agg.instance_variable_set(:@generated_hardware_ids,  data[:generated_hardware_ids] || [])
        agg.instance_variable_set(:@generated_operation_ids, data[:generated_operation_ids] || [])
        agg.instance_variable_set(:@properties,              data[:properties] || {})
        agg.instance_variable_set(:@created_at,              data[:created_at])
        agg.instance_variable_set(:@updated_at,              data[:updated_at])
        agg
      end

      private

      # ══════════════════════════════════════════════════════════════════
      #  GERAÇÃO DE PEÇAS
      # ══════════════════════════════════════════════════════════════════

      # Gera peça da porta (abrir ou basculante).
      # A porta recebe fita de borda nos 4 lados.
      # As dimensões dependem do tipo de sobreposição:
      #   :total   — porta cobre vão + 2x espessura corpo - 2x folga
      #   :meia    — porta cobre vão + 1x espessura corpo - 2x folga
      #   :interna — porta cabe dentro do vão com folga
      #
      # @param opening [Opening] abertura que contém este agregado
      # @param mod [ModEntity] módulo pai
      # @param ruleset [RuleSet] regras construtivas
      # @return [Array<Hash>] lista com 1 peça (a porta)
      def generate_door_parts(opening, mod, ruleset)
        body_thick = resolve_body_thickness(mod, ruleset)
        folga      = ruleset.rule(:clearances, :door, fallback: 2.0)
        esp_porta  = resolve_front_thickness(mod, ruleset)

        o_width  = effective_opening_width(opening)
        o_height = effective_opening_height(opening)

        case @overlap
        when :total
          # Porta cobre laterais inteiras: vão + 2× espessura corpo - 2× folga
          porta_w = o_width  + (2.0 * body_thick) - (2.0 * folga)
          porta_h = o_height + (2.0 * body_thick) - (2.0 * folga)
        when :meia
          # Meia sobreposição: porta cobre metade de cada lateral
          porta_w = o_width  + body_thick - (2.0 * folga)
          porta_h = o_height + (2.0 * body_thick) - (2.0 * folga)
        when :interna
          # Interna: porta cabe dentro do vão
          porta_w = o_width  - (2.0 * folga)
          porta_h = o_height - (2.0 * folga)
        else
          porta_w = o_width  + (2.0 * body_thick) - (2.0 * folga)
          porta_h = o_height + (2.0 * body_thick) - (2.0 * folga)
        end

        @width_mm  = porta_w.round(1)
        @height_mm = porta_h.round(1)
        @depth_mm  = esp_porta.to_f

        part_id = Core::Ids.generate
        [{
          ornato_id:        part_id,
          module_id:        @module_id,
          aggregate_id:     @ornato_id,
          name:             "Porta #{@subtype || :lisa}",
          part_type:        :front,
          part_code:        door_code,
          width_mm:         porta_w.round(1),
          height_mm:        porta_h.round(1),
          thickness_nominal: esp_porta,
          thickness_real:   Core::Config.real_thickness(esp_porta),
          material_id:      @material_id || mod.front_material_id,
          grain_direction:  :height,
          quantity:          1,
          edgeband: {
            front:  true,
            back:   true,
            top:    true,
            bottom: true
          }
        }]
      end

      # Gera peças para porta de correr (pode haver 2 ou mais folhas).
      # Cada folha tem largura = (vão + overlap) / num_folhas.
      #
      # @param opening [Opening] abertura
      # @param mod [ModEntity] módulo pai
      # @param ruleset [RuleSet] regras construtivas
      # @return [Array<Hash>] peças (1 por folha)
      def generate_sliding_door_parts(opening, mod, ruleset)
        num_panels = (@properties[:panel_count] || 2).to_i
        esp_porta  = resolve_front_thickness(mod, ruleset)
        folga      = ruleset.rule(:clearances, :sliding_door, fallback: 3.0)
        overlap_mm = ruleset.rule(:sliding_door, :overlap_per_panel, fallback: 20.0)

        o_width  = effective_opening_width(opening)
        o_height = effective_opening_height(opening)

        # Cada folha: (vão + overlap * (n-1)) / n
        panel_w = ((o_width + (overlap_mm * (num_panels - 1))) / num_panels.to_f) - folga
        panel_h = o_height - (2.0 * folga)

        @width_mm  = panel_w.round(1)
        @height_mm = panel_h.round(1)
        @depth_mm  = esp_porta.to_f

        (1..num_panels).map do |i|
          part_id = Core::Ids.generate
          {
            ornato_id:        part_id,
            module_id:        @module_id,
            aggregate_id:     @ornato_id,
            name:             "Porta Correr #{i}/#{num_panels}",
            part_type:        :front,
            part_code:        Core::Constants::PART_CODES[:porta_correr],
            width_mm:         panel_w.round(1),
            height_mm:        panel_h.round(1),
            thickness_nominal: esp_porta,
            thickness_real:   Core::Config.real_thickness(esp_porta),
            material_id:      @material_id || mod.front_material_id,
            grain_direction:  :height,
            quantity:          1,
            edgeband: {
              front:  true,
              back:   true,
              top:    true,
              bottom: true
            }
          }
        end
      end

      # Gera peças da gaveta: frente, 2x lateral, traseira, fundo.
      # Deduções de largura baseadas em Core::Constants::SLIDE_DEDUCTIONS.
      #
      # @param opening [Opening] abertura
      # @param mod [ModEntity] módulo pai
      # @param ruleset [RuleSet] regras construtivas
      # @return [Array<Hash>] 5 peças (ou 3 se tandembox sem laterais MDF)
      def generate_drawer_parts(opening, mod, ruleset)
        body_thick    = resolve_body_thickness(mod, ruleset)
        esp_corpo     = body_thick
        esp_frente    = resolve_front_thickness(mod, ruleset)
        esp_fundo_gav = ruleset.rule(:drawer, :bottom_thickness, fallback: 3)
        folga         = ruleset.rule(:clearances, :door, fallback: 2.0)
        recuo_tras    = ruleset.rule(:drawer, :back_setback, fallback: 30.0)
        slide_type    = (@properties[:slide_type] || :telescopica).to_sym

        o_width  = effective_opening_width(opening)
        o_height = @height_mm > 0 ? @height_mm : effective_opening_height(opening)
        o_depth  = effective_opening_depth(opening)

        # Dedução total da corrediça
        slide_deduction = Core::Constants::SLIDE_DEDUCTIONS[slide_type] || 25.4
        drawer_ext_w    = o_width - slide_deduction
        drawer_int_w    = drawer_ext_w - (2.0 * esp_corpo)
        drawer_depth    = o_depth - recuo_tras

        # Altura lateral da gaveta: frente - diferença para caixa
        frente_maior = ruleset.rule(:drawer, :front_overhang, fallback: 25.0)
        alt_lateral_min = ruleset.rule(:drawer, :min_side_height, fallback: 80.0)
        alt_lateral = [o_height - frente_maior, alt_lateral_min].max

        # Traseira: mesma altura que lateral para oculta, senão desconta fundo
        alt_traseira = if slide_type == :oculta
                         alt_lateral
                       else
                         alt_lateral - esp_fundo_gav
                       end

        # Tandembox: não gera laterais MDF (são perfis metálicos)
        usa_lateral_mdf = (slide_type != :tandembox)

        # Se tandembox, largura do fundo é diferente
        if slide_type == :tandembox
          deducao_base = Core::Constants::SLIDE_DEDUCTIONS[:tandembox]
          fundo_w = o_width - deducao_base
          fundo_int_w = fundo_w
        else
          fundo_w = drawer_int_w
          fundo_int_w = drawer_int_w
        end

        # Para oculta: fundo = largura externa (apoio nos trilhos)
        if slide_type == :oculta
          esp_fundo_gav = [esp_fundo_gav, 12].max  # mín 12mm para oculta
          fundo_w = drawer_ext_w
        end

        # Comprimento da corrediça (snap para tamanhos comerciais)
        slide_length = Core::Config.snap_slide_length(drawer_depth)

        @width_mm  = drawer_ext_w.round(1)
        @depth_mm  = drawer_depth.round(1)

        # Frente: sobreposição total — cobre vão + espessura corpo
        frente_w = o_width + (2.0 * esp_corpo) - (2.0 * folga)
        frente_h = o_height

        parts = []

        # 1. Frente da gaveta (fita nos 4 lados)
        parts << {
          ornato_id:        Core::Ids.generate,
          module_id:        @module_id,
          aggregate_id:     @ornato_id,
          name:             'Frente Gaveta',
          part_type:        :drawer,
          part_code:        Core::Constants::PART_CODES[:frente_gaveta],
          width_mm:         frente_w.round(1),
          height_mm:        frente_h.round(1),
          thickness_nominal: esp_frente,
          thickness_real:   Core::Config.real_thickness(esp_frente),
          material_id:      @material_id || mod.front_material_id,
          grain_direction:  :height,
          quantity:          1,
          edgeband: { front: true, back: true, top: true, bottom: true }
        }

        if usa_lateral_mdf
          # 2. Laterais da gaveta (x2) — fita apenas no topo
          parts << {
            ornato_id:        Core::Ids.generate,
            module_id:        @module_id,
            aggregate_id:     @ornato_id,
            name:             'Lateral Gaveta',
            part_type:        :drawer,
            part_code:        Core::Constants::PART_CODES[:lateral_gaveta],
            width_mm:         drawer_depth.round(1),
            height_mm:        alt_lateral.round(1),
            thickness_nominal: esp_corpo,
            thickness_real:   Core::Config.real_thickness(esp_corpo),
            material_id:      mod.body_material_id,
            grain_direction:  :width,
            quantity:          2,
            edgeband: { front: false, back: false, top: true, bottom: false }
          }

          # 3. Traseira da gaveta — fita apenas no topo
          parts << {
            ornato_id:        Core::Ids.generate,
            module_id:        @module_id,
            aggregate_id:     @ornato_id,
            name:             'Traseira Gaveta',
            part_type:        :drawer,
            part_code:        Core::Constants::PART_CODES[:traseira_gaveta],
            width_mm:         drawer_int_w.round(1),
            height_mm:        alt_traseira.round(1),
            thickness_nominal: esp_corpo,
            thickness_real:   Core::Config.real_thickness(esp_corpo),
            material_id:      mod.body_material_id,
            grain_direction:  :width,
            quantity:          1,
            edgeband: { front: false, back: false, top: true, bottom: false }
          }
        end

        # 4. Fundo da gaveta (sem fita)
        parts << {
          ornato_id:        Core::Ids.generate,
          module_id:        @module_id,
          aggregate_id:     @ornato_id,
          name:             'Fundo Gaveta',
          part_type:        :drawer,
          part_code:        Core::Constants::PART_CODES[:fundo_gaveta],
          width_mm:         fundo_w.round(1),
          height_mm:        drawer_depth.round(1),
          thickness_nominal: esp_fundo_gav,
          thickness_real:   Core::Config.real_thickness(esp_fundo_gav),
          material_id:      mod.back_material_id,
          grain_direction:  :none,
          quantity:          1,
          edgeband: { front: false, back: false, top: false, bottom: false }
        }

        # Salvar propriedades calculadas para uso posterior (hardware/operations)
        @properties[:slide_type]     = slide_type
        @properties[:slide_length]   = slide_length
        @properties[:drawer_ext_w]   = drawer_ext_w.round(1)
        @properties[:drawer_int_w]   = drawer_int_w.round(1)
        @properties[:drawer_depth]   = drawer_depth.round(1)
        @properties[:alt_lateral]    = alt_lateral.round(1)
        @properties[:uses_mdf_sides] = usa_lateral_mdf

        parts
      end

      # Gera peça de prateleira (fixa ou regulável).
      # Prateleira fixa: fita apenas na frente.
      # Prateleira regulável: fita apenas na frente.
      #
      # @param opening [Opening] abertura
      # @param mod [ModEntity] módulo pai
      # @param ruleset [RuleSet] regras construtivas
      # @return [Array<Hash>] 1 peça
      def generate_shelf_parts(opening, mod, ruleset)
        body_thick  = resolve_body_thickness(mod, ruleset)
        recuo_front = ruleset.rule(:shelf, :front_setback, fallback: 2.0)
        recuo_back  = ruleset.rule(:shelf, :back_setback, fallback: 0.0)

        o_width = effective_opening_width(opening)
        o_depth = effective_opening_depth(opening)

        shelf_w = o_width
        shelf_d = o_depth - recuo_front - recuo_back

        @width_mm = shelf_w.round(1)
        @depth_mm = shelf_d.round(1)

        is_fixed = (@aggregate_type == :prateleira_fixa)
        part_code = is_fixed ? Core::Constants::PART_CODES[:prateleira_fixa]
                             : Core::Constants::PART_CODES[:prateleira_reg]

        [{
          ornato_id:        Core::Ids.generate,
          module_id:        @module_id,
          aggregate_id:     @ornato_id,
          name:             is_fixed ? 'Prateleira Fixa' : 'Prateleira',
          part_type:        :shelf,
          part_code:        part_code,
          width_mm:         shelf_w.round(1),
          height_mm:        shelf_d.round(1),
          thickness_nominal: @thickness_nominal || body_thick,
          thickness_real:   Core::Config.real_thickness(@thickness_nominal || body_thick),
          material_id:      @material_id || mod.body_material_id,
          grain_direction:  :width,
          quantity:          1,
          edgeband: { front: true, back: false, top: false, bottom: false }
        }]
      end

      # Gera peça de divisória vertical.
      # Fita apenas na frente.
      #
      # @param opening [Opening] abertura
      # @param mod [ModEntity] módulo pai
      # @param ruleset [RuleSet] regras construtivas
      # @return [Array<Hash>] 1 peça
      def generate_divider_parts(opening, mod, ruleset)
        body_thick = resolve_body_thickness(mod, ruleset)

        o_height = effective_opening_height(opening)
        o_depth  = effective_opening_depth(opening)

        @height_mm = o_height.round(1)
        @depth_mm  = o_depth.round(1)

        [{
          ornato_id:        Core::Ids.generate,
          module_id:        @module_id,
          aggregate_id:     @ornato_id,
          name:             'Divisória Vertical',
          part_type:        :divider,
          part_code:        Core::Constants::PART_CODES[:divisoria],
          width_mm:         o_height.round(1),
          height_mm:        o_depth.round(1),
          thickness_nominal: @thickness_nominal || body_thick,
          thickness_real:   Core::Config.real_thickness(@thickness_nominal || body_thick),
          material_id:      @material_id || mod.body_material_id,
          grain_direction:  :height,
          quantity:          1,
          edgeband: { front: true, back: false, top: false, bottom: false }
        }]
      end

      # Gera peça de fundo (traseira do módulo).
      # Sem fita de borda.
      #
      # @param opening [Opening] abertura
      # @param mod [ModEntity] módulo pai
      # @param ruleset [RuleSet] regras construtivas
      # @return [Array<Hash>] 1 peça
      def generate_back_parts(opening, mod, ruleset)
        back_thick = mod.back_thickness || ruleset.rule(:thicknesses, :back, fallback: 3)

        o_width  = effective_opening_width(opening)
        o_height = effective_opening_height(opening)

        @width_mm  = o_width.round(1)
        @height_mm = o_height.round(1)
        @depth_mm  = back_thick.to_f

        [{
          ornato_id:        Core::Ids.generate,
          module_id:        @module_id,
          aggregate_id:     @ornato_id,
          name:             'Fundo',
          part_type:        :back,
          part_code:        Core::Constants::PART_CODES[:fundo],
          width_mm:         o_width.round(1),
          height_mm:        o_height.round(1),
          thickness_nominal: back_thick,
          thickness_real:   Core::Config.real_thickness(back_thick),
          material_id:      @material_id || mod.back_material_id,
          grain_direction:  :none,
          quantity:          1,
          edgeband: { front: false, back: false, top: false, bottom: false }
        }]
      end

      # ══════════════════════════════════════════════════════════════════
      #  GERAÇÃO DE FERRAGENS
      # ══════════════════════════════════════════════════════════════════

      # Ferragens de porta: dobradiças (quantidade pela altura) + puxador.
      #
      # @param context [Hash]
      # @return [Array<Hash>]
      def generate_door_hardware(context)
        door_h = @height_mm
        hinge_count = calculate_hinge_count(door_h)
        hinge_positions = calculate_hinge_positions(door_h, hinge_count)

        hardware = []

        # Dobradiças (caneco 35mm)
        hardware << {
          ornato_id:    Core::Ids.generate,
          module_id:    @module_id,
          aggregate_id: @ornato_id,
          name:         'Dobradiça 110° c/ amortecedor',
          hardware_type: :dobradiça,
          quantity:     hinge_count,
          properties:   {
            angle:     110,
            cup_diameter: 35.0,
            positions: hinge_positions,
            side:      @side || :esquerda
          }
        }

        # Puxador (1 por porta)
        puxador_type = @properties[:handle_type] || 'Puxador padrão'
        hardware << {
          ornato_id:    Core::Ids.generate,
          module_id:    @module_id,
          aggregate_id: @ornato_id,
          name:         puxador_type,
          hardware_type: :puxador,
          quantity:     1,
          properties:   { side: @side || :esquerda }
        }

        hardware
      end

      # Ferragens de porta de correr: trilho superior/inferior.
      #
      # @param context [Hash]
      # @return [Array<Hash>]
      def generate_sliding_door_hardware(context)
        num_panels = (@properties[:panel_count] || 2).to_i
        opening = context[:opening]
        track_length = effective_opening_width(opening)

        hardware = []

        # Trilho superior
        hardware << {
          ornato_id:    Core::Ids.generate,
          module_id:    @module_id,
          aggregate_id: @ornato_id,
          name:         "Trilho superior #{num_panels} vias",
          hardware_type: :trilho,
          quantity:     1,
          properties:   {
            position: :top,
            lanes: num_panels,
            length_mm: track_length.round(1)
          }
        }

        # Trilho inferior
        hardware << {
          ornato_id:    Core::Ids.generate,
          module_id:    @module_id,
          aggregate_id: @ornato_id,
          name:         "Trilho inferior #{num_panels} vias",
          hardware_type: :trilho,
          quantity:     1,
          properties:   {
            position: :bottom,
            lanes: num_panels,
            length_mm: track_length.round(1)
          }
        }

        hardware
      end

      # Ferragens de gaveta: corrediças (1 par).
      #
      # @param context [Hash]
      # @return [Array<Hash>]
      def generate_drawer_hardware(context)
        slide_type   = (@properties[:slide_type] || :telescopica).to_sym
        slide_length = @properties[:slide_length] || 450

        slide_names = {
          telescopica: 'Corrediça Telescópica',
          oculta:      'Corrediça Oculta TANDEM',
          tandembox:   'Corrediça Tandembox',
          roller:      'Corrediça Roller'
        }

        hardware = []

        # Corrediças (1 par = 2 trilhos)
        hardware << {
          ornato_id:    Core::Ids.generate,
          module_id:    @module_id,
          aggregate_id: @ornato_id,
          name:         "#{slide_names[slide_type] || 'Corrediça'} #{slide_length}mm",
          hardware_type: :corrediça,
          quantity:     1, # 1 par
          properties:   {
            slide_type:  slide_type,
            length_mm:   slide_length,
            full_extension: (slide_type != :roller)
          }
        }

        # Ferragens extras por tipo de corrediça
        case slide_type
        when :tandembox
          hardware << {
            ornato_id:    Core::Ids.generate,
            module_id:    @module_id,
            aggregate_id: @ornato_id,
            name:         'Perfil Tandembox lateral',
            hardware_type: :perfil,
            quantity:     1, # 1 par
            properties:   { profile_code: @properties[:tandembox_profile] || 'M' }
          }
          hardware << {
            ornato_id:    Core::Ids.generate,
            module_id:    @module_id,
            aggregate_id: @ornato_id,
            name:         'Bracket traseiro Tandembox',
            hardware_type: :conector,
            quantity:     1, # 1 par
            properties:   {}
          }
          hardware << {
            ornato_id:    Core::Ids.generate,
            module_id:    @module_id,
            aggregate_id: @ornato_id,
            name:         'Fixação frontal INSERTA',
            hardware_type: :conector,
            quantity:     1, # 1 par
            properties:   {}
          }
        when :oculta
          hardware << {
            ornato_id:    Core::Ids.generate,
            module_id:    @module_id,
            aggregate_id: @ornato_id,
            name:         'Bracket traseiro TANDEM',
            hardware_type: :conector,
            quantity:     1, # 1 par
            properties:   {}
          }
          hardware << {
            ornato_id:    Core::Ids.generate,
            module_id:    @module_id,
            aggregate_id: @ornato_id,
            name:         'Locking device (fixação frontal)',
            hardware_type: :conector,
            quantity:     1, # 1 par
            properties:   {}
          }
        end

        hardware
      end

      # Ferragens de prateleira regulável: 4 suportes (pinos Ø5mm).
      #
      # @param context [Hash]
      # @return [Array<Hash>]
      def generate_shelf_hardware(context)
        [{
          ornato_id:    Core::Ids.generate,
          module_id:    @module_id,
          aggregate_id: @ornato_id,
          name:         'Suporte prateleira Ø5mm',
          hardware_type: :suporte,
          quantity:     4,
          properties:   { diameter: 5.0, material: 'metal' }
        }]
      end

      # Ferragens de peça fixa: minifix + cavilhas.
      #
      # @param context [Hash]
      # @return [Array<Hash>]
      def generate_fixed_hardware(context)
        hardware = []

        hardware << {
          ornato_id:    Core::Ids.generate,
          module_id:    @module_id,
          aggregate_id: @ornato_id,
          name:         'Minifix',
          hardware_type: :minifix,
          quantity:     4,
          properties:   {}
        }

        hardware << {
          ornato_id:    Core::Ids.generate,
          module_id:    @module_id,
          aggregate_id: @ornato_id,
          name:         'Cavilha 8x30mm',
          hardware_type: :cavilha,
          quantity:     4,
          properties:   { diameter: 8.0, length: 30.0 }
        }

        hardware
      end

      # ══════════════════════════════════════════════════════════════════
      #  GERAÇÃO DE OPERAÇÕES CNC
      # ══════════════════════════════════════════════════════════════════

      # Operações de porta: furação para caneco de dobradiça (35mm).
      #
      # @param context [Hash]
      # @return [Array<Hash>]
      def generate_door_operations(context)
        door_h = @height_mm
        hinge_count = calculate_hinge_count(door_h)
        hinge_positions = calculate_hinge_positions(door_h, hinge_count)

        # Setback da dobradiça: borda lateral ao centro do caneco
        hinge_setback = 22.5  # mm da borda (padrão Blum/Hettich)

        hinge_positions.map do |y_pos|
          {
            ornato_id:      Core::Ids.generate,
            module_id:      @module_id,
            aggregate_id:   @ornato_id,
            operation_type: :furacao,
            operation_code: Core::Constants::OPERATION_CODES[:furacao],
            name:           'Caneco dobradiça 35mm',
            face:           :back,  # face traseira da porta
            tool:           'f_35mm_dob',
            x_mm:           hinge_setback,
            y_mm:           y_pos,
            z_mm:           0.0,
            diameter_mm:    35.0,
            depth_mm:       12.5,  # profundidade padrão caneco
            properties:     { hinge_side: @side || :esquerda }
          }
        end
      end

      # Operações de gaveta: canal para encaixe do fundo.
      # Canal nas laterais e traseira a ~10mm da base, largura = espessura do fundo.
      #
      # @param context [Hash]
      # @return [Array<Hash>]
      def generate_drawer_operations(context)
        slide_type    = (@properties[:slide_type] || :telescopica).to_sym
        esp_fundo     = context[:ruleset]&.rule(:drawer, :bottom_thickness, fallback: 3) || 3
        canal_setback = 10.0  # mm da base da lateral ao centro do canal

        operations = []

        # Somente gera canal se usa laterais MDF (não tandembox)
        if @properties[:uses_mdf_sides] != false
          # Canal na lateral esquerda
          operations << {
            ornato_id:      Core::Ids.generate,
            module_id:      @module_id,
            aggregate_id:   @ornato_id,
            operation_type: :canal,
            operation_code: Core::Constants::OPERATION_CODES[:canal],
            name:           'Canal fundo gaveta (lateral)',
            face:           :right, # face interna da lateral
            tool:           "f_#{esp_fundo}mm_canal",
            x_mm:           0.0,
            y_mm:           canal_setback,
            z_mm:           0.0,
            width_mm:       Core::Config.real_thickness(esp_fundo),
            depth_mm:       (esp_fundo / 2.0).round(1),
            length_mm:      @properties[:drawer_depth] || 0.0,
            properties:     { applies_to: :lateral, quantity: 2 }
          }

          # Canal na traseira
          operations << {
            ornato_id:      Core::Ids.generate,
            module_id:      @module_id,
            aggregate_id:   @ornato_id,
            operation_type: :canal,
            operation_code: Core::Constants::OPERATION_CODES[:canal],
            name:           'Canal fundo gaveta (traseira)',
            face:           :front,
            tool:           "f_#{esp_fundo}mm_canal",
            x_mm:           0.0,
            y_mm:           canal_setback,
            z_mm:           0.0,
            width_mm:       Core::Config.real_thickness(esp_fundo),
            depth_mm:       (esp_fundo / 2.0).round(1),
            length_mm:      @properties[:drawer_int_w] || 0.0,
            properties:     { applies_to: :traseira, quantity: 1 }
          }
        end

        operations
      end

      # Operações de peça fixa: furação para minifix (15mm) e cavilha (8mm).
      # Aplica-se a prateleiras fixas e divisórias.
      #
      # @param context [Hash]
      # @return [Array<Hash>]
      def generate_fixed_operations(context)
        operations = []

        # Furação minifix: 15mm diâmetro, 12.5mm profundidade
        # 2 furos por lado (4 total) a ~50mm de cada borda
        minifix_setback = 50.0  # mm da borda frontal/traseira
        minifix_inset   = 32.0  # mm da borda lateral (sistema 32)

        [minifix_setback, @depth_mm - minifix_setback].each do |y_pos|
          operations << {
            ornato_id:      Core::Ids.generate,
            module_id:      @module_id,
            aggregate_id:   @ornato_id,
            operation_type: :furacao,
            operation_code: Core::Constants::OPERATION_CODES[:furacao],
            name:           'Minifix 15mm (peça)',
            face:           :bottom,
            tool:           'f_15mm_tambor_min',
            x_mm:           minifix_inset,
            y_mm:           y_pos,
            z_mm:           0.0,
            diameter_mm:    15.0,
            depth_mm:       12.5,
            properties:     { connector: :minifix, side: :left }
          }
          operations << {
            ornato_id:      Core::Ids.generate,
            module_id:      @module_id,
            aggregate_id:   @ornato_id,
            operation_type: :furacao,
            operation_code: Core::Constants::OPERATION_CODES[:furacao],
            name:           'Minifix 15mm (peça)',
            face:           :bottom,
            tool:           'f_15mm_tambor_min',
            x_mm:           (@width_mm || 0) - minifix_inset,
            y_mm:           y_pos,
            z_mm:           0.0,
            diameter_mm:    15.0,
            depth_mm:       12.5,
            properties:     { connector: :minifix, side: :right }
          }
        end

        # Furação cavilha: 8mm diâmetro, 15mm profundidade
        # Mesma posição dos minifix mas deslocada ~32mm
        cavilha_offset = 64.0  # segundo furo do sistema 32
        [minifix_setback, @depth_mm - minifix_setback].each do |y_pos|
          operations << {
            ornato_id:      Core::Ids.generate,
            module_id:      @module_id,
            aggregate_id:   @ornato_id,
            operation_type: :furacao,
            operation_code: Core::Constants::OPERATION_CODES[:furacao],
            name:           'Cavilha 8mm (peça)',
            face:           :bottom,
            tool:           'f_8mm_cavilha',
            x_mm:           cavilha_offset,
            y_mm:           y_pos,
            z_mm:           0.0,
            diameter_mm:    8.0,
            depth_mm:       15.0,
            properties:     { connector: :cavilha, side: :left }
          }
          operations << {
            ornato_id:      Core::Ids.generate,
            module_id:      @module_id,
            aggregate_id:   @ornato_id,
            operation_type: :furacao,
            operation_code: Core::Constants::OPERATION_CODES[:furacao],
            name:           'Cavilha 8mm (peça)',
            face:           :bottom,
            tool:           'f_8mm_cavilha',
            x_mm:           (@width_mm || 0) - cavilha_offset,
            y_mm:           y_pos,
            z_mm:           0.0,
            diameter_mm:    8.0,
            depth_mm:       15.0,
            properties:     { connector: :cavilha, side: :right }
          }
        end

        operations
      end

      # ══════════════════════════════════════════════════════════════════
      #  HELPERS PRIVADOS
      # ══════════════════════════════════════════════════════════════════

      # Resolve espessura do corpo a partir do módulo ou ruleset.
      # @param mod [ModEntity]
      # @param ruleset [RuleSet]
      # @return [Numeric]
      def resolve_body_thickness(mod, ruleset)
        mod.body_thickness || ruleset.rule(:thicknesses, :body, fallback: 15)
      end

      # Resolve espessura da frente a partir do agregado, módulo ou ruleset.
      # @param mod [ModEntity]
      # @param ruleset [RuleSet]
      # @return [Numeric]
      def resolve_front_thickness(mod, ruleset)
        @thickness_nominal || ruleset.rule(:thicknesses, :front, fallback: 18)
      end

      # Largura efetiva da abertura (usa override do agregado se > 0).
      # @param opening [Opening, #width_mm]
      # @return [Float]
      def effective_opening_width(opening)
        (@width_mm > 0 ? @width_mm : opening.width_mm).to_f
      end

      # Altura efetiva da abertura.
      # @param opening [Opening, #height_mm]
      # @return [Float]
      def effective_opening_height(opening)
        (@height_mm > 0 ? @height_mm : opening.height_mm).to_f
      end

      # Profundidade efetiva da abertura.
      # @param opening [Opening, #depth_mm]
      # @return [Float]
      def effective_opening_depth(opening)
        (@depth_mm > 0 ? @depth_mm : opening.depth_mm).to_f
      end
    end
  end
end
