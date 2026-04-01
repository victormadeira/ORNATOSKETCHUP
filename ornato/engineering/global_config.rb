# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/global_config.rb — Configuracao Global de Usinagens e Ferragens
#
# Ponto UNICO de configuracao para TODOS os parametros de usinagem,
# ferragens, furacoes e posicionamentos do sistema.
#
# ARQUITETURA:
#   1. PERFIS DE MARCA (readonly) — specs do fabricante, nao editaveis
#   2. CONFIG GLOBAL (editavel) — preferencias da fabrica/projeto
#   3. OVERRIDE POR MODULO — excecoes pontuais via atributo DC
#
# CASCATA DE LEITURA:
#   modulo.orn_calco  →  se nil  →  GlobalConfig.valor(:dobradica, :calco)
#
# PERSISTENCIA:
#   Salva no dicionario 'ornato_config' do modelo SketchUp.
#
# USO:
#   GC = Ornato::Engineering::GlobalConfig
#   GC.dobradica                                # hash completo
#   GC.valor(:minifix, :diametro_bucha)         # 15.0
#   GC.set(:dobradica, :calco, 4.0)             # altera e salva
#   GC.aplicar_perfil_dobradica(:hettich)       # troca marca
#   GC.quantidade_dobradicas(1200)              # 4
#   GC.calcular_quantidade(:uniblock, 1200)     # 3  (auto por comprimento)
#   GC.calcular_posicoes(:uniblock, 1200)       # [50.0, 600.0, 1150.0]

module Ornato
  module Engineering
    module GlobalConfig

      CONFIG_DICT = 'ornato_config'.freeze

      # ================================================================
      #  SECAO 1 — PERFIS DE MARCA (specs do fabricante, readonly)
      # ================================================================

      # ── 1.1 Dobradicas ────────────────────────────────────────────
      PERFIS_DOBRADICA = {
        blum: {
          nome: 'Blum Clip Top / Blumotion',
          diametro_copa: 35.0,          # mm
          profundidade_copa: 13.0,      # mm
          calco: 3.0,                   # mm — borda porta ate borda furo
          centro_copa: 20.5,            # mm — diametro/2 + calco
          diametro_base: 5.0,           # mm — furos fixacao base
          profundidade_base: 12.0,      # mm
          distancia_base: 48.0,         # mm — entre centros dos 2 furos base
          distancia_base_centro: 9.5,   # mm — centro caneco ao centro linha base
        },
        grass: {
          nome: 'Grass Tiomos / Nexis',
          diametro_copa: 35.0, profundidade_copa: 13.5, calco: 3.0,
          centro_copa: 20.5, diametro_base: 5.0, profundidade_base: 11.5,
          distancia_base: 48.0, distancia_base_centro: 9.5,
        },
        hettich: {
          nome: 'Hettich Sensys / Intermat',
          diametro_copa: 35.0, profundidade_copa: 13.0, calco: 3.0,
          centro_copa: 20.5, diametro_base: 5.0, profundidade_base: 12.0,
          distancia_base: 52.0, distancia_base_centro: 9.5,
        },
        hafele: {
          nome: 'Hafele / Italiana (generico)',
          diametro_copa: 35.0, profundidade_copa: 12.5, calco: 4.0,
          centro_copa: 21.5, diametro_base: 5.0, profundidade_base: 11.0,
          distancia_base: 48.0, distancia_base_centro: 9.5,
        },
        personalizado: {
          nome: 'Personalizado',
          diametro_copa: 35.0, profundidade_copa: 13.0, calco: 3.0,
          centro_copa: 20.5, diametro_base: 5.0, profundidade_base: 12.0,
          distancia_base: 48.0, distancia_base_centro: 9.5,
        },
      }.freeze

      # ── 1.2 Corredicas ────────────────────────────────────────────
      PERFIS_CORREDICA = {
        blum_tandembox: {
          nome: 'Blum Tandembox',
          folga_lateral: 13.0, altura_eixo: 37.0,
          furo_fixacao_diametro: 5.0, furo_fixacao_prof: 11.0,
          comprimentos: [250, 270, 300, 350, 400, 450, 500, 550, 600],
        },
        blum_movento: {
          nome: 'Blum Movento',
          folga_lateral: 13.0, altura_eixo: 37.0,
          furo_fixacao_diametro: 5.0, furo_fixacao_prof: 11.0,
          comprimentos: [250, 300, 350, 400, 450, 500, 550, 600],
        },
        telescopica_45mm: {
          nome: 'Telescopica 45mm (generica)',
          folga_lateral: 12.5, altura_eixo: 22.5,
          furo_fixacao_diametro: 4.0, furo_fixacao_prof: 10.0,
          comprimentos: [250, 300, 350, 400, 450, 500, 550, 600],
        },
        hettich_actro: {
          nome: 'Hettich Actro 5D',
          folga_lateral: 13.0, altura_eixo: 37.0,
          furo_fixacao_diametro: 5.0, furo_fixacao_prof: 11.0,
          comprimentos: [250, 270, 300, 350, 400, 450, 500, 550, 600],
        },
        grass_nova_pro: {
          nome: 'Grass Nova Pro Scala',
          folga_lateral: 13.0, altura_eixo: 38.0,
          furo_fixacao_diametro: 5.0, furo_fixacao_prof: 11.0,
          comprimentos: [270, 300, 350, 400, 450, 500, 550, 600],
        },
        personalizado: {
          nome: 'Personalizado',
          folga_lateral: 12.5, altura_eixo: 22.5,
          furo_fixacao_diametro: 5.0, furo_fixacao_prof: 11.0,
          comprimentos: [250, 300, 350, 400, 450, 500, 550, 600],
        },
      }.freeze

      # ── 1.3 Aventos / Basculantes ─────────────────────────────────
      PERFIS_AVENTO = {
        blum_aventos_hf: {
          nome: 'Blum Aventos HF (Bi-fold)',
          furo_lateral_diametro: 5.0,
          furo_lateral_profundidade: 11.0,
          setback_topo: 37.0,           # mm — do topo da lateral
          setback_frontal: 37.0,        # mm — da frente
          distancia_furos: 32.0,        # mm — entre furos do mecanismo
        },
        blum_aventos_hl: {
          nome: 'Blum Aventos HL (Lift)',
          furo_lateral_diametro: 5.0,
          furo_lateral_profundidade: 11.0,
          setback_topo: 37.0, setback_frontal: 37.0, distancia_furos: 32.0,
        },
        blum_aventos_hk: {
          nome: 'Blum Aventos HK (Stay lift)',
          furo_lateral_diametro: 5.0,
          furo_lateral_profundidade: 11.0,
          setback_topo: 21.0, setback_frontal: 37.0, distancia_furos: 32.0,
        },
        grass_kinvaro: {
          nome: 'Grass Kinvaro',
          furo_lateral_diametro: 5.0,
          furo_lateral_profundidade: 11.0,
          setback_topo: 37.0, setback_frontal: 37.0, distancia_furos: 32.0,
        },
        personalizado: {
          nome: 'Personalizado',
          furo_lateral_diametro: 5.0,
          furo_lateral_profundidade: 11.0,
          setback_topo: 37.0, setback_frontal: 37.0, distancia_furos: 32.0,
        },
      }.freeze

      # ================================================================
      #  SECAO 2 — REGRAS DE QUANTIDADE (editavel)
      # ================================================================

      MAX_DOBRADICAS_POR_PORTA = 6

      REGRAS_QUANTIDADE_DOBRADICA_DEFAULT = [
        # [altura_max_mm, quantidade]
        [600,   2],
        [1000,  3],
        [1500,  4],
        [2000,  5],
        [Float::INFINITY, 6],
      ].freeze

      # ================================================================
      #  SECAO 3 — DEFAULTS GLOBAIS
      # ================================================================
      # Organizados por ferragem/usinagem. Cada bloco contem:
      #   - Furacao (diametros, profundidades)
      #   - Posicionamento (setbacks, espacamentos)
      #   - Regras de quantidade automatica (dist_borda, espac_min, espac_max)
      #
      # CONVENCAO DE QUANTIDADE AUTOMATICA:
      #   Para ferragens distribuidas linearmente (minifix, cavilha,
      #   uniblock, suporte parede, confirmat), a quantidade e calculada:
      #     qty = resultado de (comprimento, dist_borda, espac_max)
      #   Campos padrao:
      #     dist_borda       — distancia da ferragem ate cada extremidade
      #     espac_max        — maximo entre ferragens (se exceder, add +1)
      #     espac_min        — minimo (seguranca, evitar furos muito proximos)
      #     qty_min          — nunca menos que isso
      #     qty_max          — nunca mais que isso (0 = sem limite)

      DEFAULTS = {

        # ==============================================================
        # 3.1  DOBRADICA — posicionamento e regras
        # ==============================================================
        dobradica: {
          perfil_ativo: :blum,

          # ── Posicionamento vertical ────────────────────────────────
          setback_vertical_topo: 100.0,    # mm — borda superior porta ate centro 1a dob
          setback_vertical_base: 100.0,    # mm — borda inferior porta ate centro ultima
          max_espaco_entre: 500.0,         # mm — maximo entre dobradicas consecutivas

          # ── Calco (override por modulo: orn_calco) ─────────────────
          calco: 3.0,                      # mm — borda porta ate borda do furo caneco

          # ── Offset individual por slot ─────────────────────────────
          # Deslocamento mm da posicao calculada. Positivo=sobe, Negativo=desce.
          # Uso: desviar dobradica de prateleira ou travessa.
          offset_slot_0: 0.0,
          offset_slot_1: 0.0,
          offset_slot_2: 0.0,
          offset_slot_3: 0.0,
          offset_slot_4: 0.0,
          offset_slot_5: 0.0,

          # ── Rebaixo da base na lateral ─────────────────────────────
          rebaixo_largura: 50.0,           # mm
          rebaixo_altura: 36.0,            # mm
          rebaixo_profundidade: 2.0,       # mm

          # ── Regras de quantidade (editavel) ────────────────────────
          regras: {
            faixa_1_ate_mm: 600,   faixa_1_qty: 2,
            faixa_2_ate_mm: 1000,  faixa_2_qty: 3,
            faixa_3_ate_mm: 1500,  faixa_3_qty: 4,
            faixa_4_ate_mm: 2000,  faixa_4_qty: 5,
            faixa_5_ate_mm: 99999, faixa_5_qty: 6,
          },
        },

        # ==============================================================
        # 3.2  CORREDICA
        # ==============================================================
        corredica: {
          perfil_ativo: :telescopica_45mm,
          folga_lateral: 12.5,             # mm
          setback_frontal: 0.0,            # mm — recuo da frente
          setback_traseiro: 0.0,           # mm — recuo do fundo
          altura_eixo: 22.5,               # mm — centro do eixo na lateral

          # Furos fixacao da corredica na lateral
          furo_fixacao_diametro: 5.0,
          furo_fixacao_prof: 11.0,
          furo_fixacao_setback: 37.0,      # mm — do frontal (System 32)
          furo_fixacao_espacamento: 32.0,  # mm — entre furos
        },

        # ==============================================================
        # 3.3  MINIFIX (excêntrico 15mm)
        # ==============================================================
        minifix: {
          # ── Furacao ────────────────────────────────────────────────
          diametro_furo_lateral: 8.0,      # mm — furo na peca lateral
          profundidade_lateral: 34.0,      # mm
          diametro_bucha: 15.0,            # mm — furo bucha na peca horizontal
          profundidade_bucha: 13.0,        # mm

          # ── Posicionamento ─────────────────────────────────────────
          setback_frontal: 37.0,           # mm — da borda frontal ao 1o furo
          setback_traseiro: 37.0,          # mm — da borda traseira (se aplicavel)

          # ── Quantidade automatica (por comprimento da junta) ───────
          dist_borda: 50.0,                # mm — distancia minima de cada extremidade
          espac_max: 300.0,                # mm — max entre minifix (se exceder, +1)
          espac_min: 96.0,                 # mm — min entre minifix (3 x 32)
          espac_preferencial: 128.0,       # mm — ideal: 4 x 32 (System 32)
          qty_min: 2,                      # nunca menos que 2 por junta
          qty_max: 0,                      # 0 = sem limite
        },

        # ==============================================================
        # 3.4  CAVILHA (8mm)
        # ==============================================================
        cavilha: {
          # ── Furacao ────────────────────────────────────────────────
          diametro: 8.0,                   # mm
          profundidade_peca: 12.0,         # mm — profundidade em cada peca

          # ── Posicionamento ─────────────────────────────────────────
          setback_frontal: 32.0,           # mm — System 32

          # ── Quantidade automatica ──────────────────────────────────
          dist_borda: 50.0,                # mm
          espac_max: 192.0,                # mm — max entre cavilhas (6 x 32)
          espac_min: 64.0,                 # mm — min (2 x 32)
          espac_preferencial: 128.0,       # mm — ideal: 4 x 32
          qty_min: 2,
          qty_max: 0,
        },

        # ==============================================================
        # 3.5  CONFIRMAT (7x50)
        # ==============================================================
        confirmat: {
          # ── Furacao ────────────────────────────────────────────────
          diametro_passante: 7.0,          # mm
          diametro_piloto: 5.0,            # mm
          profundidade_piloto: 40.0,       # mm
          diametro_cabeca: 10.0,           # mm — rebaixo da cabeca (se embutido)
          profundidade_cabeca: 3.0,        # mm
          comprimento_parafuso: 50.0,      # mm

          # ── Posicionamento ─────────────────────────────────────────
          setback_frontal: 37.0,           # mm

          # ── Quantidade automatica ──────────────────────────────────
          dist_borda: 50.0,
          espac_max: 250.0,
          espac_min: 96.0,
          espac_preferencial: 128.0,
          qty_min: 2,
          qty_max: 0,
        },

        # ==============================================================
        # 3.6  UNIBLOCK / VB (conector de bancada / tampo)
        # ==============================================================
        uniblock: {
          # ── Furacao ────────────────────────────────────────────────
          diametro_furo: 35.0,             # mm — furo passante para corpo
          profundidade_furo: 19.0,         # mm — rebaixo face superior
          diametro_parafuso: 6.0,          # mm — furo parafuso de tracao
          comprimento_parafuso: 150.0,     # mm

          # ── Posicionamento ─────────────────────────────────────────
          dist_borda_frontal: 50.0,        # mm — da borda frontal da peca
          dist_borda_traseira: 50.0,       # mm — da borda traseira
          dist_junta: 35.0,                # mm — da linha de junta

          # ── Quantidade automatica (por comprimento da junta) ───────
          # Ex: junta de 600mm → dist_borda=50 → vao=500 → 500/300=1.67
          #     → precisa 2 intermediarias + 2 bordas = min 3
          dist_borda: 50.0,                # mm — distancia de cada extremidade
          espac_max: 300.0,                # mm — max entre uniblocks
          espac_min: 150.0,                # mm — min entre uniblocks
          qty_min: 2,                      # nunca menos que 2
          qty_max: 0,
        },

        # ==============================================================
        # 3.7  SUPORTE DE PAREDE / PENDURAL (aereo, nicho)
        # ==============================================================
        suporte_parede: {
          # ── Furacao ────────────────────────────────────────────────
          diametro_furo: 5.0,              # mm — furo de fixacao
          profundidade_furo: 12.0,         # mm

          # ── Posicionamento (na traseira ou lateral do modulo) ──────
          setback_topo: 37.0,              # mm — do topo do modulo
          setback_lateral: 50.0,           # mm — de cada lateral

          # ── Quantidade automatica (por largura do modulo) ──────────
          dist_borda: 50.0,                # mm — de cada lateral
          espac_max: 500.0,                # mm — max entre suportes
          espac_min: 200.0,
          qty_min: 2,                      # minimo 2 (esq + dir)
          qty_max: 0,

          # ── Tipos de suporte ───────────────────────────────────────
          tipo_padrao: :franceses,         # :franceses, :invisivel, :cantoneira, :clips
        },

        # ==============================================================
        # 3.8  PES REGULAVEIS (base de modulo inferior)
        # ==============================================================
        pes_regulaveis: {
          # ── Furacao ────────────────────────────────────────────────
          diametro_furo: 10.0,             # mm — furo na base
          profundidade_furo: 0.0,          # mm — passante (0 = passante)

          # ── Posicionamento ─────────────────────────────────────────
          setback_frontal: 50.0,           # mm — da borda frontal
          setback_traseiro: 50.0,          # mm — da borda traseira
          setback_lateral: 30.0,           # mm — das laterais

          # ── Quantidade automatica (por largura do modulo) ──────────
          dist_borda: 30.0,                # mm
          espac_max: 500.0,                # mm — max entre pes na mesma fileira
          espac_min: 200.0,
          qty_min_frente: 2,               # minimo na fileira da frente
          qty_min_tras: 2,                 # minimo na fileira de tras
          fileiras: 2,                     # 2 fileiras (frente e tras)

          # ── Dimensoes ──────────────────────────────────────────────
          altura_min: 100.0,               # mm — pe regulavel fechado
          altura_max: 180.0,               # mm — pe regulavel aberto
          altura_padrao: 120.0,            # mm
        },

        # ==============================================================
        # 3.9  PUXADOR
        # ==============================================================
        puxador: {
          # ── Furacao (para puxador parafusado) ──────────────────────
          diametro_furo: 5.0,              # mm — furo passante
          profundidade_furo: 0.0,          # mm — passante (0 = passante)
          distancia_furos: 128.0,          # mm — entre furos do puxador (96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448, 480, 512, 544, 576, 608, 640, 672, 704, 736)

          # ── Posicionamento na porta/frente ─────────────────────────
          posicao_vertical: :oposta_dobradica, # :oposta_dobradica, :centralizado, :customizado
          setback_borda_vertical: 80.0,    # mm — da borda da porta (quando oposta_dobradica)
          setback_borda_horizontal: 40.0,  # mm — da borda lateral da porta
          orientacao: :vertical,           # :vertical, :horizontal

          # ── Cava (puxador embutido / cava fresada) ─────────────────
          cava_profundidade: 15.0,         # mm
          cava_largura: 40.0,              # mm — largura do rasgo
          cava_comprimento: 0.0,           # mm — 0 = automatico (usa largura da peca)
          cava_diametro_fresa: 6.0,        # mm — ferramenta
          cava_posicao: :topo,             # :topo, :base, :esquerda, :direita
        },

        # ==============================================================
        # 3.10  AMORTECEDOR DE PORTA (separado, nao integrado na dobradica)
        # ==============================================================
        amortecedor: {
          # ── Furacao ────────────────────────────────────────────────
          diametro_furo: 10.0,             # mm — furo para bucha
          profundidade_furo: 12.0,         # mm

          # ── Posicionamento na lateral ──────────────────────────────
          setback_topo: 50.0,              # mm — do topo da lateral
          setback_frontal: 37.0,           # mm — da borda frontal
          qty_por_porta: 1,                # 1 amortecedor por porta (quando nao e soft-close)
        },

        # ==============================================================
        # 3.11  AVENTO / BASCULANTE
        # ==============================================================
        avento: {
          perfil_ativo: :blum_aventos_hf,

          # Posicionamento dos furos na lateral
          setback_topo: 37.0,              # mm
          setback_frontal: 37.0,           # mm
        },

        # ==============================================================
        # 3.12  FECHADURA / TRINCO
        # ==============================================================
        fechadura: {
          diametro_furo_cilindro: 22.0,    # mm — furo do cilindro
          profundidade_cilindro: 18.0,     # mm
          diametro_furo_lingueta: 22.0,    # mm — furo para lingueta na lateral
          profundidade_lingueta: 15.0,     # mm
          posicao_vertical: 1000.0,        # mm — do chao (padrao para roupeiro)
          setback_borda: 25.0,             # mm — da borda da porta
        },

        # ==============================================================
        # 3.13  RASGO DO FUNDO (canal para fundo encaixado)
        # ==============================================================
        rasgo_fundo: {
          largura_fresa: 6.0,              # mm — largura da fresa
          profundidade: 10.0,              # mm — profundidade do rasgo
          distancia_traseira: 7.0,         # mm — da borda traseira ao centro do rasgo
          folga_canal: 1.0,                # mm — folga do fundo no canal
          tipo: :passante,                 # :passante (laterais) ou :interrompido (base)
          parada_distancia: 30.0,          # mm — dist da borda para parada (se interrompido)
        },

        # ==============================================================
        # 3.14  RASGO DE GAVETA (canal para fundo da gaveta)
        # ==============================================================
        rasgo_gaveta: {
          largura_fresa: 7.0,              # mm — fresa (fundo 6mm + folga 1mm)
          profundidade: 8.0,               # mm
          altura_do_fundo: 10.0,           # mm — da base da gaveta ao centro do rasgo
          folga_canal: 0.5,                # mm
        },

        # ==============================================================
        # 3.15  SUPORTE DE PRATELEIRA (pinos regulaveis)
        # ==============================================================
        suporte_prateleira: {
          diametro_pino: 5.0,              # mm
          profundidade_furo: 12.0,         # mm
          setback_frontal: 37.0,           # mm
          setback_traseiro: 37.0,          # mm
          espacamento_vertical: 32.0,      # mm — System 32 entre furos
          pinos_por_prateleira: 4,         # 4 cantos
        },

        # ==============================================================
        # 3.16  SISTEMA 32 (linhas de furos na lateral)
        # ==============================================================
        sistema_32: {
          pitch: 32.0,                     # mm — entre furos
          setback: 37.0,                   # mm — da borda frontal ao eixo
          diametro: 5.0,                   # mm
          profundidade: 12.0,              # mm
          linhas: 2,                       # qtd linhas (frente e tras)
          inicio_mm: 37.0,                 # mm — primeiro furo (de baixo)
          fim_mm_do_topo: 37.0,            # mm — ultimo furo (distancia do topo)
        },

        # ==============================================================
        # 3.17  PORTA
        # ==============================================================
        porta: {
          folga: 2.0,                      # mm — folga entre portas / porta-modulo
          espessura: 18.0,                 # mm

          # ── Tipo de dobradica por aplicacao ───────────────────────
          # Afeta: sobreposicao da porta, selecao do braco, formulas DC.
          #
          #   :reta       — Full overlay (sobreposta). Porta cobre toda a lateral.
          #                  Braco reto. Uso: modulo isolado ou extremidade.
          #   :curva      — Half overlay (meio-esquadro). Porta cobre metade da lateral.
          #                  Braco curvo 9.5mm. Uso: 2 portas compartilham lateral central.
          #   :supercurva — Inset (embutida). Porta fica rente, dentro do vao.
          #                  Braco supercurvo 16mm. Uso: estetica flush/premium.
          #
          tipo_dobradica: :reta,             # default: full overlay

          # ── Sobreposicao por tipo (mm) ────────────────────────────
          # Quanto a porta avanca alem da lateral do modulo (por lado).
          # Reta: cobre toda a espessura da lateral (~18mm para MDF 18).
          # Curva: cobre metade (~8-9mm).
          # Supercurva: nao cobre (fica dentro, sobreposicao negativa = recuo).
          sobreposicao_reta: 0.0,            # mm — ajuste sobre a lateral (0 = rente a face ext)
          sobreposicao_curva: -9.0,          # mm — recuo de 9mm (metade da lateral)
          sobreposicao_supercurva: -18.0,    # mm — recuo total (porta interna ao vao)

          # ── Folga adicional por tipo ──────────────────────────────
          # Folga extra entre porta e corpo. Supercurva precisa de mais.
          folga_supercurva: 3.0,             # mm — folga maior para porta embutida
        },

        # ==============================================================
        # 3.18  FUNDO
        # ==============================================================
        fundo: {
          espessura: 6.0,                  # mm — HDF 6mm (padrao marcenaria BR)
          entrada: 7.0,                    # mm — recuo da frente
        },

        # ==============================================================
        # 3.19  GAVETA
        # ==============================================================
        gaveta: {
          folga_frontal: 2.0,              # mm — folga frente da gaveta
          folga_lateral: 0.0,              # mm — alem da folga da corredica
          espessura_lateral: 15.0,         # mm — lateral gaveta (caixa propria)
          espessura_traseira: 15.0,        # mm — traseira gaveta
          espessura_fundo: 6.0,            # mm — fundo gaveta (HDF 6mm)
          margem_altura: 25.0,             # mm — frente menor que o vao vertical
          folga_fundo_lateral: 1.0,        # mm — folga do fundo na lateral da gaveta
        },

        # ==============================================================
        # 3.20  POCKET (iluminacao LED, furacoes especiais)
        # ==============================================================
        pocket: {
          profundidade_padrao: 8.0,        # mm
          diametro_fresa: 6.0,             # mm
        },

        # ==============================================================
        # 3.21  PASSAFIO / PASSA-CABO
        # ==============================================================
        passa_cabo: {
          diametro: 60.0,                  # mm — furo padrao
          diametro_pequeno: 35.0,          # mm — furo pequeno
          profundidade: 0.0,               # mm — passante (0 = passante)
          setback_traseiro: 50.0,          # mm — da borda traseira
          setback_lateral: 100.0,          # mm — da lateral
        },

        # ==============================================================
        # 3.22  RODAPE / CLIPS RODAPE
        # ==============================================================
        rodape: {
          altura: 100.0,                   # mm — altura do vao do rodape
          recuo: 40.0,                     # mm — recuo em relacao a frente
          espessura: 15.0,                 # mm
          # Clips de fixacao
          clip_diametro: 8.0,              # mm — furo na base para clip
          clip_profundidade: 10.0,         # mm
          clip_dist_borda: 50.0,           # mm — de cada lateral
          clip_espac_max: 500.0,           # mm
          clip_qty_min: 2,
        },

        # ==============================================================
        # 3.23  TAMPO / BANCADA
        # ==============================================================
        tampo: {
          # Furos de fixacao por baixo (conectam tampo ao modulo)
          diametro_furo: 5.0,              # mm
          profundidade_furo: 12.0,         # mm
          setback_frontal: 50.0,           # mm — da borda frontal do modulo
          setback_traseiro: 50.0,          # mm
          setback_lateral: 50.0,           # mm

          # Quantidade automatica (ao longo do comprimento)
          dist_borda: 50.0,
          espac_max: 500.0,
          espac_min: 200.0,
          qty_min: 2,
          fileiras: 2,                     # frente e tras
        },

        # ==============================================================
        # 3.24  CANTONEIRA / ESCUADRA (reforco de canto)
        # ==============================================================
        cantoneira: {
          diametro_furo: 4.0,              # mm
          profundidade_furo: 10.0,         # mm
          setback_frontal: 50.0,           # mm — da frente
          setback_traseiro: 50.0,          # mm
          qty_por_canto: 1,                # 1 cantoneira por canto (min 2 por modulo)
        },

        # ==============================================================
        # 3.25  ESPESSURAS REAIS DE MDF
        # ==============================================================
        # Espessuras reais da marcenaria brasileira:
        #   6mm = HDF (fundo, traseira)
        #   15mm → 15.5mm real
        #   18mm → 18.5mm real
        #   25mm → 25.5mm real
        #   30mm (2x15) → 31.0mm
        #   36mm (2x18) → 37.0mm
        espessuras_reais: {
          '6' => 6.0,
          '15' => 15.5, '18' => 18.5, '25' => 25.5,
          '30' => 31.0, '36' => 37.0,
        },

        # ==============================================================
        # 3.26  CHAPA PADRAO
        # ==============================================================
        chapa: {
          comprimento: 2750.0,             # mm
          largura: 1850.0,                 # mm
          refilo_por_borda: 10.0,          # mm
        },

        # ==============================================================
        # 3.27  PESO — limites para selecao de dobradica
        # ==============================================================
        peso_porta: {
          leve_ate_kg: 8.0,
          medio_ate_kg: 15.0,
          pesado_ate_kg: 25.0,
        },

        # ==============================================================
        # 3.28  FITA DE BORDA (defaults)
        # ==============================================================
        borda: {
          espessura_padrao: 1.0,           # mm (0.45, 1.0, 2.0)
          largura_padrao: 22.0,            # mm (22, 33, 45)
          descontar_da_medida: true,       # descontar espessura da medida de corte
          prioridade: :comprimento,        # :comprimento (comp passa) ou :largura
        },

        # ==============================================================
        # 3.29  DENSIDADES DE MATERIAL (para calculo de peso)
        # ==============================================================
        densidades: {
          mdf_cru: 730,                    # kg/m3
          mdf_melamina: 750,
          mdf_lacado: 760,
          mdp: 620,
          compensado: 550,
          macico_pinus: 500,
          macico_cedro: 470,
          macico_ipe: 1050,
          vidro: 2500,
        },

      }.freeze

      # ================================================================
      #  SECAO 4 — OVERRIDE POR MODULO
      # ================================================================

      MODULE_OVERRIDES = {
        # Dobradica
        [:dobradica, :calco]                => 'orn_calco',
        [:dobradica, :setback_vertical_topo]=> 'orn_setback_dob_topo',
        [:dobradica, :setback_vertical_base]=> 'orn_setback_dob_base',
        [:dobradica, :offset_slot_0]        => 'orn_dob_offset_0',
        [:dobradica, :offset_slot_1]        => 'orn_dob_offset_1',
        [:dobradica, :offset_slot_2]        => 'orn_dob_offset_2',
        [:dobradica, :offset_slot_3]        => 'orn_dob_offset_3',
        [:dobradica, :offset_slot_4]        => 'orn_dob_offset_4',
        [:dobradica, :offset_slot_5]        => 'orn_dob_offset_5',
        # Corredica
        [:corredica, :folga_lateral]        => 'orn_folga_corredica',
        # Porta
        [:porta, :folga]                    => 'orn_folga_porta',
        [:porta, :espessura]                => 'orn_espessura_porta',
        [:porta, :tipo_dobradica]            => 'orn_tipo_dobradica',
        [:porta, :sobreposicao_reta]         => 'orn_sobreposicao_reta',
        [:porta, :sobreposicao_curva]        => 'orn_sobreposicao_curva',
        [:porta, :sobreposicao_supercurva]   => 'orn_sobreposicao_supercurva',
        # Fundo
        [:fundo, :entrada]                  => 'orn_entrada_fundo',
        [:fundo, :espessura]                => 'orn_espessura_fundo',
        # Rasgo
        [:rasgo_fundo, :distancia_traseira] => 'orn_dist_rasgo_fundo',
        [:rasgo_fundo, :profundidade]       => 'orn_prof_rasgo_fundo',
        # Gaveta
        [:gaveta, :espessura_lateral]       => 'orn_esp_lat_gaveta',
        # Puxador
        [:puxador, :distancia_furos]        => 'orn_dist_furos_puxador',
        [:puxador, :setback_borda_vertical] => 'orn_setback_puxador',
        # Rodape
        [:rodape, :altura]                  => 'orn_altura_rodape',
        [:rodape, :recuo]                   => 'orn_recuo_rodape',
      }.freeze

      # ================================================================
      #  SECAO 5 — RUNTIME
      # ================================================================

      @config = nil

      def self.config
        @config ||= carregar_ou_defaults
      end

      def self.reset!
        @config = deep_dup(DEFAULTS)
      end

      # ================================================================
      #  LEITURA
      # ================================================================

      def self.get(categoria)
        config[categoria] || {}
      end

      def self.valor(categoria, chave, modulo: nil)
        if modulo
          override_key = MODULE_OVERRIDES[[categoria, chave]]
          if override_key
            val = modulo.get_attribute('ornato', override_key)
            return val unless val.nil?
            val = modulo.definition.get_attribute('dynamic_attributes', override_key)
            return val unless val.nil?
          end
        end
        hash = config[categoria]
        hash ? hash[chave] : nil
      end

      # ================================================================
      #  ESCRITA
      # ================================================================

      def self.set(categoria, chave, novo_valor)
        config[categoria] ||= {}
        config[categoria][chave] = novo_valor
        recalcular_centro_copa if categoria == :dobradica && (chave == :calco || chave == :diametro_copa)
        salvar_no_modelo
      end

      def self.set_bulk(categoria, hash)
        config[categoria] ||= {}
        hash.each { |k, v| config[categoria][k] = v }
        recalcular_centro_copa if categoria == :dobradica
        salvar_no_modelo
      end

      # ================================================================
      #  CALCULO AUTOMATICO DE QUANTIDADE (generico)
      # ================================================================
      # Qualquer ferragem com dist_borda + espac_max usa esta logica:
      #   1. Vao util = comprimento - 2 * dist_borda
      #   2. Se vao <= espac_max → qty_min (tipico 2, nas bordas)
      #   3. Senao → qty = ceil(vao / espac_max) + 1
      #   4. Clamp entre qty_min e qty_max
      #
      # Funciona para: minifix, cavilha, confirmat, uniblock,
      # suporte_parede, clips_rodape, tampo, pes_regulaveis.

      # @param categoria [Symbol] ex: :uniblock, :minifix, :confirmat
      # @param comprimento_mm [Float] comprimento da junta/peca
      # @return [Integer] quantidade calculada
      def self.calcular_quantidade(categoria, comprimento_mm)
        cfg = get(categoria)
        dist_borda = cfg[:dist_borda] || 50.0
        espac_max  = cfg[:espac_max]  || 300.0
        qty_min    = cfg[:qty_min]    || 2
        qty_max    = cfg[:qty_max]    || 0

        vao = comprimento_mm - 2.0 * dist_borda
        return qty_min if vao <= 0

        if vao <= espac_max
          qty = qty_min
        else
          intervalos = (vao / espac_max).ceil
          qty = intervalos + 1
          qty = qty_min if qty < qty_min
        end

        qty = qty_max if qty_max > 0 && qty > qty_max
        qty
      end

      # Calcula posicoes distribuidas uniformemente.
      # @param categoria [Symbol]
      # @param comprimento_mm [Float]
      # @return [Array<Float>] posicoes em mm
      def self.calcular_posicoes(categoria, comprimento_mm)
        cfg = get(categoria)
        dist_borda = cfg[:dist_borda] || 50.0
        qty = calcular_quantidade(categoria, comprimento_mm)

        return [comprimento_mm / 2.0] if qty == 1

        inicio = dist_borda
        fim = comprimento_mm - dist_borda

        if qty == 2
          [inicio, fim]
        else
          step = (fim - inicio) / (qty - 1).to_f
          (0...qty).map { |i| (inicio + step * i).round(1) }
        end
      end

      # Calcula posicoes em grid System 32 (snap para multiplo de 32).
      # @param categoria [Symbol]
      # @param comprimento_mm [Float]
      # @return [Array<Float>] posicoes snapped para System 32
      def self.calcular_posicoes_s32(categoria, comprimento_mm)
        posicoes = calcular_posicoes(categoria, comprimento_mm)
        posicoes.map { |p| (p / 32.0).round * 32.0 }
      end

      # ================================================================
      #  DOBRADICA — acesso direto
      # ================================================================

      def self.dobradica
        perfil_sym = config.dig(:dobradica, :perfil_ativo) || :blum
        perfil = PERFIS_DOBRADICA[perfil_sym] || PERFIS_DOBRADICA[:blum]
        calco_override = config.dig(:dobradica, :calco)

        resultado = perfil.merge(
          setback_vertical_topo: config.dig(:dobradica, :setback_vertical_topo) || 100.0,
          setback_vertical_base: config.dig(:dobradica, :setback_vertical_base) || 100.0,
          max_espaco_entre: config.dig(:dobradica, :max_espaco_entre) || 500.0,
          perfil_ativo: perfil_sym,
          rebaixo_largura: config.dig(:dobradica, :rebaixo_largura) || 50.0,
          rebaixo_altura: config.dig(:dobradica, :rebaixo_altura) || 36.0,
          rebaixo_profundidade: config.dig(:dobradica, :rebaixo_profundidade) || 2.0,
        )

        if calco_override && calco_override != perfil[:calco]
          resultado[:calco] = calco_override
          resultado[:centro_copa] = resultado[:diametro_copa] / 2.0 + calco_override
        end

        MAX_DOBRADICAS_POR_PORTA.times do |i|
          key = "offset_slot_#{i}".to_sym
          resultado[key] = config.dig(:dobradica, key) || 0.0
        end

        resultado
      end

      def self.perfil_dobradica(marca)
        PERFIS_DOBRADICA[marca] || PERFIS_DOBRADICA[:blum]
      end

      def self.aplicar_perfil_dobradica(marca)
        return unless PERFIS_DOBRADICA.key?(marca)
        set(:dobradica, :perfil_ativo, marca)
        set(:dobradica, :calco, PERFIS_DOBRADICA[marca][:calco])
      end

      # ================================================================
      #  CORREDICA — acesso direto
      # ================================================================

      def self.corredica
        perfil_sym = config.dig(:corredica, :perfil_ativo) || :telescopica_45mm
        perfil = PERFIS_CORREDICA[perfil_sym] || PERFIS_CORREDICA[:telescopica_45mm]

        perfil.merge(
          perfil_ativo: perfil_sym,
          setback_frontal: config.dig(:corredica, :setback_frontal) || 0.0,
          setback_traseiro: config.dig(:corredica, :setback_traseiro) || 0.0,
          furo_fixacao_setback: config.dig(:corredica, :furo_fixacao_setback) || 37.0,
          furo_fixacao_espacamento: config.dig(:corredica, :furo_fixacao_espacamento) || 32.0,
        )
      end

      def self.aplicar_perfil_corredica(marca)
        return unless PERFIS_CORREDICA.key?(marca)
        set(:corredica, :perfil_ativo, marca)
        set(:corredica, :folga_lateral, PERFIS_CORREDICA[marca][:folga_lateral])
      end

      # ================================================================
      #  AVENTO — acesso direto
      # ================================================================

      def self.avento
        perfil_sym = config.dig(:avento, :perfil_ativo) || :blum_aventos_hf
        perfil = PERFIS_AVENTO[perfil_sym] || PERFIS_AVENTO[:blum_aventos_hf]

        perfil.merge(
          perfil_ativo: perfil_sym,
          setback_topo: config.dig(:avento, :setback_topo) || 37.0,
          setback_frontal: config.dig(:avento, :setback_frontal) || 37.0,
        )
      end

      def self.aplicar_perfil_avento(marca)
        return unless PERFIS_AVENTO.key?(marca)
        set(:avento, :perfil_ativo, marca)
      end

      # ================================================================
      #  QUANTIDADE DE DOBRADICAS
      # ================================================================

      def self.regras_quantidade_dobradica
        cfg = config.dig(:dobradica, :regras) || {}
        regras = []
        (1..5).each do |i|
          ate = cfg["faixa_#{i}_ate_mm".to_sym]
          qty = cfg["faixa_#{i}_qty".to_sym]
          regras << [ate.to_f, qty.to_i] if ate && qty
        end
        regras.empty? ? REGRAS_QUANTIDADE_DOBRADICA_DEFAULT : regras
      end

      def self.set_regra_dobradica(faixa_num, ate_mm, quantidade)
        config[:dobradica] ||= {}
        config[:dobradica][:regras] ||= {}
        config[:dobradica][:regras]["faixa_#{faixa_num}_ate_mm".to_sym] = ate_mm
        config[:dobradica][:regras]["faixa_#{faixa_num}_qty".to_sym] = quantidade
        salvar_no_modelo
      end

      def self.quantidade_dobradicas(altura_porta_mm)
        regras_quantidade_dobradica.each do |max_mm, qty|
          return qty if altura_porta_mm <= max_mm
        end
        MAX_DOBRADICAS_POR_PORTA
      end

      # ================================================================
      #  FORMULAS DC — Hidden e Z parametricos
      # ================================================================

      def self.formula_hidden_dobradica(slot_index)
        return 'false' if slot_index < 2
        regras = regras_quantidade_dobradica
        regra_idx = slot_index - 2
        if regra_idx < regras.length
          limiar_mm = regras[regra_idx][0]
          limiar_cm = limiar_mm / 10.0
          "IF(Parent!orn_altura<=#{limiar_cm},TRUE,FALSE)"
        else
          'true'
        end
      end

      def self.formula_z_dobradica(slot_index, total_slots)
        cfg = dobradica
        setback_topo_cm = cfg[:setback_vertical_topo] / 10.0
        setback_base_cm = cfg[:setback_vertical_base] / 10.0
        offset_mm = cfg["offset_slot_#{slot_index}".to_sym] || 0.0
        offset_cm = offset_mm / 10.0

        if total_slots <= 2
          base = if slot_index == 0
            "#{setback_base_cm}"
          else
            "Parent!orn_altura - #{setback_topo_cm}"
          end
        else
          base = if slot_index == 0
            "#{setback_base_cm}"
          elsif slot_index == total_slots - 1
            "Parent!orn_altura - #{setback_topo_cm}"
          else
            "#{setback_base_cm} + " \
            "(Parent!orn_altura - #{setback_base_cm} - #{setback_topo_cm}) " \
            "* #{slot_index} / #{total_slots - 1}"
          end
        end

        if offset_cm != 0.0
          sign = offset_cm > 0 ? '+' : '-'
          "#{base} #{sign} #{offset_cm.abs}"
        else
          base
        end
      end

      # ================================================================
      #  CONVENIENCIAS
      # ================================================================

      def self.espessura_real(nominal_mm)
        esp = config[:espessuras_reais] || {}
        esp[nominal_mm.to_s] || esp[nominal_mm.to_i.to_s] || nominal_mm.to_f
      end

      # ================================================================
      #  PORTA — tipo de dobradica e sobreposicao
      # ================================================================

      # Retorna tipo de dobradica ativo (:reta, :curva, :supercurva).
      # Pode ser overridden por modulo via orn_tipo_dobradica.
      def self.tipo_dobradica(modulo: nil)
        tipo = valor(:porta, :tipo_dobradica, modulo: modulo)
        tipo = tipo.to_sym if tipo.is_a?(String)
        tipo || :reta
      end

      # Retorna sobreposicao em mm para o tipo de dobradica ativo.
      # @param modulo [Sketchup::ComponentInstance, nil] para override por modulo
      # @return [Float] sobreposicao em mm (positivo=alem da lateral, negativo=recuado)
      def self.sobreposicao_porta(modulo: nil)
        tipo = tipo_dobradica(modulo: modulo)
        case tipo
        when :reta
          valor(:porta, :sobreposicao_reta, modulo: modulo) || 0.0
        when :curva
          valor(:porta, :sobreposicao_curva, modulo: modulo) || -9.0
        when :supercurva
          valor(:porta, :sobreposicao_supercurva, modulo: modulo) || -18.0
        else
          0.0
        end
      end

      # Retorna folga efetiva da porta (supercurva usa folga maior).
      def self.folga_porta(modulo: nil)
        folga_base = valor(:porta, :folga, modulo: modulo) || 2.0
        tipo = tipo_dobradica(modulo: modulo)
        if tipo == :supercurva
          folga_extra = valor(:porta, :folga_supercurva, modulo: modulo) || 3.0
          folga_base + folga_extra
        else
          folga_base
        end
      end

      # Retorna o sufixo de modelo de dobradica pelo tipo.
      # Ex: 'DOBR_RETA_110_SOFT', 'DOBR_CURVA_110_SOFT', 'DOBR_SUPERCURVA_110_SOFT'
      def self.modelo_dobradica_por_tipo(tipo, tipo_modulo: nil)
        tipo = tipo.to_sym if tipo.is_a?(String)
        prefixo = case tipo
                  when :curva then 'DOBR_CURVA'
                  when :supercurva then 'DOBR_SUPERCURVA'
                  else 'DOBR_RETA'
                  end
        case tipo_modulo
        when :superior then "#{prefixo}_110_SOFT"
        when :torre, :roupeiro then "#{prefixo}_110_HEAVY"
        else "#{prefixo}_110_SOFT"
        end
      end

      def self.snap_corredica(profundidade_mm)
        perfil_sym = config.dig(:corredica, :perfil_ativo) || :telescopica_45mm
        perfil = PERFIS_CORREDICA[perfil_sym] || PERFIS_CORREDICA[:telescopica_45mm]
        comprimentos = perfil[:comprimentos] || [250, 300, 350, 400, 450, 500, 550, 600]
        comprimentos.select { |c| c <= profundidade_mm }.max || comprimentos.first
      end

      def self.snap_32(valor_mm)
        (valor_mm.to_f / 32.0).round * 32.0
      end

      # ================================================================
      #  PERSISTENCIA
      # ================================================================

      private

      def self.carregar_ou_defaults
        cfg = deep_dup(DEFAULTS)
        begin
          model = defined?(Sketchup) ? Sketchup.active_model : nil
          return cfg unless model
          dict = model.attribute_dictionary(CONFIG_DICT)
          return cfg unless dict
          cfg.each_key do |cat|
            saved = dict[cat.to_s]
            if saved.is_a?(Hash)
              saved.each do |k, v|
                if v.is_a?(Hash)
                  cfg[cat][k.to_sym] ||= {}
                  v.each { |kk, vv| cfg[cat][k.to_sym][kk.to_sym] = vv }
                else
                  cfg[cat][k.to_sym] = v
                end
              end
            end
          end
        rescue => e
          puts "[Ornato::GlobalConfig] Aviso ao carregar: #{e.message}"
        end
        cfg
      end

      def self.salvar_no_modelo
        begin
          model = defined?(Sketchup) ? Sketchup.active_model : nil
          return unless model
          config.each do |cat, valores|
            next unless valores.is_a?(Hash)
            model.set_attribute(CONFIG_DICT, cat.to_s, stringify_keys(valores))
          end
        rescue => e
          puts "[Ornato::GlobalConfig] Aviso ao salvar: #{e.message}"
        end
      end

      def self.recalcular_centro_copa
        calco = config.dig(:dobradica, :calco)
        return unless calco
        perfil_sym = config.dig(:dobradica, :perfil_ativo) || :blum
        perfil = PERFIS_DOBRADICA[perfil_sym] || PERFIS_DOBRADICA[:blum]
        diametro = perfil[:diametro_copa]
        config[:dobradica][:centro_copa_calculado] = diametro / 2.0 + calco
      end

      def self.deep_dup(hash)
        hash.each_with_object({}) do |(k, v), result|
          result[k] = case v
                      when Hash then deep_dup(v)
                      when Array then v.map { |e| e.is_a?(Hash) ? deep_dup(e) : e }
                      else v
                      end
        end
      end

      def self.stringify_keys(hash)
        return hash unless hash.is_a?(Hash)
        hash.each_with_object({}) do |(k, v), result|
          result[k.to_s] = case v
                           when Hash then stringify_keys(v)
                           when Array then v
                           else v
                           end
        end
      end
    end
  end
end
