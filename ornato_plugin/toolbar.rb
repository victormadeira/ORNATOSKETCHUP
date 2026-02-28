# ornato_plugin/toolbar.rb — Toolbar principal do plugin

module Ornato
  module ToolbarSetup
    def self.criar
      tb = ::UI::Toolbar.new(PLUGIN_NAME)

      # ─── Nova Caixa ───
      cmd_caixa = UI::Command.new('Nova Caixa') {
        Sketchup.active_model.select_tool(Tools::CaixaTool.new)
      }
      cmd_caixa.tooltip = 'Criar novo modulo (caixa)'
      cmd_caixa.status_bar_text = 'Clique para posicionar o novo modulo'
      cmd_caixa.small_icon = cmd_caixa.large_icon = icon_path('caixa')
      tb.add_item(cmd_caixa)

      # ─── Templates ───
      cmd_template = UI::Command.new('Templates') {
        Sketchup.active_model.select_tool(Tools::TemplateTool.new)
      }
      cmd_template.tooltip = 'Catalogo de templates pre-configurados'
      cmd_template.status_bar_text = 'Abrir catalogo de modulos pre-configurados'
      cmd_template.small_icon = cmd_template.large_icon = icon_path('template')
      tb.add_item(cmd_template)

      tb.add_separator

      # ─── Porta ───
      cmd_porta = UI::Command.new('Porta') {
        Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:porta))
      }
      cmd_porta.tooltip = 'Adicionar porta ao modulo'
      cmd_porta.status_bar_text = 'Clique em um vao para adicionar porta'
      cmd_porta.small_icon = cmd_porta.large_icon = icon_path('porta')
      tb.add_item(cmd_porta)

      # ─── Gaveta ───
      cmd_gaveta = UI::Command.new('Gaveta') {
        Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:gaveta))
      }
      cmd_gaveta.tooltip = 'Adicionar gaveta ao modulo'
      cmd_gaveta.status_bar_text = 'Clique em um vao para adicionar gaveta'
      cmd_gaveta.small_icon = cmd_gaveta.large_icon = icon_path('gaveta')
      tb.add_item(cmd_gaveta)

      # ─── Prateleira ───
      cmd_prat = UI::Command.new('Prateleira') {
        Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:prateleira))
      }
      cmd_prat.tooltip = 'Adicionar prateleira ao modulo'
      cmd_prat.status_bar_text = 'Clique em um vao para adicionar prateleira'
      cmd_prat.small_icon = cmd_prat.large_icon = icon_path('prateleira')
      tb.add_item(cmd_prat)

      # ─── Divisoria ───
      cmd_div = UI::Command.new('Divisoria') {
        Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:divisoria))
      }
      cmd_div.tooltip = 'Adicionar divisoria ao modulo'
      cmd_div.status_bar_text = 'Clique em um vao para adicionar divisoria'
      cmd_div.small_icon = cmd_div.large_icon = icon_path('divisoria')
      tb.add_item(cmd_div)

      tb.add_separator

      # ─── Pecas Avulsas ───
      cmd_pecas = UI::Command.new('Pecas Avulsas') {
        Sketchup.active_model.select_tool(Tools::PecasAvulsasTool.new)
      }
      cmd_pecas.tooltip = 'Tampo, rodape, painel cavilhado, moldura...'
      cmd_pecas.status_bar_text = 'Criar pecas complementares avulsas'
      cmd_pecas.small_icon = cmd_pecas.large_icon = icon_path('pecas')
      tb.add_item(cmd_pecas)

      # ─── Editar ───
      cmd_edit = UI::Command.new('Editar') {
        Sketchup.active_model.select_tool(Tools::EditorTool.new)
      }
      cmd_edit.tooltip = 'Editar modulo selecionado'
      cmd_edit.status_bar_text = 'Selecione um modulo Ornato para editar'
      cmd_edit.small_icon = cmd_edit.large_icon = icon_path('editar')
      tb.add_item(cmd_edit)

      tb.add_separator

      # ─── Painel ───
      cmd_painel = UI::Command.new('Painel') {
        Ornato.mostrar_painel
      }
      cmd_painel.tooltip = 'Abrir painel Ornato'
      cmd_painel.status_bar_text = 'Abre o painel lateral do Ornato'
      cmd_painel.small_icon = cmd_painel.large_icon = icon_path('painel')
      tb.add_item(cmd_painel)

      tb.show
      tb
    end

    def self.icon_path(nome)
      path = File.join(PLUGIN_DIR, 'icons', "#{nome}.png")
      File.exist?(path) ? path : ''
    end
  end

  # Cria toolbar ao carregar
  @toolbar = ToolbarSetup.criar unless file_loaded?(File.join(PLUGIN_DIR, 'toolbar.rb'))
  file_loaded(File.join(PLUGIN_DIR, 'toolbar.rb'))
end
