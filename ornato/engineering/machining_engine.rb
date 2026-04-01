# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# engineering/machining_engine.rb — Motor de usinagem CNC
#
# Gera operações de usinagem:
#   - Canal de fundo (rasgo para fundo encaixado)
#   - Canal de gaveta (rasgo para fundo de gaveta)
#   - Rebaixo para dobradiças
#   - Fresagem de cava (puxador embutido)
#   - Pocket para iluminação
#
# Cada operação se torna uma Operation associada a uma Part.

module Ornato
  module Engineering
    class MachiningEngine
      # Gera canal de fundo em laterais e base.
      # O canal corre ao longo do COMPRIMENTO (length) da peça,
      # posicionado na borda TRASEIRA — ou seja, na dimensão de
      # profundidade (depth) da lateral, não na largura (width).
      #
      # @param part [Domain::Part] peça onde criar o canal
      # @param back_thickness [Integer] espessura nominal do fundo
      # @param groove_depth [Float] profundidade do canal (default: 8mm)
      # @return [Domain::Operation]
      def generate_back_groove(part, back_thickness, groove_depth: 8.0)
        groove_width = Core::Config.real_thickness(back_thickness) + 0.5

        # O canal fica na borda traseira: posição X = profundidade da peça
        # (depth_mm) menos a profundidade de corte do canal.
        # O canal corre ao longo do comprimento (length_mm) da lateral.
        Domain::Operation.new(
          parent_part_id: part.ornato_id,
          operation_type: :canal,
          face: :back,
          x_mm: part.depth_mm - groove_depth,
          y_mm: 0.0,
          depth_mm: groove_depth,
          tool_diameter_mm: groove_width,
          tool_id: 'f_6mm_canal',
          length_mm: part.length_mm,
          description: "Canal Fundo #{part.name}"
        )
      rescue StandardError => e
        raise MachiningError, "Falha ao gerar canal de fundo para #{part.name}: #{e.message}"
      end

      # Gera canal para fundo de gaveta.
      # O canal corre ao longo do COMPRIMENTO (length) da peça lateral/traseira,
      # posicionado na parte INFERIOR (Y = groove_height_mm desde a base).
      #
      # @param part [Domain::Part] lateral ou traseira da gaveta
      # @param bottom_thickness [Integer] espessura do fundo (6mm padrão HDF)
      # @param groove_height_mm [Float] altura do canal (distância da base)
      # @return [Domain::Operation]
      def generate_drawer_bottom_groove(part, bottom_thickness: 6, groove_height_mm: 10.0)
        groove_width = Core::Config.real_thickness(bottom_thickness) + 0.5

        # X fixo em 0 (começo da peça), Y na altura especificada desde a base.
        # O canal corre ao longo do comprimento (length_mm) da peça.
        Domain::Operation.new(
          parent_part_id: part.ornato_id,
          operation_type: :canal,
          face: :back,
          x_mm: 0.0,
          y_mm: groove_height_mm,
          depth_mm: 8.0,
          tool_diameter_mm: groove_width,
          tool_id: 'f_6mm_canal',
          length_mm: part.length_mm,
          width_mm: groove_width,
          description: "Canal Fundo Gaveta #{part.name}"
        )
      rescue StandardError => e
        raise MachiningError, "Falha ao gerar canal de gaveta para #{part.name}: #{e.message}"
      end

      # Gera fresagem de cava (puxador embutido).
      # Lida corretamente com peças rotacionadas usando as dimensões
      # reais (width_mm / length_mm) em vez de cut_width / cut_length
      # que podem estar trocadas após rotação.
      #
      # @param part [Domain::Part] porta ou frente de gaveta
      # @param cava_depth [Float] profundidade da cava (default: 15mm)
      # @param cava_width [Float] largura da cava (default: 40mm)
      # @param position [Symbol] :top, :bottom, :left, :right
      # @return [Domain::Operation]
      def generate_cava(part, cava_depth: 15.0, cava_width: 40.0, position: :top)
        # Usar dimensões reais da peça para evitar problemas com rotação
        w = part.width_mm
        l = part.length_mm

        raise ArgumentError, "Largura da peça (#{w}) menor que cava_width (#{cava_width})" if position == :top && w < cava_width
        raise ArgumentError, "Largura da peça (#{w}) menor que cava_width (#{cava_width})" if position == :bottom && w < cava_width
        raise ArgumentError, "Comprimento da peça (#{l}) menor que cava_width (#{cava_width})" if position == :left && l < cava_width
        raise ArgumentError, "Comprimento da peça (#{l}) menor que cava_width (#{cava_width})" if position == :right && l < cava_width

        x, y, length = case position
                        when :top
                          [0.0, l - cava_width, w]
                        when :bottom
                          [0.0, 0.0, w]
                        when :left
                          [0.0, 0.0, l]
                        when :right
                          [w - cava_width, 0.0, l]
                        else
                          raise ArgumentError, "Posição inválida: #{position}. Use :top, :bottom, :left ou :right"
                        end

        Domain::Operation.new(
          parent_part_id: part.ornato_id,
          operation_type: :cava,
          face: :front,
          x_mm: x,
          y_mm: y,
          depth_mm: cava_depth,
          tool_diameter_mm: 6.0,
          tool_id: 'f_6mm_canal',
          length_mm: length,
          width_mm: cava_width,
          description: "Cava #{position} #{part.name}"
        )
      rescue ArgumentError
        raise
      rescue StandardError => e
        raise MachiningError, "Falha ao gerar cava para #{part.name}: #{e.message}"
      end

      # Gera rebaixo para encaixe de dobradiça na lateral.
      # Suporta diferentes modelos de dobradiça via parâmetros de tamanho.
      #
      # Tamanhos comuns:
      #   Blum CLIP top O35:     50 x 36 mm (padrão)
      #   Blum CLIP top O110:    52 x 38 mm
      #   Hettich Sensys:        48 x 34 mm
      #   Grass Tiomos:          49 x 35 mm
      #
      # @param lateral [Domain::Part]
      # @param hinge_positions [Array<Float>] posições Y das dobradiças
      # @param plate_length [Float] comprimento da placa (default: 50mm — Blum O35)
      # @param plate_width [Float] largura da placa (default: 36mm — Blum O35)
      # @param rebate_depth [Float] profundidade do rebaixo (default: 2mm)
      # @return [Array<Domain::Operation>]
      def generate_hinge_plate_rebates(lateral, hinge_positions, plate_length: 50.0, plate_width: 36.0, rebate_depth: 2.0)
        hinge_positions.map.with_index do |y, i|
          Domain::Operation.new(
            parent_part_id: lateral.ornato_id,
            operation_type: :rebaixo,
            face: :left,
            x_mm: 0.0,
            y_mm: y - (plate_length / 2.0),  # centralizar o rebaixo
            depth_mm: rebate_depth,
            tool_diameter_mm: 10.0,
            tool_id: 'f_10mm',
            length_mm: plate_length,
            width_mm: plate_width,
            description: "Rebaixo Dobradiça #{i + 1}"
          )
        end
      rescue StandardError => e
        raise MachiningError, "Falha ao gerar rebaixos de dobradiça para #{lateral.name}: #{e.message}"
      end

      # Gera pocket retangular (para iluminação LED, etc.).
      # @param part [Domain::Part]
      # @param x [Float], y [Float] posição
      # @param width [Float], length [Float] dimensões
      # @param depth [Float] profundidade
      # @return [Domain::Operation]
      def generate_pocket(part, x:, y:, width:, length:, depth:)
        Domain::Operation.new(
          parent_part_id: part.ornato_id,
          operation_type: :pocket,
          face: :top,
          x_mm: x,
          y_mm: y,
          depth_mm: depth,
          tool_diameter_mm: 6.0,
          tool_id: 'f_6mm_canal',
          length_mm: length,
          width_mm: width,
          description: "Pocket #{part.name}"
        )
      rescue StandardError => e
        raise MachiningError, "Falha ao gerar pocket para #{part.name}: #{e.message}"
      end
    end

    # Erro específico do motor de usinagem
    class MachiningError < StandardError; end
  end
end
