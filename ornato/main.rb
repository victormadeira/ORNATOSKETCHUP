# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# ornato/main.rb — Bootstrap: carrega todos os subsistemas
#
# Ordem de carregamento:
#   1. Core (errors, config, ids, logger, events, constants, attributes, feature_flags)
#   2. Domain (contracts, entities)
#   3. Catalog (manager, defaults, snapshot, rulesets)
#   4. Recipes (base, registry, receitas individuais)
#   5. Components (factory, orchestrator, updater, engines, bridge)
#   6. Engineering (drilling, edging, machining, validator, readiness)
#   7. Export (engine)
#   8. Geometry (builder)
#   9. Visualization (markers, labels)
#  10. Tools (module_tool)
#  11. UI (toolbar, panel, observers)

require 'json'

module Ornato
  ORNATO_DIR = File.dirname(__FILE__)

  def self.load_subsystem(dir, files)
    files.each do |file|
      path = File.join(ORNATO_DIR, dir, "#{file}.rb")
      if File.exist?(path)
        require path
      else
        puts "ORNATO WARN: Arquivo nao encontrado: #{path}"
      end
    end
  end

  # -- 1. Core -----------------------------------------------------------------
  load_subsystem('core', %w[
    errors config ids logger events constants attributes feature_flags
  ])

  Core.logger.info("ORNATO v#{Core::Config::VERSION} iniciando...")
  Core.logger.info("Ruby #{RUBY_VERSION} / SketchUp #{Sketchup.version}")

  # -- 2. Domain ---------------------------------------------------------------
  load_subsystem('domain', %w[
    contracts project environment opening part
    hardware_item operation revision aggregate
    mod_entity ruleset diff_report machine_profile
  ])

  # -- 3. Catalog --------------------------------------------------------------
  load_subsystem('catalog', %w[
    default_catalog catalog_manager catalog_snapshot default_rulesets
  ])

  # -- 4. Recipes --------------------------------------------------------------
  load_subsystem('recipes', %w[
    recipe_base recipe_registry
    balcao_simples aereo_simples gaveteiro torre_forno
    roupeiro nicho painel tampo rodape canto
  ])

  # -- 5. Components -----------------------------------------------------------
  load_subsystem('components', %w[
    module_factory rebuild_orchestrator module_updater
    aggregate_engine identity_reconciler state_bridge
  ])

  # -- 6. Engineering ----------------------------------------------------------
  load_subsystem('engineering', %w[
    global_config ornato_attributes
    box_builder aggregate_builder accessory_builder
    hardware_embedder hardware_swapper hardware_catalog hardware_resolver
    capacity_validator collision_engine classificador_automatico
    export_bridge erp_bridge import_bridge module_connector tampo_organico_builder
    drilling_engine edging_engine machining_engine
    validator readiness_evaluator
  ])

  # -- 7. Export ---------------------------------------------------------------
  load_subsystem('export', %w[export_engine])

  # -- 8. Geometry -------------------------------------------------------------
  load_subsystem('geometry', %w[geometry_builder])

  # -- 9. Visualization --------------------------------------------------------
  load_subsystem('visualization', %w[drill_markers part_labels])

  # -- 10. Tools ---------------------------------------------------------------
  load_subsystem('tools', %w[module_tool])

  # -- 11. UI ------------------------------------------------------------------
  load_subsystem('ui', %w[toolbar level_detector main_panel observers])

  # -- Bootstrap ---------------------------------------------------------------

  def self.boot
    model = Sketchup.active_model
    return unless model

    # Carregar catalogo
    Core.catalog = Catalog::CatalogManager.new
    Core.catalog.load

    # Registrar receitas padrao
    Recipes::RecipeRegistry.instance.register_defaults

    # Criar toolbar
    toolbar = UI::Toolbar.new
    toolbar.setup(model)

    # Registrar observers
    UI::ObserverManager.attach(model)

    # Registrar menu
    setup_menu

    Core.logger.info("ORNATO v#{Core::Config::VERSION} pronto! #{Recipes::RecipeRegistry.instance.count} receitas carregadas.")
  end

  # ── Defaults inteligentes por tipo de modulo ──
  SMART_DEFAULTS = {
    inferior:          { l: 60, p: 55, a: 72 },
    superior:          { l: 80, p: 33, a: 70 },
    torre:             { l: 60, p: 55, a: 220 },
    gaveteiro:         { l: 60, p: 55, a: 72 },
    estante:           { l: 80, p: 30, a: 200 },
    roupeiro:          { l: 100, p: 55, a: 240 },
    bancada:           { l: 120, p: 60, a: 75 },
    pia:               { l: 80, p: 55, a: 82 },
    nicho:             { l: 60, p: 20, a: 40 },
    torre_quente:      { l: 60, p: 55, a: 220 },
    cooktop:           { l: 80, p: 55, a: 86 },
    micro_ondas:       { l: 60, p: 38, a: 45 },
    lava_louca:        { l: 60, p: 55, a: 82 },
    canto_l:           { l: 100, p: 55, a: 72 },
    canto_l_superior:  { l: 80, p: 33, a: 70 },
    ilha:              { l: 180, p: 70, a: 90 },
    espelheira:        { l: 60, p: 15, a: 80 },
    pia_banheiro:      { l: 60, p: 45, a: 80 },
  }.freeze

  # ── Categorias para organizar menus ──
  MENU_CATEGORIES = {
    'Cozinha' => [:inferior, :superior, :cooktop, :pia, :lava_louca, :torre_quente, :micro_ondas, :canto_l, :canto_l_superior, :ilha],
    'Quarto / Closet' => [:roupeiro, :gaveteiro, :torre],
    'Sala / Escritorio' => [:estante, :bancada, :nicho],
    'Banheiro' => [:pia_banheiro, :espelheira, :nicho],
    'Lavanderia / Varanda' => [:inferior, :superior, :torre, :nicho],
  }.freeze

  def self.setup_menu
    menu = ::UI.menu('Plugins')
    ornato_menu = menu.add_submenu('ORNATO')

    ornato_menu.add_item('Painel de Propriedades') { UI::MainPanel.instance.show }
    ornato_menu.add_separator

    # ── Sub-menus categorizados ──
    mod_menu = ornato_menu.add_submenu('Novo Modulo')

    MENU_CATEGORIES.each do |categoria, tipos|
      cat_menu = mod_menu.add_submenu(categoria)
      tipos.each do |tipo_sym|
        config = Engineering::BoxBuilder::CONFIGS[tipo_sym]
        next unless config
        cat_menu.add_item(config[:descricao]) do
          criar_modulo_via_menu(tipo_sym, config)
        end
      end
    end

    # ── Agregados com sub-categorias ──
    agg_menu = ornato_menu.add_submenu('Adicionar ao Modulo')

    portas_menu = agg_menu.add_submenu('Portas')
    portas_menu.add_item('Porta Unica') do
      mod = find_selected_ornato_module
      Engineering::AggregateBuilder.adicionar_porta(mod, tipo: :unica) if mod
    end
    portas_menu.add_item('Porta Dupla') do
      mod = find_selected_ornato_module
      Engineering::AggregateBuilder.adicionar_porta(mod, tipo: :dupla) if mod
    end
    portas_menu.add_item('Basculante') do
      mod = find_selected_ornato_module
      Engineering::AggregateBuilder.adicionar_basculante(mod) if mod
    end

    internas_menu = agg_menu.add_submenu('Divisoes Internas')
    internas_menu.add_item('Prateleira') do
      mod = find_selected_ornato_module
      Engineering::AggregateBuilder.adicionar_prateleira(mod) if mod
    end
    internas_menu.add_item('Divisoria Vertical') do
      mod = find_selected_ornato_module
      Engineering::AggregateBuilder.adicionar_divisoria(mod) if mod
    end

    agg_menu.add_separator
    agg_menu.add_item('Tampo Organico') do
      Engineering::TampoOrganicoBuilder.criar_de_selecao
    end

    # ── Acoes sobre modulo selecionado ──
    ornato_menu.add_separator

    ornato_menu.add_item('Validar Modulo') do
      mod = find_selected_ornato_module
      if mod
        alertas = Engineering::CapacityValidator.validar(mod)
        nome = mod.definition.get_attribute('dynamic_attributes', 'orn_nome') || mod.definition.name
        if alertas.empty?
          ::UI.messagebox("#{nome}: OK — Nenhum problema encontrado!")
        else
          erros = alertas.select { |a| a[:nivel] == :erro }
          avisos = alertas.select { |a| a[:nivel] == :aviso }
          msg = "#{nome} — Validacao\n\n"
          unless erros.empty?
            msg += "ERROS (#{erros.length}):\n"
            erros.each { |e| msg += "  #{e[:mensagem]}\n    → #{e[:sugestao]}\n" }
            msg += "\n"
          end
          unless avisos.empty?
            msg += "AVISOS (#{avisos.length}):\n"
            avisos.each { |a| msg += "  #{a[:mensagem]}\n    → #{a[:sugestao]}\n" }
          end
          ::UI.messagebox(msg)
        end
      end
    end

    ornato_menu.add_item('Classificar Pecas') do
      mod = find_selected_ornato_module
      if mod
        classificador = Engineering::ClassificadorAutomatico.new
        resultados = classificador.classificar_modulo(mod)
        ::UI.messagebox("Classificacao concluida: #{resultados.length} pecas classificadas")
      end
    end

    ornato_menu.add_separator
    ornato_menu.add_item('Exportar Projeto') do
      Engineering::ExportBridge.exportar_para_arquivo
    end

    ornato_menu.add_separator
    ornato_menu.add_item('Sobre ORNATO') do
      ::UI.messagebox(
        "ORNATO — Plataforma Parametrica de Marcenaria Industrial\n" \
        "Versao: #{Core::Config::VERSION}\n\n" \
        "Modulos faceis para o projetista,\npecas confiaveis para a fabrica."
      )
    end

    setup_context_menu
  end

  # Helper: criar modulo com defaults inteligentes
  def self.criar_modulo_via_menu(tipo_sym, config)
    defs = SMART_DEFAULTS[tipo_sym] || { l: 60, p: 55, a: 72 }

    prompts = ['Largura (cm):', 'Profundidade (cm):', 'Altura (cm):', 'Nome:']
    defaults = [defs[:l].to_s, defs[:p].to_s, defs[:a].to_s, '']
    result = ::UI.inputbox(prompts, defaults, ['', '', '', ''], "Novo #{config[:descricao]}")
    return unless result

    begin
      instance = Engineering::BoxBuilder.criar(
        tipo_sym,
        largura: result[0].to_f,
        profundidade: result[1].to_f,
        altura: result[2].to_f,
        nome: result[3].empty? ? nil : result[3]
      )
      nome_def = instance.definition.name
      qtd_pecas = instance.definition.entities.count { |e|
        e.is_a?(Sketchup::ComponentInstance) &&
        e.definition.get_attribute('dynamic_attributes', 'orn_marcado') == true
      }
      Sketchup.status_text = "ORNATO: #{nome_def} criado — #{qtd_pecas} pecas"
    rescue => e
      ::UI.messagebox("Erro ao criar modulo:\n#{e.message}")
    end
  end

  # ── Agregados permitidos por tipo de modulo ──
  AGREGADOS_POR_TIPO = {
    inferior:     [:porta_unica, :porta_dupla, :prateleira, :divisoria, :gaveta],
    superior:     [:porta_unica, :porta_dupla, :basculante, :prateleira, :divisoria],
    torre:        [:porta_unica, :porta_dupla, :prateleira, :divisoria],
    gaveteiro:    [:gaveta, :divisoria],
    estante:      [:prateleira, :divisoria],
    roupeiro:     [:porta_unica, :porta_dupla, :porta_correr, :prateleira, :divisoria, :gaveta],
    bancada:      [:prateleira],
    pia:          [:porta_unica, :porta_dupla, :gaveta],
    nicho:        [:prateleira],
    torre_quente: [:porta_unica, :prateleira],
    cooktop:      [:porta_unica, :gaveta],
    micro_ondas:  [:basculante, :prateleira],
    lava_louca:   [:porta_unica, :porta_dupla],
    canto_l:      [:porta_unica, :prateleira, :divisoria],
    canto_l_superior: [:porta_unica, :basculante, :prateleira],
    ilha:         [:porta_unica, :porta_dupla, :prateleira, :divisoria, :gaveta],
    espelheira:   [:porta_unica, :porta_dupla, :prateleira],
    pia_banheiro: [:porta_unica, :porta_dupla, :gaveta, :prateleira],
  }.freeze

  AGREGADO_LABELS = {
    porta_unica: 'Porta Unica',
    porta_dupla: 'Porta Dupla',
    porta_correr: 'Portas de Correr',
    basculante: 'Basculante',
    prateleira: 'Prateleira',
    divisoria: 'Divisoria Vertical',
    gaveta: 'Gaveta',
  }.freeze

  def self.setup_context_menu
    ::UI.add_context_menu_handler do |menu|
      sel = Sketchup.active_model.selection
      modulo = sel.find { |e| UI::LevelDetector.modulo_ornato?(e) rescue false }
      next unless modulo

      dc = 'dynamic_attributes'
      def_ = modulo.respond_to?(:definition) ? modulo.definition : nil
      next unless def_

      nome = def_.get_attribute(dc, 'orn_nome') || def_.name
      tipo_str = def_.get_attribute(dc, 'orn_tipo_modulo') || ''
      tipo_sym = tipo_str.to_s.to_sym
      larg = (def_.get_attribute(dc, 'orn_largura') || 0).to_f
      prof = (def_.get_attribute(dc, 'orn_profundidade') || 0).to_f
      alt = (def_.get_attribute(dc, 'orn_altura') || 0).to_f
      dims = "#{(larg*10).round}x#{(prof*10).round}x#{(alt*10).round}mm"

      ornato_sub = menu.add_submenu("ORNATO: #{nome} (#{dims})")

      # ── Agregados contextuais ──
      permitidos = AGREGADOS_POR_TIPO[tipo_sym] || [:porta_unica, :prateleira, :divisoria]
      add_sub = ornato_sub.add_submenu('Adicionar')

      permitidos.each do |agg_tipo|
        label = AGREGADO_LABELS[agg_tipo] || agg_tipo.to_s
        add_sub.add_item(label) do
          executar_agregado(modulo, agg_tipo)
        end
      end

      ornato_sub.add_separator

      # ── Acoes ──
      ornato_sub.add_item('Validar') do
        alertas = Engineering::CapacityValidator.validar(modulo)
        if alertas.empty?
          Sketchup.status_text = "#{nome}: OK — sem problemas"
          ::UI.messagebox("#{nome}: OK — Nenhum problema!")
        else
          erros = alertas.select { |a| a[:nivel] == :erro }
          avisos = alertas.select { |a| a[:nivel] == :aviso }
          msg = "#{nome} — Validacao\n\n"
          msg += "ERROS (#{erros.length}):\n" + erros.map { |e| "  #{e[:mensagem]}\n    → #{e[:sugestao]}" }.join("\n") + "\n\n" unless erros.empty?
          msg += "AVISOS (#{avisos.length}):\n" + avisos.map { |a| "  #{a[:mensagem]}\n    → #{a[:sugestao]}" }.join("\n") unless avisos.empty?
          ::UI.messagebox(msg)
        end
      end

      ornato_sub.add_item('Classificar Pecas') do
        classificador = Engineering::ClassificadorAutomatico.new
        resultados = classificador.classificar_modulo(modulo)
        Sketchup.status_text = "#{nome}: #{resultados.length} pecas classificadas"
      end

      ornato_sub.add_item('Exportar JSON') do
        json = Engineering::ExportBridge.exportar_modulos([modulo])
        if json
          path = ::UI.savepanel('Salvar JSON', '', "#{nome.gsub(/\s/, '_')}.json")
          if path
            File.write(path, json, encoding: 'UTF-8')
            Sketchup.status_text = "Exportado: #{path}"
          end
        end
      end
    end
  end

  # Executa agregado por tipo
  def self.executar_agregado(modulo, tipo)
    case tipo
    when :porta_unica
      Engineering::AggregateBuilder.adicionar_porta(modulo, tipo: :unica)
    when :porta_dupla
      Engineering::AggregateBuilder.adicionar_porta(modulo, tipo: :dupla)
    when :porta_correr
      Engineering::AggregateBuilder.adicionar_portas_correr(modulo, quantidade: 2)
    when :basculante
      Engineering::AggregateBuilder.adicionar_basculante(modulo)
    when :prateleira
      Engineering::AggregateBuilder.adicionar_prateleira(modulo)
    when :divisoria
      Engineering::AggregateBuilder.adicionar_divisoria(modulo)
    when :gaveta
      Engineering::AggregateBuilder.criar_conjunto_gavetas(modulo.definition, 3, 15)
    end
    Sketchup.status_text = "#{AGREGADO_LABELS[tipo]} adicionado(a)"
  rescue => e
    ::UI.messagebox("Erro: #{e.message}")
  end

  def self.find_selected_ornato_module
    sel = Sketchup.active_model.selection
    modulo = sel.find { |e| UI::LevelDetector.modulo_ornato?(e) rescue false }
    unless modulo
      ::UI.messagebox("Selecione um modulo ORNATO primeiro.")
    end
    modulo
  end

  # Iniciar ao carregar
  unless file_loaded?(File.basename(__FILE__))
    boot
    file_loaded(File.basename(__FILE__))
  end
end
