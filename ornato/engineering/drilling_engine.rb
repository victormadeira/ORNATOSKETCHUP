# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/drilling_engine.rb — Motor de furacao
#
# Gera padroes de furacao:
#   - Sistema 32 (linhas de furos para prateleiras regulaveis)
#   - Furacao de conectores (minifix, cavilha)
#   - Furacao de dobradicas (caneco 35mm)
#   - Furacao de corredicas
#
# Todos os parametros vem de GlobalConfig — nada hardcoded.

module Ornato
  module Engineering
    class DrillingEngine

      # Gera furacao Sistema 32 em uma lateral.
      # @param lateral [Domain::Part] peca lateral
      # @param options [Hash] configuracoes
      # @return [Array<Domain::Operation>] operacoes de furacao
      def generate_system_32(lateral, options = {})
        s32 = GlobalConfig.get(:sistema_32)
        operations = []

        n_lines = options[:lines]   || s32[:linhas]        || 2
        start_y = options[:start_y] || s32[:inicio_mm]     || 37.0
        end_y   = options[:end_y]   || (lateral.length_mm - (s32[:fim_mm_do_topo] || 37.0))
        pitch   = s32[:pitch]        || 32.0
        setback = s32[:setback]      || 37.0
        depth   = s32[:profundidade] || 12.0
        dia     = s32[:diametro]     || 5.0

        n_furos = ((end_y - start_y) / pitch).floor + 1
        return operations unless n_furos > 0

        setbacks = if n_lines == 2
                     [setback, lateral.width_mm - setback]
                   elsif n_lines == 1
                     [setback]
                   else
                     positions = [setback]
                     spacing = (lateral.width_mm - 2 * setback) / (n_lines - 1)
                     (n_lines - 2).times { |i| positions << setback + (i + 1) * spacing }
                     positions << lateral.width_mm - setback
                     positions
                   end

        setbacks.each_with_index do |sb, line_idx|
          n_furos.times do |i|
            y = start_y + (i * pitch)
            op = Domain::Operation.new(
              parent_part_id: lateral.ornato_id,
              operation_type: :furacao,
              face: :left,
              x_mm: sb,
              y_mm: y,
              depth_mm: depth,
              tool_diameter_mm: dia,
              tool_id: "f_#{dia.to_i}mm",
              description: "S32_L#{line_idx + 1}_F#{i + 1}"
            )
            operations << op
          end
        end

        operations
      end

      # Gera furacao para minifix (conector excentrico).
      # @param part [Domain::Part]
      # @param positions [Array<Hash>] posicoes { x:, y:, face: }
      # @return [Array<Domain::Operation>]
      def generate_minifix_boring(part, positions)
        cfg = GlobalConfig.get(:minifix)
        positions.map do |pos|
          Domain::Operation.new(
            parent_part_id: part.ornato_id,
            operation_type: :furacao,
            face: pos[:face] || :top,
            x_mm: pos[:x],
            y_mm: pos[:y],
            depth_mm: cfg[:profundidade_bucha] || 13.0,
            tool_diameter_mm: cfg[:diametro_bucha] || 15.0,
            tool_id: 'f_15mm_tambor_min',
            description: "Minifix #{pos[:x]},#{pos[:y]}"
          )
        end
      end

      # Gera furacao para cavilhas.
      # @param part [Domain::Part]
      # @param positions [Array<Hash>]
      # @return [Array<Domain::Operation>]
      def generate_dowel_boring(part, positions)
        cfg = GlobalConfig.get(:cavilha)
        positions.map do |pos|
          Domain::Operation.new(
            parent_part_id: part.ornato_id,
            operation_type: :furacao,
            face: pos[:face] || :top,
            x_mm: pos[:x],
            y_mm: pos[:y],
            depth_mm: cfg[:profundidade_peca] || 12.0,
            tool_diameter_mm: cfg[:diametro] || 8.0,
            tool_id: "f_#{(cfg[:diametro] || 8).to_i}mm_cavilha",
            description: "Cavilha #{pos[:x]},#{pos[:y]}"
          )
        end
      end

      # Gera furacao de dobradica (caneco 35mm).
      # Parametros vem de GlobalConfig.dobradica (perfil de marca ativo).
      # @param door_part [Domain::Part]
      # @param hinge_positions [Array<Float>] posicoes Y
      # @return [Array<Domain::Operation>]
      def generate_hinge_boring(door_part, hinge_positions, setback_mm: nil)
        cfg = GlobalConfig.dobradica
        setback = setback_mm || cfg[:centro_copa] || 20.5

        hinge_positions.map.with_index do |y, i|
          Domain::Operation.new(
            parent_part_id: door_part.ornato_id,
            operation_type: :furacao,
            face: :back,
            x_mm: setback,
            y_mm: y,
            depth_mm: cfg[:profundidade_copa] || 13.0,
            tool_diameter_mm: cfg[:diametro_copa] || 35.0,
            tool_id: 'f_35mm_dob',
            description: "Caneco #{i + 1}"
          )
        end
      end

      # Gera furacao dos furos da base da dobradica na lateral.
      # @param lateral [Domain::Part]
      # @param hinge_positions [Array<Float>] posicoes Y de cada dobradica
      # @return [Array<Domain::Operation>]
      def generate_hinge_base_boring(lateral, hinge_positions)
        cfg = GlobalConfig.dobradica
        dist_base = cfg[:distancia_base] || 48.0
        dia_base = cfg[:diametro_base] || 5.0
        prof_base = cfg[:profundidade_base] || 12.0

        operations = []
        hinge_positions.each_with_index do |y, i|
          [-dist_base / 2.0, dist_base / 2.0].each_with_index do |offset, j|
            operations << Domain::Operation.new(
              parent_part_id: lateral.ornato_id,
              operation_type: :furacao,
              face: :left,
              x_mm: cfg[:distancia_base_centro] || 9.5,
              y_mm: y + offset,
              depth_mm: prof_base,
              tool_diameter_mm: dia_base,
              tool_id: "f_#{dia_base.to_i}mm",
              description: "Base Dob #{i + 1} F#{j + 1}"
            )
          end
        end
        operations
      end

      # Calcula posicoes de dobradicas baseado na altura da porta.
      # Usa regras de GlobalConfig (editaveis).
      # @param height_mm [Float] altura da porta
      # @return [Array<Float>] posicoes Y
      def calculate_hinge_positions(height_mm)
        cfg = GlobalConfig.dobradica
        count = GlobalConfig.quantidade_dobradicas(height_mm)
        top_offset = cfg[:setback_vertical_topo] || 100.0
        bottom_offset = cfg[:setback_vertical_base] || 100.0

        if count == 2
          [bottom_offset, height_mm - top_offset]
        else
          positions = [bottom_offset, height_mm - top_offset]
          remaining = count - 2
          spacing = (height_mm - bottom_offset - top_offset) / (remaining + 1)
          remaining.times { |i| positions << bottom_offset + (i + 1) * spacing }
          positions.sort
        end
      end

      # Conta numero de dobradicas necessarias pela altura.
      # Delegado para GlobalConfig (regras editaveis).
      def calculate_hinge_count(height_mm)
        GlobalConfig.quantidade_dobradicas(height_mm)
      end
    end
  end
end
