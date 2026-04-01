# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# engineering/erp_bridge.rb — Ponte bidirecional Plugin ↔ ERP Web
#
# Comunicação HTTP com o servidor Ornato ERP para:
#   - Enviar módulos (import)
#   - Consultar status de produção
#   - Consultar custos por material
#   - Receber alertas de validação
#   - Listar lotes anteriores
#
# Endpoint: POST /api/cnc/plugin/sync
# Health:   GET  /api/cnc/plugin/ping

require 'net/http'
require 'uri'
require 'json'

module Ornato
  module Engineering
    class ErpBridge
      DEFAULT_BASE_URL = 'http://localhost:3001'.freeze
      SYNC_PATH = '/api/cnc/plugin/sync'.freeze
      PING_PATH = '/api/cnc/plugin/ping'.freeze

      TIMEOUT_OPEN = 5    # segundos
      TIMEOUT_READ = 30   # segundos

      # Cache de token e conexão
      @token = nil
      @base_url = nil
      @last_ping = nil
      @online = false

      class << self
        attr_accessor :token

        # ── Configuração ────────────────────────────────────

        # URL base do servidor ERP.
        # Tenta GlobalConfig, senão usa default.
        def base_url
          @base_url ||= if defined?(GlobalConfig) && GlobalConfig.respond_to?(:get)
            GlobalConfig.get(:server_url, DEFAULT_BASE_URL).sub(%r{/api/cnc.*$}, '')
          else
            DEFAULT_BASE_URL
          end
        end

        def base_url=(url)
          @base_url = url
          @last_ping = nil
          @online = false
        end

        # ── Conexão ─────────────────────────────────────────

        # Verifica se o servidor ERP está acessível.
        # Cacheia resultado por 30 segundos.
        def online?
          if @last_ping && (Time.now - @last_ping) < 30
            return @online
          end
          ping!
        end

        # Força verificação de conexão.
        def ping!
          uri = URI.parse("#{base_url}#{PING_PATH}")
          http = build_http(uri)
          http.open_timeout = 3
          http.read_timeout = 5
          response = http.get(uri.path)

          @last_ping = Time.now
          @online = (response.code.to_i == 200)

          if @online
            data = JSON.parse(response.body) rescue {}
            Core.logger.info("ERP online: #{data['server']} v#{data['version']}")
          end

          @online
        rescue => e
          @last_ping = Time.now
          @online = false
          Core.logger.warn("ERP offline: #{e.message}")
          false
        end

        # ── Ações de Sync ───────────────────────────────────

        # Importa módulos do SketchUp para o ERP.
        # @param json_string [String] JSON no formato UpMobb/Ornato
        # @param nome [String] nome do lote
        # @param projeto_id [Integer, nil] ID do projeto no ERP
        # @param orc_id [Integer, nil] ID do orçamento no ERP
        # @return [Hash] { ok, lote_id, total_pecas, msg } ou { error }
        def importar(json_string, nome: nil, projeto_id: nil, orc_id: nil)
          sync_request('import', {
            json: json_string.is_a?(String) ? (JSON.parse(json_string) rescue json_string) : json_string,
            nome: nome,
            projeto_id: projeto_id,
            orc_id: orc_id,
          })
        end

        # Consulta status de produção de um lote.
        # @param lote_id [Integer]
        # @return [Hash] { ok, lote: { status, ... }, producao: { progresso_pct, ... } }
        def status(lote_id)
          sync_request('status', { lote_id: lote_id })
        end

        # Consulta custos por material de um lote.
        # @param lote_id [Integer]
        # @return [Hash] { ok, materiais: [...], plano: { total_chapas, aproveitamento } }
        def custos(lote_id)
          sync_request('custos', { lote_id: lote_id })
        end

        # Consulta alertas de validação de um lote.
        # @param lote_id [Integer]
        # @return [Hash] { ok, total, alertas: [...] }
        def alertas(lote_id)
          sync_request('alertas', { lote_id: lote_id })
        end

        # Lista lotes recentes do usuário.
        # @return [Hash] { ok, lotes: [...] }
        def listar_lotes
          sync_request('listar_lotes', {})
        end

        # ── Exportar e Enviar (wrapper completo) ────────────

        # Exporta módulos selecionados e envia ao ERP.
        # Retorna resultado com lote_id para consultas posteriores.
        def exportar_e_sincronizar(cliente: '', projeto: '', codigo: '', vendedor: '')
          unless online?
            return { 'error' => 'Servidor ERP não está acessível', 'offline' => true }
          end

          # Gerar JSON via ExportBridge
          json = ExportBridge.exportar_selecao_ou_modelo(
            cliente: cliente, projeto: projeto,
            codigo: codigo, vendedor: vendedor
          )

          unless json
            return { 'error' => 'Nenhum módulo para exportar' }
          end

          # Enviar ao ERP
          result = importar(json, nome: "#{projeto} #{codigo}".strip)

          if result && result['ok']
            lote_id = result['lote_id']
            Core.events.emit(:erp_sync_completed, lote_id: lote_id, total: result['total_pecas'])
            Core.logger.info("ERP sync OK: Lote ##{lote_id}, #{result['total_pecas']} peças")

            # Buscar alertas automaticamente
            alerta_result = alertas(lote_id) rescue nil

            result['alertas'] = alerta_result['alertas'] if alerta_result && alerta_result['ok']
          end

          result
        end

        private

        # Envia request POST /api/cnc/plugin/sync com action + payload.
        def sync_request(action, payload)
          uri = URI.parse("#{base_url}#{SYNC_PATH}")
          http = build_http(uri)

          request = Net::HTTP::Post.new(uri.path)
          request['Content-Type'] = 'application/json'
          request['Authorization'] = "Bearer #{@token}" if @token
          request.body = JSON.generate({ action: action, payload: payload })

          response = http.request(request)

          case response.code.to_i
          when 200, 201
            JSON.parse(response.body)
          when 401
            Core.logger.warn("ERP: Token expirado ou inválido")
            { 'error' => 'Autenticação necessária. Faça login no ERP.', 'auth_required' => true }
          when 404
            { 'error' => 'Endpoint não encontrado. Verifique versão do ERP.' }
          else
            body = response.body rescue ''
            parsed = JSON.parse(body) rescue { 'error' => "HTTP #{response.code}: #{body}" }
            parsed
          end
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
          @online = false
          { 'error' => 'Servidor ERP não está acessível' }
        rescue Net::OpenTimeout, Net::ReadTimeout
          { 'error' => 'Timeout ao conectar ao servidor ERP' }
        rescue => e
          Core.logger.error("ERP sync error: #{e.message}")
          { 'error' => "Erro: #{e.message}" }
        end

        def build_http(uri)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.open_timeout = TIMEOUT_OPEN
          http.read_timeout = TIMEOUT_READ
          http
        end
      end
    end
  end
end
