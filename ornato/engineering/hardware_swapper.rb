# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/hardware_swapper.rb — Troca de ferragens em modulos existentes
#
# Permite trocar tipo de corredica, articulador, suporte de prateleira,
# fixacao estrutural e puxador em modulos ja criados. Quando a troca
# impacta a construcao (ex: corredica telescopica → quadro metalico),
# as pecas afetadas sao destruidas e recriadas com a receita correta.
#
# FLUXO:
#   1. Usuario seleciona modulo no SketchUp
#   2. Menu Ornato > Configurar Ferragens
#   3. HtmlDialog mostra opcoes atuais
#   4. Usuario troca (ex: corredica telescopica → tandem)
#   5. HardwareSwapper:
#      a) Remove ferragens e pecas antigas
#      b) Atualiza atributos DC do modulo
#      c) Recria pecas com receita correta
#      d) Reembute ferragens novas

module Ornato
  module Engineering
    class HardwareSwapper

      # ================================================================
      # Receitas de gaveta por tipo de corredica
      # ================================================================
      # Cada receita define quais pecas de madeira a gaveta precisa,
      # as formulas de dimensionamento, e parametros da corredica.
      #
      # TIPOS:
      #   :telescopica    — corredica lateral ball-bearing (5 pecas MDF)
      #   :oculta         — undermount/tandem Blum (5 pecas, lateral baixa)
      #   :quadro_metalico — Metabox/FGV (3 pecas, lateral e metal)
      #   :tandembox      — Blum Tandembox (2-3 pecas, lateral+traseira metal)
      GAVETA_RECEITAS = {
        telescopica: {
          descricao: 'Corredica Telescopica (Lateral)',
          pecas: [:frente, :lateral_esq, :lateral_dir, :traseira, :fundo],
          lateral_material: 'MDF 15mm Branco TX',
          lateral_espessura_cm: 1.5,
          fundo_encaixado: true,
          folga_corredica_cm: 1.25,        # 12.5mm cada lado
          altura_lateral_formula: :proporcional,  # altura_frente - 30mm
          recuo_frente_cm: 1.5,            # 15mm abaixo da frente
          fundo_tipo: :rasgo,              # encaixado em rasgo na lateral
          fundo_entrada_cm: 0.8,           # 8mm entrada no rasgo
          modelo_resolver: 'CORR_TELESCOPICA',
          profundidade_maxima_mm: 550,
          carga_maxima_kg: 35,
        },
        oculta: {
          descricao: 'Corredica Oculta (Undermount/Tandem)',
          pecas: [:frente, :lateral_esq, :lateral_dir, :traseira, :fundo],
          lateral_material: 'MDF 15mm Branco TX',
          lateral_espessura_cm: 1.5,
          fundo_encaixado: false,           # fundo apoiado na corredica
          folga_corredica_cm: 1.3,          # 13mm cada lado
          altura_lateral_formula: :fixa,    # 82mm fixo (padrao Tandem)
          altura_lateral_fixa_mm: 82,
          recuo_frente_cm: 1.5,
          fundo_tipo: :apoiado,             # apoiado nos trilhos
          fundo_entrada_cm: 0.0,
          clip_traseiro: true,              # precisa de clip de encaixe
          modelo_resolver: 'CORR_OCULTA_TANDEM',
          profundidade_maxima_mm: 650,
          carga_maxima_kg: 50,
        },
        quadro_metalico: {
          descricao: 'Quadro Metalico (Metabox/FGV)',
          pecas: [:frente, :traseira, :fundo],  # SEM laterais MDF
          lateral_material: nil,            # lateral e metalica (nao corta)
          lateral_espessura_cm: 0.0,
          fundo_encaixado: false,
          folga_corredica_cm: 0.0,          # lateral E a corredica
          altura_lateral_formula: :selecionavel,
          alturas_disponiveis_mm: [86, 118, 150],
          altura_lateral_fixa_mm: 86,       # default
          recuo_frente_cm: 0.0,
          fundo_tipo: :apoiado,
          fundo_entrada_cm: 0.0,
          modelo_resolver: 'CORR_QUADRO_METALICO',
          profundidade_maxima_mm: 500,
          carga_maxima_kg: 25,
          # Traseira mais estreita (entre as laterais metalicas)
          traseira_largura_deducao_extra_cm: 0.0,
        },
        tandembox: {
          descricao: 'Tandembox (Blum) / ArciTech (Hettich)',
          pecas: [:frente, :fundo],         # lateral + traseira metalicas
          lateral_material: nil,
          lateral_espessura_cm: 0.0,
          fundo_encaixado: false,
          folga_corredica_cm: 0.0,
          altura_lateral_formula: :selecionavel,
          alturas_disponiveis_mm: [83, 115, 198, 270],
          altura_lateral_fixa_mm: 83,       # default M height
          recuo_frente_cm: 0.0,
          fundo_tipo: :metalico,            # fundo pode ser metalico
          fundo_entrada_cm: 0.0,
          modelo_resolver: 'CORR_TANDEMBOX',
          profundidade_maxima_mm: 650,
          carga_maxima_kg: 65,
        },
      }.freeze

      # ================================================================
      # Receitas de articulador/basculante
      # ================================================================
      ARTICULADOR_RECEITAS = {
        aventos_hf: {
          descricao: 'Aventos HF (Blum) — Porta sobe paralela',
          tipo: :lift_up,
          mecanismo: :aventos,
          modelo_resolver: 'AVENT_HF',
          peso_porta_max_kg: 13.0,
          altura_porta_max_mm: 600,
        },
        aventos_hl: {
          descricao: 'Aventos HL (Blum) — Porta sobe articulada',
          tipo: :lift_up,
          mecanismo: :aventos,
          modelo_resolver: 'AVENT_HL',
          peso_porta_max_kg: 10.0,
          altura_porta_max_mm: 700,
        },
        aventos_hk: {
          descricao: 'Aventos HK-S (Blum) — Compacto stay-lift',
          tipo: :stay_lift,
          mecanismo: :aventos,
          modelo_resolver: 'AVENT_HK',
          peso_porta_max_kg: 5.0,
          altura_porta_max_mm: 400,
        },
        pistao_gas: {
          descricao: 'Pistao a Gas — Forca ajustavel',
          tipo: :lift_up,
          mecanismo: :pistao,
          modelo_resolver: 'PIST_GAS',
          forcas_disponiveis_n: [60, 80, 100, 120, 150],
          peso_porta_max_kg: 15.0,
          altura_porta_max_mm: 900,
        },
        pistao_hidraulico: {
          descricao: 'Pistao Hidraulico — Soft-close',
          tipo: :lift_up,
          mecanismo: :pistao,
          modelo_resolver: 'PIST_HIDR',
          forcas_disponiveis_n: [80, 100, 120],
          peso_porta_max_kg: 12.0,
          altura_porta_max_mm: 700,
        },
        kinvaro: {
          descricao: 'Kinvaro (Grass) — Lift system',
          tipo: :lift_up,
          mecanismo: :kinvaro,
          modelo_resolver: 'KINVARO',
          peso_porta_max_kg: 12.0,
          altura_porta_max_mm: 600,
        },
        dobratica_basculante: {
          descricao: 'Dobradica Basculante — Simples (sem mola)',
          tipo: :flip_up,
          mecanismo: :dobradica,
          modelo_resolver: 'DOBR_BASC',
          peso_porta_max_kg: 5.0,
          altura_porta_max_mm: 500,
        },
      }.freeze

      # ================================================================
      # Receitas de suporte de prateleira
      # ================================================================
      SUPORTE_PRATELEIRA_RECEITAS = {
        pino_5mm: {
          descricao: 'Pino Metalico 5mm (padrao)',
          diametro_mm: 5.0,
          profundidade_mm: 12.0,
          capacidade_kg: 15.0,
          modelo_resolver: 'SUP_PINO_5',
          qtd_por_prateleira: 4,
        },
        pino_8mm: {
          descricao: 'Pino Metalico 8mm (reforcado)',
          diametro_mm: 8.0,
          profundidade_mm: 15.0,
          capacidade_kg: 30.0,
          modelo_resolver: 'SUP_PINO_8',
          qtd_por_prateleira: 4,
        },
        suporte_metalico: {
          descricao: 'Suporte Metalico em L',
          diametro_mm: 5.0,
          profundidade_mm: 12.0,
          capacidade_kg: 40.0,
          modelo_resolver: 'SUP_METAL_L',
          qtd_por_prateleira: 4,
        },
        cremalheira: {
          descricao: 'Cremalheira (trilho vertical)',
          diametro_mm: 0,
          profundidade_mm: 0,
          capacidade_kg: 50.0,
          modelo_resolver: 'SUP_CREM',
          qtd_por_prateleira: 4,  # 4 trilhos
        },
        parafuso_confirmat: {
          descricao: 'Confirmat (prateleira fixa)',
          diametro_mm: 7.0,
          profundidade_mm: 50.0,
          capacidade_kg: 80.0,
          modelo_resolver: 'SUP_CONFIRMAT',
          qtd_por_prateleira: 4,
          fixa: true,
        },
      }.freeze

      # ================================================================
      # Receitas de fixacao estrutural
      # ================================================================
      FIXACAO_RECEITAS = {
        minifix: {
          descricao: 'Minifix 15mm (excêntrico)',
          tipo: :excentric,
          diametro_furo_mm: 15.0,
          profundidade_mm: 12.0,
          modelo_resolver: 'MINIFIX_15',
          reversivel: true,
        },
        confirmat: {
          descricao: 'Confirmat 7x50mm (parafuso)',
          tipo: :screw,
          diametro_furo_mm: 5.0,
          profundidade_mm: 50.0,
          modelo_resolver: 'CONFIRMAT_7x50',
          reversivel: false,
        },
        cavilha: {
          descricao: 'Cavilha 8x30mm (encaixe)',
          tipo: :dowel,
          diametro_furo_mm: 8.0,
          profundidade_mm: 15.0,
          modelo_resolver: 'CAVILHA_8x30',
          reversivel: false,
        },
        minifix_cavilha: {
          descricao: 'Minifix + Cavilha (combinado)',
          tipo: :combined,
          componentes: [:minifix, :cavilha],
          modelo_resolver: 'MINIFIX_CAVILHA',
          reversivel: true,
        },
        vb_conector: {
          descricao: 'VB Connector (bancada/tampo)',
          tipo: :vb,
          modelo_resolver: 'VB_CONECTOR',
          reversivel: true,
        },
      }.freeze

      # ================================================================
      # Receitas de pes/base
      # ================================================================
      PE_RECEITAS = {
        regulavel: {
          descricao: 'Pe Regulavel (padrao)',
          altura_mm: 100,
          ajuste_mm: 20,
          modelo_resolver: 'PE_REGULAVEL',
        },
        rodizio: {
          descricao: 'Rodizio (com freio)',
          altura_mm: 50,
          modelo_resolver: 'PE_RODIZIO',
        },
        sapata: {
          descricao: 'Sapata Niveladora',
          altura_mm: 15,
          modelo_resolver: 'PE_SAPATA',
        },
        suspenso: {
          descricao: 'Suporte Parede (suspenso)',
          altura_mm: 0,
          modelo_resolver: 'SUP_PAREDE',
          parede: true,
        },
      }.freeze

      # ================================================================
      # Interface publica — Trocar Corredica
      # ================================================================
      # Troca o tipo de corredica de TODAS as gavetas do modulo.
      # IMPACTO: destroi gavetas antigas e recria com a receita nova.
      #
      # @param modulo [Sketchup::ComponentInstance]
      # @param novo_tipo [Symbol] :telescopica, :oculta, :quadro_metalico, :tandembox
      # @param altura_metal_mm [Float, nil] para quadro_metalico/tandembox
      # @return [Boolean] sucesso
      def self.trocar_corredica(modulo, novo_tipo, altura_metal_mm: nil)
        receita = GAVETA_RECEITAS[novo_tipo]
        raise "Tipo de corredica desconhecido: #{novo_tipo}" unless receita

        model = Sketchup.active_model
        model.start_operation("Trocar Corredica → #{receita[:descricao]}", true)

        begin
          parent_def = modulo.definition

          # 1. Coletar info das gavetas atuais (quantidade, alturas)
          gavetas_info = coletar_info_gavetas(parent_def)
          return true if gavetas_info.empty?  # sem gavetas

          # 2. Remover todas as pecas de gaveta + corredicas
          remover_gavetas(parent_def)
          remover_ferragens_tipo(parent_def, 'corredica')

          # 3. Atualizar atributos do modulo
          parent_def.set_attribute('dynamic_attributes', 'orn_tipo_corredica', novo_tipo.to_s)
          parent_def.set_attribute('ornato', 'orn_tipo_corredica', novo_tipo.to_s)

          if altura_metal_mm && receita[:altura_lateral_formula] == :selecionavel
            parent_def.set_attribute('dynamic_attributes', 'orn_altura_lateral_gaveta', altura_metal_mm)
          end

          # 4. Recriar gavetas com receita nova (preservando alturas originais)
          quantidade = gavetas_info.length
          quantidade.times do |i|
            alt_frente = gavetas_info[i] ? gavetas_info[i][:altura_frente_cm] : nil
            criar_gaveta_receita(parent_def, i, quantidade, alt_frente, receita)

            # Embutir corredicas
            HardwareEmbedder.embutir_corredicas(
              parent_def,
              gaveta_indice: i,
              total_gavetas: quantidade,
              modelo: receita[:modelo_resolver]
            )
          end

          # 5. Recalcular DC
          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          # 6. Validar resultado (aviso ao usuario se houver problemas)
          if defined?(CapacityValidator)
            alertas = CapacityValidator.validar(modulo) rescue []
            erros = alertas.select { |a| a[:nivel] == :erro }
            if erros.any?
              puts "[HardwareSwapper] AVISO pos-troca: #{erros.map { |e| e[:mensagem] }.join('; ')}"
            end
          end

          model.commit_operation
          true

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # ================================================================
      # Trocar Articulador/Basculante
      # ================================================================
      # @param modulo [Sketchup::ComponentInstance]
      # @param novo_tipo [Symbol] chave de ARTICULADOR_RECEITAS
      # @param forca_n [Float, nil] forca em Newtons (para pistao)
      def self.trocar_articulador(modulo, novo_tipo, forca_n: nil)
        receita = ARTICULADOR_RECEITAS[novo_tipo]
        raise "Tipo de articulador desconhecido: #{novo_tipo}" unless receita

        model = Sketchup.active_model
        model.start_operation("Trocar Articulador → #{receita[:descricao]}", true)

        begin
          parent_def = modulo.definition

          # 1. Remover ferragens de articulador/avento existentes
          remover_ferragens_tipo(parent_def, 'avento')
          remover_ferragens_tipo(parent_def, 'pistao')
          remover_ferragens_tipo(parent_def, 'articulador')

          # 2. Atualizar atributos
          parent_def.set_attribute('dynamic_attributes', 'orn_tipo_articulador', novo_tipo.to_s)
          parent_def.set_attribute('ornato', 'orn_tipo_articulador', novo_tipo.to_s)
          if forca_n
            parent_def.set_attribute('dynamic_attributes', 'orn_forca_articulador', forca_n)
          end

          # 3. Embutir novo articulador
          case receita[:mecanismo]
          when :aventos
            HardwareEmbedder.embutir_aventos(parent_def, modelo: receita[:modelo_resolver])
          when :pistao
            HardwareEmbedder.embutir_pistao(parent_def, modelo: receita[:modelo_resolver],
                                             forca_n: forca_n)
          when :kinvaro
            HardwareEmbedder.embutir_aventos(parent_def, modelo: receita[:modelo_resolver])
          when :dobradica
            # Basculante simples usa dobradica no topo
            HardwareEmbedder.embutir_dobradicas(parent_def,
              porta_tipo: :basculante, modelo: receita[:modelo_resolver],
              espessura_porta: 18.0, lado: :superior)
          end

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation
          true

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # ================================================================
      # Trocar Suporte de Prateleira
      # ================================================================
      def self.trocar_suporte_prateleira(modulo, novo_tipo)
        receita = SUPORTE_PRATELEIRA_RECEITAS[novo_tipo]
        raise "Tipo de suporte desconhecido: #{novo_tipo}" unless receita

        model = Sketchup.active_model
        model.start_operation("Trocar Suporte Prateleira → #{receita[:descricao]}", true)

        begin
          parent_def = modulo.definition

          # 1. Remover suportes existentes
          remover_ferragens_tipo(parent_def, 'suporte_prateleira')
          remover_ferragens_tipo(parent_def, 'pino')
          remover_ferragens_tipo(parent_def, 'cremalheira')

          # 2. Atualizar atributos
          parent_def.set_attribute('dynamic_attributes', 'orn_tipo_suporte_prat', novo_tipo.to_s)
          parent_def.set_attribute('ornato', 'orn_tipo_suporte_prat', novo_tipo.to_s)

          # 3. Se prateleira fixa (confirmat), converter subtipo das prateleiras
          if receita[:fixa]
            converter_prateleiras_para_fixas(parent_def)
          else
            converter_prateleiras_para_regulaveis(parent_def)
          end

          # 4. Embutir novos suportes
          contar_prateleiras(parent_def).times do |i|
            HardwareEmbedder.embutir_suportes_prateleira(
              parent_def,
              posicao_z_pct: (i + 1).to_f / (contar_prateleiras(parent_def) + 1),
              modelo: receita[:modelo_resolver]
            )
          end

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation
          true

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # ================================================================
      # Trocar Fixacao Estrutural
      # ================================================================
      def self.trocar_fixacao(modulo, novo_tipo)
        receita = FIXACAO_RECEITAS[novo_tipo]
        raise "Tipo de fixacao desconhecido: #{novo_tipo}" unless receita

        model = Sketchup.active_model
        model.start_operation("Trocar Fixacao → #{receita[:descricao]}", true)

        begin
          parent_def = modulo.definition

          # 1. Remover ferragens estruturais
          remover_ferragens_tipo(parent_def, 'minifix')
          remover_ferragens_tipo(parent_def, 'confirmat')
          remover_ferragens_tipo(parent_def, 'cavilha')

          # 2. Atualizar atributo
          parent_def.set_attribute('dynamic_attributes', 'orn_tipo_fixacao', novo_tipo.to_s)
          parent_def.set_attribute('ornato', 'orn_tipo_fixacao', novo_tipo.to_s)

          # 3. Embutir novas ferragens
          case receita[:tipo]
          when :excentric
            HardwareEmbedder.embutir_minifix(parent_def, junta: :base, lado: :esquerda)
            HardwareEmbedder.embutir_minifix(parent_def, junta: :base, lado: :direita)
            HardwareEmbedder.embutir_minifix(parent_def, junta: :topo, lado: :esquerda)
            HardwareEmbedder.embutir_minifix(parent_def, junta: :topo, lado: :direita)
          when :screw
            HardwareEmbedder.embutir_confirmat(parent_def, junta: :base, lado: :esquerda) rescue nil
            HardwareEmbedder.embutir_confirmat(parent_def, junta: :base, lado: :direita) rescue nil
            HardwareEmbedder.embutir_confirmat(parent_def, junta: :topo, lado: :esquerda) rescue nil
            HardwareEmbedder.embutir_confirmat(parent_def, junta: :topo, lado: :direita) rescue nil
          when :dowel
            HardwareEmbedder.embutir_cavilha(parent_def, junta: :base, lado: :esquerda) rescue nil
            HardwareEmbedder.embutir_cavilha(parent_def, junta: :base, lado: :direita) rescue nil
            HardwareEmbedder.embutir_cavilha(parent_def, junta: :topo, lado: :esquerda) rescue nil
            HardwareEmbedder.embutir_cavilha(parent_def, junta: :topo, lado: :direita) rescue nil
          when :combined
            receita[:componentes].each do |comp|
              next if comp == novo_tipo  # prevenir recursao infinita
              comp_receita = FIXACAO_RECEITAS[comp]
              next unless comp_receita && comp_receita[:tipo] != :combined
              trocar_fixacao(modulo, comp)
            end
          end

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation
          true

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # ================================================================
      # Trocar Pe/Base
      # ================================================================
      def self.trocar_pe(modulo, novo_tipo)
        receita = PE_RECEITAS[novo_tipo]
        raise "Tipo de pe desconhecido: #{novo_tipo}" unless receita

        model = Sketchup.active_model
        model.start_operation("Trocar Pe → #{receita[:descricao]}", true)

        begin
          parent_def = modulo.definition

          # Remover pes existentes
          remover_ferragens_tipo(parent_def, 'pe')
          remover_ferragens_tipo(parent_def, 'rodizio')
          remover_ferragens_tipo(parent_def, 'sapata')
          remover_ferragens_tipo(parent_def, 'suporte_parede')

          # Atualizar atributo
          parent_def.set_attribute('dynamic_attributes', 'orn_tipo_pe', novo_tipo.to_s)
          parent_def.set_attribute('ornato', 'orn_tipo_pe', novo_tipo.to_s)

          # Atualizar altura rodape se necessario
          if receita[:parede]
            parent_def.set_attribute('dynamic_attributes', 'orn_altura_rodape', 0)
          elsif receita[:altura_mm].to_f != (parent_def.get_attribute('dynamic_attributes', 'orn_altura_rodape') || 0).to_f
            parent_def.set_attribute('dynamic_attributes', 'orn_altura_rodape', receita[:altura_mm])
            parent_def.set_attribute('ornato', 'orn_altura_rodape', receita[:altura_mm])
          end

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation
          true

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # ================================================================
      # Trocar Dobradica
      # ================================================================
      # @param modulo [Sketchup::ComponentInstance]
      # @param novo_tipo [Symbol] :reta_sobreposta, :curva_meio_esquadro, :supercurva_embutida
      DOBRADICA_TIPOS = {
        reta_sobreposta: {
          descricao: 'Reta (Sobreposta)',
          angulo_abertura: 110,
          tipo_clip: :clip_on,
          overlay_mm: 16.0,
          modelo_resolver: 'DOBR_RETA_110',
        },
        curva_meio_esquadro: {
          descricao: 'Curva (Meio-Esquadro)',
          angulo_abertura: 110,
          tipo_clip: :clip_on,
          overlay_mm: 8.0,
          modelo_resolver: 'DOBR_CURVA_110',
        },
        supercurva_embutida: {
          descricao: 'Supercurva (Embutida)',
          angulo_abertura: 110,
          tipo_clip: :clip_on,
          overlay_mm: -2.0,    # embutida: overlay negativo
          modelo_resolver: 'DOBR_SUPER_110',
        },
      }.freeze

      def self.trocar_dobradica(modulo, novo_tipo)
        receita = DOBRADICA_TIPOS[novo_tipo]
        raise "Tipo de dobradica desconhecido: #{novo_tipo}" unless receita

        model = Sketchup.active_model
        model.start_operation("Trocar Dobradica → #{receita[:descricao]}", true)

        begin
          parent_def = modulo.definition

          # 1. Remover dobradicas existentes
          remover_ferragens_tipo(parent_def, 'dobradica')

          # 2. Atualizar atributos
          parent_def.set_attribute('dynamic_attributes', 'orn_tipo_dobradica', novo_tipo.to_s)
          parent_def.set_attribute('ornato', 'orn_tipo_dobradica', novo_tipo.to_s)
          parent_def.set_attribute('dynamic_attributes', 'orn_overlay_dobradica', receita[:overlay_mm])

          # 3. Detectar portas e embutir novas dobradicas
          portas = parent_def.entities.select do |e|
            next false unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
            next false unless e.respond_to?(:definition)
            tipo_p = e.definition.get_attribute('dynamic_attributes', 'orn_tipo_peca').to_s
            %w[porta basculante].include?(tipo_p)
          end

          portas.each do |porta|
            espessura = (porta.definition.get_attribute('dynamic_attributes', 'orn_espessura') || 18).to_f
            subtipo = porta.definition.get_attribute('dynamic_attributes', 'orn_subtipo').to_s
            lado = subtipo == 'direita' ? :direita : :esquerda

            HardwareEmbedder.embutir_dobradicas(
              parent_def,
              porta_tipo: :normal,
              modelo: receita[:modelo_resolver],
              espessura_porta: espessura,
              lado: lado
            )
          end

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          # Validar resultado
          if defined?(CapacityValidator)
            alertas = CapacityValidator.validar(modulo) rescue []
            erros = alertas.select { |a| a[:nivel] == :erro }
            if erros.any?
              puts "[HardwareSwapper] AVISO pos-troca dobradica: #{erros.map { |e| e[:mensagem] }.join('; ')}"
            end
          end

          model.commit_operation
          true

        rescue => e
          model.abort_operation
          raise e
        end
      end

      private

      # ================================================================
      # Criar gaveta com receita especifica
      # ================================================================
      def self.criar_gaveta_receita(parent_def, indice, total, altura_frente, receita)
        model = Sketchup.active_model

        # Altura da frente (cm)
        lenz_frente = if altura_frente
          "#{altura_frente / 10.0}"
        else
          "((Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)) / #{total}) - (Parent!orn_folga_porta/10)"
        end

        z_frente = "Parent!orn_altura_rodape/10 + (Parent!orn_folga_porta/10) + " \
                   "((Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)) / #{total}) * #{indice}"

        corte_larg_frente = if altura_frente
          "#{altura_frente}"
        else
          "((Parent!orn_altura*10 - Parent!orn_altura_rodape - Parent!orn_folga_porta*2) / #{total}) - Parent!orn_folga_porta"
        end

        # Altura da caixa interna
        folga_cm = receita[:folga_corredica_cm]
        lat_esp_cm = receita[:lateral_espessura_cm]
        recuo_cm = receita[:recuo_frente_cm]
        entrada_cm = receita[:fundo_entrada_cm]

        case receita[:altura_lateral_formula]
        when :proporcional
          lenz_caixa = if altura_frente
            "#{(altura_frente - 30.0) / 10.0}"
          else
            "((Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)) / #{total}) - (Parent!orn_folga_porta/10) - 3.0"
          end
          corte_larg_caixa = if altura_frente
            "#{altura_frente - 30.0}"
          else
            "((Parent!orn_altura*10 - Parent!orn_altura_rodape - Parent!orn_folga_porta*2) / #{total}) - Parent!orn_folga_porta - 30"
          end
        when :fixa
          alt_mm = receita[:altura_lateral_fixa_mm]
          lenz_caixa = "#{alt_mm / 10.0}"
          corte_larg_caixa = "#{alt_mm}"
        when :selecionavel
          alt_mm = receita[:altura_lateral_fixa_mm]  # default
          lenz_caixa = "#{alt_mm / 10.0}"
          corte_larg_caixa = "#{alt_mm}"
        end

        z_caixa = "#{z_frente} + #{recuo_cm}"

        # ── 1. FRENTE (sempre presente) ────────────────────────
        nome_frente = "Frente Gaveta #{indice + 1}"
        frente_def = model.definitions.add(nome_frente)
        AggregateBuilder.send(:criar_geometria_caixa, frente_def, 50.cm, 1.85.cm, 20.cm)

        frente_formulas = {
          lenx: 'Parent!orn_largura',
          leny: 'Parent!orn_espessura_porta/10',
          lenz: lenz_frente,
          x: '0',
          y: 'Parent!orn_profundidade',
          z: z_frente,
          corte_comp: 'Parent!orn_largura*10',
          corte_larg: corte_larg_frente,
        }

        BoxBuilder.send(:configurar_peca_dc, frente_def, {
          orn_marcado: true,
          orn_tipo_peca: 'frente_gaveta',
          orn_codigo: "FRE_GAV_#{indice + 1}",
          orn_nome: nome_frente,
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true, orn_borda_traseira: true,
          orn_borda_esquerda: true, orn_borda_direita: true,
          orn_face_visivel: 'face_a',
        }, frente_formulas)

        parent_def.entities.add_instance(frente_def, ORIGIN)

        # ── 2. LATERAIS (se na receita) ────────────────────────
        if receita[:pecas].include?(:lateral_esq)
          criar_lateral_gaveta_receita(parent_def, indice, :esquerda,
            lenz_caixa, corte_larg_caixa, z_caixa, receita)
          criar_lateral_gaveta_receita(parent_def, indice, :direita,
            lenz_caixa, corte_larg_caixa, z_caixa, receita)
        end

        # ── 3. TRASEIRA (se na receita) ────────────────────────
        if receita[:pecas].include?(:traseira)
          criar_traseira_gaveta_receita(parent_def, indice,
            lenz_caixa, corte_larg_caixa, z_caixa, receita)
        end

        # ── 4. FUNDO (se na receita e nao metalico) ───────────
        if receita[:pecas].include?(:fundo) && receita[:fundo_tipo] != :metalico
          criar_fundo_gaveta_receita(parent_def, indice, z_caixa, receita)
        end
      end

      def self.criar_lateral_gaveta_receita(parent_def, indice, lado,
                                             lenz_caixa, corte_larg, z_caixa, receita)
        model = Sketchup.active_model
        folga = receita[:folga_corredica_cm]
        esp = receita[:lateral_espessura_cm]
        sufixo = lado == :esquerda ? 'E' : 'D'
        nome = "Lat #{sufixo == 'E' ? 'Esq' : 'Dir'} Gaveta #{indice + 1}"

        lat_def = model.definitions.add(nome)
        AggregateBuilder.send(:criar_geometria_caixa, lat_def, esp.cm, 40.cm, 12.cm)

        x_formula = if lado == :esquerda
          "Parent!orn_espessura_real + #{folga}"
        else
          "Parent!orn_largura - Parent!orn_espessura_real - #{folga} - #{esp}"
        end

        formulas = {
          lenx: "#{esp}",
          leny: 'Parent!orn_profundidade - 5.0',
          lenz: lenz_caixa,
          x: x_formula,
          y: '0',
          z: z_caixa,
          corte_comp: '(Parent!orn_profundidade - 5.0)*10',
          corte_larg: corte_larg,
        }

        BoxBuilder.send(:configurar_peca_dc, lat_def, {
          orn_marcado: true,
          orn_tipo_peca: 'lateral_gaveta',
          orn_subtipo: lado.to_s,
          orn_codigo: "LAT_GAV_#{sufixo}_#{indice + 1}",
          orn_nome: nome,
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: false,
          orn_material: receita[:lateral_material],
          orn_face_visivel: 'face_b',
        }, formulas)

        parent_def.entities.add_instance(lat_def, ORIGIN)
      end

      def self.criar_traseira_gaveta_receita(parent_def, indice,
                                              lenz_caixa, corte_larg, z_caixa, receita)
        model = Sketchup.active_model
        folga = receita[:folga_corredica_cm]
        esp_lat = receita[:lateral_espessura_cm]
        nome = "Traseira Gaveta #{indice + 1}"

        tras_def = model.definitions.add(nome)
        AggregateBuilder.send(:criar_geometria_caixa, tras_def, 30.cm, 1.5.cm, 12.cm)

        # Para quadro metalico, nao desconta laterais MDF (nao existem)
        lenx_formula = if esp_lat > 0
          "Parent!orn_largura - 2*Parent!orn_espessura_real - 2*#{folga} - 2*#{esp_lat}"
        else
          "Parent!orn_largura - 2*Parent!orn_espessura_real"
        end

        x_formula = if esp_lat > 0
          "Parent!orn_espessura_real + #{folga} + #{esp_lat}"
        else
          "Parent!orn_espessura_real"
        end

        formulas = {
          lenx: lenx_formula,
          leny: '1.5',
          lenz: lenz_caixa,
          x: x_formula,
          y: '0',
          z: z_caixa,
          corte_comp: "(#{lenx_formula})*10",
          corte_larg: corte_larg,
        }

        BoxBuilder.send(:configurar_peca_dc, tras_def, {
          orn_marcado: true,
          orn_tipo_peca: 'traseira_gaveta',
          orn_codigo: "TRAS_GAV_#{indice + 1}",
          orn_nome: nome,
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_material: 'MDF 15mm Branco TX',
          orn_face_visivel: 'face_b',
        }, formulas)

        parent_def.entities.add_instance(tras_def, ORIGIN)
      end

      def self.criar_fundo_gaveta_receita(parent_def, indice, z_caixa, receita)
        model = Sketchup.active_model
        folga = receita[:folga_corredica_cm]
        esp_lat = receita[:lateral_espessura_cm]
        entrada = receita[:fundo_entrada_cm]
        nome = "Fundo Gaveta #{indice + 1}"

        fundo_def = model.definitions.add(nome)
        AggregateBuilder.send(:criar_geometria_caixa, fundo_def, 30.cm, 40.cm, 0.6.cm)

        # Largura do fundo depende do tipo
        if receita[:fundo_tipo] == :rasgo && esp_lat > 0
          # Encaixado em rasgo nas laterais: entre laterais + 2*entrada
          lenx = "Parent!orn_largura - 2*Parent!orn_espessura_real - 2*#{folga} - 2*#{esp_lat} + 2*#{entrada}"
          x_fundo = "Parent!orn_espessura_real + #{folga} + #{esp_lat} - #{entrada}"
        elsif esp_lat > 0
          # Apoiado: entre laterais
          lenx = "Parent!orn_largura - 2*Parent!orn_espessura_real - 2*#{folga} - 2*#{esp_lat}"
          x_fundo = "Parent!orn_espessura_real + #{folga} + #{esp_lat}"
        else
          # Quadro metalico/tandembox: largura total menos corpo
          lenx = "Parent!orn_largura - 2*Parent!orn_espessura_real"
          x_fundo = "Parent!orn_espessura_real"
        end

        leny = if entrada > 0
          "Parent!orn_profundidade - 5.0 + #{entrada}"
        else
          "Parent!orn_profundidade - 5.0"
        end

        formulas = {
          lenx: lenx,
          leny: leny,
          lenz: '0.6',
          x: x_fundo,
          y: '0',
          z: z_caixa,
          corte_comp: "(#{lenx})*10",
          corte_larg: "(#{leny})*10",
        }

        BoxBuilder.send(:configurar_peca_dc, fundo_def, {
          orn_marcado: true,
          orn_tipo_peca: 'fundo_gaveta',
          orn_codigo: "FUNDO_GAV_#{indice + 1}",
          orn_nome: nome,
          orn_na_lista_corte: true,
          orn_grao: 'sem',
          orn_material: 'HDF 6mm',
          orn_face_visivel: 'face_b',
        }, formulas)

        parent_def.entities.add_instance(fundo_def, ORIGIN)
      end

      # ================================================================
      # Helpers — remoção e coleta
      # ================================================================

      def self.coletar_info_gavetas(parent_def)
        gavetas = []
        parent_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          edef = entity.definition
          tipo = edef.get_attribute('dynamic_attributes', 'orn_tipo_peca')
          if tipo == 'frente_gaveta'
            # Preservar altura da frente para nao perder ao reconstruir
            lenz = edef.get_attribute('dynamic_attributes', '_lenz') ||
                   edef.get_attribute('dynamic_attributes', 'orn_corte_larg')
            gavetas << {
              indice: gavetas.length,
              nome: edef.get_attribute('dynamic_attributes', 'orn_nome'),
              altura_frente_cm: lenz.is_a?(Numeric) ? lenz : nil,
            }
          end
        end
        gavetas
      end

      def self.remover_gavetas(parent_def)
        tipos_gaveta = %w[frente_gaveta lateral_gaveta traseira_gaveta fundo_gaveta]
        to_erase = []
        parent_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          tipo = entity.definition.get_attribute('dynamic_attributes', 'orn_tipo_peca')
          to_erase << entity if tipos_gaveta.include?(tipo)
        end
        parent_def.entities.erase_entities(to_erase) unless to_erase.empty?
      end

      def self.remover_ferragens_tipo(parent_def, subtipo_pattern)
        to_erase = []
        parent_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          tipo = entity.definition.get_attribute('dynamic_attributes', 'orn_tipo_peca')
          subtipo = entity.definition.get_attribute('dynamic_attributes', 'orn_subtipo')
          if tipo == 'ferragem' && subtipo.to_s.include?(subtipo_pattern)
            to_erase << entity
          end
        end
        parent_def.entities.erase_entities(to_erase) unless to_erase.empty?
      end

      def self.converter_prateleiras_para_fixas(parent_def)
        parent_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          tipo = entity.definition.get_attribute('dynamic_attributes', 'orn_tipo_peca')
          if tipo == 'prateleira'
            entity.definition.set_attribute('dynamic_attributes', 'orn_subtipo', 'fixa')
            entity.definition.set_attribute('ornato', 'orn_subtipo', 'fixa')
          end
        end
      end

      def self.converter_prateleiras_para_regulaveis(parent_def)
        parent_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          tipo = entity.definition.get_attribute('dynamic_attributes', 'orn_tipo_peca')
          if tipo == 'prateleira'
            entity.definition.set_attribute('dynamic_attributes', 'orn_subtipo', 'regulavel')
            entity.definition.set_attribute('ornato', 'orn_subtipo', 'regulavel')
          end
        end
      end

      def self.contar_prateleiras(parent_def)
        count = 0
        parent_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          tipo = entity.definition.get_attribute('dynamic_attributes', 'orn_tipo_peca')
          count += 1 if tipo == 'prateleira'
        end
        count
      end

    end
  end
end
