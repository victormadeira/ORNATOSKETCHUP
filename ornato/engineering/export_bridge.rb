# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/export_bridge.rb — Exportador de modulos para o Sistema Web
#
# Converte modulos Ornato (SketchUp DC) para o formato JSON compativel
# com o endpoint POST /api/cnc/lotes/importar do sistema web Ornato.
#
# FORMATO DE SAIDA:
#   JSON com campos upm* (compativel com UpMobb/WPS) que o backend
#   Express processa e insere nas tabelas cnc_lotes + cnc_pecas.
#
# FLUXO:
#   1. Usuario seleciona modulos no SketchUp
#   2. ExportBridge.exportar_selecao() → JSON string
#   3. JSON e enviado via HTTP POST ao backend
#   4. Backend insere no banco e roda otimizacao
#
# CAMPOS MAPEADOS:
#   orn_corte_comp  → upmcutlength (mm)
#   orn_corte_larg  → upmcutwidth (mm)
#   orn_espessura_real → upmrealthickness (mm)
#   orn_material    → upmmaterialcode
#   orn_borda_*     → upmedgeside1-4
#   orn_tipo_peca   → upmcode (CM_LAT_ESQ, CM_BAS, etc.)
#   orn_grao        → upmdraw (FTE1x2 = comprimento, FTED1x3 = largura)
#   machining ops   → machining.workers[]

require 'json'

module Ornato
  module Engineering
    class ExportBridge

      ORNATO_DICT = 'ornato'.freeze
      DC_DICT     = 'dynamic_attributes'.freeze

      # ================================================================
      # Interface publica
      # ================================================================

      # Exporta todos os modulos selecionados para JSON.
      # @param cliente [String] nome do cliente
      # @param projeto [String] nome do projeto
      # @param codigo [String] codigo do projeto
      # @param vendedor [String] nome do vendedor
      # @return [String] JSON formatado para o endpoint /api/cnc/lotes/importar
      def self.exportar_selecao(cliente: '', projeto: '', codigo: '', vendedor: '')
        model = Sketchup.active_model
        selection = model.selection

        modulos = selection.select { |e| modulo_ornato?(e) }
        if modulos.empty?
          UI.messagebox('Nenhum modulo Ornato selecionado.')
          return nil
        end

        exportar_modulos(modulos,
          cliente: cliente, projeto: projeto,
          codigo: codigo, vendedor: vendedor)
      end

      # Exporta todos os modulos Ornato do modelo.
      # @return [String] JSON
      def self.exportar_modelo(cliente: '', projeto: '', codigo: '', vendedor: '')
        model = Sketchup.active_model
        modulos = []

        model.entities.each do |entity|
          modulos << entity if modulo_ornato?(entity)
        end

        if modulos.empty?
          puts '[ExportBridge] Nenhum modulo Ornato encontrado no modelo.'
          return nil
        end

        exportar_modulos(modulos,
          cliente: cliente, projeto: projeto,
          codigo: codigo, vendedor: vendedor)
      end

      # Exporta seleção ou modelo inteiro (sem UI.messagebox).
      # Usado pelo ErpBridge para sync silencioso.
      # @return [String, nil] JSON ou nil se vazio
      def self.exportar_selecao_ou_modelo(cliente: '', projeto: '', codigo: '', vendedor: '')
        model = Sketchup.active_model
        modulos = model.selection.select { |e| modulo_ornato?(e) }

        if modulos.empty?
          model.entities.each { |e| modulos << e if modulo_ornato?(e) }
        end

        return nil if modulos.empty?

        exportar_modulos(modulos,
          cliente: cliente, projeto: projeto,
          codigo: codigo, vendedor: vendedor)
      end

      # Exporta lista de modulos para JSON string.
      # @param modulos [Array<Sketchup::ComponentInstance>]
      # @return [String] JSON
      def self.exportar_modulos(modulos, cliente: '', projeto: '', codigo: '', vendedor: '')
        result = {
          details_project: {
            client_name: cliente,
            project_name: projeto,
            project_code: codigo,
            seller_name: vendedor,
          },
          model_entities: {},
          machining: {},
        }

        machining_idx = 0

        modulos.each_with_index do |modulo, mod_idx|
          mod_def = modulo.definition
          mod_nome = attr_dc(mod_def, 'orn_nome') || mod_def.name
          mod_tipo = attr_dc(mod_def, 'orn_tipo_modulo') || 'inferior'
          mod_code = attr_dc(mod_def, 'orn_modulo_code') || "M#{format('%02d', mod_idx + 1)}"
          mod_material = attr_dc(mod_def, 'orn_material_corpo') || ''
          mod_larg = (attr_dc(mod_def, 'orn_largura') || 0).to_f
          mod_prof = (attr_dc(mod_def, 'orn_profundidade') || 0).to_f
          mod_alt = (attr_dc(mod_def, 'orn_altura') || 0).to_f

          mod_entry = {
            upmmasterid: mod_idx,
            upmmasterdescription: mod_nome,
            orn_modulo_codigo: mod_code,
            orn_modulo_tipo: mod_tipo,
            orn_modulo_material: mod_material,
            orn_modulo_dims: "#{(mod_larg*10).round}x#{(mod_prof*10).round}x#{(mod_alt*10).round}",
            entities: {},
          }

          peca_idx = 0
          percorrer_pecas(mod_def) do |peca_def, peca_inst|
            # Ignorar ferragens (nao vao para lista de corte)
            na_lista = attr_dc(peca_def, 'orn_na_lista_corte')
            next if na_lista == false || na_lista == 0 || na_lista == '0' || na_lista == 'false'

            tipo_peca = attr_dc(peca_def, 'orn_tipo_peca')
            next if tipo_peca == 'ferragem'

            peca_data = construir_peca(peca_def, peca_inst, mod_idx, mod_nome)
            # Enriquecer com codigos para ERP (etiquetas/labels)
            peca_code = format('%02d', peca_idx + 1)
            peca_data[:orn_peca_codigo] = "#{mod_code}-#{peca_code}"
            peca_data[:orn_peca_seq] = peca_code
            peca_data[:orn_modulo_codigo] = mod_code
            peca_data[:orn_modulo_nome] = mod_nome
            peca_data[:orn_modulo_tipo] = mod_tipo
            mod_entry[:entities][peca_idx.to_s] = peca_data

            # Coletar usinagens (machining) — respeitando feature flag
            machining_code = peca_data[:upmprocesscodea]
            if machining_code && !machining_code.empty? && (Core::FeatureFlags.enabled?(:export_machining) rescue true)
              result[:machining][machining_idx.to_s] = {
                code: machining_code,
                workers: coletar_usinagens(peca_def, peca_inst),
              }
              machining_idx += 1
            end

            peca_idx += 1
          end

          # Coletar ferragens do módulo para o ERP (etiquetas, orçamento)
          ferragens = []
          percorrer_pecas(mod_def) do |peca_def, peca_inst|
            tipo_peca = attr_dc(peca_def, 'orn_tipo_peca')
            next unless tipo_peca == 'ferragem'
            nome_hw = attr_dc(peca_def, 'orn_nome') || peca_def.name
            subtipo_hw = attr_dc(peca_def, 'orn_subtipo') || ''
            marca = attr_dc(peca_def, 'orn_marca') || ''
            modelo_hw = attr_dc(peca_def, 'orn_modelo') || ''
            ferragens << {
              nome: nome_hw,
              subtipo: subtipo_hw,
              marca: marca,
              modelo: modelo_hw,
            }
          end
          mod_entry[:orn_ferragens] = ferragens unless ferragens.empty?

          result[:model_entities][mod_idx.to_s] = mod_entry
        end

        JSON.pretty_generate(result)
      end

      # Exporta e envia diretamente ao servidor web.
      # @param url [String] URL do endpoint (ex: 'http://localhost:3000/api/cnc/lotes/importar')
      # @return [Boolean] sucesso
      def self.exportar_e_enviar(url, cliente: '', projeto: '', codigo: '', vendedor: '')
        json = exportar_selecao(
          cliente: cliente, projeto: projeto,
          codigo: codigo, vendedor: vendedor)
        return false unless json

        enviar_json(url, json)
      end

      private

      # ================================================================
      # Construcao de peca no formato upm*
      # ================================================================

      def self.construir_peca(peca_def, peca_inst, mod_idx, mod_nome)
        # Dimensoes de corte (mm)
        corte_comp = avaliar_formula_ou_valor(peca_def, 'orn_corte_comp')
        corte_larg = avaliar_formula_ou_valor(peca_def, 'orn_corte_larg')

        # Espessura
        esp_real = attr_dc(peca_def, 'orn_espessura_real') ||
                   attr_dc(peca_def, 'orn_espessura') || 18.5

        # Material
        material = attr_dc(peca_def, 'orn_material') ||
                   attr_ornato(peca_def, 'orn_material') || ''
        material_code = material_para_code(material, esp_real)

        # Bordas
        borda_f = borda_str(peca_def, 'orn_borda_frontal')
        borda_t = borda_str(peca_def, 'orn_borda_traseira')
        borda_e = borda_str(peca_def, 'orn_borda_esquerda')
        borda_d = borda_str(peca_def, 'orn_borda_direita')

        # Grao → upmdraw
        grao = attr_dc(peca_def, 'orn_grao') || 'comprimento'
        upmdraw = grao_para_upmdraw(grao)

        # Codigo da peca
        tipo_peca = attr_dc(peca_def, 'orn_tipo_peca') || ''
        subtipo = attr_dc(peca_def, 'orn_subtipo') || ''
        upmcode = tipo_peca_para_upmcode(tipo_peca, subtipo)

        # Nome
        nome = attr_dc(peca_def, 'orn_nome') || peca_def.name

        # Face visivel
        face = attr_dc(peca_def, 'orn_face_visivel') || 'face_a'

        # Persistent ID
        persistent_id = attr_dc(peca_def, 'orn_id') ||
                         attr_ornato(peca_def, 'orn_id') || ''

        # Dimensoes 3D (cm → mm)
        # Tentar DC attributes primeiro; fallback para bounding box se DC nao computou
        height_cm = avaliar_formula_ou_valor(peca_def, '_lenz') || 0
        depth_cm  = avaliar_formula_ou_valor(peca_def, '_leny') || 0
        width_cm  = avaliar_formula_ou_valor(peca_def, '_lenx') || 0

        if (height_cm == 0 || depth_cm == 0 || width_cm == 0) && peca_def.bounds
          bb = peca_def.bounds
          # SketchUp bounds retorna em inches; .to_cm converte
          # Usar eixos diretos (X=largura/espessura, Y=profundidade, Z=altura)
          width_cm  = bb.width.to_cm if width_cm == 0    # X
          depth_cm  = bb.depth.to_cm if depth_cm == 0    # Y
          height_cm = bb.height.to_cm if height_cm == 0  # Z
        end

        # Machining code
        process_a = attr_dc(peca_def, 'orn_grupo_operacao') || ''

        # QR data: dados para etiqueta QR (inspirado Haixun/MOBPRO)
        nome_safe = nome.to_s.tr('|', '-')
        mat_safe = material.to_s.tr('|', '-')
        qr_data = "#{upmcode}|#{nome_safe}|#{(corte_comp || 0).round}x#{(corte_larg || 0).round}x#{esp_real}|#{mat_safe}"

        {
          upmpiece: true,
          upmpersistentid: persistent_id,
          upmcode: upmcode,
          upmdescription: nome,
          upmquantity: 1,
          upmedgeside1: borda_f,
          upmedgeside2: borda_t,
          upmedgeside3: borda_e,
          upmedgeside4: borda_d,
          upmedgesidetype: '',
          upmdraw: upmdraw,
          upmprocesscodea: process_a,
          upmprocesscodeb: '',
          upmheight: height_cm * 10.0,   # cm → mm
          upmdepth: depth_cm * 10.0,
          upmwidth: width_cm * 10.0,
          qr_label: qr_data,
          entities: {
            '0' => {
              upmfeedstockpanel: true,
              upmmaterialcode: material_code,
              upmdescription: material,
              upmrealthickness: esp_real,
              upmcutlength: aplicar_deducao_borda(corte_comp || 0, borda_f, borda_t, esp_borda_mm(peca_def)),
              upmcutwidth: aplicar_deducao_borda(corte_larg || 0, borda_e, borda_d, esp_borda_mm(peca_def)),
            }
          }
        }
      end

      # ================================================================
      # Helpers de atributos
      # ================================================================

      def self.modulo_ornato?(entity)
        return false unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
        return false unless entity.respond_to?(:definition)
        marcado = entity.definition.get_attribute(DC_DICT, 'orn_marcado')
        tipo = entity.definition.get_attribute(DC_DICT, 'orn_tipo_modulo')
        marcado == true && tipo && !tipo.to_s.empty?
      end

      def self.attr_dc(definition, key)
        definition.get_attribute(DC_DICT, key)
      end

      def self.attr_ornato(definition, key)
        definition.get_attribute(ORNATO_DICT, key)
      end

      # Avaliar formula DC ou retornar valor direto.
      # Formulas como 'Parent!orn_largura*10' nao podem ser avaliadas
      # fora do SketchUp DC engine. Neste caso retornamos o valor
      # numerico ja calculado pelo DC no atributo sem _formula.
      def self.avaliar_formula_ou_valor(peca_def, attr_name)
        # Tentar valor direto (ja calculado pelo DC engine)
        val = attr_dc(peca_def, attr_name)
        return val.to_f if val.is_a?(Numeric)

        # Para formulas de corte, o valor calculado fica no atributo sem _formula
        # Ex: orn_corte_comp = valor calculado, orn_corte_comp_formula = formula
        val = attr_dc(peca_def, attr_name.to_s.sub('_formula', ''))
        return val.to_f if val.is_a?(Numeric)

        nil
      end

      # ================================================================
      # Conversores
      # ================================================================

      # Converte flag de borda Ornato para string de fita de borda
      def self.borda_str(peca_def, attr_name)
        val = attr_dc(peca_def, attr_name)
        val == true || val == 1 || val == '1' || val == 'true' ? '1' : ''
      end

      # Converte direcao de grao para codigo upmdraw
      # FTE1x2 = comprimento passa (grao no comprimento)
      # FTED1x3 = largura passa (grao na largura)
      def self.grao_para_upmdraw(grao)
        case grao.to_s.downcase
        when 'comprimento', 'length' then 'FTE1x2'
        when 'largura', 'width' then 'FTED1x3'
        else ''
        end
      end

      # Converte tipo_peca Ornato para upmcode
      def self.tipo_peca_para_upmcode(tipo, subtipo)
        base = case tipo.to_s
               when 'lateral'
                 case subtipo.to_s
                 when 'direita' then 'CM_LAT_DIR'
                 when 'retorno' then 'CM_LAT_RET'
                 else 'CM_LAT_ESQ'
                 end
               when 'base'
                 subtipo.to_s == 'retorno' ? 'CM_BAS_RET' : 'CM_BAS'
               when 'topo'
                 subtipo.to_s == 'retorno' ? 'CM_TOP_RET' : 'CM_TOP'
               when 'fundo'      then 'CM_FUN'
               when 'prateleira' then 'CM_PRA'
               when 'divisoria'  then 'CM_DIV'
               when 'travessa'   then 'CM_TRA'
               when 'rodape'     then 'CM_ROD'
               when 'porta'
                 case subtipo.to_s
                 when 'esquerda'   then 'CM_POR_ESQ'
                 when 'direita'    then 'CM_POR_DIR'
                 when 'basculante' then 'CM_POR_BAS'
                 when 'correr'     then 'CM_POR_COR'
                 else 'CM_POR'
                 end
               when 'frente_gaveta'   then 'CM_FRE_GAV'
               when 'lateral_gaveta'
                 subtipo.to_s == 'direita' ? 'CM_LAT_GAV_D' : 'CM_LAT_GAV_E'
               when 'traseira_gaveta' then 'CM_TRAS_GAV'
               when 'fundo_gaveta'    then 'CM_FUN_GAV'
               when 'testeira'        then 'CM_TEST'
               when 'tampo'
                 subtipo.to_s == 'organico' ? 'CM_TAM_ORG' : (subtipo.to_s == 'passante' ? 'CM_TAM_PASS' : 'CM_TAM')
               when 'acessorio'       then "ACES_#{subtipo.to_s.upcase}"
               else "CM_#{tipo.to_s.upcase[0..2]}"
               end
        base
      end

      MATERIAIS_VALIDOS = %w[MDF MDP HDF COMPENSADO VIDRO ESPELHO OSB METAL].freeze

      # Converte nome de material para material_code
      # Ex: 'MDF 18mm Branco TX' → 'MDF_18.5_BRANCO_TX'
      def self.material_para_code(material, espessura_real)
        return '' if material.nil? || material.empty?
        parts = material.to_s.split(/\s+/)
        tipo = (parts[0] || 'MDF').upcase
        unless MATERIAIS_VALIDOS.any? { |m| tipo.include?(m) }
          puts "[ExportBridge] AVISO: Material '#{tipo}' desconhecido, usando MDF."
          tipo = 'MDF'
        end
        acabamento = parts[2..].join('_').upcase if parts.length > 2
        acabamento = 'BRANCO_TX' if acabamento.nil? || acabamento.empty?
        "#{tipo}_#{espessura_real}_#{acabamento}"
      end

      # ================================================================
      # Percorrer pecas de um modulo
      # ================================================================

      def self.percorrer_pecas(mod_def, &block)
        mod_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          peca_def = entity.definition
          marcado = peca_def.get_attribute(DC_DICT, 'orn_marcado')
          if marcado == true
            block.call(peca_def, entity)
          end
          # Recursivo: buscar pecas aninhadas (gavetas, sub-componentes)
          # Apenas se nao for ferragem (ferragens sao tratadas em coletar_usinagens)
          tipo = attr_dc(peca_def, 'orn_tipo_peca')
          if tipo != 'ferragem' && tipo != 'acessorio'
            percorrer_pecas(peca_def, &block)
          end
        end
      end

      # ================================================================
      # Coletar usinagens para machining JSON
      # ================================================================

      def self.coletar_usinagens(peca_def, peca_inst)
        workers = []

        # Verificar se tem operacoes de machining no dicionario ornato
        ops_json = attr_ornato(peca_def, 'orn_operacoes_cnc')
        if ops_json.is_a?(String) && !ops_json.empty?
          begin
            ops = JSON.parse(ops_json)
            ops.each do |op|
              workers << {
                category: op['tipo'] || 'transfer_hole',
                tool_code: op['ferramenta'] || '',
                face: op['face'] || 'top',
                side: op['lado'] || 'side_a',
                x: op['x'] || 0,
                y: op['y'] || 0,
                depth: op['profundidade'] || 5,
                length: op['comprimento'],
                width: op['largura'],
                diameter: op['diametro'],
              }
            end
          rescue JSON::ParserError
            # Ignorar JSON invalido
          end
        end

        # Coletar ferragens embutidas (dobradicas, minifix, puxadores) como furos.
        # Ferragens sao IRMAS das pecas no modulo (nao filhas da peca).
        # Precisamos buscar no parent (modulo) e associar pela peca-alvo.
        mod_def = nil
        if peca_inst.respond_to?(:parent)
          parent = peca_inst.parent
          mod_def = parent.is_a?(Sketchup::ComponentDefinition) ? parent : nil
        end

        # Buscar dentro da propria peca (caso ferragem esteja aninhada)
        coletar_ferragens_de(peca_def, workers)

        # Buscar no modulo pai — ferragens que referenciam esta peca
        if mod_def
          peca_nome = peca_def.name
          mod_def.entities.each do |sibling|
            next unless sibling.is_a?(Sketchup::ComponentInstance)
            sib_def = sibling.definition
            tipo_peca = attr_dc(sib_def, 'orn_tipo_peca')
            next unless tipo_peca == 'ferragem'

            # Verificar se esta ferragem pertence a esta peca
            # via atributo orn_peca_alvo ou por proximidade espacial
            peca_alvo = attr_dc(sib_def, 'orn_peca_alvo')
            if peca_alvo && peca_alvo == peca_nome
              coletar_ferragens_de_instancia(sib_def, sibling, workers)
            elsif !peca_alvo
              # Sem peca_alvo: associar por tipo de ferragem e proximidade
              subtipo = attr_dc(sib_def, 'orn_subtipo')
              if subtipo == 'dobradica' || subtipo == 'minifix'
                # Dobradicas ficam na lateral, minifix nas pecas estruturais
                tipo_peca_atual = attr_dc(peca_def, 'orn_tipo_peca')
                if subtipo == 'dobradica' && tipo_peca_atual == 'porta'
                  coletar_ferragens_de_instancia(sib_def, sibling, workers)
                elsif subtipo == 'minifix' && %w[lateral base topo].include?(tipo_peca_atual)
                  coletar_ferragens_de_instancia(sib_def, sibling, workers)
                end
              elsif subtipo == 'puxador' || subtipo == 'puxador_furo'
                tipo_peca_atual = attr_dc(peca_def, 'orn_tipo_peca')
                if %w[porta frente_gaveta].include?(tipo_peca_atual)
                  coletar_ferragens_de_instancia(sib_def, sibling, workers)
                end
              end
            end
          end
        end

        workers.compact
      end

      # Coleta ferragens de dentro de uma definition (aninhadas)
      def self.coletar_ferragens_de(definition, workers)
        definition.entities.each do |child|
          next unless child.is_a?(Sketchup::ComponentInstance)
          child_def = child.definition
          tipo_ferragem = attr_dc(child_def, 'orn_subtipo')
          next unless tipo_ferragem
          coletar_ferragens_de_instancia(child_def, child, workers)
        end
      end

      # Coleta uma unica ferragem como worker
      def self.coletar_ferragens_de_instancia(def_, inst, workers)
        tipo_ferragem = attr_dc(def_, 'orn_subtipo')
        case tipo_ferragem
        when 'dobradica'
          workers << worker_dobradica(def_, inst)
        when 'minifix'
          workers << worker_minifix(def_, inst)
        when 'puxador_furo', 'puxador'
          workers << worker_puxador(def_, inst)
        end
      end

      def self.worker_dobradica(def_, inst)
        cfg = defined?(GlobalConfig) ? GlobalConfig.dobradica : { diametro_copa: 35, profundidade_copa: 12 }
        # Extrair posicao real do DC (x, z em cm → converter para mm)
        x_mm = extrair_posicao_mm(inst, :x)
        z_mm = extrair_posicao_mm(inst, :z)
        {
          category: 'transfer_hole',
          tool_code: "f_#{cfg[:diametro_copa]}mm",
          face: 'back',      # copa e na face interna da porta
          side: 'side_b',
          x: x_mm,
          y: z_mm,           # Y no CNC = Z no SketchUp (vertical)
          depth: cfg[:profundidade_copa],
          diameter: cfg[:diametro_copa],
        }
      end

      def self.worker_minifix(def_, inst)
        cfg = defined?(GlobalConfig) ? GlobalConfig.get(:minifix) : { diametro_furo_lateral: 8, profundidade_lateral: 34 }
        x_mm = extrair_posicao_mm(inst, :x)
        y_mm = extrair_posicao_mm(inst, :y)
        z_mm = extrair_posicao_mm(inst, :z)
        # Minifix na lateral: furo horizontal na face interna
        {
          category: 'transfer_hole',
          tool_code: "f_#{cfg[:diametro_furo_lateral]}mm",
          face: 'top',
          side: 'side_a',
          x: y_mm,           # Y do SketchUp = profundidade = X no CNC
          y: z_mm,           # Z do SketchUp = altura = Y no CNC
          depth: cfg[:profundidade_lateral],
          diameter: cfg[:diametro_furo_lateral],
        }
      end

      def self.worker_puxador(def_, inst)
        cfg = defined?(GlobalConfig) ? GlobalConfig.get(:puxador) : { diametro_furo: 5 }
        x_mm = extrair_posicao_mm(inst, :x)
        z_mm = extrair_posicao_mm(inst, :z)
        {
          category: 'transfer_hole',
          tool_code: "f_#{cfg[:diametro_furo]}mm",
          face: 'back',
          side: 'side_b',
          x: x_mm,
          y: z_mm,
          depth: 0,  # passante
          diameter: cfg[:diametro_furo],
        }
      end

      # Espessura da borda em mm a partir da peca
      def self.esp_borda_mm(peca_def)
        # Ler espessura de borda da peca ou do modulo pai
        val = attr_dc(peca_def, 'orn_borda_espessura')
        return val.to_f if val.is_a?(Numeric) && val > 0

        # Verificar se deve descontar borda
        descontar = attr_dc(peca_def, 'orn_descontar_borda')
        return 0.0 unless descontar == true || descontar == 1 || descontar == '1' || descontar == 'true'

        # Default: 1.0mm (PVC padrao) — consistente com ornato_attributes.rb
        1.0
      end

      # Deduzir espessura de borda do corte.
      # lado1 e lado2 sao strings: '1' = tem borda, '' = sem borda
      def self.aplicar_deducao_borda(dimensao_mm, lado1, lado2, esp_borda)
        return dimensao_mm if esp_borda <= 0
        deducao = 0.0
        deducao += esp_borda if lado1 == '1'
        deducao += esp_borda if lado2 == '1'
        [dimensao_mm - deducao, 0].max
      end

      # Extrair posicao em mm a partir da instancia DC.
      # O DC engine calcula as formulas e armazena o resultado em
      # polegadas nos atributos x, y, z da instancia.
      def self.extrair_posicao_mm(inst, eixo)
        return 0 unless inst.is_a?(Sketchup::ComponentInstance)
        # Posicao da instancia vem da transformacao (em polegadas internas)
        pos = inst.transformation.origin
        case eixo
        when :x then pos.x.to_mm.round(2)
        when :y then pos.y.to_mm.round(2)
        when :z then pos.z.to_mm.round(2)
        else 0
        end
      end

      # ================================================================
      # Enviar JSON via HTTP
      # ================================================================

      def self.enviar_json(url, json_string)
        require 'net/http'
        require 'uri'

        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = 10
        http.read_timeout = 30

        request = Net::HTTP::Post.new(uri.path)
        request['Content-Type'] = 'application/json'
        request.body = json_string

        response = http.request(request)

        if response.code.to_i == 200 || response.code.to_i == 201
          result = JSON.parse(response.body)
          puts "[ExportBridge] Exportacao OK — Lote #{result['id']}, #{result['total_pecas']} pecas"
          true
        else
          puts "[ExportBridge] ERRO #{response.code}: #{response.body}"
          false
        end

      rescue => e
        puts "[ExportBridge] Erro de conexao: #{e.message}"
        false
      end

      # ================================================================
      # Salvar JSON em arquivo
      # ================================================================

      def self.exportar_para_arquivo(caminho = nil, cliente: '', projeto: '', codigo: '', vendedor: '')
        # Tentar exportar selecao; se vazio, exportar modelo inteiro
        model = Sketchup.active_model
        selection = model.selection
        modulos_sel = selection.select { |e| modulo_ornato?(e) }

        if modulos_sel.empty?
          # Sem selecao: exportar todos os modulos do modelo
          json = exportar_modelo(
            cliente: cliente, projeto: projeto,
            codigo: codigo, vendedor: vendedor)
        else
          json = exportar_modulos(modulos_sel,
            cliente: cliente, projeto: projeto,
            codigo: codigo, vendedor: vendedor)
        end
        return false unless json

        caminho ||= UI.savepanel('Salvar JSON Ornato', '', 'projeto_ornato.json')
        return false unless caminho

        # Escrita segura: grava em tmp e renomeia (evita corrupção se SketchUp crashar)
        tmp_caminho = "#{caminho}.tmp"
        begin
          File.write(tmp_caminho, json, encoding: 'UTF-8')
          File.rename(tmp_caminho, caminho)
        rescue Errno::EACCES, Errno::ENOSPC, IOError => e
          File.delete(tmp_caminho) rescue nil
          ::UI.messagebox("Erro ao salvar: #{e.message}\nVerifique permissoes e espaco em disco.")
          return false
        end

        # Resumo para o usuario
        data = JSON.parse(json) rescue nil
        if data && data['model_entities']
          qtd_modulos = data['model_entities'].length
          qtd_pecas = data['model_entities'].values.sum { |m| m['entities']&.length || 0 }
          tamanho_kb = (File.size(caminho) / 1024.0).round(1)
          puts "[ExportBridge] JSON salvo: #{caminho} (#{qtd_modulos} modulos, #{qtd_pecas} pecas, #{tamanho_kb}KB)"
          Sketchup.status_text = "ORNATO: Exportado #{qtd_modulos} modulos, #{qtd_pecas} pecas (#{tamanho_kb}KB)"
        else
          puts "[ExportBridge] JSON salvo em: #{caminho}"
        end
        true
      end
    end
  end
end
