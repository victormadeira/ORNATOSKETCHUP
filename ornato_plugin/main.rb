# ornato_plugin/main.rb — Inicialização do plugin
# Carrega todos os módulos na ordem correta

module Ornato
  PLUGIN_DIR = File.dirname(__FILE__) unless defined?(PLUGIN_DIR)

  # ─── Base ───
  require File.join(PLUGIN_DIR, 'config')
  require File.join(PLUGIN_DIR, 'utils')

  # ─── Models ───
  require File.join(PLUGIN_DIR, 'models', 'peca')
  require File.join(PLUGIN_DIR, 'models', 'vao')
  require File.join(PLUGIN_DIR, 'models', 'modulo_info')
  require File.join(PLUGIN_DIR, 'models', 'material_info')

  # ─── Engines ───
  require File.join(PLUGIN_DIR, 'engines', 'motor_caixa')
  require File.join(PLUGIN_DIR, 'engines', 'motor_agregados')
  require File.join(PLUGIN_DIR, 'engines', 'motor_furacao')
  require File.join(PLUGIN_DIR, 'engines', 'motor_fita_borda')
  require File.join(PLUGIN_DIR, 'engines', 'motor_usinagem')
  require File.join(PLUGIN_DIR, 'engines', 'motor_portas')
  require File.join(PLUGIN_DIR, 'engines', 'motor_pecas_avulsas')
  require File.join(PLUGIN_DIR, 'engines', 'motor_plano_corte')
  require File.join(PLUGIN_DIR, 'engines', 'motor_templates')
  require File.join(PLUGIN_DIR, 'engines', 'motor_precificacao')
  require File.join(PLUGIN_DIR, 'engines', 'motor_alinhamento')

  # ─── Tools ───
  require File.join(PLUGIN_DIR, 'tools', 'caixa_tool')
  require File.join(PLUGIN_DIR, 'tools', 'agregado_tool')
  require File.join(PLUGIN_DIR, 'tools', 'editor_tool')
  require File.join(PLUGIN_DIR, 'tools', 'template_tool')
  require File.join(PLUGIN_DIR, 'tools', 'pecas_avulsas_tool')

  # ─── UI ───
  require File.join(PLUGIN_DIR, 'ui', 'painel')
  require File.join(PLUGIN_DIR, 'ui', 'propriedades')
  require File.join(PLUGIN_DIR, 'ui', 'catalogo_templates')

  # ─── Sistema ───
  require File.join(PLUGIN_DIR, 'toolbar')
  require File.join(PLUGIN_DIR, 'menu')
  require File.join(PLUGIN_DIR, 'observers')
  require File.join(PLUGIN_DIR, 'context_menu')

  # Inicialização ao carregar
  def self.init
    @painel = nil
    @propriedades = nil
    setup_observers
    ContextMenu.setup
    puts "[Ornato] Plugin v#{PLUGIN_VERSION} carregado com sucesso."
    puts "[Ornato] #{Engines::MotorTemplates::CATALOGO.size} templates disponiveis"
    puts "[Ornato] #{Models::BibliotecaMateriais.materiais_padrao.size} materiais na biblioteca"
    puts "[Ornato] Menu de contexto (right-click) ativo"
  end

  def self.painel
    @painel ||= UI::Painel.new
  end

  def self.propriedades
    @propriedades ||= UI::Propriedades.new
  end

  def self.mostrar_painel
    painel.mostrar
  end

  def self.setup_observers
    Sketchup.active_model.add_observer(Observers::ModelObserver.new)
  end

  init
end
