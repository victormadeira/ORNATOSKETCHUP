# ornato_plugin/engines/motor_export.rb — Motor de exportacao JSON (compativel UpMobb)
# Gera JSON com 3 secoes: model_entities, details_project, machining
# Formato documentado em ANALISE_UPMOBB.md secoes 15-16

require 'json'

module Ornato
  module Engines
    class MotorExport

      # ─── Mapeamento de tipos de peca → codigos UpMobb ───
      UPMCODE = {
        # Caixaria
        lateral_esq:   'CM_LAT_ESQ',
        lateral_dir:   'CM_LAT_DIR',
        lateral:       'CM_LAT_DIR',   # generico (sera detectado por posicao)
        base:          'CM_BAS',
        topo:          'CM_BAS',
        fundo:         'CM_FUN_VER',
        fundo_hor:     'CM_FUN_HOR',
        regua:         'CM_REG',
        regua_pe:      'CM_REG',
        prateleira:    'CM_PRA',
        divisoria:     'CM_DIV',
        traseira:      'CM_TRG',
        tampo:         'CM_BAS',

        # Gaveta
        gaveta_lateral_esq:    'CM_LEG',
        gaveta_lateral_dir:    'CM_LDG',
        gaveta_fundo:          'CM_FUN_GAV_VER',
        gaveta_chapa:          'CM_CHGAV',
        gaveta_contra_frente:  'CM_CFG',
        gaveta_frente:         'CM_FRE_GAV_LIS',

        # Porta
        porta:                 'CM_POR_LIS',
        porta_provencal:       'CM_POR_LIS',
        porta_almofadada:      'CM_POR_LIS',
        porta_vidro:           'CM_POR_LIS',
        porta_veneziana:       'CM_POR_LIS',
        chapa_porta_ver:       'CM_CHPOR_VER_DIR',
        chapa_porta_ver_esq:   'CM_CHPOR_VER_ESQ',
        chapa_porta_ver_dir:   'CM_CHPOR_VER_DIR',

        # Modulo (pai)
        modulo:        'CM_BAL',

        # Usinagem
        usinagem_rasgo: 'CM_USI_RAS',
      }.freeze

      # ─── Mapeamento de tipo de modulo → descricao UpMobb ───
      MODULO_DESC = {
        inferior:   'Balcao',
        superior:   'Armario Alto',
        torre:      'Torre',
        gaveteiro:  'Gaveteiro',
        nicho:      'Nicho',
        prateleira: 'Prateleira',
        bancada:    'Bancada',
      }.freeze

      # ─── Codigos de orientacao/desenho (upmdraw) ───
      # Codificam a orientacao da peca + quais lados tem fita
      UPMDRAW = {
        lateral_dir:           'FTE1x2',   # Frontal Topo Esquerda
        lateral_esq:           'FTD1x2',   # Frontal Topo Direita
        base:                  'FTED1x3',  # Frontal Topo Esquerda Direita (4 lados)
        topo:                  'FTED1x3',
        regua:                 'FT1x3',    # Frontal Topo
        regua_pe:              'FT1x3',
        prateleira:            'F2x1',     # Frontal
        divisoria:             'E2x1',     # Esquerda
        fundo:                 'E2x1',
        fundo_hor:             '2x1',
        porta:                 'FTED2x1',  # 4 lados
        gaveta_lateral_esq:    'FT2x1',
        gaveta_lateral_dir:    'FT2x1',
        gaveta_fundo:          '2x1',
        gaveta_chapa:          'F1x2',
        gaveta_contra_frente:  'FED1x3',
        gaveta_frente:         'FTED2x1',
        chapa_porta_ver:       'F1x2',
        traseira:              '2x1',
      }.freeze

      # ─── Ferragens → codigos UpMobb ───
      FERRAGEM_CODE = {
        minifix_15:   'CM_KIT_MIN15TW_16_PLAST_BRANCO',
        minifix_18:   'CM_KIT_MIN15TW_19',
        cavilha_8x28: 'CM_KIT_CAV_8X28',
        parafuso_4x25: 'CM_KIT_PAR_4X25',
      }.freeze

      # ─── Ferramentas CNC → codigos UpMobb ───
      FERRAMENTA_CNC = {
        furo_15mm_minifix:   'f_15mm_tambor_min',
        furo_35mm_dobradica: 'f_35mm_dob',
        furo_3mm:            'f_3mm',
        furo_5mm_twister:    'f_5mm_twister243',
        furo_8mm_cavilha:    'f_8mm_cavilha',
        furo_8mm_eixo_min:   'f_8mm_eixo_tambor_min',
        pocket_3mm:          'p_3mm',
        pocket_8mm:          'p_8mm_cavilha',
        rasgo_fundo:         'r_f',
      }.freeze

      # ═══════════════════════════════════════════════════════════════
      # API PUBLICA
      # ═══════════════════════════════════════════════════════════════

      # Exporta todo o projeto para JSON
      # @param opcoes [Hash] :cliente, :projeto, :codigo, :vendedor, :caminho
      # @return [String] caminho do arquivo gerado
      def self.exportar_projeto(opcoes = {})
        model = Sketchup.active_model
        modulos = Utils.listar_modulos

        if modulos.empty?
          ::UI.messagebox('Nenhum modulo Ornato encontrado no projeto.', MB_OK)
          return nil
        end

        # Coleta dados de todos os modulos
        dados_modulos = []
        modulos.each_with_index do |grupo, idx|
          mi = Models::ModuloInfo.carregar_do_grupo(grupo)
          next unless mi
          dados_modulos << { modulo_info: mi, grupo: grupo, master_id: idx + 1 }
        end

        # Gera as 3 secoes do JSON
        json_data = {
          'model_entities' => gerar_model_entities(dados_modulos),
          'details_project' => gerar_details_project(opcoes, model),
          'machining' => gerar_machining(dados_modulos),
        }

        # Salva o arquivo
        caminho = opcoes[:caminho]
        unless caminho
          nome_projeto = opcoes[:projeto] || model.title || 'projeto_ornato'
          nome_projeto = nome_projeto.gsub(/[^a-zA-Z0-9_\-]/, '_')
          caminho = ::UI.savepanel(
            'Exportar JSON para Producao',
            File.dirname(model.path.empty? ? Dir.home : model.path),
            "#{nome_projeto}.json"
          )
        end

        return nil unless caminho

        # Garante extensao .json
        caminho += '.json' unless caminho.end_with?('.json')

        begin
          File.open(caminho, 'w:UTF-8') do |f|
            f.write(JSON.pretty_generate(json_data))
          end

          total_pecas = dados_modulos.sum { |d| d[:modulo_info].pecas.length }
          ::UI.messagebox(
            "JSON exportado com sucesso!\n\n" \
            "Arquivo: #{File.basename(caminho)}\n" \
            "Modulos: #{dados_modulos.length}\n" \
            "Pecas: #{total_pecas}\n" \
            "Tamanho: #{(File.size(caminho) / 1024.0).round(1)} KB",
            MB_OK
          )
          caminho
        rescue => e
          ::UI.messagebox("Erro ao salvar JSON:\n#{e.message}", MB_OK)
          puts "[Ornato] ERRO export: #{e.message}"
          puts e.backtrace.first(3).join("\n")
          nil
        end
      end

      # Exporta um unico modulo para JSON
      # @param grupo [Sketchup::Group] grupo do modulo
      # @param opcoes [Hash] :cliente, :projeto, :codigo, :vendedor, :caminho
      # @return [String] caminho do arquivo gerado
      def self.exportar_modulo(grupo, opcoes = {})
        mi = Models::ModuloInfo.carregar_do_grupo(grupo)
        unless mi
          ::UI.messagebox('Grupo selecionado nao e um modulo Ornato.', MB_OK)
          return nil
        end

        dados = [{ modulo_info: mi, grupo: grupo, master_id: 1 }]

        json_data = {
          'model_entities' => gerar_model_entities(dados),
          'details_project' => gerar_details_project(opcoes, Sketchup.active_model),
          'machining' => gerar_machining(dados),
        }

        caminho = opcoes[:caminho]
        unless caminho
          nome = mi.nome.gsub(/[^a-zA-Z0-9_\-]/, '_')
          caminho = ::UI.savepanel(
            'Exportar Modulo JSON',
            nil,
            "#{nome}.json"
          )
        end
        return nil unless caminho

        caminho += '.json' unless caminho.end_with?('.json')

        File.open(caminho, 'w:UTF-8') do |f|
          f.write(JSON.pretty_generate(json_data))
        end

        caminho
      end

      # Gera JSON como string (sem salvar arquivo) — util para API/ERP
      def self.gerar_json_string(opcoes = {})
        model = Sketchup.active_model
        modulos = Utils.listar_modulos
        return '{}' if modulos.empty?

        dados_modulos = []
        modulos.each_with_index do |grupo, idx|
          mi = Models::ModuloInfo.carregar_do_grupo(grupo)
          next unless mi
          dados_modulos << { modulo_info: mi, grupo: grupo, master_id: idx + 1 }
        end

        json_data = {
          'model_entities' => gerar_model_entities(dados_modulos),
          'details_project' => gerar_details_project(opcoes, model),
          'machining' => gerar_machining(dados_modulos),
        }

        JSON.pretty_generate(json_data)
      end

      # ═══════════════════════════════════════════════════════════════
      # SECAO 1: model_entities
      # ═══════════════════════════════════════════════════════════════

      private

      def self.gerar_model_entities(dados_modulos)
        entities = {}

        dados_modulos.each_with_index do |dados, mod_idx|
          mi = dados[:modulo_info]
          grupo = dados[:grupo]
          master_id = dados[:master_id]

          # Entidade do modulo (pai)
          modulo_entity = {
            'upmcode'        => UPMCODE[:modulo],
            'upmdescription' => descricao_modulo(mi),
            'upmwidth'       => mi.largura.to_s,
            'upmheight'      => mi.altura.to_s,
            'upmdepth'       => mi.profundidade.to_s,
            'upmfinish'      => codigo_acabamento_material(mi.material_corpo),
            'upmmasterid'    => master_id,
            'upmnamefile'    => Sketchup.active_model.title || 'projeto_ornato',
            'entities'       => {},
          }

          # Adiciona pecas como sub-entidades do modulo
          peca_idx = 0
          mi.pecas.each do |peca|
            persistent_id = gerar_persistent_id(grupo, peca, peca_idx)

            peca_entity = gerar_peca_entity(peca, mi, master_id, persistent_id)
            modulo_entity['entities'][peca_idx.to_s] = peca_entity
            peca_idx += 1
          end

          entities[mod_idx.to_s] = modulo_entity
        end

        entities
      end

      # Gera a entidade JSON de uma peca individual
      def self.gerar_peca_entity(peca, mi, master_id, persistent_id)
        esp_real = peca.espessura_real
        tipo_sym = detectar_tipo_sym(peca)

        # Dimensoes de corte
        comp_corte = peca.comprimento.to_f
        larg_corte = peca.largura.to_f

        # Codigos de fita de borda para os 4 lados
        fitas = calcular_fitas_4_lados(peca, mi)

        # Codigo de acabamento de fita (1C, 2C+1L, etc.)
        acabamento_fita = calcular_acabamento_fita(peca)

        # Resumo de fita (sem +)
        resumo_fita = acabamento_fita.gsub('+', '')

        entity = {
          'upmpiece'             => true,
          'upmcode'              => resolver_upmcode(peca, tipo_sym),
          'upmdescription'       => peca.nome,
          'upmpersistentid'      => persistent_id,
          'upmprocesscodea'      => "#{persistent_id}A",
          'upmprocesscodeb'      => "#{persistent_id}B",
          'upmnamefile'          => Sketchup.active_model.title || 'projeto_ornato',
          'upmmasterdescription' => descricao_modulo(mi),
          'upmmasterid'          => master_id,
          'upmdepth'             => larg_corte.to_s,
          'upmheight'            => comp_corte.to_s,
          'upmwidth'             => esp_real.to_s,
          'upmlength'            => comp_corte.to_s,
          'upmdraw'              => resolver_upmdraw(tipo_sym),
          'upmedgeside1'         => fitas[0],
          'upmedgeside2'         => fitas[1],
          'upmedgeside3'         => fitas[2],
          'upmedgeside4'         => fitas[3],
          'upmedgesides'         => resumo_fita,
          'upmedgesidetype'      => acabamento_fita,
          'upmfinish'            => codigo_acabamento_material(mi.material_corpo),
          'upmtextaggregates'    => '',
          'entities'             => gerar_sub_entidades(peca, mi, esp_real, comp_corte, larg_corte, fitas),
        }

        entity
      end

      # ═══════════════════════════════════════════════════════════════
      # SUB-ENTIDADES DE UMA PECA (painel + fitas + ferragens + usinagens)
      # ═══════════════════════════════════════════════════════════════

      def self.gerar_sub_entidades(peca, mi, esp_real, comp, larg, fitas)
        subs = {}
        sub_idx = 0

        # 0 — Painel MDF (feedstock)
        area_m2 = (comp * larg) / 1_000_000.0
        mat_code = codigo_material(mi.material_corpo, esp_real)

        # Ajustes de dimensao (pecas que encaixam em rasgo: -1mm)
        extra_length = '0'
        extra_width = '0'
        if peca_encaixa_em_rasgo?(peca, mi)
          extra_length = '-1'
          extra_width = '-1'
        end

        subs[sub_idx.to_s] = {
          'upmfeedstockpanel'    => true,
          'upmallowtransferjob'  => 1,
          'upmcutlist'           => 1,
          'upmcutlength'         => comp.to_s,
          'upmcutwidth'          => larg.to_s,
          'upmcutthickness'      => esp_real.to_s,
          'upmcutliquidlength'   => comp.to_s,
          'upmcutliquidwidth'    => larg.to_s,
          'upmdescription'       => 'Chapa de MDF',
          'upmextralength'       => extra_length,
          'upmextrawidth'        => extra_width,
          'upmfinish'            => codigo_acabamento_material(mi.material_corpo),
          'upmjobaxis'           => 'xyz',
          'upmmaterialcode'      => mat_code,
          'upmmaterialtype'      => 'MDF',
          'upmquantity'          => area_m2.round(6).to_s,
          'entities'             => {},
        }
        sub_idx += 1

        # 1..4 — Fitas de borda (uma sub-entidade por fita)
        posicoes_fita = ['Comprimento_Frontal', 'Comprimento_Traseiro', 'Largura_esquerda', 'Largura_direita']
        dimensoes_fita = [comp, comp, larg, larg]  # comprimento da fita em mm

        fitas.each_with_index do |codigo_fita, i|
          next if codigo_fita.nil? || codigo_fita.empty?

          metros_lineares = dimensoes_fita[i] / 1000.0

          subs[sub_idx.to_s] = {
            'upmcode'           => codigo_fita,
            'upmdescription'    => "Fita de borda #{descrever_fita(codigo_fita)}",
            'upmedge'           => 1,
            'upmdisable'        => '0',
            'upmfinish'         => codigo_acabamento_material(mi.material_corpo),
            'upmquantity'       => metros_lineares.round(4).to_s,
            'upmtextaggregates' => posicoes_fita[i],
            'upmwidth'          => dimensoes_fita[i].to_s,
            'entities'          => {},
          }
          sub_idx += 1
        end

        # Ferragens associadas a peca
        ferragens_peca = detectar_ferragens_peca(peca, mi)
        ferragens_peca.each do |ferragem|
          subs[sub_idx.to_s] = {
            'upmcode'        => ferragem[:code],
            'upmdescription' => ferragem[:descricao],
            'upmfinish'      => ferragem[:acabamento] || '',
            'upmtestbounds'  => ferragem[:qtd].to_s,
            'entities'       => {},
          }
          sub_idx += 1
        end

        # Usinagens na peca
        usinagens_peca = detectar_usinagens_peca(peca, mi)
        usinagens_peca.each do |usi|
          subs[sub_idx.to_s] = {
            'upmcode'          => UPMCODE[:usinagem_rasgo],
            'upmcornerradius'  => '0',
            'upmdepth'         => usi[:profundidade].to_s,
            'upmdescription'   => usi[:descricao],
            'upmdisable'       => '0',
            'upmjobcategory'   => usi[:categoria] || 'Transfer_vertical_saw_cut',
            'upmlength'        => usi[:comprimento].to_s,
            'upmquantity'      => (usi[:comprimento] / 1000.0).round(4).to_s,
            'upmtestbounds'    => '2',
            'upmtool'          => usi[:ferramenta] || 'r_f',
            'upmwidth'         => usi[:largura].to_s,
            'entities'         => {},
          }
          sub_idx += 1
        end

        subs
      end

      # ═══════════════════════════════════════════════════════════════
      # SECAO 2: details_project
      # ═══════════════════════════════════════════════════════════════

      def self.gerar_details_project(opcoes, model)
        {
          'client'              => opcoes[:cliente] || 'Cliente',
          'project'             => opcoes[:projeto] || model.title || 'Projeto Ornato',
          'my_code'             => opcoes[:codigo] || '01',
          'seller'              => opcoes[:vendedor] || 'Ornato',
          'type_material_panel' => 'MDF',
        }
      end

      # ═══════════════════════════════════════════════════════════════
      # SECAO 3: machining (dados CNC por peca)
      # ═══════════════════════════════════════════════════════════════

      def self.gerar_machining(dados_modulos)
        machining = {}

        dados_modulos.each do |dados|
          mi = dados[:modulo_info]
          grupo = dados[:grupo]

          mi.pecas.each_with_index do |peca, peca_idx|
            persistent_id = gerar_persistent_id(grupo, peca, peca_idx)
            esp_real = peca.espessura_real
            comp = peca.comprimento.to_f
            larg = peca.largura.to_f

            # Fitas das 4 bordas
            fitas = calcular_fitas_4_lados(peca, mi)

            # Workers (operacoes CNC)
            workers = gerar_workers_peca(peca, mi, comp, larg, esp_real)

            machining[persistent_id.to_s] = {
              'code'       => "#{persistent_id}A",
              'name_peace' => peca.nome,
              'length'     => comp,
              'width'      => larg,
              'thickness'  => esp_real,
              'borders'    => fitas,
              'workers'    => workers,
            }
          end
        end

        machining
      end

      # Gera operacoes CNC (workers) para uma peca
      def self.gerar_workers_peca(peca, mi, comp, larg, esp)
        workers = {}
        worker_idx = 0
        tipo = detectar_tipo_sym(peca)

        # ─── Canal de fundo (laterais, base, topo) ───
        if [:lateral_esq, :lateral_dir, :lateral].include?(tipo) &&
           mi.tipo_fundo == Config::FUNDO_REBAIXADO
          # Rasgo de serra na lateral para encaixe do fundo
          profundidade_rasgo = mi.espessura_fundo_real + 1.0  # folga
          largura_rasgo = mi.espessura_fundo_real + 0.5

          workers[worker_idx.to_s] = {
            'category' => 'Transfer_vertical_saw_cut',
            'tool'     => 'r_f',
            'face'     => 'left',
            'x'        => (comp - mi.rebaixo_fundo).round(2),
            'y'        => 0,
            'depth'    => profundidade_rasgo.round(2),
            'length'   => larg.round(2),
            'width'    => largura_rasgo.round(2),
          }
          worker_idx += 1
        end

        # ─── Furos de minifix (laterais) ───
        if [:lateral_esq, :lateral_dir, :lateral].include?(tipo)
          # Furos na face para tambor do minifix (base e topo)
          posicoes_y = [37, larg - 37]  # 37mm das bordas (recuo padrao)
          posicoes_x_base = [37]
          posicoes_x_topo = [comp - 37]

          (posicoes_x_base + posicoes_x_topo).each do |px|
            posicoes_y.each do |py|
              # Furo 15mm tambor
              workers[worker_idx.to_s] = {
                'category' => 'transfer_hole',
                'tool'     => 'f_15mm_tambor_min',
                'face'     => 'top',
                'x'        => px.round(2),
                'y'        => py.round(2),
                'depth'    => 12.5,
              }
              worker_idx += 1
            end
          end

          # Furos na borda para eixo do minifix
          posicoes_y.each do |py|
            # Borda inferior
            workers[worker_idx.to_s] = {
              'category' => 'transfer_hole',
              'tool'     => 'f_8mm_eixo_tambor_min',
              'face'     => 'bottom',
              'x'        => py.round(2),
              'y'        => (esp / 2.0).round(2),
              'depth'    => 34,
            }
            worker_idx += 1

            # Borda superior
            workers[worker_idx.to_s] = {
              'category' => 'transfer_hole',
              'tool'     => 'f_8mm_eixo_tambor_min',
              'face'     => 'top_edge',
              'x'        => py.round(2),
              'y'        => (esp / 2.0).round(2),
              'depth'    => 34,
            }
            worker_idx += 1
          end

          # Sistema 32 — furos para pinos de prateleira
          inicio_y = Config::SISTEMA_32_INICIO
          passo = Config::SISTEMA_32_PASSO
          recuo = Config::SISTEMA_32_RECUO_BORDA
          colunas_x = [recuo, larg - recuo]  # 2 colunas

          y = inicio_y
          while y <= (comp - inicio_y)
            colunas_x.each do |cx|
              workers[worker_idx.to_s] = {
                'category' => 'transfer_hole',
                'tool'     => 'f_5mm_twister243',
                'face'     => 'top',
                'x'        => y.round(2),
                'y'        => cx.round(2),
                'depth'    => 12,
              }
              worker_idx += 1
            end
            y += passo
          end
        end

        # ─── Furos de minifix (base/topo — na borda) ───
        if [:base, :topo].include?(tipo)
          posicoes_y = [37, larg - 37]
          posicoes_y.each do |py|
            # Furo na borda esquerda
            workers[worker_idx.to_s] = {
              'category' => 'transfer_hole',
              'tool'     => 'f_5mm_twister243',
              'face'     => 'left_edge',
              'x'        => py.round(2),
              'y'        => (esp / 2.0).round(2),
              'depth'    => 34,
            }
            worker_idx += 1

            # Furo na borda direita
            workers[worker_idx.to_s] = {
              'category' => 'transfer_hole',
              'tool'     => 'f_5mm_twister243',
              'face'     => 'right_edge',
              'x'        => py.round(2),
              'y'        => (esp / 2.0).round(2),
              'depth'    => 34,
            }
            worker_idx += 1
          end
        end

        # ─── Furos de dobradica (porta) ───
        if tipo == :porta
          qtd_dobradicas = Config.qtd_dobradicas(comp)
          posicoes = calcular_posicoes_dobradica(comp, qtd_dobradicas)
          recuo_borda = 23  # mm da borda ao centro do furo

          posicoes.each do |pos_y|
            workers[worker_idx.to_s] = {
              'category' => 'transfer_hole',
              'tool'     => 'f_35mm_dob',
              'face'     => 'back',
              'x'        => recuo_borda.round(2),
              'y'        => pos_y.round(2),
              'depth'    => 12.5,
            }
            worker_idx += 1
          end
        end

        # ─── Cavilhas para gaveta ───
        if [:gaveta_lateral_esq, :gaveta_lateral_dir].include?(tipo)
          # Furos para cavilha na frente e atras
          [37, comp - 37].each do |px|
            workers[worker_idx.to_s] = {
              'category' => 'transfer_hole',
              'tool'     => 'f_8mm_cavilha',
              'face'     => 'bottom_edge',
              'x'        => px.round(2),
              'y'        => (esp / 2.0).round(2),
              'depth'    => 19,
            }
            worker_idx += 1
          end
        end

        workers
      end

      # ═══════════════════════════════════════════════════════════════
      # HELPERS DE CODIGO
      # ═══════════════════════════════════════════════════════════════

      # Detecta o tipo simbolo da peca baseado no nome
      def self.detectar_tipo_sym(peca)
        nome = peca.nome.downcase
        tipo = peca.tipo

        return :lateral_esq if nome.include?('lateral') && nome.include?('esq')
        return :lateral_dir if nome.include?('lateral') && nome.include?('dir') && !nome.include?('gaveta')
        return :gaveta_lateral_esq if nome.include?('lateral') && nome.include?('esq') && nome.include?('gaveta')
        return :gaveta_lateral_dir if nome.include?('lateral') && nome.include?('dir') && nome.include?('gaveta')
        return :gaveta_fundo if nome.include?('fundo') && nome.include?('gaveta')
        return :gaveta_chapa if nome.include?('chapa') && nome.include?('gaveta')
        return :gaveta_contra_frente if nome.include?('contra') && nome.include?('frente')
        return :gaveta_frente if nome.include?('frente') && nome.include?('gaveta')
        return :regua_pe if nome.include?('regua') && nome.include?('pe')
        return :regua if nome.include?('regua')
        return :chapa_porta_ver if nome.include?('chapa') && nome.include?('porta')
        return :porta if tipo == :porta || nome.include?('porta')
        return :prateleira if tipo == :prateleira || nome.include?('prateleira')
        return :divisoria if tipo == :divisoria || nome.include?('divisoria')
        return :fundo if tipo == :fundo || nome.include?('fundo')
        return :base if tipo == :base || nome.include?('base')
        return :topo if tipo == :topo || nome.include?('topo') || nome.include?('tampo')
        return :lateral if tipo == :lateral
        return :traseira if nome.include?('traseira')

        tipo || :generico
      end

      # Resolve o upmcode a partir do tipo
      def self.resolver_upmcode(peca, tipo_sym)
        UPMCODE[tipo_sym] || 'CM_PCA'  # generico se nao mapeado
      end

      # Resolve o codigo de orientacao/desenho
      def self.resolver_upmdraw(tipo_sym)
        UPMDRAW[tipo_sym] || '2x1'
      end

      # Codigo do material: MDF_15.5_BRANCO_TX
      def self.codigo_material(material_nome, espessura_real)
        acabamento = codigo_acabamento_material(material_nome)
        "MDF_#{espessura_real}_#{acabamento}"
      end

      # Extrai o acabamento do nome do material
      # Ex: "MDF Branco TX 18mm" → "BRANCO_TX"
      def self.codigo_acabamento_material(material_nome)
        return 'BRANCO_TX' unless material_nome

        nome = material_nome.to_s.upcase
        # Remove prefixo MDF e espessura
        nome = nome.gsub(/MDF\s*/i, '').gsub(/\d+\.?\d*\s*MM/i, '').strip
        # Converte espacos para underscore
        resultado = nome.gsub(/\s+/, '_').gsub(/[^A-Z0-9_]/, '')
        resultado.empty? ? 'BRANCO_TX' : resultado
      end

      # Gera codigo de fita de borda: CMBOR22x045BRANCO_TX
      # Largura da fita baseada na espessura nominal + 3-4mm extra
      def self.codigo_fita_borda(espessura_nominal, material_nome)
        acabamento = codigo_acabamento_material(material_nome)

        # Largura da fita = espessura nominal + ~4mm (padrao industria)
        largura_fita = case espessura_nominal.to_i
                        when 15 then 19
                        when 18 then 22
                        when 25 then 29
                        when 6  then 10
                        when 9  then 13
                        when 12 then 16
                        else espessura_nominal.to_i + 4
                        end

        # Espessura da fita: 0.45mm (padrao PVC)
        "CMBOR#{largura_fita}x045#{acabamento}"
      end

      # Calcula os codigos de fita para os 4 lados da peca
      # Retorna array [frontal, traseiro, esquerda, direita]
      def self.calcular_fitas_4_lados(peca, mi)
        codigo = codigo_fita_borda(mi.espessura_corpo, mi.material_corpo)

        fitas = ['', '', '', '']
        fitas[0] = codigo if peca.fita_frente
        fitas[1] = codigo if peca.fita_tras
        fitas[2] = codigo if peca.fita_topo    # topo = largura esquerda
        fitas[3] = codigo if peca.fita_base     # base = largura direita

        fitas
      end

      # Calcula o codigo de acabamento de fita (1C, 2C+1L, 4Lados, etc.)
      def self.calcular_acabamento_fita(peca)
        c = 0  # comprimentos com fita (frente + tras)
        l = 0  # larguras com fita (topo + base)

        c += 1 if peca.fita_frente
        c += 1 if peca.fita_tras
        l += 1 if peca.fita_topo
        l += 1 if peca.fita_base

        return '' if c == 0 && l == 0
        return '4Lados' if c == 2 && l == 2

        partes = []
        partes << "#{c}C" if c > 0
        partes << "#{l}L" if l > 0
        partes.join('+')
      end

      # Descreve a fita a partir do codigo
      def self.descrever_fita(codigo)
        return '' unless codigo && !codigo.empty?
        # CMBOR22x045BRANCO_TX → "branco tx 22x045"
        match = codigo.match(/CMBOR(\d+)x(\d+)(.+)/)
        if match
          larg = match[1]
          esp = match[2]
          acabamento = match[3].gsub('_', ' ').downcase
          "#{acabamento} #{larg}x#{esp}"
        else
          codigo
        end
      end

      # Descricao do modulo para o JSON
      def self.descricao_modulo(mi)
        desc = MODULO_DESC[mi.tipo]
        desc ||= mi.nome || 'Modulo'
        desc
      end

      # Gera um ID persistente unico para a peca
      def self.gerar_persistent_id(grupo, peca, peca_idx)
        # Usa o entityID do SketchUp se disponivel, senao gera baseado em hash
        if peca.respond_to?(:grupo_ref) && peca.grupo_ref && peca.grupo_ref.respond_to?(:entityID)
          peca.grupo_ref.entityID
        elsif grupo && grupo.respond_to?(:entityID)
          grupo.entityID * 100 + peca_idx
        else
          # Fallback: hash do nome + indice
          (peca.nome.hash.abs % 900000) + 100000 + peca_idx
        end
      end

      # Verifica se a peca encaixa em rasgo de fundo (-1mm ajuste)
      def self.peca_encaixa_em_rasgo?(peca, mi)
        return false unless mi.tipo_fundo == Config::FUNDO_REBAIXADO
        tipo = detectar_tipo_sym(peca)
        [:fundo, :fundo_hor, :gaveta_fundo].include?(tipo)
      end

      # Detecta ferragens associadas a uma peca especifica
      def self.detectar_ferragens_peca(peca, mi)
        ferragens = []
        tipo = detectar_tipo_sym(peca)
        esp = mi.espessura_corpo

        case tipo
        when :lateral_esq, :lateral_dir, :lateral
          # Minifix (2 por juncao lateral-base, 2 por juncao lateral-topo = 4)
          code_min = esp <= 15 ? FERRAGEM_CODE[:minifix_15] : FERRAGEM_CODE[:minifix_18]
          ferragens << {
            code: code_min,
            descricao: 'Minifix',
            acabamento: 'PLAST_BRANCO',
            qtd: 4,
          }
          # Cavilhas
          ferragens << {
            code: FERRAGEM_CODE[:cavilha_8x28],
            descricao: 'Cavilha 8x28',
            acabamento: '',
            qtd: 4,
          }

        when :porta
          # Dobradicas (calculadas por altura)
          qtd = Config.qtd_dobradicas(peca.comprimento)
          ferragens << {
            code: 'CM_KIT_HAFELE_DOB_RET_110_SC_CF4_NIQ',
            descricao: 'Dobradica Hafele 110 Reta',
            acabamento: 'NIQ',
            qtd: qtd,
          }

        when :gaveta_frente, :gaveta_chapa
          # Corredicao (par)
          ferragens << {
            code: 'CM_KIT_COR_HAFELE_H45_S_SC_500',
            descricao: 'Corredica Hafele H45 500mm',
            acabamento: 'SC',
            qtd: 1,
          }
        end

        ferragens
      end

      # Detecta usinagens na peca
      def self.detectar_usinagens_peca(peca, mi)
        usinagens = []
        tipo = detectar_tipo_sym(peca)

        # Canal de fundo nas laterais
        if [:lateral_esq, :lateral_dir, :lateral].include?(tipo) &&
           mi.tipo_fundo == Config::FUNDO_REBAIXADO
          esp_fundo = mi.espessura_fundo_real
          usinagens << {
            descricao: 'Rasgo de serra',
            profundidade: 8,
            comprimento: peca.largura.to_f,  # ao longo da profundidade
            largura: esp_fundo + 0.5,         # largura do rasgo
            ferramenta: 'r_f',
            categoria: 'Transfer_vertical_saw_cut',
          }
        end

        # Canal de fundo na base e topo (rebaixado)
        if [:base, :topo].include?(tipo) && mi.tipo_fundo == Config::FUNDO_REBAIXADO
          esp_fundo = mi.espessura_fundo_real
          usinagens << {
            descricao: 'Rasgo de serra',
            profundidade: 8,
            comprimento: peca.comprimento.to_f,
            largura: esp_fundo + 0.5,
            ferramenta: 'r_f',
            categoria: 'Transfer_vertical_saw_cut',
          }
        end

        # Canal fundo gaveta
        if [:gaveta_lateral_esq, :gaveta_lateral_dir].include?(tipo)
          usinagens << {
            descricao: 'Rasgo para fundo de gaveta',
            profundidade: 8,
            comprimento: peca.largura.to_f,
            largura: 7,
            ferramenta: 'r_f',
            categoria: 'Transfer_vertical_saw_cut',
          }
        end

        usinagens
      end

      # Calcula posicoes das dobradicas
      def self.calcular_posicoes_dobradica(altura, qtd)
        return [] if qtd <= 0

        margem_sup = 100  # 100mm do topo
        margem_inf = 100  # 100mm da base

        if qtd == 1
          [altura / 2.0]
        elsif qtd == 2
          [margem_inf, altura - margem_sup]
        else
          posicoes = [margem_inf, altura - margem_sup]
          espaco = (altura - margem_inf - margem_sup) / (qtd - 1).to_f
          (1...(qtd - 1)).each do |i|
            posicoes << (margem_inf + espaco * i)
          end
          posicoes.sort
        end
      end

      # ═══════════════════════════════════════════════════════════════
      # DIALOG DE CONFIGURACAO DE EXPORTACAO
      # ═══════════════════════════════════════════════════════════════

      # Mostra dialog para configurar opcoes de exportacao antes de gerar JSON
      def self.mostrar_dialog_exportacao
        model = Sketchup.active_model
        modulos = Utils.listar_modulos

        if modulos.empty?
          ::UI.messagebox('Nenhum modulo Ornato encontrado no projeto.', MB_OK)
          return
        end

        html = gerar_html_dialog_exportacao(model, modulos.length)

        dialog = ::UI::HtmlDialog.new(
          dialog_title: 'Ornato — Exportar JSON',
          preferences_key: 'ornato_export',
          width: 500,
          height: 480,
          resizable: false,
          style: ::UI::HtmlDialog::STYLE_DIALOG
        )

        dialog.set_html(html)

        dialog.add_action_callback('exportar') do |_ctx, dados_json|
          begin
            dados = JSON.parse(dados_json)
            opcoes = {
              cliente: dados['cliente'],
              projeto: dados['projeto'],
              codigo: dados['codigo'],
              vendedor: dados['vendedor'],
            }
            dialog.close
            exportar_projeto(opcoes)
          rescue => e
            puts "[Ornato] Erro no dialog export: #{e.message}"
          end
        end

        dialog.add_action_callback('cancelar') do |_ctx|
          dialog.close
        end

        dialog.show
      end

      # HTML do dialog de exportacao
      def self.gerar_html_dialog_exportacao(model, qtd_modulos)
        nome_projeto = model.title.empty? ? 'Projeto Ornato' : model.title

        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <style>
              * { box-sizing: border-box; margin: 0; padding: 0; }
              body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: #f5f5f5; padding: 20px; color: #333;
              }
              .header {
                background: #e67e22; color: white; padding: 15px 20px;
                border-radius: 8px; margin-bottom: 20px; text-align: center;
              }
              .header h2 { font-size: 18px; margin-bottom: 4px; }
              .header small { opacity: 0.9; font-size: 12px; }
              .info-bar {
                background: #fff3e0; border-left: 4px solid #e67e22;
                padding: 10px 15px; margin-bottom: 20px; border-radius: 4px;
                font-size: 13px;
              }
              .form-group { margin-bottom: 14px; }
              label {
                display: block; font-weight: 600; margin-bottom: 4px;
                font-size: 13px; color: #555;
              }
              input[type="text"] {
                width: 100%; padding: 8px 12px; border: 1px solid #ddd;
                border-radius: 6px; font-size: 14px; outline: none;
                transition: border-color 0.2s;
              }
              input[type="text"]:focus { border-color: #e67e22; }
              .buttons {
                display: flex; gap: 10px; margin-top: 20px;
                justify-content: flex-end;
              }
              .btn {
                padding: 10px 24px; border: none; border-radius: 6px;
                font-size: 14px; font-weight: 600; cursor: pointer;
              }
              .btn-primary {
                background: #e67e22; color: white;
              }
              .btn-primary:hover { background: #d35400; }
              .btn-secondary {
                background: #e0e0e0; color: #555;
              }
              .btn-secondary:hover { background: #ccc; }
              .checkbox-row {
                display: flex; align-items: center; gap: 8px;
                margin-bottom: 8px; font-size: 13px;
              }
              .checkbox-row input { width: 16px; height: 16px; }
            </style>
          </head>
          <body>
            <div class="header">
              <h2>Exportar JSON para Producao</h2>
              <small>Formato compativel com UpMobb / Ornato ERP</small>
            </div>

            <div class="info-bar">
              <strong>#{qtd_modulos} modulo(s)</strong> encontrado(s) no projeto.
              O JSON incluira todas as pecas, fitas, ferragens e usinagens.
            </div>

            <div class="form-group">
              <label>Nome do Projeto</label>
              <input type="text" id="projeto" value="#{nome_projeto}">
            </div>

            <div class="form-group">
              <label>Cliente</label>
              <input type="text" id="cliente" value="">
            </div>

            <div class="form-group">
              <label>Codigo Interno</label>
              <input type="text" id="codigo" value="01">
            </div>

            <div class="form-group">
              <label>Vendedor / Projetista</label>
              <input type="text" id="vendedor" value="Ornato">
            </div>

            <hr style="margin: 16px 0; border: none; border-top: 1px solid #e0e0e0;">

            <div class="checkbox-row">
              <input type="checkbox" id="chk_usinagem" checked>
              <label for="chk_usinagem" style="font-weight: normal;">Exportar usinagens (CNC)</label>
            </div>
            <div class="checkbox-row">
              <input type="checkbox" id="chk_furos" checked>
              <label for="chk_furos" style="font-weight: normal;">Exportar furos (minifix, cavilha, sistema 32)</label>
            </div>
            <div class="checkbox-row">
              <input type="checkbox" id="chk_ferragens" checked>
              <label for="chk_ferragens" style="font-weight: normal;">Incluir ferragens nas pecas</label>
            </div>

            <div class="buttons">
              <button class="btn btn-secondary" onclick="sketchup.cancelar()">Cancelar</button>
              <button class="btn btn-primary" onclick="doExport()">Exportar JSON</button>
            </div>

            <script>
              function doExport() {
                var dados = {
                  projeto: document.getElementById('projeto').value,
                  cliente: document.getElementById('cliente').value,
                  codigo: document.getElementById('codigo').value,
                  vendedor: document.getElementById('vendedor').value,
                  usinagem: document.getElementById('chk_usinagem').checked,
                  furos: document.getElementById('chk_furos').checked,
                  ferragens: document.getElementById('chk_ferragens').checked
                };
                sketchup.exportar(JSON.stringify(dados));
              }
            </script>
          </body>
          </html>
        HTML
      end

    end
  end
end
