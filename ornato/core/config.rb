# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# core/config.rb — Constantes invariantes do sistema
#
# REGRA: Este arquivo contém APENAS constantes que NUNCA mudam entre
# projetos, clientes ou rulesets. Dados variáveis (materiais, ferragens,
# regras construtivas) vivem em RuleSet e CatalogSnapshot.

module Ornato
  module Core
    module Config
      # ── Versões ────────────────────────────────────────────────────

      PLUGIN_VERSION    = '1.0.0'.freeze
      SCHEMA_VERSION    = 1
      MIN_SKETCHUP_VERSION = 21

      # ── Dicionários de atributos no SketchUp ──────────────────────
      # Cada dicionário agrupa atributos por responsabilidade.
      # Nunca misturar dados de design com dados de fabricação.

      DICT_IDENTITY      = 'ornato.identity'.freeze
      DICT_DESIGN        = 'ornato.design'.freeze
      DICT_ENGINEERING   = 'ornato.engineering'.freeze
      DICT_MANUFACTURING = 'ornato.manufacturing'.freeze
      DICT_SYNC          = 'ornato.sync'.freeze
      DICT_AUDIT         = 'ornato.audit'.freeze

      ALL_DICTS = [
        DICT_IDENTITY, DICT_DESIGN, DICT_ENGINEERING,
        DICT_MANUFACTURING, DICT_SYNC, DICT_AUDIT
      ].freeze

      # ── Tags/Layers do SketchUp ───────────────────────────────────
      # Overlays técnicos separados por domínio visual.
      # Podem ser ligados/desligados sem corromper o modelo.

      TAG_MODULOS   = 'ORNATO_Modulos'.freeze
      TAG_PECAS     = 'ORNATO_Pecas'.freeze
      TAG_FURACOES  = 'ORNATO_Furacoes'.freeze
      TAG_USINAGENS = 'ORNATO_Usinagens'.freeze
      TAG_ALERTAS   = 'ORNATO_Alertas'.freeze
      TAG_COTAS     = 'ORNATO_Cotas'.freeze
      TAG_DEBUG     = 'ORNATO_Debug'.freeze

      ALL_TAGS = [
        TAG_MODULOS, TAG_PECAS, TAG_FURACOES, TAG_USINAGENS,
        TAG_ALERTAS, TAG_COTAS, TAG_DEBUG
      ].freeze

      # ── Sistema 32mm (invariante europeia de marcenaria) ──────────
      # Pitch entre furos, setback da borda frontal, diâmetro padrão.
      # Estes valores são norma industrial, não configuração.

      SYSTEM_32_PITCH    = 32.0   # mm entre furos na vertical
      SYSTEM_32_SETBACK  = 37.0   # mm da borda frontal ao eixo do furo
      SYSTEM_32_DIAMETER = 5.0    # mm diâmetro padrão de furo

      # ── Espessuras reais de MDF ───────────────────────────────────
      # Confirmado com UpMobb: a chapa de MDF nunca tem espessura
      # nominal exata. A diferença é relevante para encaixes, canais
      # e planicidade. Ex: 18mm nominal = 18.5mm real.

      REAL_THICKNESSES = {
        3  => 3.0,
        6  => 6.0,
        9  => 9.0,
        12 => 12.0,
        15 => 15.5,
        18 => 18.5,
        20 => 20.5,
        25 => 25.5
      }.freeze

      # Engrossado (duas chapas coladas): 15.5 + 15.5 = 31.0
      THICKNESS_ENGROSSADO = 31.0

      # ── Chapa padrão de corte ─────────────────────────────────────
      # Dimensões da chapa comercial brasileira padrão.

      SHEET_WIDTH  = 2750.0  # mm (comprimento da chapa)
      SHEET_HEIGHT = 1850.0  # mm (largura da chapa)
      SHEET_TRIM   = 10.0    # mm de refilo por borda

      # ── Performance targets (ms) ──────────────────────────────────
      # Metas de tempo para operações críticas.
      # Rebuild que exceder o target gera warning no log.

      REBUILD_FULL_TARGET    = 500   # módulo simples
      REBUILD_FULL_MAX       = 3000  # módulo complexo (torre 8 gavetas)
      REBUILD_PARTIAL_TARGET = 200
      REBUILD_VISUAL_TARGET  = 100
      EXPORT_TARGET          = 5000  # projeto completo (20 módulos)
      RECONCILE_TARGET       = 1000

      # ── UI ────────────────────────────────────────────────────────

      BRAND_COLOR   = '#e67e22'.freeze
      BRAND_COLOR_DARK = '#d35400'.freeze
      PANEL_WIDTH   = 380
      PANEL_HEIGHT  = 700
      PANEL_MIN_WIDTH = 320

      # ── Métodos utilitários invariantes ────────────────────────────

      # Retorna espessura real para nominal.
      # @param nominal [Numeric] espessura nominal em mm
      # @return [Float] espessura real em mm
      def self.real_thickness(nominal)
        REAL_THICKNESSES[nominal.to_i] || nominal.to_f
      end

      # Converte mm para unidade interna do SketchUp (polegadas).
      # @param value_mm [Numeric] valor em milímetros
      # @return [Float] valor em polegadas
      def self.mm(value_mm)
        value_mm.to_f / 25.4
      end

      # Converte unidade interna do SketchUp (polegadas) para mm.
      # @param value_inches [Numeric] valor em polegadas
      # @return [Float] valor em milímetros
      def self.to_mm(value_inches)
        value_inches.to_f * 25.4
      end

      # Arredonda valor para múltiplo mais próximo de 32mm.
      # Usado para posicionamento de furos no sistema 32.
      # @param value_mm [Numeric] valor em mm
      # @return [Float] valor arredondado para múltiplo de 32
      def self.snap_32(value_mm)
        (value_mm.to_f / SYSTEM_32_PITCH).round * SYSTEM_32_PITCH
      end

      # Arredonda profundidade para comprimento padrão de corrediça.
      # Comprimentos comerciais: 250, 300, 350, 400, 450, 500, 550, 600mm.
      # @param depth_mm [Numeric] profundidade disponível em mm
      # @return [Float] comprimento de corrediça mais próximo
      def self.snap_slide_length(depth_mm)
        standards = [250.0, 300.0, 350.0, 400.0, 450.0, 500.0, 550.0, 600.0]
        standards.select { |s| s <= depth_mm }.max || standards.first
      end

      # Diretório base do plugin (onde os arquivos .rb estão).
      # Usado para localizar assets (ícones, HTML, cache).
      def self.plugin_dir
        File.dirname(File.dirname(__FILE__))
      end

      # Diretório de dados do plugin (cache de catálogo, config local).
      def self.data_dir
        File.join(plugin_dir, 'data')
      end

      # Diretório de cache do catálogo.
      def self.catalog_cache_dir
        File.join(data_dir, 'catalog_cache')
      end

      # Diretório de ícones da toolbar.
      def self.icons_dir
        File.join(data_dir, 'icons')
      end
    end
  end
end
