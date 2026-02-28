# ornato_plugin/tools/caixa_tool.rb — Ferramenta interativa para criar modulos

module Ornato
  module Tools
    class CaixaTool
      def initialize
        @estado  = :aguardando_clique
        @ponto   = nil
        @modulo  = nil
        @cursor_id = nil
      end

      def activate
        @estado = :aguardando_clique
        Sketchup.active_model.selection.clear
        Sketchup.status_text = 'Ornato: Clique para posicionar o novo modulo'
        mostrar_dialog_config
      end

      def deactivate(view)
        view.invalidate
        @dialog.close if @dialog && @dialog.visible?
      end

      def onMouseMove(flags, x, y, view)
        @mouse_ip = Sketchup::InputPoint.new
        @mouse_ip.pick(view, x, y)
        view.tooltip = 'Clique para posicionar o modulo'
        view.invalidate
      end

      def onLButtonDown(flags, x, y, view)
        return unless @estado == :aguardando_clique

        ip = Sketchup::InputPoint.new
        ip.pick(view, x, y)
        @ponto = ip.position

        criar_modulo(view)
      end

      def onKeyDown(key, repeat, flags, view)
        Sketchup.active_model.select_tool(nil) if key == VK_ESCAPE
      end

      def draw(view)
        return unless @mouse_ip && @estado == :aguardando_clique

        pos = @mouse_ip.position
        l = Utils.mm(@largura || 600)
        a = Utils.mm(@altura || 700)
        p = Utils.mm(@profundidade || 560)

        pts = [
          Geom::Point3d.new(pos.x, pos.y, pos.z),
          Geom::Point3d.new(pos.x + l, pos.y, pos.z),
          Geom::Point3d.new(pos.x + l, pos.y + p, pos.z),
          Geom::Point3d.new(pos.x, pos.y + p, pos.z),
          Geom::Point3d.new(pos.x, pos.y, pos.z)
        ]
        pts_top = pts[0..3].map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + a) }
        pts_top << pts_top[0]

        view.drawing_color = Config::COR_PREVIEW
        view.line_width = 2
        view.draw(GL_LINE_STRIP, pts)
        view.draw(GL_LINE_STRIP, pts_top)

        4.times do |i|
          view.draw(GL_LINES, [pts[i], pts_top[i]])
        end

        view.tooltip = "#{@largura || 600} x #{@altura || 700} x #{@profundidade || 560} mm"
      end

      def getExtents
        bb = Geom::BoundingBox.new
        if @mouse_ip
          bb.add(@mouse_ip.position)
          l = Utils.mm(@largura || 600)
          a = Utils.mm(@altura || 700)
          p = Utils.mm(@profundidade || 560)
          bb.add(@mouse_ip.position.offset(Geom::Vector3d.new(l, p, a)))
        end
        bb
      end

      private

      def mostrar_dialog_config
        @largura        = 600
        @altura         = 700
        @profundidade   = 560
        @tipo           = :inferior
        @espessura      = 15
        @tipo_fundo     = :rebaixado
        @montagem       = :laterais_entre
        @tipo_base      = :pes_regulaveis
        @nome           = 'Modulo'
        @ambiente       = 'Geral'
        @material_corpo = 'MDF Branco TX 15mm'
        @material_frente = 'MDF Carvalho Hanover 15mm'
        @fixacao        = :minifix

        # Gera options de materiais da biblioteca
        materiais_corpo = Models::BibliotecaMateriais.materiais_padrao
          .select { |m| [:corpo, :frente].include?(m.categoria) && m.espessura >= 15 }
          .map(&:nome)
        materiais_frente = Models::BibliotecaMateriais.materiais_padrao
          .select { |m| [:frente, :corpo, :premium].include?(m.categoria) }
          .map(&:nome)

        opts_corpo = materiais_corpo.map { |n|
          sel = n == @material_corpo ? 'selected' : ''
          "<option value=\"#{n}\" #{sel}>#{n}</option>"
        }.join("\n                ")
        opts_frente = materiais_frente.map { |n|
          sel = n == @material_frente ? 'selected' : ''
          "<option value=\"#{n}\" #{sel}>#{n}</option>"
        }.join("\n                ")

        html = <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              body { font-family: -apple-system, 'Segoe UI', sans-serif; padding: 12px; font-size: 13px; background: #f5f5f5; color: #333; overflow-y: auto; }
              h3 { margin-bottom: 10px; font-size: 14px; color: #1a1a1a; border-bottom: 2px solid #e67e22; padding-bottom: 6px; }
              .field { margin-bottom: 8px; }
              label { display: block; font-weight: 600; margin-bottom: 3px; font-size: 12px; color: #555; }
              input, select { width: 100%; padding: 6px 8px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px; }
              input:focus, select:focus { border-color: #e67e22; outline: none; }
              .row { display: flex; gap: 8px; }
              .row .field { flex: 1; }
              .btn { width: 100%; padding: 10px; background: #e67e22; color: white; border: none; border-radius: 4px; font-size: 14px; font-weight: 600; cursor: pointer; margin-top: 10px; }
              .btn:hover { background: #d35400; }
              hr { border: none; border-top: 1px solid #ddd; margin: 10px 0; }
              .section-title { font-size: 11px; font-weight: 700; color: #999; text-transform: uppercase; margin: 8px 0 4px; }
            </style>
          </head>
          <body>
            <h3>NOVO MODULO</h3>

            <div class="row">
              <div class="field">
                <label>Nome</label>
                <input id="nome" value="Modulo" />
              </div>
              <div class="field">
                <label>Ambiente</label>
                <input id="ambiente" value="Geral" />
              </div>
            </div>

            <div class="field">
              <label>Tipo</label>
              <select id="tipo">
                <option value="inferior" selected>Inferior (Base)</option>
                <option value="superior">Superior (Aereo)</option>
                <option value="torre">Torre (Coluna)</option>
                <option value="bancada">Bancada</option>
                <option value="estante">Estante/Nicho</option>
                <option value="gaveteiro">Gaveteiro</option>
                <option value="painel">Painel</option>
              </select>
            </div>

            <hr>
            <div class="section-title">Dimensoes</div>
            <div class="row">
              <div class="field">
                <label>Largura (mm)</label>
                <input id="largura" type="number" value="600" min="100" max="2400" />
              </div>
              <div class="field">
                <label>Altura (mm)</label>
                <input id="altura" type="number" value="700" min="100" max="2700" />
              </div>
              <div class="field">
                <label>Profund. (mm)</label>
                <input id="profundidade" type="number" value="560" min="100" max="800" />
              </div>
            </div>

            <hr>
            <div class="section-title">Materiais</div>
            <div class="field">
              <label>Material Corpo</label>
              <select id="material_corpo">
                #{opts_corpo}
              </select>
            </div>
            <div class="field">
              <label>Material Frente</label>
              <select id="material_frente">
                #{opts_frente}
              </select>
            </div>

            <hr>
            <div class="section-title">Construcao</div>
            <div class="row">
              <div class="field">
                <label>Espessura Corpo</label>
                <select id="espessura">
                  <option value="15" selected>15mm</option>
                  <option value="18">18mm</option>
                  <option value="25">25mm</option>
                </select>
              </div>
              <div class="field">
                <label>Montagem</label>
                <select id="montagem">
                  <option value="laterais_entre" selected>Brasil (lat. entre)</option>
                  <option value="base_topo_entre">Europa (B/T entre)</option>
                </select>
              </div>
            </div>

            <div class="row">
              <div class="field">
                <label>Fundo</label>
                <select id="tipo_fundo">
                  <option value="rebaixado" selected>Rebaixado</option>
                  <option value="sobreposto">Sobreposto</option>
                  <option value="sem_fundo">Sem Fundo</option>
                </select>
              </div>
              <div class="field">
                <label>Base</label>
                <select id="tipo_base">
                  <option value="pes_regulaveis" selected>Pes Regulaveis</option>
                  <option value="rodape">Rodape</option>
                  <option value="direta">Direta (sem recuo)</option>
                  <option value="suspensa">Suspensa (aereo)</option>
                </select>
              </div>
            </div>

            <div class="field">
              <label>Fixacao</label>
              <select id="fixacao">
                <option value="minifix" selected>Minifix</option>
                <option value="vb">VB (Verbolzen)</option>
                <option value="cavilha">Cavilha</option>
                <option value="confirmat">Confirmat</option>
              </select>
            </div>

            <button class="btn" onclick="aplicar()">CLIQUE NO MODELO PARA POSICIONAR</button>

            <script>
              function aplicar() {
                var data = {
                  nome: document.getElementById('nome').value,
                  ambiente: document.getElementById('ambiente').value,
                  tipo: document.getElementById('tipo').value,
                  largura: parseInt(document.getElementById('largura').value),
                  altura: parseInt(document.getElementById('altura').value),
                  profundidade: parseInt(document.getElementById('profundidade').value),
                  espessura: parseInt(document.getElementById('espessura').value),
                  montagem: document.getElementById('montagem').value,
                  tipo_fundo: document.getElementById('tipo_fundo').value,
                  tipo_base: document.getElementById('tipo_base').value,
                  fixacao: document.getElementById('fixacao').value,
                  material_corpo: document.getElementById('material_corpo').value,
                  material_frente: document.getElementById('material_frente').value
                };
                sketchup.configurar(JSON.stringify(data));
              }

              document.querySelectorAll('input, select').forEach(function(el) {
                el.addEventListener('change', aplicar);
              });
            </script>
          </body>
          </html>
        HTML

        @dialog = ::UI::HtmlDialog.new(
          dialog_title: 'Novo Modulo — Ornato',
          width: 340, height: 580,
          style: ::UI::HtmlDialog::STYLE_DIALOG
        )
        @dialog.set_html(html)

        @dialog.add_action_callback('configurar') do |_ctx, json_str|
          data = Utils.parse_json(json_str)
          @nome           = data[:nome] || 'Modulo'
          @ambiente       = data[:ambiente] || 'Geral'
          @tipo           = (data[:tipo] || 'inferior').to_sym
          @largura        = data[:largura] || 600
          @altura         = data[:altura] || 700
          @profundidade   = data[:profundidade] || 560
          @espessura      = data[:espessura] || 15
          @montagem       = (data[:montagem] || 'laterais_entre').to_sym
          @tipo_fundo     = (data[:tipo_fundo] || 'rebaixado').to_sym
          @tipo_base      = (data[:tipo_base] || 'pes_regulaveis').to_sym
          @fixacao        = (data[:fixacao] || 'minifix').to_sym
          @material_corpo = data[:material_corpo] || 'MDF Branco TX 15mm'
          @material_frente = data[:material_frente] || 'MDF Carvalho Hanover 15mm'
        end

        @dialog.show
      end

      def criar_modulo(view)
        mi = Models::ModuloInfo.new(
          nome:            @nome,
          ambiente:        @ambiente,
          tipo:            @tipo,
          largura:         @largura,
          altura:          @altura,
          profundidade:    @profundidade,
          espessura_corpo: @espessura,
          montagem:        @montagem,
          tipo_fundo:      @tipo_fundo,
          tipo_base:       @tipo_base,
          fixacao:         @fixacao,
          material_corpo:  @material_corpo,
          material_frente: @material_frente
        )

        grupo = Engines::MotorCaixa.construir(mi, @ponto)
        if grupo
          Sketchup.active_model.selection.clear
          Sketchup.active_model.selection.add(grupo)
          Sketchup.status_text = "Ornato: Modulo '#{@nome}' criado com sucesso"
          Ornato.painel.atualizar if Ornato.painel.visivel?
        end

        view.invalidate
      end
    end
  end
end
