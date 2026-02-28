# ornato_plugin/engines/motor_furacao.rb — Motor de furação (Sistema 32mm)

module Ornato
  module Engines
    class MotorFuracao
      Furo = Struct.new(:x, :y, :diametro, :profundidade, :tipo, :face, :peca_nome, keyword_init: true)

      # Gera mapa de furação completo para um módulo
      # Retorna hash { peca_nome => [Furo, Furo, ...] }
      def self.gerar_mapa(modulo_info)
        mi = modulo_info
        mapa = {}

        mi.pecas.each do |peca|
          furos = []

          case peca.tipo
          when :lateral
            furos += furos_lateral(peca, mi)
          when :base, :topo
            furos += furos_base_topo(peca, mi)
          when :prateleira
            furos += furos_prateleira(peca, mi)
          when :porta
            furos += furos_porta(peca, mi)
          when :frente_gaveta
            furos += furos_frente_gaveta(peca, mi)
          when :divisoria
            furos += furos_divisoria(peca, mi)
          end

          mapa[peca.nome] = furos unless furos.empty?
        end

        mapa
      end

      # Valida colisões entre furos
      def self.validar(mapa)
        erros = []
        avisos = []

        mapa.each do |peca_nome, furos|
          # Agrupa furos por face
          por_face = furos.group_by(&:face)

          por_face.each do |face, furos_face|
            furos_face.combination(2).each do |f1, f2|
              dist = Math.sqrt((f1.x - f2.x)**2 + (f1.y - f2.y)**2)
              raio_soma = (f1.diametro + f2.diametro) / 2.0
              min_dist = raio_soma + 5.0  # 5mm mínimo entre bordas

              if dist < raio_soma
                erros << "#{peca_nome}: Furos #{f1.tipo} e #{f2.tipo} se sobrepõem (dist: #{dist.round(1)}mm)"
              elsif dist < min_dist
                avisos << "#{peca_nome}: Furos #{f1.tipo} e #{f2.tipo} muito próximos (dist: #{dist.round(1)}mm, mín: #{min_dist.round(1)}mm)"
              end
            end

            # Verifica distância da borda
            furos_face.each do |f|
              raio = f.diametro / 2.0
              if f.x - raio < 8
                erros << "#{peca_nome}: Furo #{f.tipo} muito perto da borda esquerda (#{(f.x - raio).round(1)}mm, mín: 8mm)"
              end
              if f.y - raio < 8
                erros << "#{peca_nome}: Furo #{f.tipo} muito perto da borda inferior (#{(f.y - raio).round(1)}mm, mín: 8mm)"
              end
            end
          end
        end

        { erros: erros, avisos: avisos, valido: erros.empty? }
      end

      private

      # ─── Furação da lateral ───
      def self.furos_lateral(peca, mi)
        furos = []
        comp = peca.comprimento  # altura da lateral
        larg = peca.largura      # profundidade

        esp = mi.espessura_corpo
        centro_esp = esp / 2.0  # centro da espessura para furos de borda

        # Fixação base (borda inferior) — minifix + cavilha
        if mi.fixacao == Config::FIXACAO_MINIFIX
          # Face interna: tambor minifix
          furos << Furo.new(x: 37, y: centro_esp, diametro: Config::FURO_MINIFIX_FACE_D,
                           profundidade: Config::FURO_MINIFIX_FACE_PROF, tipo: :minifix_tambor, face: :interna, peca_nome: peca.nome)
          furos << Furo.new(x: 70, y: centro_esp, diametro: Config::FURO_CAVILHA_D,
                           profundidade: Config::FURO_CAVILHA_PROF, tipo: :cavilha, face: :interna, peca_nome: peca.nome)

          # Borda inferior: parafuso minifix
          furos << Furo.new(x: 37, y: centro_esp, diametro: Config::FURO_MINIFIX_BORDA_D,
                           profundidade: Config::FURO_MINIFIX_BORDA_PROF, tipo: :minifix_parafuso, face: :borda_inferior, peca_nome: peca.nome)
          furos << Furo.new(x: 70, y: centro_esp, diametro: Config::FURO_CAVILHA_D,
                           profundidade: Config::FURO_CAVILHA_PROF, tipo: :cavilha, face: :borda_inferior, peca_nome: peca.nome)

          # Fixação topo (espelhado)
          furos << Furo.new(x: 37, y: comp - centro_esp, diametro: Config::FURO_MINIFIX_FACE_D,
                           profundidade: Config::FURO_MINIFIX_FACE_PROF, tipo: :minifix_tambor, face: :interna, peca_nome: peca.nome)
          furos << Furo.new(x: 70, y: comp - centro_esp, diametro: Config::FURO_CAVILHA_D,
                           profundidade: Config::FURO_CAVILHA_PROF, tipo: :cavilha, face: :interna, peca_nome: peca.nome)

          furos << Furo.new(x: 37, y: centro_esp, diametro: Config::FURO_MINIFIX_BORDA_D,
                           profundidade: Config::FURO_MINIFIX_BORDA_PROF, tipo: :minifix_parafuso, face: :borda_superior, peca_nome: peca.nome)
          furos << Furo.new(x: 70, y: centro_esp, diametro: Config::FURO_CAVILHA_D,
                           profundidade: Config::FURO_CAVILHA_PROF, tipo: :cavilha, face: :borda_superior, peca_nome: peca.nome)
        end

        # Sistema 32mm (furos para prateleira) — linha de furos na face interna
        inicio = Config::SISTEMA_32_INICIO
        passo = Config::SISTEMA_32_PASSO
        margem_sup = esp + 80   # não furar muito perto do topo/base
        margem_inf = esp + 80

        pos = margem_inf
        while pos <= (comp - margem_sup)
          furos << Furo.new(x: inicio, y: pos, diametro: Config::FURO_PIN_D,
                           profundidade: Config::FURO_PIN_PROF, tipo: :pin_32mm, face: :interna, peca_nome: peca.nome)
          # Segunda linha de furos (traseira)
          furos << Furo.new(x: larg - inicio, y: pos, diametro: Config::FURO_PIN_D,
                           profundidade: Config::FURO_PIN_PROF, tipo: :pin_32mm, face: :interna, peca_nome: peca.nome)
          pos += passo
        end

        furos
      end

      # ─── Furação de base/topo ───
      def self.furos_base_topo(peca, mi)
        furos = []
        esp = mi.espessura_corpo
        centro_esp = esp / 2.0

        if mi.fixacao == Config::FIXACAO_MINIFIX
          # Borda esquerda e direita: parafuso minifix
          furos << Furo.new(x: 37, y: centro_esp, diametro: Config::FURO_MINIFIX_BORDA_D,
                           profundidade: Config::FURO_MINIFIX_BORDA_PROF, tipo: :minifix_parafuso, face: :borda_esquerda, peca_nome: peca.nome)
          furos << Furo.new(x: 70, y: centro_esp, diametro: Config::FURO_CAVILHA_D,
                           profundidade: Config::FURO_CAVILHA_PROF, tipo: :cavilha, face: :borda_esquerda, peca_nome: peca.nome)

          furos << Furo.new(x: 37, y: centro_esp, diametro: Config::FURO_MINIFIX_BORDA_D,
                           profundidade: Config::FURO_MINIFIX_BORDA_PROF, tipo: :minifix_parafuso, face: :borda_direita, peca_nome: peca.nome)
          furos << Furo.new(x: 70, y: centro_esp, diametro: Config::FURO_CAVILHA_D,
                           profundidade: Config::FURO_CAVILHA_PROF, tipo: :cavilha, face: :borda_direita, peca_nome: peca.nome)
        end

        furos
      end

      # ─── Furação da prateleira ───
      def self.furos_prateleira(peca, mi)
        [] # Prateleira removível: sem furação (usa pinos na lateral)
           # Prateleira fixa: minifix nas bordas (similar à base/topo)
      end

      # ─── Furação da porta (caneco dobradiça + puxador) ───
      def self.furos_porta(peca, mi)
        furos = []
        alt = peca.comprimento   # altura da porta
        larg = peca.largura      # largura da porta

        # Canecos de dobradiça
        qtd = Utils.qtd_dobradicas(alt)
        recuo = Config::DOBRADICA_RECUO_BORDA
        recuo_x = Config::FURO_CANECO_RECUO  # 22mm da borda

        posicoes = calcular_posicoes_dobradica(alt, qtd, recuo)
        posicoes.each do |pos_y|
          furos << Furo.new(x: recuo_x, y: pos_y, diametro: Config::FURO_CANECO_D,
                           profundidade: Config::FURO_CANECO_PROF, tipo: :caneco_dobradica, face: :interna, peca_nome: peca.nome)
        end

        # Puxador (centro da porta por padrão)
        furos << Furo.new(x: larg - 37, y: alt / 2.0, diametro: Config::FURO_PUXADOR_D,
                         profundidade: peca.espessura, tipo: :puxador, face: :passante, peca_nome: peca.nome)

        furos
      end

      # ─── Furação da frente de gaveta (puxador) ───
      def self.furos_frente_gaveta(peca, mi)
        furos = []
        alt = peca.comprimento
        larg = peca.largura

        # Puxador centralizado
        furos << Furo.new(x: larg / 2.0, y: alt / 2.0, diametro: Config::FURO_PUXADOR_D,
                         profundidade: peca.espessura, tipo: :puxador, face: :passante, peca_nome: peca.nome)

        furos
      end

      # ─── Furação da divisória ───
      def self.furos_divisoria(peca, mi)
        furos = []
        esp = mi.espessura_corpo

        if mi.fixacao == Config::FIXACAO_MINIFIX
          furos << Furo.new(x: 37, y: esp / 2.0, diametro: Config::FURO_MINIFIX_BORDA_D,
                           profundidade: Config::FURO_MINIFIX_BORDA_PROF, tipo: :minifix_parafuso, face: :borda_inferior, peca_nome: peca.nome)
          furos << Furo.new(x: 70, y: esp / 2.0, diametro: Config::FURO_CAVILHA_D,
                           profundidade: Config::FURO_CAVILHA_PROF, tipo: :cavilha, face: :borda_inferior, peca_nome: peca.nome)
          furos << Furo.new(x: 37, y: esp / 2.0, diametro: Config::FURO_MINIFIX_BORDA_D,
                           profundidade: Config::FURO_MINIFIX_BORDA_PROF, tipo: :minifix_parafuso, face: :borda_superior, peca_nome: peca.nome)
          furos << Furo.new(x: 70, y: esp / 2.0, diametro: Config::FURO_CAVILHA_D,
                           profundidade: Config::FURO_CAVILHA_PROF, tipo: :cavilha, face: :borda_superior, peca_nome: peca.nome)
        end

        furos
      end

      # Calcula posições das dobradiças igualmente espaçadas
      def self.calcular_posicoes_dobradica(altura, quantidade, recuo)
        return [recuo, altura - recuo] if quantidade == 2

        posicoes = [recuo]
        espaco = (altura - (2 * recuo)) / (quantidade - 1).to_f
        (1...quantidade - 1).each do |i|
          posicoes << (recuo + (i * espaco)).round(1)
        end
        posicoes << (altura - recuo)
        posicoes
      end
    end
  end
end
