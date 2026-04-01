# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# ui/level_detector.rb — Detector de nível hierárquico
#
# Detecta em qual nível da hierarquia o projetista está:
#   :projeto   — nada selecionado, ou múltiplos módulos
#   :modulo    — um módulo ORNATO selecionado
#   :peca      — uma peça dentro de um módulo (lateral, base, porta...)
#   :operacao  — uma ferragem ou operação dentro de uma peça
#
# Retorna um hash com:
#   { nivel: :modulo, entity: <entity>, parent: <parent>, breadcrumb: [...] }

module Ornato
  module UI
    module LevelDetector
      DC = 'dynamic_attributes'.freeze

      # Detecta o nível do entity selecionado.
      # Retorna hash com :nivel, :entity, :parent_module, :breadcrumb, :data
      def self.detectar(selection)
        return nivel_projeto(selection) if selection.nil? || selection.empty?

        entity = selection.first
        return nivel_projeto(selection) unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

        # Caso 1: É um módulo ORNATO (raiz)
        if modulo_ornato?(entity)
          # Múltiplos módulos selecionados → nível projeto
          modulos = selection.select { |e| modulo_ornato?(e) }
          if modulos.length > 1
            return nivel_projeto_multi(modulos)
          end
          return nivel_modulo(entity)
        end

        # Caso 2: É uma peça marcada (dentro de um módulo)
        if peca_ornato?(entity)
          parent_mod = encontrar_modulo_pai(entity)
          tipo_peca = ler_attr(entity, 'orn_tipo_peca')

          # Ferragem é nível operação
          if tipo_peca == 'ferragem'
            return nivel_operacao(entity, parent_mod)
          end

          return nivel_peca(entity, parent_mod)
        end

        # Caso 3: Entity genérica — tentar subir na hierarquia para o módulo pai
        parent_mod = encontrar_modulo_pai(entity)
        if parent_mod
          return nivel_modulo(parent_mod)
        end

        # Nada reconhecido
        nivel_projeto(selection)
      end

      private

      def self.modulo_ornato?(entity)
        return false unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        def_ = entity.respond_to?(:definition) ? entity.definition : nil
        return false unless def_
        def_.get_attribute(DC, 'orn_marcado') == true &&
          !def_.get_attribute(DC, 'orn_tipo_modulo').to_s.empty?
      rescue
        false
      end

      def self.peca_ornato?(entity)
        return false unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        def_ = entity.respond_to?(:definition) ? entity.definition : nil
        return false unless def_
        def_.get_attribute(DC, 'orn_marcado') == true &&
          !def_.get_attribute(DC, 'orn_tipo_peca').to_s.empty?
      rescue
        false
      end

      def self.encontrar_modulo_pai(entity)
        # Estratégia 1: Usar edit_transform path do modelo ativo
        model = Sketchup.active_model
        if model
          path = model.active_path
          if path && path.length > 0
            # O primeiro item do active_path é o grupo/componente mais externo sendo editado
            path.each do |inst|
              return inst if modulo_ornato?(inst)
            end
          end
        end

        # Estratégia 2: Subir via parent (funciona quando não está editando)
        current = entity
        5.times do
          parent = current.respond_to?(:parent) ? current.parent : nil
          break unless parent

          if parent.respond_to?(:instances)
            parent.instances.each do |inst|
              return inst if modulo_ornato?(inst)
            end
          end

          if parent.respond_to?(:instances) && parent.instances.first
            current = parent.instances.first
          else
            break
          end
        end
        nil
      end

      def self.ler_attr(entity, attr)
        def_ = entity.respond_to?(:definition) ? entity.definition : nil
        return nil unless def_
        def_.get_attribute(DC, attr)
      end

      def self.to_bool(val)
        return false if val.nil?
        return false if val == false
        return false if val.to_s == 'false' || val.to_s == '0'
        true
      end

      # ── Código persistente do módulo ──

      # Obtém código persistido (orn_modulo_code) ou atribui um novo baseado
      # na posição atual do módulo no modelo. Grava no atributo DC para que
      # o código sobreviva a reordenações e sessões.
      def self.obter_ou_atribuir_codigo(entity)
        def_ = entity.definition
        code = def_.get_attribute(DC, 'orn_modulo_code')
        return code if code && !code.to_s.empty?

        # Primeiro uso — calcular pela posição e persistir
        model = Sketchup.active_model
        todos = model.entities.select { |e| modulo_ornato?(e) }
        idx = todos.index(entity) || todos.length
        code = "M#{format('%02d', idx + 1)}"
        def_.set_attribute(DC, 'orn_modulo_code', code)
        code
      rescue
        "M00"
      end

      # Reatribui códigos sequenciais a TODOS os módulos do modelo.
      # Útil após exclusão/reordenação. Chamado pelo nivel_projeto.
      def self.reatribuir_codigos(modulos)
        changed = false
        modulos.each_with_index do |m, idx|
          code = "M#{format('%02d', idx + 1)}"
          old_code = m.definition.get_attribute(DC, 'orn_modulo_code')
          if old_code != code
            m.definition.set_attribute(DC, 'orn_modulo_code', code)
            changed = true
          end
        end
        # Notificar sistema que códigos mudaram (para refresh de painel/export)
        Core.events.emit(:module_codes_changed, module_count: modulos.length) if changed
      rescue => e
        # Não interromper fluxo por falha em evento
      end

      # ── Construtores de nível ──

      # Calcula métricas agregadas de uma lista de módulos (DRY).
      def self.calcular_metricas(modulos)
        total_pecas = 0
        total_area = 0.0
        total_fita = 0.0
        total_peso = 0.0
        materiais = Hash.new(0.0)

        modulos.each do |mod|
          def_ = mod.definition rescue next
          def_.entities.each do |e|
            next unless (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) && e.respond_to?(:definition)
            ed = e.definition
            next unless ed.get_attribute(DC, 'orn_marcado') == true
            total_pecas += 1
            c = (ed.get_attribute(DC, 'orn_corte_comp') || 0).to_f
            l = (ed.get_attribute(DC, 'orn_corte_larg') || 0).to_f
            esp = (ed.get_attribute(DC, 'orn_espessura_real') || 18.5).to_f
            total_area += (c * l) / 1_000_000.0
            total_peso += (c * l * esp) / 1_000_000_000.0 * 750
            mat = ed.get_attribute(DC, 'orn_material') || 'Sem material'
            materiais[mat] += (c * l) / 1_000_000.0
            %w[orn_borda_frontal orn_borda_traseira].each { |a| total_fita += c / 1000.0 if to_bool(ed.get_attribute(DC, a)) }
            %w[orn_borda_esquerda orn_borda_direita].each { |a| total_fita += l / 1000.0 if to_bool(ed.get_attribute(DC, a)) }
          end
        end

        {
          total_pecas: total_pecas,
          total_area_m2: total_area.round(2),
          total_fita_m: total_fita.round(1),
          total_peso_kg: total_peso.round(1),
          materiais: materiais.map { |k, v| { nome: k, area_m2: v.round(3) } },
        }
      end

      def self.nivel_projeto(selection)
        model = Sketchup.active_model
        todos = model.entities.select { |e| modulo_ornato?(e) }

        # Reatribuir códigos sequenciais (garante consistência após exclusão)
        reatribuir_codigos(todos)

        metricas = calcular_metricas(todos)

        {
          nivel: :projeto,
          entity: nil,
          parent_module: nil,
          breadcrumb: [{ label: 'Projeto', nivel: :projeto }],
          data: metricas.merge(
            total_modulos: todos.length,
            modulos: todos.each_with_index.map { |m, idx| resumo_modulo(m, idx) },
          )
        }
      end

      def self.nivel_projeto_multi(modulos)
        metricas = calcular_metricas(modulos)

        {
          nivel: :projeto,
          entity: nil,
          parent_module: nil,
          breadcrumb: [{ label: 'Projeto', nivel: :projeto }],
          data: metricas.merge(
            total_modulos: modulos.length,
            modulos: modulos.each_with_index.map { |m, idx| resumo_modulo(m, idx) },
            multi_selecao: true,
          )
        }
      end

      def self.nivel_modulo(entity)
        def_ = entity.definition
        nome = def_.get_attribute(DC, 'orn_nome') || def_.name
        tipo = def_.get_attribute(DC, 'orn_tipo_modulo') || ''
        larg = (def_.get_attribute(DC, 'orn_largura') || 0).to_f
        prof = (def_.get_attribute(DC, 'orn_profundidade') || 0).to_f
        alt = (def_.get_attribute(DC, 'orn_altura') || 0).to_f
        esp = (def_.get_attribute(DC, 'orn_espessura_corpo') || 1.8).to_f
        material = def_.get_attribute(DC, 'orn_material_corpo') || ''
        tipo_fundo = def_.get_attribute(DC, 'orn_tipo_fundo') || ''

        # Código persistido — se ainda não tem, atribui e grava no componente
        mod_code = obter_ou_atribuir_codigo(entity)

        # ── Loop ÚNICO: coletar peças + calcular métricas ──
        pecas = []
        area_m2 = 0.0
        fita_m = 0.0
        peso_kg = 0.0

        def_.entities.each do |e|
          next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
          ed = e.respond_to?(:definition) ? e.definition : nil
          next unless ed
          next unless ed.get_attribute(DC, 'orn_marcado') == true

          tipo_p = ed.get_attribute(DC, 'orn_tipo_peca') || ''
          subtipo = ed.get_attribute(DC, 'orn_subtipo') || ''
          nome_p = ed.get_attribute(DC, 'orn_nome') || ed.name

          # Dimensões de corte
          comp_f = (ed.get_attribute(DC, 'orn_corte_comp') || 0).to_f
          larg_f = (ed.get_attribute(DC, 'orn_corte_larg') || 0).to_f
          esp_peca = (ed.get_attribute(DC, 'orn_espessura_real') || ed.get_attribute(DC, 'orn_espessura') || 18.5).to_f

          # Bordas
          borda_f = to_bool(ed.get_attribute(DC, 'orn_borda_frontal'))
          borda_t = to_bool(ed.get_attribute(DC, 'orn_borda_traseira'))
          borda_e = to_bool(ed.get_attribute(DC, 'orn_borda_esquerda'))
          borda_d = to_bool(ed.get_attribute(DC, 'orn_borda_direita'))

          # Métricas (acumular no mesmo loop)
          unless tipo_p == 'ferragem'
            area_m2 += (comp_f * larg_f) / 1_000_000.0
            peso_kg += (comp_f * larg_f * esp_peca) / 1_000_000_000.0 * 750
            fita_m += comp_f / 1000.0 if borda_f
            fita_m += comp_f / 1000.0 if borda_t
            fita_m += larg_f / 1000.0 if borda_e
            fita_m += larg_f / 1000.0 if borda_d
          end

          dims_str = comp_f > 0 && larg_f > 0 ? "#{comp_f.round} x #{larg_f.round} x #{esp_peca.round}" : nil

          pecas << {
            entity_id: e.entityID,
            nome: nome_p,
            tipo: tipo_p,
            subtipo: subtipo,
            dims: dims_str,
            bordas: { frontal: borda_f, traseira: borda_t, esquerda: borda_e, direita: borda_d },
          }
        end

        # Classificação — frente_gaveta agora vai pro grupo gavetas (junto com o corpo)
        tipos_estruturais = %w[lateral base topo fundo travessa rodape]
        tipos_frontais    = %w[porta basculante]
        tipos_internos    = %w[prateleira divisoria]
        tipos_gavetas     = %w[gaveta lateral_gaveta traseira_gaveta fundo_gaveta frente_gaveta]

        estruturais = pecas.select { |p| tipos_estruturais.include?(p[:tipo]) }
        frontais    = pecas.select { |p| tipos_frontais.include?(p[:tipo]) }
        internas    = pecas.select { |p| tipos_internos.include?(p[:tipo]) }
        gavetas     = pecas.select { |p| tipos_gavetas.include?(p[:tipo]) }
        ferragens   = pecas.select { |p| p[:tipo] == 'ferragem' }

        {
          nivel: :modulo,
          entity: entity,
          parent_module: entity,
          breadcrumb: [
            { label: 'Projeto', nivel: :projeto },
            { label: nome, nivel: :modulo, entity_id: entity.entityID },
          ],
          data: {
            _code: mod_code,
            entity_id: entity.entityID,
            nome: nome,
            tipo: tipo,
            largura_mm: (larg * 10).round,
            profundidade_mm: (prof * 10).round,
            altura_mm: (alt * 10).round,
            espessura_mm: (esp * 10).round,
            material: material,
            tipo_fundo: tipo_fundo,
            total_pecas: pecas.length - ferragens.length,
            composicao: {
              estruturais: estruturais,
              frontais: frontais,
              internas: internas,
              gavetas: gavetas,
              ferragens: ferragens,
            },
            tipo_sym: tipo.to_sym,
            area_m2: area_m2.round(3),
            fita_metros: fita_m.round(2),
            peso_kg: peso_kg.round(1),
          }
        }
      end

      def self.nivel_peca(entity, parent_mod)
        def_ = entity.respond_to?(:definition) ? entity.definition : nil
        return nivel_projeto(nil) unless def_

        nome_peca = def_.get_attribute(DC, 'orn_nome') || def_.name
        tipo_peca = def_.get_attribute(DC, 'orn_tipo_peca') || ''
        subtipo = def_.get_attribute(DC, 'orn_subtipo') || ''

        # Dimensões
        comp = (def_.get_attribute(DC, 'orn_corte_comp') || 0).to_f
        larg = (def_.get_attribute(DC, 'orn_corte_larg') || 0).to_f
        esp = (def_.get_attribute(DC, 'orn_espessura') || 18).to_f
        esp_real = (def_.get_attribute(DC, 'orn_espessura_real') || esp).to_f

        # Material
        material = def_.get_attribute(DC, 'orn_material') || ''
        grao = def_.get_attribute(DC, 'orn_grao') || 'comprimento'

        # Bordas (normalizar boolean — DC pode retornar string)
        bordas = {
          frontal: to_bool(def_.get_attribute(DC, 'orn_borda_frontal')),
          traseira: to_bool(def_.get_attribute(DC, 'orn_borda_traseira')),
          esquerda: to_bool(def_.get_attribute(DC, 'orn_borda_esquerda')),
          direita: to_bool(def_.get_attribute(DC, 'orn_borda_direita')),
          prioridade: def_.get_attribute(DC, 'orn_borda_prioridade') || 'comprimento',
        }

        # Face visível
        face_visivel = def_.get_attribute(DC, 'orn_face_visivel') || 'face_a'

        # Operações CNC (sub-componentes ferragem) — COM posição e face
        operacoes = []
        def_.entities.each do |e|
          next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
          next unless e.respond_to?(:definition)
          ed = e.definition
          next unless ed.get_attribute(DC, 'orn_tipo_peca') == 'ferragem'
          operacoes << {
            entity_id: e.entityID,
            nome: ed.get_attribute(DC, 'orn_nome') || ed.name,
            subtipo: ed.get_attribute(DC, 'orn_subtipo') || '',
            face: ed.get_attribute(DC, 'orn_face') || 'frente',
            pos_x: (ed.get_attribute(DC, 'orn_pos_x') || 0).to_f,
            pos_y: (ed.get_attribute(DC, 'orn_pos_y') || 0).to_f,
            diametro: (ed.get_attribute(DC, 'orn_diametro') || 0).to_f,
          }
        end

        # Na lista de corte (default true para pecas marcadas sem atributo explicito)
        na_lista_raw = def_.get_attribute(DC, 'orn_na_lista_corte')
        na_lista = na_lista_raw.nil? ? true : to_bool(na_lista_raw)

        # Contexto do módulo pai — código e índice da peça
        parent_code = nil
        piece_code = nil
        if parent_mod
          parent_code = obter_ou_atribuir_codigo(parent_mod)
          # Calcular índice sequencial da peça dentro do módulo
          piece_idx = 0
          parent_mod.definition.entities.each do |e|
            next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
            next unless e.respond_to?(:definition)
            ed = e.definition
            next unless ed.get_attribute(DC, 'orn_marcado') == true
            next if ed.get_attribute(DC, 'orn_tipo_peca') == 'ferragem'
            piece_idx += 1
            if e.entityID == entity.entityID
              piece_code = format('%02d', piece_idx)
              break
            end
          end
        end

        # Breadcrumb
        bc = [{ label: 'Projeto', nivel: :projeto }]
        if parent_mod
          nome_mod = parent_mod.definition.get_attribute(DC, 'orn_nome') || parent_mod.definition.name
          bc << { label: nome_mod, nivel: :modulo, entity_id: parent_mod.entityID }
        end
        bc << { label: nome_peca, nivel: :peca, entity_id: entity.entityID }

        {
          nivel: :peca,
          entity: entity,
          parent_module: parent_mod,
          breadcrumb: bc,
          data: {
            _parent_code: parent_code,
            _piece_code: piece_code,
            nome: nome_peca,
            tipo: tipo_peca,
            subtipo: subtipo,
            comp_mm: comp,
            larg_mm: larg,
            espessura_mm: esp,
            espessura_real_mm: esp_real,
            material: material,
            grao: grao,
            bordas: bordas,
            face_visivel: face_visivel,
            na_lista_corte: na_lista,
            operacoes: operacoes,
          }
        }
      end

      def self.nivel_operacao(entity, parent_mod)
        def_ = entity.respond_to?(:definition) ? entity.definition : nil
        return nivel_projeto(nil) unless def_

        nome = def_.get_attribute(DC, 'orn_nome') || def_.name
        subtipo = def_.get_attribute(DC, 'orn_subtipo') || ''

        # Tentar encontrar a peça pai
        peca_pai = nil
        parent_def = entity.respond_to?(:parent) ? entity.parent : nil
        if parent_def.respond_to?(:instances)
          peca_pai = parent_def.instances.find { |i| peca_ornato?(i) }
        end

        bc = [{ label: 'Projeto', nivel: :projeto }]
        if parent_mod
          nome_mod = parent_mod.definition.get_attribute(DC, 'orn_nome') || parent_mod.definition.name
          bc << { label: nome_mod, nivel: :modulo, entity_id: parent_mod.entityID }
        end
        if peca_pai
          nome_peca = peca_pai.definition.get_attribute(DC, 'orn_nome') || peca_pai.definition.name
          bc << { label: nome_peca, nivel: :peca, entity_id: peca_pai.entityID }
        end
        bc << { label: nome, nivel: :operacao, entity_id: entity.entityID }

        # Ler dados CNC adicionais
        pos_x = (def_.get_attribute(DC, 'orn_pos_x') || 0).to_f
        pos_y = (def_.get_attribute(DC, 'orn_pos_y') || 0).to_f
        pos_z = (def_.get_attribute(DC, 'orn_pos_z') || 0).to_f
        diametro = (def_.get_attribute(DC, 'orn_diametro') || 0).to_f
        profundidade = (def_.get_attribute(DC, 'orn_profundidade_furo') || 0).to_f
        face = def_.get_attribute(DC, 'orn_face') || ''
        marca = def_.get_attribute(DC, 'orn_marca') || ''
        modelo = def_.get_attribute(DC, 'orn_modelo') || ''

        {
          nivel: :operacao,
          entity: entity,
          parent_module: parent_mod,
          breadcrumb: bc,
          data: {
            nome: nome,
            subtipo: subtipo,
            tipo_ferragem: subtipo,
            pos_x: pos_x,
            pos_y: pos_y,
            pos_z: pos_z,
            diametro: diametro,
            profundidade: profundidade,
            face: face,
            marca: marca,
            modelo: modelo,
          }
        }
      end

      def self.resumo_modulo(entity, idx = 0)
        def_ = entity.definition
        nome = def_.get_attribute(DC, 'orn_nome') || def_.name
        tipo = def_.get_attribute(DC, 'orn_tipo_modulo') || ''
        larg = (def_.get_attribute(DC, 'orn_largura') || 0).to_f
        prof = (def_.get_attribute(DC, 'orn_profundidade') || 0).to_f
        alt = (def_.get_attribute(DC, 'orn_altura') || 0).to_f
        material = def_.get_attribute(DC, 'orn_material_corpo') || ''

        # Ler código persistido (já atribuído por reatribuir_codigos)
        mod_code = def_.get_attribute(DC, 'orn_modulo_code') || "M#{format('%02d', idx + 1)}"

        qtd_pecas = 0
        def_.entities.each do |e|
          next unless (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) && e.respond_to?(:definition)
          ed = e.definition rescue next
          next unless ed.get_attribute(DC, 'orn_marcado') == true
          next if ed.get_attribute(DC, 'orn_tipo_peca') == 'ferragem'
          qtd_pecas += 1
        end

        {
          entity_id: entity.entityID,
          _code: mod_code,
          nome: nome,
          tipo: tipo,
          material: material,
          dims: "#{(larg*10).round}x#{(prof*10).round}x#{(alt*10).round}",
          pecas: qtd_pecas,
        }
      rescue
        { entity_id: entity.entityID, _code: "M#{format('%02d', idx + 1)}", nome: '?', tipo: '?', dims: '?', pecas: 0 }
      end
    end
  end
end
