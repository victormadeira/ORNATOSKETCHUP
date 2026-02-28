# ornato_plugin/ui/catalogo_templates.rb — Painel HTML de catalogo de templates

module Ornato
  module UI
    class CatalogoTemplates
      def self.mostrar(&callback)
        @callback = callback

        dialog = ::UI::HtmlDialog.new(
          dialog_title: 'Ornato: Catalogo de Templates',
          width: 520,
          height: 650,
          style: ::UI::HtmlDialog::STYLE_DIALOG
        )

        dialog.set_html(html_catalogo)

        dialog.add_action_callback('selecionar') do |_ctx, template_id|
          dialog.close
          @callback.call(template_id) if @callback
        end

        dialog.add_action_callback('criar_direto') do |_ctx, template_id|
          dialog.close
          Sketchup.active_model.select_tool(Tools::TemplateTool.new(template_id))
        end

        dialog.add_action_callback('fechar') do |_ctx|
          dialog.close
        end

        dialog.show
      end

      private

      def self.html_catalogo
        categorias = {}
        Engines::MotorTemplates::CATALOGO.each do |id, tmpl|
          cat = tmpl[:categoria].to_s.capitalize
          categorias[cat] ||= []
          categorias[cat] << { id: id, data: tmpl }
        end

        # Carrega customizados
        customizados = Engines::MotorTemplates.carregar_customizados
        unless customizados.empty?
          categorias['Customizado'] ||= []
          customizados.each do |id, data|
            categorias['Customizado'] << { id: id, data: data }
          end
        end

        icones_cat = {
          'Cozinha' => '&#x1F373;',
          'Quarto' => '&#x1F6CF;',
          'Banheiro' => '&#x1F6BF;',
          'Escritorio' => '&#x1F4BC;',
          'Sala' => '&#x1F4FA;',
          'Lavanderia' => '&#x1F9FA;',
          'Customizado' => '&#x2B50;'
        }

        cards_html = ''
        categorias.each do |cat, templates|
          icone = icones_cat[cat] || '&#x1F4E6;'
          cards_html += "<div class='cat-section'>"
          cards_html += "<div class='cat-header'>#{icone} #{cat} <span class='cat-count'>(#{templates.length})</span></div>"
          cards_html += "<div class='cards-grid'>"

          templates.each do |t|
            d = t[:data]
            tipo_label = (d[:tipo] || '').to_s.capitalize
            dims = "#{d[:largura]}x#{d[:altura]}x#{d[:profundidade]}mm"
            esp = "#{d[:espessura] || d[:espessura_corpo]}mm"

            cards_html += <<~CARD
              <div class="card" onclick="selecionar('#{t[:id]}')" title="Clique para usar este template">
                <div class="card-nome">#{d[:nome]}</div>
                <div class="card-tipo">#{tipo_label}</div>
                <div class="card-dims">#{dims}</div>
                <div class="card-esp">Esp: #{esp}</div>
                <div class="card-agreg">#{contar_agregados(d)} componentes</div>
              </div>
            CARD
          end

          cards_html += "</div></div>"
        end

        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              body {
                font-family: -apple-system, 'Segoe UI', Roboto, sans-serif;
                font-size: 13px; color: #333; background: #f5f5f5;
                overflow-y: auto;
              }
              .header {
                background: linear-gradient(135deg, #27ae60, #2ecc71);
                color: white; padding: 14px 16px;
                display: flex; justify-content: space-between; align-items: center;
                position: sticky; top: 0; z-index: 10;
              }
              .header h2 { font-size: 16px; font-weight: 700; }
              .header .subtitle { font-size: 11px; opacity: 0.85; }
              .header .btn-close {
                background: rgba(255,255,255,0.2); border: none; color: white;
                padding: 6px 12px; border-radius: 4px; cursor: pointer; font-size: 12px;
              }
              .header .btn-close:hover { background: rgba(255,255,255,0.3); }

              .search-bar {
                padding: 10px 16px; background: white;
                border-bottom: 1px solid #e0e0e0;
              }
              .search-bar input {
                width: 100%; padding: 8px 12px; border: 1px solid #ddd;
                border-radius: 4px; font-size: 13px;
              }
              .search-bar input:focus { border-color: #27ae60; outline: none; }

              .cat-section { padding: 0 12px; margin-bottom: 4px; }
              .cat-header {
                font-size: 13px; font-weight: 700; color: #555;
                padding: 10px 4px 6px; border-bottom: 1px solid #e0e0e0;
                margin-bottom: 8px;
              }
              .cat-count { font-weight: 400; color: #999; font-size: 12px; }

              .cards-grid {
                display: grid;
                grid-template-columns: repeat(auto-fill, minmax(145px, 1fr));
                gap: 8px; margin-bottom: 12px;
              }
              .card {
                background: white; border: 1px solid #e0e0e0;
                border-radius: 6px; padding: 10px; cursor: pointer;
                transition: all 0.15s;
              }
              .card:hover {
                border-color: #27ae60; box-shadow: 0 2px 8px rgba(39,174,96,0.15);
                transform: translateY(-1px);
              }
              .card-nome {
                font-size: 12px; font-weight: 700; color: #1a1a1a;
                margin-bottom: 4px; line-height: 1.3;
              }
              .card-tipo {
                font-size: 10px; background: #27ae60; color: white;
                display: inline-block; padding: 1px 6px; border-radius: 10px;
                margin-bottom: 4px;
              }
              .card-dims { font-size: 11px; color: #666; }
              .card-esp { font-size: 10px; color: #999; }
              .card-agreg { font-size: 10px; color: #27ae60; margin-top: 3px; }

              .hidden { display: none !important; }
            </style>
          </head>
          <body>
            <div class="header">
              <div>
                <h2>CATALOGO DE TEMPLATES</h2>
                <div class="subtitle">#{Engines::MotorTemplates::CATALOGO.size} templates disponiveis</div>
              </div>
              <button class="btn-close" onclick="sketchup.fechar()">Fechar</button>
            </div>

            <div class="search-bar">
              <input id="busca" placeholder="Buscar template..." oninput="filtrar()" />
            </div>

            <div id="conteudo">
              #{cards_html}
            </div>

            <script>
              function selecionar(id) {
                sketchup.criar_direto(id);
              }

              function filtrar() {
                var termo = document.getElementById('busca').value.toLowerCase();
                var cards = document.querySelectorAll('.card');
                var sections = document.querySelectorAll('.cat-section');

                cards.forEach(function(card) {
                  var texto = card.textContent.toLowerCase();
                  card.classList.toggle('hidden', termo.length > 0 && texto.indexOf(termo) === -1);
                });

                // Esconde categorias vazias
                sections.forEach(function(sec) {
                  var visibleCards = sec.querySelectorAll('.card:not(.hidden)');
                  sec.classList.toggle('hidden', visibleCards.length === 0);
                });
              }
            </script>
          </body>
          </html>
        HTML
      end

      def self.contar_agregados(data)
        agregados = data[:agregados]
        return 0 unless agregados
        agregados.length
      end
    end
  end
end
