# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/import_bridge.rb — Importador de bibliotecas externas
#
# Importa componentes de bibliotecas de terceiros e converte seus
# atributos proprietarios para o schema Ornato (orn_*).
#
# Formato .lib (bibliotecas externas):
#   Arquivo ZIP contendo um .skp com Dynamic Components.
#   Atributos proprietarios sao lidos e mapeados para atributos Ornato.
#
# Este modulo:
#   1. Le atributos de bibliotecas externas (dynamic_attributes)
#   2. Converte para atributos Ornato (orn_*)
#   3. Marca pecas com dicionario 'ornato' (diferencia de paredes, pisos, etc.)
#   4. Extrai dimensoes de corte, bordas, material, espessura
#   5. Classifica pecas automaticamente
#
# Apos a importacao, as pecas sao 100% Ornato — o plugin opera
# exclusivamente com atributos orn_*.
#
# ═══════════════════════════════════════════════════════════════════════
# MAPEAMENTO WPS → ORNATO
# ═══════════════════════════════════════════════════════════════════════
#
# DIMENSOES:
#   wps: wpsuserwidth   → ornato: dim_largura_mm (eixo X do modulo)
#   wps: wpsuserdepth   → ornato: dim_profundidade_mm (eixo Y)
#   wps: wpsuserheight  → ornato: dim_altura_mm (eixo Z)
#   wps: wpscutlength   → ornato: corte_comprimento_mm (bruto, para nesting)
#   wps: wpscutwidth    → ornato: corte_largura_mm (bruto)
#   wps: wpscutthickness → ornato: espessura_real_mm
#   wps: wpscutliquidlength → (informativo, NAO usado no nesting)
#   wps: wpscutliquidwidth  → (informativo, NAO usado no nesting)
#   wps: wpsextralength  → ornato: extra_comprimento_mm (sobra de corte)
#   wps: wpsextrawidth   → ornato: extra_largura_mm
#
# ESPESSURA:
#   wps: wpsgespessuracorpo    → ornato: espessura_nominal (ex: 18)
#   wps: wpsgespessurafundo    → (espessura especifica do fundo)
#   wps: wpsgespessuraprateleira → (espessura das prateleiras)
#   wps: wpsgespessuraportasefrentes → (espessura das portas)
#   (espessura real = wpscutthickness = nominal + delta melamina)
#
# BORDAS (por peca, por lado):
#   wps: wpsgbordafrontal{peca}     → ornato: borda_frontal (1/0)
#   wps: wpsgbordatraseira{peca}    → ornato: borda_traseira
#   wps: wpsgbordadireita{peca}     → ornato: borda_direita
#   wps: wpsgbordaesquerda{peca}    → ornato: borda_esquerda
#   wps: wpsgespessurabordacorpo    → ornato: espessura_borda_mm
#   wps: wpsglarguraborda           → ornato: largura_borda_mm
#   wps: wpsdescontoborda           → ornato: desconto_borda (delta dim.)
#   wps: wpsgdescontarbordacorpos   → flag: descontar borda das dimensoes
#   wps: wpsgdescontarbordaportasefrentes → flag para portas
#   Pecas: lateral, base, prateleira, travessa, fundo
#   Variantes: comfixacao / semfixacao (com/sem encaixe)
#
# DIRECAO DE TEXTURA (GRAO):
#   wps: wpsgdirecaotextura{peca}  → ornato: grao (:length / :width / :none)
#   Pecas: lateral, base, fundo, prateleira, travessa, portasefrentes
#
# MATERIAL:
#   wps: wpsfinish       → ornato: material_acabamento (nome visual)
#   wps: wpsgmaterialtypecorpos → ornato: tipo_material (MDF, MDP, etc.)
#   wps: wpscode         → ornato: codigo_wps (codigo interno WPS)
#   wps: wpsdescription  → ornato: descricao_wps
#
# FUNDO:
#   wps: wpsgentradafundo         → ornato: recuo_fundo_mm
#   wps: wpsgtipofundocorpo       → ornato: tipo_fundo (:encaixado, :parafusado, :sem)
#   wps: wpsgespessurafundo       → ornato: espessura_fundo_mm
#   wps: wpsgfolgalarguracanalfundo → ornato: folga_canal_fundo_mm
#   wps: wpsgfolgarebaixofundo    → ornato: folga_rebaixo_fundo_mm
#   wps: wpsgfixacaofundoparafusado → flag parafusado
#
# FERRAGEM:
#   wps: wpsgDistanciaCalco       → ornato: calco_mm (calco da porta)
#   wps: wpsgDistanciaFurosCaneco → ornato: dist_furos_caneco_mm
#   wps: wpsgFuroCanecoMarcacao   → ornato: furo_caneco_marcacao
#   wps: wpsgdesviarsuportepinoplastico → flag desvio suporte pino
#   wps: wpsgcantoneirahabilitada → flag cantoneira
#
# IDENTIFICACAO:
#   wps: itemcode        → ornato: codigo_peca (ex: 'LATDIR', 'BASINF')
#   wps: wpsdescription  → ornato: nome_peca
#   wps: wpsdestination  → ornato: destino (qual modulo/grupo)
#   wps: wpsid           → ornato: wps_id (ID interno WPS)
#   wps: wpsedgeside     → ornato: lado_borda (qual lado tem borda)
#
# CONTROLE:
#   wps: wpsdisable      → ornato: desabilitado (peca oculta/inativa)
#   wps: wpscutlist      → ornato: na_lista_corte (1=sim, 0=nao)
#   wps: wpsallowtransferjob → ornato: permite_transferencia
#
# ═══════════════════════════════════════════════════════════════════════

module Ornato
  module Engineering
    class ImportBridge

      # Namespace do dicionario Ornato — CHAVE para diferenciar pecas
      # de mobiliario de qualquer outra geometria no modelo
      ORNATO_DICT = 'ornato'.freeze

      # Dicionario de atributos dinamicos do SketchUp
      DC_DICT = 'dynamic_attributes'.freeze

      # ================================================================
      # Resultado da conversao WPS → Ornato
      # ================================================================
      ConversaoResult = Struct.new(
        :sucesso,            # Boolean
        :tipo_peca,          # Symbol: :lateral, :base, :fundo, :porta, etc.
        :subtipo,            # Symbol, nil: :esquerda, :direita, :comfixacao, etc.
        :dimensoes,          # Hash: { comprimento:, largura:, espessura_nominal:, espessura_real: }
        :bordas,             # Hash<Symbol, Boolean>: { frontal:, traseira:, esquerda:, direita: }
        :material,           # Hash: { acabamento:, tipo:, codigo: }
        :grao,               # Symbol: :length, :width, :none
        :fundo,              # Hash: { tipo:, espessura:, entrada:, folga: }
        :na_lista_corte,     # Boolean
        :codigo_peca,        # String: itemcode WPS
        :nome_peca,          # String: descricao
        :atributos_raw,      # Hash: todos atributos WPS originais
        :avisos,             # Array<String>: problemas encontrados
        keyword_init: true
      )

      # ================================================================
      # Interface publica
      # ================================================================

      # Verifica se uma entidade SketchUp e uma peca Ornato marcada.
      # @param entity [Sketchup::Entity]
      # @return [Boolean]
      def self.peca_ornato?(entity)
        return false unless entity.respond_to?(:attribute_dictionaries)
        dict = entity.attribute_dictionary(ORNATO_DICT)
        dict != nil && dict['orn_marcado'] == true
      end

      # Verifica se uma entidade tem atributos WPS.
      # @param entity [Sketchup::Entity]
      # @return [Boolean]
      def self.tem_wps?(entity)
        return false unless entity.respond_to?(:attribute_dictionaries)
        dict = entity.attribute_dictionary(DC_DICT)
        return false unless dict

        # Procurar qualquer atributo com prefixo wps
        dict.each_pair do |key, _|
          return true if key.to_s.start_with?('wps')
        end
        false
      end

      # Marca uma entidade como peca Ornato.
      # Isso diferencia pecas de mobiliario de paredes, pisos, etc.
      # @param entity [Sketchup::Entity]
      # @param tipo [Symbol] tipo da peca
      # @param dados [Hash] dados adicionais
      def self.marcar_peca!(entity, tipo:, dados: {})
        # Usar prefixo orn_ para compatibilidade com OrnatoAttributes.peca_ornato?
        entity.set_attribute(ORNATO_DICT, 'orn_marcado', true)
        entity.set_attribute(ORNATO_DICT, 'orn_tipo_peca', tipo.to_s)
        entity.set_attribute(ORNATO_DICT, 'orn_versao', '1.0')
        entity.set_attribute(ORNATO_DICT, 'orn_timestamp', Time.now.iso8601)

        dados.each do |key, value|
          # Garantir que chaves usam prefixo orn_ se nao tiverem
          attr_name = key.to_s.start_with?('orn_') ? key.to_s : "orn_#{key}"
          entity.set_attribute(ORNATO_DICT, attr_name, value)
        end
      end

      # Desmarca uma entidade (remove dicionario Ornato).
      # @param entity [Sketchup::Entity]
      def self.desmarcar_peca!(entity)
        dict = entity.attribute_dictionary(ORNATO_DICT)
        entity.attribute_dictionaries.delete(dict) if dict
      end

      # Le atributos WPS de um componente e converte para formato Ornato.
      # @param entity [Sketchup::ComponentInstance, Sketchup::Group]
      # @return [ConversaoResult]
      def self.converter_wps_para_ornato(entity)
        avisos = []
        attrs = ler_atributos_wps(entity)

        if attrs.empty?
          return ConversaoResult.new(
            sucesso: false,
            avisos: ['Entidade nao possui atributos WPS (dynamic_attributes)']
          )
        end

        tipo, subtipo = detectar_tipo_peca(attrs, entity)
        dimensoes = extrair_dimensoes(attrs, entity, avisos)
        bordas = extrair_bordas(attrs, tipo)
        material = extrair_material(attrs)
        grao = extrair_grao(attrs, tipo)
        fundo = extrair_fundo(attrs)
        na_lista = attrs['wpscutlist'].to_s == '1'
        codigo = extrair_valor(attrs, 'itemcode')
        nome = extrair_valor(attrs, 'wpsdescription') || extrair_valor(attrs, '_name') || entity.name

        ConversaoResult.new(
          sucesso: true,
          tipo_peca: tipo,
          subtipo: subtipo,
          dimensoes: dimensoes,
          bordas: bordas,
          material: material,
          grao: grao,
          fundo: fundo,
          na_lista_corte: na_lista,
          codigo_peca: codigo,
          nome_peca: nome,
          atributos_raw: attrs,
          avisos: avisos
        )
      end

      # Converte e marca todas as pecas WPS de um modulo.
      # Pecas sao marcadas com ornato_part para diferencia-las de paredes.
      #
      # @param grupo_modulo [Sketchup::Group, Sketchup::ComponentInstance]
      # @return [Array<Hash>] [{ entity:, resultado: ConversaoResult }, ...]
      def self.converter_modulo(grupo_modulo)
        resultados = []

        percorrer_entidades(grupo_modulo) do |entity, profundidade|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)

          resultado = converter_wps_para_ornato(entity)

          if resultado.sucesso && resultado.na_lista_corte
            # Marcar como peca Ornato
            ImportBridge.marcar_peca!(entity,
              tipo: resultado.tipo_peca,
              dados: {
                'orn_subtipo' => resultado.subtipo.to_s,
                'orn_codigo' => resultado.codigo_peca,
                'orn_corte_comp' => resultado.dimensoes[:comprimento],
                'orn_corte_larg' => resultado.dimensoes[:largura],
                'orn_espessura' => resultado.dimensoes[:espessura_nominal],
                'orn_espessura_real' => resultado.dimensoes[:espessura_real],
                'orn_material' => resultado.material[:acabamento],
                'orn_grao' => resultado.grao.to_s,
                'orn_borda_frontal' => resultado.bordas[:frontal],
                'orn_borda_traseira' => resultado.bordas[:traseira],
                'orn_borda_esquerda' => resultado.bordas[:esquerda],
                'orn_borda_direita' => resultado.bordas[:direita],
                'orn_na_lista_corte' => true,
                'orn_origem' => 'import_bridge'
              }
            )

            resultados << { entity: entity, resultado: resultado, profundidade: profundidade }
          end
        end

        resultados
      end

      # Importa um .lib WPS (descomprime e carrega no modelo).
      # @param lib_path [String] caminho do arquivo .lib
      # @return [String, nil] caminho do .skp extraido ou nil se falhou
      def self.extrair_skp_de_lib(lib_path)
        return nil unless File.exist?(lib_path)
        return nil unless File.extname(lib_path).downcase == '.lib'

        require 'zip' rescue require 'rubygems'; require 'zip'

        temp_dir = File.join(Dir.tmpdir, "ornato_lib_#{Time.now.to_i}")
        Dir.mkdir(temp_dir) unless Dir.exist?(temp_dir)

        skp_path = nil
        Zip::File.open(lib_path) do |zip_file|
          zip_file.each do |entry|
            if entry.name.end_with?('.skp')
              dest = File.join(temp_dir, entry.name)
              entry.extract(dest)
              skp_path = dest
              break
            end
          end
        end

        skp_path
      rescue => e
        puts "ImportBridge: Erro ao extrair .lib: #{e.message}"
        nil
      end

      private

      # ================================================================
      # Leitura de atributos WPS
      # ================================================================

      def self.ler_atributos_wps(entity)
        attrs = {}

        # Ler do dicionario dynamic_attributes
        dict = entity.attribute_dictionary(DC_DICT)
        return attrs unless dict

        dict.each_pair do |key, value|
          attrs[key.to_s] = value
        end

        # Tambem tentar ler do definition (para ComponentInstance)
        if entity.respond_to?(:definition)
          def_dict = entity.definition.attribute_dictionary(DC_DICT)
          if def_dict
            def_dict.each_pair do |key, value|
              # Atributos do definition tem prioridade menor (template)
              attrs[key.to_s] ||= value
            end
          end
        end

        attrs
      end

      def self.extrair_valor(attrs, *keys)
        keys.each do |key|
          val = attrs[key]
          return val.to_s unless val.nil? || val.to_s.strip.empty?
          # Tentar com underscore prefix (padrao SketchUp DC)
          val = attrs["_#{key}"]
          return val.to_s unless val.nil? || val.to_s.strip.empty?
        end
        nil
      end

      # ================================================================
      # Deteccao de tipo de peca
      # ================================================================

      def self.detectar_tipo_peca(attrs, entity)
        # 1. Verificar itemcode WPS (mais confiavel)
        itemcode = extrair_valor(attrs, 'itemcode')&.upcase
        if itemcode
          tipo, subtipo = tipo_por_itemcode(itemcode)
          return [tipo, subtipo] if tipo
        end

        # 2. Verificar description WPS
        desc = extrair_valor(attrs, 'wpsdescription', '_description')
        if desc
          tipo, subtipo = tipo_por_descricao(desc)
          return [tipo, subtipo] if tipo
        end

        # 3. Verificar nome da entidade
        nome = entity.name || ''
        nome = entity.definition.name if nome.empty? && entity.respond_to?(:definition)
        if nome && !nome.empty?
          tipo, subtipo = tipo_por_descricao(nome)
          return [tipo, subtipo] if tipo
        end

        # 4. Verificar wpsdestination (qual grupo/posicao)
        dest = extrair_valor(attrs, 'wpsdestination')
        if dest
          tipo, subtipo = tipo_por_destino(dest)
          return [tipo, subtipo] if tipo
        end

        [:desconhecido, nil]
      end

      def self.tipo_por_itemcode(code)
        case code
        when /^LAT.*DIR/  then [:lateral, :direita]
        when /^LAT.*ESQ/  then [:lateral, :esquerda]
        when /^LAT/       then [:lateral, nil]
        when /^BAS.*INF/  then [:base, nil]
        when /^BAS/       then [:base, nil]
        when /^TOP/, /^REG/ then [:topo, nil]
        when /^FUN/       then [:fundo, nil]
        when /^PRA/       then [:prateleira, nil]
        when /^DIV/       then [:divisoria, nil]
        when /^POR/       then [:porta, nil]
        when /^FRE.*GAV/  then [:frente_gaveta, nil]
        when /^LAT.*GAV/  then [:lateral_gaveta, nil]
        when /^TRA.*GAV/  then [:traseira_gaveta, nil]
        when /^FUN.*GAV/  then [:fundo_gaveta, nil]
        when /^TAM/       then [:tampo, nil]
        when /^TRA/       then [:travessa, nil]
        when /^ROD/       then [:rodape, nil]
        when /^PAR/       then [:parafuso, nil]
        when /^DOB/       then [:dobradica, nil]
        when /^COR/       then [:corredica, nil]
        when /^PUX/       then [:puxador, nil]
        else nil
        end
      end

      def self.tipo_por_descricao(desc)
        d = desc.downcase.gsub(/[^a-z\s]/, '')
        case d
        when /lateral\s*(dir|direita)/       then [:lateral, :direita]
        when /lateral\s*(esq|esquerda)/      then [:lateral, :esquerda]
        when /lateral/                        then [:lateral, nil]
        when /base\s*(inf|inferior)/         then [:base, nil]
        when /base/                           then [:base, nil]
        when /topo|rega|superior/            then [:topo, nil]
        when /fundo/                          then [:fundo, nil]
        when /prateleira/                     then [:prateleira, nil]
        when /divisoria|divis/               then [:divisoria, nil]
        when /porta/                          then [:porta, nil]
        when /frente.*gaveta/                then [:frente_gaveta, nil]
        when /lateral.*gaveta/               then [:lateral_gaveta, nil]
        when /traseira.*gaveta/              then [:traseira_gaveta, nil]
        when /fundo.*gaveta/                 then [:fundo_gaveta, nil]
        when /tampo/                          then [:tampo, nil]
        when /travessa/                       then [:travessa, nil]
        when /rodape|rodap/                  then [:rodape, nil]
        when /chapa/                          then [:chapa, nil]
        else nil
        end
      end

      def self.tipo_por_destino(dest)
        d = dest.downcase
        case d
        when /lateral/ then [:lateral, nil]
        when /base/    then [:base, nil]
        when /fundo/   then [:fundo, nil]
        when /porta/   then [:porta, nil]
        else nil
        end
      end

      # ================================================================
      # Extracao de dimensoes
      # ================================================================

      def self.extrair_dimensoes(attrs, entity, avisos)
        # Preferir dimensoes de corte WPS (se disponiveis)
        comp = parse_float(extrair_valor(attrs, 'wpscutlength'))
        larg = parse_float(extrair_valor(attrs, 'wpscutwidth'))
        esp = parse_float(extrair_valor(attrs, 'wpscutthickness'))

        # Espessura nominal
        esp_nom = parse_float(extrair_valor(attrs, 'wpsgespessuracorpo'))

        # Se nao tem dimensoes de corte, usar LenX/LenY/LenZ
        if comp.nil? || comp <= 0
          # wpsuserwidth/depth/height estao em cm no SketchUp
          user_w = parse_float(extrair_valor(attrs, 'wpsuserwidth', '_lenx'))
          user_d = parse_float(extrair_valor(attrs, 'wpsuserdepth', '_leny'))
          user_h = parse_float(extrair_valor(attrs, 'wpsuserheight', '_lenz'))

          # Converter de cm para mm (SketchUp DC usa polegadas internamente)
          # Na verdade, dynamic_attributes armazena em polegadas!
          if user_w && user_w > 0
            user_w_mm = user_w * 25.4  # polegadas para mm
            user_d_mm = (user_d || 0) * 25.4
            user_h_mm = (user_h || 0) * 25.4

            dims = [user_w_mm, user_d_mm, user_h_mm].sort.reverse
            comp = dims[0]
            larg = dims[1]
            esp = dims[2] if esp.nil? || esp <= 0
          end
        end

        # Fallback: bounding box da entidade
        if comp.nil? || comp <= 0
          bb = entity.bounds
          unless bb.empty?
            dims = [bb.width.to_mm, bb.height.to_mm, bb.depth.to_mm].sort.reverse
            comp = dims[0].round(1)
            larg = dims[1].round(1)
            esp = dims[2].round(1) if esp.nil? || esp <= 0
            avisos << "Dimensoes extraidas do bounding box (sem atributos WPS de corte)"
          end
        end

        # Snap espessura nominal
        if esp_nom.nil? || esp_nom <= 0
          esp_nom = snap_espessura(esp)
        end

        {
          comprimento: (comp || 0).round(1),
          largura: (larg || 0).round(1),
          espessura_nominal: (esp_nom || 0).round(1),
          espessura_real: (esp || 0).round(1)
        }
      end

      def self.snap_espessura(valor)
        return 0 if valor.nil? || valor <= 0
        nominais = [6.0, 15.0, 18.0, 25.0, 30.0, 36.0]
        nominais.min_by { |n| (n - valor).abs }
      end

      # ================================================================
      # Extracao de bordas
      # ================================================================

      def self.extrair_bordas(attrs, tipo_peca)
        sufixo = sufixo_borda(tipo_peca)

        {
          frontal: borda_ativa?(attrs, "wpsgbordafrontal#{sufixo}"),
          traseira: borda_ativa?(attrs, "wpsgbordatraseira#{sufixo}"),
          esquerda: borda_ativa?(attrs, "wpsgbordaesquerda#{sufixo}"),
          direita: borda_ativa?(attrs, "wpsgbordadireita#{sufixo}")
        }
      end

      def self.sufixo_borda(tipo)
        case tipo
        when :lateral then 'lateral'
        when :base then 'base'
        when :topo then 'base' # topo usa mesmos atributos de base no WPS
        when :prateleira then 'prateleira'
        when :travessa then 'travessa'
        when :fundo then 'fundo'
        else 'lateral' # default
        end
      end

      def self.borda_ativa?(attrs, key)
        # WPS usa '0' ou '1', ou pode ser flag comfixacao/semfixacao
        val = attrs[key]
        return false if val.nil?

        case val.to_s.strip
        when '1', 'true', 'sim', 'yes' then true
        when '0', 'false', 'nao', 'no' then false
        else
          # Se o valor e numerico > 0, considerar ativo
          parse_float(val.to_s).to_f > 0
        end
      end

      # ================================================================
      # Extracao de material
      # ================================================================

      def self.extrair_material(attrs)
        {
          acabamento: extrair_valor(attrs, 'wpsfinish'),
          tipo: extrair_valor(attrs, 'wpsgmaterialtypecorpos'),
          codigo: extrair_valor(attrs, 'wpscode')
        }
      end

      # ================================================================
      # Extracao de grao
      # ================================================================

      def self.extrair_grao(attrs, tipo_peca)
        sufixo = case tipo_peca
                 when :lateral then 'lateral'
                 when :base, :topo then 'base'
                 when :fundo then 'fundo'
                 when :prateleira then 'prateleira'
                 when :travessa then 'travessa'
                 when :porta, :frente_gaveta then 'portasefrentes'
                 else 'lateral'
                 end

        direcao = extrair_valor(attrs, "wpsgdirecaotextura#{sufixo}")

        case direcao.to_s.downcase
        when 'comprimento', 'length', 'horizontal' then :length
        when 'largura', 'width', 'vertical' then :width
        when 'sem', 'none', 'nenhuma' then :none
        else :length # default
        end
      end

      # ================================================================
      # Extracao de fundo
      # ================================================================

      def self.extrair_fundo(attrs)
        tipo_raw = extrair_valor(attrs, 'wpsgtipofundocorpo', 'wpsgtipofundocorpoaereo')
        tipo = case tipo_raw.to_s.downcase
               when /encaixado/, /canal/ then :encaixado
               when /parafusado/, /sobreposto/ then :parafusado
               when /sem/, /none/ then :sem
               else :encaixado
               end

        {
          tipo: tipo,
          espessura: parse_float(extrair_valor(attrs, 'wpsgespessurafundo')),
          entrada: parse_float(extrair_valor(attrs, 'wpsgentradafundo')),
          folga_canal: parse_float(extrair_valor(attrs, 'wpsgfolgalarguracanalfundo')),
          folga_rebaixo: parse_float(extrair_valor(attrs, 'wpsgfolgarebaixofundo'))
        }
      end

      # ================================================================
      # Helpers
      # ================================================================

      def self.parse_float(val)
        return nil if val.nil?
        Float(val.to_s.gsub(',', '.'))
      rescue ArgumentError, TypeError
        nil
      end

      def self.percorrer_entidades(entity, profundidade = 0, &block)
        ents = if entity.respond_to?(:definition)
                 entity.definition.entities
               elsif entity.respond_to?(:entities)
                 entity.entities
               else
                 return
               end

        ents.each do |child|
          if child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group)
            block.call(child, profundidade)
            percorrer_entidades(child, profundidade + 1, &block)
          end
        end
      end
    end
  end
end
