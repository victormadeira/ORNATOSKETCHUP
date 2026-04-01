# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/hardware_catalog.rb — Catalogo de ferragens (.skp)
#
# Mapeia modelos logicos (usados pelo HardwareResolver) para os
# arquivos .skp reais na biblioteca Ornato. Quando o BoxBuilder ou
# AggregateBuilder precisam inserir uma ferragem, consultam este
# catalogo para localizar o .skp correto.
#
# ESTRUTURA:
#   HardwareCatalog.skp_path(:dobradica, :reta_amortecedor)
#   => "/Users/.../ornato/biblioteca/ferragens/dobradicas/Dobradica Amor. Cj.skp"
#
#   HardwareCatalog.todos(:corredica)
#   => [{ id: :telescopica, skp: "...", ... }, ...]

module Ornato
  module Engineering
    class HardwareCatalog

      # Raiz da biblioteca (relativo ao plugin)
      BIBLIOTECA_ROOT = File.expand_path(
        File.join(__dir__, '..', 'biblioteca', 'ferragens')
      ).freeze

      # ================================================================
      # Catalogo de Dobradicas
      # ================================================================
      DOBRADICAS = {
        # Dobradica reta 110 sem amortecedor (simples)
        reta_simples: {
          skp: 'dobradicas/Dobradica Sem Amor. Cj.skp',
          descricao: 'Dobradica Reta 110 Sem Amortecedor',
          angulo: 110,
          amortecedor: false,
          tipo_copo: :reta,
          modelos_resolver: ['DOBR_RETA_110'],
        },

        # Dobradica reta 110 com amortecedor (soft-close)
        reta_amortecedor: {
          skp: 'dobradicas/Dobradica Amor. Cj.skp',
          descricao: 'Dobradica Reta 110 Com Amortecedor',
          angulo: 110,
          amortecedor: true,
          tipo_copo: :reta,
          modelos_resolver: ['DOBR_RETA_110_SOFT'],
        },

        # Dobradica reta 110 reforçada (heavy duty)
        reta_reforçada: {
          skp: 'dobradicas/Dobradica Amor. Calco Duplo Cj.skp',
          descricao: 'Dobradica Reta 110 Calco Duplo (Reforçada)',
          angulo: 110,
          amortecedor: true,
          tipo_copo: :reta,
          modelos_resolver: ['DOBR_RETA_110_HEAVY'],
        },

        # Dobradica 165 graus
        reta_165: {
          skp: 'dobradicas/Dobradica Amor. 165 Cj.skp',
          descricao: 'Dobradica Reta 165 Com Amortecedor',
          angulo: 165,
          amortecedor: true,
          tipo_copo: :reta,
          modelos_resolver: ['DOBR_RETA_165'],
        },

        # Dobradica 165 sem amortecedor
        reta_165_simples: {
          skp: 'dobradicas/Dobradica Sem Amor.165 Cj.skp',
          descricao: 'Dobradica Reta 165 Sem Amortecedor',
          angulo: 165,
          amortecedor: false,
          tipo_copo: :reta,
          modelos_resolver: ['DOBR_RETA_165_SEM'],
        },

        # Dobradica curva (meio-esquadro / half overlay)
        curva_amortecedor: {
          skp: 'dobradicas/Dobradica Curva Amor. Cj.skp',
          descricao: 'Dobradica Curva 110 Com Amortecedor',
          angulo: 110,
          amortecedor: true,
          tipo_copo: :curva,
          modelos_resolver: ['DOBR_CURVA_110', 'DOBR_CURVA_110_SOFT'],
        },

        curva_simples: {
          skp: 'dobradicas/Dobradica Curva Sem Amor. Cj.skp',
          descricao: 'Dobradica Curva 110 Sem Amortecedor',
          angulo: 110,
          amortecedor: false,
          tipo_copo: :curva,
          modelos_resolver: ['DOBR_CURVA_110_SEM'],
        },

        # Dobradica curva reforçada (half overlay heavy duty)
        curva_reforçada: {
          skp: 'dobradicas/Dobradica Curva Amor. Cj.skp',
          descricao: 'Dobradica Curva 110 Reforçada',
          angulo: 110,
          amortecedor: true,
          tipo_copo: :curva,
          modelos_resolver: ['DOBR_CURVA_110_HEAVY'],
        },

        # Dobradica supercurva (embutida / inset / flush)
        supercurva_amortecedor: {
          skp: 'dobradicas/Dobradica Supercurva Amor. Cj.skp',
          descricao: 'Dobradica Supercurva 110 Com Amortecedor (Embutida)',
          angulo: 110,
          amortecedor: true,
          tipo_copo: :supercurva,
          modelos_resolver: ['DOBR_SUPERCURVA_110', 'DOBR_SUPERCURVA_110_SOFT'],
        },

        supercurva_simples: {
          skp: 'dobradicas/Dobradica Supercurva Sem Amor. Cj.skp',
          descricao: 'Dobradica Supercurva 110 Sem Amortecedor (Embutida)',
          angulo: 110,
          amortecedor: false,
          tipo_copo: :supercurva,
          modelos_resolver: ['DOBR_SUPERCURVA_110_SEM'],
        },

        supercurva_reforçada: {
          skp: 'dobradicas/Dobradica Supercurva Amor. Cj.skp',
          descricao: 'Dobradica Supercurva 110 Reforçada (Embutida)',
          angulo: 110,
          amortecedor: true,
          tipo_copo: :supercurva,
          modelos_resolver: ['DOBR_SUPERCURVA_110_HEAVY'],
        },

        # Canto reto (para portas em canto 90 graus)
        canto_reto_amortecedor: {
          skp: 'dobradicas/Dobradica Amor. Cj Canto Reto.skp',
          descricao: 'Dobradica Canto Reto Com Amortecedor',
          angulo: 110,
          amortecedor: true,
          tipo_copo: :canto_reto,
          modelos_resolver: ['DOBR_CANTO_RETO'],
        },

        # Canto L (165 graus em canto)
        canto_l: {
          skp: 'dobradicas/Dobradica Amor. 165 Cj Canto L.skp',
          descricao: 'Dobradica Canto L 165 Com Amortecedor',
          angulo: 165,
          amortecedor: true,
          tipo_copo: :canto_l,
          modelos_resolver: ['DOBR_CANTO_L'],
        },

        # Porta espessa (> 18mm, ex: 25mm)
        porta_espessa_amortecedor: {
          skp: 'dobradicas/Dobradica Porta Espessa Amor. Cj.skp',
          descricao: 'Dobradica Porta Espessa Com Amortecedor',
          angulo: 110,
          amortecedor: true,
          tipo_copo: :reta,
          modelos_resolver: ['DOBR_ESPESSA_110'],
        },

        # Vai-e-vem (sem click de parada)
        vai_e_vem: {
          skp: 'dobradicas/Dobradica Vai e Vem.skp',
          descricao: 'Dobradica Vai e Vem',
          angulo: 180,
          amortecedor: false,
          tipo_copo: :reta,
          modelos_resolver: ['DOBR_VAI_VEM'],
        },

        # Folha (para armarios pequenos)
        folha: {
          skp: 'dobradicas/Dobradica Folha.skp',
          descricao: 'Dobradica de Folha',
          angulo: 270,
          amortecedor: false,
          tipo_copo: :folha,
          modelos_resolver: ['DOBR_FOLHA'],
        },
      }.freeze

      # ================================================================
      # Catalogo de Kits Dobradica (porta + dobradicas pre-montadas)
      # ================================================================
      KITS_DOBRADICA = {
        kit_1_porta: {
          skp: 'dobradicas/Kit Porta Dobradica.skp',
          descricao: 'Kit 1 Porta com Dobradicas',
          portas: 1,
        },
        kit_2_portas: {
          skp: 'dobradicas/Kit 2 Portas Dobradica.skp',
          descricao: 'Kit 2 Portas com Dobradicas',
          portas: 2,
        },
        kit_1_porta_alta: {
          skp: 'dobradicas/Kit Porta Alta Dobradica.skp',
          descricao: 'Kit 1 Porta Alta com Dobradicas',
          portas: 1,
        },
        kit_2_portas_altas: {
          skp: 'dobradicas/Kit 2 Portas Altas Dobradica.skp',
          descricao: 'Kit 2 Portas Altas com Dobradicas',
          portas: 2,
        },
      }.freeze

      # ================================================================
      # Catalogo de Corredicas
      # ================================================================
      CORREDICAS = {
        telescopica: {
          skp: 'corredicas/Corredica Telescopica.skp',
          descricao: 'Corredica Telescopica Simples',
          tipo: :telescopica,
          extracao_total: false,
          modelos_resolver: ['CORR_TELESCOPICA'],
        },
        telescopica_amortecedor: {
          skp: 'corredicas/Corredica Telescopica com Amortecedor.skp',
          descricao: 'Corredica Telescopica com Amortecedor',
          tipo: :telescopica,
          extracao_total: false,
          modelos_resolver: ['CORR_TELESCOPICA_SOFT'],
        },
        telescopica_inox: {
          skp: 'corredicas/Corredica Telescopica Inox.skp',
          descricao: 'Corredica Telescopica Inox',
          tipo: :telescopica,
          extracao_total: false,
          modelos_resolver: ['CORR_TELESCOPICA_INOX'],
        },
        telescopica_light: {
          skp: 'corredicas/Corredica Telescopica Light.skp',
          descricao: 'Corredica Telescopica Light',
          tipo: :telescopica,
          extracao_total: false,
          modelos_resolver: ['CORR_TELESCOPICA_LIGHT'],
        },
        oculta_total: {
          skp: 'corredicas/Corredica Oculta Extensao Total.skp',
          descricao: 'Corredica Oculta Extracao Total (Tandembox)',
          tipo: :oculta,
          extracao_total: true,
          modelos_resolver: ['CORR_OCULTA_TANDEM'],
        },
        oculta_slowmotion: {
          skp: 'corredicas/Corredica Oculta Slowmotion.skp',
          descricao: 'Corredica Oculta Slowmotion',
          tipo: :oculta,
          extracao_total: true,
          modelos_resolver: ['CORR_OCULTA_SLOW'],
        },
        sobreposta: {
          skp: 'corredicas/Corredica Sobreposta.skp',
          descricao: 'Corredica Sobreposta',
          tipo: :sobreposta,
          extracao_total: false,
          modelos_resolver: ['CORR_SOBREPOSTA'],
        },
      }.freeze

      # ================================================================
      # Catalogo de Minifix / Cavilha
      # ================================================================
      MINIFIX_CAVILHA = {
        minifix_cavilha: {
          skp: 'minifix_cavilha/Minifix e Cavilha CJ.skp',
          descricao: 'Conjunto Minifix + Cavilha',
          modelos_resolver: ['MINIFIX_CAM_15'],
        },
        minifix_cavilha_simetrico: {
          skp: 'minifix_cavilha/Minifix e Cavilha CJ Simetrico.skp',
          descricao: 'Conjunto Minifix + Cavilha Simetrico',
          modelos_resolver: ['MINIFIX_CAM_15_SIM'],
        },
        minifix_cavilha_multiplo: {
          skp: 'minifix_cavilha/Minifix e Cavilha Multiplo CJ.skp',
          descricao: 'Conjunto Minifix + Cavilha Multiplo',
          modelos_resolver: ['MINIFIX_CAM_15_MULT'],
        },
        kit_minifix: {
          skp: 'minifix_cavilha/Kit Minifix.skp',
          descricao: 'Kit Minifix Individual',
          modelos_resolver: ['KIT_MINIFIX'],
        },
        kit_bucha: {
          skp: 'minifix_cavilha/Kit Bucha.skp',
          descricao: 'Kit Bucha Individual',
          modelos_resolver: ['KIT_BUCHA'],
        },
        kit_rafix: {
          skp: 'minifix_cavilha/Kit Rafix.skp',
          descricao: 'Kit Rafix (alternativa ao minifix)',
          modelos_resolver: ['KIT_RAFIX'],
        },
        cavilha: {
          skp: 'minifix_cavilha/Cavilha CJ.skp',
          descricao: 'Conjunto Cavilha',
          modelos_resolver: ['CAVILHA_8X30'],
        },
        rafix_duplo: {
          skp: 'minifix_cavilha/Rafix Duplo CJ.skp',
          descricao: 'Rafix Duplo CJ',
          modelos_resolver: ['RAFIX_DUPLO'],
        },
      }.freeze

      # ================================================================
      # Catalogo de Suportes (prateleira regulavel)
      # ================================================================
      SUPORTES = {
        pino_metalico: {
          skp: 'suportes/Pino Metalico.skp',
          descricao: 'Pino Metalico para Prateleira',
          modelos_resolver: ['SUPORTE_PINO_MET'],
        },
        pino_plastico: {
          skp: 'suportes/Pino Plastico.skp',
          descricao: 'Pino Plastico para Prateleira',
          modelos_resolver: ['SUPORTE_PINO_PLAST'],
        },
        pino_metalico_chato: {
          skp: 'suportes/Pino Metalico Chato CJ.skp',
          descricao: 'Pino Metalico Chato CJ',
          modelos_resolver: ['SUPORTE_PINO_CHATO'],
        },
        suporte_pino_u: {
          skp: 'suportes/Suporte Pino U.skp',
          descricao: 'Suporte Pino U',
          modelos_resolver: ['SUPORTE_PINO_U'],
        },
      }.freeze

      # ================================================================
      # Catalogo de Aventos (basculante / lift)
      # ================================================================
      AVENTOS = {
        avento_padrao: {
          skp: 'aventos/Avento HF CJ.skp',
          descricao: 'Avento HF Bi-fold (Blum)',
          tipo: :bi_fold,
          modelos_resolver: ['AVENT_HF'],
        },
        avento_lift: {
          skp: 'aventos/Avento HL CJ.skp',
          descricao: 'Avento HL Lift (Blum)',
          tipo: :lift,
          modelos_resolver: ['AVENT_HL'],
        },
        avento_stay: {
          skp: 'aventos/Avento HK CJ.skp',
          descricao: 'Avento HK Stay (Blum)',
          tipo: :stay,
          modelos_resolver: ['AVENT_HK'],
        },
        pistao_gas: {
          skp: 'aventos/Pistao Gas.skp',
          descricao: 'Pistao a Gas (generico)',
          tipo: :pistao,
          modelos_resolver: ['AVENT_PISTAO'],
        },
      }.freeze

      # ================================================================
      # Catalogo de Puxadores
      # ================================================================
      # Entre-furos padrao System 32: 32, 64, 96, 128, 160, 192, 224,
      # 256, 288, 320, 352, 384, 416, 448, 480, 512, 544, 576, 608,
      # 640, 672, 704, 736mm.
      # Puxadores com 1 furo: botao/pomo. Com 2 furos: barra/perfil.
      # Cava: sem furo (fresada).
      PUXADORES = {
        # Barras parafusadas (2 furos) — varios entre-furos
        barra_128: {
          skp: 'puxadores/Puxador Barra 128.skp',
          descricao: 'Puxador Barra 128mm',
          tipo: :barra,
          entre_furos: 128,
          furos: 2,
          modelos_resolver: ['PUX_BARRA_128'],
        },
        barra_160: {
          skp: 'puxadores/Puxador Barra 160.skp',
          descricao: 'Puxador Barra 160mm',
          tipo: :barra,
          entre_furos: 160,
          furos: 2,
          modelos_resolver: ['PUX_BARRA_160'],
        },
        barra_192: {
          skp: 'puxadores/Puxador Barra 192.skp',
          descricao: 'Puxador Barra 192mm',
          tipo: :barra,
          entre_furos: 192,
          furos: 2,
          modelos_resolver: ['PUX_BARRA_192'],
        },
        barra_256: {
          skp: 'puxadores/Puxador Barra 256.skp',
          descricao: 'Puxador Barra 256mm',
          tipo: :barra,
          entre_furos: 256,
          furos: 2,
          modelos_resolver: ['PUX_BARRA_256'],
        },
        barra_320: {
          skp: 'puxadores/Puxador Barra 320.skp',
          descricao: 'Puxador Barra 320mm',
          tipo: :barra,
          entre_furos: 320,
          furos: 2,
          modelos_resolver: ['PUX_BARRA_320'],
        },
        barra_480: {
          skp: 'puxadores/Puxador Barra 480.skp',
          descricao: 'Puxador Barra 480mm',
          tipo: :barra,
          entre_furos: 480,
          furos: 2,
          modelos_resolver: ['PUX_BARRA_480'],
        },
        barra_736: {
          skp: 'puxadores/Puxador Barra 736.skp',
          descricao: 'Puxador Barra 736mm',
          tipo: :barra,
          entre_furos: 736,
          furos: 2,
          modelos_resolver: ['PUX_BARRA_736'],
        },

        # Perfil (aluminio extrudado, 2 furos)
        perfil_128: {
          skp: 'puxadores/Puxador Perfil 128.skp',
          descricao: 'Puxador Perfil Aluminio 128mm',
          tipo: :perfil,
          entre_furos: 128,
          furos: 2,
          modelos_resolver: ['PUX_PERFIL_128'],
        },
        perfil_256: {
          skp: 'puxadores/Puxador Perfil 256.skp',
          descricao: 'Puxador Perfil Aluminio 256mm',
          tipo: :perfil,
          entre_furos: 256,
          furos: 2,
          modelos_resolver: ['PUX_PERFIL_256'],
        },

        # Botao/Pomo (1 furo central)
        botao: {
          skp: 'puxadores/Puxador Botao.skp',
          descricao: 'Puxador Botao / Pomo',
          tipo: :botao,
          entre_furos: 0,
          furos: 1,
          modelos_resolver: ['PUX_BOTAO'],
        },

        # Cava fresada (sem furo, sem .skp — apenas usinagem)
        cava: {
          skp: 'puxadores/Cava Fresada.skp',
          descricao: 'Cava Fresada (puxador embutido)',
          tipo: :cava,
          entre_furos: 0,
          furos: 0,
          modelos_resolver: ['PUX_CAVA'],
        },

        # Shell/Concha (embutido concavo, 1 furo grande)
        concha: {
          skp: 'puxadores/Puxador Concha.skp',
          descricao: 'Puxador Concha / Shell',
          tipo: :concha,
          entre_furos: 0,
          furos: 1,
          modelos_resolver: ['PUX_CONCHA'],
        },
      }.freeze

      # Entre-furos disponiveis no padrao System 32
      ENTRE_FUROS_S32 = (1..23).map { |n| n * 32 }.freeze
      # => [32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384,
      #     416, 448, 480, 512, 544, 576, 608, 640, 672, 704, 736]

      # ================================================================
      # Interface publica
      # ================================================================

      # Retorna o caminho absoluto do .skp para um modelo do HardwareResolver.
      #
      # @param modelo_resolver [String] ex: 'DOBR_RETA_110_SOFT', 'CORR_TELESCOPICA_350'
      # @return [String, nil] caminho absoluto do .skp ou nil
      def self.skp_para_modelo(modelo_resolver)
        # Corrediça: extrair tamanho (ex: CORR_TELESCOPICA_350 -> CORR_TELESCOPICA)
        modelo_base = modelo_resolver.sub(/_\d{3}$/, '')

        catalogo = todos_catalogos
        entrada = catalogo.find { |e| e[:modelos_resolver]&.include?(modelo_base) }
        return nil unless entrada

        caminho = File.join(BIBLIOTECA_ROOT, entrada[:skp])
        File.exist?(caminho) ? caminho : nil
      end

      # Retorna a entrada do catalogo para um tipo e variante.
      #
      # @param categoria [Symbol] :dobradica, :corredica, :minifix, :suporte
      # @param variante [Symbol] ex: :reta_amortecedor, :telescopica
      # @return [Hash, nil]
      def self.buscar(categoria, variante)
        hash = case categoria
               when :dobradica then DOBRADICAS
               when :kit_dobradica then KITS_DOBRADICA
               when :corredica then CORREDICAS
               when :minifix, :cavilha then MINIFIX_CAVILHA
               when :suporte then SUPORTES
               when :avento then AVENTOS
               when :puxador then PUXADORES
               else nil
               end
        return nil unless hash

        entrada = hash[variante]
        return nil unless entrada

        caminho = File.join(BIBLIOTECA_ROOT, entrada[:skp])
        entrada.merge(skp_path: caminho, existe: File.exist?(caminho))
      end

      # Lista todos os itens de uma categoria.
      #
      # @param categoria [Symbol]
      # @return [Array<Hash>]
      def self.listar(categoria)
        hash = case categoria
               when :dobradica then DOBRADICAS
               when :kit_dobradica then KITS_DOBRADICA
               when :corredica then CORREDICAS
               when :minifix, :cavilha then MINIFIX_CAVILHA
               when :suporte then SUPORTES
               when :avento then AVENTOS
               when :puxador then PUXADORES
               else {}
               end

        hash.map do |id, entry|
          caminho = File.join(BIBLIOTECA_ROOT, entry[:skp])
          entry.merge(id: id, skp_path: caminho, existe: File.exist?(caminho))
        end
      end

      # Seleciona automaticamente a dobradica com base no HardwareResolver.
      #
      # @param modelo_resolver [String] ex: 'DOBR_RETA_110', 'DOBR_RETA_110_SOFT'
      # @param espessura_porta [Float] espessura em mm (para selecionar porta espessa)
      # @param canto [Symbol, nil] :reto, :l, nil
      # @return [Hash, nil] entrada do catalogo com :skp_path
      def self.selecionar_dobradica(modelo_resolver, espessura_porta: 18.0, canto: nil)
        # Porta espessa (> 20mm)
        if espessura_porta > 20
          if canto == :reto
            return buscar(:dobradica, :canto_reto_amortecedor)
          elsif canto == :l
            return buscar(:dobradica, :canto_l)
          else
            return buscar(:dobradica, :porta_espessa_amortecedor)
          end
        end

        # Canto especial
        if canto == :reto
          return buscar(:dobradica, :canto_reto_amortecedor)
        elsif canto == :l
          return buscar(:dobradica, :canto_l)
        end

        # Busca genérica: percorrer todas as variantes e encontrar pelo modelos_resolver
        DOBRADICAS.each do |variante, entry|
          if entry[:modelos_resolver]&.include?(modelo_resolver)
            return buscar(:dobradica, variante)
          end
        end

        # Fallback por prefixo (curva/supercurva/reta)
        case modelo_resolver.to_s
        when /SUPERCURVA/ then buscar(:dobradica, :supercurva_amortecedor)
        when /CURVA/      then buscar(:dobradica, :curva_amortecedor)
        when /165/        then buscar(:dobradica, :reta_165)
        else buscar(:dobradica, :reta_amortecedor)
        end
      end

      # Seleciona automaticamente a corredica.
      #
      # @param modelo_resolver [String] ex: 'CORR_TELESCOPICA_450'
      # @return [Hash, nil]
      def self.selecionar_corredica(modelo_resolver)
        modelo_base = modelo_resolver.sub(/_\d{3}$/, '')

        case modelo_base
        when 'CORR_TELESCOPICA'       then buscar(:corredica, :telescopica_amortecedor)
        when 'CORR_TELESCOPICA_SOFT'  then buscar(:corredica, :telescopica_amortecedor)
        when 'CORR_TELESCOPICA_INOX'  then buscar(:corredica, :telescopica_inox)
        when 'CORR_TELESCOPICA_LIGHT' then buscar(:corredica, :telescopica_light)
        when 'CORR_OCULTA_TANDEM'     then buscar(:corredica, :oculta_total)
        when 'CORR_OCULTA_SLOW'       then buscar(:corredica, :oculta_slowmotion)
        when 'CORR_SOBREPOSTA'        then buscar(:corredica, :sobreposta)
        else buscar(:corredica, :telescopica_amortecedor) # default
        end
      end

      # Verifica integridade: lista todos os .skp faltantes.
      #
      # @return [Array<Hash>] entradas cujo .skp nao existe
      def self.verificar_integridade
        todos_catalogos.select do |entry|
          caminho = File.join(BIBLIOTECA_ROOT, entry[:skp])
          !File.exist?(caminho)
        end
      end

      private

      # Seleciona puxador pelo modelo resolver.
      def self.selecionar_puxador(modelo_resolver)
        PUXADORES.each do |variante, entry|
          if entry[:modelos_resolver]&.include?(modelo_resolver)
            caminho = File.join(BIBLIOTECA_ROOT, entry[:skp])
            return entry.merge(id: variante, skp_path: caminho, existe: File.exist?(caminho))
          end
        end
        # Default: barra 128
        buscar(:puxador, :barra_128)
      end

      # Retorna puxadores disponiveis para um entre-furos especifico.
      def self.puxadores_para_entre_furos(entre_furos_mm)
        PUXADORES.select { |_, e| e[:entre_furos] == entre_furos_mm }
                 .map { |id, e| e.merge(id: id) }
      end

      def self.todos_catalogos
        [DOBRADICAS, KITS_DOBRADICA, CORREDICAS, MINIFIX_CAVILHA, SUPORTES, AVENTOS, PUXADORES].flat_map do |hash|
          hash.map { |id, entry| entry.merge(id: id) }
        end
      end
    end
  end
end
