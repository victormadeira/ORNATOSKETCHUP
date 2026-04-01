# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# ui/main_panel.rb — Painel principal adaptativo (HtmlDialog)
#
# Painel de propriedades que se adapta ao nível hierárquico:
#   - Projeto: resumo geral, lista de módulos
#   - Módulo: dimensões, composição, ações contextuais
#   - Peça: material, bordas, face visível, operações
#   - Operação: posição, parâmetros técnicos
#
# Filosofia C (híbrido):
#   - Seleção no 3D → painel atualiza automaticamente
#   - Breadcrumb clicável → navegação bidirecional
#   - Clicar na lista do painel → seleciona no 3D

module Ornato
  module UI
    class MainPanel
      DIALOG_ID = 'ornato_main_panel'.freeze
      DIALOG_TITLE = 'ORNATO'.freeze
      WIDTH = 380
      HEIGHT = 750

      @instance = nil

      def self.instance
        @instance ||= new
      end

      def initialize
        @dialog = nil
        @bridge = nil
      end

      def show
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          return
        end

        create_dialog
        @dialog.show
        Core.logger.info('Painel principal aberto')
      end

      def close
        @dialog&.close
        @dialog = nil
        @bridge = nil
      end

      def visible?
        @dialog&.visible? || false
      end

      def bridge
        @bridge
      end

      def push_nivel(info)
        payload = serializar_nivel(info)
        @bridge&.send_to_js('ornatoReceiveLevel', payload)

        # Auto-validar quando nível é módulo (feedback instantâneo ao projetista)
        if info[:nivel] == :modulo && info[:entity]
          auto_validate(info[:entity])
        end
      end

      def auto_validate(modulo)
        return unless Core::FeatureFlags.enabled?(:auto_validation)
        alertas = Engineering::CapacityValidator.validar(modulo) rescue []
        nome = modulo.definition.get_attribute('dynamic_attributes', 'orn_nome') || modulo.definition.name rescue '?'
        alertas.each { |a| a[:modulo] = nome }
        @bridge&.send_to_js('ornatoReceiveAlerts', { alerts: alertas })
      rescue => e
        # Silenciar — auto-validação não deve interromper fluxo
      end

      private

      def create_dialog
        @dialog = ::UI::HtmlDialog.new(
          dialog_title: DIALOG_TITLE,
          preferences_key: DIALOG_ID,
          scrollable: true,
          resizable: true,
          width: WIDTH,
          height: HEIGHT,
          style: ::UI::HtmlDialog::STYLE_DIALOG
        )

        html_path = File.join(File.dirname(__FILE__), 'html', 'main_panel.html')
        if File.exist?(html_path)
          @dialog.set_file(html_path)
        else
          @dialog.set_html(adaptive_html)
        end

        @bridge = Components::StateBridge.new(@dialog)

        # Callback: JS pronto
        @dialog.add_action_callback('ornato_ready') do |_ctx|
          Core.logger.info('Painel JS pronto')
          # Enviar estado inicial baseado na seleção atual
          sel = Sketchup.active_model&.selection
          info = LevelDetector.detectar(sel)
          payload = serializar_nivel(info)
          @bridge.send_to_js('ornatoReceiveLevel', payload)
        end

        # Callback: navegação pelo breadcrumb (JS → Ruby)
        @dialog.add_action_callback('ornato_navigate') do |_ctx, entity_id_str|
          navigate_to_entity(entity_id_str.to_i)
        end

        # Callback: selecionar entity da lista (JS → Ruby)
        @dialog.add_action_callback('ornato_select_entity') do |_ctx, entity_id_str|
          select_entity(entity_id_str.to_i)
        end

        # Callback: ação genérica
        @dialog.add_action_callback('ornato_action') do |_ctx, action_json|
          handle_panel_action(action_json)
        end

        @dialog.set_on_closed do
          Core.logger.info('Painel principal fechado')
          @dialog = nil
          @bridge = nil
        end
      end

      def serializar_nivel(info)
        {
          nivel: info[:nivel].to_s,
          breadcrumb: info[:breadcrumb].map { |b|
            { label: b[:label], nivel: b[:nivel].to_s, entity_id: b[:entity_id] }
          },
          data: info[:data],
        }
      end

      # Navegar para um entity pelo ID (bidirecional: painel → 3D)
      def navigate_to_entity(entity_id)
        model = Sketchup.active_model
        return unless model

        # entity_id 0 = voltar ao nível projeto (limpar seleção e fechar edição)
        if entity_id == 0
          begin
            model.close_active while model.active_path && !model.active_path.empty?
          rescue => e
            # Algumas versoes do SU podem falhar ao fechar contexto
          end
          model.selection.clear
          return
        end

        # Reutilizar a mesma lógica multi-estratégia de select_entity
        select_entity(entity_id)
      end

      # Selecionar entity no 3D
      def select_entity(entity_id)
        model = Sketchup.active_model
        return unless model

        # Primeiro: tentar no contexto atual de edição (active_entities)
        entity = find_in_entities(model.active_entities, entity_id)
        if entity
          model.selection.clear
          model.selection.add(entity)
          return
        end

        # Segundo: buscar nas entities do modelo (nível raiz)
        entity = find_in_entities(model.entities, entity_id)
        if entity
          model.selection.clear
          model.selection.add(entity)
          return
        end

        # Terceiro: buscar dentro de módulos (sub-entities)
        # Se já estamos editando um módulo, selecionar a peça dentro dele
        if model.active_path && !model.active_path.empty?
          parent = model.active_path.last
          if parent.respond_to?(:definition)
            found = find_in_entities(parent.definition.entities, entity_id)
            if found
              model.selection.clear
              model.selection.add(found)
              return
            end
          end
        end

        # Quarto: buscar em todos os módulos raiz — selecionar o módulo pai
        model.entities.each do |e|
          next unless e.respond_to?(:definition)
          found = find_in_entities(e.definition.entities, entity_id)
          if found
            model.selection.clear
            model.selection.add(e)
            return
          end
        end
      end

      def find_in_entities(entities, entity_id)
        entities.each do |e|
          return e if e.respond_to?(:entityID) && e.entityID == entity_id
        end
        nil
      rescue => e
        nil
      end

      def handle_panel_action(action_json)
        data = JSON.parse(action_json, symbolize_names: true)
        action = data[:action]
        payload = data[:payload] || {}

        case action
        when 'resize_module'
          resize_from_panel(payload)
        when 'add_aggregate'
          add_aggregate_from_panel(payload)
        when 'validate_module'
          validate_from_panel
        when 'export_project'
          Engineering::ExportBridge.exportar_para_arquivo
        when 'validate_all'
          validate_all_modules
        when 'swap_hardware'
          swap_hardware_from_panel(payload)
        when 'connect_modules'
          connect_modules_from_panel
        when 'add_testeira'
          add_testeira_from_panel
        when 'add_tampo_passante'
          add_tampo_passante_from_panel
        when 'create_module'
          create_module_from_panel(payload)

        # ── ERP Sync ─────────────────────────────────────
        when 'erp_sync'
          erp_sync_from_panel(payload)
        when 'erp_status'
          erp_status_from_panel(payload)
        when 'erp_custos'
          erp_custos_from_panel(payload)
        end
      rescue => e
        @bridge&.push_error("Erro: #{e.message}")
      end

      def resize_from_panel(payload)
        model = Sketchup.active_model

        # Encontrar o módulo: pode ser seleção direta ou via active_path
        sel = model.selection.first
        modulo = nil
        if sel && (LevelDetector.modulo_ornato?(sel) rescue false)
          modulo = sel
        else
          # Buscar módulo pai
          modulo = LevelDetector.encontrar_modulo_pai(sel) if sel
        end
        return @bridge&.push_error("Nenhum modulo selecionado para redimensionar") unless modulo

        def_ = modulo.definition
        dc = 'dynamic_attributes'

        # Validar valores positivos
        w = payload[:width]&.to_f
        d = payload[:depth]&.to_f
        h = payload[:height]&.to_f
        if (w && w <= 0) || (d && d <= 0) || (h && h <= 0)
          return @bridge&.push_error("Dimensoes devem ser maiores que zero")
        end

        # Verificar limites maximos (aviso, nao bloqueio)
        tipo_modulo = def_.get_attribute(dc, 'orn_tipo_modulo') || 'inferior'
        maximos = Engineering::CapacityValidator::DIMENSAO_MAXIMA[tipo_modulo.to_sym]
        avisos = []
        if maximos
          avisos << "Largura #{w.round}mm excede max #{maximos[:largura]}mm" if w && w > maximos[:largura]
          avisos << "Altura #{h.round}mm excede max #{maximos[:altura]}mm" if h && h > maximos[:altura]
          avisos << "Profundidade #{d.round}mm excede max #{maximos[:profundidade]}mm" if d && d > maximos[:profundidade]
        end

        model.start_operation('ORNATO Resize', true)

        def_.set_attribute(dc, 'orn_largura', w / 10.0) if w
        def_.set_attribute(dc, 'orn_profundidade', d / 10.0) if d
        def_.set_attribute(dc, 'orn_altura', h / 10.0) if h

        # Forcar recalculo dos Dynamic Components (formulas de pecas filhas)
        begin
          if defined?($dc_observers) && $dc_observers && $dc_observers.respond_to?(:get_latest_class)
            dc_class = $dc_observers.get_latest_class
            dc_class.redraw_with_undo(modulo) if dc_class && dc_class.respond_to?(:redraw_with_undo)
          end
        rescue => e
          Core.logger.warn("DC observer nao disponivel: #{e.message}")
        end

        model.commit_operation

        # Atualizar painel com novos dados
        info = LevelDetector.detectar(model.selection)
        @bridge&.send_to_js('ornatoReceiveLevel', serializar_nivel(info))

        # Notificar avisos de limites (apos aplicar, para nao bloquear)
        unless avisos.empty?
          @bridge&.push_error("Aviso: #{avisos.join('; ')}")
        end
      rescue => e
        model.abort_operation rescue nil
        @bridge&.push_error("Erro ao redimensionar: #{e.message}")
      end

      def add_aggregate_from_panel(payload)
        model = Sketchup.active_model

        # Encontrar o módulo (pode ser o selecionado ou o pai)
        modulo = model.selection.find { |e| LevelDetector.modulo_ornato?(e) rescue false }
        unless modulo
          # Tentar via active_path (editando dentro do módulo)
          modulo = LevelDetector.encontrar_modulo_pai(model.selection.first) if model.selection.first
        end
        return @bridge&.push_error("Nenhum modulo encontrado") unless modulo

        tipo = payload[:tipo]&.to_sym
        return unless tipo

        model.start_operation('ORNATO Agregar', true)
        Ornato.executar_agregado(modulo, tipo)
        model.commit_operation

        # Atualizar painel
        info = LevelDetector.nivel_modulo(modulo)
        @bridge&.send_to_js('ornatoReceiveLevel', serializar_nivel(info))
      rescue => e
        model.abort_operation rescue nil
        @bridge&.push_error("Erro ao agregar: #{e.message}")
      end

      def swap_hardware_from_panel(payload)
        modulo = find_panel_module
        return @bridge&.push_error("Nenhum modulo selecionado") unless modulo

        categoria = payload[:categoria]
        return @bridge&.push_error("Categoria de ferragem nao informada") unless categoria

        # Delegar para o diálogo da toolbar (que já tem o fluxo completo)
        Toolbar.instance.send(:show_hardware_swap_dialog) rescue nil
      end

      def connect_modules_from_panel
        model = Sketchup.active_model
        modulos = model.selection.select { |e| LevelDetector.modulo_ornato?(e) rescue false }
        if modulos.length != 2
          @bridge&.push_error("Selecione exatamente 2 modulos no 3D para conectar (#{modulos.length} selecionado(s))")
          return
        end

        mod_esq, mod_dir = modulos
        if mod_dir.transformation.origin.x < mod_esq.transformation.origin.x
          mod_esq, mod_dir = mod_dir, mod_esq
        end

        begin
          info = Engineering::ModuleConnector.conectar(mod_esq, mod_dir, tipo: :uniao_simples)
          @bridge&.push_error("Modulos conectados com sucesso (Uniao Simples)")
          # Refresh panel
          panel_info = LevelDetector.detectar(model.selection)
          @bridge&.send_to_js('ornatoReceiveLevel', serializar_nivel(panel_info))
        rescue => e
          @bridge&.push_error("Erro ao conectar: #{e.message}")
        end
      end

      def add_testeira_from_panel
        modulo = find_panel_module
        return @bridge&.push_error("Nenhum modulo selecionado") unless modulo

        # Default: testeira esquerda 50mm (mais comum em cozinhas)
        begin
          Engineering::ModuleConnector.criar_testeira(modulo, lado: :esquerda, largura_mm: 50)
          @bridge&.push_error("Testeira esquerda 50mm adicionada. Use toolbar para opcoes avancadas.")
          info = LevelDetector.nivel_modulo(modulo)
          @bridge&.send_to_js('ornatoReceiveLevel', serializar_nivel(info))
        rescue => e
          @bridge&.push_error("Erro ao criar testeira: #{e.message}")
        end
      end

      def add_tampo_passante_from_panel
        model = Sketchup.active_model
        modulos = model.selection.select { |e| LevelDetector.modulo_ornato?(e) rescue false }
        if modulos.empty?
          mod = find_panel_module
          modulos = [mod] if mod
        end
        return @bridge&.push_error("Selecione modulo(s) para cobrir com tampo") if modulos.empty?

        # Ordenar por posição X
        modulos_sorted = modulos.sort_by { |m| m.transformation.origin.x }

        begin
          instance = Engineering::ModuleConnector.criar_tampo_passante(modulos_sorted)
          nome = instance.definition.name rescue 'Tampo'
          @bridge&.push_error("#{nome} criado cobrindo #{modulos_sorted.length} modulo(s)")
        rescue => e
          @bridge&.push_error("Erro ao criar tampo passante: #{e.message}")
        end
      end

      def create_module_from_panel(payload)
        tipo_sym = (payload[:tipo] || 'inferior').to_sym
        largura = (payload[:largura] || 60).to_f
        profundidade = (payload[:profundidade] || 55).to_f
        altura = (payload[:altura] || 72).to_f
        nome = payload[:nome]

        instance = Engineering::BoxBuilder.criar(
          tipo_sym,
          largura: largura,
          profundidade: profundidade,
          altura: altura,
          nome: nome && !nome.empty? ? nome : nil
        )

        if instance
          nome_def = instance.definition.name
          @bridge&.push_success("Modulo #{nome_def} criado com sucesso!")
          Core.logger.info("Modulo criado via painel: #{nome_def} (#{tipo_sym})")
        end
      rescue => e
        @bridge&.push_error("Erro ao criar modulo: #{e.message}")
      end

      # Helper: encontrar módulo selecionado ou via active_path
      def find_panel_module
        model = Sketchup.active_model
        modulo = model.selection.find { |e| LevelDetector.modulo_ornato?(e) rescue false }
        unless modulo
          sel = model.selection.first
          modulo = LevelDetector.encontrar_modulo_pai(sel) if sel
        end
        unless modulo
          model.active_path&.each do |inst|
            if (LevelDetector.modulo_ornato?(inst) rescue false)
              modulo = inst
              break
            end
          end
        end
        modulo
      end

      def validate_from_panel
        model = Sketchup.active_model
        modulos = model.selection.select { |e|
          LevelDetector.modulo_ornato?(e) rescue false
        }

        if modulos.empty?
          # Talvez esteja dentro de um módulo editando — buscar módulo pai
          sel = model.selection.first
          if sel
            parent_mod = LevelDetector.encontrar_modulo_pai(sel)
            modulos = [parent_mod] if parent_mod
          end
          # Ou via active_path
          if modulos.empty? && model.active_path
            model.active_path.each do |inst|
              if (LevelDetector.modulo_ornato?(inst) rescue false)
                modulos = [inst]
                break
              end
            end
          end
          return @bridge&.push_error("Nenhum modulo encontrado para validar") if modulos.empty?
        end

        todas_alertas = []
        modulos.each do |mod|
          alertas = Engineering::CapacityValidator.validar(mod) rescue []
          nome = mod.definition.get_attribute('dynamic_attributes', 'orn_nome') || mod.definition.name rescue '?'
          alertas.each { |a| a[:modulo] = nome }
          todas_alertas.concat(alertas)
        end

        @bridge&.send_to_js('ornatoReceiveAlerts', { alerts: todas_alertas })
      rescue => e
        @bridge&.push_error("Erro ao validar: #{e.message}")
      end

      # ── ERP Bridge ─────────────────────────────────────────

      def erp_sync_from_panel(payload)
        # Sync completo: exportar + enviar + receber status/custos/alertas
        ::UI.start_timer(0.1, false) do
          begin
            result = Engineering::ErpBridge.exportar_e_sincronizar(
              cliente: payload[:cliente] || '',
              projeto: payload[:projeto] || '',
              codigo: payload[:codigo] || '',
              vendedor: payload[:vendedor] || ''
            )

            if result && result['ok']
              lote_id = result['lote_id']

              # Buscar custos
              custos_result = Engineering::ErpBridge.custos(lote_id) rescue {}
              result['materiais'] = custos_result['materiais'] if custos_result['ok']
              result['plano'] = custos_result['plano'] if custos_result['plano']

              @bridge&.send_to_js('ornatoReceiveErpStatus', result)
              @bridge&.send_to_js('ornatoReceiveSuccess', { message: "Sync ERP OK — #{result['total_pecas']} pecas enviadas" })
            else
              @bridge&.send_to_js('ornatoReceiveErpStatus', result || { 'error' => 'Falha no sync' })
            end
          rescue => e
            @bridge&.send_to_js('ornatoReceiveErpStatus', { 'error' => e.message })
          end
        end
      end

      def erp_status_from_panel(payload)
        lote_id = payload[:lote_id]
        return @bridge&.push_error('lote_id ausente') unless lote_id

        ::UI.start_timer(0.1, false) do
          begin
            result = Engineering::ErpBridge.status(lote_id)
            if result && result['ok']
              @bridge&.send_to_js('ornatoReceiveErpStatus', {
                'ok' => true,
                'lote_id' => lote_id,
                'lote' => result['lote'],
                'producao' => result['producao'],
              })
            else
              @bridge&.send_to_js('ornatoReceiveErpStatus', result || { 'error' => 'Falha' })
            end
          rescue => e
            @bridge&.send_to_js('ornatoReceiveErpStatus', { 'error' => e.message })
          end
        end
      end

      def erp_custos_from_panel(payload)
        lote_id = payload[:lote_id]
        return @bridge&.push_error('lote_id ausente') unless lote_id

        ::UI.start_timer(0.1, false) do
          begin
            result = Engineering::ErpBridge.custos(lote_id)
            if result && result['ok']
              @bridge&.send_to_js('ornatoReceiveErpStatus', {
                'ok' => true,
                'lote_id' => lote_id,
                'materiais' => result['materiais'],
                'plano' => result['plano'],
              })
            else
              @bridge&.send_to_js('ornatoReceiveErpStatus', result || { 'error' => 'Falha' })
            end
          rescue => e
            @bridge&.send_to_js('ornatoReceiveErpStatus', { 'error' => e.message })
          end
        end
      end

      def validate_all_modules
        model = Sketchup.active_model
        todos = model.entities.select { |e|
          (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) &&
          (LevelDetector.modulo_ornato?(e) rescue false)
        }

        if todos.empty?
          return @bridge&.push_error("Nenhum modulo ORNATO no modelo")
        end

        todas_alertas = []
        todos.each do |mod|
          alertas = Engineering::CapacityValidator.validar(mod) rescue []
          nome = mod.definition.get_attribute('dynamic_attributes', 'orn_nome') || mod.definition.name rescue '?'
          alertas.each { |a| a[:modulo] = nome }
          todas_alertas.concat(alertas)
        end

        @bridge&.send_to_js('ornatoReceiveAlerts', { alerts: todas_alertas })

        if todas_alertas.empty?
          @bridge&.send_to_js('ornatoReceiveSuccess', { message: "#{todos.length} modulos validados — nenhum problema" })
        else
          erros = todas_alertas.count { |a| a[:nivel] == :erro }
          avisos = todas_alertas.count { |a| a[:nivel] == :aviso }
          @bridge&.send_to_js('ornatoReceiveError', { message: "#{todos.length} modulos: #{erros} erro(s), #{avisos} aviso(s)" })
        end
      rescue => e
        @bridge&.push_error("Erro ao validar: #{e.message}")
      end

      # ── HTML adaptativo ──

      def adaptive_html
        ver = defined?(Core::Config::VERSION) ? Core::Config::VERSION : '?'
        <<~HTML
          <!DOCTYPE html>
          <html lang="pt-BR">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>ORNATO</title>
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                font-size: 13px;
                color: #333;
                background: #f0f0f0;
                overflow-x: hidden;
              }

              /* ── Header fixo ── */
              .header {
                background: linear-gradient(135deg, #e67e22, #d35400);
                color: white;
                padding: 10px 16px;
                display: flex;
                align-items: center;
                justify-content: space-between;
                position: sticky;
                top: 0;
                z-index: 100;
              }
              .header h1 { font-size: 15px; font-weight: 700; letter-spacing: 1px; }
              .header .ver { font-size: 10px; opacity: 0.7; }

              /* ── Breadcrumb ── */
              .breadcrumb {
                background: #fff;
                padding: 8px 16px;
                font-size: 12px;
                border-bottom: 1px solid #e0e0e0;
                display: flex;
                align-items: center;
                gap: 4px;
                flex-wrap: wrap;
              }
              .breadcrumb .bc-item {
                color: #e67e22;
                cursor: pointer;
                text-decoration: none;
                font-weight: 500;
              }
              .breadcrumb .bc-item:hover { text-decoration: underline; }
              .breadcrumb .bc-current {
                color: #333;
                font-weight: 600;
              }
              .breadcrumb .bc-sep { color: #999; margin: 0 2px; }

              /* ── Conteúdo scrollável ── */
              .content { padding: 12px; }

              /* ── Cards ── */
              .card {
                background: white;
                border-radius: 8px;
                padding: 12px 16px;
                margin-bottom: 8px;
                box-shadow: 0 1px 3px rgba(0,0,0,0.08);
              }
              .card h3 {
                font-size: 11px;
                color: #888;
                text-transform: uppercase;
                letter-spacing: 0.5px;
                margin-bottom: 8px;
                font-weight: 600;
              }

              /* ── Campos ── */
              .field { margin-bottom: 6px; display: flex; justify-content: space-between; align-items: center; }
              .field label { color: #666; font-size: 12px; }
              .field .value { font-weight: 600; font-size: 13px; }
              .field input[type="number"], .field select {
                border: 1px solid #ddd;
                border-radius: 4px;
                padding: 4px 8px;
                font-size: 12px;
                width: 90px;
                text-align: right;
              }
              .field input:focus, .field select:focus {
                outline: none;
                border-color: #e67e22;
                box-shadow: 0 0 0 2px rgba(230,126,34,0.15);
              }

              /* ── Lista de itens clicáveis ── */
              .item-list { list-style: none; }
              .item-list li {
                padding: 8px 12px;
                margin: 2px 0;
                border-radius: 6px;
                cursor: pointer;
                display: flex;
                justify-content: space-between;
                align-items: center;
                transition: background 0.15s;
              }
              .item-list li:hover { background: #f5f0eb; }
              .item-list .item-name { font-weight: 500; }
              .item-list .item-meta { font-size: 11px; color: #999; }
              .item-list .item-badge {
                font-size: 10px;
                padding: 2px 8px;
                border-radius: 10px;
                font-weight: 600;
              }
              .badge-struct { background: #e8f5e9; color: #2e7d32; }
              .badge-front { background: #e3f2fd; color: #1565c0; }
              .badge-intern { background: #fff3e0; color: #e65100; }
              .badge-drawer { background: #fce4ec; color: #c62828; }
              .badge-hw { background: #f3e5f5; color: #7b1fa2; }

              /* ── Diagrama de bordas ── */
              .borda-diagram {
                display: grid;
                grid-template-columns: 40px 1fr 40px;
                grid-template-rows: 30px 80px 30px;
                gap: 2px;
                margin: 8px auto;
                width: 200px;
              }
              .borda-top { grid-column: 2; grid-row: 1; }
              .borda-left { grid-column: 1; grid-row: 2; }
              .borda-center {
                grid-column: 2; grid-row: 2;
                background: #f5f5f5;
                border: 2px solid #ddd;
                border-radius: 4px;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 10px;
                color: #999;
              }
              .borda-right { grid-column: 3; grid-row: 2; }
              .borda-bottom { grid-column: 2; grid-row: 3; }
              .borda-btn {
                width: 100%;
                height: 100%;
                border: none;
                border-radius: 3px;
                cursor: pointer;
                font-size: 10px;
                font-weight: 600;
                transition: all 0.15s;
              }
              .borda-btn.active { background: #e67e22; color: white; }
              .borda-btn.inactive { background: #eee; color: #999; }
              .borda-btn:hover { opacity: 0.85; }

              /* ── Botões ── */
              .btn {
                border: none;
                border-radius: 6px;
                padding: 8px 16px;
                font-size: 12px;
                font-weight: 600;
                cursor: pointer;
                width: 100%;
                margin-top: 4px;
                transition: all 0.15s;
              }
              .btn-primary { background: #e67e22; color: white; }
              .btn-primary:hover { background: #d35400; }
              .btn-secondary { background: #ecf0f1; color: #333; }
              .btn-secondary:hover { background: #ddd; }
              .btn-sm { padding: 5px 10px; width: auto; font-size: 11px; }
              .btn-group { display: flex; gap: 4px; margin-top: 8px; }
              .btn-group .btn { flex: 1; }

              /* ── Status badges ── */
              .status { padding: 3px 8px; border-radius: 10px; font-size: 10px; font-weight: 600; display: inline-block; }
              .status-ok { background: #e8f5e9; color: #2e7d32; }
              .status-warn { background: #fff3e0; color: #e65100; }
              .status-error { background: #ffebee; color: #c62828; }
              .toast-error, .toast-success {
                position: fixed; left: 16px; right: 16px;
                padding: 10px 14px; border-radius: 6px;
                font-size: 12px; z-index: 9999;
                animation: toastIn 0.3s ease;
                color: #fff;
              }
              .toast-error { background: #c62828; }
              .toast-success { background: #2e7d32; }
              @keyframes toastIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }

              /* ── Dark Mode ── */
              body.dark { background: #1e1e1e; color: #ddd; }
              body.dark .card { background: #2d2d2d; box-shadow: 0 1px 3px rgba(0,0,0,0.3); }
              body.dark .card h3 { color: #e67e22; }
              body.dark .breadcrumb { background: #252525; border-color: #444; }
              body.dark .breadcrumb .bc-current { color: #ddd; }
              body.dark .field label { color: #aaa; }
              body.dark .value { color: #eee; }
              body.dark input[type="number"] { background: #3a3a3a; color: #eee; border-color: #555; }
              body.dark .item-list li { border-color: #444; }
              body.dark .item-list li:hover { background: #3a3a3a; }
              body.dark .item-meta { color: #888; }
              body.dark .btn-secondary { background: #3a3a3a; color: #ddd; }
              body.dark .btn-secondary:hover { background: #4a4a4a; }
              body.dark .empty-hint { color: #888; }
              body.dark .borda-center { background: #3a3a3a; border-color: #555; }
              body.dark .borda-btn.inactive { background: #3a3a3a; color: #888; }
              body.dark .alert-item { background: #2d2d2d; }
              body.dark .shortcut-footer { background: #252525 !important; border-color: #444 !important; color: #666 !important; }

              /* ── Alertas ── */
              .alert-item { padding: 8px; border-bottom: 1px solid #f0f0f0; font-size: 12px; line-height: 1.4; border-radius: 4px; margin-bottom: 2px; }
              .alert-item:last-child { border: none; margin-bottom: 0; }

              /* ── Empty state ── */
              .empty-hint { text-align: center; color: #aaa; padding: 20px; font-size: 12px; }

              /* ── Animação suave ── */
              .fade-in { animation: fadeIn 0.2s ease; }
              @keyframes fadeIn { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: translateY(0); } }
            </style>
          </head>
          <body>
            <div class="header">
              <h1>ORNATO</h1>
              <div style="display:flex;align-items:center;gap:8px">
                <button onclick="toggleDark()" style="background:none;border:none;cursor:pointer;font-size:16px;color:white;opacity:0.7" title="Dark mode">◐</button>
                <span class="ver">v#{ver}</span>
              </div>
            </div>

            <div class="breadcrumb" id="breadcrumb"></div>

            <div class="content" id="main-content">
              <div class="empty-hint">Carregando...</div>
            </div>

            <script>
              // ═══════════════════════════════════════════════
              // Estado global
              // ═══════════════════════════════════════════════
              var currentLevel = null;
              var currentData = null;

              // ═══════════════════════════════════════════════
              // Recebe nível do Ruby (entrada principal)
              // ═══════════════════════════════════════════════
              function ornatoReceiveLevel(payload) {
                currentLevel = payload.nivel;
                currentData = payload.data;
                renderBreadcrumb(payload.breadcrumb);
                renderContent(payload.nivel, payload.data);
              }

              // Compatibilidade com StateBridge existente
              function ornatoReceiveState(data) {
                if (!data || !data.module) {
                  ornatoReceiveLevel({ nivel: 'projeto', breadcrumb: [{ label: 'Projeto', nivel: 'projeto' }], data: { total_modulos: 0, modulos: [] } });
                }
              }

              function ornatoReceivePartial(data) { console.log('Partial:', data); }
              var _toastCount = 0;
              function showToast(msg, cls, duration) {
                var toast = document.createElement('div');
                toast.className = cls;
                toast.textContent = msg;
                toast.style.bottom = (16 + _toastCount * 48) + 'px';
                _toastCount++;
                document.body.appendChild(toast);
                setTimeout(function() { toast.remove(); _toastCount = Math.max(0, _toastCount - 1); }, duration);
              }

              function ornatoReceiveError(data) {
                console.error('Erro:', data.message);
                showToast(data.message || 'Erro desconhecido', 'toast-error', 4000);
              }
              function ornatoReceiveSuccess(data) {
                console.log('OK:', data.message);
                showToast(data.message || 'OK', 'toast-success', 3000);
              }

              var _lastAlerts = [];
              var _alertFilter = 'todos';

              function ornatoReceiveAlerts(data) {
                var el = document.getElementById('alerts-section');
                if (!el || !data || !data.alerts) return;
                _lastAlerts = data.alerts;
                _alertFilter = 'todos';
                renderAlertsFiltered(el);
              }

              function renderAlertsFiltered(el) {
                if (!el) el = document.getElementById('alerts-section');
                if (!el) return;
                var alerts = _lastAlerts;
                if (alerts.length === 0) {
                  el.innerHTML = '<div class="empty-hint">Nenhum problema encontrado</div>';
                  return;
                }

                // Contar por categoria
                var cats = {};
                alerts.forEach(function(a) {
                  var c = a.categoria || 'outros';
                  cats[c] = (cats[c] || 0) + 1;
                });

                // Filtro tabs
                var html = '<div style="display:flex;gap:4px;flex-wrap:wrap;margin-bottom:8px">';
                html += '<button class="btn btn-sm ' + (_alertFilter === 'todos' ? 'btn-primary' : 'btn-secondary') +
                  '" onclick="filterAlerts(\\\'todos\\\')">Todos (' + alerts.length + ')</button>';
                var catLabels = {estrutural:'Estrut.', material:'Material', ferragem:'Ferrag.', bordas:'Bordas', furacao:'Furação', outros:'Outros'};
                for (var c in cats) {
                  var label = catLabels[c] || c;
                  html += '<button class="btn btn-sm ' + (_alertFilter === c ? 'btn-primary' : 'btn-secondary') +
                    '" onclick="filterAlerts(\\\'' + c + '\\\')">' + label + ' (' + cats[c] + ')</button>';
                }
                html += '</div>';

                // Alertas filtrados
                var filtered = _alertFilter === 'todos' ? alerts : alerts.filter(function(a) { return (a.categoria || 'outros') === _alertFilter; });
                filtered.forEach(function(a) {
                  var cls = a.nivel === 'erro' ? 'status-error' : 'status-warn';
                  html += '<div class="alert-item"><span class="status ' + cls + '">' +
                    (a.nivel || '').toUpperCase() + '</span> ';
                  if (a.modulo) html += '<span style="color:#1379F0;font-size:11px">[' + esc(a.modulo) + ']</span> ';
                  if (a.peca) html += '<strong>' + esc(a.peca) + ':</strong> ';
                  html += esc(a.mensagem || '') +
                    (a.sugestao ? '<br><small style="color:#888">\u2192 ' + esc(a.sugestao) + '</small>' : '') +
                    '</div>';
                });
                el.innerHTML = html;
              }

              function filterAlerts(cat) {
                _alertFilter = cat;
                renderAlertsFiltered(null);
              }

              // ═══════════════════════════════════════════════
              // Breadcrumb
              // ═══════════════════════════════════════════════
              function renderBreadcrumb(items) {
                var bc = document.getElementById('breadcrumb');
                if (!items || items.length === 0) { bc.innerHTML = ''; return; }

                var html = '';
                items.forEach(function(item, i) {
                  var isLast = (i === items.length - 1);
                  if (isLast) {
                    html += '<span class="bc-current">' + esc(item.label) + '</span>';
                  } else {
                    var eid = item.entity_id || 0;
                    html += '<span class="bc-item" onclick="navigateTo(' + eid + ', \\'' + item.nivel + '\\')">' + esc(item.label) + '</span>';
                    html += '<span class="bc-sep">›</span>';
                  }
                });
                bc.innerHTML = html;
              }

              // ═══════════════════════════════════════════════
              // Renderização por nível
              // ═══════════════════════════════════════════════
              function renderContent(nivel, data) {
                var el = document.getElementById('main-content');
                el.className = 'content fade-in';

                switch (nivel) {
                  case 'projeto':  el.innerHTML = renderProjeto(data); break;
                  case 'modulo':   el.innerHTML = renderModulo(data); break;
                  case 'peca':     el.innerHTML = renderPeca(data); break;
                  case 'operacao': el.innerHTML = renderOperacao(data); break;
                  default:         el.innerHTML = '<div class="empty-hint">Selecione um modulo ORNATO</div>';
                }
              }

              // ── Nível Projeto ──
              function renderProjeto(d) {
                if (!d) return '<div class="empty-hint">Selecione um modulo ORNATO<br>ou crie um novo no menu</div>';

                var tp = d.total_pecas || 0;
                var html = '<div class="card"><h3>Projeto</h3>';
                html += '<div class="field"><label>Modulos</label><span class="value">' + (d.total_modulos || 0) + '</span></div>';
                html += '<div class="field"><label>Pecas</label><span class="value">' + tp + '</span></div>';
                if (d.total_area_m2) html += '<div class="field"><label>Area total</label><span class="value">' + d.total_area_m2 + ' m\u00B2</span></div>';
                if (d.total_fita_m) html += '<div class="field"><label>Fita de borda</label><span class="value">' + d.total_fita_m + ' m</span></div>';
                if (d.total_peso_kg) html += '<div class="field"><label>Peso estimado</label><span class="value">' + d.total_peso_kg + ' kg</span></div>';
                if (d.total_modulos > 0) {
                  html += '<button class="btn btn-secondary btn-sm" style="margin-top:4px;width:100%" onclick="sendAction(\'validate_all\', {})">Validar todos</button>';
                }
                html += '</div>';

                // Materiais breakdown
                if (d.materiais && d.materiais.length > 0) {
                  html += '<div class="card"><h3>Materiais</h3>';
                  d.materiais.forEach(function(m) {
                    html += '<div class="field"><label>' + esc(m.nome) + '</label><span class="value">' + m.area_m2 + ' m\u00B2</span></div>';
                  });
                  html += '</div>';
                }

                if (d.modulos && d.modulos.length > 0) {
                  html += '<div class="card"><h3>Modulos</h3><ul class="item-list">';
                  d.modulos.forEach(function(m) {
                    html += '<li onclick="selectEntity(' + m.entity_id + ')">' +
                      '<div><span class="item-name">' + esc(m.nome) + '</span>' +
                      '<br><span class="item-meta">' + esc(m.tipo) + ' · ' + m.dims + 'mm</span></div>' +
                      '<span class="item-badge badge-struct">' + m.pecas + 'p</span>' +
                      '</li>';
                  });
                  html += '</ul></div>';
                } else {
                  html += '<div class="empty-hint">Nenhum modulo ORNATO no modelo.</div>';
                  html += '<div class="card" style="text-align:center;padding:20px">';
                  html += '<p style="color:#888;margin-bottom:12px">Crie seu primeiro modulo pelo menu:</p>';
                  html += '<p style="font-weight:600;color:#333">Plugins → ORNATO → Novo Modulo</p>';
                  html += '<p style="color:#888;margin-top:8px;font-size:11px">ou use o botao Novo Modulo na toolbar</p>';
                  html += '</div>';
                }

                if (d.total_modulos > 0) {
                  html += '<div class="card"><h3>Saude do projeto</h3>';
                  html += '<div id="alerts-section"><div class="empty-hint">Clique validar para ver</div></div>';
                  html += '</div>';

                  html += '<div class="btn-group">';
                  html += '<button class="btn btn-primary" onclick="sendAction(\'export_project\', {})">Exportar</button>';
                  html += '</div>';
                }
                return html;
              }

              // Limites máximos por tipo (espelho do Ruby DIMENSAO_MAXIMA)
              var DIM_MAXIMA = {
                inferior:{largura:1200,altura:900,profundidade:650},
                superior:{largura:1200,altura:900,profundidade:400},
                torre:{largura:800,altura:2700,profundidade:650},
                gaveteiro:{largura:800,altura:900,profundidade:650},
                roupeiro:{largura:1200,altura:2700,profundidade:650},
                estante:{largura:1200,altura:2700,profundidade:450},
                bancada:{largura:3000,altura:100,profundidade:800},
                pia:{largura:1200,altura:900,profundidade:650},
                nicho:{largura:1200,altura:600,profundidade:400},
                torre_quente:{largura:800,altura:2700,profundidade:650},
                cooktop:{largura:1200,altura:900,profundidade:650},
                ilha:{largura:3000,altura:1000,profundidade:1000},
                espelheira:{largura:1200,altura:1000,profundidade:200},
                pia_banheiro:{largura:1200,altura:900,profundidade:550}
              };

              function dimFieldMax(label, id, val, max) {
                var warn = (max && val > max) ? ' style="color:#c62828;font-weight:600"' : '';
                var hint = max ? '<span style="font-size:10px;color:#999"> max ' + max + '</span>' : '';
                return '<div class="field"><label>' + label + hint + '</label>' +
                  '<input type="number" id="' + id + '" value="' + (val || 0) +
                  '" step="1" min="1"' + (max ? ' max="' + (max * 1.5) + '"' : '') +
                  ' onchange="onDimChange()"' + warn + '></div>';
              }

              // ── Nível Módulo ──
              function renderModulo(d) {
                if (!d) return '<div class="empty-hint">Dados do modulo indisponiveis</div>';

                var html = '';

                // Card: Identidade
                html += '<div class="card"><h3>Modulo</h3>';
                html += '<div class="field"><label>Nome</label><span class="value">' + esc(d.nome) + '</span></div>';
                html += '<div class="field"><label>Tipo</label><span class="value">' + esc(d.tipo) + '</span></div>';
                html += '<div class="field"><label>Material</label><span class="value" style="font-size:11px">' + esc(d.material) + '</span></div>';
                html += '</div>';

                // Card: Dimensões editáveis com limites
                var lim = DIM_MAXIMA[d.tipo_sym] || {};
                html += '<div class="card"><h3>Dimensoes (mm)</h3>';
                html += dimFieldMax('Largura [W]', 'dim-w', d.largura_mm, lim.largura);
                html += dimFieldMax('Profundidade [D]', 'dim-d', d.profundidade_mm, lim.profundidade);
                html += dimFieldMax('Altura [H]', 'dim-h', d.altura_mm, lim.altura);
                html += '<div class="field"><label>Espessura</label><span class="value">' + d.espessura_mm + 'mm</span></div>';
                if (d.area_m2 || d.fita_metros) {
                  html += '<div style="border-top:1px solid #eee;margin-top:6px;padding-top:6px">';
                  html += '<div class="field"><label>Area chapa</label><span class="value">' + (d.area_m2 || 0) + ' m²</span></div>';
                  html += '<div class="field"><label>Fita borda</label><span class="value">' + (d.fita_metros || 0) + ' m</span></div>';
                  html += '<div class="field"><label>Peso estimado</label><span class="value">' + (d.peso_kg || 0) + ' kg</span></div>';
                  html += '</div>';
                }
                html += '</div>';

                // Card: Composição (lista clicável)
                html += '<div class="card"><h3>Composicao (' + d.total_pecas + ' pecas)</h3>';
                html += renderComposicao(d.composicao);
                html += '</div>';

                // Card: Ações contextuais
                var agr = getAgregadosPermitidos(d.tipo_sym);
                html += '<div class="card"><h3>Adicionar</h3>';
                html += '<div class="btn-group" style="flex-wrap:wrap">';
                agr.forEach(function(a) {
                  html += '<button class="btn btn-secondary btn-sm" onclick="sendAction(\'add_aggregate\', {tipo: \\'' + a.tipo + '\\'})">+ ' + a.label + '</button>';
                });
                html += '</div></div>';

                // Card: Ferragens
                html += '<div class="card"><h3>Ferragens</h3>';
                html += '<div class="btn-group" style="flex-wrap:wrap">';
                html += '<button class="btn btn-secondary btn-sm" onclick="sendAction(\'swap_hardware\', {categoria: \\\'Corredica\\\'})">Corredica</button>';
                html += '<button class="btn btn-secondary btn-sm" onclick="sendAction(\'swap_hardware\', {categoria: \\\'Dobradica\\\'})">Dobradica</button>';
                html += '<button class="btn btn-secondary btn-sm" onclick="sendAction(\'swap_hardware\', {categoria: \\\'Fixacao\\\'})">Fixacao</button>';
                html += '<button class="btn btn-secondary btn-sm" onclick="sendAction(\'swap_hardware\', {categoria: \\\'Pe\\\'})">Pe/Base</button>';
                html += '</div></div>';

                // Card: Conexao (kitchen runs)
                html += '<div class="card"><h3>Conexao</h3>';
                html += '<div class="btn-group" style="flex-wrap:wrap">';
                html += '<button class="btn btn-secondary btn-sm" onclick="sendAction(\'connect_modules\', {})">Conectar Modulos</button>';
                html += '<button class="btn btn-secondary btn-sm" onclick="sendAction(\'add_testeira\', {})">+ Testeira</button>';
                html += '<button class="btn btn-secondary btn-sm" onclick="sendAction(\'add_tampo_passante\', {})">+ Tampo Passante</button>';
                html += '</div></div>';

                // Card: Validação
                html += '<div class="card"><h3>Validacao</h3>';
                html += '<div id="alerts-section"><div class="empty-hint">Clique para validar</div></div>';
                html += '<div class="btn-group" style="margin-top:8px">';
                html += '<button class="btn btn-secondary" onclick="sendAction(\'validate_module\', {})">Validar</button>';
                html += '<button class="btn btn-primary" onclick="sendAction(\'export_project\', {})">Exportar</button>';
                html += '</div></div>';

                return html;
              }

              function dimField(label, id, val) {
                return '<div class="field"><label>' + label + '</label>' +
                  '<input type="number" id="' + id + '" value="' + (val || 0) +
                  '" step="1" min="1" onchange="onDimChange()"></div>';
              }

              function onDimChange() {
                var w = parseFloat(document.getElementById('dim-w').value) || 0;
                var h = parseFloat(document.getElementById('dim-h').value) || 0;
                var d = parseFloat(document.getElementById('dim-d').value) || 0;
                sendAction('resize_module', { width: w, height: h, depth: d });
              }

              function renderComposicao(comp) {
                if (!comp) return '';
                var html = '<ul class="item-list">';

                function addGroup(items, badge, cls) {
                  if (!items) return;
                  items.forEach(function(p) {
                    html += '<li onclick="selectEntity(' + p.entity_id + ')">' +
                      '<span class="item-name">' + esc(p.nome) + '</span>' +
                      '<span class="item-badge ' + cls + '">' + badge + '</span></li>';
                  });
                }

                addGroup(comp.estruturais, 'EST', 'badge-struct');
                addGroup(comp.frontais, 'FRONT', 'badge-front');
                addGroup(comp.internas, 'INT', 'badge-intern');
                addGroup(comp.gavetas, 'GAV', 'badge-drawer');
                addGroup(comp.ferragens, 'HW', 'badge-hw');

                html += '</ul>';
                return html;
              }

              // ── Nível Peça ──
              function renderPeca(d) {
                if (!d) return '<div class="empty-hint">Dados da peca indisponiveis</div>';

                var html = '';

                // Card: Identidade
                html += '<div class="card"><h3>Peca</h3>';
                html += '<div class="field"><label>Nome</label><span class="value">' + esc(d.nome) + '</span></div>';
                html += '<div class="field"><label>Tipo</label><span class="value">' + esc(d.tipo) + (d.subtipo ? ' (' + d.subtipo + ')' : '') + '</span></div>';
                html += '<div class="field"><label>Na lista corte</label><span class="status ' + (d.na_lista_corte ? 'status-ok' : 'status-warn') + '">' + (d.na_lista_corte ? 'Sim' : 'Nao') + '</span></div>';
                html += '</div>';

                // Card: Dimensões
                html += '<div class="card"><h3>Dimensoes</h3>';
                html += '<div class="field"><label>Comprimento</label><span class="value">' + round1(d.comp_mm) + ' mm</span></div>';
                html += '<div class="field"><label>Largura</label><span class="value">' + round1(d.larg_mm) + ' mm</span></div>';
                html += '<div class="field"><label>Espessura</label><span class="value">' + round1(d.espessura_mm) + ' mm (real: ' + round1(d.espessura_real_mm) + ')</span></div>';
                html += '</div>';

                // Card: Material
                html += '<div class="card"><h3>Material</h3>';
                html += '<div class="field"><label>Material</label><span class="value" style="font-size:11px">' + esc(d.material) + '</span></div>';
                html += '<div class="field"><label>Grao</label><span class="value">' + esc(d.grao) + '</span></div>';
                html += '<div class="field"><label>Face visivel</label><span class="value">' + esc(d.face_visivel) + '</span></div>';
                html += '</div>';

                // Card: Bordas (diagrama visual + código)
                var bordaCode = calcBordaCode(d.bordas);
                html += '<div class="card"><h3>Bordas <span class="item-badge badge-struct" style="float:right">' + bordaCode + '</span></h3>';
                html += renderBordaDiagram(d.bordas);
                html += '</div>';

                // Card: Operações (lista clicável)
                if (d.operacoes && d.operacoes.length > 0) {
                  html += '<div class="card"><h3>Operacoes (' + d.operacoes.length + ')</h3>';
                  html += '<ul class="item-list">';
                  d.operacoes.forEach(function(op) {
                    html += '<li onclick="selectEntity(' + op.entity_id + ')">' +
                      '<span class="item-name">' + esc(op.nome) + '</span>' +
                      '<span class="item-badge badge-hw">' + esc(op.subtipo) + '</span></li>';
                  });
                  html += '</ul></div>';
                }

                return html;
              }

              function calcBordaCode(bordas) {
                if (!bordas) return 'SEM';
                var c = 0, l = 0;
                if (bordas.frontal) c++;
                if (bordas.traseira) c++;
                if (bordas.esquerda) l++;
                if (bordas.direita) l++;
                var total = c + l;
                if (total === 0) return 'SEM';
                if (total === 4) return '4L';
                if (c === 2 && l === 0) return '2C';
                if (c === 0 && l === 2) return '2L';
                if (c === 1 && l === 0) return '1C';
                if (c === 0 && l === 1) return '1L';
                if (c === 2 && l === 1) return '2C+1L';
                if (c === 1 && l === 2) return '1C+2L';
                if (c === 1 && l === 1) return '1C+1L';
                return total + 'L';
              }

              function renderBordaDiagram(bordas) {
                if (!bordas) return '';
                var f = bordas.frontal ? 'active' : 'inactive';
                var t = bordas.traseira ? 'active' : 'inactive';
                var e = bordas.esquerda ? 'active' : 'inactive';
                var d = bordas.direita ? 'active' : 'inactive';

                return '<div class="borda-diagram">' +
                  '<div class="borda-top"><button class="borda-btn ' + f + '">F</button></div>' +
                  '<div class="borda-left"><button class="borda-btn ' + e + '" style="height:100%">E</button></div>' +
                  '<div class="borda-center">PECA</div>' +
                  '<div class="borda-right"><button class="borda-btn ' + d + '" style="height:100%">D</button></div>' +
                  '<div class="borda-bottom"><button class="borda-btn ' + t + '">T</button></div>' +
                  '</div>' +
                  '<div style="text-align:center;font-size:10px;color:#999">Prioridade: ' + (bordas.prioridade || 'comprimento') + '</div>';
              }

              // ── Nível Operação ──
              function renderOperacao(d) {
                if (!d) return '<div class="empty-hint">Dados da operacao indisponiveis</div>';

                var html = '';
                html += '<div class="card"><h3>Operacao / Ferragem</h3>';
                html += '<div class="field"><label>Nome</label><span class="value">' + esc(d.nome) + '</span></div>';
                html += '<div class="field"><label>Tipo</label><span class="value">' + esc(d.subtipo) + '</span></div>';
                if (d.marca) html += '<div class="field"><label>Marca</label><span class="value">' + esc(d.marca) + '</span></div>';
                if (d.modelo) html += '<div class="field"><label>Modelo</label><span class="value">' + esc(d.modelo) + '</span></div>';
                html += '</div>';

                // Card: Posicao e dimensoes CNC
                if (d.diametro || d.profundidade || d.face) {
                  html += '<div class="card"><h3>Dados CNC</h3>';
                  if (d.face) html += '<div class="field"><label>Face</label><span class="value">' + esc(d.face) + '</span></div>';
                  if (d.diametro) html += '<div class="field"><label>Diametro</label><span class="value">' + round1(d.diametro) + ' mm</span></div>';
                  if (d.profundidade) html += '<div class="field"><label>Profundidade</label><span class="value">' + round1(d.profundidade) + ' mm</span></div>';
                  html += '</div>';
                }

                // Card: Posição 3D
                if (d.pos_x || d.pos_y || d.pos_z) {
                  html += '<div class="card"><h3>Posicao</h3>';
                  html += '<div class="field"><label>X</label><span class="value">' + round1(d.pos_x) + ' mm</span></div>';
                  html += '<div class="field"><label>Y</label><span class="value">' + round1(d.pos_y) + ' mm</span></div>';
                  html += '<div class="field"><label>Z</label><span class="value">' + round1(d.pos_z) + ' mm</span></div>';
                  html += '</div>';
                }

                return html;
              }

              // ═══════════════════════════════════════════════
              // Agregados permitidos por tipo
              // ═══════════════════════════════════════════════
              var AGREGADOS = {
                inferior:     [{tipo:'porta_unica',label:'Porta'},{tipo:'prateleira',label:'Prateleira'},{tipo:'gaveta',label:'Gaveta'},{tipo:'divisoria',label:'Divisoria'}],
                superior:     [{tipo:'porta_unica',label:'Porta'},{tipo:'basculante',label:'Basculante'},{tipo:'prateleira',label:'Prateleira'},{tipo:'divisoria',label:'Divisoria'}],
                torre:        [{tipo:'porta_unica',label:'Porta'},{tipo:'prateleira',label:'Prateleira'},{tipo:'divisoria',label:'Divisoria'}],
                gaveteiro:    [{tipo:'gaveta',label:'Gaveta'},{tipo:'divisoria',label:'Divisoria'}],
                estante:      [{tipo:'prateleira',label:'Prateleira'},{tipo:'divisoria',label:'Divisoria'}],
                roupeiro:     [{tipo:'porta_unica',label:'Porta'},{tipo:'porta_correr',label:'Correr'},{tipo:'prateleira',label:'Prateleira'},{tipo:'gaveta',label:'Gaveta'},{tipo:'divisoria',label:'Divisoria'}],
                bancada:      [{tipo:'prateleira',label:'Prateleira'}],
                pia:          [{tipo:'porta_unica',label:'Porta'},{tipo:'gaveta',label:'Gaveta'}],
                nicho:        [{tipo:'prateleira',label:'Prateleira'}],
                torre_quente: [{tipo:'porta_unica',label:'Porta'},{tipo:'prateleira',label:'Prateleira'}],
                cooktop:      [{tipo:'porta_unica',label:'Porta'},{tipo:'gaveta',label:'Gaveta'}],
                micro_ondas:  [{tipo:'basculante',label:'Basculante'},{tipo:'prateleira',label:'Prateleira'}],
                lava_louca:   [{tipo:'porta_unica',label:'Porta'}],
                canto_l:      [{tipo:'porta_unica',label:'Porta'},{tipo:'prateleira',label:'Prateleira'}],
                canto_l_superior:[{tipo:'basculante',label:'Basculante'},{tipo:'prateleira',label:'Prateleira'}],
                ilha:         [{tipo:'porta_unica',label:'Porta'},{tipo:'prateleira',label:'Prateleira'},{tipo:'gaveta',label:'Gaveta'},{tipo:'divisoria',label:'Divisoria'}],
                espelheira:   [{tipo:'porta_unica',label:'Porta'},{tipo:'porta_dupla',label:'Porta Dupla'},{tipo:'prateleira',label:'Prateleira'}],
                pia_banheiro: [{tipo:'porta_unica',label:'Porta'},{tipo:'porta_dupla',label:'Porta Dupla'},{tipo:'gaveta',label:'Gaveta'},{tipo:'prateleira',label:'Prateleira'}]
              };

              function getAgregadosPermitidos(tipo) {
                return AGREGADOS[tipo] || [{tipo:'porta_unica',label:'Porta'},{tipo:'prateleira',label:'Prateleira'}];
              }

              // ═══════════════════════════════════════════════
              // Comunicação com Ruby
              // ═══════════════════════════════════════════════
              function navigateTo(entityId, nivel) {
                if (nivel === 'projeto') {
                  // Limpar seleção → observer vai detectar nível projeto
                  sketchup.ornato_navigate('0');
                  return;
                }
                if (entityId) {
                  sketchup.ornato_navigate('' + entityId);
                }
              }

              function selectEntity(entityId) {
                if (entityId) {
                  sketchup.ornato_select_entity('' + entityId);
                }
              }

              function sendAction(action, payload) {
                var data = JSON.stringify({ action: action, payload: payload });
                sketchup.ornato_action(data);
              }

              // ═══════════════════════════════════════════════
              // Utilitários
              // ═══════════════════════════════════════════════
              function esc(s) { return s ? String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;') : ''; }
              function round1(v) { return v ? Math.round(v * 10) / 10 : 0; }

              // ═══════════════════════════════════════════════
              // Dark Mode toggle
              // ═══════════════════════════════════════════════
              function toggleDark() {
                document.body.classList.toggle('dark');
                // Persistir preferência
                try { localStorage.setItem('ornato_dark', document.body.classList.contains('dark') ? '1' : '0'); } catch(e) {}
              }
              // Restaurar preferência
              try { if (localStorage.getItem('ornato_dark') === '1') document.body.classList.add('dark'); } catch(e) {}

              // ═══════════════════════════════════════════════
              // Atalhos de teclado (produtividade projetista)
              // ═══════════════════════════════════════════════
              document.addEventListener('keydown', function(e) {
                // Ignorar se estiver digitando em input
                if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;

                // V = Validar
                if (e.key === 'v' || e.key === 'V') {
                  if (currentLevel === 'modulo') sendAction('validate_module', {});
                  else if (currentLevel === 'projeto') sendAction('validate_all', {});
                }
                // E = Exportar
                if (e.key === 'e' || e.key === 'E') {
                  sendAction('export_project', {});
                }
                // Escape = Voltar ao nivel projeto
                if (e.key === 'Escape') {
                  navigateTo(0, 'projeto');
                }
                // W/H/D = Focar campo largura/altura/profundidade
                if (currentLevel === 'modulo') {
                  if (e.key === 'w' || e.key === 'W') { var el = document.getElementById('dim-w'); if (el) { el.focus(); el.select(); e.preventDefault(); } }
                  if (e.key === 'h' || e.key === 'H') { var el = document.getElementById('dim-h'); if (el) { el.focus(); el.select(); e.preventDefault(); } }
                  if (e.key === 'd' || e.key === 'D') { var el = document.getElementById('dim-d'); if (el) { el.focus(); el.select(); e.preventDefault(); } }
                }
              });

              // Notificar Ruby que JS está pronto
              sketchup.ornato_ready();
            </script>

            <div class="shortcut-footer" style="position:fixed;bottom:0;left:0;right:0;background:#f8f8f8;border-top:1px solid #e0e0e0;padding:4px 12px;font-size:9px;color:#aaa;display:flex;justify-content:space-between">
              <span>V validar · E exportar · Esc projeto</span>
              <span>W/H/D focar dimensao</span>
            </div>
          </body>
          </html>
        HTML
      end
    end
  end
end
