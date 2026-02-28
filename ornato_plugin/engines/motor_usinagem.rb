# ornato_plugin/engines/motor_usinagem.rb — Motor de usinagens CNC
# Specs reais: Blum, Hettich, padrões industriais moveleiros

module Ornato
  module Engines
    class MotorUsinagem

      # Estrutura de dados para cada operação de usinagem
      Usinagem = Struct.new(
        :tipo,          # :canal, :rebaixo, :fresagem_perfil, :furo, :pocket, :rasgo, :dado
        :x, :y,         # posição início (mm) — relativa à peça
        :comprimento,   # mm (para canais/rasgos)
        :largura,       # mm (largura do canal/fresagem)
        :profundidade,  # mm
        :diametro,      # mm (para furos)
        :face,          # :superior, :inferior, :frente, :tras, :esquerda, :direita, :borda_*, :interna, :frontal
        :ferramenta,    # diâmetro da fresa ou broca (mm)
        :rpm,           # rotação (RPM)
        :avanco,        # velocidade de avanço (m/min)
        :prof_passe,    # profundidade por passe (mm) — nil = passe único
        :descricao,     # texto descritivo
        :peca_nome,     # nome da peça
        keyword_init: true
      )

      # ═══════════════════════════════════════════════
      # PERFIS DE BORDA disponíveis
      # ═══════════════════════════════════════════════
      PERFIS_BORDA = {
        arredondado_r2: { raio: 2,  ferramenta: 4,  descricao: 'Arredondado R2mm' },
        arredondado:    { raio: 3,  ferramenta: 6,  descricao: 'Arredondado R3mm' },
        arredondado_r6: { raio: 6,  ferramenta: 12, descricao: 'Arredondado R6mm (1/4")' },
        arredondado_r9: { raio: 9,  ferramenta: 18, descricao: 'Arredondado R9mm (3/8")' },
        chanfro_2:      { raio: 2,  ferramenta: 6,  descricao: 'Chanfro 45° 2mm' },
        chanfro_45:     { raio: 3,  ferramenta: 6,  descricao: 'Chanfro 45° 3mm' },
        chanfro_6:      { raio: 6,  ferramenta: 12, descricao: 'Chanfro 45° 6mm' },
        ogee:           { raio: 8,  ferramenta: 16, descricao: 'Ogee — raio 4.8mm, prof 16mm' },
        meia_cana:      { raio: 6,  ferramenta: 12, descricao: 'Meia-cana (Cove) R6mm' },
        meia_cana_r9:   { raio: 9,  ferramenta: 18, descricao: 'Meia-cana (Cove) R9mm' },
        boleado:        { raio: 10, ferramenta: 20, descricao: 'Boleado R10mm' },
        reto:           { raio: 0,  ferramenta: 0,  descricao: 'Reto (sem perfil)' },
      }.freeze

      # ═══════════════════════════════════════════════
      # CANAL PARA FUNDO (rebaixado)
      # ═══════════════════════════════════════════════
      # Canal fresado nas laterais, base e topo para encaixar o fundo
      # Specs reais: 3mm HDF → canal 3.5mm × 10mm prof; 6mm MDF → canal 6.5mm × 10mm prof
      # Distância da borda traseira: 7mm (padrão industrial)
      def self.canal_fundo(peca, modulo_info)
        usinagens = []
        mi = modulo_info
        return usinagens unless mi.tipo_fundo == Config::FUNDO_REBAIXADO

        esp_fundo = mi.espessura_fundo  # 3mm ou 6mm
        spec = esp_fundo <= 3 ? Config::CANAL_FUNDO_3MM : Config::CANAL_FUNDO_6MM
        cnc  = esp_fundo <= 3 ? Config::CNC_PARAMS[:canal_3mm] : Config::CNC_PARAMS[:canal_6mm]

        larg_canal  = spec[:largura]
        prof_canal  = spec[:profundidade]
        dist_borda  = spec[:dist_borda_tras]

        case peca.tipo
        when :lateral
          # Canal vertical na face interna, perto da borda traseira
          usinagens << Usinagem.new(
            tipo: :canal, x: peca.largura - dist_borda - (larg_canal / 2.0), y: 0,
            comprimento: peca.comprimento, largura: larg_canal, profundidade: prof_canal,
            face: :interna, ferramenta: cnc[:ferramenta_d],
            rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
            descricao: spec[:descricao], peca_nome: peca.nome
          )
        when :base, :topo
          # Canal horizontal na face interna
          usinagens << Usinagem.new(
            tipo: :canal, x: 0, y: peca.largura - dist_borda - (larg_canal / 2.0),
            comprimento: peca.comprimento, largura: larg_canal, profundidade: prof_canal,
            face: :interna, ferramenta: cnc[:ferramenta_d],
            rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
            descricao: spec[:descricao], peca_nome: peca.nome
          )
        end

        usinagens
      end

      # ═══════════════════════════════════════════════
      # CANAL PARA FUNDO DE GAVETA
      # ═══════════════════════════════════════════════
      # Canal nas laterais e frente da gaveta para encaixar o fundo
      # Spec: 8mm da base, 8mm profundidade, largura = espessura fundo + 0.5mm folga
      def self.canal_fundo_gaveta(peca, esp_fundo = 3)
        return [] unless [:lateral_gaveta, :frente_gaveta, :traseira_gaveta].include?(peca.tipo)

        larg_canal = esp_fundo + 0.5
        dist_base  = Config::CANAL_GAVETA_DIST_BASE
        prof       = Config::CANAL_GAVETA_PROF
        cnc = esp_fundo <= 3 ? Config::CNC_PARAMS[:canal_3mm] : Config::CNC_PARAMS[:canal_6mm]

        [Usinagem.new(
          tipo: :canal, x: 0, y: dist_base,
          comprimento: peca.comprimento, largura: larg_canal, profundidade: prof,
          face: :interna, ferramenta: cnc[:ferramenta_d],
          rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
          descricao: "Canal p/ fundo gaveta #{esp_fundo}mm", peca_nome: peca.nome
        )]
      end

      # ═══════════════════════════════════════════════
      # REBAIXO (rabbet) — para fundo sobreposto
      # ═══════════════════════════════════════════════
      # Rebaixo = espessura do painel + 1mm folga, profundidade 10mm
      def self.rebaixo_fundo(peca, modulo_info)
        return [] unless modulo_info.tipo_fundo == Config::FUNDO_SOBREPOSTO
        return [] unless [:lateral, :base, :topo].include?(peca.tipo)

        esp_fundo = modulo_info.espessura_fundo
        spec = Config::FUNDO_METODO[:rebaixo]
        larg_rebaixo = esp_fundo + spec[:folga]
        prof = spec[:prof_rebaixo]
        cnc = Config::CNC_PARAMS[:canal_6mm]

        [Usinagem.new(
          tipo: :rebaixo, x: 0, y: peca.largura - larg_rebaixo,
          comprimento: peca.comprimento, largura: larg_rebaixo, profundidade: prof,
          face: :traseira, ferramenta: cnc[:ferramenta_d],
          rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
          descricao: "Rebaixo p/ fundo sobreposto #{esp_fundo}mm", peca_nome: peca.nome
        )]
      end

      # ═══════════════════════════════════════════════
      # DADO / HOUSING (encaixe para prateleira fixa / divisória)
      # ═══════════════════════════════════════════════
      # Dado cego: começa/termina 10-15mm antes da borda frontal
      # Profundidade: metade da espessura do painel (7-10mm)
      # Largura: espessura do painel encaixado (14.5mm p/ tight fit em 15mm)
      def self.dado_housing(peca, posicao_y, esp_encaixe = 15, opts = {})
        cego = opts[:cego] != false  # padrão: dado cego (blind dado)
        margem_frontal = opts[:margem_frontal] || 12  # mm — onde o dado para (antes da borda frontal)
        prof = opts[:profundidade] || (esp_encaixe <= 15 ? 7.5 : 9.0)
        larg = opts[:largura] || (esp_encaixe - 0.5)  # tight fit
        cnc = esp_encaixe <= 15 ? Config::CNC_PARAMS[:dado_15mm] : Config::CNC_PARAMS[:dado_18mm]

        comp_dado = cego ? (peca.largura - margem_frontal) : peca.largura

        [Usinagem.new(
          tipo: :dado, x: (cego ? 0 : 0), y: posicao_y - (larg / 2.0),
          comprimento: comp_dado, largura: larg, profundidade: prof,
          face: :interna, ferramenta: cnc[:ferramenta_d],
          rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
          descricao: "Dado #{cego ? 'cego' : 'passante'} #{esp_encaixe}mm — prof #{prof}mm",
          peca_nome: peca.nome
        )]
      end

      # ═══════════════════════════════════════════════
      # FRESAGEM DE PERFIL DE BORDA
      # ═══════════════════════════════════════════════
      def self.fresagem_perfil(peca, perfil, arestas = [:frente])
        return [] if perfil == :reto
        info = PERFIS_BORDA[perfil]
        return [] unless info
        cnc = Config::CNC_PARAMS[:perfil_borda]

        arestas.map do |aresta|
          comp = case aresta
                 when :frente, :tras then peca.comprimento
                 when :topo, :base then peca.largura
                 end

          Usinagem.new(
            tipo: :fresagem_perfil, x: 0, y: 0,
            comprimento: comp, largura: info[:raio] * 2, profundidade: info[:raio],
            face: aresta, ferramenta: info[:ferramenta],
            rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: nil,
            descricao: "Perfil #{info[:descricao]} — #{aresta}", peca_nome: peca.nome
          )
        end
      end

      # ═══════════════════════════════════════════════
      # POCKET PARA DOBRADIÇA (caneco Ø35mm)
      # ═══════════════════════════════════════════════
      # Specs Blum: Ø35mm, 12.5mm prof, recuo 23mm da borda
      # Placa montagem: 37mm da borda do módulo
      def self.pocket_dobradica(peca, posicoes_y, recuo_x = nil)
        recuo = recuo_x || Config::CANECO_RECUO_BORDA  # 23mm (Blum standard)
        cnc = Config::CNC_PARAMS[:caneco_35mm]

        posicoes_y.map do |pos_y|
          Usinagem.new(
            tipo: :pocket, x: recuo, y: pos_y,
            comprimento: 0, largura: 0, profundidade: Config::CANECO_PROF,
            diametro: Config::CANECO_D, face: :interna, ferramenta: cnc[:ferramenta_d],
            rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: nil,
            descricao: "Caneco dobradiça Ø#{Config::CANECO_D}mm — prof #{Config::CANECO_PROF}mm",
            peca_nome: peca.nome
          )
        end
      end

      # ═══════════════════════════════════════════════
      # FURAÇÃO PLACA DE MONTAGEM (no módulo)
      # ═══════════════════════════════════════════════
      # Furos para fixar a placa de montagem (calço) na lateral do módulo
      # Spec: 37mm da borda frontal do módulo, Ø3mm, prof 12mm
      def self.furacao_placa_montagem(peca, posicoes_y, recuo_x = nil)
        recuo = recuo_x || Config::CALCO_PLACA_RECUO  # 37mm
        posicoes_y.map do |pos_y|
          Usinagem.new(
            tipo: :furo, x: recuo, y: pos_y,
            diametro: 3.0, profundidade: 12.0,
            face: :interna, ferramenta: 3.0,
            rpm: 6_000, avanco: nil, prof_passe: nil,
            descricao: "Furo placa montagem dobradiça — 37mm borda",
            peca_nome: peca.nome
          )
        end
      end

      # ═══════════════════════════════════════════════
      # CANAL PARA VIDRO (portas com vidro)
      # ═══════════════════════════════════════════════
      # Specs reais: canal = vidro + 1mm folga, prof 10-12mm
      # Config::PORTA_VIDRO define parâmetros padrão
      def self.canal_vidro(peca, esp_vidro = nil, prof_canal = nil, larg_quadro = nil)
        spec = Config::PORTA_VIDRO
        esp_vidro   ||= spec[:esp_vidro]         # 4mm
        larg_canal    = spec[:canal_vidro_largura] # 5mm (vidro + 1mm)
        prof_canal  ||= spec[:canal_vidro_prof]    # 11mm
        larg_quadro ||= spec[:largura_quadro]      # 70mm

        cnc = Config::CNC_PARAMS[:canal_3mm]  # usa fresa 3mm com passes

        usinagens = []

        # Canal nas 4 bordas internas do quadro
        comp_int = peca.comprimento - (2 * larg_quadro)
        larg_int = peca.largura - (2 * larg_quadro)

        # Canal horizontal superior e inferior
        [:topo, :base].each do |pos|
          y_pos = pos == :topo ? peca.largura - larg_quadro : larg_quadro
          usinagens << Usinagem.new(
            tipo: :canal, x: larg_quadro, y: y_pos,
            comprimento: comp_int, largura: larg_canal, profundidade: prof_canal,
            face: :interna, ferramenta: esp_vidro,
            rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
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
            rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
            descricao: "Canal p/ vidro #{esp_vidro}mm (#{pos})", peca_nome: peca.nome
          )
        end

        usinagens
      end

      # ═══════════════════════════════════════════════
      # FRESAGEM PROVENÇAL / SHAKER
      # ═══════════════════════════════════════════════
      # Método MDF simulação: pocket na face frontal, deixando quadro intacto
      # Specs: Config::PORTA_PROVENCAL
      # Profundidade pocket: 6-8mm (deixa painel com 10-12mm de espessura)
      def self.fresagem_provencal(peca, opts = {})
        spec = Config::PORTA_PROVENCAL
        margem        = opts[:margem]       || spec[:largura_stile]    # 60mm
        largura_fresa = opts[:largura]      || 10   # largura do canal
        profundidade  = opts[:profundidade] || spec[:pocket_prof]      # 7mm
        raio_canto    = opts[:raio_canto]   || spec[:raio_canto]       # 8mm
        cnc = Config::CNC_PARAMS[:pocket]

        # Retângulo fresado na face da porta
        comp_int = peca.comprimento - (2 * margem)
        larg_int = peca.largura - (2 * margem)

        usinagens = []

        # 4 canais formando o quadro provençal
        # Horizontal superior
        usinagens << Usinagem.new(
          tipo: :canal, x: margem, y: margem,
          comprimento: comp_int, largura: largura_fresa, profundidade: profundidade,
          face: :frontal, ferramenta: cnc[:ferramenta_d],
          rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
          descricao: 'Fresagem provençal — horizontal sup', peca_nome: peca.nome
        )
        # Horizontal inferior
        usinagens << Usinagem.new(
          tipo: :canal, x: margem, y: peca.largura - margem,
          comprimento: comp_int, largura: largura_fresa, profundidade: profundidade,
          face: :frontal, ferramenta: cnc[:ferramenta_d],
          rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
          descricao: 'Fresagem provençal — horizontal inf', peca_nome: peca.nome
        )
        # Vertical esquerdo
        usinagens << Usinagem.new(
          tipo: :canal, x: margem, y: margem,
          comprimento: larg_int, largura: largura_fresa, profundidade: profundidade,
          face: :frontal, ferramenta: cnc[:ferramenta_d],
          rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
          descricao: 'Fresagem provençal — vertical esq', peca_nome: peca.nome
        )
        # Vertical direito
        usinagens << Usinagem.new(
          tipo: :canal, x: peca.comprimento - margem, y: margem,
          comprimento: larg_int, largura: largura_fresa, profundidade: profundidade,
          face: :frontal, ferramenta: cnc[:ferramenta_d],
          rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
          descricao: 'Fresagem provençal — vertical dir', peca_nome: peca.nome
        )

        usinagens
      end

      # ═══════════════════════════════════════════════
      # FRESAGEM ALMOFADADA (raised panel simulation)
      # ═══════════════════════════════════════════════
      # Pocket na face frontal criando efeito de almofada em relevo
      # O centro fica saliente (não fresado), borda é rebaixada
      def self.fresagem_almofadada(peca, opts = {})
        spec = Config::PORTA_ALMOFADADA
        margem       = opts[:margem]       || spec[:largura_stile]  # 60mm
        profundidade = opts[:profundidade] || 4   # mm — rebaixo leve
        cnc = Config::CNC_PARAMS[:pocket]

        comp_int = peca.comprimento - (2 * margem)
        larg_int = peca.largura - (2 * margem)

        usinagens = []

        # Pocket retangular ao redor do centro (simulando moldura rebaixada)
        # 4 faixas: topo, base, esquerda, direita
        faixa = 25  # mm — largura da faixa fresada entre moldura e almofada

        # Faixa superior
        usinagens << Usinagem.new(
          tipo: :pocket, x: margem, y: margem,
          comprimento: comp_int, largura: faixa, profundidade: profundidade,
          face: :frontal, ferramenta: cnc[:ferramenta_d],
          rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
          descricao: 'Fresagem almofadada — faixa sup', peca_nome: peca.nome
        )
        # Faixa inferior
        usinagens << Usinagem.new(
          tipo: :pocket, x: margem, y: peca.largura - margem - faixa,
          comprimento: comp_int, largura: faixa, profundidade: profundidade,
          face: :frontal, ferramenta: cnc[:ferramenta_d],
          rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
          descricao: 'Fresagem almofadada — faixa inf', peca_nome: peca.nome
        )
        # Faixa esquerda
        usinagens << Usinagem.new(
          tipo: :pocket, x: margem, y: margem + faixa,
          comprimento: faixa, largura: larg_int - (2 * faixa), profundidade: profundidade,
          face: :frontal, ferramenta: cnc[:ferramenta_d],
          rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
          descricao: 'Fresagem almofadada — faixa esq', peca_nome: peca.nome
        )
        # Faixa direita
        usinagens << Usinagem.new(
          tipo: :pocket, x: margem + comp_int - faixa, y: margem + faixa,
          comprimento: faixa, largura: larg_int - (2 * faixa), profundidade: profundidade,
          face: :frontal, ferramenta: cnc[:ferramenta_d],
          rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
          descricao: 'Fresagem almofadada — faixa dir', peca_nome: peca.nome
        )

        usinagens
      end

      # ═══════════════════════════════════════════════
      # FURAÇÃO PARA CAVILHA (junção de painéis)
      # ═══════════════════════════════════════════════
      # Specs reais: Ø8mm (padrão), prof 19mm, espaçamento 96mm (sistema 32mm)
      # Regra: diâmetro = 1/3 da espessura do painel
      # Folga do furo: +0.15mm do diâmetro da cavilha
      def self.furacao_cavilha_painel(peca, opts = {})
        tipo_cav    = opts[:tipo] || :padrao
        spec        = Config::CAVILHA_SPECS[tipo_cav] || Config::CAVILHA_SPECS[:padrao]
        diametro    = spec[:diametro]
        profundidade= spec[:furo_prof]
        espacamento = opts[:espacamento] || Config::CAVILHA_ESPACAMENTO_MIN  # 96mm
        margem      = opts[:margem] || Config::CAVILHA_DIST_BORDA_MIN        # 32mm
        furo_d      = diametro + Config::CAVILHA_FOLGA_FURO                  # 8.15mm

        usinagens = []
        bordas = opts[:bordas] || [:direita]

        bordas.each do |borda|
          case borda
          when :direita, :esquerda
            comp = peca.comprimento
            pos = margem
            while pos <= (comp - margem)
              x = borda == :direita ? peca.largura : 0
              usinagens << Usinagem.new(
                tipo: :furo, x: x, y: pos,
                diametro: furo_d, profundidade: profundidade,
                face: "borda_#{borda}".to_sym, ferramenta: furo_d,
                rpm: 6_000, avanco: nil, prof_passe: nil,
                descricao: "Cavilha Ø#{diametro}mm — prof #{profundidade}mm",
                peca_nome: peca.nome
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
                diametro: furo_d, profundidade: profundidade,
                face: "borda_#{borda}".to_sym, ferramenta: furo_d,
                rpm: 6_000, avanco: nil, prof_passe: nil,
                descricao: "Cavilha Ø#{diametro}mm — prof #{profundidade}mm",
                peca_nome: peca.nome
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
      # Specs reais: ângulo 20°, ripa 6mm × 30mm, mortise 11mm prof
      # Espaçamento calculado pela fórmula:
      #   spacing = (esp_stile + esp_ripa) / sin(angulo)
      def self.rasgos_veneziana(peca, opts = {})
        spec = Config::PORTA_VENEZIANA
        angulo      = opts[:angulo]         || spec[:angulo_ripa]    # 20°
        esp_ripa    = opts[:espessura_ripa] || spec[:esp_ripa]       # 6mm
        larg_ripa   = opts[:largura_ripa]   || spec[:largura_ripa]   # 30mm
        prof_rasgo  = opts[:profundidade]   || spec[:mortise_prof]    # 11mm
        larg_quadro = opts[:largura_quadro] || spec[:largura_quadro]  # 55mm

        # Espaçamento real calculado pela fórmula de veneziana
        angulo_rad  = angulo * Math::PI / 180.0
        espacamento = ((spec[:esp_stile] + esp_ripa) / Math.sin(angulo_rad)).round(1)
        espacamento = opts[:espacamento] || espacamento

        usinagens = []
        larg_rasgo = esp_ripa + 0.5  # folga para encaixe

        # Rasgos nos montantes (área útil = comprimento - 2 × largura quadro)
        pos_y = larg_quadro + 15  # início após travessa inferior + margem
        limite = peca.comprimento - larg_quadro - 15

        while pos_y <= limite
          usinagens << Usinagem.new(
            tipo: :rasgo, x: 0, y: pos_y,
            comprimento: larg_ripa, largura: larg_rasgo, profundidade: prof_rasgo,
            face: :interna, ferramenta: esp_ripa,
            rpm: 18_000, avanco: 3.0, prof_passe: nil,
            descricao: "Rasgo veneziana #{angulo}° — Ø#{larg_rasgo}mm × #{prof_rasgo}mm prof — pos #{pos_y.round(0)}mm",
            peca_nome: peca.nome
          )
          pos_y += espacamento
        end

        usinagens
      end

      # ═══════════════════════════════════════════════
      # FRESAGEM PERFIL GOLA (puxador embutido / J-pull)
      # ═══════════════════════════════════════════════
      # Specs: 30mm prof × 12mm larg (J-pull padrão) ou customizado
      def self.fresagem_gola(peca, posicao = :topo, profundidade = 15, largura = 40)
        cnc = Config::CNC_PARAMS[:pocket]
        y = case posicao
            when :topo then peca.comprimento - profundidade
            when :base then 0
            end

        [Usinagem.new(
          tipo: :fresagem_perfil, x: 0, y: y,
          comprimento: peca.largura, largura: largura, profundidade: profundidade,
          face: :superior, ferramenta: cnc[:ferramenta_d],
          rpm: cnc[:rpm], avanco: cnc[:avanco], prof_passe: cnc[:prof_passe],
          descricao: "Fresagem gola (puxador embutido) #{posicao}", peca_nome: peca.nome
        )]
      end

      # ═══════════════════════════════════════════════
      # FURAÇÃO MINIFIX (face + borda)
      # ═══════════════════════════════════════════════
      # Face: Ø15mm, prof 12.7mm (alojamento do minifix)
      # Borda: Ø8mm, prof 34mm (parafuso)
      def self.furacao_minifix(peca, posicoes, eixo = :horizontal)
        usinagens = []
        posicoes.each do |pos|
          # Furo na face (alojamento)
          usinagens << Usinagem.new(
            tipo: :furo, x: pos[:x], y: pos[:y],
            diametro: Config::FURO_MINIFIX_FACE_D, profundidade: Config::FURO_MINIFIX_FACE_PROF,
            face: :inferior, ferramenta: Config::FURO_MINIFIX_FACE_D,
            rpm: 4_000, avanco: nil, prof_passe: nil,
            descricao: "Minifix face Ø#{Config::FURO_MINIFIX_FACE_D}mm", peca_nome: peca.nome
          )
          # Furo na borda (parafuso)
          borda_face = eixo == :horizontal ? :borda_topo : :borda_esquerda
          usinagens << Usinagem.new(
            tipo: :furo, x: pos[:x], y: pos[:y],
            diametro: Config::FURO_MINIFIX_BORDA_D, profundidade: Config::FURO_MINIFIX_BORDA_PROF,
            face: borda_face, ferramenta: Config::FURO_MINIFIX_BORDA_D,
            rpm: 6_000, avanco: nil, prof_passe: nil,
            descricao: "Minifix borda Ø#{Config::FURO_MINIFIX_BORDA_D}mm", peca_nome: peca.nome
          )
        end
        usinagens
      end

      # ═══════════════════════════════════════════════
      # FURAÇÃO CONFIRMAT (borda)
      # ═══════════════════════════════════════════════
      # Face da peça adjacente: Ø8mm passante ou prof 10mm
      # Borda da peça recebedora: Ø5mm, prof 50mm
      def self.furacao_confirmat(peca, posicoes, tipo_furo = :borda)
        posicoes.map do |pos|
          d    = tipo_furo == :borda ? Config::FURO_CONFIRMAT_BORDA_D : Config::FURO_CONFIRMAT_FACE_D
          prof = tipo_furo == :borda ? Config::FURO_CONFIRMAT_BORDA_PROF : 10.0
          face = tipo_furo == :borda ? :borda_topo : :inferior

          Usinagem.new(
            tipo: :furo, x: pos[:x], y: pos[:y],
            diametro: d, profundidade: prof,
            face: face, ferramenta: d,
            rpm: 5_000, avanco: nil, prof_passe: nil,
            descricao: "Confirmat #{tipo_furo} Ø#{d}mm — prof #{prof}mm",
            peca_nome: peca.nome
          )
        end
      end

      # ═══════════════════════════════════════════════
      # VALIDAÇÃO DE COLISÃO ENTRE USINAGENS
      # ═══════════════════════════════════════════════
      def self.validar_colisoes(usinagens)
        erros = []
        avisos = []

        por_peca = usinagens.group_by(&:peca_nome)

        por_peca.each do |peca_nome, usins|
          por_face = usins.group_by(&:face)

          por_face.each do |face, usins_face|
            usins_face.combination(2).each do |u1, u2|
              # Sobreposição de furos
              if u1.tipo == :furo && u2.tipo == :furo
                dist = Math.sqrt((u1.x - u2.x)**2 + (u1.y - u2.y)**2)
                raio_soma = ((u1.diametro || 0) + (u2.diametro || 0)) / 2.0
                if dist < raio_soma
                  erros << "#{peca_nome} [#{face}]: #{u1.descricao} colide com #{u2.descricao} (dist: #{dist.round(1)}mm)"
                elsif dist < raio_soma + 3
                  avisos << "#{peca_nome} [#{face}]: #{u1.descricao} muito perto de #{u2.descricao} (dist: #{dist.round(1)}mm)"
                end
              end

              # Sobreposição de canais
              if u1.tipo == :canal && u2.tipo == :canal
                if (u1.y - u2.y).abs < ((u1.largura + u2.largura) / 2.0)
                  if u1.x < (u2.x + (u2.comprimento || 0)) && u2.x < (u1.x + (u1.comprimento || 0))
                    erros << "#{peca_nome} [#{face}]: Canais se sobrepõem — #{u1.descricao} e #{u2.descricao}"
                  end
                end
              end

              # Furo dentro de canal
              if u1.tipo == :furo && u2.tipo == :canal
                if u1.x >= u2.x && u1.x <= (u2.x + (u2.comprimento || 0)) &&
                   (u1.y - u2.y).abs < ((u2.largura || 0) / 2.0 + (u1.diametro || 0) / 2.0)
                  avisos << "#{peca_nome} [#{face}]: #{u1.descricao} dentro do #{u2.descricao}"
                end
              end
            end

            # Limites da peça
            usins_face.each do |u|
              if u.tipo == :furo
                raio = (u.diametro || 0) / 2.0
                if (u.x || 0) - raio < 3 || (u.y || 0) - raio < 3
                  avisos << "#{peca_nome} [#{face}]: #{u.descricao} muito perto da borda (mín 3mm)"
                end
              end
            end
          end
        end

        { erros: erros, avisos: avisos, valido: erros.empty? }
      end

      # ═══════════════════════════════════════════════
      # GERA TODAS AS USINAGENS DE UM MÓDULO
      # ═══════════════════════════════════════════════
      def self.gerar_usinagens_modulo(modulo_info)
        mi = modulo_info
        todas = []

        mi.pecas.each do |peca|
          # Canal de fundo do módulo
          todas += canal_fundo(peca, mi)

          # Canal de fundo de gaveta
          if [:lateral_gaveta, :frente_gaveta, :traseira_gaveta].include?(peca.tipo)
            todas += canal_fundo_gaveta(peca)
          end

          # Rebaixo de fundo sobreposto
          todas += rebaixo_fundo(peca, mi)

          # Caneco de dobradiça em portas
          if peca.tipo == :porta
            qtd = Utils.qtd_dobradicas(peca.comprimento)
            posicoes = calcular_posicoes_dobradica(peca.comprimento, qtd)
            todas += pocket_dobradica(peca, posicoes)
          end
        end

        todas
      end

      # ═══════════════════════════════════════════════
      # RELATÓRIO DE USINAGENS (texto formatado)
      # ═══════════════════════════════════════════════
      def self.relatorio_texto(usinagens)
        return "Nenhuma usinagem registrada." if usinagens.empty?

        linhas = ["═══ RELATÓRIO DE USINAGENS CNC ═══\n"]
        linhas << "Total: #{usinagens.length} operações\n"

        por_peca = usinagens.group_by(&:peca_nome)
        por_peca.each do |nome, usins|
          linhas << "\n── #{nome} (#{usins.length} operações) ──"
          usins.each_with_index do |u, i|
            linhas << "  #{i + 1}. #{u.descricao}"
            linhas << "     Face: #{u.face} | Ferramenta: Ø#{u.ferramenta}mm"
            if u.rpm
              linhas << "     RPM: #{u.rpm} | Avanço: #{u.avanco} m/min"
            end
            if u.tipo == :furo
              linhas << "     Pos: (#{(u.x || 0).round(1)}, #{(u.y || 0).round(1)}) | Ø#{u.diametro}mm × #{u.profundidade}mm"
            elsif u.comprimento && u.comprimento > 0
              linhas << "     Pos: (#{(u.x || 0).round(1)}, #{(u.y || 0).round(1)}) | #{u.comprimento.round(1)} × #{(u.largura || 0).round(1)} × #{u.profundidade}mm"
            end
          end
        end

        # Validação
        validacao = validar_colisoes(usinagens)
        unless validacao[:erros].empty? && validacao[:avisos].empty?
          linhas << "\n═══ VALIDAÇÃO ═══"
          validacao[:erros].each { |e| linhas << "  ❌ ERRO: #{e}" }
          validacao[:avisos].each { |a| linhas << "  ⚠️  AVISO: #{a}" }
        end

        linhas.join("\n")
      end

      # ═══════════════════════════════════════════════
      # EXPORTAR USINAGENS CSV
      # ═══════════════════════════════════════════════
      def self.exportar_csv(usinagens, caminho)
        CSV.open(caminho, 'wb', col_sep: ';') do |csv|
          csv << %w[Peca Tipo Face X Y Comprimento Largura Profundidade Diametro Ferramenta RPM Avanco Descricao]
          usinagens.each do |u|
            csv << [
              u.peca_nome, u.tipo, u.face,
              (u.x || 0).round(1), (u.y || 0).round(1),
              (u.comprimento || 0).round(1), (u.largura || 0).round(1),
              u.profundidade, u.diametro, u.ferramenta,
              u.rpm, u.avanco, u.descricao
            ]
          end
        end
        caminho
      end

      private

      # Calcula posições Y das dobradiças na porta
      # Recuo padrão: 80mm do topo/base (Config::DOBRADICA_RECUO_BORDA)
      def self.calcular_posicoes_dobradica(altura_porta, qtd)
        recuo = Config::DOBRADICA_RECUO_BORDA  # 80mm
        return [recuo] if qtd <= 1

        posicoes = [recuo, altura_porta - recuo]
        if qtd > 2
          espaco = (altura_porta - (2 * recuo)) / (qtd - 1).to_f
          (1..(qtd - 2)).each do |i|
            posicoes << (recuo + espaco * i).round(1)
          end
        end
        posicoes.sort
      end
    end
  end
end
