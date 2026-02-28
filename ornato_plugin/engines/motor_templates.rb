# ornato_plugin/engines/motor_templates.rb — Sistema de templates de módulos

module Ornato
  module Engines
    class MotorTemplates

      TEMPLATES_DIR = File.join(PLUGIN_DIR, 'templates').freeze

      # Templates pré-configurados
      CATALOGO = {
        # ═══ COZINHA ═══
        'coz_sup_1p' => {
          nome: 'Superior 1 Porta', categoria: :cozinha, tipo: :superior,
          largura: 600, altura: 700, profundidade: 350,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :suspensa, fixacao: :minifix,
          agregados: [{ tipo: :porta, opts: { sobreposicao: :total } }]
        },
        'coz_sup_2p' => {
          nome: 'Superior 2 Portas', categoria: :cozinha, tipo: :superior,
          largura: 800, altura: 700, profundidade: 350,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :suspensa, fixacao: :minifix,
          agregados: [{ tipo: :porta_dupla, opts: {} }]
        },
        'coz_sup_basculante' => {
          nome: 'Superior Basculante', categoria: :cozinha, tipo: :superior,
          largura: 600, altura: 350, profundidade: 350,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :suspensa, fixacao: :minifix,
          agregados: [{ tipo: :porta, opts: { tipo: :basculante } }]
        },
        'coz_sup_escorredor' => {
          nome: 'Superior Escorredor', categoria: :cozinha, tipo: :superior,
          largura: 600, altura: 700, profundidade: 350,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :sem_fundo,
          tipo_base: :suspensa, fixacao: :minifix,
          agregados: [
            { tipo: :porta, opts: { sobreposicao: :total } },
            { tipo: :prateleira, opts: { posicao: 350 } }
          ]
        },
        'coz_inf_1p' => {
          nome: 'Inferior 1 Porta', categoria: :cozinha, tipo: :inferior,
          largura: 450, altura: 850, profundidade: 560,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :pes_regulaveis, fixacao: :minifix,
          agregados: [
            { tipo: :porta, opts: { sobreposicao: :total } },
            { tipo: :prateleira, opts: { posicao: 300 } }
          ]
        },
        'coz_inf_2p' => {
          nome: 'Inferior 2 Portas', categoria: :cozinha, tipo: :inferior,
          largura: 800, altura: 850, profundidade: 560,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :pes_regulaveis, fixacao: :minifix,
          agregados: [
            { tipo: :porta_dupla, opts: {} },
            { tipo: :prateleira, opts: { posicao: 300 } }
          ]
        },
        'coz_inf_3gav' => {
          nome: 'Inferior 3 Gavetas', categoria: :cozinha, tipo: :inferior,
          largura: 600, altura: 850, profundidade: 560,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :pes_regulaveis, fixacao: :minifix,
          agregados: [{ tipo: :gavetas, opts: { quantidade: 3, tipo_corredica: :telescopica } }]
        },
        'coz_inf_pia' => {
          nome: 'Inferior Pia', categoria: :cozinha, tipo: :inferior,
          largura: 800, altura: 850, profundidade: 560,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :pes_regulaveis, fixacao: :minifix,
          agregados: [{ tipo: :porta_dupla, opts: {} }]
          # Sem topo (bancada por cima) e com recorte para sifão
        },
        'coz_torre_forno' => {
          nome: 'Torre Forno', categoria: :cozinha, tipo: :torre,
          largura: 600, altura: 2100, profundidade: 560,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :pes_regulaveis, fixacao: :minifix,
          agregados: [
            { tipo: :divisoria, opts: { direcao: :horizontal, posicao: 850 } },
            # Vão inferior: forno
            # Vão superior: micro + prateleira
          ]
        },
        'coz_torre_despenseiro' => {
          nome: 'Torre Despenseiro', categoria: :cozinha, tipo: :torre,
          largura: 450, altura: 2100, profundidade: 560,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :pes_regulaveis, fixacao: :minifix,
          agregados: [
            { tipo: :porta, opts: { sobreposicao: :total } },
            { tipo: :prateleira, opts: { posicao: 400 } },
            { tipo: :prateleira, opts: { posicao: 800 } },
            { tipo: :prateleira, opts: { posicao: 1200 } },
            { tipo: :prateleira, opts: { posicao: 1600 } },
          ]
        },

        # ═══ QUARTO ═══
        'qto_guarda_roupa_2p_correr' => {
          nome: 'Guarda-Roupa 2P Correr', categoria: :quarto, tipo: :torre,
          largura: 1800, altura: 2400, profundidade: 600,
          espessura: 18, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :pes_regulaveis, fixacao: :minifix,
          agregados: [
            { tipo: :divisoria, opts: { direcao: :vertical, posicao: 900 } },
            { tipo: :divisoria, opts: { direcao: :horizontal, posicao: 1000 } },  # vão esq
          ]
        },
        'qto_criado_mudo' => {
          nome: 'Criado-Mudo 2 Gavetas', categoria: :quarto, tipo: :inferior,
          largura: 500, altura: 500, profundidade: 420,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :pes_regulaveis, fixacao: :minifix,
          agregados: [{ tipo: :gavetas, opts: { quantidade: 2, tipo_corredica: :telescopica } }]
        },
        'qto_comoda' => {
          nome: 'Cômoda 4 Gavetas', categoria: :quarto, tipo: :inferior,
          largura: 1000, altura: 850, profundidade: 500,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :pes_regulaveis, fixacao: :minifix,
          agregados: [{ tipo: :gavetas, opts: { quantidade: 4, tipo_corredica: :oculta } }]
        },
        'qto_painel_tv' => {
          nome: 'Painel TV', categoria: :quarto, tipo: :painel,
          largura: 1800, altura: 1200, profundidade: 30,
          espessura: 18, montagem: :laterais_entre, tipo_fundo: :sem_fundo,
          tipo_base: :suspensa, fixacao: :minifix,
          agregados: []
        },

        # ═══ BANHEIRO ═══
        'ban_gabinete_suspenso' => {
          nome: 'Gabinete Suspenso', categoria: :banheiro, tipo: :superior,
          largura: 800, altura: 500, profundidade: 420,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :suspensa, fixacao: :minifix,
          agregados: [
            { tipo: :porta, opts: { sobreposicao: :total } },
            { tipo: :gavetas, opts: { quantidade: 1, tipo_corredica: :oculta } }
          ]
        },
        'ban_espelheira' => {
          nome: 'Espelheira', categoria: :banheiro, tipo: :superior,
          largura: 800, altura: 600, profundidade: 150,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :suspensa, fixacao: :minifix,
          agregados: [
            { tipo: :porta, opts: { tipo_porta: :vidro_inteiro, material_vidro: 'Espelho Comum 4mm' } },
            { tipo: :prateleira, opts: { posicao: 300 } }
          ]
        },

        # ═══ ESCRITÓRIO ═══
        'esc_estante' => {
          nome: 'Estante 5 Prateleiras', categoria: :escritorio, tipo: :estante,
          largura: 800, altura: 2100, profundidade: 300,
          espessura: 18, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :pes_regulaveis, fixacao: :minifix,
          agregados: [
            { tipo: :prateleira, opts: { posicao: 350 } },
            { tipo: :prateleira, opts: { posicao: 700 } },
            { tipo: :prateleira, opts: { posicao: 1050 } },
            { tipo: :prateleira, opts: { posicao: 1400 } },
            { tipo: :prateleira, opts: { posicao: 1750 } },
          ]
        },
        'esc_gaveteiro_volante' => {
          nome: 'Gaveteiro Volante', categoria: :escritorio, tipo: :gaveteiro,
          largura: 400, altura: 550, profundidade: 500,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :rodape, fixacao: :minifix,
          agregados: [{ tipo: :gavetas, opts: { quantidade: 3, tipo_corredica: :telescopica } }]
        },

        # ═══ SALA ═══
        'sala_rack_tv' => {
          nome: 'Rack TV', categoria: :sala, tipo: :inferior,
          largura: 1800, altura: 500, profundidade: 450,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :pes_regulaveis, fixacao: :minifix,
          agregados: [
            { tipo: :divisoria, opts: { direcao: :vertical, posicao: 600 } },
            { tipo: :divisoria, opts: { direcao: :vertical, posicao: 1200 } },
          ]
        },
        'sala_bar_adega' => {
          nome: 'Bar/Adega', categoria: :sala, tipo: :inferior,
          largura: 600, altura: 1200, profundidade: 400,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :pes_regulaveis, fixacao: :minifix,
          agregados: [
            { tipo: :divisoria, opts: { direcao: :horizontal, posicao: 600 } },
            { tipo: :porta, opts: { tipo_porta: :vidro } },
          ]
        },

        # ═══ LAVANDERIA ═══
        'lav_armario_sup' => {
          nome: 'Armário Superior Lavanderia', categoria: :lavanderia, tipo: :superior,
          largura: 1000, altura: 700, profundidade: 350,
          espessura: 15, montagem: :laterais_entre, tipo_fundo: :rebaixado,
          tipo_base: :suspensa, fixacao: :minifix,
          agregados: [
            { tipo: :porta_dupla, opts: {} },
            { tipo: :prateleira, opts: { posicao: 350 } }
          ]
        },
      }.freeze

      # Lista templates por categoria
      def self.listar_por_categoria(categoria = nil)
        if categoria
          CATALOGO.select { |_, v| v[:categoria] == categoria }
        else
          CATALOGO
        end
      end

      def self.categorias
        CATALOGO.values.map { |v| v[:categoria] }.uniq.sort
      end

      # Cria módulo a partir de template
      def self.criar_de_template(template_id, posicao = nil, overrides = {})
        tmpl = CATALOGO[template_id]
        return nil unless tmpl

        params = tmpl.merge(overrides)

        mi = Models::ModuloInfo.new(
          nome:            params[:nome],
          tipo:            params[:tipo],
          largura:         params[:largura],
          altura:          params[:altura],
          profundidade:    params[:profundidade],
          espessura_corpo: params[:espessura] || params[:espessura_corpo],
          montagem:        params[:montagem],
          tipo_fundo:      params[:tipo_fundo],
          tipo_base:       params[:tipo_base],
          fixacao:         params[:fixacao],
          ambiente:        params[:ambiente] || params[:categoria].to_s.capitalize,
          material_corpo:  params[:material_corpo] || 'MDF Branco TX 15mm',
          material_frente: params[:material_frente] || 'MDF Carvalho Hanover 15mm',
        )

        grupo = MotorCaixa.construir(mi, posicao)
        return nil unless grupo

        # Aplica agregados do template
        if params[:agregados] && mi.vao_principal
          params[:agregados].each do |agreg|
            vao = mi.vao_principal  # usa vão principal (pode melhorar com sub-vãos)
            case agreg[:tipo]
            when :porta
              MotorAgregados.adicionar_porta(mi, vao, agreg[:opts] || {})
            when :porta_dupla
              MotorAgregados.adicionar_porta_dupla(mi, vao, agreg[:opts] || {})
            when :prateleira
              MotorAgregados.adicionar_prateleira(mi, vao, agreg[:opts] || {})
            when :gavetas
              MotorAgregados.adicionar_gavetas(mi, vao,
                agreg[:opts][:quantidade] || 3, agreg[:opts] || {})
            when :gaveta
              MotorAgregados.adicionar_gaveta(mi, vao, agreg[:opts] || {})
            when :divisoria
              MotorAgregados.adicionar_divisoria(mi, vao,
                agreg[:opts][:direcao] || :vertical, agreg[:opts] || {})
            end
          end
        end

        grupo
      end

      # Salva módulo atual como template customizado
      def self.salvar_template(grupo, nome, categoria = :customizado)
        mi = Models::ModuloInfo.carregar_do_grupo(grupo)
        return nil unless mi

        template = {
          nome: nome,
          categoria: categoria,
          tipo: mi.tipo,
          largura: mi.largura,
          altura: mi.altura,
          profundidade: mi.profundidade,
          espessura: mi.espessura_corpo,
          montagem: mi.montagem,
          tipo_fundo: mi.tipo_fundo,
          tipo_base: mi.tipo_base,
          fixacao: mi.fixacao,
          material_corpo: mi.material_corpo,
          material_frente: mi.material_frente,
          material_fundo: mi.material_fundo,
          fita_corpo: mi.fita_corpo,
          fita_frente: mi.fita_frente,
          salvo_em: Time.now.to_s
        }

        # Salva em arquivo
        Dir.mkdir(TEMPLATES_DIR) unless File.directory?(TEMPLATES_DIR)
        id = "custom_#{nome.downcase.gsub(/\s+/, '_').gsub(/[^a-z0-9_]/, '')}"
        path = File.join(TEMPLATES_DIR, "#{id}.json")

        File.open(path, 'w') do |f|
          f.write(Utils.to_json(template))
        end

        puts "[Ornato] Template '#{nome}' salvo em #{path}"
        id
      end

      # Carrega templates customizados do disco
      def self.carregar_customizados
        return {} unless File.directory?(TEMPLATES_DIR)

        customizados = {}
        Dir.glob(File.join(TEMPLATES_DIR, '*.json')).each do |path|
          begin
            conteudo = File.read(path)
            data = Utils.parse_json(conteudo)
            id = File.basename(path, '.json')
            customizados[id] = data
          rescue => e
            puts "[Ornato] Erro ao carregar template #{path}: #{e.message}"
          end
        end

        customizados
      end
    end
  end
end
