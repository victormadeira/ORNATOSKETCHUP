# ornato_plugin/models/vao.rb — Modelo de vão (espaço interno que aceita agregados)

module Ornato
  module Models
    class Vao
      attr_accessor :id, :x, :y, :z, :largura, :altura, :profundidade,
                    :agregados, :sub_vaos, :parent_vao

      # x, y, z: posição relativa dentro do módulo (mm)
      # largura, altura, profundidade: dimensões internas do vão (mm)
      def initialize(opts = {})
        @id           = opts[:id] || Utils.gerar_id
        @x            = opts[:x] || 0
        @y            = opts[:y] || 0
        @z            = opts[:z] || 0
        @largura      = opts[:largura] || 0
        @altura       = opts[:altura] || 0
        @profundidade = opts[:profundidade] || 0
        @agregados    = []      # lista de agregados neste vão
        @sub_vaos     = []      # sub-vãos criados por divisórias
        @parent_vao   = opts[:parent_vao]
      end

      # Verifica se o vão foi subdividido
      def subdividido?
        !@sub_vaos.empty?
      end

      # Adiciona um agregado ao vão
      def adicionar_agregado(agregado)
        @agregados << agregado
      end

      # Subdivide o vão verticalmente na posição dada (mm da esquerda)
      # Retorna [vao_esquerdo, vao_direito]
      def dividir_vertical(posicao_mm, espessura_divisoria = 15)
        larg_esq = posicao_mm - (espessura_divisoria / 2.0)
        larg_dir = @largura - posicao_mm - (espessura_divisoria / 2.0)

        vao_esq = Vao.new(
          x: @x, y: @y, z: @z,
          largura: larg_esq, altura: @altura, profundidade: @profundidade,
          parent_vao: self
        )
        vao_dir = Vao.new(
          x: @x + posicao_mm + (espessura_divisoria / 2.0), y: @y, z: @z,
          largura: larg_dir, altura: @altura, profundidade: @profundidade,
          parent_vao: self
        )

        @sub_vaos = [vao_esq, vao_dir]
        [vao_esq, vao_dir]
      end

      # Subdivide o vão horizontalmente na posição dada (mm da base)
      # Retorna [vao_inferior, vao_superior]
      def dividir_horizontal(posicao_mm, espessura_divisoria = 15)
        alt_inf = posicao_mm - (espessura_divisoria / 2.0)
        alt_sup = @altura - posicao_mm - (espessura_divisoria / 2.0)

        vao_inf = Vao.new(
          x: @x, y: @y, z: @z,
          largura: @largura, altura: alt_inf, profundidade: @profundidade,
          parent_vao: self
        )
        vao_sup = Vao.new(
          x: @x, y: @y, z: @z + posicao_mm + (espessura_divisoria / 2.0),
          largura: @largura, altura: alt_sup, profundidade: @profundidade,
          parent_vao: self
        )

        @sub_vaos = [vao_inf, vao_sup]
        [vao_inf, vao_sup]
      end

      # Retorna todos os vãos-folha (sem sub-divisões) recursivamente
      def vaos_folha
        return [self] unless subdividido?
        @sub_vaos.flat_map(&:vaos_folha)
      end

      # Verifica se um ponto (px, pz) está dentro do vão (2D: largura × altura)
      def contem?(px, pz)
        px >= @x && px <= (@x + @largura) &&
          pz >= @z && pz <= (@z + @altura)
      end

      # Encontra o vão-folha que contém o ponto
      def encontrar_vao(px, pz)
        return nil unless contem?(px, pz)
        if subdividido?
          @sub_vaos.each do |sv|
            resultado = sv.encontrar_vao(px, pz)
            return resultado if resultado
          end
          nil
        else
          self
        end
      end

      def to_hash
        {
          id: @id, x: @x, y: @y, z: @z,
          largura: @largura, altura: @altura, profundidade: @profundidade,
          agregados: @agregados.map { |a| a.respond_to?(:to_hash) ? a.to_hash : a.to_s },
          sub_vaos: @sub_vaos.map(&:to_hash)
        }
      end
    end
  end
end
