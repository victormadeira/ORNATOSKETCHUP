# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/ornato_attributes.rb — Sistema de Atributos Ornato
#
# Define o schema de atributos que o plugin Ornato usa para marcar
# pecas no SketchUp. Toda entidade que pertence a um movel Ornato
# recebe o dicionario 'ornato' com atributos padronizados.
#
# REGRA FUNDAMENTAL: somente entidades com dicionario 'ornato' e
# atributo 'orn_marcado' = true sao reconhecidas como pecas de
# mobiliario. Paredes, pisos, eletrodomesticos etc. sao ignorados
# na exportacao e lista de corte.
#
# ═══════════════════════════════════════════════════════════════
# SCHEMA DE ATRIBUTOS ORNATO (prefixo: orn)
# ═══════════════════════════════════════════════════════════════
#
# Cada atributo segue o padrao do Dynamic Components do SketchUp:
#   orn{nome}              — valor do atributo
#   orn{nome}_formula      — formula (se parametrico)
#   orn{nome}_label        — label de exibicao
#   orn{nome}_access       — nivel de acesso (TEXTBOX, LIST, VIEW, NONE)
#   orn{nome}_formlabel    — label do formulario
#   orn{nome}_options      — opcoes (para LIST)
#   orn{nome}_units        — unidade (CENTIMETERS, STRING, FLOAT)
#   orn{nome}_error        — mensagem de erro (validacao)
#
# ═══════════════════════════════════════════════════════════════

module Ornato
  # Stub para Core::Ids caso ainda nao exista (definido em core/ids.rb ou box_builder.rb)
  module Core
    module Ids
      def self.generate
        ts = Time.now.to_i.to_s(16)
        rnd = rand(0xFFFF).to_s(16).rjust(4, '0')
        "orn_#{ts}#{rnd}"
      end
    end unless defined?(Core::Ids)
  end

  module Engineering
    module OrnatoAttributes

      # ── Dicionarios ─────────────────────────────────────────────
      DICT_NAME = 'ornato'.freeze               # dicionario principal
      DC_DICT   = 'dynamic_attributes'.freeze   # dicionario SketchUp DC

      # ── Prefixo ─────────────────────────────────────────────────
      PREFIX = 'orn'.freeze

      # ================================================================
      # ATRIBUTOS DO MODULO (grupo raiz do movel)
      # ================================================================
      MODULE_ATTRS = {
        # ── Identidade ───────────────────────────────────────────
        orn_marcado:        { default: true,    type: :boolean, label: 'Ornato',        access: 'NONE' },
        orn_versao:         { default: '1.0',   type: :string,  label: 'Versao Schema', access: 'VIEW' },
        orn_id:             { default: '',      type: :string,  label: 'Ornato ID',     access: 'VIEW' },
        orn_nome:           { default: '',      type: :string,  label: 'Nome',          access: 'TEXTBOX' },
        orn_tipo_modulo:    { default: '',      type: :string,  label: 'Tipo Modulo',   access: 'LIST',
                              options: 'Inferior=inferior&Superior=superior&Torre=torre&Gaveteiro=gaveteiro&Estante=estante&Roupeiro=roupeiro&Bancada=bancada&Pia=pia&Nicho=nicho&Torre Quente=torre_quente&Cooktop=cooktop&Micro-ondas=micro_ondas&Lava-Louca=lava_louca&Canto L=canto_l&Canto L Superior=canto_l_superior&Ilha=ilha' },
        orn_ambiente:       { default: '',      type: :string,  label: 'Ambiente',      access: 'TEXTBOX' },
        orn_cliente:        { default: '',      type: :string,  label: 'Cliente',        access: 'TEXTBOX' },

        # ── Dimensoes do modulo (parametricas, em cm no SketchUp) ──
        orn_largura:        { default: 60.0,    type: :float,   label: 'Largura',       access: 'TEXTBOX', units: 'CENTIMETERS',
                              formlabel: 'Largura (cm):' },
        orn_profundidade:   { default: 55.0,    type: :float,   label: 'Profundidade',  access: 'TEXTBOX', units: 'CENTIMETERS',
                              formlabel: 'Profundidade (cm):' },
        orn_altura:         { default: 72.0,    type: :float,   label: 'Altura',        access: 'TEXTBOX', units: 'CENTIMETERS',
                              formlabel: 'Altura (cm):' },

        # ── Material padrao do corpo ─────────────────────────────
        orn_material_corpo: { default: 'MDF 18mm Branco TX', type: :string, label: 'Material Corpo', access: 'LIST',
                              formlabel: 'Material do Corpo:' },
        # NOTA: orn_espessura_corpo e em CM (unidade interna DC).
        # O dropdown mostra labels em mm para o usuario.
        # Ao trocar, a formula de orn_espessura_real recalcula automaticamente.
        orn_espessura_corpo:{ default: 1.8,     type: :float,   label: 'Espessura Corpo', access: 'LIST',
                              options: '15mm=1.5&18mm=1.8&25mm=2.5&30mm (2x15)=3.0&36mm (2x18)=3.6',
                              units: 'CENTIMETERS',
                              formlabel: 'Espessura do Corpo:' },
        orn_espessura_real: { default: 1.85,    type: :float,   label: 'Espessura Real (cm)', access: 'VIEW',
                              units: 'CENTIMETERS' },

        # ── Fita de borda padrao ─────────────────────────────────
        orn_borda_material: { default: 'Fita PVC Branco TX', type: :string, label: 'Material Borda', access: 'LIST',
                              formlabel: 'Material Borda:' },
        orn_borda_espessura:{ default: 1.0,     type: :float,   label: 'Espessura Borda (mm)', access: 'LIST',
                              options: '0.45=0.45&1.0=1.0&2.0=2.0',
                              formlabel: 'Espessura Borda (mm):' },
        orn_borda_largura:  { default: 22.0,    type: :float,   label: 'Largura Borda (mm)', access: 'LIST',
                              options: '22=22&33=33&45=45',
                              formlabel: 'Largura Borda (mm):' },
        orn_descontar_borda:{ default: true,     type: :boolean, label: 'Descontar Borda', access: 'LIST',
                              options: 'Sim=true&Nao=false',
                              formlabel: 'Descontar Borda:' },

        # ── Fundo ────────────────────────────────────────────────
        orn_tipo_fundo:     { default: 'encaixado', type: :string, label: 'Tipo Fundo', access: 'LIST',
                              options: 'Encaixado=encaixado&Parafusado=parafusado&Sem Fundo=sem',
                              formlabel: 'Tipo de Fundo:' },
        orn_espessura_fundo:{ default: 6.0,     type: :float,   label: 'Espessura Fundo (mm)', access: 'LIST',
                              options: '6mm HDF=6&15mm MDF=15',
                              formlabel: 'Espessura Fundo (mm):' },
        orn_entrada_fundo:  { default: 7.0,     type: :float,   label: 'Entrada Fundo (mm)', access: 'TEXTBOX',
                              formlabel: 'Recuo do fundo (mm):' },
        orn_folga_canal:    { default: 9.0,     type: :float,   label: 'Extensao Fundo no Rasgo (mm)', access: 'TEXTBOX',
                              formlabel: 'Extensao no Rasgo (mm):' },

        # ── Prateleiras ──────────────────────────────────────────
        orn_qtd_prateleiras:{ default: 1,       type: :integer, label: 'Qtd Prateleiras', access: 'LIST',
                              options: '0=0&1=1&2=2&3=3&4=4&5=5',
                              formlabel: 'Quantidade de Prateleiras:' },
        orn_recuo_prateleira:{ default: 0.0,    type: :float,   label: 'Recuo Prateleira (mm)', access: 'TEXTBOX' },
        orn_espessura_prat: { default: 18.0,    type: :float,   label: 'Espessura Prateleira (mm)', access: 'LIST',
                              options: '15mm=15&18mm=18&25mm=25',
                              formlabel: 'Espessura Prateleira (mm):' },

        # ── Porta ────────────────────────────────────────────────
        orn_lado_porta:     { default: 'esquerda', type: :string, label: 'Lado Porta', access: 'LIST',
                              options: 'Esquerda=esquerda&Direita=direita',
                              formlabel: 'Lado da Porta:' },
        orn_folga_porta:    { default: 2.0,     type: :float,   label: 'Folga Porta (mm)', access: 'TEXTBOX' },
        orn_espessura_porta:{ default: 18.0,    type: :float,   label: 'Espessura Porta (mm)', access: 'LIST',
                              options: '15mm=15&18mm=18&25mm=25',
                              formlabel: 'Espessura da Porta (mm):' },
        orn_tipo_dobradica: { default: 'reta',  type: :string,  label: 'Tipo Dobradica', access: 'LIST',
                              options: 'Reta (Sobreposta)=reta&Curva (Meio-Esquadro)=curva&Supercurva (Embutida)=supercurva',
                              formlabel: 'Tipo de Dobradica:' },
        orn_sobreposicao_porta: { default: 0.0, type: :float,   label: 'Sobreposicao Porta (mm)', access: 'VIEW' },

        # ── Porta de Correr ──────────────────────────────────────
        orn_tipo_porta:     { default: 'abrir', type: :string,  label: 'Tipo Porta', access: 'LIST',
                              options: 'Abrir=abrir&Correr=correr&Basculante=basculante',
                              formlabel: 'Tipo de Porta:' },
        orn_qtd_portas_correr: { default: 2,    type: :integer, label: 'Qtd Portas Correr', access: 'LIST',
                              options: '2 Folhas=2&3 Folhas=3',
                              formlabel: 'Quantidade Portas Correr:' },
        orn_overlap_porta_correr: { default: 25.0, type: :float, label: 'Sobreposicao Correr (mm)', access: 'TEXTBOX',
                              formlabel: 'Sobreposicao entre portas (mm):' },

        # ── Rodape ────────────────────────────────────────────────
        orn_altura_rodape:  { default: 100.0,   type: :float,   label: 'Altura Rodape (mm)', access: 'TEXTBOX',
                              formlabel: 'Altura Rodape (mm):' },
        orn_recuo_rodape:   { default: 40.0,    type: :float,   label: 'Recuo Rodape (mm)', access: 'TEXTBOX',
                              formlabel: 'Recuo Rodape (mm):' },

        # ── Puxador ──────────────────────────────────────────────
        orn_tipo_puxador:   { default: 'barra', type: :string,  label: 'Tipo Puxador', access: 'LIST',
                              options: 'Barra=barra&Perfil=perfil&Botao/Pomo=botao&Cava Fresada=cava&Concha=concha',
                              formlabel: 'Tipo de Puxador:' },
        orn_entre_furos_puxador: { default: 128, type: :integer, label: 'Entre-Furos (mm)', access: 'LIST',
                              options: '32=32&64=64&96=96&128=128&160=160&192=192&256=256&320=320&480=480&736=736',
                              formlabel: 'Entre-Furos Puxador (mm):' },
        orn_orientacao_puxador: { default: 'vertical', type: :string, label: 'Orientacao Puxador', access: 'LIST',
                              options: 'Vertical=vertical&Horizontal=horizontal',
                              formlabel: 'Orientacao Puxador:' },
        orn_modelo_puxador: { default: 'PUX_BARRA_128', type: :string, label: 'Modelo Puxador', access: 'LIST',
                              formlabel: 'Modelo Puxador:' },

        # ── Ferragem ─────────────────────────────────────────────
        orn_dist_calco:     { default: 3.0,     type: :float,   label: 'Dist Calco (mm)', access: 'TEXTBOX' },
        orn_dist_furos_caneco:{ default: 20.5,  type: :float,   label: 'Dist Furos Caneco (mm)', access: 'VIEW' },

        # ── Corredica (gavetas) ──────────────────────────────────
        orn_tipo_corredica: { default: 'telescopica', type: :string, label: 'Tipo Corredica', access: 'LIST',
                              options: 'Telescopica=telescopica&Oculta Tandem=oculta&Quadro Metalico=quadro_metalico&Tandembox=tandembox',
                              formlabel: 'Tipo de Corredica:' },
        orn_altura_lateral_gaveta: { default: 0, type: :float, label: 'Altura Lateral Gaveta (mm)', access: 'LIST',
                              options: 'Proporcional=0&86mm=86&118mm=118&150mm=150&83mm (M)=83&115mm (K)=115&198mm (D)=198',
                              formlabel: 'Altura Lateral Gaveta:' },

        # ── Articulador (basculante) ─────────────────────────────
        orn_tipo_articulador: { default: 'aventos_hf', type: :string, label: 'Tipo Articulador', access: 'LIST',
                              options: 'Aventos HF (Blum)=aventos_hf&Aventos HL=aventos_hl&Aventos HK-S=aventos_hk&Pistao Gas=pistao_gas&Pistao Hidraulico=pistao_hidraulico&Kinvaro (Grass)=kinvaro&Dobr. Basculante=dobratica_basculante',
                              formlabel: 'Tipo de Articulador:' },
        orn_forca_articulador: { default: 100, type: :float, label: 'Forca Articulador (N)', access: 'LIST',
                              options: '60N=60&80N=80&100N=100&120N=120&150N=150',
                              formlabel: 'Forca do Pistao (N):' },

        # ── Suporte de prateleira ────────────────────────────────
        orn_tipo_suporte_prat: { default: 'pino_5mm', type: :string, label: 'Suporte Prateleira', access: 'LIST',
                              options: 'Pino 5mm=pino_5mm&Pino 8mm=pino_8mm&Suporte Metalico L=suporte_metalico&Cremalheira=cremalheira&Confirmat (Fixa)=parafuso_confirmat',
                              formlabel: 'Tipo de Suporte:' },

        # ── Fixacao estrutural ───────────────────────────────────
        orn_tipo_fixacao:   { default: 'minifix', type: :string, label: 'Fixacao Estrutural', access: 'LIST',
                              options: 'Minifix=minifix&Confirmat=confirmat&Cavilha=cavilha&Minifix+Cavilha=minifix_cavilha&VB Conector=vb_conector',
                              formlabel: 'Tipo de Fixacao:' },

        # ── Pe/Base ──────────────────────────────────────────────
        orn_tipo_pe:        { default: 'regulavel', type: :string, label: 'Tipo Pe', access: 'LIST',
                              options: 'Regulavel=regulavel&Rodizio=rodizio&Sapata=sapata&Suspenso (Parede)=suspenso',
                              formlabel: 'Tipo de Pe/Base:' },

        # ── Canto L (blind corner) ──────────────────────────────
        orn_largura_retorno:{ default: 0, type: :float, label: 'Largura Retorno', access: 'TEXTBOX',
                              units: 'CENTIMETERS', formlabel: 'Largura Retorno (canto L):' },

        # ── Acabamento por face ──────────────────────────────────
        orn_material_face_a:{ default: '', type: :string, label: 'Material Face A', access: 'LIST',
                              formlabel: 'Material Face A (visivel):' },
        orn_material_face_b:{ default: '', type: :string, label: 'Material Face B', access: 'LIST',
                              formlabel: 'Material Face B (interna):' },

        # ── Controle de exportacao ───────────────────────────────
        orn_exportar:       { default: true,    type: :boolean, label: 'Exportar', access: 'LIST',
                              options: 'Sim=true&Nao=false' },
      }.freeze

      # ================================================================
      # ATRIBUTOS DA PECA (cada componente/grupo filho)
      # ================================================================
      PART_ATTRS = {
        # ── Identidade da peca ───────────────────────────────────
        orn_marcado:        { default: true,    type: :boolean, label: 'Ornato',         access: 'NONE' },
        orn_id:             { default: '',      type: :string,  label: 'ID',             access: 'VIEW' },
        orn_codigo:         { default: '',      type: :string,  label: 'Codigo',         access: 'VIEW' },
        orn_nome:           { default: '',      type: :string,  label: 'Nome',           access: 'TEXTBOX' },
        orn_tipo_peca:      { default: '',      type: :string,  label: 'Tipo',           access: 'LIST',
                              options: 'Lateral=lateral&Base=base&Topo=topo&Fundo=fundo&Prateleira=prateleira&Divisoria=divisoria&Porta=porta&Frente Gaveta=frente_gaveta&Lateral Gaveta=lateral_gaveta&Traseira Gaveta=traseira_gaveta&Fundo Gaveta=fundo_gaveta&Tampo=tampo&Travessa=travessa&Rodape=rodape&Testeira=testeira&Acessorio=acessorio&Ferragem=ferragem' },
        orn_subtipo:        { default: '',      type: :string,  label: 'Subtipo',        access: 'LIST',
                              options: 'Esquerda=esquerda&Direita=direita&Fixa=fixa&Regulavel=regulavel&Com Fixacao=comfixacao&Sem Fixacao=semfixacao' },

        # ── Dimensoes de corte (BRUTO — para nesting) ───────────
        orn_corte_comp:     { default: 0.0,     type: :float,   label: 'Corte Comp (mm)', access: 'VIEW' },
        orn_corte_larg:     { default: 0.0,     type: :float,   label: 'Corte Larg (mm)', access: 'VIEW' },
        orn_espessura:      { default: 18.0,    type: :float,   label: 'Espessura (mm)',  access: 'VIEW' },
        orn_espessura_real: { default: 18.5,    type: :float,   label: 'Esp. Real (mm)',  access: 'VIEW' },
        orn_extra_comp:     { default: 0.0,     type: :float,   label: 'Extra Comp (mm)', access: 'TEXTBOX' },
        orn_extra_larg:     { default: 0.0,     type: :float,   label: 'Extra Larg (mm)', access: 'TEXTBOX' },

        # ── Dimensoes liquidas (informativas) ────────────────────
        orn_liq_comp:       { default: 0.0,     type: :float,   label: 'Liq Comp (mm)',   access: 'VIEW' },
        orn_liq_larg:       { default: 0.0,     type: :float,   label: 'Liq Larg (mm)',   access: 'VIEW' },

        # ── Material ─────────────────────────────────────────────
        orn_material:       { default: '',      type: :string,  label: 'Material',        access: 'LIST',
                              formlabel: 'Material:' },
        orn_acabamento:     { default: '',      type: :string,  label: 'Acabamento',      access: 'VIEW' },

        # ── Grao (direcao da textura) ────────────────────────────
        orn_grao:           { default: 'comprimento', type: :string, label: 'Grao', access: 'LIST',
                              options: 'Comprimento=comprimento&Largura=largura&Sem=sem',
                              formlabel: 'Direcao do Grao:' },

        # ── Fita de borda (4 lados) ──────────────────────────────
        orn_borda_frontal:  { default: false,   type: :boolean, label: 'Borda Frontal',   access: 'LIST',
                              options: 'Sim=true&Nao=false' },
        orn_borda_traseira: { default: false,   type: :boolean, label: 'Borda Traseira',  access: 'LIST',
                              options: 'Sim=true&Nao=false' },
        orn_borda_esquerda: { default: false,   type: :boolean, label: 'Borda Esquerda',  access: 'LIST',
                              options: 'Sim=true&Nao=false' },
        orn_borda_direita:  { default: false,   type: :boolean, label: 'Borda Direita',   access: 'LIST',
                              options: 'Sim=true&Nao=false' },
        orn_borda_prioridade:{ default: 'comprimento', type: :string, label: 'Prioridade Borda', access: 'LIST',
                               options: 'Comprimento Passa=comprimento&Largura Passa=largura' },

        # ── Face visivel (para G-code) ───────────────────────────
        orn_face_visivel:   { default: 'face_a', type: :string, label: 'Face Visivel',    access: 'LIST',
                              options: 'Face A=face_a&Face B=face_b&Ambas=ambas&Nenhuma=nenhuma' },

        # ── Usinagem ─────────────────────────────────────────────
        orn_grupo_montagem: { default: '',      type: :string,  label: 'Grupo Montagem',  access: 'VIEW' },
        orn_grupo_operacao: { default: '',      type: :string,  label: 'Grupo Operacao',  access: 'VIEW' },

        # ── Controle ─────────────────────────────────────────────
        orn_na_lista_corte: { default: true,    type: :boolean, label: 'Lista de Corte',  access: 'LIST',
                              options: 'Sim=true&Nao=false' },
        orn_no_bom:         { default: false,   type: :boolean, label: 'No BOM',          access: 'LIST',
                              options: 'Sim=true&Nao=false' },
        orn_desabilitado:   { default: false,   type: :boolean, label: 'Desabilitado',    access: 'LIST',
                              options: 'Sim=true&Nao=false' },
        orn_quantidade:     { default: 1,       type: :integer, label: 'Quantidade',      access: 'TEXTBOX' },

        # ── Acessorio/Ferragem ───────────────────────────────────
        orn_categoria_acessorio: { default: '', type: :string, label: 'Categoria', access: 'VIEW' },
        orn_modelo_acessorio:    { default: '', type: :string, label: 'Modelo',    access: 'VIEW' },
        orn_ferragem:            { default: '', type: :string, label: 'Ferragem',  access: 'VIEW' },

        # ── Organico (tampo) ─────────────────────────────────────
        orn_organico:        { default: false, type: :boolean, label: 'Organico',  access: 'VIEW' },
        orn_contorno_json:   { default: '',    type: :string,  label: 'Contorno',  access: 'NONE' },
      }.freeze

      # ================================================================
      # Metodos de conveniencia
      # ================================================================

      # Verifica se uma entidade e uma peca Ornato marcada.
      # @param entity [Sketchup::Entity]
      # @return [Boolean]
      def self.peca_ornato?(entity)
        return false unless entity.respond_to?(:get_attribute)
        # Verificar na instancia primeiro, depois na definition (onde BoxBuilder marca)
        return true if entity.get_attribute(DICT_NAME, 'orn_marcado') == true
        if entity.respond_to?(:definition)
          entity.definition.get_attribute(DICT_NAME, 'orn_marcado') == true
        else
          false
        end
      end

      # Verifica se uma entidade e um modulo Ornato (grupo raiz).
      # @param entity [Sketchup::Entity]
      # @return [Boolean]
      def self.modulo_ornato?(entity)
        return false unless peca_ornato?(entity)
        tipo = entity.get_attribute(DICT_NAME, 'orn_tipo_modulo')
        tipo = entity.definition.get_attribute(DICT_NAME, 'orn_tipo_modulo') if (tipo.nil? || tipo.to_s.empty?) && entity.respond_to?(:definition)
        tipo && !tipo.to_s.empty?
      end

      # Marca uma entidade como peca Ornato com atributos padrao.
      # @param entity [Sketchup::Entity]
      # @param tipo [Symbol] tipo da peca (:lateral, :base, etc.)
      # @param attrs [Hash] atributos adicionais { orn_nome: 'Lateral Dir', ... }
      def self.marcar_peca!(entity, tipo:, attrs: {})
        # Atributos obrigatorios
        entity.set_attribute(DICT_NAME, 'orn_marcado', true)
        entity.set_attribute(DICT_NAME, 'orn_tipo_peca', tipo.to_s)
        entity.set_attribute(DICT_NAME, 'orn_id', Core::Ids.generate)
        entity.set_attribute(DICT_NAME, 'orn_versao', '1.0')

        # Atributos adicionais
        attrs.each do |key, value|
          entity.set_attribute(DICT_NAME, key.to_s, value)
        end

        # Aplicar defaults para atributos nao fornecidos
        PART_ATTRS.each do |attr_name, spec|
          key = attr_name.to_s
          unless attrs.key?(attr_name) || entity.get_attribute(DICT_NAME, key)
            entity.set_attribute(DICT_NAME, key, spec[:default])
          end
        end
      end

      # Marca uma entidade como modulo Ornato (grupo raiz).
      # @param entity [Sketchup::Entity]
      # @param tipo_modulo [Symbol] tipo do modulo
      # @param attrs [Hash] atributos adicionais
      def self.marcar_modulo!(entity, tipo_modulo:, attrs: {})
        entity.set_attribute(DICT_NAME, 'orn_marcado', true)
        entity.set_attribute(DICT_NAME, 'orn_tipo_modulo', tipo_modulo.to_s)
        entity.set_attribute(DICT_NAME, 'orn_id', Core::Ids.generate)
        entity.set_attribute(DICT_NAME, 'orn_versao', '1.0')

        attrs.each do |key, value|
          entity.set_attribute(DICT_NAME, key.to_s, value)
        end

        MODULE_ATTRS.each do |attr_name, spec|
          key = attr_name.to_s
          unless attrs.key?(attr_name) || entity.get_attribute(DICT_NAME, key)
            entity.set_attribute(DICT_NAME, key, spec[:default])
          end
        end
      end

      # Remove marcacao Ornato de uma entidade.
      # @param entity [Sketchup::Entity]
      def self.desmarcar!(entity)
        dict = entity.attribute_dictionary(DICT_NAME)
        entity.attribute_dictionaries.delete(dict) if dict
      end

      # Le todos os atributos Ornato de uma entidade.
      # @param entity [Sketchup::Entity]
      # @return [Hash] atributos { 'orn_nome' => 'Lateral Dir', ... }
      def self.ler_atributos(entity)
        dict = entity.attribute_dictionary(DICT_NAME)
        return {} unless dict

        attrs = {}
        dict.each_pair { |k, v| attrs[k] = v }
        attrs
      end

      # Atualiza um atributo Ornato.
      # @param entity [Sketchup::Entity]
      # @param key [String, Symbol]
      # @param value [Object]
      def self.set(entity, key, value)
        entity.set_attribute(DICT_NAME, key.to_s, value)
      end

      # Le um atributo Ornato.
      # @param entity [Sketchup::Entity]
      # @param key [String, Symbol]
      # @return [Object, nil]
      def self.get(entity, key)
        entity.get_attribute(DICT_NAME, key.to_s)
      end

      # Coleta todas as pecas Ornato do modelo ativo.
      # @return [Array<Sketchup::Entity>]
      def self.coletar_pecas(model = nil)
        model ||= Sketchup.active_model
        pecas = []
        percorrer(model.entities) do |entity|
          pecas << entity if peca_ornato?(entity) && !modulo_ornato?(entity)
        end
        pecas
      end

      # Coleta todos os modulos Ornato do modelo ativo.
      # @return [Array<Sketchup::Entity>]
      def self.coletar_modulos(model = nil)
        model ||= Sketchup.active_model
        modulos = []
        percorrer(model.entities) do |entity|
          modulos << entity if modulo_ornato?(entity)
        end
        modulos
      end

      private

      def self.percorrer(entities, &block)
        entities.each do |entity|
          if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
            block.call(entity)
            sub = entity.respond_to?(:definition) ? entity.definition.entities : entity.entities
            percorrer(sub, &block)
          end
        end
      end
    end
  end
end
