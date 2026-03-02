# ornato_plugin/ui/painel_usinagem.rb — Painel de visualização 2D de usinagens
# Semelhante ao peaceMachining.html do UpMobb
# Mostra SVG renderizado com furos, canais, fresagens em vista 2D da peça

module Ornato
  module UI
    class PainelUsinagem

      def initialize
        @dialog = nil
      end

      # Mostra o painel de usinagem para uma peça
      # @param grupo [Sketchup::Group] — grupo da peça (com DICT_PECA)
      # @param modulo_info [ModuloInfo, nil] — módulo pai (se houver)
      def mostrar(grupo, modulo_info = nil)
        peca_data = extrair_dados_peca(grupo)
        return unless peca_data

        usinagens = coletar_usinagens(grupo, modulo_info)

        html = gerar_html(peca_data, usinagens)

        @dialog = ::UI::HtmlDialog.new(
          dialog_title: "Ornato — Usinagens: #{peca_data[:nome]}",
          width: 900,
          height: 700,
          resizable: true,
          style: ::UI::HtmlDialog::STYLE_DIALOG
        )

        @dialog.add_action_callback('fechar') { @dialog.close }
        @dialog.add_action_callback('toggle_lado') do |_ctx, lado|
          # Callback para trocar lado A/B (futuro)
          puts "[Ornato] Painel usinagem: toggle lado #{lado}"
        end

        @dialog.set_html(html)
        @dialog.show
      end

      def visivel?
        @dialog && @dialog.visible?
      end

      private

      # ═══ Extrai dados da peça do grupo ═══
      def extrair_dados_peca(grupo)
        dict = Config::DICT_PECA
        tipo = Utils.get_attr(grupo, dict, 'tipo')
        return nil unless tipo

        {
          nome: Utils.get_attr(grupo, dict, 'nome') || grupo.name,
          tipo: tipo,
          comprimento: (Utils.get_attr(grupo, dict, 'comprimento') || 0).to_f,
          largura: (Utils.get_attr(grupo, dict, 'largura') || 0).to_f,
          espessura: (Utils.get_attr(grupo, dict, 'espessura') || 15).to_f,
          espessura_real: (Utils.get_attr(grupo, dict, 'espessura_real') || 15.5).to_f,
          material: Utils.get_attr(grupo, dict, 'material') || 'MDF',
          tem_contorno: Utils.get_attr(grupo, dict, 'tem_contorno') || false
        }
      end

      # ═══ Coleta usinagens (automáticas + manuais) ═══
      def coletar_usinagens(grupo, modulo_info)
        usinagens = []

        # Usinagens automáticas (se tiver módulo pai)
        if modulo_info
          tipo_sym = Utils.get_attr(grupo, Config::DICT_PECA, 'tipo')&.to_sym
          peca_tmp = Models::Peca.new(
            nome: Utils.get_attr(grupo, Config::DICT_PECA, 'nome'),
            tipo: tipo_sym,
            comprimento: Utils.get_attr(grupo, Config::DICT_PECA, 'comprimento').to_f,
            largura: Utils.get_attr(grupo, Config::DICT_PECA, 'largura').to_f,
            espessura: Utils.get_attr(grupo, Config::DICT_PECA, 'espessura').to_f
          )

          # Gerar usinagens automáticas para esta peça
          begin
            auto = Engines::MotorUsinagem.canal_fundo(peca_tmp, modulo_info)
            usinagens.concat(auto)

            if [:lateral_gaveta, :frente_gaveta, :traseira_gaveta].include?(tipo_sym)
              usinagens.concat(Engines::MotorUsinagem.canal_fundo_gaveta(peca_tmp))
            end

            if tipo_sym == :porta
              qtd = Utils.qtd_dobradicas(peca_tmp.comprimento)
              posicoes = (1..qtd).map { |i|
                recuo = Config::DOBRADICA_RECUO_BORDA
                if qtd <= 1
                  recuo
                else
                  recuo + ((peca_tmp.comprimento - 2 * recuo) / (qtd - 1).to_f * (i - 1))
                end
              }
              usinagens.concat(Engines::MotorUsinagem.pocket_dobradica(peca_tmp, posicoes))
            end
          rescue => e
            puts "[Ornato] Painel usinagem: erro usinagens auto: #{e.message}"
          end
        end

        # Usinagens manuais (do dicionário do grupo)
        begin
          manuais_json = Utils.get_attr(grupo, Config::DICT_PECA, 'usinagens_manuais')
          if manuais_json && !manuais_json.empty?
            manuais = Utils.parse_json(manuais_json)
            if manuais.is_a?(Array)
              manuais.each do |m|
                usinagens << Engines::MotorUsinagem::Usinagem.new(
                  tipo: (m[:tipo] || m['tipo'] || 'furo').to_sym,
                  x: (m[:x] || m['x'] || 0).to_f,
                  y: (m[:y] || m['y'] || 0).to_f,
                  comprimento: (m[:comprimento] || m['comprimento'] || 0).to_f,
                  largura: (m[:largura] || m['largura'] || 0).to_f,
                  profundidade: (m[:profundidade] || m['profundidade'] || 0).to_f,
                  diametro: (m[:diametro] || m['diametro'] || 0).to_f,
                  face: (m[:face] || m['face'] || 'superior').to_sym,
                  ferramenta: (m[:ferramenta] || m['ferramenta'] || 0).to_f,
                  descricao: m[:descricao] || m['descricao'] || "#{m[:tipo] || m['tipo']} manual",
                  peca_nome: (m[:peca_nome] || m['peca_nome'] || '')
                )
              end
            end
          end
        rescue => e
          puts "[Ornato] Painel usinagem: erro usinagens manuais: #{e.message}"
        end

        usinagens
      end

      # ═══ Gerar HTML com SVG ═══
      def gerar_html(peca, usinagens)
        comp = peca[:comprimento]
        larg = peca[:largura]

        # Escala SVG
        svg_w = 700
        svg_h = 500
        scale = [svg_w / (comp + 40), svg_h / (larg + 40)].min
        scale = [scale, 0.5].max  # mínimo 0.5

        margin = 20

        # Gerar elementos SVG das usinagens
        svg_usinagens = usinagens.map { |u| svg_usinagem(u, scale, margin) }.compact.join("\n")

        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <title>Ornato — Usinagens: #{peca[:nome]}</title>
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              body { font-family: 'Segoe UI', Arial, sans-serif; background: #1a1a2e; color: #eee; }
              .header {
                background: #e67e22; color: #fff; padding: 12px 20px;
                display: flex; justify-content: space-between; align-items: center;
              }
              .header h2 { font-size: 16px; font-weight: 600; }
              .header .info { font-size: 12px; opacity: 0.9; }
              .container { display: flex; height: calc(100vh - 52px); }
              .sidebar {
                width: 240px; background: #16213e; padding: 15px;
                overflow-y: auto; border-right: 1px solid #333;
              }
              .sidebar h3 { font-size: 13px; color: #e67e22; margin-bottom: 10px; border-bottom: 1px solid #333; padding-bottom: 5px; }
              .info-row { font-size: 12px; margin-bottom: 6px; display: flex; justify-content: space-between; }
              .info-row .label { color: #999; }
              .info-row .value { color: #fff; font-weight: 500; }
              .usi-list { margin-top: 15px; }
              .usi-item {
                font-size: 11px; padding: 6px 8px; margin-bottom: 4px;
                background: #1a1a2e; border-radius: 4px; border-left: 3px solid #e67e22;
              }
              .usi-item .usi-tipo { font-weight: 600; color: #e67e22; }
              .usi-item .usi-pos { color: #888; margin-top: 2px; }
              .main-area { flex: 1; padding: 20px; display: flex; flex-direction: column; align-items: center; }
              .svg-container {
                background: #fff; border-radius: 6px; overflow: hidden;
                box-shadow: 0 4px 12px rgba(0,0,0,0.3);
              }
              .legend {
                display: flex; gap: 15px; margin-top: 15px; flex-wrap: wrap;
              }
              .legend-item { display: flex; align-items: center; gap: 5px; font-size: 11px; }
              .legend-dot { width: 12px; height: 12px; border-radius: 50%; }
              .lado-toggle {
                display: flex; gap: 5px; margin-bottom: 15px;
              }
              .lado-btn {
                padding: 6px 16px; border: 1px solid #e67e22; border-radius: 4px;
                background: transparent; color: #e67e22; cursor: pointer; font-size: 12px;
              }
              .lado-btn.active { background: #e67e22; color: #fff; }
              .stats {
                display: flex; gap: 20px; margin-top: 10px;
              }
              .stat { font-size: 11px; color: #999; }
              .stat span { color: #e67e22; font-weight: 600; }
            </style>
          </head>
          <body>
            <div class="header">
              <h2>#{peca[:nome]}</h2>
              <div class="info">#{peca[:comprimento].round(1)} x #{peca[:largura].round(1)} x #{peca[:espessura]}mm | #{peca[:material]}</div>
            </div>
            <div class="container">
              <div class="sidebar">
                <h3>Informacoes da Peca</h3>
                <div class="info-row"><span class="label">Tipo:</span><span class="value">#{peca[:tipo]}</span></div>
                <div class="info-row"><span class="label">Comprimento:</span><span class="value">#{peca[:comprimento].round(1)} mm</span></div>
                <div class="info-row"><span class="label">Largura:</span><span class="value">#{peca[:largura].round(1)} mm</span></div>
                <div class="info-row"><span class="label">Espessura:</span><span class="value">#{peca[:espessura]} mm</span></div>
                <div class="info-row"><span class="label">Esp. Real:</span><span class="value">#{peca[:espessura_real]} mm</span></div>
                <div class="info-row"><span class="label">Material:</span><span class="value">#{peca[:material]}</span></div>
                <div class="info-row"><span class="label">Contorno:</span><span class="value">#{peca[:tem_contorno] ? 'Sim' : 'Retangular'}</span></div>

                <div class="usi-list">
                  <h3>Usinagens (#{usinagens.length})</h3>
                  #{usinagens.map.with_index { |u, i|
                    "<div class='usi-item'>
                      <div class='usi-tipo'>#{i + 1}. #{u.tipo} #{u.diametro && u.diametro > 0 ? "O#{u.diametro.round(1)}mm" : ''}</div>
                      <div class='usi-pos'>Pos: (#{(u.x || 0).round(1)}, #{(u.y || 0).round(1)}) | Prof: #{(u.profundidade || 0).round(1)}mm</div>
                      <div class='usi-pos'>Face: #{u.face} | Ferr: O#{(u.ferramenta || 0).round(1)}mm</div>
                    </div>"
                  }.join("\n")}
                </div>
              </div>

              <div class="main-area">
                <div class="lado-toggle">
                  <button class="lado-btn active" onclick="this.classList.add('active');this.nextElementSibling.classList.remove('active')">Lado A (Superior)</button>
                  <button class="lado-btn" onclick="this.classList.add('active');this.previousElementSibling.classList.remove('active')">Lado B (Inferior)</button>
                </div>

                <div class="svg-container">
                  <svg width="#{(comp * scale + margin * 2).round(0)}" height="#{(larg * scale + margin * 2).round(0)}"
                       viewBox="0 0 #{(comp * scale + margin * 2).round(0)} #{(larg * scale + margin * 2).round(0)}">
                    <!-- Fundo -->
                    <rect x="0" y="0" width="100%" height="100%" fill="#f8f8f8"/>

                    <!-- Contorno da peca -->
                    <rect x="#{margin}" y="#{margin}"
                          width="#{(comp * scale).round(1)}" height="#{(larg * scale).round(1)}"
                          fill="#f0ead6" stroke="#333" stroke-width="2"/>

                    <!-- Cotas -->
                    <text x="#{(margin + comp * scale / 2).round(1)}" y="#{margin - 5}"
                          text-anchor="middle" font-size="11" fill="#666">#{comp.round(1)} mm</text>
                    <text x="#{margin - 5}" y="#{(margin + larg * scale / 2).round(1)}"
                          text-anchor="middle" font-size="11" fill="#666"
                          transform="rotate(-90, #{margin - 5}, #{(margin + larg * scale / 2).round(1)})">#{larg.round(1)} mm</text>

                    <!-- Usinagens -->
                    #{svg_usinagens}

                    <!-- Centro de referencia -->
                    <line x1="#{margin}" y1="#{(margin + larg * scale / 2).round(1)}"
                          x2="#{(margin + comp * scale).round(1)}" y2="#{(margin + larg * scale / 2).round(1)}"
                          stroke="#ccc" stroke-width="0.5" stroke-dasharray="4,4"/>
                    <line x1="#{(margin + comp * scale / 2).round(1)}" y1="#{margin}"
                          x2="#{(margin + comp * scale / 2).round(1)}" y2="#{(margin + larg * scale).round(1)}"
                          stroke="#ccc" stroke-width="0.5" stroke-dasharray="4,4"/>
                  </svg>
                </div>

                <div class="legend">
                  <div class="legend-item"><div class="legend-dot" style="background:#e74c3c"></div> Furos</div>
                  <div class="legend-item"><div class="legend-dot" style="background:#e74c3c;opacity:0.5;border:1px dashed #e74c3c"></div> Furos de topo</div>
                  <div class="legend-item"><div class="legend-dot" style="background:#d4a574;border-radius:2px"></div> Rebaixos/Canais</div>
                  <div class="legend-item"><div class="legend-dot" style="background:#e67e22;border-radius:2px"></div> Fresagens</div>
                  <div class="legend-item"><div class="legend-dot" style="background:#3498db;border-radius:2px"></div> Pockets</div>
                </div>

                <div class="stats">
                  <div class="stat">Total: <span>#{usinagens.length}</span> operacoes</div>
                  <div class="stat">Furos: <span>#{usinagens.count { |u| u.tipo == :furo || u.tipo == :pocket }}</span></div>
                  <div class="stat">Canais: <span>#{usinagens.count { |u| u.tipo == :canal || u.tipo == :rebaixo || u.tipo == :dado }}</span></div>
                  <div class="stat">Fresagens: <span>#{usinagens.count { |u| u.tipo == :fresagem_perfil || u.tipo == :rasgo }}</span></div>
                </div>
              </div>
            </div>
          </body>
          </html>
        HTML
      end

      # ═══ Gerar SVG de uma usinagem individual ═══
      def svg_usinagem(u, scale, margin)
        x = (u.x || 0) * scale + margin
        y = (u.y || 0) * scale + margin

        case u.tipo
        when :furo
          r = ((u.diametro || 5) / 2.0) * scale
          r = [r, 3].max  # mínimo 3px
          borda = u.face.to_s.include?('borda') ? 'stroke-dasharray="3,2"' : ''
          "<circle cx=\"#{x.round(1)}\" cy=\"#{y.round(1)}\" r=\"#{r.round(1)}\" fill=\"rgba(231,76,60,0.4)\" stroke=\"#e74c3c\" stroke-width=\"1.5\" #{borda}/>
           <line x1=\"#{(x - r * 0.5).round(1)}\" y1=\"#{y.round(1)}\" x2=\"#{(x + r * 0.5).round(1)}\" y2=\"#{y.round(1)}\" stroke=\"#c0392b\" stroke-width=\"0.8\"/>
           <line x1=\"#{x.round(1)}\" y1=\"#{(y - r * 0.5).round(1)}\" x2=\"#{x.round(1)}\" y2=\"#{(y + r * 0.5).round(1)}\" stroke=\"#c0392b\" stroke-width=\"0.8\"/>"

        when :pocket
          r = ((u.diametro || 35) / 2.0) * scale
          r = [r, 5].max
          "<circle cx=\"#{x.round(1)}\" cy=\"#{y.round(1)}\" r=\"#{r.round(1)}\" fill=\"rgba(52,152,219,0.3)\" stroke=\"#3498db\" stroke-width=\"1.5\"/>
           <circle cx=\"#{x.round(1)}\" cy=\"#{y.round(1)}\" r=\"#{(r * 0.15).round(1)}\" fill=\"#3498db\"/>"

        when :canal, :dado
          comp = ((u.comprimento || 100) * scale).round(1)
          larg = ((u.largura || 6) * scale).round(1)
          larg = [larg, 2].max
          "<rect x=\"#{x.round(1)}\" y=\"#{(y - larg / 2).round(1)}\" width=\"#{comp}\" height=\"#{larg}\" fill=\"rgba(212,165,116,0.5)\" stroke=\"#d4a574\" stroke-width=\"1\"/>"

        when :rebaixo
          comp = ((u.comprimento || 100) * scale).round(1)
          larg = ((u.largura || 10) * scale).round(1)
          larg = [larg, 3].max
          "<rect x=\"#{x.round(1)}\" y=\"#{(y - larg / 2).round(1)}\" width=\"#{comp}\" height=\"#{larg}\" fill=\"rgba(212,165,116,0.3)\" stroke=\"#d4a574\" stroke-width=\"1\" stroke-dasharray=\"4,2\"/>"

        when :fresagem_perfil, :rasgo
          comp = ((u.comprimento || 100) * scale).round(1)
          larg = ((u.largura || 10) * scale).round(1)
          larg = [larg, 2].max
          "<rect x=\"#{x.round(1)}\" y=\"#{(y - larg / 2).round(1)}\" width=\"#{comp}\" height=\"#{larg}\" fill=\"rgba(230,126,34,0.3)\" stroke=\"#e67e22\" stroke-width=\"1\"/>"

        else
          # Genérico — ponto
          "<circle cx=\"#{x.round(1)}\" cy=\"#{y.round(1)}\" r=\"4\" fill=\"#e67e22\" stroke=\"#c0392b\" stroke-width=\"1\"/>"
        end
      end

    end
  end
end
