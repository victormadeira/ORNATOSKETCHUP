# ornato_plugin/config.rb — Constantes e configurações padrão

module Ornato
  module Config
    # ─── Dimensões Padrão (mm) ───
    ESPESSURA_CORPO_PADRAO   = 15
    ESPESSURA_FUNDO_PADRAO   = 3
    REBAIXO_FUNDO_PADRAO     = 8
    FOLGA_PORTA              = 2
    FOLGA_ENTRE_PORTAS       = 3
    FOLGA_GAVETA_VERTICAL    = 3
    RECUO_RODAPE_PADRAO      = 50
    ALTURA_RODAPE_PADRAO     = 100
    RECUO_PRATELEIRA_FRONTAL = 20
    RECUO_TRASEIRO_GAVETA    = 50

    # ─── Sistema 32mm ───
    SISTEMA_32_PASSO         = 32
    SISTEMA_32_INICIO        = 37    # distância da borda frontal
    SISTEMA_32_RECUO_BORDA   = 9.5   # centro do furo na espessura 15mm

    # ─── Furação ───
    FURO_MINIFIX_FACE_D      = 15.0
    FURO_MINIFIX_FACE_PROF   = 12.7
    FURO_MINIFIX_BORDA_D     = 8.0
    FURO_MINIFIX_BORDA_PROF  = 34.0
    FURO_CAVILHA_D           = 8.0
    FURO_CAVILHA_PROF        = 16.0
    FURO_CANECO_D            = 35.0
    FURO_CANECO_PROF         = 12.0
    FURO_CANECO_RECUO        = 22.0  # da borda da porta
    FURO_PIN_D               = 5.0
    FURO_PIN_PROF            = 10.0
    FURO_PUXADOR_D           = 5.0
    FURO_CONFIRMAT_FACE_D    = 8.0
    FURO_CONFIRMAT_BORDA_D   = 5.0
    FURO_CONFIRMAT_BORDA_PROF= 50.0

    # ─── Dobradiça — quantidade por altura ───
    DOBRADICA_REGRAS = [
      { ate: 600,  qtd: 2 },
      { ate: 900,  qtd: 2 },
      { ate: 1200, qtd: 3 },
      { ate: 1600, qtd: 4 },
      { ate: 99999, qtd: 5 }
    ].freeze
    DOBRADICA_RECUO_BORDA = 80  # mm do topo/base da porta

    # ─── Corrediça — especificações técnicas por tipo ───
    # Fonte: manuais Blum, Hettich, Grass (2024/2025)
    CORREDICA_SPECS = {
      # ── Telescópica (ball-bearing side-mount) ──
      # Blum 560H/566H, Hettich, King Slide, Accuride
      telescopica: {
        nome: 'Telescópica Lateral',
        folga_por_lado: 12.7,         # mm — espaço entre gaveta e lateral do módulo
        montagem: :lateral,            # fixa na lateral do módulo e da gaveta
        extensao: :total,              # extensão total (full extension)
        altura_mecanismo: 45.0,        # mm — altura do perfil da corrediça
        comprimentos: [250, 300, 350, 400, 450, 500, 550, 600, 650, 700],
        capacidade_kg: [30, 45, 60],   # leve, médio, pesado
        largura_min_gaveta: 200,       # mm
        largura_max_gaveta: 610,       # mm
        soft_close: :opcional,         # add-on ou integrado
        # Fórmula: largura gaveta = vão interno - (2 × 12.7) = vão - 25.4
        furos_por_trilho: 3,           # parafusos por trilho
        furo_diametro: 4.0,            # mm
        posicao_vertical: :centro_lateral  # centro da lateral da gaveta
      },

      # ── Oculta / Embutida (undermount) ──
      # Blum TANDEM 560H/563H/566H/569H
      oculta: {
        nome: 'Oculta (Undermount)',
        folga_por_lado: 5.0,           # mm — folga real entre gaveta e lateral
        deducao_interna: 42.0,         # mm — largura interna da gaveta = vão - 42mm (Blum TANDEM)
        montagem: :inferior,           # fixa no fundo do módulo (embaixo da gaveta)
        extensao: :total,
        altura_mecanismo: 13.0,        # mm — altura do trilho runner
        folga_inferior: 14.0,          # mm — espaço abaixo da gaveta até o fundo do módulo
        folga_superior: 7.0,           # mm — espaço acima da gaveta
        comprimentos: [250, 270, 300, 350, 400, 450, 500, 550, 600],
        capacidade_kg: { '560H' => 30, '563H' => 45, '566H' => 50, '569H' => 65 },
        largura_min_interna: 95,       # mm
        largura_max_modulo: 600,       # mm
        soft_close: :integrado,        # Blumotion integrado
        # Fórmula: largura interna gaveta = vão - 42mm
        #          largura externa gaveta = vão - 42 + (2 × espessura_lateral)
        #          Para lateral 15mm: externa = vão - 42 + 30 = vão - 12mm
        #          Comprimento gaveta = comprimento corrediça - 10mm
        espessura_fundo_min: 12,       # mm — fundo da gaveta precisa ser estrutural
        fixacao_frontal: :locking_device, # clip de fixação Blum
        ajuste_altura: 2.0,            # mm — ajuste vertical da frente
        ajuste_lateral: 1.5,           # mm — ajuste lateral da frente
        bracket_traseiro: true,        # necessita bracket traseiro no fundo do módulo
        lateral_limpa: true            # sem corrediça aparente na lateral
      },

      # ── Tandembox (sistema de caixa metálica) ──
      # Blum TANDEMBOX Antaro/Intivo
      tandembox: {
        nome: 'Tandembox (Caixa Metálica)',
        folga_por_lado: 5.0,           # mm — folga real
        deducao_interna: 42.0,         # mm — para largura interna
        deducao_base: 75.0,            # mm — para fundo/base da gaveta
        perfil_lateral: 16.5,          # mm — espessura do perfil metálico
        montagem: :inferior,
        extensao: :total,
        # Alturas disponíveis dos perfis laterais (códigos Blum)
        alturas_perfil: {
          'N' => { perfil: 68,  sistema: 83,  util: 50 },
          'M' => { perfil: 83,  sistema: 99,  util: 68 },
          'K' => { perfil: 115, sistema: 131, util: 99 },
          'D' => { perfil: 203, sistema: 220, util: 195 }
        },
        comprimentos: [270, 300, 350, 400, 450, 500, 550, 600, 650],
        capacidade_kg: [30, 65],
        largura_min_modulo: 300,       # mm
        largura_max_modulo: 1200,      # mm
        soft_close: :integrado,        # Blumotion
        fixacao_frontal: :inserta,     # INSERTA ou ZSF bracket
        ajuste_altura: 2.0,
        ajuste_lateral: 1.5,
        bracket_traseiro: true,
        lateral_metalica: true         # não usa lateral de MDF — perfil metálico
      },

      # ── Roller (econômica, nylon) ──
      # Grass 6600, FGV, genérica
      roller: {
        nome: 'Roller (Econômica)',
        folga_por_lado: 12.5,          # mm
        montagem: :lateral,
        extensao: :parcial,            # 3/4 de extensão (não abre totalmente)
        altura_mecanismo: 37.0,        # mm
        comprimentos: [250, 300, 350, 400, 450, 500, 550, 600],
        capacidade_kg: [34],
        largura_max_gaveta: 610,
        soft_close: :nenhum,           # apenas auto-fechamento por gravidade
        auto_fechamento: true,         # roldana puxa a gaveta nos últimos 25mm
        furos_por_trilho: 2,
        furo_diametro: 4.0,
        posicao_vertical: :base_lateral
      }
    }.freeze

    # Comprimentos padrão consolidados (para snap)
    CORREDICA_COMPRIMENTOS = [250, 270, 300, 350, 400, 450, 500, 550, 600, 650, 700].freeze

    # Folga simplificada por tipo (retrocompatibilidade)
    CORREDICA_FOLGAS = {
      telescopica: 12.7,
      oculta:      5.0,    # folga real (deducao interna é 42mm/2=21mm por lado)
      tandembox:   5.0,    # folga real (usa perfil metálico)
      roller:      12.5
    }.freeze

    # ─── Gaveta — folgas e regras ───
    GAVETA_FOLGA_ENTRE_FRENTES = 3.0   # mm — espaço entre frentes de gavetas empilhadas
    GAVETA_FRENTE_MAIOR_CAIXA  = 30    # mm — frente da gaveta é X mm maior que caixa
    GAVETA_ALTURA_LATERAL_MIN  = 60    # mm — altura mínima da lateral da gaveta
    GAVETA_ALTURA_FRENTE_MIN   = 80    # mm — altura mínima da frente da gaveta
    GAVETA_MAX_POR_VAO         = 8     # máximo de gavetas empilhadas num vão

    # ─── Tipos de módulo ───
    TIPOS_MODULO = %w[
      inferior superior torre bancada estante gaveteiro painel
    ].freeze

    # ─── Tipos de montagem ───
    MONTAGEM_BRASIL  = :laterais_entre   # laterais entre base e topo
    MONTAGEM_EUROPA  = :base_topo_entre  # base e topo entre laterais

    # ─── Tipos de fundo ───
    FUNDO_REBAIXADO  = :rebaixado
    FUNDO_SOBREPOSTO = :sobreposto
    FUNDO_SEM        = :sem_fundo

    # ─── Tipos de base ───
    BASE_RODAPE      = :rodape
    BASE_PES         = :pes_regulaveis
    BASE_DIRETA      = :direta
    BASE_SUSPENSA    = :suspensa

    # ─── Tipos de fixação ───
    FIXACAO_MINIFIX  = :minifix
    FIXACAO_VB       = :vb
    FIXACAO_CAVILHA  = :cavilha
    FIXACAO_CONFIRMAT= :confirmat

    # ─── Tipos de porta ───
    PORTA_ABRIR      = :abrir
    PORTA_BASCULANTE = :basculante
    PORTA_CORRER     = :correr

    # ─── Sobreposição de porta ───
    SOBREP_TOTAL     = :total
    SOBREP_MEIA      = :meia
    SOBREP_INTERNA   = :interna

    # ─── Corrediça tipo ───
    CORR_TELESCOPICA = :telescopica
    CORR_OCULTA      = :oculta
    CORR_TANDEMBOX   = :tandembox
    CORR_ROLLER      = :roller

    # ─── Parâmetros CNC (velocidades e ferramentas) ───
    CNC_PARAMS = {
      # Corte de painel (serra / fresa de compressão)
      corte_painel: {
        ferramenta_d: 6, rpm: 18_000, avanco: 7.0, # m/min
        prof_passe: :total, descricao: 'Corte painel — fresa compressão 6mm'
      },
      # Canal / groove (fresa reta)
      canal_3mm: {
        ferramenta_d: 3, rpm: 18_000, avanco: 4.0,
        prof_passe: 5.0, descricao: 'Canal 3mm — fresa reta 3mm'
      },
      canal_6mm: {
        ferramenta_d: 6, rpm: 18_000, avanco: 5.0,
        prof_passe: 5.0, descricao: 'Canal 6mm — fresa reta 6mm'
      },
      # Dado / housing (fresa reta)
      dado_15mm: {
        ferramenta_d: 6, rpm: 18_000, avanco: 3.5,
        prof_passe: 4.0, passes: 2, descricao: 'Dado 15mm — 2 passes'
      },
      dado_18mm: {
        ferramenta_d: 6, rpm: 18_000, avanco: 3.5,
        prof_passe: 5.0, passes: 2, descricao: 'Dado 18mm — 2 passes'
      },
      # Pocket (fresa reta para rebaixos)
      pocket: {
        ferramenta_d: 8, rpm: 18_000, avanco: 4.0,
        prof_passe: 3.5, descricao: 'Pocket genérico — fresa 8mm'
      },
      # Furação caneco dobradiça (broca Forstner)
      caneco_35mm: {
        ferramenta_d: 35, rpm: 4_000, avanco: :plunge,
        prof_passe: :total, descricao: 'Caneco 35mm — Forstner'
      },
      # Perfil de borda
      perfil_borda: {
        rpm: 17_000, avanco: 3.0,
        prof_passe: :total, descricao: 'Fresagem perfil de borda'
      },
    }.freeze

    # ─── Caneco dobradiça — specs Blum/Hettich ───
    CANECO_D                 = 35.0   # mm — diâmetro do caneco
    CANECO_PROF              = 12.5   # mm — profundidade (12-13mm)
    CANECO_RECUO_BORDA       = 23.0   # mm — centro do furo à borda da porta (Blum standard)
    CALCO_PLACA_RECUO        = 37.0   # mm — centro da placa de fixação à borda do módulo

    # ─── Canal fundo — specs reais ───
    CANAL_FUNDO_3MM = {
      largura: 3.5, profundidade: 10.0, dist_borda_tras: 7.0,
      descricao: 'Canal p/ fundo HDF 3mm'
    }.freeze
    CANAL_FUNDO_6MM = {
      largura: 6.5, profundidade: 10.0, dist_borda_tras: 7.0,
      descricao: 'Canal p/ fundo MDF/Comp 6mm'
    }.freeze

    # ─── Canal fundo gaveta ───
    CANAL_GAVETA_DIST_BASE = 8.0     # mm da base da lateral
    CANAL_GAVETA_PROF      = 8.0     # mm

    # ─── Porta — specs construtivas ───
    PORTA_VIDRO = {
      largura_quadro: 70,        # mm — stile/rail (60-80, padrão 70)
      esp_vidro: 4,              # mm
      canal_vidro_largura: 5,    # mm (vidro + 1mm folga)
      canal_vidro_prof: 11,      # mm (10-12mm)
    }.freeze

    PORTA_PROVENCAL = {
      largura_stile: 60,         # mm (55-65)
      largura_rail: 60,          # mm
      canal_painel_largura: 6,   # mm (para painel 6mm)
      canal_painel_prof: 11,     # mm
      pocket_prof: 7,            # mm (fresagem MDF simulação)
      raio_canto: 8,             # mm
    }.freeze

    PORTA_VENEZIANA = {
      angulo_ripa: 20,           # graus (17-25, mais comum 20)
      esp_ripa: 6,               # mm
      largura_ripa: 30,          # mm (30mm p/ portas de armário)
      mortise_prof: 11,          # mm (7/16")
      esp_stile: 20,             # mm
      largura_quadro: 55,        # mm
    }.freeze

    PORTA_ALMOFADADA = {
      largura_stile: 60,         # mm (55-70)
      canal_painel_largura: 6,   # mm
      canal_painel_prof: 11,     # mm
      lingua_painel_esp: 6,      # mm (encaixa no canal)
    }.freeze

    PORTA_PERFIL_AL = {
      larguras_perfil: [3, 8, 19],  # mm — slim, standard, wide
      esp_vidro_aceito: [4, 5, 6],  # mm
      acabamentos: %w[Natural Preto Creme Cinza].freeze,
    }.freeze

    # ─── Cavilha / Dowel — specs reais ───
    CAVILHA_SPECS = {
      padrao: { diametro: 8, comprimento: 35, furo_prof: 19 },  # mm
      leve:   { diametro: 6, comprimento: 30, furo_prof: 17 },
      pesado: { diametro: 10, comprimento: 40, furo_prof: 22 },
    }.freeze
    CAVILHA_ESPACAMENTO_MIN  = 96    # mm — otimizado para sistema 32mm
    CAVILHA_ESPACAMENTO_MAX  = 128   # mm
    CAVILHA_DIST_BORDA_MIN   = 32    # mm — do primeiro furo à borda
    CAVILHA_FOLGA_FURO       = 0.15  # mm — furo = diâmetro + folga

    # ─── Fundo — métodos de instalação ───
    FUNDO_METODO = {
      canal: {
        descricao: 'Canal fresado nos 4 lados',
        folga: 0.5,  # mm — folga no canal
        encaixe: 10, # mm — profundidade de encaixe
      },
      sobreposto_grampeado: {
        descricao: 'Sobreposto e grampeado',
        folga: 1.0,     # mm por lado (menor que carcaça)
        grampo_espacamento: 100,  # mm entre grampos
        grampo_comprimento: 25,   # mm
      },
      rebaixo: {
        descricao: 'Encaixe em rebaixo',
        folga: 1.0,     # mm — rebaixo = espessura painel + folga
        prof_rebaixo: 10, # mm
      },
      dividido: {
        descricao: 'Fundo dividido (> 900mm largura)',
        largura_divisor: 60,  # mm — montante central
        sobreposicao: 10,     # mm — encaixe cada lado
      },
    }.freeze

    # ─── Conversão mm → polegadas SketchUp ───
    MM = 1.mm  # SketchUp usa polegadas internamente; 1.mm converte

    # ─── Cores para visualização ───
    COR_CORPO        = Sketchup::Color.new(240, 235, 220)  # bege claro
    COR_FRENTE       = Sketchup::Color.new(180, 140, 100)  # carvalho
    COR_FUNDO        = Sketchup::Color.new(255, 255, 255)  # branco
    COR_HIGHLIGHT     = Sketchup::Color.new(0, 120, 255, 80)  # azul translúcido
    COR_ERRO         = Sketchup::Color.new(255, 60, 60)
    COR_PREVIEW      = Sketchup::Color.new(100, 200, 100, 60)

    # ─── Atributos SketchUp (dicionário) ───
    DICT_ORNATO      = 'ornato'.freeze
    DICT_MODULO      = 'ornato_modulo'.freeze
    DICT_PECA        = 'ornato_peca'.freeze
    DICT_AGREGADO    = 'ornato_agregado'.freeze
    DICT_VAO         = 'ornato_vao'.freeze
  end
end
