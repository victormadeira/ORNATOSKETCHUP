# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/hardware_resolver.rb — Resolvedor automatico de ferragens
#
# Dado um par de pecas em contato, determina qual ferragem usar
# baseado em regras do mercado moveleiro.
#
# Fatores de decisao:
#   - Tipo semantico das pecas (lateral+base, porta+lateral, etc.)
#   - Peso estimado (para portas → tipo de dobradica)
#   - Dimensoes (largura da porta → 1 ou 2 portas, altura → qty dobradicas)
#   - Material (MDF, compensado, macico)
#   - Tipo de modulo (inferior, superior, torre)
#
# Ferragens suportadas:
#   - Minifix (excêntrico 15mm)
#   - Cavilha 8mm
#   - Confirmat 7mm
#   - Dobradiça caneco 35mm (reta, curva 110°, 170°)
#   - Corrediça telescópica (250-600mm)
#   - Corrediça oculta (tandembox, etc.)
#   - Puxador (perfil, botão, cava)
#   - Suporte de prateleira (pino 5mm)

module Ornato
  module Engineering
    class HardwareResolver

      # Resultado da resolucao de ferragem
      HardwareResult = Struct.new(
        :ferragem,           # Symbol: :minifix, :cavilha, :confirmat, :dobradica, :corredica, :suporte_prat
        :modelo,             # String: modelo especifico (ex: 'DOBR_RETA_110', 'MINIFIX_CAM')
        :quantidade,         # Integer: quantidade necessaria
        :especificacoes,     # Hash: detalhes tecnicos
        :regra_aplicada,     # String: qual regra determinou esta escolha
        :alternativas,       # Array<HardwareResult>: opcoes alternativas
        keyword_init: true
      )

      # ================================================================
      # Constantes de peso e dimensao
      # ================================================================

      # Densidade media dos materiais (kg/m3)
      DENSIDADE = {
        mdf_cru: 730,
        mdf_melamina: 750,
        mdf_lacado: 760,
        mdp: 620,
        compensado: 550,
        macico_pinus: 500,
        macico_cedro: 470,
        macico_ipe: 1050
      }.freeze

      # Limites de peso para dobradicas
      PESO_PORTA = {
        leve: 8.0,     # kg — dobradica simples
        medio: 15.0,   # kg — dobradica reforçada
        pesado: 25.0   # kg — dobradica com amortecedor pesado
      }.freeze

      # ================================================================
      # Interface publica
      # ================================================================

      # Resolve ferragem para um par de pecas em contato.
      #
      # @param peca_a [Domain::Part] primeira peca
      # @param peca_b [Domain::Part] segunda peca
      # @param tipo_contato [Symbol] tipo de contato (:topo_face, :face_face, etc.)
      # @param tipo_modulo [Symbol, nil] tipo do modulo pai
      # @return [Array<HardwareResult>] ferragens necessarias
      def resolver(peca_a, peca_b, tipo_contato, tipo_modulo: nil)
        resultados = []

        par = identificar_par(peca_a, peca_b)

        case par
        when :lateral_base, :lateral_topo
          resultados << resolver_fixacao_estrutural(peca_a, peca_b, tipo_modulo)
        when :lateral_prateleira
          resultados.concat(resolver_prateleira(peca_a, peca_b))
        when :porta_lateral
          resultados << resolver_dobradica(peca_a, peca_b, tipo_modulo)
        when :frente_gaveta_lateral
          resultados << resolver_corredica(peca_a, peca_b, tipo_modulo)
        when :lateral_fundo
          # Fundo nao precisa de ferragem — vai no rasgo
          resultados << HardwareResult.new(
            ferragem: :rasgo,
            modelo: 'RASGO_FUNDO_6X10',
            quantidade: 1,
            especificacoes: { largura: 6, profundidade: 10, distancia_traseira: 7 },
            regra_aplicada: 'Fundo encaixado em rasgo',
            alternativas: []
          )
        end

        resultados
      end

      private

      def identificar_par(peca_a, peca_b)
        tipos = [normalizar(peca_a.part_type), normalizar(peca_b.part_type)].sort
        key = tipos.join('_').to_sym

        {
          base_lateral:          :lateral_base,
          lateral_topo:          :lateral_topo,
          lateral_prateleira:    :lateral_prateleira,
          fundo_lateral:         :lateral_fundo,
          lateral_porta:         :porta_lateral,
          frente_gaveta_lateral: :frente_gaveta_lateral,
          divisoria_lateral:     :lateral_base,
          divisoria_prateleira:  :lateral_prateleira,
        }[key]
      end

      def normalizar(tipo)
        case tipo
        when :structural then 'lateral'
        when :front then 'porta'
        when :drawer then 'frente_gaveta'
        when :back then 'fundo'
        when :shelf then 'prateleira'
        when :divider then 'divisoria'
        else tipo.to_s
        end
      end

      # ── Fixacao estrutural (minifix vs confirmat) ─────────────────

      def resolver_fixacao_estrutural(peca_a, peca_b, tipo_modulo)
        # Regra: modulo visivel → minifix (invisivel na montagem)
        #        modulo de servico → confirmat (mais rapido de montar)

        if tipo_modulo == :servico || tipo_modulo == :despensa
          HardwareResult.new(
            ferragem: :confirmat,
            modelo: 'CONFIRMAT_7X50',
            quantidade: calcular_qty_fixacao(peca_a, peca_b),
            especificacoes: {
              diametro: 7.0, comprimento: 50.0,
              furo_passante: 7.0, furo_piloto: 5.0
            },
            regra_aplicada: "Modulo #{tipo_modulo}: confirmat por praticidade",
            alternativas: [minifix_result(peca_a, peca_b)]
          )
        else
          minifix_result(peca_a, peca_b)
        end
      end

      def minifix_result(peca_a, peca_b)
        HardwareResult.new(
          ferragem: :minifix,
          modelo: 'MINIFIX_CAM_15',
          quantidade: calcular_qty_fixacao(peca_a, peca_b),
          especificacoes: {
            diametro_bucha: 15.0, profundidade_bucha: 13.0,
            diametro_furo_lateral: 8.0, profundidade_lateral: 34.0,
            setback: 37.0
          },
          regra_aplicada: 'Fixacao padrao: minifix',
          alternativas: []
        )
      end

      def calcular_qty_fixacao(peca_a, peca_b)
        comprimento = [peca_a.cut_length, peca_b.cut_length].min
        if comprimento < 300
          2
        elsif comprimento < 600
          2
        elsif comprimento < 1200
          3
        else
          (comprimento / 400.0).ceil
        end
      end

      # ── Prateleira ────────────────────────────────────────────────

      def resolver_prateleira(peca_a, peca_b)
        lateral = [peca_a, peca_b].find { |p| [:lateral, :structural, :divisoria, :divider].include?(p.part_type) }
        prateleira = [peca_a, peca_b].find { |p| [:prateleira, :shelf].include?(p.part_type) }

        resultados = []

        # Minifix para prateleiras fixas
        resultados << HardwareResult.new(
          ferragem: :minifix,
          modelo: 'MINIFIX_CAM_15',
          quantidade: calcular_qty_fixacao(peca_a, peca_b),
          especificacoes: {
            diametro_bucha: 15.0, profundidade_bucha: 13.0,
            diametro_furo_lateral: 8.0, profundidade_lateral: 34.0,
            setback: 37.0
          },
          regra_aplicada: 'Prateleira fixa: minifix',
          alternativas: []
        )

        # Cavilhas intermediarias
        comprimento = prateleira ? prateleira.cut_length : peca_b.cut_length
        qty_cavilha = [(comprimento / 128.0).floor - 1, 0].max

        if qty_cavilha > 0
          resultados << HardwareResult.new(
            ferragem: :cavilha,
            modelo: 'CAVILHA_8X30',
            quantidade: qty_cavilha,
            especificacoes: {
              diametro: 8.0, comprimento: 30.0,
              profundidade_cada_lado: 12.0,
              espacamento: 128.0
            },
            regra_aplicada: "Cavilhas intermediarias: #{qty_cavilha} unidades",
            alternativas: []
          )
        end

        resultados
      end

      # ── Dobradica ─────────────────────────────────────────────────

      def resolver_dobradica(peca_a, peca_b, tipo_modulo)
        porta = [peca_a, peca_b].find { |p| [:porta, :front].include?(p.part_type) }
        lateral = [peca_a, peca_b].find { |p| p != porta }
        return nil unless porta

        peso = estimar_peso(porta)
        altura = porta.cut_length
        quantidade = calcular_qty_dobradica(altura, peso)
        modelo = selecionar_modelo_dobradica(peso, tipo_modulo)

        HardwareResult.new(
          ferragem: :dobradica,
          modelo: modelo,
          quantidade: quantidade,
          especificacoes: {
            diametro_copa: 35.0, profundidade_copa: 12.5,
            setback_copa: 21.5,
            angulo_abertura: modelo.include?('170') ? 170 : 110,
            amortecedor: peso > PESO_PORTA[:leve],
            peso_porta_kg: peso.round(2)
          },
          regra_aplicada: "Porta #{altura}mm, #{peso.round(1)}kg: #{quantidade} dobradicas #{modelo}",
          alternativas: []
        )
      end

      def estimar_peso(peca)
        # Area em m2 * espessura em m * densidade
        area_m2 = peca.area_m2
        esp_m = peca.thickness_real / 1000.0
        densidade = DENSIDADE[:mdf_melamina]
        area_m2 * esp_m * densidade
      end

      def calcular_qty_dobradica(altura, peso)
        # Regra do mercado:
        # ate 600mm: 2 dobradicas
        # 600-1000mm: 3 dobradicas
        # 1000-1500mm: 4 dobradicas
        # acima: +1 a cada 400mm

        base = if altura <= 600 then 2
               elsif altura <= 1000 then 3
               elsif altura <= 1500 then 4
               else 4 + ((altura - 1500) / 400.0).ceil
               end

        # Bonus por peso
        base += 1 if peso > PESO_PORTA[:medio]
        base += 1 if peso > PESO_PORTA[:pesado]

        base
      end

      def selecionar_modelo_dobradica(peso, tipo_modulo)
        if tipo_modulo == :superior
          # Aéreo: dobradica com mola forte + amortecedor
          peso > PESO_PORTA[:medio] ? 'DOBR_RETA_110_HEAVY' : 'DOBR_RETA_110_SOFT'
        elsif peso > PESO_PORTA[:pesado]
          'DOBR_RETA_110_HEAVY'
        elsif peso > PESO_PORTA[:leve]
          'DOBR_RETA_110_SOFT'
        else
          'DOBR_RETA_110'
        end
      end

      # ── Corrediça ─────────────────────────────────────────────────

      def resolver_corredica(peca_a, peca_b, tipo_modulo)
        frente = [peca_a, peca_b].find { |p| [:frente_gaveta, :drawer].include?(p.part_type) }
        lateral = [peca_a, peca_b].find { |p| p != frente }
        return nil unless lateral

        profundidade = lateral.cut_width # menor dimensao da lateral = profundidade do modulo
        comprimento_corredica = snap_corredica(profundidade)

        if tipo_modulo == :superior || tipo_modulo == :torre
          modelo = 'CORR_OCULTA_TANDEM'
        else
          modelo = 'CORR_TELESCOPICA'
        end

        HardwareResult.new(
          ferragem: :corredica,
          modelo: "#{modelo}_#{comprimento_corredica}",
          quantidade: 2, # par (esquerda + direita)
          especificacoes: {
            comprimento: comprimento_corredica,
            tipo: modelo,
            extracao_total: modelo.include?('OCULTA'),
            capacidade_kg: modelo.include?('OCULTA') ? 30 : 20
          },
          regra_aplicada: "Gaveta: #{modelo} #{comprimento_corredica}mm",
          alternativas: []
        )
      end

      # Snap para tamanho comercial de corrediça (250, 300, 350, 400, 450, 500, 550, 600)
      def snap_corredica(profundidade)
        tamanhos = [250, 300, 350, 400, 450, 500, 550, 600]
        # Corrediça deve ser 50mm menor que a profundidade do modulo
        ideal = profundidade - 50
        tamanhos.min_by { |t| (t - ideal).abs }
      end
    end
  end
end
