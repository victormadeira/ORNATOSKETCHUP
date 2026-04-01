# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/accessory_builder.rb — Construtor de acessorios internos
#
# Cria acessorios que vao no BOM (Bill of Materials) mas NAO geram
# pecas na lista de corte CNC. Sao itens comprados prontos:
#   - Cestos aramados (pull-out wire baskets)
#   - Sapateiras (shoe racks)
#   - Cabideiros/varoes (clothes rails)
#   - Lixeiras pull-out
#   - Aramados rotativos (lazy susan, magic corner)
#   - Vidros e espelhos
#   - Perfis de iluminacao LED
#   - Passa-cabos e grelhas de ventilacao
#
# Cada acessorio e inserido como ComponentInstance com orn_na_lista_corte=false
# mas com orn_no_bom=true para aparecer no orcamento e lista de materiais.

module Ornato
  module Engineering
    class AccessoryBuilder

      # ================================================================
      # Catalogo de acessorios
      # ================================================================
      ACESSORIOS = {
        # ── Aramados ─────────────────────────────────────────────
        cesto_aramado: {
          descricao: 'Cesto Aramado Pull-Out',
          categoria: :aramado,
          na_lista_corte: false,
          no_bom: true,
          larguras_mm: [250, 300, 350, 400, 450, 500, 600],
          profundidades_mm: [400, 450, 500],
          alturas_mm: [120, 170, 220],
          precisa_corredica: true,
          modelo_resolver: 'ACES_CESTO',
        },
        cesto_roupeiro: {
          descricao: 'Cesto Roupeiro (roupa suja)',
          categoria: :aramado,
          na_lista_corte: false,
          no_bom: true,
          larguras_mm: [400, 450, 500, 600],
          alturas_mm: [300, 400],
          precisa_corredica: true,
          modelo_resolver: 'ACES_CESTO_ROUP',
        },

        # ── Sapateira ────────────────────────────────────────────
        sapateira_articulada: {
          descricao: 'Sapateira Articulada (inclinada)',
          categoria: :sapateira,
          na_lista_corte: false,
          no_bom: true,
          larguras_mm: [400, 450, 500, 600, 700, 800, 900],
          pares_por_nivel: 3,
          niveis: [2, 3],
          modelo_resolver: 'ACES_SAPAT_ART',
        },
        sapateira_aramada: {
          descricao: 'Sapateira Aramada (prateleira inclinada)',
          categoria: :sapateira,
          na_lista_corte: false,
          no_bom: true,
          larguras_mm: [400, 500, 600, 700, 800, 900],
          modelo_resolver: 'ACES_SAPAT_ARAM',
        },

        # ── Cabideiro ────────────────────────────────────────────
        varao_oval: {
          descricao: 'Varao Oval Cromado (cabideiro)',
          categoria: :cabideiro,
          na_lista_corte: false,
          no_bom: true,
          comprimentos_mm: [300, 400, 500, 600, 700, 800, 900, 1000, 1200],
          diametro_mm: 30,  # oval 30x15mm
          suportes: 2,      # 2 suportes laterais
          modelo_resolver: 'ACES_VARAO_OVAL',
        },
        varao_pull_out: {
          descricao: 'Varao Retrátil (Pull-Out)',
          categoria: :cabideiro,
          na_lista_corte: false,
          no_bom: true,
          comprimentos_mm: [250, 300, 350, 400, 450, 500],
          modelo_resolver: 'ACES_VARAO_PULL',
        },

        # ── Lixeira ──────────────────────────────────────────────
        lixeira_simples: {
          descricao: 'Lixeira Pull-Out Simples (1 balde)',
          categoria: :lixeira,
          na_lista_corte: false,
          no_bom: true,
          largura_modulo_min_mm: 300,
          capacidade_litros: 15,
          modelo_resolver: 'ACES_LIXEIRA_1',
        },
        lixeira_dupla: {
          descricao: 'Lixeira Pull-Out Dupla (2 baldes)',
          categoria: :lixeira,
          na_lista_corte: false,
          no_bom: true,
          largura_modulo_min_mm: 400,
          capacidade_litros: 30,  # 2x15L
          modelo_resolver: 'ACES_LIXEIRA_2',
        },
        lixeira_seletiva: {
          descricao: 'Lixeira Seletiva (3 baldes)',
          categoria: :lixeira,
          na_lista_corte: false,
          no_bom: true,
          largura_modulo_min_mm: 500,
          capacidade_litros: 45,  # 3x15L
          modelo_resolver: 'ACES_LIXEIRA_3',
        },

        # ── Aramado Rotativo ─────────────────────────────────────
        lazy_susan: {
          descricao: 'Aramado Giratório (Lazy Susan)',
          categoria: :rotativo,
          na_lista_corte: false,
          no_bom: true,
          diametros_mm: [450, 500, 600, 700],
          para_canto: true,
          modelo_resolver: 'ACES_LAZY_SUSAN',
        },
        magic_corner: {
          descricao: 'Magic Corner (canto cego)',
          categoria: :rotativo,
          na_lista_corte: false,
          no_bom: true,
          largura_modulo_min_mm: 800,
          modelo_resolver: 'ACES_MAGIC_CORNER',
        },

        # ── Vidro ────────────────────────────────────────────────
        vidro_temperado: {
          descricao: 'Vidro Temperado (prateleira/porta)',
          categoria: :vidro,
          na_lista_corte: false,
          no_bom: true,
          espessuras_mm: [4, 6, 8, 10],
          tipos: [:incolor, :fume, :bronze, :serigrafado, :jateado],
          modelo_resolver: 'ACES_VIDRO_TEMP',
        },
        espelho: {
          descricao: 'Espelho (porta ou fundo)',
          categoria: :vidro,
          na_lista_corte: false,
          no_bom: true,
          espessuras_mm: [3, 4],
          fixacao: [:colado, :com_perfil],
          modelo_resolver: 'ACES_ESPELHO',
        },

        # ── Iluminacao ───────────────────────────────────────────
        perfil_led: {
          descricao: 'Perfil Aluminio para Fita LED',
          categoria: :iluminacao,
          na_lista_corte: false,
          no_bom: true,
          comprimentos_mm: [300, 400, 500, 600, 800, 1000, 1200],
          tipos: [:embutido, :sobrepor, :canto],
          modelo_resolver: 'ACES_PERFIL_LED',
        },
        sensor_porta: {
          descricao: 'Sensor de Abertura para LED',
          categoria: :iluminacao,
          na_lista_corte: false,
          no_bom: true,
          modelo_resolver: 'ACES_SENSOR_PORTA',
        },

        # ── Passa-cabos / Ventilacao ─────────────────────────────
        passa_cabo_60: {
          descricao: 'Passa-Cabos 60mm (escritorio)',
          categoria: :passagem,
          na_lista_corte: false,
          no_bom: true,
          diametro_mm: 60,
          furo_necessario: true,
          furo_peca_alvo: 'topo',  # furo na peca topo (mesa/bancada)
          modelo_resolver: 'ACES_PASSA_CABO_60',
        },
        passa_cabo_80: {
          descricao: 'Passa-Cabos 80mm',
          categoria: :passagem,
          na_lista_corte: false,
          no_bom: true,
          diametro_mm: 80,
          furo_necessario: true,
          furo_peca_alvo: 'topo',  # furo na peca topo (mesa/bancada)
          modelo_resolver: 'ACES_PASSA_CABO_80',
        },
        grelha_ventilacao: {
          descricao: 'Grelha de Ventilacao (torre quente)',
          categoria: :passagem,
          na_lista_corte: false,
          no_bom: true,
          larguras_mm: [60, 80, 100],
          alturas_mm: [300, 400, 500],
          modelo_resolver: 'ACES_GRELHA',
        },

        # ── Hidraulica (banheiro/cozinha) ────────────────────────
        furo_sifao: {
          descricao: 'Furo para Sifao (base gabinete)',
          categoria: :passagem,
          na_lista_corte: false,
          no_bom: true,
          diametro_mm: 50,
          furo_necessario: true,
          furo_peca_alvo: 'base',     # furo na base (acesso sifao)
          modelo_resolver: 'ACES_FURO_SIFAO',
        },
        furo_hidraulica: {
          descricao: 'Furo para Tubulacao Hidraulica',
          categoria: :passagem,
          na_lista_corte: false,
          no_bom: true,
          diametro_mm: 35,
          furo_necessario: true,
          furo_peca_alvo: 'fundo',    # furo no fundo (saida agua)
          modelo_resolver: 'ACES_FURO_HIDRA',
        },
      }.freeze

      # ================================================================
      # Interface publica
      # ================================================================

      # Adiciona um acessorio ao modulo.
      # O acessorio e marcado como orn_na_lista_corte=false, orn_no_bom=true.
      # @param modulo [Sketchup::ComponentInstance]
      # @param tipo [Symbol] chave de ACESSORIOS
      # @param posicao_z_pct [Float] posicao vertical (0.0 a 1.0)
      # @param dimensoes [Hash] override de dimensoes { largura_mm:, profundidade_mm:, altura_mm: }
      # @return [Sketchup::ComponentInstance, nil]
      # @param vao [Integer, nil] indice do vao (entre divisorias). nil = largura total.
      def self.adicionar(modulo, tipo:, posicao_z_pct: 0.5, dimensoes: {}, vao: nil)
        spec = ACESSORIOS[tipo]
        raise "Acessorio desconhecido: #{tipo}" unless spec

        model = Sketchup.active_model
        parent_def = modulo.definition
        tipo_modulo = parent_def.get_attribute('dynamic_attributes', 'orn_tipo_modulo') || ''

        # Validacao: lazy susan e magic corner precisam de modulo canto_l
        if spec[:para_canto] && tipo_modulo != 'canto_l'
          puts "[AccessoryBuilder] AVISO: #{spec[:descricao]} e otimizado para modulos canto_l. " \
               "Modulo atual: #{tipo_modulo}. Inserindo mesmo assim."
        end

        model.start_operation("Adicionar #{spec[:descricao]}", true)

        begin
          nome = spec[:descricao]
          nome_unico = "#{nome}_#{Time.now.to_i}_#{rand(10000).to_s.rjust(4, '0')}"
          acess_def = model.definitions.add(nome_unico)

          # Geometria placeholder (caixa transparente)
          # Para acessorios de canto_l, usar largura_retorno como profundidade
          if spec[:para_canto] && tipo_modulo == 'canto_l'
            lr = parent_def.get_attribute('dynamic_attributes', 'orn_largura_retorno')
            default_w = lr ? (lr * 10).to_i : 400
            default_d = default_w
          else
            default_w = 400
            default_d = 400
          end
          w = (dimensoes[:largura_mm] || default_w) / 10.0
          d = (dimensoes[:profundidade_mm] || default_d) / 10.0
          h = (dimensoes[:altura_mm] || 200) / 10.0
          AggregateBuilder.send(:criar_geometria_caixa, acess_def, w.cm, d.cm, h.cm)

          # Posicao dentro do modulo
          z_formula = "Parent!orn_espessura_real + " \
                      "(Parent!orn_altura - 2*Parent!orn_espessura_real) * #{posicao_z_pct}"

          # Formulas de dimensao e posicao dependem do tipo de acessorio
          # Se vao especificado, calcular formulas por compartimento (entre divisorias)
          vao_f = if vao && defined?(AggregateBuilder)
            AggregateBuilder.send(:calcular_formulas_vao, parent_def, vao)
          else
            nil
          end

          formulas = if spec[:para_canto] && tipo_modulo == 'canto_l'
            # Lazy susan / magic corner: centrar no cruzamento do L
            {
              lenx: "#{w}",
              leny: "#{d}",
              lenz: "#{h}",
              x: 'Parent!orn_espessura_real',
              y: 'Parent!orn_espessura_real',
              z: z_formula,
            }
          elsif vao_f
            # Acessorio dentro de um vao especifico
            {
              lenx: vao_f[:lenx],
              leny: prof_formula_acessorio(parent_def),
              lenz: "#{h}",
              x: vao_f[:x],
              y: '0',
              z: z_formula,
            }
          else
            {
              lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real',
              leny: prof_formula_acessorio(parent_def),
              lenz: "#{h}",
              x: 'Parent!orn_espessura_real',
              y: '0',
              z: z_formula,
            }
          end

          BoxBuilder.send(:configurar_peca_dc, acess_def, {
            orn_marcado: true,
            orn_tipo_peca: 'acessorio',
            orn_subtipo: tipo.to_s,
            orn_codigo: "ACES_#{tipo.to_s.upcase}",
            orn_nome: nome,
            orn_na_lista_corte: false,
            orn_no_bom: true,
            orn_categoria_acessorio: spec[:categoria].to_s,
            orn_modelo_acessorio: spec[:modelo_resolver],
            orn_face_visivel: 'nenhuma',
          }, formulas)

          instance = parent_def.entities.add_instance(acess_def, ORIGIN)

          # Registrar no modulo
          acessorios_json = parent_def.get_attribute('ornato', 'orn_acessorios_json') || '[]'
          acessorios = begin; JSON.parse(acessorios_json); rescue; []; end
          acessorios << {
            tipo: tipo.to_s,
            descricao: spec[:descricao],
            categoria: spec[:categoria].to_s,
            modelo: spec[:modelo_resolver],
            posicao_z_pct: posicao_z_pct,
          }
          parent_def.set_attribute('ornato', 'orn_acessorios_json', acessorios.to_json)

          # Se precisa corredica, embutir
          if spec[:precisa_corredica]
            HardwareEmbedder.embutir_corredicas(
              parent_def,
              gaveta_indice: 0,
              total_gavetas: 1,
              modelo: 'CORR_TELESCOPICA'
            ) rescue nil
          end

          # Se precisa furo (passa-cabos), registrar operacao CNC na peca-alvo
          if spec[:furo_necessario]
            # Passa-cabo: furo vai na base ou topo, nao no acessorio
            alvo_furo = spec[:furo_peca_alvo] || 'topo'
            peca_alvo_def = encontrar_peca(parent_def, alvo_furo.to_sym)
            if peca_alvo_def
              registrar_furo_acessorio(peca_alvo_def, spec)
            else
              # Fallback: registrar no acessorio (menos correto para CNC, mas funcional)
              registrar_furo_acessorio(acess_def, spec)
            end
          end

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation
          instance

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # Adiciona porta com vidro (caixilho de aluminio + vidro temperado)
      # @param modulo [Sketchup::ComponentInstance]
      # @param tipo_vidro [Symbol] :incolor, :fume, :bronze, :jateado
      # @param espessura_vidro_mm [Float] 4, 6, 8
      # @param perfil [Symbol] :aluminio_natural, :aluminio_preto, :aluminio_champagne
      def self.adicionar_porta_vidro(modulo, tipo_vidro: :incolor,
                                      espessura_vidro_mm: 4, perfil: :aluminio_natural)
        model = Sketchup.active_model
        model.start_operation('Adicionar Porta com Vidro', true)

        begin
          parent_def = modulo.definition

          # A porta e uma moldura de aluminio (comprada pronta) + vidro
          # Nao vai na lista de corte de MDF — vai no BOM como acessorio
          nome = "Porta Vidro #{tipo_vidro}"
          porta_def = model.definitions.add(nome)

          # Profundidade real: vidro + perfil aluminio (tipicamente ~20mm total)
          prof_total_cm = (espessura_vidro_mm + 16.0) / 10.0  # vidro + perfil = cm

          AggregateBuilder.send(:criar_geometria_caixa, porta_def, 50.cm, prof_total_cm.cm, 72.cm)

          formulas = {
            lenx: 'Parent!orn_largura + (Parent!orn_sobreposicao_porta*2/10)',
            leny: "#{prof_total_cm}",
            lenz: 'Parent!orn_altura - Parent!orn_altura_rodape/10 - (Parent!orn_folga_porta*2/10)',
            x: '-(Parent!orn_sobreposicao_porta/10)',
            y: 'Parent!orn_profundidade + (Parent!orn_sobreposicao_porta/10)',
            z: 'Parent!orn_altura_rodape/10 + (Parent!orn_folga_porta/10)',
            corte_comp: '(Parent!orn_altura*10 - Parent!orn_altura_rodape) - (Parent!orn_folga_porta*2)',
            corte_larg: '(Parent!orn_largura*10) + (Parent!orn_sobreposicao_porta*2)',
          }

          BoxBuilder.send(:configurar_peca_dc, porta_def, {
            orn_marcado: true,
            orn_tipo_peca: 'porta',
            orn_subtipo: 'vidro',
            orn_codigo: 'POR_VIDRO',
            orn_nome: nome,
            orn_na_lista_corte: false,   # porta de vidro nao vai na lista de corte MDF
            orn_no_bom: true,
            orn_material: "Vidro #{tipo_vidro} #{espessura_vidro_mm}mm + Perfil #{perfil}",
            orn_borda_frontal: false,
            orn_face_visivel: 'ambas',
          }, formulas)

          parent_def.entities.add_instance(porta_def, ORIGIN)

          # Embutir dobradicas (vidro usa dobradica especifica)
          HardwareEmbedder.embutir_dobradicas(
            parent_def,
            porta_tipo: :unica,
            modelo: 'DOBR_VIDRO',
            espessura_porta: espessura_vidro_mm + 16,  # vidro + perfil
            lado: :esquerda
          ) rescue nil

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # Adiciona espelho colado em porta ou fundo
      def self.adicionar_espelho(modulo, alvo: :porta, espessura_mm: 4)
        model = Sketchup.active_model
        model.start_operation('Adicionar Espelho', true)

        begin
          parent_def = modulo.definition

          nome = "Espelho #{alvo}"
          esp_def = model.definitions.add(nome)

          esp_cm = espessura_mm / 10.0
          AggregateBuilder.send(:criar_geometria_caixa, esp_def, 50.cm, esp_cm.cm, 72.cm)

          # Verificar se tem portas de correr (espelho deve cobrir 1 porta, nao o modulo todo)
          qtd_correr = parent_def.get_attribute('dynamic_attributes', 'orn_qtd_portas_correr')
          if qtd_correr && qtd_correr.to_i > 1 && alvo == :porta
            overlap_mm = parent_def.get_attribute('dynamic_attributes', 'orn_overlap_porta_correr') || 25
            n = qtd_correr.to_i
            # Largura de 1 porta de correr: (largura + (n-1)*overlap) / n - folga
            lenx_espelho = "(Parent!orn_largura + #{(n-1) * overlap_mm / 10.0}) / #{n} - 1.0"
          else
            lenx_espelho = 'Parent!orn_largura - 1.0'
          end

          formulas = if alvo == :porta
            {
              lenx: lenx_espelho,
              leny: "#{esp_cm}",
              lenz: 'Parent!orn_altura - Parent!orn_altura_rodape/10 - 1.0',
              x: '0.5',
              y: 'Parent!orn_profundidade + 0.5',
              z: 'Parent!orn_altura_rodape/10 + 0.5',
            }
          else  # fundo
            {
              lenx: 'Parent!orn_largura - 2*Parent!orn_espessura_real - 1.0',
              leny: "#{esp_cm}",
              lenz: 'Parent!orn_altura - 2*Parent!orn_espessura_real - 1.0',
              x: 'Parent!orn_espessura_real + 0.5',
              y: '0.5',
              z: 'Parent!orn_espessura_real + 0.5',
            }
          end

          BoxBuilder.send(:configurar_peca_dc, esp_def, {
            orn_marcado: true,
            orn_tipo_peca: 'acessorio',
            orn_subtipo: 'espelho',
            orn_codigo: 'ACES_ESPELHO',
            orn_nome: nome,
            orn_na_lista_corte: false,
            orn_no_bom: true,
            orn_material: "Espelho #{espessura_mm}mm",
          }, formulas)

          parent_def.entities.add_instance(esp_def, ORIGIN)

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # Adiciona recorte/furo especial no modulo
      # @param modulo [Sketchup::ComponentInstance]
      # @param tipo [Symbol] :tubulacao, :tomada, :ventilacao, :passa_cabo
      # @param peca_alvo [Symbol] :base, :topo, :fundo, :lateral_esq, :lateral_dir
      # @param posicao [Hash] { x_pct: 0.5, y_pct: 0.5 } posicao relativa na peca
      # @param dimensoes [Hash] { largura_mm: 60, altura_mm: 60 } ou { diametro_mm: 60 }
      def self.adicionar_recorte(modulo, tipo:, peca_alvo:, posicao: {}, dimensoes: {})
        model = Sketchup.active_model
        model.start_operation("Adicionar Recorte #{tipo}", true)

        begin
          parent_def = modulo.definition

          # Encontrar a peca-alvo dentro do modulo
          peca_def = encontrar_peca(parent_def, peca_alvo)
          return nil unless peca_def

          # Registrar recorte como operacao CNC
          x_pct = posicao[:x_pct] || 0.5
          y_pct = posicao[:y_pct] || 0.5

          operacao = {
            tipo: tipo.to_s,
            forma: dimensoes[:diametro_mm] ? 'circular' : 'retangular',
            diametro: dimensoes[:diametro_mm],
            largura: dimensoes[:largura_mm],
            altura: dimensoes[:altura_mm],
            x_pct: x_pct,
            y_pct: y_pct,
            passante: true,  # furo passante
          }

          # Armazenar como JSON na peca
          ops_json = peca_def.get_attribute('ornato', 'orn_recortes_json') || '[]'
          ops = begin; JSON.parse(ops_json); rescue; []; end
          ops << operacao
          peca_def.set_attribute('ornato', 'orn_recortes_json', ops.to_json)
          peca_def.set_attribute('dynamic_attributes', 'orn_recortes_json', ops.to_json)

          model.commit_operation
          true

        rescue => e
          model.abort_operation
          raise e
        end
      end

      private

      # Formula de profundidade para acessorios internos.
      # Desconta recuo do fundo quando o modulo tem fundo (encaixado ou parafusado).
      # Acessorios precisam caber entre a face frontal e o fundo.
      def self.prof_formula_acessorio(parent_def)
        tipo_fundo = parent_def.get_attribute('dynamic_attributes', 'orn_tipo_fundo')
        if tipo_fundo && tipo_fundo.to_s != 'sem'
          # Profundidade util = total - recuo do fundo - espessura do fundo
          'Parent!orn_profundidade - Parent!orn_entrada_fundo - Parent!orn_espessura_fundo'
        else
          'Parent!orn_profundidade'
        end
      end

      def self.encontrar_peca(parent_def, tipo_peca)
        tipo_str = tipo_peca.to_s
        parent_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          tipo = entity.definition.get_attribute('dynamic_attributes', 'orn_tipo_peca')
          subtipo = entity.definition.get_attribute('dynamic_attributes', 'orn_subtipo')
          nome_completo = "#{tipo}_#{subtipo}"
          if tipo == tipo_str || nome_completo == tipo_str || subtipo == tipo_str
            return entity.definition
          end
        end
        nil
      end

      def self.registrar_furo_acessorio(acess_def, spec)
        ops_json = acess_def.get_attribute('ornato', 'orn_operacoes_cnc') || '[]'
        ops = begin; JSON.parse(ops_json); rescue; []; end
        ops << {
          tipo: 'furo_passante',
          ferramenta: "f_#{spec[:diametro_mm]}mm",
          face: 'top',
          lado: 'side_a',
          diametro: spec[:diametro_mm],
          profundidade: 'passante',
          x: 'centro',
          y: 'centro',
        }
        acess_def.set_attribute('ornato', 'orn_operacoes_cnc', ops.to_json)
        acess_def.set_attribute('dynamic_attributes', 'orn_operacoes_cnc', ops.to_json)
      end

    end
  end
end
