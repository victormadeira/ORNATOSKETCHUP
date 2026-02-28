# ornato_plugin/engines/motor_usinagem.rb — Motor de usinagens CNC

module Ornato
  module Engines
    class MotorUsinagem

      # Tipos de usinagem
      Usinagem = Struct.new(
        :tipo,          # :canal, :rebaixo, :fresagem_perfil, :furo, :pocket, :rasgo
        :x, :y,         # posição início (mm) — relativa à peça
        :comprimento,   # mm (para canais/rasgos)
        :largura,       # mm (largura do canal/fresagem)
        :profundidade,  # mm
        :diametro,      # mm (para furos)
        :face,          # :superior, :inferior, :frente, :tras, :esquerda, :direita, :borda_*
        :ferramenta,    # diâmetro da fresa ou broca
        :descricao,     # texto descritivo
        :peca_nome,     # nome da peça
        keyword_init: true
      )

      # ═══════════════════════════════════════════════
      # CANAL PARA FUNDO (rebaixado)
      # ═══════════════════════════════════════════════
      # Canal fresado nas laterais, base e topo para encaixar o fundo
      def self.canal_fundo(peca, modulo_info)
        usinagens = []
        mi = modulo_info
        return usinagens unless mi.tipo_fundo == Config::FUNDO_REBAIXADO

        esp_fundo = mi.espessura_fundo  # 3mm ou 6mm
        rebaixo = mi.rebaixo_fundo      # 8mm da borda traseira
        prof_canal = rebaixo            # profundidade do canal = rebaixo
        larg_canal = esp_fundo + 0.5    # folga de 0.5mm para encaixe

        # Distância do canal da borda traseira
        dist_borda = mi.espessura_corpo - rebaixo

        case peca.tipo
        when :lateral
          # Canal vertical na face interna, perto da borda traseira
          usinagens << Usinagem.new(
            tipo: :canal, x: peca.largura - dist_borda - (larg_canal / 2.0), y: 0,
            comprimento: peca.comprimento, largura: larg_canal, profundidade: prof_canal,
            face: :interna, ferramenta: esp_fundo,
            descricao: "Canal p/ fundo #{esp_fundo}mm", peca_nome: peca.nome
          )
        when :base, :topo
          # Canal horizontal na face interna
          usinagens << Usinagem.new(
            tipo: :canal, x: 0, y: peca.largura - dist_borda - (larg_canal / 2.0),
            comprimento: peca.comprimento, largura: larg_canal, profundidade: prof_canal,
            face: :interna, ferramenta: esp_fundo,
            descricao: "Canal p/ fundo #{esp_fundo}mm", peca_nome: peca.nome
          )
        end

        usinagens
      end

      # ═══════════════════════════════════════════════
      # CANAL PARA FUNDO DE GAVETA
      # ═══════════════════════════════════════════════
      def self.canal_fundo_gaveta(peca, esp_fundo = 3)
        return [] unless [:lateral_gaveta, :frente_gaveta, :traseira_gaveta].include?(peca.tipo)

        larg_canal = esp_fundo + 0.5
        dist_base = 10  # 10mm da base da lateral/frente

        [Usinagem.new(
          tipo: :canal, x: 0, y: dist_base,
          comprimento: peca.comprimento, largura: larg_canal, profundidade: 8,
          face: :interna, ferramenta: esp_fundo,
          descricao: "Canal p/ fundo gaveta #{esp_fundo}mm", peca_nome: peca.nome
        )]
      end

      # ═══════════════════════════════════════════════
      # REBAIXO (rabbet) — para fundo sobreposto
      # ═══════════════════════════════════════════════
      def self.rebaixo_fundo(peca, modulo_info)
        return [] unless modulo_info.tipo_fundo == Config::FUNDO_SOBREPOSTO
        return [] unless [:lateral, :base, :topo].include?(peca.tipo)

        esp_fundo = modulo_info.espessura_fundo
        prof = esp_fundo + 1  # 1mm mais fundo para folga

        [Usinagem.new(
          tipo: :rebaixo, x: 0, y: peca.largura - esp_fundo,
          comprimento: peca.comprimento, largura: esp_fundo + 1, profundidade: prof,
          face: :traseira, ferramenta: 6,
          descricao: "Rebaixo p/ fundo sobreposto #{esp_fundo}mm", peca_nome: peca.nome
        )]
      end

      # ═══════════════════════════════════════════════
      # FRESAGEM DE PERFIL DE BORDA
      # ═══════════════════════════════════════════════
      PERFIS_BORDA = {
        arredondado:    { raio: 3,  ferramenta: 6,  descricao: 'Arredondado R3mm' },
        arredondado_r5: { raio: 5,  ferramenta: 10, descricao: 'Arredondado R5mm' },
        chanfro_45:     { raio: 3,  ferramenta: 6,  descricao: 'Chanfro 45° 3mm' },
        ogee:           { raio: 8,  ferramenta: 16, descricao: 'Ogee clássico' },
        meia_cana:      { raio: 6,  ferramenta: 12, descricao: 'Meia-cana R6mm' },
        boleado:        { raio: 10, ferramenta: 20, descricao: 'Boleado R10mm' },
        reto:           { raio: 0,  ferramenta: 0,  descricao: 'Reto (sem perfil)' },
      }.freeze

      def self.fresagem_perfil(peca, perfil, arestas = [:frente])
        return [] if perfil == :reto
        info = PERFIS_BORDA[perfil]
        return [] unless info

        arestas.map do |aresta|
          comp = case aresta
                 when :frente, :tras then peca.comprimento
                 when :topo, :base then peca.largura
                 end

          Usinagem.new(
            tipo: :fresagem_perfil, x: 0, y: 0,
            comprimento: comp, largura: info[:raio] * 2, profundidade: info[:raio],
            face: aresta, ferramenta: info[:ferramenta],
            descricao: "Perfil #{info[:descricao]} — #{aresta}", peca_nome: peca.nome
          )
        end
      end

      # ═══════════════════════════════════════════════
      # POCKET PARA DOBRADIÇA (caneco)
      # ═══════════════════════════════════════════════
      def self.pocket_dobradica(peca, posicoes_y, recuo_x = 22)
        posicoes_y.map do |pos_y|
          Usinagem.new(
            tipo: :pocket, x: recuo_x, y: pos_y,
            comprimento: 0, largura: 0, profundidade: Config::FURO_CANECO_PROF,
            diametro: Config::FURO_CANECO_D, face: :interna, ferramenta: 35,
            descricao: "Caneco dobradiça Ø35mm", peca_nome: peca.nome
          )
        end
      end

      # ═══════════════════════════════════════════════
      # CANAL PARA VIDRO (portas com vidro)
      # ═══════════════════════════════════════════════
      def self.canal_vidro(peca, esp_vidro = 4, prof_canal = 10, larg_quadro = 60)
        # Canal na face interna do quadro da porta para encaixar vidro
        larg_canal = esp_vidro + 1  # folga de 1mm

        usinagens = []

        # Canal nas 4 bordas internas do quadro
        # Comprimento interno = comprimento da peça - (2 × largura do quadro)
        comp_int = peca.comprimento - (2 * larg_quadro)
        larg_int = peca.largura - (2 * larg_quadro)

        # Canal horizontal superior e inferior
        [:topo, :base].each do |pos|
          y_pos = pos == :topo ? peca.largura - larg_quadro : larg_quadro
          usinagens << Usinagem.new(
            tipo: :canal, x: larg_quadro, y: y_pos,
            comprimento: comp_int, largura: larg_canal, profundidade: prof_canal,
            face: :interna, ferramenta: esp_vidro,
            descricao: "Canal p/ vidro #{esp_vidro}mm (#{pos})", peca_nome: peca.nome
          )
        end

        # Canal vertical esquerdo e direito
        [:esquerda, :direita].each do |pos|
          x_pos = pos == :esquerda ? larg_quadro : peca.comprimento - larg_quadro
          usinagens << Usinagem.new(
            tipo: :canal, x: x_pos, y: larg_quadro,
            comprimento: larg_int, largura: larg_canal, profundidade: prof_canal,
            face: :interna, ferramenta: esp_vidro,
            descricao: "Canal p/ vidro #{esp_vidro}mm (#{pos})", peca_nome: peca.nome
          )
        end

        usinagens
      end

      # ═══════════════════════════════════════════════
      # FRESAGEM PROVENÇAL / SHAKER
      # ═══════════════════════════════════════════════
      # Fresa um quadro na face da porta para criar efeito provençal
      def self.fresagem_provencal(peca, opts = {})
        margem = opts[:margem] || 80         # distância da borda (mm)
        largura_fresa = opts[:largura] || 10 # largura do canal fresado
        profundidade = opts[:profundidade] || 6
        raio_canto = opts[:raio_canto] || 8  # raio nos cantos do quadro

        # Retângulo fresado na face da porta
        comp_int = peca.comprimento - (2 * margem)
        larg_int = peca.largura - (2 * margem)

        usinagens = []

        # 4 canais formando o quadro
        # Horizontal superior
        usinagens << Usinagem.new(
          tipo: :canal, x: margem, y: margem,
          comprimento: comp_int, largura: largura_fresa, profundidade: profundidade,
          face: :frontal, ferramenta: largura_fresa,
          descricao: 'Fresagem provençal — horizontal sup', peca_nome: peca.nome
        )
        # Horizontal inferior
        usinagens << Usinagem.new(
          tipo: :canal, x: margem, y: peca.largura - margem,
          comprimento: comp_int, largura: largura_fresa, profundidade: profundidade,
          face: :frontal, ferramenta: largura_fresa,
          descricao: 'Fresagem provençal — horizontal inf', peca_nome: peca.nome
        )
        # Vertical esquerdo
        usinagens << Usinagem.new(
          tipo: :canal, x: margem, y: margem,
          comprimento: larg_int, largura: largura_fresa, profundidade: profundidade,
          face: :frontal, ferramenta: largura_fresa,
          descricao: 'Fresagem provençal — vertical esq', peca_nome: peca.nome
        )
        # Vertical direito
        usinagens << Usinagem.new(
          tipo: :canal, x: peca.comprimento - margem, y: margem,
          comprimento: larg_int, largura: largura_fresa, profundidade: profundidade,
          face: :frontal, ferramenta: largura_fresa,
          descricao: 'Fresagem provençal — vertical dir', peca_nome: peca.nome
        )

        usinagens
      end

      # ═══════════════════════════════════════════════
      # FURAÇÃO PARA CAVILHA (junção de painéis)
      # ═══════════════════════════════════════════════
      def self.furacao_cavilha_painel(peca, opts = {})
        diametro = opts[:diametro] || 8      # mm
        profundidade = opts[:profundidade] || 16
        espacamento = opts[:espacamento] || 150  # mm entre cavilhas
        margem = opts[:margem] || 50         # mm das bordas

        usinagens = []
        # Furos na borda (para junção com outra peça)
        bordas = opts[:bordas] || [:direita]  # quais bordas furar

        bordas.each do |borda|
          case borda
          when :direita, :esquerda
            comp = peca.comprimento
            pos = margem
            while pos <= (comp - margem)
              x = borda == :direita ? peca.largura : 0
              usinagens << Usinagem.new(
                tipo: :furo, x: x, y: pos,
                diametro: diametro, profundidade: profundidade,
                face: "borda_#{borda}".to_sym, ferramenta: diametro,
                descricao: "Cavilha Ø#{diametro}mm p/ junção painel", peca_nome: peca.nome
              )
              pos += espacamento
            end
          when :topo, :base
            comp = peca.largura
            pos = margem
            while pos <= (comp - margem)
              y = borda == :topo ? peca.comprimento : 0
              usinagens << Usinagem.new(
                tipo: :furo, x: pos, y: y,
                diametro: diametro, profundidade: profundidade,
                face: "borda_#{borda}".to_sym, ferramenta: diametro,
                descricao: "Cavilha Ø#{diametro}mm p/ junção painel", peca_nome: peca.nome
              )
              pos += espacamento
            end
          end
        end

        usinagens
      end

      # ═══════════════════════════════════════════════
      # RASGO PARA VENEZIANA (louvered)
      # ═══════════════════════════════════════════════
      def self.rasgos_veneziana(peca, opts = {})
        angulo = opts[:angulo] || 17         # graus de inclinação das ripas
        esp_ripa = opts[:espessura_ripa] || 6  # mm
        espacamento = opts[:espacamento] || 25  # mm entre rasgos
        margem_sup = opts[:margem_superior] || 60
        margem_inf = opts[:margem_inferior] || 60
        prof_rasgo = opts[:profundidade] || 8

        usinagens = []
        larg_rasgo = esp_ripa + 0.5  # folga

        # Rasgos nos montantes laterais (bordas esq e dir do quadro)
        pos_y = margem_inf
        while pos_y <= (peca.comprimento - margem_sup)
          usinagens << Usinagem.new(
            tipo: :rasgo, x: 0, y: pos_y,
            comprimento: 0, largura: larg_rasgo, profundidade: prof_rasgo,
            face: :interna, ferramenta: esp_ripa,
            descricao: "Rasgo veneziana #{angulo}° — pos #{pos_y.round(0)}mm", peca_nome: peca.nome
          )
          pos_y += espacamento
        end

        usinagens
      end

      # ═══════════════════════════════════════════════
      # FRESAGEM PERFIL GOLA (puxador embutido)
      # ═══════════════════════════════════════════════
      def self.fresagem_gola(peca, posicao = :topo, profundidade = 15, largura = 40)
        y = case posicao
            when :topo then peca.comprimento - profundidade
            when :base then 0
            end

        [Usinagem.new(
          tipo: :fresagem_perfil, x: 0, y: y,
          comprimento: peca.largura, largura: largura, profundidade: profundidade,
          face: :superior, ferramenta: largura,
          descricao: "Fresagem gola (puxador embutido) #{posicao}", peca_nome: peca.nome
        )]
      end

      # ═══════════════════════════════════════════════
      # VALIDAÇÃO DE COLISÃO ENTRE USINAGENS
      # ═══════════════════════════════════════════════
      def self.validar_colisoes(usinagens)
        erros = []
        avisos = []

        # Agrupa por peça e face
        por_peca = usinagens.group_by(&:peca_nome)

        por_peca.each do |peca_nome, usins|
          por_face = usins.group_by(&:face)

          por_face.each do |face, usins_face|
            usins_face.combination(2).each do |u1, u2|
              # Verifica sobreposição para furos
              if u1.tipo == :furo && u2.tipo == :furo
                dist = Math.sqrt((u1.x - u2.x)**2 + (u1.y - u2.y)**2)
                raio_soma = ((u1.diametro || 0) + (u2.diametro || 0)) / 2.0
                if dist < raio_soma
                  erros << "#{peca_nome} [#{face}]: #{u1.descricao} colide com #{u2.descricao} (dist: #{dist.round(1)}mm)"
                elsif dist < raio_soma + 3
                  avisos << "#{peca_nome} [#{face}]: #{u1.descricao} muito perto de #{u2.descricao} (dist: #{dist.round(1)}mm)"
                end
              end

              # Verifica sobreposição de canais
              if u1.tipo == :canal && u2.tipo == :canal
                # Canais paralelos: verifica se se cruzam
                if (u1.y - u2.y).abs < ((u1.largura + u2.largura) / 2.0)
                  # Na mesma linha — verifica sobreposição em X
                  if u1.x < (u2.x + u2.comprimento) && u2.x < (u1.x + u1.comprimento)
                    erros << "#{peca_nome} [#{face}]: Canais se sobrepõem — #{u1.descricao} e #{u2.descricao}"
                  end
                end
              end

              # Furo dentro de canal
              if u1.tipo == :furo && u2.tipo == :canal
                if u1.x >= u2.x && u1.x <= (u2.x + u2.comprimento) &&
                   (u1.y - u2.y).abs < (u2.largura / 2.0 + (u1.diametro || 0) / 2.0)
                  avisos << "#{peca_nome} [#{face}]: #{u1.descricao} dentro do #{u2.descricao}"
                end
              end
            end

            # Verifica se usinagem está dentro dos limites da peça
            usins_face.each do |u|
              if u.tipo == :furo
                raio = (u.diametro || 0) / 2.0
                if u.x - raio < 5 || u.y - raio < 5
                  avisos << "#{peca_nome} [#{face}]: #{u.descricao} muito perto da borda (mín 5mm)"
                end
              end
            end
          end
        end

        { erros: erros, avisos: avisos, valido: erros.empty? }
      end

      # Gera todas as usinagens de um módulo completo
      def self.gerar_usinagens_modulo(modulo_info)
        mi = modulo_info
        todas = []

        mi.pecas.each do |peca|
          # Canal de fundo
          todas += canal_fundo(peca, mi)

          # Canal de fundo de gaveta
          todas += canal_fundo_gaveta(peca) if [:lateral_gaveta, :frente_gaveta, :traseira_gaveta].include?(peca.tipo)

          # Rebaixo de fundo sobreposto
          todas += rebaixo_fundo(peca, mi)
        end

        todas
      end
    end
  end
end
