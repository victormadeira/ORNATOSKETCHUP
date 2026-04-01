# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/hardware_embedder.rb — Embutidor de ferragens em modulos
#
# Insere componentes de ferragem (.skp) como sub-componentes DC dentro
# de modulos de moveis. Assim como o WPS faz, as ferragens ficam
# embutidas no modulo e se reposicionam parametricamente.
#
# FLUXO:
#   1. AggregateBuilder cria porta/gaveta
#   2. Chama HardwareEmbedder.embutir_dobradicas(modulo_def, porta_def, ...)
#   3. HardwareEmbedder:
#      a) Consulta HardwareCatalog para localizar .skp
#      b) Carrega definition do .skp (ou reutiliza se ja carregado)
#      c) Insere instancias com posicoes parametricas (Parent! formulas)
#      d) Marca como ferragem (orn_tipo_peca: 'ferragem', orn_na_lista_corte: false)
#
# POSICIONAMENTO:
#   Dobradica: na face interna da lateral, alinhada com a porta
#     - Z superior: porta_altura - 100mm (setback topo)
#     - Z inferior: 100mm (setback base)
#     - Z intermediarias: distribuidas uniformemente
#     - Y: alinhada com a frente do modulo
#   Corredica: nas laterais internas do modulo
#     - Par esquerda/direita
#     - Z: centrada na altura da gaveta correspondente
#     - Y: do fundo ate a frente do modulo

module Ornato
  module Engineering
    class HardwareEmbedder

      # ================================================================
      # Constantes REMOVIDAS — agora vem de GlobalConfig:
      #   dobradica: setback_vertical, centro_copa, diametro_copa
      #   corredica: folga_lateral
      # ================================================================

      # Cache de definitions ja carregadas (evita reload)
      # Inclui model_id para invalidar quando muda de modelo
      @@definitions_cache = {}
      @@cache_model_id = nil

      # ================================================================
      # Interface publica — Dobradicas
      # ================================================================

      # Embutir dobradicas dentro do modulo para uma porta.
      # Cria ate MAX_DOBRADICAS_POR_PORTA slots (default 6).
      # Cada slot tem formula Hidden parametrica — se a porta for baixa,
      # os slots excedentes ficam ocultos automaticamente via DC.
      # Ao redimensionar o modulo, a quantidade se ajusta sozinha.
      #
      # @param parent_def [Sketchup::ComponentDefinition] definition do modulo
      # @param porta_tipo [Symbol] :unica, :esquerda, :direita
      # @param modelo [String] modelo do HardwareResolver (ex: 'DOBR_RETA_110_SOFT')
      # @param espessura_porta [Float] espessura da porta em mm
      # @param lado [Symbol] :esquerda ou :direita — lado onde as dobradicas ficam
      # @return [Array<Sketchup::ComponentInstance>] instancias criadas
      def self.embutir_dobradicas(parent_def, porta_tipo:, modelo:,
                                   espessura_porta: 18.0, lado: nil,
                                   quantidade: nil)
        cfg = GlobalConfig.dobradica
        max_slots = GlobalConfig::MAX_DOBRADICAS_POR_PORTA

        # Determinar lado da dobradica
        lado_dob = lado || case porta_tipo
                           when :esquerda then :esquerda
                           when :direita then :direita
                           else :esquerda  # porta unica: dobradica na esquerda
                           end

        # Buscar .skp no catalogo
        catalogo_entry = HardwareCatalog.selecionar_dobradica(
          modelo, espessura_porta: espessura_porta
        )
        return [] unless catalogo_entry && catalogo_entry[:existe]

        # Carregar definition
        dob_def = carregar_definition(catalogo_entry[:skp_path], catalogo_entry[:descricao])
        return [] unless dob_def

        instances = []
        centro_copa_cm = cfg[:centro_copa] / 10.0

        # Detectar tipo de dobradica pelo modelo selecionado
        # IMPORTANTE: testar SUPERCURVA antes de CURVA (SUPERCURVA contem CURVA)
        tipo_dob = if modelo.include?('SUPERCURVA')
                     :supercurva
                   elsif modelo.include?('CURVA')
                     :curva
                   else
                     :reta
                   end

        max_slots.times do |i|
          # Formula Z parametrica pela altura da porta
          z_formula = GlobalConfig.formula_z_dobradica(i, max_slots)

          # Formula Hidden — slot aparece/desaparece conforme altura
          hidden_formula = GlobalConfig.formula_hidden_dobradica(i)

          # Posicao X (na lateral — face interna)
          # Reta: na espessura da lateral (face interna)
          # Curva/Supercurva: mesma posicao (o braco e que muda o angulo)
          x_formula = if lado_dob == :esquerda
            'Parent!orn_espessura_real'
          else
            'Parent!orn_largura - Parent!orn_espessura_real'
          end

          # Posicao Y (frente do modulo, centro do caneco)
          # centro_copa vem do perfil de marca: diametro/2 + calco
          # Para curva/supercurva, a porta esta recuada, mas o caneco
          # e furado na porta independentemente — a posicao Y da dobradica
          # no modulo segue a posicao da porta.
          # Usa orn_sobreposicao_porta para ajustar Y da dobradica.
          y_formula = "Parent!orn_profundidade + (Parent!orn_sobreposicao_porta/10) - #{centro_copa_cm}"

          # Nome unico
          nome_inst = "Dobradica #{lado_dob.to_s.capitalize} #{i + 1}"

          # Criar wrapper DC para a ferragem
          wrapper = criar_wrapper_ferragem(
            parent_def, dob_def, nome_inst,
            tipo_ferragem: 'dobradica',
            codigo: "DOBR_#{lado_dob.to_s.upcase[0]}#{i + 1}",
            formulas: {
              x: x_formula,
              y: y_formula,
              z: z_formula,
              hidden: hidden_formula,
            },
            extras: {
              orn_tipo_dobradica: tipo_dob.to_s,
              orn_modelo_dobradica: modelo,
            }
          )

          instances << wrapper if wrapper
        end

        instances
      end

      # ================================================================
      # Interface publica — Corredicas
      # ================================================================

      # Embutir par de corredicas dentro do modulo para uma gaveta.
      #
      # @param parent_def [Sketchup::ComponentDefinition] definition do modulo
      # @param gaveta_indice [Integer] indice da gaveta (0-based)
      # @param total_gavetas [Integer] total de gavetas no modulo
      # @param modelo [String] modelo do HardwareResolver (ex: 'CORR_TELESCOPICA_450')
      # @return [Array<Sketchup::ComponentInstance>] instancias criadas (2: esq + dir)
      def self.embutir_corredicas(parent_def, gaveta_indice:, total_gavetas:,
                                   modelo: 'CORR_TELESCOPICA')
        catalogo_entry = HardwareCatalog.selecionar_corredica(modelo)
        return [] unless catalogo_entry && catalogo_entry[:existe]

        corr_def = carregar_definition(catalogo_entry[:skp_path], catalogo_entry[:descricao])
        return [] unless corr_def

        instances = []

        # Posicao Z central da gaveta
        z_formula = formula_z_corredica(gaveta_indice, total_gavetas)

        # Corredica esquerda
        instances << criar_wrapper_ferragem(
          parent_def, corr_def,
          "Corredica Esq Gaveta #{gaveta_indice + 1}",
          tipo_ferragem: 'corredica',
          codigo: "CORR_E_G#{gaveta_indice + 1}",
          formulas: {
            x: 'Parent!orn_espessura_real',
            y: '0',
            z: z_formula,
          }
        )

        # Corredica direita
        instances << criar_wrapper_ferragem(
          parent_def, corr_def,
          "Corredica Dir Gaveta #{gaveta_indice + 1}",
          tipo_ferragem: 'corredica',
          codigo: "CORR_D_G#{gaveta_indice + 1}",
          formulas: {
            x: 'Parent!orn_largura - Parent!orn_espessura_real',
            y: '0',
            z: z_formula,
          }
        )

        instances.compact
      end

      # ================================================================
      # Interface publica — Minifix/Cavilha (juntas estruturais)
      # ================================================================

      # Embutir minifix nas juntas lateral-base e lateral-topo.
      #
      # @param parent_def [Sketchup::ComponentDefinition] definition do modulo
      # @param junta [Symbol] :base, :topo — qual junta
      # @param lado [Symbol] :esquerda, :direita — qual lateral
      # @return [Sketchup::ComponentInstance, nil]
      # Embutir minifix nas juntas lateral-base e lateral-topo.
      # Calcula quantidade automatica via GlobalConfig (min 2 por junta).
      #
      # @param parent_def [Sketchup::ComponentDefinition] definition do modulo
      # @param junta [Symbol] :base, :topo — qual junta
      # @param lado [Symbol] :esquerda, :direita — qual lateral
      # @return [Array<Sketchup::ComponentInstance>]
      def self.embutir_minifix(parent_def, junta:, lado:)
        catalogo_entry = HardwareCatalog.buscar(:minifix, :minifix_cavilha)
        return [] unless catalogo_entry && catalogo_entry[:existe]

        mini_def = carregar_definition(catalogo_entry[:skp_path], catalogo_entry[:descricao])
        return [] unless mini_def

        # Posicao X (na lateral)
        x_formula = if lado == :esquerda
          'Parent!orn_espessura_real/2'
        else
          'Parent!orn_largura - Parent!orn_espessura_real/2'
        end

        # Posicao Z (na base ou topo)
        z_formula = if junta == :base
          'Parent!orn_espessura_real/2'
        else
          'Parent!orn_altura - Parent!orn_espessura_real/2'
        end

        # Calcular posicoes Y distribuidas pela profundidade da junta.
        # Leitura: profundidade do modulo a partir dos atributos DC.
        prof_mm_attr = parent_def.get_attribute('dynamic_attributes', 'orn_profundidade')
        prof_mm = (prof_mm_attr || 55.0) * 10.0  # cm -> mm

        posicoes_y = GlobalConfig.calcular_posicoes_s32(:minifix, prof_mm)
        posicoes_y = [prof_mm / 2.0] if posicoes_y.empty?

        instances = []
        posicoes_y.each_with_index do |y_mm, i|
          y_cm = y_mm / 10.0  # mm -> cm
          nome = "Minifix #{junta.to_s.capitalize} #{lado.to_s.capitalize} #{i + 1}"

          inst = criar_wrapper_ferragem(
            parent_def, mini_def, nome,
            tipo_ferragem: 'minifix',
            codigo: "MF_#{junta.to_s.upcase[0]}_#{lado.to_s.upcase[0]}#{i + 1}",
            formulas: {
              x: x_formula,
              y: "#{y_cm}",
              z: z_formula,
            }
          )
          instances << inst if inst
        end

        instances
      end

      # ================================================================
      # Interface publica — Suportes de prateleira regulavel
      # ================================================================

      # Embutir 4 suportes (pinos) para uma prateleira regulavel.
      #
      # @param parent_def [Sketchup::ComponentDefinition]
      # @param posicao_z_pct [Float] posicao vertical em % (0.0 a 1.0)
      # @return [Array<Sketchup::ComponentInstance>]
      def self.embutir_suportes_prateleira(parent_def, posicao_z_pct: 0.5)
        catalogo_entry = HardwareCatalog.buscar(:suporte, :pino_metalico)
        return [] unless catalogo_entry && catalogo_entry[:existe]

        pino_def = carregar_definition(catalogo_entry[:skp_path], catalogo_entry[:descricao])
        return [] unless pino_def

        z_formula = "Parent!orn_espessura_real + " \
                    "(Parent!orn_altura - 2*Parent!orn_espessura_real) * #{posicao_z_pct}"

        instances = []

        # 4 cantos: esq-frente, esq-tras, dir-frente, dir-tras
        positions = [
          { nome: 'Sup Prat EF', x: 'Parent!orn_espessura_real/2',
            y: 'Parent!orn_profundidade - 3.7', codigo: 'SP_EF' },   # 37mm da frente
          { nome: 'Sup Prat ET', x: 'Parent!orn_espessura_real/2',
            y: '3.7', codigo: 'SP_ET' },                              # 37mm do fundo
          { nome: 'Sup Prat DF', x: 'Parent!orn_largura - Parent!orn_espessura_real/2',
            y: 'Parent!orn_profundidade - 3.7', codigo: 'SP_DF' },
          { nome: 'Sup Prat DT', x: 'Parent!orn_largura - Parent!orn_espessura_real/2',
            y: '3.7', codigo: 'SP_DT' },
        ]

        positions.each do |pos|
          instances << criar_wrapper_ferragem(
            parent_def, pino_def, pos[:nome],
            tipo_ferragem: 'suporte_prateleira',
            codigo: pos[:codigo],
            formulas: {
              x: pos[:x],
              y: pos[:y],
              z: z_formula,
            }
          )
        end

        instances.compact
      end

      # ================================================================
      # Interface publica — Puxadores
      # ================================================================

      # Embutir puxador em porta ou frente de gaveta.
      # Cria 1 ou 2 furos (conforme tipo) com posicao parametrica.
      #
      # Para puxador de barra (2 furos):
      #   - Vertical: furos alinhados no eixo Z, separados por entre_furos
      #   - Horizontal: furos alinhados no eixo X, separados por entre_furos
      # Para botao (1 furo): furo unico na posicao calculada.
      # Para cava: sem furo, cria marcador de usinagem (fresa).
      #
      # @param parent_def [Sketchup::ComponentDefinition]
      # @param alvo [Symbol] :porta ou :gaveta
      # @param modelo [String] modelo resolver (ex: 'PUX_BARRA_128')
      # @param entre_furos_mm [Integer] distancia entre furos (0 para botao/cava)
      # @param orientacao [Symbol] :vertical ou :horizontal
      # @param lado_porta [Symbol, nil] :esquerda, :direita — lado oposto a dobradica
      # @param setback_vertical_cm [Float] distancia da borda vertical da porta (cm)
      # @param setback_horizontal_cm [Float] distancia da borda horizontal (cm)
      # @param gaveta_indice [Integer] indice da gaveta (para posicao Z)
      # @return [Array<Sketchup::ComponentInstance>]
      def self.embutir_puxador(parent_def, alvo:, modelo:, entre_furos_mm:,
                                orientacao: :vertical, lado_porta: nil,
                                setback_vertical_cm: 8.0,
                                setback_horizontal_cm: 4.0,
                                gaveta_indice: 0)
        catalogo_entry = HardwareCatalog.selecionar_puxador(modelo)
        pux_def = nil
        if catalogo_entry && catalogo_entry[:existe]
          pux_def = carregar_definition(catalogo_entry[:skp_path], catalogo_entry[:descricao])
        end

        ef_cm = entre_furos_mm / 10.0
        tipo_pux = catalogo_entry ? catalogo_entry[:tipo] : :barra
        num_furos = catalogo_entry ? (catalogo_entry[:furos] || 2) : 2

        instances = []

        if alvo == :porta
          # Puxador em porta — posicao oposta a dobradica
          # Detectar lado da dobradica para colocar puxador no lado oposto
          lado_dob = detectar_lado_dobradica(parent_def)
          lado_pux = lado_porta || (lado_dob == :esquerda ? :direita : :esquerda)

          # X: do lado oposto a dobradica
          x_formula = if lado_pux == :direita
            "Parent!orn_largura - Parent!orn_espessura_real - #{setback_horizontal_cm}"
          else
            "Parent!orn_espessura_real + #{setback_horizontal_cm}"
          end

          # Y: na face frontal (mesma profundidade da porta)
          y_formula = 'Parent!orn_profundidade + (Parent!orn_sobreposicao_porta/10)'

          if tipo_pux == :cava
            # Cava: marcador de usinagem na borda da porta
            instances << criar_marcador_puxador(
              parent_def, 'Cava Puxador',
              tipo: :cava,
              x: x_formula,
              y: y_formula,
              z: "Parent!orn_altura / 2",
              extras: { orn_tipo_puxador: 'cava', orn_modelo_puxador: modelo }
            )
          elsif num_furos == 1
            # Botao: 1 furo
            z_formula = "#{setback_vertical_cm}"
            inst = embutir_instancia_puxador(parent_def, pux_def, 'Puxador Botao',
              x: x_formula, y: y_formula, z: z_formula,
              modelo: modelo, tipo: 'botao', indice: 0)
            instances << inst if inst
          else
            # Barra/Perfil: 2 furos
            if orientacao == :vertical
              z_base = "#{setback_vertical_cm}"
              z_topo = "#{setback_vertical_cm} + #{ef_cm}"

              inst1 = embutir_instancia_puxador(parent_def, pux_def, 'Puxador Furo Inf',
                x: x_formula, y: y_formula, z: z_base,
                modelo: modelo, tipo: 'barra', indice: 0)
              inst2 = embutir_instancia_puxador(parent_def, pux_def, 'Puxador Furo Sup',
                x: x_formula, y: y_formula, z: z_topo,
                modelo: modelo, tipo: 'barra', indice: 1)
              instances << inst1 if inst1
              instances << inst2 if inst2
            else
              # Horizontal
              x_esq = "#{x_formula} - #{ef_cm / 2.0}"
              x_dir = "#{x_formula} + #{ef_cm / 2.0}"
              z_formula = "#{setback_vertical_cm}"

              inst1 = embutir_instancia_puxador(parent_def, pux_def, 'Puxador Furo Esq',
                x: x_esq, y: y_formula, z: z_formula,
                modelo: modelo, tipo: 'barra', indice: 0)
              inst2 = embutir_instancia_puxador(parent_def, pux_def, 'Puxador Furo Dir',
                x: x_dir, y: y_formula, z: z_formula,
                modelo: modelo, tipo: 'barra', indice: 1)
              instances << inst1 if inst1
              instances << inst2 if inst2
            end
          end

        elsif alvo == :gaveta
          # Puxador em gaveta — centralizado horizontalmente
          x_formula = 'Parent!orn_largura / 2'
          y_formula = 'Parent!orn_profundidade'

          # Z depende da gaveta: precisa do atributo da frente
          total_gavetas_attr = parent_def.get_attribute('dynamic_attributes', 'orn_qtd_gavetas') || 3
          z_base_formula = "(Parent!orn_folga_porta/10) + " \
                           "((Parent!orn_altura - (Parent!orn_folga_porta*2/10)) / #{total_gavetas_attr}) * #{gaveta_indice} + " \
                           "#{setback_vertical_cm}"

          if tipo_pux == :cava
            instances << criar_marcador_puxador(
              parent_def, "Cava Gaveta #{gaveta_indice + 1}",
              tipo: :cava,
              x: x_formula, y: y_formula, z: z_base_formula,
              extras: { orn_tipo_puxador: 'cava', orn_modelo_puxador: modelo }
            )
          elsif num_furos == 1
            inst = embutir_instancia_puxador(parent_def, pux_def,
              "Puxador Gaveta #{gaveta_indice + 1}",
              x: x_formula, y: y_formula, z: z_base_formula,
              modelo: modelo, tipo: 'botao', indice: 0)
            instances << inst if inst
          else
            if orientacao == :horizontal
              x_esq = "Parent!orn_largura / 2 - #{ef_cm / 2.0}"
              x_dir = "Parent!orn_largura / 2 + #{ef_cm / 2.0}"

              inst1 = embutir_instancia_puxador(parent_def, pux_def,
                "Puxador Gaveta #{gaveta_indice + 1} Esq",
                x: x_esq, y: y_formula, z: z_base_formula,
                modelo: modelo, tipo: 'barra', indice: 0)
              inst2 = embutir_instancia_puxador(parent_def, pux_def,
                "Puxador Gaveta #{gaveta_indice + 1} Dir",
                x: x_dir, y: y_formula, z: z_base_formula,
                modelo: modelo, tipo: 'barra', indice: 1)
              instances << inst1 if inst1
              instances << inst2 if inst2
            else
              # Vertical na gaveta
              z_inf = z_base_formula
              z_sup = "#{z_base_formula} + #{ef_cm}"

              inst1 = embutir_instancia_puxador(parent_def, pux_def,
                "Puxador Gaveta #{gaveta_indice + 1} Inf",
                x: x_formula, y: y_formula, z: z_inf,
                modelo: modelo, tipo: 'barra', indice: 0)
              inst2 = embutir_instancia_puxador(parent_def, pux_def,
                "Puxador Gaveta #{gaveta_indice + 1} Sup",
                x: x_formula, y: y_formula, z: z_sup,
                modelo: modelo, tipo: 'barra', indice: 1)
              instances << inst1 if inst1
              instances << inst2 if inst2
            end
          end
        end

        instances.compact
      end

      # ================================================================
      # Interface publica — Aventos (basculante)
      # ================================================================

      # Embutir par de mecanismos de avento (esquerda + direita nas laterais).
      # Posicao: topo da lateral, setback frontal e topo conforme perfil.
      #
      # @param parent_def [Sketchup::ComponentDefinition] definition do modulo
      # @return [Array<Sketchup::ComponentInstance>]
      def self.embutir_aventos(parent_def)
        cfg = GlobalConfig.avento
        catalogo_entry = HardwareCatalog.buscar(:avento, :avento_padrao)

        # Se nao ha avento no catalogo, tentar o generico
        unless catalogo_entry && catalogo_entry[:existe]
          # Avento sem .skp — criar apenas marcadores de posicao
          # para CNC (furos de fixacao) sem componente visual
          return embutir_furos_avento(parent_def, cfg)
        end

        avento_def = carregar_definition(catalogo_entry[:skp_path], catalogo_entry[:descricao])
        return embutir_furos_avento(parent_def, cfg) unless avento_def

        setback_topo_cm = (cfg[:setback_topo] || 37.0) / 10.0
        setback_frontal_cm = (cfg[:setback_frontal] || 37.0) / 10.0

        instances = []

        # Avento esquerdo
        instances << criar_wrapper_ferragem(
          parent_def, avento_def, 'Avento Esquerdo',
          tipo_ferragem: 'avento',
          codigo: 'AVENT_E',
          formulas: {
            x: 'Parent!orn_espessura_real',
            y: "#{setback_frontal_cm}",
            z: "Parent!orn_altura - #{setback_topo_cm}",
          }
        )

        # Avento direito
        instances << criar_wrapper_ferragem(
          parent_def, avento_def, 'Avento Direito',
          tipo_ferragem: 'avento',
          codigo: 'AVENT_D',
          formulas: {
            x: 'Parent!orn_largura - Parent!orn_espessura_real',
            y: "#{setback_frontal_cm}",
            z: "Parent!orn_altura - #{setback_topo_cm}",
          }
        )

        instances.compact
      end

      # Cria marcadores de furacao para avento quando nao ha .skp disponivel.
      # O mecanismo de avento precisa de 2 furos por lateral (direito e esquerdo).
      def self.embutir_furos_avento(parent_def, cfg)
        setback_topo_cm = (cfg[:setback_topo] || 37.0) / 10.0
        setback_frontal_cm = (cfg[:setback_frontal] || 37.0) / 10.0
        dist_furos_cm = (cfg[:distancia_furos] || 32.0) / 10.0

        instances = []

        # 2 furos por lado (esq + dir) para fixacao do mecanismo
        [
          { nome: 'Furo Avento E1', x: 'Parent!orn_espessura_real/2',
            y: "#{setback_frontal_cm}", codigo: 'FAV_E1' },
          { nome: 'Furo Avento E2', x: 'Parent!orn_espessura_real/2',
            y: "#{setback_frontal_cm} + #{dist_furos_cm}", codigo: 'FAV_E2' },
          { nome: 'Furo Avento D1', x: 'Parent!orn_largura - Parent!orn_espessura_real/2',
            y: "#{setback_frontal_cm}", codigo: 'FAV_D1' },
          { nome: 'Furo Avento D2', x: 'Parent!orn_largura - Parent!orn_espessura_real/2',
            y: "#{setback_frontal_cm} + #{dist_furos_cm}", codigo: 'FAV_D2' },
        ].each do |pos|
          # Criar um marker vazio como wrapper (sem geometria de hardware)
          marker_def = Sketchup.active_model.definitions.add(
            "#{pos[:nome]}_#{Time.now.to_i}_#{rand(10000).to_s.rjust(4, '0')}"
          )
          marker_def.set_attribute('dynamic_attributes', 'orn_marcado', true)
          marker_def.set_attribute('dynamic_attributes', 'orn_tipo_peca', 'ferragem')
          marker_def.set_attribute('dynamic_attributes', 'orn_subtipo', 'avento_furo')
          marker_def.set_attribute('dynamic_attributes', 'orn_codigo', pos[:codigo])
          marker_def.set_attribute('dynamic_attributes', 'orn_nome', pos[:nome])
          marker_def.set_attribute('dynamic_attributes', 'orn_na_lista_corte', false)
          marker_def.set_attribute('dynamic_attributes', 'orn_ferragem', true)
          marker_def.set_attribute('dynamic_attributes', '_has_behaviors', true)

          # Posicao parametrica
          marker_def.set_attribute('dynamic_attributes', '_inst__x_formula', pos[:x])
          marker_def.set_attribute('dynamic_attributes', '_inst__y_formula', pos[:y])
          marker_def.set_attribute('dynamic_attributes', '_inst__z_formula',
                                   "Parent!orn_altura - #{setback_topo_cm}")

          inst = parent_def.entities.add_instance(marker_def, ORIGIN)
          inst.name = pos[:nome]
          instances << inst
        end

        instances
      end

      private

      # ================================================================
      # Helpers de Puxador
      # ================================================================

      # Embutir uma instancia de puxador (wrapper) com posicao parametrica.
      def self.embutir_instancia_puxador(parent_def, pux_def, nome,
                                          x:, y:, z:, modelo:, tipo:, indice:)
        if pux_def
          # Tem .skp — criar wrapper com ferragem visual
          criar_wrapper_ferragem(
            parent_def, pux_def, nome,
            tipo_ferragem: 'puxador',
            codigo: "PUX_#{indice}",
            formulas: { x: x, y: y, z: z },
            extras: {
              orn_tipo_puxador: tipo,
              orn_modelo_puxador: modelo,
            }
          )
        else
          # Sem .skp — criar marcador de furo para CNC
          criar_marcador_puxador(parent_def, nome,
            tipo: :furo, x: x, y: y, z: z,
            extras: { orn_tipo_puxador: tipo, orn_modelo_puxador: modelo })
        end
      end

      # Criar marcador de puxador (para CNC, quando nao ha .skp).
      def self.criar_marcador_puxador(parent_def, nome, tipo:, x:, y:, z:, extras: {})
        model = Sketchup.active_model
        marker_def = model.definitions.add(
          "#{nome}_#{Time.now.to_i}_#{rand(10000).to_s.rjust(4, '0')}"
        )

        dict = 'dynamic_attributes'
        marker_def.set_attribute(dict, 'orn_marcado', true)
        marker_def.set_attribute(dict, 'orn_tipo_peca', 'ferragem')
        marker_def.set_attribute(dict, 'orn_subtipo', "puxador_#{tipo}")
        marker_def.set_attribute(dict, 'orn_nome', nome)
        marker_def.set_attribute(dict, 'orn_na_lista_corte', false)
        marker_def.set_attribute(dict, 'orn_ferragem', true)
        marker_def.set_attribute(dict, '_has_behaviors', true)

        marker_def.set_attribute('ornato', 'orn_marcado', true)
        marker_def.set_attribute('ornato', 'orn_tipo_peca', 'ferragem')
        marker_def.set_attribute('ornato', 'orn_na_lista_corte', false)

        extras.each do |k, v|
          marker_def.set_attribute(dict, k.to_s, v)
          marker_def.set_attribute('ornato', k.to_s, v)
        end

        marker_def.set_attribute(dict, '_inst__x_formula', x)
        marker_def.set_attribute(dict, '_inst__y_formula', y)
        marker_def.set_attribute(dict, '_inst__z_formula', z)

        inst = parent_def.entities.add_instance(marker_def, ORIGIN)
        inst.name = nome
        inst
      end

      # Detectar lado da dobradica analisando sub-componentes existentes.
      def self.detectar_lado_dobradica(parent_def)
        parent_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          subtipo = entity.definition.get_attribute('dynamic_attributes', 'orn_subtipo')
          if subtipo == 'dobradica'
            codigo = entity.definition.get_attribute('dynamic_attributes', 'orn_codigo') || ''
            # Usar regex para detectar sufixo _D seguido de digito (ex: DOBR_D1)
            # .include?('D') dava falso positivo porque 'DOBR' contem 'D'
            return :direita if codigo =~ /_D\d/
            return :esquerda if codigo =~ /_E\d/
            # Fallback: verificar posicao X da instancia
            x_pos = entity.transformation.origin.x
            largura_modulo = parent_def.bounds.width
            return x_pos > (largura_modulo / 2.0) ? :direita : :esquerda
          end
        end
        :esquerda # default
      end

      # ================================================================
      # Carregar .skp como definition
      # ================================================================

      def self.carregar_definition(skp_path, nome_fallback = nil)
        model = Sketchup.active_model

        # Invalidar cache se mudou de modelo
        current_model_id = model.object_id
        if @@cache_model_id != current_model_id
          @@definitions_cache = {}
          @@cache_model_id = current_model_id
        end

        return @@definitions_cache[skp_path] if @@definitions_cache[skp_path]

        # Verificar se ja existe uma definition com este caminho
        existing = model.definitions.find { |d| d.path == skp_path }
        if existing
          @@definitions_cache[skp_path] = existing
          return existing
        end

        # Carregar do arquivo
        unless File.exist?(skp_path)
          puts "[Ornato::HardwareEmbedder] AVISO: SKP nao encontrado: #{skp_path}"
          return nil
        end

        begin
          defs = model.definitions.load(skp_path)
          @@definitions_cache[skp_path] = defs
          defs
        rescue => e
          puts "[Ornato::HardwareEmbedder] ERRO ao carregar #{skp_path}: #{e.message}"
          nil
        end
      end

      # ================================================================
      # Criar wrapper DC para ferragem
      # ================================================================
      # O wrapper e um ComponentDefinition intermediario que contem a
      # ferragem importada e permite posicionamento parametrico via
      # formulas DC. A ferragem em si nao e alterada.

      def self.criar_wrapper_ferragem(parent_def, hardware_def, nome,
                                       tipo_ferragem:, codigo:, formulas: {},
                                       extras: {})
        model = Sketchup.active_model
        dict = 'dynamic_attributes'

        # CRITICO: cada instancia de ferragem precisa de uma definition UNICA
        # para ter suas proprias formulas de posicao. Se compartilhassem a mesma
        # definition, a segunda dobradica sobrescreveria a posicao da primeira.
        # Sufixo unico evita colisao de nomes ao re-inserir ferragens.
        nome_unico = "#{nome}_#{Time.now.to_i}_#{rand(10000).to_s.rjust(4, '0')}"
        wrapper_def = model.definitions.add(nome_unico)

        # Inserir a ferragem original como sub-componente do wrapper
        wrapper_def.entities.add_instance(hardware_def, ORIGIN)

        # Marcar wrapper como ferragem Ornato (NAO vai para lista de corte)
        wrapper_def.set_attribute(dict, 'orn_marcado', true)
        wrapper_def.set_attribute(dict, 'orn_tipo_peca', 'ferragem')
        wrapper_def.set_attribute(dict, 'orn_subtipo', tipo_ferragem)
        wrapper_def.set_attribute(dict, 'orn_codigo', codigo)
        wrapper_def.set_attribute(dict, 'orn_nome', nome)
        wrapper_def.set_attribute(dict, 'orn_na_lista_corte', false)
        wrapper_def.set_attribute(dict, 'orn_ferragem', true)
        wrapper_def.set_attribute(dict, '_has_behaviors', true)

        # Marcar tambem no dicionario 'ornato' para compatibilidade com
        # OrnatoAttributes.peca_ornato? e coletar_pecas
        wrapper_def.set_attribute('ornato', 'orn_marcado', true)
        wrapper_def.set_attribute('ornato', 'orn_tipo_peca', 'ferragem')
        wrapper_def.set_attribute('ornato', 'orn_na_lista_corte', false)

        # Atributos extras (tipo_dobradica, modelo, etc.)
        extras.each do |k, v|
          wrapper_def.set_attribute(dict, k.to_s, v)
          wrapper_def.set_attribute('ornato', k.to_s, v)
        end

        # Aplicar formulas de posicionamento na definition unica do wrapper
        if formulas[:x]
          wrapper_def.set_attribute(dict, '_inst__x_formula', formulas[:x])
        end
        if formulas[:y]
          wrapper_def.set_attribute(dict, '_inst__y_formula', formulas[:y])
        end
        if formulas[:z]
          wrapper_def.set_attribute(dict, '_inst__z_formula', formulas[:z])
        end

        # Hidden (parametrico — controla visibilidade por altura da porta)
        if formulas[:hidden]
          wrapper_def.set_attribute(dict, '_inst__hidden_formula', formulas[:hidden])
          wrapper_def.set_attribute(dict, 'hidden', formulas[:hidden])
        end

        # Rotacao (se especificada)
        if formulas[:rotx]
          wrapper_def.set_attribute(dict, '_inst__rotx_formula', formulas[:rotx])
        end
        if formulas[:roty]
          wrapper_def.set_attribute(dict, '_inst__roty_formula', formulas[:roty])
        end
        if formulas[:rotz]
          wrapper_def.set_attribute(dict, '_inst__rotz_formula', formulas[:rotz])
        end

        # Inserir o wrapper no parent
        instance = parent_def.entities.add_instance(wrapper_def, ORIGIN)
        instance.name = nome
        instance
      end

      # ================================================================
      # Formulas de posicionamento
      # ================================================================

      # Formula Z agora delegada para GlobalConfig.formula_z_dobradica
      # (mantido como alias para compatibilidade com codigo existente)
      def self.formula_z_dobradica(indice, quantidade)
        GlobalConfig.formula_z_dobradica(indice, quantidade)
      end

      # Formula Z para corredica da gaveta N de Q total.
      # Posiciona no centro da altura da gaveta correspondente.
      # Leva em conta a zona de rodape (orn_altura_rodape) para modulos inferiores.
      # Espaco util = altura - rodape - base - topo
      def self.formula_z_corredica(indice, total)
        # Z = rodape + base + (espaco_util / total) * indice + (espaco_util / total) / 2
        # espaco_util = altura - rodape/10 - 2*espessura_real
        "Parent!orn_altura_rodape/10 + Parent!orn_espessura_real + " \
        "((Parent!orn_altura - Parent!orn_altura_rodape/10 - 2*Parent!orn_espessura_real) / #{total}) * #{indice} + " \
        "((Parent!orn_altura - Parent!orn_altura_rodape/10 - 2*Parent!orn_espessura_real) / #{total}) / 2"
      end

      # ================================================================
      # Trilho para portas de correr
      # ================================================================

      # Embutir trilho superior e inferior para portas de correr.
      # Trilhos sao componentes lineares que percorrem a largura do modulo.
      #
      # @param parent_def [Sketchup::ComponentDefinition] definition do modulo
      # @param quantidade [Integer] quantidade de portas (define quantas trilhas)
      def self.embutir_trilho_correr(parent_def, quantidade: 2)
        model = Sketchup.active_model

        # Trilho superior
        trilho_sup_nome = "Trilho Sup Correr"
        trilho_sup_def = model.definitions.add(trilho_sup_nome)
        criar_geometria_placeholder(trilho_sup_def, 50.cm, 1.5.cm, 1.0.cm)

        formulas_sup = {
          lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real',
          leny: '1.5',   # 15mm profundidade do trilho
          lenz: '1.0',   # 10mm altura do trilho
          x: 'Parent!orn_espessura_real',
          y: 'Parent!orn_profundidade - 2.0',  # 20mm da frente
          z: 'Parent!orn_altura - Parent!orn_espessura_real - 1.0',
        }

        configurar_ferragem_dc(trilho_sup_def, {
          orn_marcado: true,
          orn_tipo_peca: 'ferragem',
          orn_subtipo: 'trilho_superior',
          orn_codigo: 'TRILHO_SUP',
          orn_nome: trilho_sup_nome,
          orn_na_lista_corte: false,
        }, formulas_sup)

        parent_def.entities.add_instance(trilho_sup_def, ORIGIN)

        # Trilho inferior
        trilho_inf_nome = "Trilho Inf Correr"
        trilho_inf_def = model.definitions.add(trilho_inf_nome)
        criar_geometria_placeholder(trilho_inf_def, 50.cm, 1.5.cm, 0.5.cm)

        formulas_inf = {
          lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real',
          leny: '1.5',
          lenz: '0.5',   # 5mm guia inferior
          x: 'Parent!orn_espessura_real',
          y: 'Parent!orn_profundidade - 2.0',
          z: 'Parent!orn_altura_rodape/10 + Parent!orn_espessura_real',
        }

        configurar_ferragem_dc(trilho_inf_def, {
          orn_marcado: true,
          orn_tipo_peca: 'ferragem',
          orn_subtipo: 'trilho_inferior',
          orn_codigo: 'TRILHO_INF',
          orn_nome: trilho_inf_nome,
          orn_na_lista_corte: false,
        }, formulas_inf)

        parent_def.entities.add_instance(trilho_inf_def, ORIGIN)
      end

      # Criar geometria placeholder simples (sem BoxBuilder dependency)
      def self.criar_geometria_placeholder(definition, w, d, h)
        pts = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(w, 0, 0),
          Geom::Point3d.new(w, d, 0),
          Geom::Point3d.new(0, d, 0)
        ]
        face = definition.entities.add_face(pts)
        face.pushpull(h) if face
      end

      # Configurar ferragem DC (wrapper simplificado)
      def self.configurar_ferragem_dc(definition, attrs, formulas)
        dc_dict = 'dynamic_attributes'
        attrs.each do |key, value|
          definition.set_attribute(dc_dict, key.to_s, value)
        end

        formulas.each do |key, formula|
          case key
          when :lenx then definition.set_attribute(dc_dict, '_lenx_formula', formula)
          when :leny then definition.set_attribute(dc_dict, '_leny_formula', formula)
          when :lenz then definition.set_attribute(dc_dict, '_lenz_formula', formula)
          when :x then definition.set_attribute(dc_dict, '_inst__x_formula', formula)
          when :y then definition.set_attribute(dc_dict, '_inst__y_formula', formula)
          when :z then definition.set_attribute(dc_dict, '_inst__z_formula', formula)
          end
        end

        definition.set_attribute(dc_dict, '_has_behaviors', true)
      end

      # Limpar cache (para recarregar .skp atualizados)
      def self.limpar_cache
        @@definitions_cache = {}
      end
    end
  end
end
