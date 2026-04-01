# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# core/constants.rb — Enums, tipos e constantes semânticas
#
# Centraliza todos os valores enumerados usados pelo domínio.
# Usar estes arrays para validação de input.

module Ornato
  module Core
    module Constants
      # ── Tipos de módulo ────────────────────────────────────────────

      MODULE_TYPES = [
        :balcao, :aereo, :torre, :roupeiro, :gaveteiro,
        :nicho, :painel, :tampo, :rodape, :canto
      ].freeze

      # ── Tipos de ambiente ──────────────────────────────────────────

      ENVIRONMENT_TYPES = [
        :cozinha, :quarto, :closet, :banheiro, :lavanderia,
        :escritorio, :gourmet, :sala, :varanda, :despensa, :outro
      ].freeze

      # ── Tipos de peça ──────────────────────────────────────────────

      PART_TYPES = [
        :structural, :front, :drawer, :back, :shelf,
        :divider, :loose, :accessory
      ].freeze

      # ── Tipos de agregado ──────────────────────────────────────────

      AGGREGATE_TYPES = [
        :prateleira_fixa, :prateleira_regulavel, :divisoria_vertical,
        :fundo, :porta_abrir, :porta_basculante, :porta_correr,
        :gaveta, :gavetao, :puxador, :perfil_cava, :acessorio
      ].freeze

      # ── Subtipos de porta ──────────────────────────────────────────

      DOOR_SUBTYPES = [
        :lisa, :provencal, :almofadada, :vidro, :vidro_inteiro,
        :perfil_aluminio, :veneziana, :ripada, :cego
      ].freeze

      # ── Tipos de sobreposição de porta ─────────────────────────────

      OVERLAP_TYPES = [:total, :meia, :interna].freeze

      # ── Tipos de operação CNC ──────────────────────────────────────

      OPERATION_TYPES = [
        :furacao, :canal, :rebaixo, :fresagem, :pocket,
        :rasgo, :cava, :corte_especial
      ].freeze

      # ── Faces de operação ──────────────────────────────────────────

      OPERATION_FACES = [:top, :bottom, :front, :back, :left, :right].freeze

      # ── Tipos de ferragem ──────────────────────────────────────────

      HARDWARE_TYPES = [
        :dobradiça, :corrediça, :puxador, :suporte, :conector,
        :minifix, :cavilha, :parafuso, :amortecedor, :perfil,
        :trilho, :acessorio
      ].freeze

      # ── Tipos de corrediça ─────────────────────────────────────────

      SLIDE_TYPES = [:telescopica, :oculta, :tandembox, :roller].freeze

      # Deduções por tipo de corrediça (mm total a subtrair da largura do vão)
      SLIDE_DEDUCTIONS = {
        telescopica: 25.4,   # 12.7mm por lado
        oculta:      42.0,   # TANDEM undermount
        tandembox:   75.0,   # Tandembox metal profile
        roller:      25.0    # 12.5mm por lado
      }.freeze

      # ── Direção do grão ────────────────────────────────────────────

      GRAIN_DIRECTIONS = [:length, :width, :none].freeze

      # ── Tipos de montagem ──────────────────────────────────────────

      ASSEMBLY_TYPES = [:brasil, :europa].freeze
      # brasil: laterais ENTRE base e topo
      # europa: base e topo ENTRE laterais

      # ── Tipos de fundo ─────────────────────────────────────────────

      BACK_TYPES = [:encaixado, :sobreposto, :nenhum].freeze
      # encaixado: em canal (rasgo nas laterais/base)
      # sobreposto: parafusado na traseira
      # nenhum: sem fundo (closet)

      # ── Tipos de base ──────────────────────────────────────────────

      BASE_TYPES = [:rodape, :pes, :direto].freeze

      # ── Estados do projeto ─────────────────────────────────────────

      PROJECT_STATES = [
        :draft, :validated, :commercial_approved,
        :production_approved, :factory_frozen,
        :in_production, :completed
      ].freeze

      # Transições permitidas entre estados do projeto
      PROJECT_TRANSITIONS = {
        draft:                [:validated],
        validated:            [:draft, :commercial_approved],
        commercial_approved:  [:validated, :production_approved],
        production_approved:  [:commercial_approved, :factory_frozen],
        factory_frozen:       [:draft],  # via nova revisão
        in_production:        [:completed],
        completed:            []
      }.freeze

      # ── Estados do módulo (locais no plugin) ───────────────────────

      MODULE_STATES = [:draft, :validated, :ready_for_export].freeze

      # ── Níveis de validação ────────────────────────────────────────

      VALIDATION_LEVELS = [:blocking, :warning, :suggestion].freeze

      # ── Escopos de rebuild ─────────────────────────────────────────

      REBUILD_SCOPES = [:full, :partial_aggregate, :partial_engineering, :visual_only].freeze

      # ── Códigos de peça para exportação (UpMobb compatível) ────────

      PART_CODES = {
        lateral_esq:       'CM_LAT_ESQ',
        lateral_dir:       'CM_LAT_DIR',
        base:              'CM_BAS',
        topo:              'CM_REG',
        fundo:             'CM_FUN',
        prateleira:        'CM_PRA',
        prateleira_fixa:   'CM_PRA_FIX',
        prateleira_reg:    'CM_PRA_REG',
        divisoria:         'CM_DIV',
        porta_lisa:        'CM_POR_LIS',
        porta_vidro:       'CM_POR_VID',
        porta_veneziana:   'CM_POR_VEN',
        porta_almofadada:  'CM_POR_ALM',
        porta_provencal:   'CM_POR_PRO',
        porta_correr:      'CM_POR_COR',
        frente_gaveta:     'CM_FRE_GAV_LIS',
        lateral_gaveta:    'CM_LAT_GAV',
        traseira_gaveta:   'CM_TRA_GAV',
        fundo_gaveta:      'CM_FUN_GAV_VER',
        painel:            'CM_PNL',
        tampo:             'CM_TAM',
        rodape:            'CM_RDP',
        requadro:          'CM_REQ'
      }.freeze

      # ── Códigos de operação para exportação ────────────────────────

      OPERATION_CODES = {
        furacao:         'CM_USI_FUR',
        canal:           'CM_USI_CAN',
        rebaixo:         'CM_USI_REB',
        fresagem:        'CM_USI_FRE',
        pocket:          'CM_USI_POC',
        rasgo:           'CM_USI_RAS',
        cava:            'CM_USI_CAV',
        corte_especial:  'CM_USI_CES'
      }.freeze
    end
  end
end
