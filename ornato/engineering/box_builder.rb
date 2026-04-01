# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/box_builder.rb — Construtor de caixas (modulos) parametricas
#
# Constroi modulos de marcenaria como Dynamic Components parametricos
# com atributos Ornato (orn_*). O usuario define dimensoes e parametros
# no Component Options do SketchUp, e todas as pecas filhas se
# recalculam automaticamente.
#
# FLUXO DE CONSTRUCAO:
#   1. BoxBuilder.criar(:inferior, largura: 60, profundidade: 55, altura: 72)
#   2. Cria grupo raiz com atributos orn_* do modulo
#   3. Cria pecas filhas (lateral, base, topo, fundo, travessa)
#   4. Cada peca tem formulas parametricas que referenciam Parent!
#   5. Agregados sao adicionados depois (portas, gavetas, prateleiras)
#
# ARQUITETURA DE FORMULAS:
#   - Modulo pai define: orn_largura, orn_profundidade, orn_altura
#   - Pecas filhas calculam suas dimensoes via formulas:
#     Lateral: LenX = orn_profundidade, LenZ = orn_altura
#     Base:    LenX = orn_largura - 2*orn_espessura_corpo, LenY = orn_profundidade
#     Fundo:   LenX = orn_largura - 2*orn_espessura_corpo, LenZ = orn_altura - 2*orn_espessura_corpo
#
# TIPOS DE MODULO:
#   :inferior    — balcao (base com pe/rodape, sem topo passante)
#   :superior    — aereo (topo e base passantes, sem pe)
#   :torre       — coluna alto (2000mm+, laterais grandes)
#   :gaveteiro   — caixa com gavetas (sem portas)
#   :estante     — caixa aberta com prateleiras
#   :roupeiro    — armario grande com divisorias internas
#   :bancada     — tampo com apoios

module Ornato
  # Stubs para Core::Config e Core::Ids caso ainda nao existam.
  # ATENCAO: Se core/config.rb e core/ids.rb estiverem carregados (via main.rb),
  # estes stubs NAO serao definidos. Os valores aqui DEVEM espelhar os reais.
  module Core
    module Config
      # Espessuras reais da marcenaria brasileira:
      #   6mm = HDF fundo/traseira
      #   15mm nominal → 15.5mm real
      #   18mm nominal → 18.5mm real
      #   25mm nominal → 25.5mm real
      #   30mm (dois de 15) → 31.0mm real
      #   36mm (dois de 18) → 37.0mm real
      ESPESSURA_DELTA = {
        6 => 6.0,
        15 => 15.5, 18 => 18.5, 25 => 25.5,
        30 => 31.0, 36 => 37.0
      }.freeze

      def self.real_thickness(nominal_mm)
        ESPESSURA_DELTA[nominal_mm.to_i] || nominal_mm.to_f
      end
    end unless defined?(Core::Config)

    module Ids
      def self.generate
        ts = Time.now.to_i.to_s(16)
        rnd = rand(0xFFFF).to_s(16).rjust(4, '0')
        "orn_#{ts}#{rnd}"
      end
    end unless defined?(Core::Ids)
  end

  module Engineering
    class BoxBuilder

      # ================================================================
      # Configuracoes por tipo de modulo
      # ================================================================
      CONFIGS = {
        inferior: {
          base_passante: :nenhuma,     # base entre laterais (nao passante)
          topo_passante: :nenhuma,     # rega entre laterais
          tem_rodape: true,
          altura_rodape: 100.0,        # mm
          tem_travessa: true,
          fundo_tipo: :encaixado,      # rasgo nas laterais
          fundo_espessura: 6.0,
          prateleiras_padrao: 1,
          descricao: 'Balcao Inferior'
        },
        superior: {
          base_passante: :inferior,    # base passante por baixo
          topo_passante: :superior,    # topo passante por cima
          tem_rodape: false,
          altura_rodape: 0,
          tem_travessa: true,
          fundo_tipo: :encaixado,
          fundo_espessura: 6.0,
          prateleiras_padrao: 1,
          descricao: 'Aereo Superior'
        },
        torre: {
          base_passante: :nenhuma,
          topo_passante: :nenhuma,
          tem_rodape: true,
          altura_rodape: 100.0,
          tem_travessa: false,
          fundo_tipo: :parafusado,
          fundo_espessura: 6.0,
          prateleiras_padrao: 3,
          descricao: 'Torre / Coluna'
        },
        gaveteiro: {
          base_passante: :nenhuma,
          topo_passante: :nenhuma,
          tem_rodape: true,
          altura_rodape: 100.0,
          tem_travessa: false,
          fundo_tipo: :encaixado,
          fundo_espessura: 6.0,
          prateleiras_padrao: 0,
          descricao: 'Gaveteiro'
        },
        estante: {
          base_passante: :ambas,       # base e topo passantes
          topo_passante: :ambas,
          tem_rodape: false,
          altura_rodape: 0,
          tem_travessa: false,
          fundo_tipo: :parafusado,
          fundo_espessura: 6.0,
          prateleiras_padrao: 3,
          descricao: 'Estante Aberta'
        },
        roupeiro: {
          base_passante: :nenhuma,
          topo_passante: :nenhuma,
          tem_rodape: true,
          altura_rodape: 100.0,
          tem_travessa: false,
          fundo_tipo: :parafusado,
          fundo_espessura: 6.0,
          prateleiras_padrao: 2,
          descricao: 'Roupeiro'
        },
        bancada: {
          base_passante: :nenhuma,
          topo_passante: :superior,     # tampo passante (cobre laterais)
          tem_rodape: false,
          altura_rodape: 0,
          tem_travessa: true,
          fundo_tipo: :sem,           # bancada nao tem fundo
          fundo_espessura: 0,
          prateleiras_padrao: 0,
          descricao: 'Bancada / Tampo'
        },
        pia: {
          base_passante: :nenhuma,
          topo_passante: :nenhuma,
          tem_rodape: true,
          altura_rodape: 100.0,
          tem_travessa: true,
          fundo_tipo: :sem,           # pia sem fundo (acesso hidraulica)
          fundo_espessura: 0,
          prateleiras_padrao: 0,
          descricao: 'Balcao de Pia'
        },
        nicho: {
          base_passante: :nenhuma,
          topo_passante: :nenhuma,
          tem_rodape: false,
          altura_rodape: 0,
          tem_travessa: false,
          fundo_tipo: :parafusado,
          fundo_espessura: 6.0,
          prateleiras_padrao: 0,
          descricao: 'Nicho Aberto'
        },

        # ── Modulos especializados ────────────────────────────────

        torre_quente: {
          base_passante: :nenhuma,
          topo_passante: :nenhuma,
          tem_rodape: true,
          altura_rodape: 100.0,
          tem_travessa: false,
          fundo_tipo: :parafusado,
          fundo_espessura: 6.0,
          prateleiras_padrao: 1,       # prateleira entre forno e micro
          descricao: 'Torre Quente (Forno + Micro)'
        },
        cooktop: {
          base_passante: :nenhuma,
          topo_passante: :nenhuma,
          tem_topo: false,               # sem topo — abertura para cooktop
          tem_rodape: true,
          altura_rodape: 100.0,
          tem_travessa: true,
          fundo_tipo: :encaixado,
          fundo_espessura: 6.0,
          prateleiras_padrao: 0,
          descricao: 'Balcao Cooktop'
        },
        micro_ondas: {
          base_passante: :nenhuma,
          topo_passante: :nenhuma,
          tem_rodape: false,
          altura_rodape: 0,
          tem_travessa: true,
          fundo_tipo: :parafusado,
          fundo_espessura: 6.0,
          prateleiras_padrao: 0,
          descricao: 'Nicho Micro-ondas'
        },
        lava_louca: {
          base_passante: :nenhuma,
          topo_passante: :nenhuma,
          tem_rodape: true,
          altura_rodape: 100.0,
          tem_travessa: true,
          fundo_tipo: :sem,             # sem fundo (acesso para instalacao)
          fundo_espessura: 0,
          prateleiras_padrao: 0,
          descricao: 'Balcao Lava-Louca'
        },
        canto_l: {
          base_passante: :nenhuma,
          topo_passante: :nenhuma,
          tem_rodape: true,
          altura_rodape: 100.0,
          tem_travessa: true,
          fundo_tipo: :encaixado,
          fundo_espessura: 6.0,
          prateleiras_padrao: 1,
          descricao: 'Canto L (Blind Corner)',
          # Geometria L: largura = ala frontal, largura_retorno = ala lateral
          # Profundidade = profundidade de ambas as alas
          # O modulo forma um L visto de cima
          canto_l_especial: true,
        },
        canto_l_superior: {
          base_passante: :ambas,
          topo_passante: :ambas,
          tem_rodape: false,
          altura_rodape: 0,
          tem_travessa: true,
          fundo_tipo: :parafusado,
          fundo_espessura: 6.0,
          prateleiras_padrao: 1,
          descricao: 'Canto L Superior (Aereo)',
          canto_l_especial: true,
        },
        ilha: {
          base_passante: :nenhuma,
          topo_passante: :nenhuma,
          tem_rodape: true,
          altura_rodape: 100.0,
          tem_travessa: true,
          fundo_tipo: :sem,             # ilha: sem fundo (acessivel dos 2 lados)
          fundo_espessura: 0,
          prateleiras_padrao: 1,
          descricao: 'Ilha de Cozinha',
        },

        # ── Modulos Banheiro ─────────────────────────────────

        espelheira: {
          base_passante: :inferior,
          topo_passante: :superior,
          tem_rodape: false,
          altura_rodape: 0,
          tem_travessa: false,
          fundo_tipo: :parafusado,
          fundo_espessura: 3.0,
          prateleiras_padrao: 2,
          tem_topo: true,
          descricao: 'Espelheira Banheiro'
        },
        pia_banheiro: {
          base_passante: :nenhuma,
          topo_passante: :nenhuma,
          tem_rodape: false,
          altura_rodape: 0,
          tem_travessa: true,
          fundo_tipo: :parafusado,
          fundo_espessura: 6.0,
          prateleiras_padrao: 0,
          tem_topo: true,
          descricao: 'Gabinete Banheiro'
        },
      }.freeze

      # ================================================================
      # Formulas parametricas (template)
      # ================================================================
      # Cada formula e uma string que sera avaliada no contexto do
      # Dynamic Component do SketchUp. Usa Parent! para referenciar
      # atributos do modulo pai.
      #
      # Variaveis disponiveis:
      #   Parent!orn_largura        — largura do modulo (cm, SketchUp)
      #   Parent!orn_profundidade   — profundidade
      #   Parent!orn_altura         — altura
      #   Parent!orn_espessura_corpo — espessura nominal (cm, ex: 1.8)
      #   Parent!orn_espessura_real  — espessura real (cm, ex: 1.85)
      #   Parent!orn_entrada_fundo   — recuo do fundo (cm)
      #   Parent!orn_espessura_fundo — espessura do fundo (cm)
      #   Parent!orn_borda_espessura — espessura da borda (cm)
      #   Parent!orn_tipo_fundo      — tipo do fundo
      #   Parent!orn_base_passante   — tipo de passagem da base
      # ================================================================

      FORMULAS = {
        # ── Lateral Esquerda (passante — altura total) ───────────
        lateral_esq: {
          lenx: 'Parent!orn_espessura_real',
          leny: 'Parent!orn_profundidade',
          lenz: 'Parent!orn_altura',
          x: '0',
          y: '0',
          z: '0',
          rotx: '0', roty: '0', rotz: '0',
          corte_comp: 'Parent!orn_altura*10',            # mm
          corte_larg: 'Parent!orn_profundidade*10',      # mm
        },

        # ── Lateral Direita (passante — altura total) ────────────
        lateral_dir: {
          lenx: 'Parent!orn_espessura_real',
          leny: 'Parent!orn_profundidade',
          lenz: 'Parent!orn_altura',
          x: 'Parent!orn_largura - Parent!orn_espessura_real',
          y: '0',
          z: '0',
          rotx: '0', roty: '0', rotz: '0',
          corte_comp: 'Parent!orn_altura*10',
          corte_larg: 'Parent!orn_profundidade*10',
        },

        # ── Lateral Esquerda (entre base/topo passantes) ─────────
        # Usada quando base E topo sao passantes (ex: :superior, :estante)
        # Lateral encurtada: nao cobre a espessura da base nem do topo.
        lateral_esq_entre: {
          lenx: 'Parent!orn_espessura_real',
          leny: 'Parent!orn_profundidade',
          lenz: 'Parent!orn_altura - 2*Parent!orn_espessura_real',
          x: '0',
          y: '0',
          z: 'Parent!orn_espessura_real',
          rotx: '0', roty: '0', rotz: '0',
          corte_comp: '(Parent!orn_altura - 2*Parent!orn_espessura_real)*10',
          corte_larg: 'Parent!orn_profundidade*10',
        },

        # ── Lateral Direita (entre base/topo passantes) ──────────
        lateral_dir_entre: {
          lenx: 'Parent!orn_espessura_real',
          leny: 'Parent!orn_profundidade',
          lenz: 'Parent!orn_altura - 2*Parent!orn_espessura_real',
          x: 'Parent!orn_largura - Parent!orn_espessura_real',
          y: '0',
          z: 'Parent!orn_espessura_real',
          rotx: '0', roty: '0', rotz: '0',
          corte_comp: '(Parent!orn_altura - 2*Parent!orn_espessura_real)*10',
          corte_larg: 'Parent!orn_profundidade*10',
        },

        # ── Base (entre laterais) ────────────────────────────────
        # Z = acima do rodape (orn_altura_rodape/10). Se nao tem rodape, Z=0.
        base_entre: {
          lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real',
          leny: 'Parent!orn_profundidade',
          lenz: 'Parent!orn_espessura_real',
          x: 'Parent!orn_espessura_real',
          y: '0',
          z: 'Parent!orn_altura_rodape/10',
          corte_comp: '(Parent!orn_largura - 2*Parent!orn_espessura_real)*10',
          corte_larg: 'Parent!orn_profundidade*10',
        },

        # ── Base Passante Inferior ───────────────────────────────
        base_passante_inf: {
          lenx: 'Parent!orn_largura',
          leny: 'Parent!orn_profundidade',
          lenz: 'Parent!orn_espessura_real',
          x: '0',
          y: '0',
          z: '0',
          corte_comp: 'Parent!orn_largura*10',
          corte_larg: 'Parent!orn_profundidade*10',
        },

        # ── Topo/Rega (entre laterais) ──────────────────────────
        topo_entre: {
          lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real',
          leny: 'Parent!orn_profundidade',
          lenz: 'Parent!orn_espessura_real',
          x: 'Parent!orn_espessura_real',
          y: '0',
          z: 'Parent!orn_altura - Parent!orn_espessura_real',
          corte_comp: '(Parent!orn_largura - 2*Parent!orn_espessura_real)*10',
          corte_larg: 'Parent!orn_profundidade*10',
        },

        # ── Topo Passante Superior ───────────────────────────────
        topo_passante_sup: {
          lenx: 'Parent!orn_largura',
          leny: 'Parent!orn_profundidade',
          lenz: 'Parent!orn_espessura_real',
          x: '0',
          y: '0',
          z: 'Parent!orn_altura - Parent!orn_espessura_real',
          corte_comp: 'Parent!orn_largura*10',
          corte_larg: 'Parent!orn_profundidade*10',
        },

        # ── Fundo Encaixado ──────────────────────────────────────
        # Vai em rasgo nas laterais, a 7mm da traseira.
        # Para modulos com rodape: base esta elevada, entao o fundo
        # comeca acima da zona de rodape + espessura_base.
        # Altura do fundo = altura - rodape - 2*esp_corpo + 2*folga_canal
        fundo_encaixado: {
          lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real + 2*Parent!orn_folga_canal/10',
          leny: 'Parent!orn_espessura_fundo_real',
          lenz: 'Parent!orn_altura - Parent!orn_altura_rodape/10 - 2*Parent!orn_espessura_real + 2*Parent!orn_folga_canal/10',
          x: 'Parent!orn_espessura_real - Parent!orn_folga_canal/10',
          y: 'Parent!orn_entrada_fundo/10',
          z: 'Parent!orn_altura_rodape/10 + Parent!orn_espessura_real - Parent!orn_folga_canal/10',
          corte_comp: '(Parent!orn_largura - 2*Parent!orn_espessura_real + 2*Parent!orn_folga_canal/10)*10',
          corte_larg: '(Parent!orn_altura - Parent!orn_altura_rodape/10 - 2*Parent!orn_espessura_real + 2*Parent!orn_folga_canal/10)*10',
        },

        # ── Fundo Encaixado (para modulos com base/topo passantes) ─
        # Quando laterais sao "entre" (base e topo passantes), o fundo
        # se encaixa no vao entre base e topo passantes.
        # Altura = altura - 2*esp (mesma que lateral entre) + 2*folga_canal
        # Largura = entre laterais + 2*folga_canal (entra no rasgo)
        fundo_encaixado_passante: {
          lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real + 2*Parent!orn_folga_canal/10',
          leny: 'Parent!orn_espessura_fundo_real',
          lenz: 'Parent!orn_altura - 2*Parent!orn_espessura_real + 2*Parent!orn_folga_canal/10',
          x: 'Parent!orn_espessura_real - Parent!orn_folga_canal/10',
          y: 'Parent!orn_entrada_fundo/10',
          z: 'Parent!orn_espessura_real - Parent!orn_folga_canal/10',
          corte_comp: '(Parent!orn_largura - 2*Parent!orn_espessura_real + 2*Parent!orn_folga_canal/10)*10',
          corte_larg: '(Parent!orn_altura - 2*Parent!orn_espessura_real + 2*Parent!orn_folga_canal/10)*10',
        },

        # ── Fundo Parafusado ─────────────────────────────────────
        # Pregado/parafusado na traseira, sobre as laterais
        fundo_parafusado: {
          lenx: 'Parent!orn_largura',
          leny: 'Parent!orn_espessura_fundo_real',
          lenz: 'Parent!orn_altura',
          x: '0',
          y: '0',
          z: '0',
          corte_comp: 'Parent!orn_largura*10',
          corte_larg: 'Parent!orn_altura*10',
        },

        # ── Travessa Frontal ─────────────────────────────────────
        travessa: {
          lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real',
          leny: 'Parent!orn_espessura_real',
          lenz: 'Parent!orn_espessura_real',  # altura da travessa = espessura corpo
          x: 'Parent!orn_espessura_real',
          y: 'Parent!orn_profundidade - Parent!orn_espessura_real',
          z: 'Parent!orn_altura - Parent!orn_espessura_real',
          corte_comp: '(Parent!orn_largura - 2*Parent!orn_espessura_real)*10',
          corte_larg: 'Parent!orn_espessura_real*10',
        },

        # ── Rodape ───────────────────────────────────────────────
        # Recuo usa orn_recuo_rodape (mm) para toe-kick configuravel
        rodape: {
          lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real',
          leny: 'Parent!orn_espessura_real',
          lenz: 'Parent!orn_altura_rodape/10',
          x: 'Parent!orn_espessura_real',
          y: 'Parent!orn_profundidade - Parent!orn_recuo_rodape/10',
          z: '0',
          corte_comp: '(Parent!orn_largura - 2*Parent!orn_espessura_real)*10',
          corte_larg: 'Parent!orn_altura_rodape',
        },

        # ── Prateleira ───────────────────────────────────────────
        prateleira: {
          lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real',
          leny: 'Parent!orn_profundidade - Parent!orn_recuo_prateleira/10',
          lenz: 'Parent!orn_espessura_real',
          # Posicao Z calculada pela formula de espacamento
          corte_comp: '(Parent!orn_largura - 2*Parent!orn_espessura_real)*10',
          corte_larg: '(Parent!orn_profundidade - Parent!orn_recuo_prateleira/10)*10',
        },
        # ── Canto L: Lateral Retorno (parede extra do L) ──────────
        # Fica perpendicular a lateral esquerda, formando o retorno do L.
        # Posicao: na borda esquerda, ao longo de Y (profundidade do retorno)
        canto_l_lateral_retorno: {
          lenx: 'Parent!orn_largura_retorno - Parent!orn_espessura_real',
          leny: 'Parent!orn_espessura_real',
          lenz: 'Parent!orn_altura',
          x: 'Parent!orn_espessura_real',
          y: 'Parent!orn_profundidade - Parent!orn_espessura_real',
          z: '0',
          corte_comp: 'Parent!orn_altura*10',
          corte_larg: '(Parent!orn_largura_retorno - Parent!orn_espessura_real)*10',
        },

        # ── Canto L: Base frontal (entre laterais da ala frontal) ────
        canto_l_base_frontal: {
          lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real',
          leny: 'Parent!orn_profundidade',
          lenz: 'Parent!orn_espessura_real',
          x: 'Parent!orn_espessura_real',
          y: '0',
          z: 'Parent!orn_altura_rodape/10',
          corte_comp: '(Parent!orn_largura - 2*Parent!orn_espessura_real)*10',
          corte_larg: 'Parent!orn_profundidade*10',
        },

        # ── Canto L: Base retorno (entre lateral esq e lateral retorno) ─
        canto_l_base_retorno: {
          lenx: 'Parent!orn_largura_retorno - Parent!orn_espessura_real',
          leny: 'Parent!orn_profundidade - Parent!orn_espessura_real',
          lenz: 'Parent!orn_espessura_real',
          x: 'Parent!orn_espessura_real',
          y: 'Parent!orn_espessura_real',
          z: 'Parent!orn_altura_rodape/10',
          corte_comp: '(Parent!orn_largura_retorno - Parent!orn_espessura_real)*10',
          corte_larg: '(Parent!orn_profundidade - Parent!orn_espessura_real)*10',
        },

        # ── Canto L: Topo frontal ────────────────────────────────
        canto_l_topo_frontal: {
          lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real',
          leny: 'Parent!orn_profundidade',
          lenz: 'Parent!orn_espessura_real',
          x: 'Parent!orn_espessura_real',
          y: '0',
          z: 'Parent!orn_altura - Parent!orn_espessura_real',
          corte_comp: '(Parent!orn_largura - 2*Parent!orn_espessura_real)*10',
          corte_larg: 'Parent!orn_profundidade*10',
        },

        # ── Canto L: Topo retorno ────────────────────────────────
        canto_l_topo_retorno: {
          lenx: 'Parent!orn_largura_retorno - Parent!orn_espessura_real',
          leny: 'Parent!orn_profundidade - Parent!orn_espessura_real',
          lenz: 'Parent!orn_espessura_real',
          x: 'Parent!orn_espessura_real',
          y: 'Parent!orn_espessura_real',
          z: 'Parent!orn_altura - Parent!orn_espessura_real',
          corte_comp: '(Parent!orn_largura_retorno - Parent!orn_espessura_real)*10',
          corte_larg: '(Parent!orn_profundidade - Parent!orn_espessura_real)*10',
        },
      }.freeze

      # ================================================================
      # Interface publica
      # ================================================================

      # Cria um modulo completo no modelo SketchUp ativo.
      #
      # @param tipo [Symbol] tipo do modulo (ver CONFIGS)
      # @param largura [Float] largura em cm
      # @param profundidade [Float] profundidade em cm
      # @param altura [Float] altura em cm
      # @param material [String] material do corpo
      # @param espessura [Float] espessura nominal em mm
      # @param nome [String, nil] nome do modulo
      # @param posicao [Geom::Point3d, nil] posicao no modelo
      # @return [Sketchup::ComponentInstance] instancia do modulo criado
      def self.criar(tipo, largura:, profundidade:, altura:,
                     material: 'MDF 18mm Branco TX', espessura: 18.0,
                     nome: nil, posicao: nil, largura_retorno: nil)
        config = CONFIGS[tipo]
        raise "Tipo de modulo desconhecido: #{tipo}" unless config

        # Validacao de dimensoes minimas
        esp_real_cm = Core::Config.real_thickness(espessura) / 10.0
        esp_min_cm = esp_real_cm * 2 + 1.0
        if largura < esp_min_cm
          raise "Largura #{largura}cm muito pequena para espessura #{espessura}mm " \
                "(minimo: #{esp_min_cm.round(1)}cm)"
        end
        if profundidade < esp_min_cm
          raise "Profundidade #{profundidade}cm muito pequena para espessura #{espessura}mm " \
                "(minimo: #{esp_min_cm.round(1)}cm)"
        end
        # Altura: bancada/nicho podem ser baixos (apenas espessura do tampo)
        alt_min = (tipo == :bancada || tipo == :nicho) ? esp_real_cm + 0.5 : esp_min_cm
        if altura < alt_min
          raise "Altura #{altura}cm muito pequena para espessura #{espessura}mm " \
                "(minimo: #{alt_min.round(1)}cm)"
        end

        # Validacao de dimensoes maximas (chapa MDF padrao: 2750x1850mm)
        max_comp_mm = 2750.0  # comprimento maximo da chapa
        max_larg_mm = 1850.0  # largura maxima da chapa
        [
          ['Lateral (altura)', altura * 10.0, profundidade * 10.0],
          ['Base/Topo (largura)', largura * 10.0, profundidade * 10.0],
        ].each do |peca_nome, dim_comp, dim_larg|
          if dim_comp > max_comp_mm || dim_larg > max_larg_mm
            puts "[Ornato::BoxBuilder] AVISO: #{peca_nome} excede chapa padrao " \
                 "(#{dim_comp.round}x#{dim_larg.round}mm > #{max_comp_mm.to_i}x#{max_larg_mm.to_i}mm)"
          end
        end

        model = Sketchup.active_model
        model.start_operation("Criar #{config[:descricao]}", true)

        begin
          # 1. Criar ComponentDefinition para o modulo
          nome_def = nome || "#{config[:descricao]} #{largura.round}x#{profundidade.round}x#{altura.round}"
          definition = model.definitions.add(nome_def)

          # 2. Configurar atributos do modulo (Dynamic Component)
          esp_real = Core::Config.real_thickness(espessura) / 10.0 # mm -> cm
          esp_cm = espessura / 10.0

          # Formula DC para recalcular espessura_real automaticamente
          # quando o usuario troca orn_espessura_corpo no Component Options.
          # Valores em cm (DC interno). Mapeamento: nominal_cm → real_cm
          #   0.6cm (6mm) → 0.6cm
          #   1.5cm (15mm) → 1.55cm (15.5mm real)
          #   1.8cm (18mm) → 1.85cm (18.5mm real)
          #   2.5cm (25mm) → 2.55cm (25.5mm real)
          #   3.0cm (30mm) → 3.1cm  (31.0mm real)
          #   3.6cm (36mm) → 3.7cm  (37.0mm real)
          formula_esp_real = 'IF(orn_espessura_corpo=0.6,0.6,' \
                             'IF(orn_espessura_corpo=1.5,1.55,' \
                             'IF(orn_espessura_corpo=1.8,1.85,' \
                             'IF(orn_espessura_corpo=2.5,2.55,' \
                             'IF(orn_espessura_corpo=3.0,3.1,' \
                             'IF(orn_espessura_corpo=3.6,3.7,' \
                             'orn_espessura_corpo))))))'

          # Formula DC para espessura_fundo_real
          # 6mm → 0.6cm, 15mm → 1.55cm (15.5mm real)
          formula_esp_fundo_real = 'IF(orn_espessura_fundo=6,0.6,' \
                                   'IF(orn_espessura_fundo=15,1.55,0.6))'

          configurar_modulo_dc(definition, {
            orn_marcado: true,
            orn_versao: '1.0',
            orn_id: Core::Ids.generate,
            orn_nome: nome_def,
            orn_tipo_modulo: tipo.to_s,
            orn_largura: largura,
            orn_profundidade: profundidade,
            orn_altura: altura,
            orn_material_corpo: material,
            orn_espessura_corpo: esp_cm,
            orn_espessura_real: esp_real,
            orn_tipo_fundo: config[:fundo_tipo].to_s,
            orn_espessura_fundo: config[:fundo_espessura],
            orn_entrada_fundo: 7.0,  # 7mm padrao
            orn_folga_canal: 9.0,    # mm — quanto o fundo entra no rasgo (profundidade_rasgo - folga_real)
            orn_qtd_prateleiras: config[:prateleiras_padrao],
            orn_recuo_prateleira: 0.0,
            orn_altura_rodape: config[:altura_rodape],
            orn_recuo_rodape: config[:tem_rodape] ? 40.0 : 0.0,  # mm — recuo toe-kick do rodape
            orn_folga_porta: 2.0,        # folga entre portas (mm) — usado nas PORTA_FORMULAS
            orn_espessura_porta: 18.0,   # espessura das portas (mm) — usado nas PORTA_FORMULAS
            orn_sobreposicao_porta: 0.0, # sobreposicao em mm — setado por AggregateBuilder conforme tipo_dobradica
            orn_tipo_dobradica: 'reta',  # reta/curva/supercurva — define braco e sobreposicao
            orn_tipo_corredica: 'telescopica',  # padrao — HardwareSwapper altera quando usuario troca
            orn_tipo_fixacao: 'minifix',        # padrao — HardwareSwapper altera
            orn_tipo_suporte_prat: 'pino_5mm',  # padrao — HardwareSwapper altera
            orn_exportar: true,
          })

          # Canto L: atributo extra para dimensao do retorno
          if config[:canto_l_especial]
            lr = largura_retorno || (profundidade * 0.6).round(1)
            min_lr = esp_real * 2 + 1.0
            if lr < min_lr
              raise "Largura Retorno #{lr}cm muito pequena (minimo: #{min_lr.round(1)}cm)"
            end
            if lr > profundidade
              raise "Largura Retorno #{lr}cm nao pode exceder profundidade (#{profundidade}cm)"
            end
            definition.set_attribute('dynamic_attributes', 'orn_largura_retorno', lr)
            definition.set_attribute('ornato', 'orn_largura_retorno', lr)
            definition.set_attribute('dynamic_attributes', 'orn_largura_retorno_label', 'Largura Retorno')
            definition.set_attribute('dynamic_attributes', 'orn_largura_retorno_access', 'TEXTBOX')
            definition.set_attribute('dynamic_attributes', 'orn_largura_retorno_units', 'CENTIMETERS')
          end

          # 2b. Aplicar formulas DC para recalculo automatico
          # Quando o usuario troca orn_espessura_corpo no Component Options,
          # orn_espessura_real recalcula automaticamente via formula DC
          dc = 'dynamic_attributes'
          definition.set_attribute(dc, 'orn_espessura_real_formula', formula_esp_real)
          definition.set_attribute(dc, 'orn_espessura_real_units', 'CENTIMETERS')

          # Formula para espessura do fundo (recalcula quando troca tipo/espessura)
          definition.set_attribute(dc, 'orn_espessura_fundo_real_formula', formula_esp_fundo_real)
          definition.set_attribute(dc, 'orn_espessura_fundo_real', config[:fundo_espessura] == 15 ? 1.55 : 0.6)

          # 3. Criar pecas estruturais
          if config[:canto_l_especial]
            criar_canto_l_pecas(definition, config, esp_real)
          else
            criar_laterais(definition, config, esp_real)
            criar_base(definition, config, esp_real, largura)
            criar_topo(definition, config, esp_real, largura, altura) unless config[:tem_topo] == false
            criar_fundo(definition, config)
            criar_travessa(definition, config) if config[:tem_travessa]
            criar_rodape(definition, config) if config[:tem_rodape]
            criar_prateleiras(definition, config)
          end

          # 4. Embutir ferragens estruturais (minifix nas juntas)
          embutir_ferragens_estruturais(definition, config)

          # 5. Inserir no modelo
          ponto = posicao || Geom::Point3d.new(0, 0, 0)
          transform = Geom::Transformation.new(ponto)
          instance = model.active_entities.add_instance(definition, transform)

          # 6. Forcar recalculo do Dynamic Component
          instance.set_attribute('dynamic_attributes', '_has_behaviors', true)
          $dc_observers&.get_latest_class&.redraw_with_undo(instance) if defined?($dc_observers) && $dc_observers

          model.commit_operation

          # 7. Validacao automatica pos-criacao (feedback na status bar)
          begin
            if defined?(CapacityValidator)
              alertas = CapacityValidator.validar(instance)
              qtd_pecas = definition.entities.count { |e|
                e.is_a?(Sketchup::ComponentInstance) &&
                e.definition.get_attribute('dynamic_attributes', 'orn_marcado') == true
              }
              erros = alertas.count { |a| a[:nivel] == :erro }
              avisos = alertas.count { |a| a[:nivel] == :aviso }

              status = "ORNATO: #{nome_def} criado — #{qtd_pecas} pecas"
              status += " | #{erros} erros" if erros > 0
              status += " | #{avisos} avisos" if avisos > 0
              status += " | OK" if erros == 0 && avisos == 0
              Sketchup.status_text = status
            end
          rescue
            # Validacao opcional — nao bloquear criacao
          end

          instance

        rescue => e
          model.abort_operation
          raise e
        end
      end

      private

      # ================================================================
      # Configuracao de Dynamic Component
      # ================================================================

      def self.configurar_modulo_dc(definition, attrs)
        dc_dict = 'dynamic_attributes'
        ornato_dict = OrnatoAttributes::DICT_NAME  # 'ornato'

        attrs.each do |key, value|
          attr_name = key.to_s

          # Valor no dicionario DC (para formulas parametricas Parent!)
          definition.set_attribute(dc_dict, attr_name, value)

          # Espelhar no dicionario Ornato (para deteccao via OrnatoAttributes)
          definition.set_attribute(ornato_dict, attr_name, value)

          # Metadata para Component Options (apenas no DC dict)
          spec = OrnatoAttributes::MODULE_ATTRS[key]
          if spec
            definition.set_attribute(dc_dict, "#{attr_name}_label", spec[:label]) if spec[:label]
            definition.set_attribute(dc_dict, "#{attr_name}_access", spec[:access]) if spec[:access]
            definition.set_attribute(dc_dict, "#{attr_name}_formlabel", spec[:formlabel]) if spec[:formlabel]
            definition.set_attribute(dc_dict, "#{attr_name}_options", spec[:options]) if spec[:options]
            definition.set_attribute(dc_dict, "#{attr_name}_units", spec[:units]) if spec[:units]
          end
        end

        # Flags obrigatorias para DC
        definition.set_attribute(dc_dict, '_has_behaviors', true)
        definition.set_attribute(dc_dict, '_formatversion', 1.4)
      end

      def self.configurar_peca_dc(definition, attrs, formulas = {})
        dc_dict = 'dynamic_attributes'
        ornato_dict = OrnatoAttributes::DICT_NAME  # 'ornato'

        attrs.each do |key, value|
          attr_name = key.to_s

          # Valor no dicionario DC (para formulas Parent!)
          definition.set_attribute(dc_dict, attr_name, value)

          # Espelhar no dicionario Ornato (para deteccao via OrnatoAttributes)
          definition.set_attribute(ornato_dict, attr_name, value)

          spec = OrnatoAttributes::PART_ATTRS[key]
          if spec
            definition.set_attribute(dc_dict, "#{attr_name}_label", spec[:label]) if spec[:label]
            definition.set_attribute(dc_dict, "#{attr_name}_access", spec[:access]) if spec[:access]
            definition.set_attribute(dc_dict, "#{attr_name}_options", spec[:options]) if spec[:options]
          end
        end

        # Aplicar formulas parametricas (referenciando Parent!)
        formulas.each do |key, formula|
          case key
          when :lenx
            definition.set_attribute(dc_dict, '_lenx_formula', formula)
            definition.set_attribute(dc_dict, '_lenx_units', 'CENTIMETERS')
          when :leny
            definition.set_attribute(dc_dict, '_leny_formula', formula)
            definition.set_attribute(dc_dict, '_leny_units', 'CENTIMETERS')
          when :lenz
            definition.set_attribute(dc_dict, '_lenz_formula', formula)
            definition.set_attribute(dc_dict, '_lenz_units', 'CENTIMETERS')
          when :x
            definition.set_attribute(dc_dict, '_inst__x_formula', formula)
          when :y
            definition.set_attribute(dc_dict, '_inst__y_formula', formula)
          when :z
            definition.set_attribute(dc_dict, '_inst__z_formula', formula)
          when :rotx
            definition.set_attribute(dc_dict, '_inst__rotx_formula', formula)
          when :roty
            definition.set_attribute(dc_dict, '_inst__roty_formula', formula)
          when :rotz
            definition.set_attribute(dc_dict, '_inst__rotz_formula', formula)
          when :corte_comp
            definition.set_attribute(dc_dict, 'orn_corte_comp_formula', formula)
          when :corte_larg
            definition.set_attribute(dc_dict, 'orn_corte_larg_formula', formula)
          end
        end

        definition.set_attribute(dc_dict, '_has_behaviors', true)
      end

      # ================================================================
      # Criacao de pecas
      # ================================================================

      def self.criar_laterais(parent_def, config, esp_real)
        # Determinar se laterais ficam entre base/topo passantes
        # Se ambos (base e topo) sao passantes, a lateral e encurtada
        base_pass = config[:base_passante] != :nenhuma
        topo_pass = config[:topo_passante] != :nenhuma
        laterais_entre = base_pass && topo_pass

        formula_esq = laterais_entre ? FORMULAS[:lateral_esq_entre] : FORMULAS[:lateral_esq]
        formula_dir = laterais_entre ? FORMULAS[:lateral_dir_entre] : FORMULAS[:lateral_dir]

        # Geometria placeholder: altura depende de se e entre ou passante
        alt_tipo = laterais_entre ? :altura_interna : :altura

        # Lateral Esquerda
        lat_esq_def = criar_peca_geometria(parent_def, 'Lateral Esq',
          esp_real, :profundidade, alt_tipo)
        configurar_peca_dc(lat_esq_def, {
          orn_marcado: true,
          orn_tipo_peca: 'lateral',
          orn_subtipo: 'esquerda',
          orn_codigo: 'LAT_ESQ',
          orn_nome: 'Lateral Esquerda',
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
          orn_face_visivel: 'face_a',
        }, formula_esq)

        # Lateral Direita
        lat_dir_def = criar_peca_geometria(parent_def, 'Lateral Dir',
          esp_real, :profundidade, alt_tipo)
        configurar_peca_dc(lat_dir_def, {
          orn_marcado: true,
          orn_tipo_peca: 'lateral',
          orn_subtipo: 'direita',
          orn_codigo: 'LAT_DIR',
          orn_nome: 'Lateral Direita',
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
          orn_face_visivel: 'face_a',
        }, formula_dir)
      end

      def self.criar_base(parent_def, config, esp_real, largura)
        case config[:base_passante]
        when :inferior, :ambas
          formulas = FORMULAS[:base_passante_inf]
          nome = 'Base Passante'
        else
          formulas = FORMULAS[:base_entre]
          nome = 'Base'
        end

        base_def = criar_peca_geometria(parent_def, nome,
          esp_real, :largura_interna, :profundidade)
        configurar_peca_dc(base_def, {
          orn_marcado: true,
          orn_tipo_peca: 'base',
          orn_codigo: 'BASE',
          orn_nome: nome,
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
          orn_face_visivel: 'face_a',
        }, formulas)
      end

      def self.criar_topo(parent_def, config, esp_real, largura, altura)
        return if config[:tem_topo] == false  # cooktop, etc

        case config[:topo_passante]
        when :superior, :ambas
          formulas = FORMULAS[:topo_passante_sup]
          nome = 'Topo Passante'
        else
          formulas = FORMULAS[:topo_entre]
          nome = 'Topo / Rega'
        end

        topo_def = criar_peca_geometria(parent_def, nome,
          esp_real, :largura_interna, :profundidade)
        configurar_peca_dc(topo_def, {
          orn_marcado: true,
          orn_tipo_peca: 'topo',
          orn_codigo: 'TOPO',
          orn_nome: nome,
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
          orn_face_visivel: 'face_a',
        }, formulas)
      end

      def self.criar_fundo(parent_def, config)
        case config[:fundo_tipo]
        when :encaixado
          # Selecionar formula correta: se base e topo sao passantes,
          # o fundo encaixa no vao entre eles (mesma logica das laterais)
          base_pass = config[:base_passante] != :nenhuma
          topo_pass = config[:topo_passante] != :nenhuma
          if base_pass && topo_pass
            formulas = FORMULAS[:fundo_encaixado_passante]
          else
            formulas = FORMULAS[:fundo_encaixado]
          end
          nome = 'Fundo Encaixado'
        when :parafusado
          formulas = FORMULAS[:fundo_parafusado]
          nome = 'Fundo Parafusado'
        else
          return # sem fundo
        end

        fundo_def = criar_peca_geometria(parent_def, nome,
          0.6, :largura_interna, :altura_interna) # 6mm espessura (HDF)
        configurar_peca_dc(fundo_def, {
          orn_marcado: true,
          orn_tipo_peca: 'fundo',
          orn_codigo: 'FUNDO',
          orn_nome: nome,
          orn_na_lista_corte: true,
          orn_grao: 'sem',
          orn_borda_frontal: false,
          orn_borda_traseira: false,
          orn_borda_esquerda: false,
          orn_borda_direita: false,
          orn_face_visivel: 'face_b',
        }, formulas)
      end

      def self.criar_travessa(parent_def, config)
        trav_def = criar_peca_geometria(parent_def, 'Travessa',
          1.85, :largura_interna, 1.85) # espessura x largura_interna x espessura
        configurar_peca_dc(trav_def, {
          orn_marcado: true,
          orn_tipo_peca: 'travessa',
          orn_codigo: 'TRAV',
          orn_nome: 'Travessa',
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
          orn_face_visivel: 'face_a',
        }, FORMULAS[:travessa])
      end

      def self.criar_rodape(parent_def, config)
        rod_def = criar_peca_geometria(parent_def, 'Rodape',
          1.85, :largura_interna, 10.0) # 100mm de altura
        configurar_peca_dc(rod_def, {
          orn_marcado: true,
          orn_tipo_peca: 'rodape',
          orn_codigo: 'RODAPE',
          orn_nome: 'Rodape',
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
          orn_face_visivel: 'face_a',
        }, FORMULAS[:rodape])
      end

      def self.criar_prateleiras(parent_def, config)
        qty = config[:prateleiras_padrao]
        return if qty <= 0

        qty.times do |i|
          prat_def = criar_peca_geometria(parent_def, "Prateleira #{i+1}",
            1.85, :largura_interna, :profundidade)

          # Calcular posicao Z da prateleira (espacamento uniforme)
          # Formula: base_z + (espaco_util / (qty+1)) * (i+1)
          z_formula = "Parent!orn_espessura_real + " \
                      "((Parent!orn_altura - 2*Parent!orn_espessura_real) / #{qty + 1}) * #{i + 1}"

          formulas = FORMULAS[:prateleira].merge({
            x: 'Parent!orn_espessura_real',
            y: '0',
            z: z_formula
          })

          configurar_peca_dc(prat_def, {
            orn_marcado: true,
            orn_tipo_peca: 'prateleira',
            orn_subtipo: 'fixa',
            orn_codigo: "PRAT_#{i+1}",
            orn_nome: "Prateleira #{i+1}",
            orn_na_lista_corte: true,
            orn_grao: 'comprimento',
            orn_borda_frontal: true,
            orn_face_visivel: 'face_a',
          }, formulas)
        end
      end

      # ================================================================
      # Embutir ferragens estruturais
      # ================================================================
      # Insere minifix/cavilha nas juntas lateral-base e lateral-topo
      # como sub-componentes .skp (igual ao WPS).

      def self.embutir_ferragens_estruturais(definition, config)
        # Minifix na junta lateral-base (esquerda e direita)
        HardwareEmbedder.embutir_minifix(definition, junta: :base, lado: :esquerda)
        HardwareEmbedder.embutir_minifix(definition, junta: :base, lado: :direita)

        # Minifix na junta lateral-topo (esquerda e direita)
        HardwareEmbedder.embutir_minifix(definition, junta: :topo, lado: :esquerda)
        HardwareEmbedder.embutir_minifix(definition, junta: :topo, lado: :direita)
      rescue => e
        # Ferragens sao opcionais — se falhar, o modulo continua funcional
        puts "[Ornato::BoxBuilder] AVISO: Nao foi possivel embutir ferragens: #{e.message}"
      end

      # ================================================================
      # Canto L — pecas especializadas (blind corner)
      # ================================================================
      # Vista superior do canto L (laterais passantes, base entre):
      #
      #    ┌─────────────────────┐
      #    │   Ala Frontal       │ ← lateral_dir
      #    │   (largura)         │
      #    ├─────┬───────────────┘
      #    │     │ ← lateral_retorno (perpendicular)
      #    │ Ala │
      #    │ Ret │
      #    └─────┘
      #    ↑ lateral_esq (passante L inteiro)
      #
      def self.criar_canto_l_pecas(parent_def, config, esp_real)
        # Lateral Esquerda: cobre toda a profundidade do L (altura total)
        lat_esq_def = criar_peca_geometria(parent_def, 'Lateral Esq',
          esp_real, :profundidade, :altura)
        configurar_peca_dc(lat_esq_def, {
          orn_marcado: true,
          orn_tipo_peca: 'lateral',
          orn_subtipo: 'esquerda',
          orn_codigo: 'LAT_ESQ',
          orn_nome: 'Lateral Esquerda (L)',
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
          orn_face_visivel: 'face_a',
        }, FORMULAS[:lateral_esq])

        # Lateral Direita: cobre a ala frontal (profundidade padrao)
        lat_dir_def = criar_peca_geometria(parent_def, 'Lateral Dir',
          esp_real, :profundidade, :altura)
        configurar_peca_dc(lat_dir_def, {
          orn_marcado: true,
          orn_tipo_peca: 'lateral',
          orn_subtipo: 'direita',
          orn_codigo: 'LAT_DIR',
          orn_nome: 'Lateral Direita',
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
          orn_face_visivel: 'face_a',
        }, FORMULAS[:lateral_dir])

        # Lateral Retorno: parede perpendicular formando o L
        lat_ret_def = criar_peca_geometria(parent_def, 'Lateral Retorno',
          esp_real, 30, :altura)
        configurar_peca_dc(lat_ret_def, {
          orn_marcado: true,
          orn_tipo_peca: 'lateral',
          orn_subtipo: 'retorno',
          orn_codigo: 'LAT_RET',
          orn_nome: 'Lateral Retorno (L)',
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
          orn_face_visivel: 'face_a',
        }, FORMULAS[:canto_l_lateral_retorno])

        # Base frontal: entre laterais esq e dir
        base_f_def = criar_peca_geometria(parent_def, 'Base Frontal',
          esp_real, :largura_interna, :profundidade)
        configurar_peca_dc(base_f_def, {
          orn_marcado: true,
          orn_tipo_peca: 'base',
          orn_subtipo: 'frontal',
          orn_codigo: 'BASE_F',
          orn_nome: 'Base Frontal (L)',
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
        }, FORMULAS[:canto_l_base_frontal])

        # Base retorno: entre lateral esq e lateral retorno
        base_r_def = criar_peca_geometria(parent_def, 'Base Retorno',
          esp_real, 30, :profundidade)
        configurar_peca_dc(base_r_def, {
          orn_marcado: true,
          orn_tipo_peca: 'base',
          orn_subtipo: 'retorno',
          orn_codigo: 'BASE_R',
          orn_nome: 'Base Retorno (L)',
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
        }, FORMULAS[:canto_l_base_retorno])

        # Topo frontal: entre laterais esq e dir
        topo_f_def = criar_peca_geometria(parent_def, 'Topo Frontal',
          esp_real, :largura_interna, :profundidade)
        configurar_peca_dc(topo_f_def, {
          orn_marcado: true,
          orn_tipo_peca: 'topo',
          orn_subtipo: 'frontal',
          orn_codigo: 'TOPO_F',
          orn_nome: 'Topo Frontal (L)',
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
        }, FORMULAS[:canto_l_topo_frontal])

        # Topo retorno
        topo_r_def = criar_peca_geometria(parent_def, 'Topo Retorno',
          esp_real, 30, :profundidade)
        configurar_peca_dc(topo_r_def, {
          orn_marcado: true,
          orn_tipo_peca: 'topo',
          orn_subtipo: 'retorno',
          orn_codigo: 'TOPO_R',
          orn_nome: 'Topo Retorno (L)',
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
        }, FORMULAS[:canto_l_topo_retorno])

        # Fundo: encaixado na ala frontal (o retorno fica aberto para acesso)
        criar_fundo(parent_def, config)

        # Travessa frontal
        criar_travessa(parent_def, config) if config[:tem_travessa]

        # Rodape frontal + rodape retorno
        criar_rodape(parent_def, config) if config[:tem_rodape]

        # Prateleira na ala frontal (padrao)
        criar_prateleiras(parent_def, config)
      end

      # Cria geometria basica de uma peca (caixa retangular) dentro do parent.
      # As dimensoes iniciais sao provisorias — o DC vai recalcular via formulas.
      #
      # @param parent_def [Sketchup::ComponentDefinition]
      # @param nome [String]
      # @param espessura_cm [Float]
      # @param largura_tipo [Symbol, Float]
      # @param altura_tipo [Symbol, Float]
      # @return [Sketchup::ComponentDefinition]
      def self.criar_peca_geometria(parent_def, nome, espessura_cm, largura_tipo, altura_tipo)
        model = Sketchup.active_model

        # Dimensoes iniciais placeholder (o DC vai sobrescrever via formulas)
        # Usar valores mais realistas baseados no tipo para evitar geometria
        # absurda antes do primeiro recalculo DC
        w = espessura_cm.cm    # X = espessura

        d = case largura_tipo
            when :profundidade then 55.cm
            when :largura_interna then 56.3.cm  # ~60 - 2*1.85
            when :altura_interna then 68.3.cm   # ~72 - 2*1.85
            when Numeric then largura_tipo.cm
            else 55.cm
            end

        h = case altura_tipo
            when :altura then 72.cm
            when :profundidade then 55.cm
            when :largura_interna then 56.3.cm
            when :altura_interna then 68.3.cm
            when Numeric then altura_tipo.cm
            else 72.cm
            end

        # Criar definition
        peca_def = model.definitions.add(nome)

        # Criar geometria (face + pushpull)
        pts = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(w, 0, 0),
          Geom::Point3d.new(w, d, 0),
          Geom::Point3d.new(0, d, 0)
        ]
        face = peca_def.entities.add_face(pts)
        face.pushpull(h) if face

        # Inserir como componente filho no parent
        transform = Geom::Transformation.new(ORIGIN)
        parent_def.entities.add_instance(peca_def, transform)

        peca_def
      end
    end
  end
end
