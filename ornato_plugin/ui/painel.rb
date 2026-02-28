# ornato_plugin/ui/painel.rb — Painel lateral principal (HtmlDialog)

module Ornato
  module UI
    class Painel
      def initialize
        @dialog = nil
      end

      def mostrar
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          return
        end

        @dialog = ::UI::HtmlDialog.new(
          dialog_title: 'Ornato Marcenaria',
          width: 340,
          height: 750,
          left: 100,
          top: 100,
          style: ::UI::HtmlDialog::STYLE_UTILITY
        )

        @dialog.set_html(html_conteudo)
        registrar_callbacks
        @dialog.show
        atualizar
      end

      def visivel?
        @dialog && @dialog.visible?
      end

      def atualizar
        return unless visivel?

        modulos = Utils.listar_modulos
        dados = modulos.map do |grupo|
          mi = Models::ModuloInfo.carregar_do_grupo(grupo)
          next unless mi
          {
            id: mi.id,
            nome: mi.nome,
            tipo: mi.tipo.to_s,
            ambiente: mi.ambiente,
            largura: mi.largura,
            altura: mi.altura,
            profundidade: mi.profundidade,
            material_corpo: mi.material_corpo,
            material_frente: mi.material_frente,
            pecas_count: grupo.entities.select { |e| e.get_attribute(Config::DICT_PECA, 'nome') }.length
          }
        end.compact

        # Agrupa por ambiente
        por_ambiente = {}
        dados.each do |d|
          amb = d[:ambiente] || 'Geral'
          por_ambiente[amb] ||= []
          por_ambiente[amb] << d
        end

        json = Utils.to_json(por_ambiente)
        @dialog.execute_script("atualizarArvore(#{json})")

        # Resumo
        total_modulos = dados.length
        total_pecas = dados.sum { |d| d[:pecas_count] }
        @dialog.execute_script("atualizarResumo(#{total_modulos}, #{total_pecas})")
      end

      private

      def registrar_callbacks
        @dialog.add_action_callback('selecionar_modulo') do |_ctx, modulo_id|
          modulos = Utils.listar_modulos
          grupo = modulos.find { |g| g.get_attribute(Config::DICT_MODULO, 'id') == modulo_id }
          if grupo
            Sketchup.active_model.selection.clear
            Sketchup.active_model.selection.add(grupo)
          end
        end

        @dialog.add_action_callback('editar_modulo') do |_ctx, modulo_id|
          modulos = Utils.listar_modulos
          grupo = modulos.find { |g| g.get_attribute(Config::DICT_MODULO, 'id') == modulo_id }
          if grupo
            Ornato::UI::Propriedades.mostrar(grupo)
          end
        end

        @dialog.add_action_callback('nova_caixa') do |_ctx|
          Sketchup.active_model.select_tool(Tools::CaixaTool.new)
        end

        @dialog.add_action_callback('abrir_templates') do |_ctx|
          Sketchup.active_model.select_tool(Tools::TemplateTool.new)
        end

        @dialog.add_action_callback('adicionar_agregado') do |_ctx, tipo|
          tipo_sym = tipo.to_sym
          Sketchup.active_model.select_tool(Tools::AgregadoTool.new(tipo_sym))
        end

        @dialog.add_action_callback('pecas_avulsas') do |_ctx|
          Sketchup.active_model.select_tool(Tools::PecasAvulsasTool.new)
        end

        @dialog.add_action_callback('exportar_corte') do |_ctx|
          MenuSetup.exportar_lista_corte
        end

        @dialog.add_action_callback('exportar_plano') do |_ctx|
          MenuSetup.exportar_plano_corte
        end

        @dialog.add_action_callback('exportar_ferragens') do |_ctx|
          MenuSetup.exportar_lista_ferragens
        end

        @dialog.add_action_callback('exportar_fita') do |_ctx|
          MenuSetup.exportar_resumo_fita
        end

        @dialog.add_action_callback('exportar_furacao') do |_ctx|
          MenuSetup.exportar_mapa_furacao
        end

        @dialog.add_action_callback('exportar_usinagem') do |_ctx|
          MenuSetup.exportar_resumo_usinagens
        end

        @dialog.add_action_callback('atualizar') do |_ctx|
          atualizar
        end
      end

      def html_conteudo
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              body {
                font-family: -apple-system, 'Segoe UI', Roboto, sans-serif;
                font-size: 13px; color: #333; background: #fafafa;
                overflow-y: auto;
              }
              .header {
                background: linear-gradient(135deg, #e67e22, #d35400);
                color: white; padding: 14px 16px;
                display: flex; justify-content: space-between; align-items: center;
                position: sticky; top: 0; z-index: 10;
              }
              .header h2 { font-size: 16px; font-weight: 700; }
              .header .version { font-size: 11px; opacity: 0.8; }
              .header .btn-refresh {
                background: none; border: none; color: white; cursor: pointer;
                font-size: 16px; padding: 4px;
              }
              .header .btn-refresh:hover { opacity: 0.8; }

              .toolbar {
                display: flex; gap: 4px; padding: 10px 12px;
                background: white; border-bottom: 1px solid #e0e0e0;
                flex-wrap: wrap;
              }
              .toolbar button {
                flex: 1; min-width: 55px; padding: 8px 4px;
                background: #f8f8f8; border: 1px solid #ddd; border-radius: 4px;
                font-size: 11px; cursor: pointer; text-align: center;
                transition: all 0.15s;
              }
              .toolbar button:hover { background: #e67e22; color: white; border-color: #d35400; }
              .toolbar button.green:hover { background: #27ae60; border-color: #219a52; }
              .toolbar button.purple:hover { background: #8e44ad; border-color: #7d3c98; }

              .section { padding: 12px; }
              .section-title {
                font-size: 12px; font-weight: 700; text-transform: uppercase;
                color: #888; margin-bottom: 8px; letter-spacing: 0.5px;
              }

              .tree-ambiente { margin-bottom: 8px; }
              .tree-ambiente-header {
                display: flex; align-items: center; gap: 6px;
                padding: 6px 8px; background: #f0f0f0; border-radius: 4px;
                cursor: pointer; font-weight: 600; font-size: 12px;
              }
              .tree-ambiente-header:hover { background: #e8e8e8; }
              .tree-modulo {
                display: flex; align-items: center; gap: 6px;
                padding: 6px 8px 6px 24px; cursor: pointer;
                border-radius: 4px; transition: background 0.1s;
              }
              .tree-modulo:hover { background: #fff3e0; }
              .tree-modulo.selected { background: #ffe0b2; font-weight: 600; }
              .tree-modulo .dims {
                font-size: 11px; color: #999; margin-left: auto; white-space: nowrap;
              }
              .tree-modulo .tipo-badge {
                font-size: 10px; background: #e67e22; color: white;
                padding: 1px 5px; border-radius: 10px; white-space: nowrap;
              }

              .resumo {
                background: white; border-top: 1px solid #e0e0e0;
                padding: 12px; position: sticky; bottom: 0;
              }
              .resumo-item {
                display: flex; justify-content: space-between;
                padding: 3px 0; font-size: 12px;
              }
              .resumo-total {
                font-size: 14px; font-weight: 700; color: #e67e22;
                border-top: 1px solid #ddd; padding-top: 6px; margin-top: 4px;
              }

              .empty-state {
                text-align: center; padding: 40px 20px; color: #aaa;
              }
              .empty-state p { margin-bottom: 12px; }
              .btn-primary {
                background: #e67e22; color: white; border: none;
                padding: 10px 20px; border-radius: 4px; cursor: pointer;
                font-weight: 600;
              }
              .btn-primary:hover { background: #d35400; }

              .export-bar {
                display: flex; gap: 4px; padding: 8px 12px;
                border-top: 1px solid #eee; flex-wrap: wrap;
              }
              .export-bar button {
                flex: 1; min-width: 70px; padding: 6px 4px; background: #f0f0f0; border: 1px solid #ddd;
                border-radius: 3px; font-size: 10px; cursor: pointer;
              }
              .export-bar button:hover { background: #e0e0e0; }

              .tabs { display: flex; border-bottom: 2px solid #e0e0e0; background: white; }
              .tab {
                flex: 1; padding: 8px; text-align: center; cursor: pointer;
                font-size: 12px; font-weight: 600; color: #888;
                border-bottom: 2px solid transparent; margin-bottom: -2px;
              }
              .tab:hover { color: #e67e22; }
              .tab.active { color: #e67e22; border-bottom-color: #e67e22; }
              .tab-content { display: none; }
              .tab-content.active { display: block; }
            </style>
          </head>
          <body>
            <div class="header">
              <div>
                <h2>ORNATO</h2>
                <span class="version">Plugin Marcenaria v#{PLUGIN_VERSION}</span>
              </div>
              <button class="btn-refresh" onclick="sketchup.atualizar()" title="Atualizar">&#x21bb;</button>
            </div>

            <div class="toolbar">
              <button onclick="sketchup.nova_caixa()">&#x2B1C; Caixa</button>
              <button class="green" onclick="sketchup.abrir_templates()">&#x1F4CB; Templates</button>
              <button onclick="sketchup.adicionar_agregado('porta')">&#x1F6AA; Porta</button>
              <button onclick="sketchup.adicionar_agregado('gaveta')">&#x1F5C4; Gaveta</button>
              <button onclick="sketchup.adicionar_agregado('prateleira')">&#x1F4E6; Prat.</button>
              <button onclick="sketchup.adicionar_agregado('divisoria')">&#x2702; Div.</button>
              <button class="purple" onclick="sketchup.pecas_avulsas()">&#x1F527; Avulsa</button>
            </div>

            <div class="tabs">
              <div class="tab active" onclick="trocarTab('arvore')">Projeto</div>
              <div class="tab" onclick="trocarTab('exportar')">Exportar</div>
            </div>

            <div id="tab-arvore" class="tab-content active">
              <div class="section">
                <div class="section-title">Arvore do Projeto</div>
                <div id="arvore">
                  <div class="empty-state">
                    <p>Nenhum modulo criado.</p>
                    <button class="btn-primary" onclick="sketchup.nova_caixa()">Criar Primeiro Modulo</button>
                  </div>
                </div>
              </div>
            </div>

            <div id="tab-exportar" class="tab-content">
              <div class="section">
                <div class="section-title">Listas</div>
                <div class="export-bar" style="border-top:none; padding-top:0;">
                  <button onclick="sketchup.exportar_corte()">Lista Corte CSV</button>
                  <button onclick="sketchup.exportar_plano()">Plano Otimizado</button>
                </div>
                <div class="section-title" style="margin-top:8px;">Detalhamento</div>
                <div class="export-bar" style="border-top:none; padding-top:0;">
                  <button onclick="sketchup.exportar_ferragens()">Ferragens</button>
                  <button onclick="sketchup.exportar_fita()">Fita Borda</button>
                  <button onclick="sketchup.exportar_furacao()">Furacao</button>
                  <button onclick="sketchup.exportar_usinagem()">Usinagens</button>
                </div>
              </div>
            </div>

            <div class="resumo" id="resumo">
              <div class="resumo-item">
                <span>Modulos:</span>
                <span id="total_modulos">0</span>
              </div>
              <div class="resumo-item">
                <span>Pecas:</span>
                <span id="total_pecas">0</span>
              </div>
            </div>

            <script>
              function atualizarArvore(dados) {
                var container = document.getElementById('arvore');
                var keys = Object.keys(dados);

                if (keys.length === 0) {
                  container.innerHTML = '<div class="empty-state"><p>Nenhum modulo criado.</p><button class="btn-primary" onclick="sketchup.nova_caixa()">Criar Primeiro Modulo</button></div>';
                  return;
                }

                var html = '';
                keys.sort().forEach(function(ambiente) {
                  html += '<div class="tree-ambiente">';
                  html += '<div class="tree-ambiente-header">';
                  html += '<span>&#x1F4C1;</span> ' + ambiente + ' (' + dados[ambiente].length + ')';
                  html += '</div>';

                  dados[ambiente].forEach(function(mod) {
                    html += '<div class="tree-modulo" onclick="sketchup.selecionar_modulo(\\'' + mod.id + '\\')" ondblclick="sketchup.editar_modulo(\\'' + mod.id + '\\')">';
                    html += '<span>&#x1F4E6;</span> ';
                    html += '<span>' + mod.nome + '</span>';
                    html += '<span class="tipo-badge">' + mod.tipo + '</span>';
                    html += '<span class="dims">' + mod.largura + 'x' + mod.altura + 'x' + mod.profundidade + '</span>';
                    html += '</div>';
                  });

                  html += '</div>';
                });

                container.innerHTML = html;
              }

              function atualizarResumo(totalMod, totalPecas) {
                document.getElementById('total_modulos').textContent = totalMod;
                document.getElementById('total_pecas').textContent = totalPecas;
              }

              function trocarTab(tab) {
                document.querySelectorAll('.tab').forEach(function(t) { t.classList.remove('active'); });
                document.querySelectorAll('.tab-content').forEach(function(c) { c.classList.remove('active'); });

                if (tab === 'arvore') {
                  document.querySelector('.tabs .tab:first-child').classList.add('active');
                  document.getElementById('tab-arvore').classList.add('active');
                } else {
                  document.querySelector('.tabs .tab:last-child').classList.add('active');
                  document.getElementById('tab-exportar').classList.add('active');
                }
              }
            </script>
          </body>
          </html>
        HTML
      end
    end
  end
end
