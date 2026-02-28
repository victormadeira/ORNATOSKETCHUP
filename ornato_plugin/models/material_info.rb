# ornato_plugin/models/material_info.rb — Sistema de materiais e cores

module Ornato
  module Models
    class MaterialInfo
      attr_accessor :id, :nome, :tipo, :espessura, :cor_r, :cor_g, :cor_b,
                    :textura, :fabricante, :padrao, :categoria, :preco_m2

      # tipo: :mdf, :mdp, :hdf, :compensado, :laca, :vidro, :espelho, :aluminio, :macica
      # categoria: :corpo, :frente, :fundo, :premium
      def initialize(opts = {})
        @id         = opts[:id] || Utils.gerar_id
        @nome       = opts[:nome] || 'MDF Branco 15mm'
        @tipo       = opts[:tipo] || :mdf
        @espessura  = opts[:espessura] || 15
        @cor_r      = opts[:cor_r] || 240
        @cor_g      = opts[:cor_g] || 235
        @cor_b      = opts[:cor_b] || 220
        @textura    = opts[:textura] || :lisa  # :lisa, :trama, :cristal, :natural, :madeira
        @fabricante = opts[:fabricante] || ''
        @padrao     = opts[:padrao] || ''  # código do padrão (ex: "BP Guararapes")
        @categoria  = opts[:categoria] || :corpo
        @preco_m2   = opts[:preco_m2] || 0.0
      end

      def cor_sketchup
        Sketchup::Color.new(@cor_r, @cor_g, @cor_b)
      end

      def to_hash
        { id: @id, nome: @nome, tipo: @tipo, espessura: @espessura,
          cor: [@cor_r, @cor_g, @cor_b], textura: @textura,
          fabricante: @fabricante, padrao: @padrao,
          categoria: @categoria, preco_m2: @preco_m2 }
      end
    end

    # Biblioteca local de materiais (padrão, antes de sincronizar com ERP)
    class BibliotecaMateriais
      def self.materiais_padrao
        @materiais ||= criar_biblioteca_padrao
      end

      def self.buscar(nome)
        materiais_padrao.find { |m| m.nome == nome }
      end

      def self.buscar_por_tipo(tipo)
        materiais_padrao.select { |m| m.tipo == tipo }
      end

      def self.buscar_por_categoria(categoria)
        materiais_padrao.select { |m| m.categoria == categoria }
      end

      def self.buscar_por_espessura(espessura)
        materiais_padrao.select { |m| m.espessura == espessura }
      end

      def self.chapas
        materiais_padrao.select { |m| [:mdf, :mdp, :hdf, :compensado].include?(m.tipo) }
      end

      def self.nomes
        materiais_padrao.map(&:nome)
      end

      private

      def self.criar_biblioteca_padrao
        [
          # ═══ MDF 15mm ═══
          MaterialInfo.new(nome: 'MDF Branco TX 15mm', tipo: :mdf, espessura: 15,
            cor_r: 245, cor_g: 243, cor_b: 238, textura: :trama, fabricante: 'Arauco', categoria: :corpo),
          MaterialInfo.new(nome: 'MDF Branco Liso 15mm', tipo: :mdf, espessura: 15,
            cor_r: 250, cor_g: 250, cor_b: 250, textura: :lisa, fabricante: 'Duratex', categoria: :corpo),
          MaterialInfo.new(nome: 'MDF Carvalho Hanover 15mm', tipo: :mdf, espessura: 15,
            cor_r: 180, cor_g: 140, cor_b: 100, textura: :madeira, fabricante: 'Arauco', categoria: :frente),
          MaterialInfo.new(nome: 'MDF Freijó Puro 15mm', tipo: :mdf, espessura: 15,
            cor_r: 160, cor_g: 120, cor_b: 80, textura: :madeira, fabricante: 'Guararapes', categoria: :frente),
          MaterialInfo.new(nome: 'MDF Nogueira Terracota 15mm', tipo: :mdf, espessura: 15,
            cor_r: 130, cor_g: 85, cor_b: 55, textura: :madeira, fabricante: 'Berneck', categoria: :frente),
          MaterialInfo.new(nome: 'MDF Preto TX 15mm', tipo: :mdf, espessura: 15,
            cor_r: 45, cor_g: 42, cor_b: 40, textura: :trama, fabricante: 'Arauco', categoria: :frente),
          MaterialInfo.new(nome: 'MDF Cinza Urbano 15mm', tipo: :mdf, espessura: 15,
            cor_r: 160, cor_g: 160, cor_b: 158, textura: :trama, fabricante: 'Duratex', categoria: :frente),
          MaterialInfo.new(nome: 'MDF Grigio 15mm', tipo: :mdf, espessura: 15,
            cor_r: 140, cor_g: 138, cor_b: 135, textura: :cristal, fabricante: 'Guararapes', categoria: :frente),
          MaterialInfo.new(nome: 'MDF Rovere Marsala 15mm', tipo: :mdf, espessura: 15,
            cor_r: 150, cor_g: 110, cor_b: 75, textura: :madeira, fabricante: 'Berneck', categoria: :frente),
          MaterialInfo.new(nome: 'MDF Nude 15mm', tipo: :mdf, espessura: 15,
            cor_r: 210, cor_g: 190, cor_b: 170, textura: :trama, fabricante: 'Guararapes', categoria: :frente),

          # ═══ MDF 18mm ═══
          MaterialInfo.new(nome: 'MDF Branco TX 18mm', tipo: :mdf, espessura: 18,
            cor_r: 245, cor_g: 243, cor_b: 238, textura: :trama, fabricante: 'Arauco', categoria: :corpo),
          MaterialInfo.new(nome: 'MDF Carvalho Hanover 18mm', tipo: :mdf, espessura: 18,
            cor_r: 180, cor_g: 140, cor_b: 100, textura: :madeira, fabricante: 'Arauco', categoria: :frente),
          MaterialInfo.new(nome: 'MDF Freijó Puro 18mm', tipo: :mdf, espessura: 18,
            cor_r: 160, cor_g: 120, cor_b: 80, textura: :madeira, fabricante: 'Guararapes', categoria: :frente),

          # ═══ MDF 25mm ═══
          MaterialInfo.new(nome: 'MDF Branco TX 25mm', tipo: :mdf, espessura: 25,
            cor_r: 245, cor_g: 243, cor_b: 238, textura: :trama, fabricante: 'Arauco', categoria: :corpo),

          # ═══ MDP 15mm ═══
          MaterialInfo.new(nome: 'MDP Branco 15mm', tipo: :mdp, espessura: 15,
            cor_r: 240, cor_g: 238, cor_b: 230, textura: :lisa, fabricante: 'Duratex', categoria: :corpo),
          MaterialInfo.new(nome: 'MDP Carvalho 15mm', tipo: :mdp, espessura: 15,
            cor_r: 175, cor_g: 135, cor_b: 95, textura: :madeira, fabricante: 'Duratex', categoria: :corpo),

          # ═══ MDP 18mm ═══
          MaterialInfo.new(nome: 'MDP Branco 18mm', tipo: :mdp, espessura: 18,
            cor_r: 240, cor_g: 238, cor_b: 230, textura: :lisa, fabricante: 'Duratex', categoria: :corpo),

          # ═══ HDF (fundos) ═══
          MaterialInfo.new(nome: 'HDF Branco 3mm', tipo: :hdf, espessura: 3,
            cor_r: 250, cor_g: 250, cor_b: 248, textura: :lisa, categoria: :fundo),
          MaterialInfo.new(nome: 'HDF Branco 6mm', tipo: :hdf, espessura: 6,
            cor_r: 250, cor_g: 250, cor_b: 248, textura: :lisa, categoria: :fundo),

          # ═══ Compensado (fundos reforçados / gavetas) ═══
          MaterialInfo.new(nome: 'Compensado 3mm', tipo: :compensado, espessura: 3,
            cor_r: 220, cor_g: 200, cor_b: 170, textura: :natural, categoria: :fundo),
          MaterialInfo.new(nome: 'Compensado 6mm', tipo: :compensado, espessura: 6,
            cor_r: 220, cor_g: 200, cor_b: 170, textura: :natural, categoria: :fundo),

          # ═══ Laca (pintura) ═══
          MaterialInfo.new(nome: 'Laca Branca Fosca', tipo: :laca, espessura: 15,
            cor_r: 255, cor_g: 255, cor_b: 255, textura: :lisa, categoria: :premium),
          MaterialInfo.new(nome: 'Laca Preta Fosca', tipo: :laca, espessura: 15,
            cor_r: 30, cor_g: 30, cor_b: 30, textura: :lisa, categoria: :premium),
          MaterialInfo.new(nome: 'Laca Grafite Fosca', tipo: :laca, espessura: 15,
            cor_r: 80, cor_g: 80, cor_b: 78, textura: :lisa, categoria: :premium),
          MaterialInfo.new(nome: 'Laca Verde Musgo', tipo: :laca, espessura: 15,
            cor_r: 60, cor_g: 80, cor_b: 55, textura: :lisa, categoria: :premium),
          MaterialInfo.new(nome: 'Laca Azul Marinho', tipo: :laca, espessura: 15,
            cor_r: 25, cor_g: 45, cor_b: 75, textura: :lisa, categoria: :premium),
          MaterialInfo.new(nome: 'Laca Rosa Nude', tipo: :laca, espessura: 15,
            cor_r: 220, cor_g: 180, cor_b: 175, textura: :lisa, categoria: :premium),

          # ═══ Vidro ═══
          MaterialInfo.new(nome: 'Vidro Incolor 4mm', tipo: :vidro, espessura: 4,
            cor_r: 220, cor_g: 240, cor_b: 245, textura: :lisa, categoria: :premium),
          MaterialInfo.new(nome: 'Vidro Fumê 4mm', tipo: :vidro, espessura: 4,
            cor_r: 100, cor_g: 100, cor_b: 105, textura: :lisa, categoria: :premium),
          MaterialInfo.new(nome: 'Vidro Bronze 4mm', tipo: :vidro, espessura: 4,
            cor_r: 140, cor_g: 110, cor_b: 80, textura: :lisa, categoria: :premium),
          MaterialInfo.new(nome: 'Vidro Preto 4mm', tipo: :vidro, espessura: 4,
            cor_r: 20, cor_g: 20, cor_b: 22, textura: :lisa, categoria: :premium),

          # ═══ Espelho ═══
          MaterialInfo.new(nome: 'Espelho Comum 4mm', tipo: :espelho, espessura: 4,
            cor_r: 200, cor_g: 220, cor_b: 230, textura: :lisa, categoria: :premium),
          MaterialInfo.new(nome: 'Espelho Fumê 4mm', tipo: :espelho, espessura: 4,
            cor_r: 120, cor_g: 120, cor_b: 125, textura: :lisa, categoria: :premium),
          MaterialInfo.new(nome: 'Espelho Bronze 4mm', tipo: :espelho, espessura: 4,
            cor_r: 160, cor_g: 130, cor_b: 100, textura: :lisa, categoria: :premium),

          # ═══ Alumínio (perfis) ═══
          MaterialInfo.new(nome: 'Perfil Alumínio Natural', tipo: :aluminio, espessura: 1,
            cor_r: 195, cor_g: 195, cor_b: 200, textura: :lisa, categoria: :premium),
          MaterialInfo.new(nome: 'Perfil Alumínio Preto', tipo: :aluminio, espessura: 1,
            cor_r: 35, cor_g: 35, cor_b: 38, textura: :lisa, categoria: :premium),
          MaterialInfo.new(nome: 'Perfil Alumínio Champanhe', tipo: :aluminio, espessura: 1,
            cor_r: 200, cor_g: 180, cor_b: 150, textura: :lisa, categoria: :premium),
        ]
      end
    end

    # Biblioteca de Fitas de Borda
    class BibliotecaFitas
      def self.fitas_padrao
        @fitas ||= [
          # PVC 1mm
          { nome: 'PVC 1mm Branco TX', tipo: :pvc, espessura: 1.0, largura: 22, cor_r: 245, cor_g: 243, cor_b: 238 },
          { nome: 'PVC 1mm Branco Liso', tipo: :pvc, espessura: 1.0, largura: 22, cor_r: 250, cor_g: 250, cor_b: 250 },
          { nome: 'PVC 1mm Carvalho', tipo: :pvc, espessura: 1.0, largura: 22, cor_r: 180, cor_g: 140, cor_b: 100 },
          { nome: 'PVC 1mm Freijó', tipo: :pvc, espessura: 1.0, largura: 22, cor_r: 160, cor_g: 120, cor_b: 80 },
          { nome: 'PVC 1mm Preto TX', tipo: :pvc, espessura: 1.0, largura: 22, cor_r: 45, cor_g: 42, cor_b: 40 },
          { nome: 'PVC 1mm Cinza Urbano', tipo: :pvc, espessura: 1.0, largura: 22, cor_r: 160, cor_g: 160, cor_b: 158 },

          # ABS 2mm
          { nome: 'ABS 2mm Branco TX', tipo: :abs, espessura: 2.0, largura: 22, cor_r: 245, cor_g: 243, cor_b: 238 },
          { nome: 'ABS 2mm Carvalho', tipo: :abs, espessura: 2.0, largura: 22, cor_r: 180, cor_g: 140, cor_b: 100 },
          { nome: 'ABS 2mm Freijó', tipo: :abs, espessura: 2.0, largura: 22, cor_r: 160, cor_g: 120, cor_b: 80 },
          { nome: 'ABS 2mm Preto TX', tipo: :abs, espessura: 2.0, largura: 22, cor_r: 45, cor_g: 42, cor_b: 40 },
          { nome: 'ABS 2mm Cinza Urbano', tipo: :abs, espessura: 2.0, largura: 22, cor_r: 160, cor_g: 160, cor_b: 158 },

          # PVC 0.4mm (econômica)
          { nome: 'PVC 0.4mm Branco', tipo: :pvc, espessura: 0.4, largura: 22, cor_r: 248, cor_g: 248, cor_b: 245 },
          { nome: 'PVC 0.4mm Carvalho', tipo: :pvc, espessura: 0.4, largura: 22, cor_r: 175, cor_g: 135, cor_b: 95 },

          # Fita para 18mm (largura 35mm)
          { nome: 'PVC 1mm Branco TX 35mm', tipo: :pvc, espessura: 1.0, largura: 35, cor_r: 245, cor_g: 243, cor_b: 238 },
          { nome: 'ABS 2mm Branco TX 35mm', tipo: :abs, espessura: 2.0, largura: 35, cor_r: 245, cor_g: 243, cor_b: 238 },

          # Fita para 25mm (largura 45mm)
          { nome: 'PVC 1mm Branco TX 45mm', tipo: :pvc, espessura: 1.0, largura: 45, cor_r: 245, cor_g: 243, cor_b: 238 },
        ]
      end

      def self.buscar(nome)
        fitas_padrao.find { |f| f[:nome] == nome }
      end

      def self.buscar_por_padrao(material_nome)
        # Tenta encontrar fita que corresponda ao padrão do material
        # Ex: "MDF Carvalho Hanover 15mm" → "PVC 1mm Carvalho" ou "ABS 2mm Carvalho"
        palavras_chave = material_nome.downcase.split(/[\s_]+/)
        cores = %w[branco carvalho freijó nogueira preto cinza grigio rovere nude]
        cor_encontrada = palavras_chave.find { |p| cores.any? { |c| p.include?(c) } }
        cor_encontrada ||= 'branco'

        fitas_padrao.select { |f| f[:nome].downcase.include?(cor_encontrada) }
      end

      def self.nomes
        fitas_padrao.map { |f| f[:nome] }
      end
    end
  end
end
