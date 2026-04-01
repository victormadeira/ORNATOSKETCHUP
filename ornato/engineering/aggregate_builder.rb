# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/aggregate_builder.rb — Construtor de agregados parametricos
#
# Agregados sao elementos que preenchem os vaos de um modulo:
#   - Portas (abrir, correr, basculante)
#   - Gavetas (simples, tandembox, caixa interna)
#   - Prateleiras (fixa, regulavel)
#   - Divisorias internas
#   - Nichos / fechamentos
#
# Cada agregado e inserido dentro do modulo como sub-componente DC
# com formulas que referenciam Parent! para se adaptar ao vao disponivel.
#
# FERRAGENS EMBUTIDAS:
#   Ao criar portas, gavetas ou prateleiras regulaveis, o builder
#   automaticamente embutir as ferragens correspondentes (.skp) como
#   sub-componentes do modulo — da mesma forma que o WPS faz:
#   - Porta → dobradicas (HardwareEmbedder.embutir_dobradicas)
#   - Gaveta → corredicas (HardwareEmbedder.embutir_corredicas)
#   - Prateleira regulavel → suportes/pinos (HardwareEmbedder.embutir_suportes_prateleira)
#   - Juntas estruturais → minifix/cavilha (via BoxBuilder)
#
# FLUXO:
#   1. Modulo ja criado pelo BoxBuilder
#   2. AggregateBuilder.adicionar_porta(modulo, lado: :esquerda)
#   3. Cria porta como DC parametrico dentro do modulo
#   4. Porta se redimensiona automaticamente ao vao
#   5. Embutir dobradicas como sub-componentes na lateral correspondente
#
# CALCULO DE VAOS:
#   Vao interno = Altura_modulo - Base - Topo (se nao passantes)
#   Vao largura = Largura_modulo - 2*Espessura_corpo
#   Porta = Vao + Sobreposicao - Folga (tipico: vao + 2*sobreposicao_lateral)

module Ornato
  module Engineering
    class AggregateBuilder

      # ================================================================
      # Formulas para porta (abrir)
      # ================================================================
      # UNIDADES NAS FORMULAS:
      #   orn_largura/altura/profundidade = cm (SketchUp DC interno)
      #   orn_folga_porta = mm (2.0 = 2mm)
      #   orn_espessura_porta = mm (18.0 = 18mm)
      #   /10 converte mm → cm para DC. *10 converte cm → mm para corte.
      # ================================================================
      # PORTA_FORMULAS — Formulas DC parametricas para portas
      # ================================================================
      # Usam Parent!orn_sobreposicao_porta (mm) para ajustar dimensoes:
      #   - reta (0mm): porta = largura modulo (rente a face externa)
      #   - curva (-9mm): porta recua 9mm de cada lado (meio-esquadro)
      #   - supercurva (-18mm): porta totalmente interna ao vao
      #
      # orn_sobreposicao_porta e setado no modulo por criar_porta() com
      # o valor vindo de GlobalConfig.sobreposicao_porta().
      # Convencao: /10 converte mm→cm. sobreposicao ja esta em mm.
      #
      # Formulas Y (profundidade):
      #   - reta: porta na face frontal do modulo
      #   - curva: porta recuada metade da lateral
      #   - supercurva: porta alinhada com face interna da lateral
      # Usamos orn_sobreposicao_porta para deslocar Y tambem.
      PORTA_FORMULAS = {
        # Porta unica (cobre todo o vao)
        # Altura = modulo - rodape - 2*folga (porta nao cobre zona de rodape)
        # Z = rodape + folga (comeca acima do rodape)
        unica: {
          lenx: 'Parent!orn_largura + (Parent!orn_sobreposicao_porta*2/10)',
          leny: '(Parent!orn_espessura_porta/10)',
          lenz: 'Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)',
          x: '-(Parent!orn_sobreposicao_porta/10)',
          y: 'Parent!orn_profundidade + (Parent!orn_sobreposicao_porta/10)',
          z: 'Parent!orn_altura_rodape/10 + (Parent!orn_folga_porta/10)',
          corte_comp: '(Parent!orn_altura*10 - Parent!orn_altura_rodape) - (Parent!orn_folga_porta*2)',
          corte_larg: '(Parent!orn_largura*10) + (Parent!orn_sobreposicao_porta*2)',
        },

        # Porta esquerda (de 2 portas)
        esquerda: {
          lenx: '(Parent!orn_largura/2) + (Parent!orn_sobreposicao_porta/10) - (Parent!orn_folga_porta/(10*2))',
          leny: '(Parent!orn_espessura_porta/10)',
          lenz: 'Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)',
          x: '-(Parent!orn_sobreposicao_porta/10)',
          y: 'Parent!orn_profundidade + (Parent!orn_sobreposicao_porta/10)',
          z: 'Parent!orn_altura_rodape/10 + (Parent!orn_folga_porta/10)',
          corte_comp: '(Parent!orn_altura*10 - Parent!orn_altura_rodape) - (Parent!orn_folga_porta*2)',
          corte_larg: '(Parent!orn_largura*10/2) + Parent!orn_sobreposicao_porta - (Parent!orn_folga_porta/2)',
        },

        # Porta direita (de 2 portas)
        direita: {
          lenx: '(Parent!orn_largura/2) + (Parent!orn_sobreposicao_porta/10) - (Parent!orn_folga_porta/(10*2))',
          leny: '(Parent!orn_espessura_porta/10)',
          lenz: 'Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)',
          x: '(Parent!orn_largura/2) + (Parent!orn_folga_porta/(10*2))',
          y: 'Parent!orn_profundidade + (Parent!orn_sobreposicao_porta/10)',
          z: 'Parent!orn_altura_rodape/10 + (Parent!orn_folga_porta/10)',
          corte_comp: '(Parent!orn_altura*10 - Parent!orn_altura_rodape) - (Parent!orn_folga_porta*2)',
          corte_larg: '(Parent!orn_largura*10/2) + Parent!orn_sobreposicao_porta - (Parent!orn_folga_porta/2)',
        },

        # Porta esquerda (de 3 portas)
        esquerda_tripla: {
          lenx: '(Parent!orn_largura/3) + (Parent!orn_sobreposicao_porta/10) - (Parent!orn_folga_porta/(10*3))',
          leny: '(Parent!orn_espessura_porta/10)',
          lenz: 'Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)',
          x: '-(Parent!orn_sobreposicao_porta/10)',
          y: 'Parent!orn_profundidade + (Parent!orn_sobreposicao_porta/10)',
          z: 'Parent!orn_altura_rodape/10 + (Parent!orn_folga_porta/10)',
          corte_comp: '(Parent!orn_altura*10 - Parent!orn_altura_rodape) - (Parent!orn_folga_porta*2)',
          corte_larg: '(Parent!orn_largura*10/3) + Parent!orn_sobreposicao_porta - (Parent!orn_folga_porta/3)',
        },

        # Porta central (de 3 portas)
        centro: {
          lenx: '(Parent!orn_largura/3) - (Parent!orn_folga_porta*2/(10*3))',
          leny: '(Parent!orn_espessura_porta/10)',
          lenz: 'Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)',
          x: '(Parent!orn_largura/3) + (Parent!orn_folga_porta/(10*3))',
          y: 'Parent!orn_profundidade + (Parent!orn_sobreposicao_porta/10)',
          z: 'Parent!orn_altura_rodape/10 + (Parent!orn_folga_porta/10)',
          corte_comp: '(Parent!orn_altura*10 - Parent!orn_altura_rodape) - (Parent!orn_folga_porta*2)',
          corte_larg: '(Parent!orn_largura*10/3) - (Parent!orn_folga_porta*2/3)',
        },

        # Porta direita (de 3 portas)
        direita_tripla: {
          lenx: '(Parent!orn_largura/3) + (Parent!orn_sobreposicao_porta/10) - (Parent!orn_folga_porta/(10*3))',
          leny: '(Parent!orn_espessura_porta/10)',
          lenz: 'Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)',
          x: '(Parent!orn_largura*2/3) + (Parent!orn_folga_porta/(10*3))',
          y: 'Parent!orn_profundidade + (Parent!orn_sobreposicao_porta/10)',
          z: 'Parent!orn_altura_rodape/10 + (Parent!orn_folga_porta/10)',
          corte_comp: '(Parent!orn_altura*10 - Parent!orn_altura_rodape) - (Parent!orn_folga_porta*2)',
          corte_larg: '(Parent!orn_largura*10/3) + Parent!orn_sobreposicao_porta - (Parent!orn_folga_porta/3)',
        },
      }.freeze

      # ================================================================
      # Formulas para gaveta
      # ================================================================
      # NOTA: Formulas de gaveta usam orn_altura_gaveta como atributo PROPRIO
      # da frente (nao Parent!). Este valor e setado em criar_gaveta() como formula.
      GAVETA_FORMULAS = {
        # Frente da gaveta (visivel)
        frente: {
          lenx: 'Parent!orn_largura',
          leny: 'Parent!orn_espessura_porta/10',
          # lenz e z sao override em criar_gaveta() com formulas parametricas
          x: '0',
          y: 'Parent!orn_profundidade',
          corte_comp: 'Parent!orn_largura*10',
        },

        # Lateral da gaveta (par — 15mm espessura)
        # Profundidade = prof_modulo - frente - folga_traseira (5cm = 50mm)
        # Espessura = 1.5cm (15mm → 15.5mm real)
        # Altura = altura_frente - recuo - espessura_fundo(6mm)
        lateral: {
          lenx: '1.5',                                     # 15mm fixo
          leny: 'Parent!orn_profundidade - 5.0',           # prof modulo - 50mm folga traseira
          # lenz e z sao override em criar_gaveta() com formulas parametricas
          corte_comp: '(Parent!orn_profundidade - 5.0)*10',
          corte_larg: nil,  # override per-gaveta
        },

        # Traseira da gaveta
        # Largura = largura interna da caixa gaveta (entre as 2 laterais de 15mm)
        # = largura_modulo - 2*esp_corpo - 2*folga_corredica(12.5mm) - 2*esp_lateral_gaveta(15mm)
        traseira: {
          lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real - 2*1.25 - 2*1.5',
          leny: '1.5',                                     # 15mm
          # lenz e z sao override per-gaveta
          corte_comp: '(Parent!orn_largura - 2*Parent!orn_espessura_real - 2*1.25 - 2*1.5)*10',
          corte_larg: nil,  # override per-gaveta
        },

        # Fundo da gaveta (HDF 6mm)
        # Encaixado em rasgo nas laterais e traseira
        # Largura = entre laterais + 2*entrada_rasgo(8mm)
        # Profundidade = prof_lateral + entrada_rasgo_traseira(8mm)
        fundo: {
          lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real - 2*1.25 - 2*1.5 + 2*0.8',
          leny: 'Parent!orn_profundidade - 5.0 + 0.8',
          lenz: '0.6',                                     # 6mm HDF
          corte_comp: '(Parent!orn_largura - 2*Parent!orn_espessura_real - 2*1.25 - 2*1.5 + 2*0.8)*10',
          corte_larg: '(Parent!orn_profundidade - 5.0 + 0.8)*10',
        }
      }.freeze

      # ================================================================
      # Interface publica
      # ================================================================

      # Adiciona uma porta ao modulo.
      #
      # @param modulo [Sketchup::ComponentInstance] modulo criado pelo BoxBuilder
      # @param tipo [Symbol] :unica, :esquerda, :direita, :dupla
      # @param espessura [Float] espessura em mm (default: 18)
      # @param material [String, nil] material (herda do modulo se nil)
      # @return [Sketchup::ComponentInstance] instancia da porta
      def self.adicionar_porta(modulo, tipo: :unica, espessura: 18.0, material: nil,
                               modelo_dobradica: nil, tipo_modulo: nil,
                               tipo_dobradica: nil)
        model = Sketchup.active_model
        model.start_operation("Adicionar Porta #{tipo}", true)

        begin
          parent_def = modulo.definition

          # Detectar tipo do modulo para selecao de dobradica
          tipo_mod = tipo_modulo || detectar_tipo_modulo(modulo)

          # Resolver tipo de dobradica (reta/curva/supercurva)
          tipo_dob = tipo_dobradica || GlobalConfig.tipo_dobradica(modulo: modulo)

          # Setar orn_sobreposicao_porta no modulo DC para que as formulas
          # da porta usem o valor correto. Valor em mm.
          sobreposicao = GlobalConfig.sobreposicao_porta(modulo: modulo)
          parent_def.set_attribute('dynamic_attributes', 'orn_sobreposicao_porta', sobreposicao)
          parent_def.set_attribute('dynamic_attributes', 'orn_tipo_dobradica', tipo_dob.to_s)

          # Ajustar folga se supercurva (porta embutida precisa mais folga)
          if tipo_dob == :supercurva
            folga_efetiva = GlobalConfig.folga_porta(modulo: modulo)
            parent_def.set_attribute('dynamic_attributes', 'orn_folga_porta', folga_efetiva)
          end

          # Selecionar modelo de dobradica correto pelo tipo de braco
          modelo_dob = modelo_dobradica || GlobalConfig.modelo_dobradica_por_tipo(tipo_dob, tipo_modulo: tipo_mod)

          if tipo == :dupla
            criar_porta(parent_def, :esquerda, espessura, material)
            instance = criar_porta(parent_def, :direita, espessura, material)

            embutir_dobradicas_porta(parent_def, :esquerda, espessura,
                                     modelo_dob, tipo_mod)
            embutir_dobradicas_porta(parent_def, :direita, espessura,
                                     modelo_dob, tipo_mod)

          elsif tipo == :tripla
            criar_porta(parent_def, :esquerda_tripla, espessura, material)
            criar_porta(parent_def, :centro, espessura, material)
            instance = criar_porta(parent_def, :direita_tripla, espessura, material)

            embutir_dobradicas_porta(parent_def, :esquerda_tripla, espessura,
                                     modelo_dob, tipo_mod)
            embutir_dobradicas_porta(parent_def, :centro, espessura,
                                     modelo_dob, tipo_mod)
            embutir_dobradicas_porta(parent_def, :direita_tripla, espessura,
                                     modelo_dob, tipo_mod)
          else
            instance = criar_porta(parent_def, tipo, espessura, material)

            # Embutir dobradicas
            embutir_dobradicas_porta(parent_def, tipo, espessura,
                                     modelo_dob, tipo_mod)
          end

          # Recalcular DC
          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation
          instance

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # Adiciona gavetas ao modulo.
      #
      # @param modulo [Sketchup::ComponentInstance]
      # @param quantidade [Integer] numero de gavetas
      # @param altura_frente [Float, nil] altura da frente em mm (auto se nil)
      # @return [Array<Sketchup::ComponentInstance>]
      def self.adicionar_gavetas(modulo, quantidade: 3, altura_frente: nil,
                                modelo_corredica: nil, tipo_modulo: nil)
        model = Sketchup.active_model
        model.start_operation("Adicionar #{quantidade} Gavetas", true)

        begin
          parent_def = modulo.definition
          instances = []

          # Detectar tipo do modulo para selecao de corredica
          tipo_mod = tipo_modulo || detectar_tipo_modulo(modulo)

          # Selecionar modelo de corredica
          modelo_corr = modelo_corredica || selecionar_modelo_corredica(tipo_mod)

          quantidade.times do |i|
            instances << criar_gaveta(parent_def, i, quantidade, altura_frente)

            # Embutir par de corredicas para cada gaveta
            HardwareEmbedder.embutir_corredicas(
              parent_def,
              gaveta_indice: i,
              total_gavetas: quantidade,
              modelo: modelo_corr
            )
          end

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation
          instances

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # Adiciona prateleira regulavel ao modulo.
      #
      # @param modulo [Sketchup::ComponentInstance]
      # @param posicao_z_pct [Float] posicao vertical em % (0.0 a 1.0)
      # @param recuo [Float] recuo da frente em mm
      # @return [Sketchup::ComponentInstance]
      # Adiciona prateleira ao modulo.
      # @param vao [Integer, nil] indice do vao (0=esquerda, 1=centro, ...).
      #   Se nil, prateleira cobre toda a largura interna.
      #   Vao e definido pelas divisorias existentes no modulo.
      def self.adicionar_prateleira(modulo, posicao_z_pct: 0.5, recuo: 0.0, vao: nil)
        model = Sketchup.active_model
        model.start_operation('Adicionar Prateleira', true)

        begin
          parent_def = modulo.definition

          nome = vao ? "Prateleira Vao #{vao}" : "Prateleira Regulavel"
          nome_unico = "#{nome}_#{Time.now.to_i}_#{rand(10000).to_s.rjust(4, '0')}"
          prat_def = model.definitions.add(nome_unico)

          # Geometria placeholder
          criar_geometria_caixa(prat_def, 50.cm, 55.cm, 1.85.cm)

          # Posicao Z calculada
          z_formula = "Parent!orn_espessura_real + " \
                      "(Parent!orn_altura - 2*Parent!orn_espessura_real) * #{posicao_z_pct}"

          # Calcular formulas por vao (bay) se divisorias existem
          vao_formulas = calcular_formulas_vao(parent_def, vao)

          # Profundidade: descontar fundo + recuo manual
          tipo_fundo = parent_def.get_attribute('dynamic_attributes', 'orn_tipo_fundo')
          recuo_cm = recuo / 10.0
          if tipo_fundo && tipo_fundo.to_s != 'sem'
            leny_prat = "Parent!orn_profundidade - Parent!orn_espessura_fundo - #{recuo_cm}"
            corte_larg_prat = "(Parent!orn_profundidade - Parent!orn_espessura_fundo - #{recuo_cm})*10"
          else
            leny_prat = "Parent!orn_profundidade - #{recuo_cm}"
            corte_larg_prat = "(Parent!orn_profundidade - #{recuo_cm})*10"
          end

          formulas = {
            lenx: vao_formulas[:lenx],
            leny: leny_prat,
            lenz: 'Parent!orn_espessura_real',
            x: vao_formulas[:x],
            y: '0',
            z: z_formula,
            corte_comp: vao_formulas[:corte_comp],
            corte_larg: corte_larg_prat,
          }

          BoxBuilder.send(:configurar_peca_dc, prat_def, {
            orn_marcado: true,
            orn_tipo_peca: 'prateleira',
            orn_subtipo: 'regulavel',
            orn_codigo: 'PRAT_REG',
            orn_nome: nome,
            orn_na_lista_corte: true,
            orn_grao: 'comprimento',
            orn_borda_frontal: true,
            orn_face_visivel: 'face_a',
          }, formulas)

          instance = parent_def.entities.add_instance(prat_def, ORIGIN)

          # Embutir 4 suportes/pinos para prateleira regulavel
          HardwareEmbedder.embutir_suportes_prateleira(
            parent_def,
            posicao_z_pct: posicao_z_pct
          )

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation
          instance

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # Adiciona porta basculante (avento) ao modulo.
      # A porta basculante e uma porta que abre para cima, articulada no topo.
      # Usada em aereos com avento (Blum Aventos HF/HL/HK, Grass Kinvaro).
      #
      # @param modulo [Sketchup::ComponentInstance]
      # @param espessura [Float] espessura em mm (default: 18)
      # @param material [String, nil]
      # @return [Sketchup::ComponentInstance]
      def self.adicionar_basculante(modulo, espessura: 18.0, material: nil)
        model = Sketchup.active_model
        model.start_operation('Adicionar Basculante', true)

        begin
          parent_def = modulo.definition

          nome = "Porta Basculante"
          nome_unico = "#{nome}_#{Time.now.to_i}_#{rand(10000).to_s.rjust(4, '0')}"
          basc_def = model.definitions.add(nome_unico)

          criar_geometria_caixa(basc_def, 50.cm, (espessura / 10.0).cm, 72.cm)

          # Basculante: cobre toda a frente do modulo (como porta unica)
          # Usa orn_sobreposicao_porta se definido, caso contrario 0 (rente)
          # Basculante: porta abre para cima, altura nao desconta rodape
          # (basculante e usado em aereos que nao tem rodape)
          # corte_comp = MAX(largura, altura), corte_larg = MIN(largura, altura)
          # Para basculante, largura e geralmente maior que altura
          formulas = {
            lenx: 'Parent!orn_largura + (Parent!orn_sobreposicao_porta*2/10)',
            leny: '(Parent!orn_espessura_porta/10)',
            lenz: 'Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)',
            x: '-(Parent!orn_sobreposicao_porta/10)',
            y: 'Parent!orn_profundidade + (Parent!orn_sobreposicao_porta/10)',
            z: 'Parent!orn_altura_rodape/10 + (Parent!orn_folga_porta/10)',
            # comp = largura (tipicamente maior em basculante)
            corte_comp: '(Parent!orn_largura*10) + (Parent!orn_sobreposicao_porta*2)',
            # larg = altura
            corte_larg: '(Parent!orn_altura*10 - Parent!orn_altura_rodape) - (Parent!orn_folga_porta*2)',
          }

          BoxBuilder.send(:configurar_peca_dc, basc_def, {
            orn_marcado: true,
            orn_tipo_peca: 'porta',
            orn_subtipo: 'basculante',
            orn_codigo: 'POR_BASC',
            orn_nome: nome,
            orn_na_lista_corte: true,
            orn_grao: 'comprimento',
            orn_borda_frontal: true,
            orn_borda_traseira: true,
            orn_borda_esquerda: true,
            orn_borda_direita: true,
            orn_face_visivel: 'face_a',
            orn_material: material,
          }, formulas)

          instance = parent_def.entities.add_instance(basc_def, ORIGIN)

          # Embutir mecanismo de avento (par esquerda/direita nas laterais)
          HardwareEmbedder.embutir_aventos(parent_def)

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation
          instance

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # Adiciona divisoria interna ao modulo.
      #
      # @param modulo [Sketchup::ComponentInstance]
      # @param posicao_x_pct [Float] posicao horizontal em % (0.0 a 1.0)
      # @return [Sketchup::ComponentInstance]
      def self.adicionar_divisoria(modulo, posicao_x_pct: 0.5)
        model = Sketchup.active_model
        model.start_operation('Adicionar Divisoria', true)

        begin
          parent_def = modulo.definition

          nome = "Divisoria"
          nome_unico = "#{nome}_#{Time.now.to_i}_#{rand(10000).to_s.rjust(4, '0')}"
          div_def = model.definitions.add(nome_unico)

          criar_geometria_caixa(div_def, 1.85.cm, 55.cm, 72.cm)

          x_formula = "Parent!orn_espessura_real + " \
                      "(Parent!orn_largura - 2*Parent!orn_espessura_real) * #{posicao_x_pct} - " \
                      "Parent!orn_espessura_real/2"

          # Profundidade da divisoria: descontar fundo se existir
          tipo_fundo = parent_def.get_attribute('dynamic_attributes', 'orn_tipo_fundo')
          if tipo_fundo && tipo_fundo.to_s != 'sem'
            leny_f = 'Parent!orn_profundidade - Parent!orn_espessura_fundo'
            corte_larg_f = '(Parent!orn_profundidade - Parent!orn_espessura_fundo)*10'
          else
            leny_f = 'Parent!orn_profundidade'
            corte_larg_f = 'Parent!orn_profundidade*10'
          end

          formulas = {
            lenx: 'Parent!orn_espessura_real',
            leny: leny_f,
            lenz: 'Parent!orn_altura - 2*Parent!orn_espessura_real',
            x: x_formula,
            y: '0',
            z: 'Parent!orn_espessura_real',
            corte_comp: '(Parent!orn_altura - 2*Parent!orn_espessura_real)*10',
            corte_larg: corte_larg_f,
          }

          BoxBuilder.send(:configurar_peca_dc, div_def, {
            orn_marcado: true,
            orn_tipo_peca: 'divisoria',
            orn_codigo: 'DIV',
            orn_nome: nome,
            orn_na_lista_corte: true,
            orn_grao: 'comprimento',
            orn_borda_frontal: true,
            orn_face_visivel: 'face_a',
          }, formulas)

          instance = parent_def.entities.add_instance(div_def, ORIGIN)

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation
          instance

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # ================================================================
      # Porta de correr (sliding door)
      # ================================================================
      # Portas de correr para roupeiros e armarios.
      # Cada porta = metade da largura + sobreposicao (overlap 20-30mm).
      # Hardware: trilho superior + trilho inferior + rodizios.
      # Nao usa dobradicas — trilhos e rolamentos.
      #
      # @param modulo [Sketchup::ComponentInstance]
      # @param quantidade [Integer] 2 ou 3 portas (2 e o padrao)
      # @param espessura [Float] espessura em mm
      # @param overlap [Float] sobreposicao entre portas em mm
      # @param material [String, nil]
      # @return [Array<Sketchup::ComponentInstance>]
      def self.adicionar_portas_correr(modulo, quantidade: 2, espessura: 18.0,
                                        overlap: 25.0, material: nil)
        model = Sketchup.active_model
        model.start_operation("Adicionar #{quantidade} Portas de Correr", true)

        begin
          parent_def = modulo.definition

          # Setar atributos para portas de correr no modulo
          parent_def.set_attribute('dynamic_attributes', 'orn_tipo_porta', 'correr')
          parent_def.set_attribute('dynamic_attributes', 'orn_qtd_portas_correr', quantidade)
          parent_def.set_attribute('dynamic_attributes', 'orn_overlap_porta_correr', overlap)

          instances = []
          overlap_cm = overlap / 10.0

          quantidade.times do |i|
            nome = "Porta Correr #{i + 1}"
            nome_unico = "#{nome}_#{Time.now.to_i}_#{rand(10000).to_s.rjust(4, '0')}"
            porta_def = model.definitions.add(nome_unico)

            criar_geometria_caixa(porta_def, 50.cm, (espessura / 10.0).cm, 72.cm)

            # Largura de cada porta = (largura_modulo + (qty-1)*overlap) / qty
            # Para 2 portas: cada uma = (L + overlap) / 2
            # Recuo Y para portas nas trilhas: porta_frente na trilha frontal, porta_tras na traseira
            y_offset_cm = i * (espessura / 10.0 + 0.2)  # 2mm gap entre trilhas

            formulas = {
              # Largura: (largura + (qty-1)*overlap) / qty
              lenx: "(Parent!orn_largura + #{(quantidade - 1) * overlap_cm}) / #{quantidade}",
              leny: "(#{espessura / 10.0})",
              # Altura = modulo - rodape - folga superior(5mm) - folga inferior(5mm)
              lenz: "Parent!orn_altura - Parent!orn_altura_rodape/10 - 1.0",
              # X: porta 0 começa no inicio, porta 1 deslocada
              x: "((Parent!orn_largura + #{(quantidade - 1) * overlap_cm}) / #{quantidade} - #{overlap_cm}) * #{i}",
              # Y: trilhas separadas por espessura + gap
              y: "Parent!orn_profundidade - #{y_offset_cm}",
              # Z: acima do rodape + folga inferior
              z: "Parent!orn_altura_rodape/10 + 0.5",
              corte_comp: "((Parent!orn_altura*10 - Parent!orn_altura_rodape) - 10)",
              corte_larg: "((Parent!orn_largura*10 + #{(quantidade - 1) * overlap}) / #{quantidade})",
            }

            BoxBuilder.send(:configurar_peca_dc, porta_def, {
              orn_marcado: true,
              orn_tipo_peca: 'porta',
              orn_subtipo: 'correr',
              orn_codigo: "POR_COR_#{i + 1}",
              orn_nome: nome,
              orn_na_lista_corte: true,
              orn_grao: 'comprimento',
              orn_borda_frontal: true,
              orn_borda_traseira: true,
              orn_borda_esquerda: true,
              orn_borda_direita: true,
              orn_face_visivel: 'face_a',
              orn_material: material,
            }, formulas)

            instances << parent_def.entities.add_instance(porta_def, ORIGIN)
          end

          # Embutir trilhos (superior e inferior) como ferragens
          HardwareEmbedder.embutir_trilho_correr(parent_def, quantidade: quantidade) rescue nil

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation
          instances

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # ================================================================
      # Puxador — adiciona puxador a uma porta ou frente de gaveta
      # ================================================================
      # Suporta todos os entre-furos System 32 (32, 64, 128, 192, 256...736mm).
      # Tipos: :barra (2 furos), :botao (1 furo), :cava (fresada), :concha.
      #
      # Posicionamento automatico:
      #   - Porta: lado oposto a dobradica, setback configuravel
      #   - Gaveta: centralizado horizontalmente, setback do topo
      #   - Orientacao: vertical (porta) ou horizontal (gaveta)
      #
      # @param modulo [Sketchup::ComponentInstance] modulo com porta/gaveta
      # @param alvo [Symbol] :porta, :gaveta — onde vai o puxador
      # @param modelo [String, nil] modelo resolver (ex: 'PUX_BARRA_128')
      # @param entre_furos [Integer, nil] distancia entre furos em mm (System 32)
      # @param lado_porta [Symbol] :esquerda, :direita — lado do puxador na porta
      # @param orientacao [Symbol, nil] :vertical, :horizontal (nil = auto)
      # @param gaveta_indice [Integer] indice da gaveta (0-based), se alvo=:gaveta
      # @return [Sketchup::ComponentInstance, nil]
      def self.adicionar_puxador(modulo, alvo: :porta, modelo: nil,
                                  entre_furos: nil, lado_porta: nil,
                                  orientacao: nil, gaveta_indice: 0)
        model = Sketchup.active_model
        model.start_operation('Adicionar Puxador', true)

        begin
          parent_def = modulo.definition
          cfg = GlobalConfig.get(:puxador)

          # Resolver entre-furos
          ef_mm = entre_furos || cfg[:distancia_furos] || 128
          ef_cm = ef_mm / 10.0

          # Resolver orientacao
          orient = orientacao || (alvo == :gaveta ? :horizontal : cfg[:orientacao] || :vertical)

          # Resolver modelo do puxador
          modelo_pux = modelo || resolver_modelo_puxador(ef_mm)

          # Resolver posicao
          setback_v_cm = (cfg[:setback_borda_vertical] || 80.0) / 10.0    # mm -> cm
          setback_h_cm = (cfg[:setback_borda_horizontal] || 40.0) / 10.0  # mm -> cm

          # Embutir puxador como ferragem
          HardwareEmbedder.embutir_puxador(
            parent_def,
            alvo: alvo,
            modelo: modelo_pux,
            entre_furos_mm: ef_mm,
            orientacao: orient,
            lado_porta: lado_porta,
            setback_vertical_cm: setback_v_cm,
            setback_horizontal_cm: setback_h_cm,
            gaveta_indice: gaveta_indice
          )

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation

        rescue => e
          model.abort_operation
          raise e
        end
      end

      private

      # Resolver modelo de puxador pelo entre-furos
      def self.resolver_modelo_puxador(entre_furos_mm)
        case entre_furos_mm
        when 0 then 'PUX_BOTAO'
        when 128 then 'PUX_BARRA_128'
        when 160 then 'PUX_BARRA_160'
        when 192 then 'PUX_BARRA_192'
        when 256 then 'PUX_BARRA_256'
        when 320 then 'PUX_BARRA_320'
        when 480 then 'PUX_BARRA_480'
        when 736 then 'PUX_BARRA_736'
        else "PUX_BARRA_#{entre_furos_mm}"
        end
      end

      def self.criar_porta(parent_def, tipo, espessura, material)
        model = Sketchup.active_model
        nome = "Porta #{tipo.to_s.capitalize}"
        nome_unico = "#{nome}_#{Time.now.to_i}_#{rand(10000).to_s.rjust(4, '0')}"
        porta_def = model.definitions.add(nome_unico)

        criar_geometria_caixa(porta_def, 50.cm, (espessura / 10.0).cm, 72.cm)

        formulas = PORTA_FORMULAS[tipo] || PORTA_FORMULAS[:unica]

        BoxBuilder.send(:configurar_peca_dc, porta_def, {
          orn_marcado: true,
          orn_tipo_peca: 'porta',
          orn_subtipo: tipo.to_s,
          orn_codigo: "POR_#{tipo.to_s.upcase[0..2]}",
          orn_nome: nome,
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
          orn_borda_traseira: true,
          orn_borda_esquerda: true,
          orn_borda_direita: true,
          orn_face_visivel: 'face_a',
          orn_material: material,
        }, formulas)

        parent_def.entities.add_instance(porta_def, ORIGIN)
      end

      # @param vao [Integer, nil] indice do vao (divisoria). nil = largura total.
      def self.criar_gaveta(parent_def, indice, total, altura_frente, vao: nil)
        model = Sketchup.active_model

        # ──────────────────────────────────────────────────────────
        # Formulas parametricas: tudo em termos de Parent! (modulo)
        # Unidades DC: cm. Atributos mm: orn_folga_porta, etc.
        #
        # Gaveta completa = 5 pecas:
        #   1. Frente (visivel, com borda)
        #   2. Lateral Esq (15mm MDF)
        #   3. Lateral Dir (15mm MDF)
        #   4. Traseira (15mm MDF)
        #   5. Fundo (6mm HDF, encaixado em rasgo)
        #
        # Dimensoes da caixa interna:
        #   folga_corredica = 12.5mm (cada lado) = 1.25cm
        #   esp_lateral_gaveta = 15mm = 1.5cm
        #   Largura caixa interna = largura_modulo - 2*esp_corpo - 2*folga_corredica
        #   Largura entre laterais = larg_caixa - 2*esp_lateral_gaveta
        #   Profundidade caixa = prof_modulo - 50mm (folga traseira)
        #   Altura caixa = altura_frente - 30mm (recuo superior/inferior)
        # ──────────────────────────────────────────────────────────

        # Calcular formulas por vao (bay-aware)
        vao_f = calcular_formulas_vao(parent_def, vao)

        # Altura da frente da gaveta (cm):
        # Vao util = altura - rodape - 2*folga (portas/gavetas nao cobrem rodape)
        lenz_frente = if altura_frente
          "#{altura_frente / 10.0}"
        else
          "((Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)) / #{total}) - (Parent!orn_folga_porta/10)"
        end

        # Posicao Z de cada frente (cm): comeca acima do rodape
        z_frente = "Parent!orn_altura_rodape/10 + (Parent!orn_folga_porta/10) + " \
                   "((Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)) / #{total}) * #{indice}"

        # Corte largura (mm) = altura_frente em mm
        corte_larg_frente = if altura_frente
          "#{altura_frente}"
        else
          "((Parent!orn_altura*10 - Parent!orn_altura_rodape - Parent!orn_folga_porta*2) / #{total}) - Parent!orn_folga_porta"
        end

        # Altura da caixa interna (cm) = altura_frente - 3.0cm (30mm recuo)
        # DEVE descontar rodape (mesma logica da frente)
        lenz_caixa = if altura_frente
          "#{(altura_frente - 30.0) / 10.0}"
        else
          "((Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)) / #{total}) - (Parent!orn_folga_porta/10) - 3.0"
        end

        # Corte largura caixa (mm) — tambem desconta rodape
        corte_larg_caixa = if altura_frente
          "#{altura_frente - 30.0}"
        else
          "((Parent!orn_altura*10 - Parent!orn_altura_rodape - Parent!orn_folga_porta*2) / #{total}) - Parent!orn_folga_porta - 30"
        end

        # Z base da caixa (cm) = z_frente + 1.5cm (15mm acima base da frente)
        z_caixa = "Parent!orn_altura_rodape/10 + (Parent!orn_folga_porta/10) + " \
                  "((Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)) / #{total}) * #{indice} + 1.5"

        # ── 1. FRENTE DA GAVETA ──────────────────────────────────
        nome_frente = "Frente Gaveta #{indice + 1}"
        frente_def = model.definitions.add(nome_frente)
        criar_geometria_caixa(frente_def, 50.cm, 1.85.cm, 20.cm)

        # Frente: largura do vao (se especificado)
        frente_formulas = GAVETA_FORMULAS[:frente].merge({
          z: z_frente,
          lenz: lenz_frente,
          corte_larg: corte_larg_frente,
        })
        if vao
          frente_formulas[:lenx] = vao_f[:lenx]
          frente_formulas[:x] = vao_f[:x]
          frente_formulas[:corte_comp] = vao_f[:corte_comp]
        end

        BoxBuilder.send(:configurar_peca_dc, frente_def, {
          orn_marcado: true,
          orn_tipo_peca: 'frente_gaveta',
          orn_codigo: "FRE_GAV_#{indice + 1}",
          orn_nome: nome_frente,
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
          orn_borda_traseira: true,
          orn_borda_esquerda: true,
          orn_borda_direita: true,
          orn_face_visivel: 'face_a',
        }, frente_formulas)

        parent_def.entities.add_instance(frente_def, ORIGIN)

        # ── 2. LATERAL ESQUERDA DA GAVETA ────────────────────────
        nome_lat_esq = "Lat Esq Gaveta #{indice + 1}"
        lat_esq_def = model.definitions.add(nome_lat_esq)
        criar_geometria_caixa(lat_esq_def, 1.5.cm, 40.cm, 12.cm)

        # X = inicio do vao + folga_corredica
        x_lat_esq = vao ? "(#{vao_f[:x]}) + 1.25" : 'Parent!orn_espessura_real + 1.25'
        y_lat = '0'

        lat_esq_formulas = {
          lenx: '1.5',
          leny: 'Parent!orn_profundidade - 5.0',
          lenz: lenz_caixa,
          x: x_lat_esq,
          y: y_lat,
          z: z_caixa,
          corte_comp: '(Parent!orn_profundidade - 5.0)*10',
          corte_larg: corte_larg_caixa,
        }

        BoxBuilder.send(:configurar_peca_dc, lat_esq_def, {
          orn_marcado: true,
          orn_tipo_peca: 'lateral_gaveta',
          orn_subtipo: 'esquerda',
          orn_codigo: "LAT_GAV_E_#{indice + 1}",
          orn_nome: nome_lat_esq,
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: false,
          orn_borda_traseira: false,
          orn_material: 'MDF 15mm Branco TX',
          orn_face_visivel: 'face_b',
        }, lat_esq_formulas)

        parent_def.entities.add_instance(lat_esq_def, ORIGIN)

        # ── 3. LATERAL DIREITA DA GAVETA ─────────────────────────
        nome_lat_dir = "Lat Dir Gaveta #{indice + 1}"
        lat_dir_def = model.definitions.add(nome_lat_dir)
        criar_geometria_caixa(lat_dir_def, 1.5.cm, 40.cm, 12.cm)

        # X = fim do vao - folga_corredica - esp_lateral_gaveta
        x_lat_dir = if vao
          "(#{vao_f[:x]}) + (#{vao_f[:lenx]}) - 1.25 - 1.5"
        else
          'Parent!orn_largura - Parent!orn_espessura_real - 1.25 - 1.5'
        end

        lat_dir_formulas = {
          lenx: '1.5',
          leny: 'Parent!orn_profundidade - 5.0',
          lenz: lenz_caixa,
          x: x_lat_dir,
          y: y_lat,
          z: z_caixa,
          corte_comp: '(Parent!orn_profundidade - 5.0)*10',
          corte_larg: corte_larg_caixa,
        }

        BoxBuilder.send(:configurar_peca_dc, lat_dir_def, {
          orn_marcado: true,
          orn_tipo_peca: 'lateral_gaveta',
          orn_subtipo: 'direita',
          orn_codigo: "LAT_GAV_D_#{indice + 1}",
          orn_nome: nome_lat_dir,
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: false,
          orn_borda_traseira: false,
          orn_material: 'MDF 15mm Branco TX',
          orn_face_visivel: 'face_b',
        }, lat_dir_formulas)

        parent_def.entities.add_instance(lat_dir_def, ORIGIN)

        # ── 4. TRASEIRA DA GAVETA ────────────────────────────────
        nome_tras = "Traseira Gaveta #{indice + 1}"
        tras_def = model.definitions.add(nome_tras)
        criar_geometria_caixa(tras_def, 30.cm, 1.5.cm, 12.cm)

        # X = inicio do vao + folga_corredica + esp_lateral_gaveta
        x_tras = vao ? "(#{vao_f[:x]}) + 1.25 + 1.5" : 'Parent!orn_espessura_real + 1.25 + 1.5'
        # Y = 0 (encostada na traseira)
        y_tras = '0'

        # Largura interna da gaveta (vao ou total)
        vao_lenx = vao ? vao_f[:lenx] : 'Parent!orn_largura - 2*Parent!orn_espessura_real'
        tras_lenx = "(#{vao_lenx}) - 2*1.25 - 2*1.5"

        tras_formulas = {
          lenx: tras_lenx,
          leny: '1.5',
          lenz: lenz_caixa,
          x: x_tras,
          y: y_tras,
          z: z_caixa,
          corte_comp: "(#{tras_lenx})*10",
          corte_larg: corte_larg_caixa,
        }

        BoxBuilder.send(:configurar_peca_dc, tras_def, {
          orn_marcado: true,
          orn_tipo_peca: 'traseira_gaveta',
          orn_codigo: "TRAS_GAV_#{indice + 1}",
          orn_nome: nome_tras,
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: false,
          orn_borda_traseira: false,
          orn_material: 'MDF 15mm Branco TX',
          orn_face_visivel: 'face_b',
        }, tras_formulas)

        parent_def.entities.add_instance(tras_def, ORIGIN)

        # ── 5. FUNDO DA GAVETA (HDF 6mm) ────────────────────────
        nome_fundo = "Fundo Gaveta #{indice + 1}"
        fundo_def = model.definitions.add(nome_fundo)
        criar_geometria_caixa(fundo_def, 30.cm, 40.cm, 0.6.cm)

        # X = inicio vao + folga_corredica + esp_lateral - entrada_rasgo(0.8cm)
        x_fundo = vao ? "(#{vao_f[:x]}) + 1.25 + 1.5 - 0.8" : 'Parent!orn_espessura_real + 1.25 + 1.5 - 0.8'
        y_fundo = '0'
        # Z = z_caixa (fundo na base da caixa, encaixado em rasgo a 5mm do fundo das laterais)

        fundo_lenx = "(#{vao_lenx}) - 2*1.25 - 2*1.5 + 2*0.8"

        fundo_formulas = {
          lenx: fundo_lenx,
          leny: 'Parent!orn_profundidade - 5.0 + 0.8',
          lenz: '0.6',
          x: x_fundo,
          y: y_fundo,
          z: z_caixa,
          corte_comp: "(#{fundo_lenx})*10",
          corte_larg: '(Parent!orn_profundidade - 5.0 + 0.8)*10',
        }

        BoxBuilder.send(:configurar_peca_dc, fundo_def, {
          orn_marcado: true,
          orn_tipo_peca: 'fundo_gaveta',
          orn_codigo: "FUNDO_GAV_#{indice + 1}",
          orn_nome: nome_fundo,
          orn_na_lista_corte: true,
          orn_grao: 'sem',
          orn_borda_frontal: false,
          orn_borda_traseira: false,
          orn_borda_esquerda: false,
          orn_borda_direita: false,
          orn_material: 'HDF 6mm',
          orn_face_visivel: 'face_b',
        }, fundo_formulas)

        parent_def.entities.add_instance(fundo_def, ORIGIN)
      end

      def self.criar_geometria_caixa(definition, w, d, h)
        pts = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(w, 0, 0),
          Geom::Point3d.new(w, d, 0),
          Geom::Point3d.new(0, d, 0)
        ]
        face = definition.entities.add_face(pts)
        face.pushpull(h) if face
      end

      # ================================================================
      # Helpers para embutir ferragens
      # ================================================================

      # Embutir dobradicas para uma porta especifica.
      # Quantidade agora e PARAMETRICA — HardwareEmbedder cria MAX slots
      # com Hidden formulas que se ajustam pela altura da porta.
      def self.embutir_dobradicas_porta(parent_def, porta_tipo, espessura,
                                         modelo_dobradica, tipo_modulo)
        # Selecionar modelo (soft-close padrao para superior, simples para inferior)
        modelo = modelo_dobradica || selecionar_modelo_dobradica(tipo_modulo)

        # Determinar lado das dobradicas
        lado = case porta_tipo
               when :esquerda then :esquerda
               when :direita then :direita
               when :unica then :esquerda
               else :esquerda
               end

        # Quantidade parametrica — HardwareEmbedder cria todos os slots
        # e usa Hidden formula para mostrar/esconder conforme altura
        HardwareEmbedder.embutir_dobradicas(
          parent_def,
          porta_tipo: porta_tipo,
          modelo: modelo,
          espessura_porta: espessura,
          lado: lado
        )
      end

      # Selecionar modelo de dobradica pelo tipo de modulo e tipo de braco.
      # Agora delega para GlobalConfig.modelo_dobradica_por_tipo.
      def self.selecionar_modelo_dobradica(tipo_modulo, tipo_dobradica = :reta)
        GlobalConfig.modelo_dobradica_por_tipo(tipo_dobradica, tipo_modulo: tipo_modulo)
      end

      # Selecionar modelo de corredica pelo tipo de modulo.
      def self.selecionar_modelo_corredica(tipo_modulo)
        case tipo_modulo
        when :superior then 'CORR_OCULTA_TANDEM'   # aereo: oculta
        when :torre then 'CORR_OCULTA_TANDEM'      # torre: oculta
        else 'CORR_TELESCOPICA'                     # default: telescopica
        end
      end

      # Detectar tipo do modulo a partir dos atributos DC.
      def self.detectar_tipo_modulo(modulo)
        dict = 'dynamic_attributes'
        tipo_str = modulo.definition.get_attribute(dict, 'orn_tipo_modulo')
        tipo_str ? tipo_str.to_sym : :inferior
      end

      # ================================================================
      # Sistema de Vaos (bays) — operacoes por compartimento
      # ================================================================
      # Detecta divisorias no modulo e calcula formulas de largura/posicao
      # para um vao especifico. Vao 0 = mais a esquerda.
      #
      # Retorna Hash com :lenx, :x, :corte_comp para usar em formulas DC.
      #
      # @param parent_def [Sketchup::ComponentDefinition]
      # @param vao [Integer, nil] indice do vao (nil = largura total)
      # @return [Hash] { lenx:, x:, corte_comp: }
      def self.calcular_formulas_vao(parent_def, vao)
        # Sem vao especificado: usar largura total
        if vao.nil?
          return {
            lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real',
            x: 'Parent!orn_espessura_real',
            corte_comp: '(Parent!orn_largura - 2*Parent!orn_espessura_real)*10',
          }
        end

        # Coletar posicoes das divisorias (porcentagens X)
        divisorias_pct = []
        parent_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          edef = entity.definition
          tipo = edef.get_attribute('dynamic_attributes', 'orn_tipo_peca')
          if tipo == 'divisoria'
            # Extrair posicao_x_pct da formula X da divisoria
            x_formula = edef.get_attribute('dynamic_attributes', '_inst__x_formula') || ''
            # Formula: "Parent!orn_espessura_real + (Parent!orn_largura - 2*Parent!orn_espessura_real) * PCT - Parent!orn_espessura_real/2"
            if x_formula =~ /\*\s*([\d.]+)\s*-/
              divisorias_pct << $1.to_f
            end
          end
        end
        divisorias_pct.sort!

        # Se nao ha divisorias, vao 0 = largura total
        if divisorias_pct.empty?
          return {
            lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real',
            x: 'Parent!orn_espessura_real',
            corte_comp: '(Parent!orn_largura - 2*Parent!orn_espessura_real)*10',
          }
        end

        # Calcular bordas do vao em porcentagem
        # vaos = [0..div0], [div0..div1], [div1..div2], ..., [divN..1]
        # ATENCAO: vao e 1-indexed (vao 1 = primeiro compartimento da esquerda)
        bordas = [0.0] + divisorias_pct + [1.0]
        vao_idx = [(vao || 1) - 1, bordas.length - 2].min  # 1-indexed → 0-indexed
        vao_idx = [vao_idx, 0].max  # nao pode ser negativo

        pct_inicio = bordas[vao_idx]
        pct_fim = bordas[vao_idx + 1]

        # Largura interna do modulo
        # li = Parent!orn_largura - 2*Parent!orn_espessura_real
        # Largura do vao = li * (pct_fim - pct_inicio) - orn_espessura_real
        # (desconta meia espessura de cada divisoria adjacente)
        delta_pct = pct_fim - pct_inicio

        # Deducao: meia espessura por divisoria adjacente (nao nas bordas externas)
        deducao_esq = pct_inicio > 0 ? 'Parent!orn_espessura_real/2' : '0'
        deducao_dir = pct_fim < 1.0 ? 'Parent!orn_espessura_real/2' : '0'

        lenx = "(Parent!orn_largura - 2*Parent!orn_espessura_real) * #{delta_pct.round(6)} - #{deducao_esq} - #{deducao_dir}"
        x = "Parent!orn_espessura_real + (Parent!orn_largura - 2*Parent!orn_espessura_real) * #{pct_inicio.round(6)} + #{deducao_esq}"
        corte = "((Parent!orn_largura - 2*Parent!orn_espessura_real) * #{delta_pct.round(6)} - #{deducao_esq} - #{deducao_dir})*10"

        {
          lenx: lenx,
          x: x,
          corte_comp: corte,
        }
      end
    end
  end
end
