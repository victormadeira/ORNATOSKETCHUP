# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# ui/toolbar.rb — Toolbar principal do plugin
#
# Cria a toolbar com botões para as ações principais:
#   - Novo módulo (dropdown com tipos)
#   - Painel de propriedades
#   - Validar
#   - Exportar
#   - Catálogo
#   - Configurações

module Ornato
  module UI
    class Toolbar
      TOOLBAR_NAME = 'ORNATO'.freeze

      def initialize
        @toolbar = nil
        @commands = {}
      end

      # Cria e exibe a toolbar.
      def setup(model)
        @toolbar = ::UI::Toolbar.new(TOOLBAR_NAME)

        # ── Criacao (sempre habilitado) ──
        add_command(:new_module, 'Novo Modulo', 'Criar novo modulo parametrico', 'icon_new_module') do
          show_module_creation_dialog
        end

        add_command(:properties, 'Propriedades', 'Abrir painel de propriedades', 'icon_properties') do
          MainPanel.instance.show
        end

        @toolbar.add_separator

        # ── Acoes sobre selecao (habilitam so com modulo selecionado) ──
        add_smart_command(:validate, 'Validar', 'Validar modulo selecionado', 'icon_validate') do
          validate_selected_module
        end

        add_smart_command(:add_aggregate, 'Agregar', 'Adicionar porta/gaveta/prateleira', 'icon_aggregate') do
          show_aggregate_dialog
        end

        add_smart_command(:add_accessory, 'Acessorio', 'Adicionar acessorio ao modulo', 'icon_accessory') do
          show_accessory_dialog
        end

        add_smart_command(:swap_hardware, 'Ferragem', 'Trocar tipo de ferragem', 'icon_hardware') do
          show_hardware_swap_dialog
        end

        add_smart_command(:connect_modules, 'Conectar', 'Conectar modulos lado-a-lado', 'icon_connect') do
          show_connect_modules_dialog
        end

        add_smart_command(:add_testeira, 'Testeira', 'Adicionar testeira (enchimento)', 'icon_testeira') do
          show_testeira_dialog
        end

        # Toggle portas (inspirado Gabster)
        add_toggle_command(:toggle_fronts, 'Portas', 'Mostrar/ocultar portas e frentes', 'icon_toggle') do
          toggle_front_visibility
        end

        @toolbar.add_separator

        # ── Projeto (sempre habilitado) ──
        add_command(:export, 'Exportar', 'Exportar projeto para JSON', 'icon_export') do
          export_project
        end

        add_command(:config, 'Config', 'Configuracoes do plugin', 'icon_config') do
          show_config_panel
        end

        @toolbar.show
        Core.logger.info('Toolbar criada')
      end

      # Retorna a toolbar.
      def toolbar
        @toolbar
      end

      private

      def add_command(id, label, tooltip, icon_name, &block)
        cmd = ::UI::Command.new(label, &block)
        cmd.tooltip = tooltip
        cmd.status_bar_text = tooltip
        cmd.small_icon = icon_path(icon_name, 24)
        cmd.large_icon = icon_path(icon_name, 32)
        @commands[id] = cmd
        @toolbar.add_item(cmd)
      end

      # Comando que se desabilita quando nao ha modulo ORNATO selecionado
      def add_smart_command(id, label, tooltip, icon_name, &block)
        cmd = ::UI::Command.new(label, &block)
        cmd.tooltip = tooltip
        cmd.status_bar_text = tooltip
        cmd.small_icon = icon_path(icon_name, 24)
        cmd.large_icon = icon_path(icon_name, 32)
        cmd.set_validation_proc do
          sel = Sketchup.active_model&.selection
          if sel && sel.any? { |e| LevelDetector.modulo_ornato?(e) rescue false }
            MF_ENABLED
          else
            MF_GRAYED
          end
        end
        @commands[id] = cmd
        @toolbar.add_item(cmd)
      end

      # Toggle command com estado on/off
      def add_toggle_command(id, label, tooltip, icon_name, &block)
        cmd = ::UI::Command.new(label, &block)
        cmd.tooltip = tooltip
        cmd.status_bar_text = tooltip
        cmd.small_icon = icon_path(icon_name, 24)
        cmd.large_icon = icon_path(icon_name, 32)
        cmd.set_validation_proc do
          @fronts_visible == false ? MF_CHECKED : MF_ENABLED
        end
        @commands[id] = cmd
        @toolbar.add_item(cmd)
      end

      def toggle_front_visibility
        model = Sketchup.active_model
        return unless model

        @fronts_visible = @fronts_visible.nil? ? false : !@fronts_visible
        tipos_front = %w[porta frente_gaveta basculante]
        dc = 'dynamic_attributes'
        count = 0

        model.start_operation('ORNATO Toggle Portas', true)

        model.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)

          # Verificar se é módulo ORNATO
          mod_def = entity.definition
          next unless mod_def.get_attribute(dc, 'orn_marcado') == true
          next if mod_def.get_attribute(dc, 'orn_tipo_modulo').to_s.empty?

          # Percorrer peças internas
          mod_def.entities.each do |sub|
            next unless sub.is_a?(Sketchup::ComponentInstance) || sub.is_a?(Sketchup::Group)
            sub_def = sub.respond_to?(:definition) ? sub.definition : nil
            next unless sub_def
            tipo_peca = sub_def.get_attribute(dc, 'orn_tipo_peca').to_s
            if tipos_front.include?(tipo_peca)
              sub.visible = @fronts_visible
              count += 1
            end
          end
        end

        model.commit_operation
        estado = @fronts_visible ? 'visiveis' : 'ocultas'
        Sketchup.status_text = "ORNATO: #{count} portas/frentes #{estado}"
      end

      def icon_path(name, size)
        dir = File.join(File.dirname(__FILE__), '..', 'data', 'icons')
        path = File.join(dir, "#{name}_#{size}.png")
        File.exist?(path) ? path : ''
      end

      def show_module_creation_dialog
        # Passo 1: escolher categoria e tipo
        categorias = Ornato::MENU_CATEGORIES
        cat_labels = categorias.keys
        prompts_1 = ['Ambiente:']
        defaults_1 = [cat_labels.first]
        lista_1 = [cat_labels.join('|')]

        r1 = ::UI.inputbox(prompts_1, defaults_1, lista_1, 'Novo Modulo — Passo 1/2')
        return unless r1

        categoria = r1[0]
        tipos = categorias[categoria] || categorias.values.first
        configs = tipos.map { |t| [t, Engineering::BoxBuilder::CONFIGS[t]] }.select { |_, c| c }
        tipo_labels = configs.map { |_, c| c[:descricao] }

        prompts_t = ['Tipo:']
        defaults_t = [tipo_labels.first]
        lista_t = [tipo_labels.join('|')]

        rt = ::UI.inputbox(prompts_t, defaults_t, lista_t, "#{categoria} — Tipo")
        return unless rt

        tipo_sym = configs.find { |_, c| c[:descricao] == rt[0] }&.first
        return ::UI.messagebox("Tipo invalido") unless tipo_sym

        config = Engineering::BoxBuilder::CONFIGS[tipo_sym]
        defs = Ornato::SMART_DEFAULTS[tipo_sym] || { l: 60, p: 55, a: 72 }

        # Passo 2: dimensoes com defaults inteligentes
        prompts_2 = ['Largura (cm):', 'Profundidade (cm):', 'Altura (cm):',
                     'Espessura corpo (mm):', 'Material:', 'Nome:']
        defaults_2 = [defs[:l].to_s, defs[:p].to_s, defs[:a].to_s,
                      '18', 'MDF 18mm Branco TX', '']
        lista_2 = ['', '', '', '15|18|25|30|36',
                   'MDF 15mm Branco TX|MDF 18mm Branco TX|MDF 25mm Branco TX|MDP 15mm Branco TX|MDP 18mm Branco TX',
                   '']

        r2 = ::UI.inputbox(prompts_2, defaults_2, lista_2, "Novo #{config[:descricao]}")
        return unless r2

        begin
          instance = Engineering::BoxBuilder.criar(
            tipo_sym,
            largura: r2[0].to_f,
            profundidade: r2[1].to_f,
            altura: r2[2].to_f,
            espessura: r2[3].to_f,
            material: r2[4],
            nome: r2[5].empty? ? nil : r2[5]
          )
          nome_def = instance.definition.name
          qtd_pecas = instance.definition.entities.count { |e|
            (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) &&
            e.respond_to?(:definition) &&
            (e.definition.get_attribute('dynamic_attributes', 'orn_marcado') == true rescue false)
          }
          Sketchup.status_text = "ORNATO: #{nome_def} criado — #{qtd_pecas} pecas"
        rescue => e
          ::UI.messagebox("Erro ao criar modulo:\n#{e.message}")
        end
      end

      def validate_selected_module
        model = Sketchup.active_model
        selection = model.selection

        # Validar TODOS os modulos ORNATO selecionados
        modulos = selection.select { |e| LevelDetector.modulo_ornato?(e) rescue false }
        if modulos.empty?
          ::UI.messagebox("Nenhum modulo ORNATO selecionado.\n\nSelecione um ou mais modulos e tente novamente.")
          return
        end

        total_erros = 0
        total_avisos = 0
        msg_global = ""

        modulos.each do |modulo|
          begin
            alertas = Engineering::CapacityValidator.validar(modulo)
            nome = modulo.definition.get_attribute('dynamic_attributes', 'orn_nome') || modulo.definition.name

            if alertas.empty?
              msg_global += "#{nome}: OK\n\n"
            else
              erros = alertas.select { |a| a[:nivel] == :erro }
              avisos = alertas.select { |a| a[:nivel] == :aviso }
              total_erros += erros.length
              total_avisos += avisos.length

              msg_global += "#{nome}:\n"
              erros.each { |e| msg_global += "  [ERRO] #{e[:mensagem]}\n    → #{e[:sugestao]}\n" }
              avisos.each { |a| msg_global += "  [AVISO] #{a[:mensagem]}\n    → #{a[:sugestao]}\n" }
              msg_global += "\n"
            end
          rescue => e
            msg_global += "#{modulo.definition.name}: Erro — #{e.message}\n\n"
          end
        end

        resumo = "Validacao: #{modulos.length} modulo(s)"
        resumo += " — #{total_erros} erro(s), #{total_avisos} aviso(s)" if total_erros > 0 || total_avisos > 0
        resumo += " — Tudo OK!" if total_erros == 0 && total_avisos == 0
        Sketchup.status_text = resumo

        # Sincronizar com painel se estiver aberto
        panel = MainPanel.instance
        if panel.visible?
          todas_alertas = []
          modulos.each do |mod|
            alertas = Engineering::CapacityValidator.validar(mod) rescue []
            nome = mod.definition.get_attribute('dynamic_attributes', 'orn_nome') || mod.definition.name rescue '?'
            alertas.each { |a| a[:modulo] = nome }
            todas_alertas.concat(alertas)
          end
          panel.bridge&.send_to_js('ornatoReceiveAlerts', { alerts: todas_alertas })
        end

        ::UI.messagebox("#{resumo}\n\n#{msg_global}")
      end

      def export_project
        model = Sketchup.active_model

        # Contar modulos ORNATO no modelo
        todos_modulos = model.entities.select { |e|
          (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) &&
          (LevelDetector.modulo_ornato?(e) rescue false)
        }
        selecionados = model.selection.select { |e|
          LevelDetector.modulo_ornato?(e) rescue false
        }

        escopo = if selecionados.any?
          "#{selecionados.length} modulo(s) selecionado(s)"
        else
          "#{todos_modulos.length} modulo(s) no modelo"
        end

        prompts = ['Cliente:', 'Projeto:', 'Codigo:', 'Vendedor:', 'Destino:', 'Escopo:']
        defaults = ['', '', '', '', 'Arquivo JSON', escopo]
        lista = ['', '', '', '', 'Arquivo JSON|Enviar ao Servidor',
                 selecionados.any? ? "#{escopo}|Todos (#{todos_modulos.length})" : escopo]

        result = ::UI.inputbox(prompts, defaults, lista, 'Exportar Projeto ORNATO')
        return unless result

        cliente = result[0]
        projeto = result[1]
        codigo = result[2]
        vendedor = result[3]
        destino = result[4]

        if destino == 'Enviar ao Servidor'
          url = defined?(GlobalConfig) ? GlobalConfig.get(:server_url, 'http://localhost:3000/api/cnc/lotes/importar') : 'http://localhost:3000/api/cnc/lotes/importar'
          success = Engineering::ExportBridge.exportar_e_enviar(url,
            cliente: cliente, projeto: projeto, codigo: codigo, vendedor: vendedor)
          if success
            Sketchup.status_text = "ORNATO: exportacao enviada ao servidor"
          else
            ::UI.messagebox("Falha ao enviar. Verifique a conexao com o servidor.")
          end
        else
          success = Engineering::ExportBridge.exportar_para_arquivo(nil,
            cliente: cliente, projeto: projeto, codigo: codigo, vendedor: vendedor)
          Sketchup.status_text = "ORNATO: exportacao concluida" if success
        end
      end

      def show_config_panel
        prompts = ['Espessura padrao corpo (mm):', 'Material padrao:', 'Tipo dobradica:',
                   'Tipo corredica:', 'Tipo fixacao:']
        defaults = ['18', 'MDF 18mm Branco TX', 'Reta (Sobreposta)',
                    'Telescopica', 'Minifix']
        lista = ['15|18|25|30|36',
                 'MDF 15mm Branco TX|MDF 18mm Branco TX|MDF 25mm Branco TX|MDP 15mm Branco TX|MDP 18mm Branco TX',
                 'Reta (Sobreposta)|Curva (Meio-Esquadro)|Supercurva (Embutida)',
                 'Telescopica|Oculta Tandem|Quadro Metalico|Tandembox',
                 'Minifix|Confirmat|Cavilha|Minifix+Cavilha']

        result = ::UI.inputbox(prompts, defaults, lista, 'Configuracoes ORNATO')
        return unless result

        cfg = defined?(Engineering::GlobalConfig) ? Engineering::GlobalConfig : nil
        if cfg
          cfg.set(:espessura_padrao, result[0].to_f)
          cfg.set(:material_padrao, result[1])
          cfg.set(:dobradica_padrao, result[2])
          cfg.set(:corredica_padrao, result[3])
          cfg.set(:fixacao_padrao, result[4])
          Sketchup.status_text = "ORNATO: Configuracoes salvas"
        else
          ::UI.messagebox("GlobalConfig nao disponivel. Configuracoes nao foram salvas.")
        end
      end

      # ── Dialogo de agregados (porta/gaveta/prateleira/divisoria) ──

      def show_aggregate_dialog
        modulo = find_selected_module
        return unless modulo

        # Detectar tipo do modulo para filtrar opcoes
        dc = 'dynamic_attributes'
        def_ = modulo.respond_to?(:definition) ? modulo.definition : nil
        tipo_str = def_ ? (def_.get_attribute(dc, 'orn_tipo_modulo') || '').to_s : ''
        tipo_sym = tipo_str.to_sym

        permitidos = Ornato::AGREGADOS_POR_TIPO[tipo_sym] || [:porta_unica, :prateleira, :divisoria]
        labels = permitidos.map { |t| Ornato::AGREGADO_LABELS[t] || t.to_s }

        prompts = ['Tipo:', 'Quantidade:']
        defaults = [labels.first, '1']
        lista = [labels.join('|'), '1|2|3|4|5|6']

        nome = def_ ? (def_.get_attribute(dc, 'orn_nome') || def_.name) : 'Modulo'
        result = ::UI.inputbox(prompts, defaults, lista, "Adicionar a #{nome}")
        return unless result

        tipo_label = result[0]
        qtd = result[1].to_i
        tipo_agg = permitidos[labels.index(tipo_label)] || permitidos.first

        begin
          case tipo_agg
          when :porta_unica
            Engineering::AggregateBuilder.adicionar_porta(modulo, tipo: :unica)
          when :porta_dupla
            Engineering::AggregateBuilder.adicionar_porta(modulo, tipo: :dupla)
          when :porta_correr
            Engineering::AggregateBuilder.adicionar_portas_correr(modulo, quantidade: [qtd, 2].max)
          when :basculante
            Engineering::AggregateBuilder.adicionar_basculante(modulo)
          when :prateleira
            qtd.times do |i|
              pct = (i + 1).to_f / (qtd + 1)
              Engineering::AggregateBuilder.adicionar_prateleira(modulo, posicao_z_pct: pct)
            end
          when :gaveta
            Engineering::AggregateBuilder.criar_conjunto_gavetas(modulo.definition, qtd, 15)
          when :divisoria
            qtd.times do |i|
              pct = (i + 1).to_f / (qtd + 1)
              Engineering::AggregateBuilder.adicionar_divisoria(modulo, posicao_x_pct: pct)
            end
          end
          Sketchup.status_text = "#{tipo_label} adicionado(a) a #{nome}"
        rescue => e
          ::UI.messagebox("Erro ao adicionar #{tipo_label}:\n#{e.message}")
        end
      end

      # ── Dialogo de acessorios ──

      def show_accessory_dialog
        modulo = find_selected_module
        return unless modulo

        acessorios = Engineering::AccessoryBuilder::ACESSORIOS
        nomes = acessorios.map { |k, v| "#{v[:descricao]}=#{k}" }
        labels = acessorios.map { |_, v| v[:descricao] }

        prompts = ['Acessorio:', 'Posicao vertical (%)']
        defaults = [labels.first, '50']
        lista = [labels.join('|'), '']

        result = ::UI.inputbox(prompts, defaults, lista, 'Adicionar Acessorio')
        return unless result

        selected_label = result[0]
        posicao_pct = result[1].to_f / 100.0

        tipo_sym = acessorios.find { |_, v| v[:descricao] == selected_label }&.first
        unless tipo_sym
          ::UI.messagebox("Acessorio invalido: #{selected_label}")
          return
        end

        begin
          Engineering::AccessoryBuilder.adicionar(modulo, tipo: tipo_sym, posicao_z_pct: posicao_pct)
          ::UI.messagebox("#{selected_label} adicionado com sucesso!")
        rescue => e
          ::UI.messagebox("Erro ao adicionar acessorio:\n#{e.message}")
        end
      end

      # ── Dialogo de troca de ferragem ──

      # Opcoes cascateadas por categoria de ferragem
      # Mapeamento explícito label → symbol para evitar erros de conversão regex
      HARDWARE_OPTIONS = {
        'Corredica'   => %w[Telescopica Oculta Tandembox Quadro\ Metalico],
        'Dobradica'   => %w[Reta\ (Sobreposta) Curva\ (Meio-Esquadro) Supercurva\ (Embutida)],
        'Fixacao'     => %w[Minifix Confirmat Cavilha Minifix+Cavilha],
        'Articulador' => %w[Aventos\ HF Aventos\ HL Aventos\ HK-S Pistao\ Gas],
        'Pe'          => %w[Regulavel Rodizio Sapata Suspenso],
      }.freeze

      HARDWARE_SYMBOL_MAP = {
        # Corredica
        'Telescopica'           => :telescopica,
        'Oculta'                => :oculta,
        'Tandembox'             => :tandembox,
        'Quadro Metalico'       => :quadro_metalico,
        # Dobradica
        'Reta (Sobreposta)'     => :reta_sobreposta,
        'Curva (Meio-Esquadro)' => :curva_meio_esquadro,
        'Supercurva (Embutida)' => :supercurva_embutida,
        # Fixacao
        'Minifix'               => :minifix,
        'Confirmat'             => :confirmat,
        'Cavilha'               => :cavilha,
        'Minifix+Cavilha'       => :minifix_cavilha,
        # Articulador
        'Aventos HF'            => :aventos_hf,
        'Aventos HL'            => :aventos_hl,
        'Aventos HK-S'          => :aventos_hk,
        'Pistao Gas'            => :pistao_gas,
        # Pe
        'Regulavel'             => :regulavel,
        'Rodizio'               => :rodizio,
        'Sapata'                => :sapata,
        'Suspenso'              => :suspenso,
      }.freeze

      def show_hardware_swap_dialog
        modulo = find_selected_module
        return unless modulo

        # Passo 1: categoria
        categorias = HARDWARE_OPTIONS.keys
        prompts_1 = ['Tipo de ferragem:']
        defaults_1 = [categorias.first]
        lista_1 = [categorias.join('|')]

        r1 = ::UI.inputbox(prompts_1, defaults_1, lista_1, 'Trocar Ferragem — Categoria')
        return unless r1

        categoria = r1[0]
        opcoes = HARDWARE_OPTIONS[categoria] || []
        return ::UI.messagebox("Categoria invalida") if opcoes.empty?

        # Passo 2: opcao especifica
        prompts_2 = ["Novo tipo de #{categoria}:"]
        defaults_2 = [opcoes.first]
        lista_2 = [opcoes.join('|')]

        r2 = ::UI.inputbox(prompts_2, defaults_2, lista_2, "Trocar #{categoria}")
        return unless r2

        # Conversão segura via mapa explícito (sem regex frágil)
        novo_tipo = HARDWARE_SYMBOL_MAP[r2[0]]
        unless novo_tipo
          ::UI.messagebox("Tipo de ferragem desconhecido: #{r2[0]}")
          return
        end

        begin
          case categoria
          when 'Corredica'
            Engineering::HardwareSwapper.trocar_corredica(modulo, novo_tipo)
          when 'Dobradica'
            Engineering::HardwareSwapper.trocar_dobradica(modulo, novo_tipo)
          when 'Fixacao'
            Engineering::HardwareSwapper.trocar_fixacao(modulo, novo_tipo)
          when 'Articulador'
            Engineering::HardwareSwapper.trocar_articulador(modulo, novo_tipo)
          when 'Pe'
            Engineering::HardwareSwapper.trocar_pe(modulo, novo_tipo)
          end
          Sketchup.status_text = "#{categoria} trocada para #{r2[0]}"
        rescue => e
          ::UI.messagebox("Erro ao trocar ferragem:\n#{e.message}")
        end
      end

      # ── Dialogo de conexao entre modulos ──

      def show_connect_modules_dialog
        model = Sketchup.active_model
        selection = model.selection

        # Precisamos de exatamente 2 modulos ORNATO selecionados
        modulos = selection.select { |e| LevelDetector.modulo_ornato?(e) rescue false }
        if modulos.length < 2
          ::UI.messagebox("Selecione 2 modulos ORNATO para conectar.\n\n" \
                          "Dica: segure Ctrl/Cmd e clique nos dois modulos adjacentes.")
          return
        end
        if modulos.length > 2
          ::UI.messagebox("Selecione apenas 2 modulos para conectar.\n" \
                          "(#{modulos.length} modulos selecionados)")
          return
        end

        mod_esq = modulos[0]
        mod_dir = modulos[1]
        # Detectar qual esta mais a esquerda pelo X da origem
        if mod_dir.transformation.origin.x < mod_esq.transformation.origin.x
          mod_esq, mod_dir = mod_dir, mod_esq
        end

        nome_esq = (mod_esq.definition.get_attribute('dynamic_attributes', 'orn_nome') rescue nil) || mod_esq.definition.name
        nome_dir = (mod_dir.definition.get_attribute('dynamic_attributes', 'orn_nome') rescue nil) || mod_dir.definition.name

        tipos = Engineering::ModuleConnector::CONEXAO_TIPOS
        labels = tipos.map { |_, v| v[:descricao] }
        keys = tipos.keys

        prompts = ['Tipo de conexao:']
        defaults = [labels[1]]  # default: uniao_simples
        lista = [labels.join('|')]

        result = ::UI.inputbox(prompts, defaults, lista,
                               "Conectar: #{nome_esq} ↔ #{nome_dir}")
        return unless result

        tipo_idx = labels.index(result[0]) || 1
        tipo_sym = keys[tipo_idx]

        begin
          info = Engineering::ModuleConnector.conectar(mod_esq, mod_dir, tipo: tipo_sym)
          Sketchup.status_text = "ORNATO: #{nome_esq} ↔ #{nome_dir} conectados (#{result[0]})"
        rescue => e
          ::UI.messagebox("Erro ao conectar modulos:\n#{e.message}")
        end
      end

      # ── Dialogo de testeira (enchimento parede) ──

      def show_testeira_dialog
        modulo = find_selected_module
        return unless modulo

        prompts = ['Lado:', 'Largura (mm):', 'Material:']
        defaults = ['Esquerda', '50', 'MDF 18mm Branco TX']
        lista = ['Esquerda|Direita|Superior', '',
                 'MDF 15mm Branco TX|MDF 18mm Branco TX|MDF 25mm Branco TX|MDP 18mm Branco TX']

        nome = modulo.definition.get_attribute('dynamic_attributes', 'orn_nome') || modulo.definition.name rescue 'Modulo'
        result = ::UI.inputbox(prompts, defaults, lista, "Testeira — #{nome}")
        return unless result

        lado = { 'Esquerda' => :esquerda, 'Direita' => :direita, 'Superior' => :superior }[result[0]]
        largura_mm = result[1].to_f
        material = result[2]

        begin
          Engineering::ModuleConnector.criar_testeira(modulo, lado: lado,
                                                       largura_mm: largura_mm, material: material)
          Sketchup.status_text = "ORNATO: Testeira #{result[0]} adicionada (#{largura_mm}mm)"
        rescue => e
          ::UI.messagebox("Erro ao criar testeira:\n#{e.message}")
        end
      end

      # Helper: encontrar modulo selecionado
      def find_selected_module
        model = Sketchup.active_model
        modulo = model.selection.find { |e| LevelDetector.modulo_ornato?(e) rescue false }
        unless modulo
          ::UI.messagebox("Selecione um modulo ORNATO primeiro.\n\nClique em um modulo no modelo e tente novamente.")
        end
        modulo
      end
    end
  end
end
