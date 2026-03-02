# ornato_plugin/engines/motor_api.rb — Comunicacao HTTP com ERP Ornato
#
# Fornece login JWT e envio de JSON de producao diretamente do SketchUp para o ERP.
# Endpoints utilizados:
#   POST /api/auth/login         => { email, senha } => { token, user }
#   POST /api/cnc/lotes/importar => { json, nome }   => { id, nome, total_pecas, cliente, projeto }
#
# Token JWT persistido via Sketchup.write_default (sobrevive entre sessoes).

require 'net/http'
require 'uri'
require 'json'

module Ornato
  module Engines
    class MotorApi

      # ═══════════════════════════════════════════════════════════
      # ESTADO (class-level)
      # ═══════════════════════════════════════════════════════════

      @@token      = nil
      @@user_info  = nil
      @@server_url = nil

      # ═══════════════════════════════════════════════════════════
      # CONFIGURACAO DO SERVIDOR
      # ═══════════════════════════════════════════════════════════

      def self.server_url
        @@server_url ||= Sketchup.read_default('Ornato', 'server_url') || Config::API_SERVER_DEFAULT
      end

      def self.configurar_servidor(url)
        @@server_url = url.chomp('/')
        Sketchup.write_default('Ornato', 'server_url', @@server_url)
      end

      # ═══════════════════════════════════════════════════════════
      # AUTENTICACAO JWT
      # ═══════════════════════════════════════════════════════════

      def self.token
        @@token ||= Sketchup.read_default('Ornato', 'api_token')
      end

      def self.user_info
        @@user_info
      end

      def self.logado?
        t = token
        !t.nil? && !t.empty?
      end

      # Login no ERP — obtem JWT token
      # @param email [String]
      # @param senha [String]
      # @return [Hash, nil] { 'token' => ..., 'user' => { 'id', 'nome', 'email', 'role' } }
      def self.login(email, senha)
        uri = URI("#{server_url}/api/auth/login")
        http = criar_http(uri, timeout: 10)

        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = { email: email, senha: senha }.to_json

        res = http.request(req)

        if res.code == '200'
          data = JSON.parse(res.body)
          @@token = data['token']
          @@user_info = data['user']
          Sketchup.write_default('Ornato', 'api_token', @@token)
          Sketchup.write_default('Ornato', 'api_email', email)
          data
        else
          error = JSON.parse(res.body) rescue { 'error' => res.message }
          puts "[Ornato API] Login falhou: #{error['error']}"
          nil
        end
      rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Net::OpenTimeout, Net::ReadTimeout => e
        puts "[Ornato API] Servidor indisponivel: #{e.message}"
        nil
      rescue => e
        puts "[Ornato API] Erro inesperado no login: #{e.message}"
        nil
      end

      # Limpa token e info do usuario
      def self.logout
        @@token = nil
        @@user_info = nil
        Sketchup.write_default('Ornato', 'api_token', '')
      end

      # ═══════════════════════════════════════════════════════════
      # ENVIO DE PRODUCAO
      # ═══════════════════════════════════════════════════════════

      # Envia JSON de producao para o ERP
      # @param json_data [Hash] JSON ja parseado (hash Ruby)
      # @param nome_lote [String, nil] Nome opcional para o lote
      # @return [Hash, nil] { 'id', 'nome', 'total_pecas', 'cliente', 'projeto' } ou nil
      def self.enviar_producao(json_data, nome_lote = nil)
        unless logado?
          puts "[Ornato API] Nao autenticado. Faca login primeiro."
          return nil
        end

        body = { 'json' => json_data }
        body['nome'] = nome_lote if nome_lote

        uri = URI("#{server_url}/api/cnc/lotes/importar")
        http = criar_http(uri, timeout: 30)

        req = Net::HTTP::Post.new(uri, {
          'Content-Type'  => 'application/json',
          'Authorization' => "Bearer #{token}"
        })
        req.body = body.to_json

        res = http.request(req)

        case res.code
        when '200', '201'
          JSON.parse(res.body)
        when '401'
          # Token expirado — limpar e avisar
          logout
          puts "[Ornato API] Token expirado. Faca login novamente."
          nil
        else
          error = JSON.parse(res.body) rescue { 'error' => res.message }
          puts "[Ornato API] Erro ao enviar (#{res.code}): #{error['error']}"
          nil
        end
      rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Net::OpenTimeout, Net::ReadTimeout => e
        puts "[Ornato API] Servidor indisponivel: #{e.message}"
        nil
      rescue => e
        puts "[Ornato API] Erro inesperado ao enviar: #{e.message}"
        nil
      end

      # ═══════════════════════════════════════════════════════════
      # TESTA CONEXAO
      # ═══════════════════════════════════════════════════════════

      # Verifica se o servidor ERP esta acessivel
      # @return [Boolean]
      def self.testar_conexao
        uri = URI("#{server_url}/api/auth/login")
        http = criar_http(uri, timeout: 5)
        # OPTIONS ou HEAD — leve, so para checar se responde
        req = Net::HTTP::Options.new(uri)
        res = http.request(req)
        true
      rescue
        false
      end

      # ═══════════════════════════════════════════════════════════
      # DIALOG DE LOGIN + ENVIO
      # ═══════════════════════════════════════════════════════════

      # Mostra dialog HTML para login no ERP e envio do JSON
      # @param json_data [Hash] JSON de producao gerado pelo motor_export
      def self.mostrar_dialog_envio(json_data)
        return unless json_data

        # Contagem de informacoes para preview
        pecas_count = contar_pecas(json_data)
        modulos_count = json_data['model_entities']&.length || 0
        projeto_nome = json_data.dig('details_project', 'upmprojname') || 'Projeto'
        cliente_nome = json_data.dig('details_project', 'upmclientname') || ''

        email_salvo = Sketchup.read_default('Ornato', 'api_email') || ''
        ja_logado = logado?

        html = gerar_html_dialog_envio(
          projeto_nome, cliente_nome, modulos_count, pecas_count,
          email_salvo, ja_logado, server_url
        )

        dialog = ::UI::HtmlDialog.new(
          dialog_title: 'Ornato — Enviar para ERP',
          preferences_key: 'ornato_api_envio',
          width: 480,
          height: ja_logado ? 380 : 520,
          resizable: false,
          style: ::UI::HtmlDialog::STYLE_DIALOG
        )

        dialog.set_html(html)

        # Callback: Login
        dialog.add_action_callback('fazer_login') do |_ctx, dados_json|
          begin
            dados = JSON.parse(dados_json)
            result = login(dados['email'], dados['senha'])
            if result
              dialog.execute_script("onLoginSuccess('#{result['user']['nome']}')")
            else
              dialog.execute_script("onLoginError('Credenciais invalidas ou servidor indisponivel')")
            end
          rescue => e
            dialog.execute_script("onLoginError('Erro: #{e.message.gsub("'", "\\\\'")}')")
          end
        end

        # Callback: Configurar servidor
        dialog.add_action_callback('config_servidor') do |_ctx, url|
          configurar_servidor(url)
          dialog.execute_script("onServerConfigured('#{server_url}')")
        end

        # Callback: Testar conexao
        dialog.add_action_callback('testar_conexao') do |_ctx|
          ok = testar_conexao
          dialog.execute_script("onConexaoTestada(#{ok})")
        end

        # Callback: Enviar producao
        dialog.add_action_callback('enviar') do |_ctx, nome_lote|
          begin
            result = enviar_producao(json_data, nome_lote.to_s.strip.empty? ? nil : nome_lote)
            if result
              msg = "Lote importado com sucesso!\\n\\n" \
                    "#{result['total_pecas']} pecas\\n" \
                    "Cliente: #{result['cliente']}\\n" \
                    "Projeto: #{result['projeto']}"
              dialog.execute_script("onEnvioSuccess('#{msg.gsub("'", "\\\\'")}')")
              # Fechar dialog apos 2 segundos
              dialog.execute_script("setTimeout(function(){ window.close(); }, 2000)")
            else
              if logado?
                dialog.execute_script("onEnvioError('Erro ao enviar. Verifique o console do SketchUp.')")
              else
                dialog.execute_script("onEnvioError('Sessao expirada. Faca login novamente.')")
                dialog.execute_script("mostrarLogin()")
              end
            end
          rescue => e
            dialog.execute_script("onEnvioError('Erro: #{e.message.gsub("'", "\\\\'")}')")
          end
        end

        # Callback: Cancelar
        dialog.add_action_callback('cancelar') do |_ctx|
          dialog.close
        end

        dialog.show
      end

      # ═══════════════════════════════════════════════════════════
      # METODOS PRIVADOS
      # ═══════════════════════════════════════════════════════════
      class << self
        private

        # Cria instancia Net::HTTP configurada
        def criar_http(uri, timeout: 15)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.open_timeout = timeout
          http.read_timeout = timeout
          http
        end

        # Conta total de pecas no JSON de producao
        def contar_pecas(json_data)
          count = 0
          (json_data['model_entities'] || {}).each do |_mid, mod|
            (mod['entities'] || {}).each do |_pid, _peca|
              count += 1
            end
          end
          count
        end

        # Gera HTML do dialog de login + envio
        def gerar_html_dialog_envio(projeto, cliente, modulos, pecas, email_salvo, ja_logado, srv_url)
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
                  background: #22c55e; color: white; padding: 15px 20px;
                  border-radius: 8px; margin-bottom: 20px; text-align: center;
                }
                .header h2 { font-size: 18px; margin-bottom: 4px; }
                .header small { opacity: 0.9; font-size: 12px; }
                .info-bar {
                  background: #f0fdf4; border-left: 4px solid #22c55e;
                  padding: 10px 15px; margin-bottom: 16px; border-radius: 4px;
                  font-size: 13px; line-height: 1.5;
                }
                .info-bar strong { color: #16a34a; }
                .form-group { margin-bottom: 14px; }
                label {
                  display: block; font-weight: 600; margin-bottom: 4px;
                  font-size: 13px; color: #555;
                }
                input[type="text"], input[type="email"], input[type="password"] {
                  width: 100%; padding: 8px 12px; border: 1px solid #ddd;
                  border-radius: 6px; font-size: 14px; outline: none;
                  transition: border-color 0.2s;
                }
                input:focus { border-color: #22c55e; }
                .buttons {
                  display: flex; gap: 10px; margin-top: 20px;
                  justify-content: flex-end;
                }
                .btn {
                  padding: 10px 24px; border: none; border-radius: 6px;
                  font-size: 14px; font-weight: 600; cursor: pointer;
                  transition: background 0.2s;
                }
                .btn-primary { background: #22c55e; color: white; }
                .btn-primary:hover { background: #16a34a; }
                .btn-secondary { background: #e0e0e0; color: #555; }
                .btn-secondary:hover { background: #ccc; }
                .btn-orange { background: #e67e22; color: white; }
                .btn-orange:hover { background: #d35400; }
                .btn:disabled { opacity: 0.5; cursor: not-allowed; }
                .status {
                  padding: 8px 12px; border-radius: 6px; margin-top: 10px;
                  font-size: 13px; display: none;
                }
                .status.success { display: block; background: #dcfce7; color: #166534; }
                .status.error { display: block; background: #fef2f2; color: #991b1b; }
                .status.info { display: block; background: #eff6ff; color: #1e40af; }
                #loginSection { #{ja_logado ? 'display:none;' : ''} }
                #envioSection { #{ja_logado ? '' : 'display:none;'} }
                .server-row {
                  display: flex; gap: 6px; align-items: center; margin-bottom: 14px;
                }
                .server-row input { flex: 1; }
                .server-row button {
                  padding: 8px 12px; border: 1px solid #ddd; background: #f9f9f9;
                  border-radius: 6px; cursor: pointer; font-size: 12px; white-space: nowrap;
                }
                .server-row button:hover { background: #eee; }
                .user-badge {
                  background: #dcfce7; color: #166534; padding: 6px 12px;
                  border-radius: 20px; font-size: 12px; display: inline-block;
                  margin-bottom: 14px;
                }
                hr {
                  margin: 16px 0; border: none; border-top: 1px solid #e0e0e0;
                }
              </style>
            </head>
            <body>
              <div class="header">
                <h2>Enviar para ERP Ornato</h2>
                <small>Envio direto do SketchUp para producao CNC</small>
              </div>

              <div class="info-bar">
                <strong>#{projeto}</strong>#{cliente.empty? ? '' : " — #{cliente}"}<br>
                #{modulos} modulo(s), #{pecas} peca(s) para enviar
              </div>

              <!-- ═══ SECAO LOGIN ═══ -->
              <div id="loginSection">
                <div class="server-row">
                  <input type="text" id="serverUrl" value="#{srv_url}" placeholder="http://localhost:3001">
                  <button onclick="testarConexao()">Testar</button>
                </div>

                <div class="form-group">
                  <label>Email</label>
                  <input type="email" id="email" value="#{email_salvo}">
                </div>
                <div class="form-group">
                  <label>Senha</label>
                  <input type="password" id="senha" placeholder="Sua senha do ERP">
                </div>

                <div id="loginStatus" class="status"></div>

                <div class="buttons">
                  <button class="btn btn-secondary" onclick="sketchup.cancelar()">Cancelar</button>
                  <button class="btn btn-primary" id="btnLogin" onclick="fazerLogin()">Entrar</button>
                </div>
              </div>

              <!-- ═══ SECAO ENVIO ═══ -->
              <div id="envioSection">
                <div id="userBadge" class="user-badge"></div>

                <div class="form-group">
                  <label>Nome do Lote (opcional)</label>
                  <input type="text" id="nomeLote" value="#{projeto}" placeholder="Nome para identificar o lote no ERP">
                </div>

                <div id="envioStatus" class="status"></div>

                <div class="buttons">
                  <button class="btn btn-secondary" onclick="sketchup.cancelar()">Cancelar</button>
                  <button class="btn btn-primary" id="btnEnviar" onclick="enviarParaERP()">Enviar para ERP</button>
                </div>
              </div>

              <script>
                function fazerLogin() {
                  var email = document.getElementById('email').value.trim();
                  var senha = document.getElementById('senha').value;
                  if (!email || !senha) {
                    setStatus('loginStatus', 'error', 'Preencha email e senha.');
                    return;
                  }
                  // Configurar servidor antes do login
                  var url = document.getElementById('serverUrl').value.trim();
                  if (url) sketchup.config_servidor(url);

                  document.getElementById('btnLogin').disabled = true;
                  setStatus('loginStatus', 'info', 'Conectando...');
                  sketchup.fazer_login(JSON.stringify({ email: email, senha: senha }));
                }

                function onLoginSuccess(nome) {
                  document.getElementById('loginSection').style.display = 'none';
                  document.getElementById('envioSection').style.display = 'block';
                  document.getElementById('userBadge').textContent = 'Logado como: ' + nome;
                }

                function onLoginError(msg) {
                  document.getElementById('btnLogin').disabled = false;
                  setStatus('loginStatus', 'error', msg);
                }

                function testarConexao() {
                  var url = document.getElementById('serverUrl').value.trim();
                  if (url) sketchup.config_servidor(url);
                  setStatus('loginStatus', 'info', 'Testando conexao...');
                  sketchup.testar_conexao();
                }

                function onConexaoTestada(ok) {
                  if (ok) {
                    setStatus('loginStatus', 'success', 'Servidor acessivel!');
                  } else {
                    setStatus('loginStatus', 'error', 'Servidor indisponivel. Verifique a URL.');
                  }
                }

                function onServerConfigured(url) {
                  document.getElementById('serverUrl').value = url;
                }

                function enviarParaERP() {
                  var nome = document.getElementById('nomeLote').value.trim();
                  document.getElementById('btnEnviar').disabled = true;
                  setStatus('envioStatus', 'info', 'Enviando...');
                  sketchup.enviar(nome);
                }

                function onEnvioSuccess(msg) {
                  setStatus('envioStatus', 'success', msg.replace(/\\\\n/g, '\\n'));
                  document.getElementById('btnEnviar').textContent = 'Enviado!';
                }

                function onEnvioError(msg) {
                  document.getElementById('btnEnviar').disabled = false;
                  setStatus('envioStatus', 'error', msg);
                }

                function mostrarLogin() {
                  document.getElementById('loginSection').style.display = 'block';
                  document.getElementById('envioSection').style.display = 'none';
                }

                function setStatus(id, type, msg) {
                  var el = document.getElementById(id);
                  el.className = 'status ' + type;
                  el.textContent = msg;
                }

                // Auto-focus: se ja logado, foco no botao enviar; senao, foco no email
                window.onload = function() {
                  var loginSec = document.getElementById('loginSection');
                  if (loginSec.style.display === 'none') {
                    document.getElementById('btnEnviar').focus();
                  } else {
                    var emailField = document.getElementById('email');
                    if (emailField.value) {
                      document.getElementById('senha').focus();
                    } else {
                      emailField.focus();
                    }
                  }
                };
              </script>
            </body>
            </html>
          HTML
        end

      end  # class << self

    end
  end
end
