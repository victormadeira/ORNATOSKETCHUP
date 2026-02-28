# ornato_plugin/ui/propriedades.rb — Painel de propriedades do modulo selecionado

module Ornato
  module UI
    class Propriedades
      def self.mostrar(grupo)
        mi = Models::ModuloInfo.carregar_do_grupo(grupo)
        return unless mi

        dialog = ::UI::HtmlDialog.new(
          dialog_title: "Propriedades: #{mi.nome}",
          width: 380,
          height: 700,
          style: ::UI::HtmlDialog::STYLE_DIALOG
        )

        dialog.set_html(html_propriedades(mi))

        dialog.add_action_callback('aplicar') do |_ctx, json_str|
          data = Utils.parse_json(json_str)
          aplicar_alteracoes(grupo, mi, data)
          dialog.close
        end

        dialog.add_action_callback('cancelar') do |_ctx|
          dialog.close
        end

        dialog.add_action_callback('gerar_furacao') do |_ctx|
          mapa = Engines::MotorFuracao.gerar_mapa(mi)
          validacao = Engines::MotorFuracao.validar(mapa)
          total_furos = mapa.values.flatten.length
          msg = "Mapa de Furacao Gerado\n\n"
          msg += "Total de furos: #{total_furos}\n"
          mapa.each { |peca, furos| msg += "  #{peca}: #{furos.length} furos\n" }
          if validacao[:colisoes].any?
            msg += "\nColisoes detectadas: #{validacao[:colisoes].length}"
          else
            msg += "\nSem colisoes detectadas."
          end
          ::UI.messagebox(msg, MB_OK)
        end

        dialog.add_action_callback('gerar_usinagem') do |_ctx|
          usinagens = Engines::MotorUsinagem.gerar_usinagens_modulo(mi)
          colisoes = Engines::MotorUsinagem.validar_colisoes(usinagens)
          msg = "Usinagens Geradas\n\n"
          msg += "Total: #{usinagens.length} operacoes\n"
          tipos = usinagens.map(&:tipo).tally
          tipos.each { |tipo, qtd| msg += "  #{tipo}: #{qtd}\n" }
          if colisoes.any?
            msg += "\nColisoes: #{colisoes.length}"
            colisoes.first(3).each { |c| msg += "\n  #{c}" }
          else
            msg += "\nSem colisoes."
          end
          ::UI.messagebox(msg, MB_OK)
        end

        dialog.add_action_callback('aplicar_fita') do |_ctx|
          Engines::MotorFitaBorda.aplicar_regra(mi)
          relatorio = Engines::MotorFitaBorda.relatorio(mi)
          msg = "Fita de Borda Aplicada\n\n"
          relatorio.each { |tipo, metros| msg += "#{tipo}: #{metros.round(2)}m\n" }
          msg += "\nTotal: #{relatorio.values.sum.round(2)}m"
          ::UI.messagebox(msg, MB_OK)
        end

        dialog.show
      end

      private

      def self.aplicar_alteracoes(grupo, mi, data)
        mi.nome              = data[:nome] if data[:nome]
        mi.ambiente          = data[:ambiente] if data[:ambiente]
        mi.largura           = data[:largura].to_i if data[:largura]
        mi.altura            = data[:altura].to_i if data[:altura]
        mi.profundidade      = data[:profundidade].to_i if data[:profundidade]
        mi.espessura_corpo   = data[:espessura].to_i if data[:espessura]
        mi.material_corpo    = data[:material_corpo] if data[:material_corpo]
        mi.material_frente   = data[:material_frente] if data[:material_frente]
        mi.fita_corpo        = data[:fita_corpo] if data[:fita_corpo]
        mi.fita_frente       = data[:fita_frente] if data[:fita_frente]
        mi.montagem          = data[:montagem].to_sym if data[:montagem]
        mi.tipo_fundo        = data[:tipo_fundo].to_sym if data[:tipo_fundo]
        mi.tipo_base         = data[:tipo_base].to_sym if data[:tipo_base]
        mi.fixacao           = data[:fixacao].to_sym if data[:fixacao]

        model = Sketchup.active_model
        model.start_operation('Ornato: Aplicar Propriedades', true)
        pos = grupo.transformation.origin
        model.active_entities.erase_entities(grupo)
        novo = Engines::MotorCaixa.construir(mi, pos)
        if novo
          model.selection.clear
          model.selection.add(novo)
        end
        model.commit_operation

        Ornato.painel.atualizar if Ornato.painel.visivel?
      end

      def self.html_propriedades(mi)
        # Gera options de materiais
        materiais_corpo = Models::BibliotecaMateriais.materiais_padrao
          .select { |m| [:corpo, :frente].include?(m.categoria) && m.espessura >= 15 }
          .map(&:nome)
        materiais_frente = Models::BibliotecaMateriais.materiais_padrao
          .select { |m| [:frente, :corpo, :premium].include?(m.categoria) }
          .map(&:nome)

        opts_mat_corpo = materiais_corpo.map { |n|
          sel = n == mi.material_corpo ? 'selected' : ''
          "<option value=\"#{n}\" #{sel}>#{n}</option>"
        }.join("\n                    ")
        opts_mat_frente = materiais_frente.map { |n|
          sel = n == mi.material_frente ? 'selected' : ''
          "<option value=\"#{n}\" #{sel}>#{n}</option>"
        }.join("\n                    ")

        # Fitas
        fitas = Models::BibliotecaFitas.nomes
        opts_fita_corpo = fitas.map { |n|
          sel = n == mi.fita_corpo ? 'selected' : ''
          "<option value=\"#{n}\" #{sel}>#{n}</option>"
        }.join("\n                    ")
        opts_fita_frente = fitas.map { |n|
          sel = n == mi.fita_frente ? 'selected' : ''
          "<option value=\"#{n}\" #{sel}>#{n}</option>"
        }.join("\n                    ")

        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              body { font-family: -apple-system, 'Segoe UI', sans-serif; padding: 16px; font-size: 13px; background: #fafafa; overflow-y: auto; }
              h3 { font-size: 14px; color: #e67e22; margin-bottom: 4px; }
              .subtitle { font-size: 12px; color: #888; margin-bottom: 12px; }
              .section { margin-bottom: 14px; }
              .section-title { font-size: 11px; font-weight: 700; color: #999; text-transform: uppercase; margin-bottom: 6px; border-bottom: 1px solid #eee; padding-bottom: 4px; }
              .field { margin-bottom: 6px; }
              label { display: block; font-size: 11px; font-weight: 600; color: #666; margin-bottom: 2px; }
              input, select { width: 100%; padding: 5px 8px; border: 1px solid #ddd; border-radius: 3px; font-size: 13px; }
              input:focus, select:focus { border-color: #e67e22; outline: none; }
              .row { display: flex; gap: 8px; }
              .row .field { flex: 1; }
              .buttons { display: flex; gap: 8px; margin-top: 16px; }
              .btn { flex: 1; padding: 10px; border: none; border-radius: 4px; font-size: 13px; font-weight: 600; cursor: pointer; }
              .btn-ok { background: #e67e22; color: white; }
              .btn-ok:hover { background: #d35400; }
              .btn-cancel { background: #eee; color: #666; }
              .btn-cancel:hover { background: #ddd; }
              .info { background: #fff3e0; padding: 8px; border-radius: 4px; font-size: 11px; color: #e65100; margin-top: 8px; }
              .action-bar { display: flex; gap: 4px; margin-top: 8px; flex-wrap: wrap; }
              .btn-action {
                flex: 1; min-width: 80px; padding: 6px 4px;
                background: #f0f0f0; border: 1px solid #ddd; border-radius: 3px;
                font-size: 11px; cursor: pointer; text-align: center;
              }
              .btn-action:hover { background: #e67e22; color: white; border-color: #d35400; }
            </style>
          </head>
          <body>
            <h3>#{mi.nome}</h3>
            <div class="subtitle">#{mi.tipo.to_s.capitalize} — #{mi.ambiente}</div>

            <div class="section">
              <div class="section-title">Identificacao</div>
              <div class="row">
                <div class="field"><label>Nome</label><input id="nome" value="#{mi.nome}" /></div>
                <div class="field"><label>Ambiente</label><input id="ambiente" value="#{mi.ambiente}" /></div>
              </div>
            </div>

            <div class="section">
              <div class="section-title">Dimensoes</div>
              <div class="row">
                <div class="field"><label>Largura (mm)</label><input id="largura" type="number" value="#{mi.largura}" /></div>
                <div class="field"><label>Altura (mm)</label><input id="altura" type="number" value="#{mi.altura}" /></div>
                <div class="field"><label>Profund. (mm)</label><input id="profundidade" type="number" value="#{mi.profundidade}" /></div>
              </div>
              <div class="info">
                Interno: #{mi.largura_interna.round(0)} x #{mi.altura_interna.round(0)} x #{mi.profundidade_interna.round(0)} mm
              </div>
            </div>

            <div class="section">
              <div class="section-title">Material</div>
              <div class="field">
                <label>Corpo</label>
                <select id="material_corpo">#{opts_mat_corpo}</select>
              </div>
              <div class="field">
                <label>Frente</label>
                <select id="material_frente">#{opts_mat_frente}</select>
              </div>
            </div>

            <div class="section">
              <div class="section-title">Fita de Borda</div>
              <div class="row">
                <div class="field">
                  <label>Corpo</label>
                  <select id="fita_corpo">#{opts_fita_corpo}</select>
                </div>
                <div class="field">
                  <label>Frente</label>
                  <select id="fita_frente">#{opts_fita_frente}</select>
                </div>
              </div>
            </div>

            <div class="section">
              <div class="section-title">Construcao</div>
              <div class="row">
                <div class="field">
                  <label>Espessura</label>
                  <select id="espessura">
                    <option value="15" #{mi.espessura_corpo == 15 ? 'selected' : ''}>15mm</option>
                    <option value="18" #{mi.espessura_corpo == 18 ? 'selected' : ''}>18mm</option>
                    <option value="25" #{mi.espessura_corpo == 25 ? 'selected' : ''}>25mm</option>
                  </select>
                </div>
                <div class="field">
                  <label>Fixacao</label>
                  <select id="fixacao">
                    <option value="minifix" #{mi.fixacao == :minifix ? 'selected' : ''}>Minifix</option>
                    <option value="vb" #{mi.fixacao == :vb ? 'selected' : ''}>VB</option>
                    <option value="cavilha" #{mi.fixacao == :cavilha ? 'selected' : ''}>Cavilha</option>
                    <option value="confirmat" #{mi.fixacao == :confirmat ? 'selected' : ''}>Confirmat</option>
                  </select>
                </div>
              </div>
              <div class="row">
                <div class="field">
                  <label>Fundo</label>
                  <select id="tipo_fundo">
                    <option value="rebaixado" #{mi.tipo_fundo == :rebaixado ? 'selected' : ''}>Rebaixado</option>
                    <option value="sobreposto" #{mi.tipo_fundo == :sobreposto ? 'selected' : ''}>Sobreposto</option>
                    <option value="sem_fundo" #{mi.tipo_fundo == :sem_fundo ? 'selected' : ''}>Sem Fundo</option>
                  </select>
                </div>
                <div class="field">
                  <label>Base</label>
                  <select id="tipo_base">
                    <option value="pes_regulaveis" #{mi.tipo_base == :pes_regulaveis ? 'selected' : ''}>Pes regulaveis</option>
                    <option value="rodape" #{mi.tipo_base == :rodape ? 'selected' : ''}>Rodape</option>
                    <option value="direta" #{mi.tipo_base == :direta ? 'selected' : ''}>Direta</option>
                    <option value="suspensa" #{mi.tipo_base == :suspensa ? 'selected' : ''}>Suspensa</option>
                  </select>
                </div>
              </div>
            </div>

            <div class="section">
              <div class="section-title">Acoes Rapidas</div>
              <div class="action-bar">
                <button class="btn-action" onclick="sketchup.gerar_furacao()">Mapa Furacao</button>
                <button class="btn-action" onclick="sketchup.gerar_usinagem()">Usinagens</button>
                <button class="btn-action" onclick="sketchup.aplicar_fita()">Aplicar Fita</button>
              </div>
            </div>

            <div class="buttons">
              <button class="btn btn-cancel" onclick="sketchup.cancelar()">Cancelar</button>
              <button class="btn btn-ok" onclick="aplicar()">Aplicar</button>
            </div>

            <script>
              function aplicar() {
                var data = {
                  nome: document.getElementById('nome').value,
                  ambiente: document.getElementById('ambiente').value,
                  largura: document.getElementById('largura').value,
                  altura: document.getElementById('altura').value,
                  profundidade: document.getElementById('profundidade').value,
                  espessura: document.getElementById('espessura').value,
                  material_corpo: document.getElementById('material_corpo').value,
                  material_frente: document.getElementById('material_frente').value,
                  fita_corpo: document.getElementById('fita_corpo').value,
                  fita_frente: document.getElementById('fita_frente').value,
                  fixacao: document.getElementById('fixacao').value,
                  tipo_fundo: document.getElementById('tipo_fundo').value,
                  tipo_base: document.getElementById('tipo_base').value,
                  montagem: '#{mi.montagem}'
                };
                sketchup.aplicar(JSON.stringify(data));
              }
            </script>
          </body>
          </html>
        HTML
      end
    end
  end
end
