# ornato_plugin/models/peca.rb — Modelo de dados de uma peça de corte

module Ornato
  module Models
    class Peca
      attr_accessor :nome, :comprimento, :largura, :espessura,
                    :quantidade, :material, :tipo,
                    :fita_frente, :fita_topo, :fita_tras, :fita_base,
                    :fita_material, :grupo_ref

      # tipo: :lateral, :base, :topo, :fundo, :prateleira, :divisoria,
      #       :porta, :frente_gaveta, :lateral_gaveta, :traseira_gaveta, :fundo_gaveta
      def initialize(opts = {})
        @nome        = opts[:nome] || 'Peça'
        @comprimento = opts[:comprimento] || 0  # mm (maior dimensão)
        @largura     = opts[:largura] || 0      # mm (menor dimensão)
        @espessura   = opts[:espessura] || 15   # mm
        @quantidade  = opts[:quantidade] || 1
        @material    = opts[:material] || 'MDF Branco 15mm'
        @tipo        = opts[:tipo] || :generica
        @fita_frente = opts[:fita_frente] || false
        @fita_topo   = opts[:fita_topo] || false
        @fita_tras   = opts[:fita_tras] || false
        @fita_base   = opts[:fita_base] || false
        @fita_material = opts[:fita_material] || 'PVC 1mm'
        @grupo_ref   = opts[:grupo_ref]  # referência ao grupo SketchUp
      end

      # Código visual de fita: ■□□□
      def fita_codigo
        [
          @fita_frente ? '■' : '□',
          @fita_topo   ? '■' : '□',
          @fita_tras   ? '■' : '□',
          @fita_base   ? '■' : '□'
        ].join
      end

      # Metros lineares de fita total
      def fita_metros
        total = 0.0
        total += @comprimento if @fita_frente
        total += @largura     if @fita_topo
        total += @comprimento if @fita_tras
        total += @largura     if @fita_base
        (total / 1000.0) * @quantidade
      end

      # Área em m²
      def area_m2
        (@comprimento * @largura / 1_000_000.0) * @quantidade
      end

      def to_hash
        {
          nome: @nome, comprimento: @comprimento, largura: @largura,
          espessura: @espessura, quantidade: @quantidade, material: @material,
          tipo: @tipo, fita: fita_codigo, fita_metros: fita_metros.round(3),
          area_m2: area_m2.round(4)
        }
      end
    end
  end
end
