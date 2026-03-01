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

      # ─── Cotagem ───
      cmd_cotas = UI::Command.new('Cotagem') {
        sel = Sketchup.active_model.selection
        if sel.length == 1 && Utils.modulo_ornato?(sel.first)
          Engines::MotorCotagem.cotar_modulo(sel.first, externas: true, internas: true)
        else
          Engines::MotorCotagem.cotar_projeto
        end
      }
      cmd_cotas.tooltip = 'Cotagem automatica (dimensoes 3D)'
      cmd_cotas.status_bar_text = 'Adiciona cotas ao modulo selecionado ou ao projeto'
      cmd_cotas.small_icon = cmd_cotas.large_icon = icon_path('cotagem')
      tb.add_item(cmd_cotas)

      # ─── Ficha Tecnica ───
      cmd_ficha = UI::Command.new('Ficha Tecnica') {
        sel = Sketchup.active_model.selection
        if sel.length == 1 && Utils.modulo_ornato?(sel.first)
          mi = Models::ModuloInfo.carregar_do_grupo(sel.first)
          if mi
            ficha = Engines::MotorFichaTecnica.gerar_ficha(mi)
            html = Engines::MotorFichaTecnica.gerar_html_ficha(ficha, formato: :completa)
            MenuSetup.mostrar_html('Ficha Tecnica', html, 800, 1000)
          end
        else
          ::UI.messagebox('Selecione um modulo Ornato primeiro.', MB_OK)
        end
      }
      cmd_ficha.tooltip = 'Gerar ficha tecnica do modulo'
      cmd_ficha.status_bar_text = 'Gera ficha tecnica completa para producao'
      cmd_ficha.small_icon = cmd_ficha.large_icon = icon_path('ficha')
      tb.add_item(cmd_ficha)

      # ─── Etiquetas ───
      cmd_etiq = UI::Command.new('Etiquetas') {
        sel = Sketchup.active_model.selection
        if sel.length == 1 && Utils.modulo_ornato?(sel.first)
          mi = Models::ModuloInfo.carregar_do_grupo(sel.first)
          if mi
            etiquetas = Engines::MotorEtiquetas.gerar_etiquetas(mi)
            html = Engines::MotorEtiquetas.gerar_html_etiquetas(etiquetas, formato: :folha)
            MenuSetup.mostrar_html('Etiquetas', html, 800, 1000)
          end
        else
          modulos = Utils.listar_modulos
          if modulos.any?
            etiquetas = Engines::MotorEtiquetas.gerar_etiquetas_projeto(modulos)
            html = Engines::MotorEtiquetas.gerar_html_etiquetas(etiquetas, formato: :folha)
            MenuSetup.mostrar_html('Etiquetas - Projeto', html, 800, 1000)
          else
            ::UI.messagebox('Nenhum modulo Ornato encontrado.', MB_OK)
          end
        end
      }
      cmd_etiq.tooltip = 'Gerar etiquetas de producao'
      cmd_etiq.status_bar_text = 'Gera etiquetas para cada peca do modulo'
      cmd_etiq.small_icon = cmd_etiq.large_icon = icon_path('etiquetas')
      tb.add_item(cmd_etiq)

      # ─── Exportar JSON ───
      cmd_export = UI::Command.new('Exportar JSON') {
        Engines::MotorExport.mostrar_dialog_exportacao
      }
      cmd_export.tooltip = 'Exportar JSON para producao (compativel UpMobb)'
      cmd_export.status_bar_text = 'Exporta JSON com pecas, fitas, ferragens e usinagens'
      cmd_export.small_icon = cmd_export.large_icon = icon_path('exportar')
      tb.add_item(cmd_export)

      # ─── Validar ───
      cmd_validar = UI::Command.new('Validar') {
        sel = Sketchup.active_model.selection
        if sel.length == 1 && Utils.modulo_ornato?(sel.first)
          mi = Models::ModuloInfo.carregar_do_grupo(sel.first)
          if mi
            texto = Engines::MotorValidacao.relatorio(mi)
            ::UI.messagebox(texto, MB_MULTILINE)
          end
        else
          ::UI.messagebox('Selecione um modulo Ornato para validar.', MB_OK)
        end
      }
      cmd_validar.tooltip = 'Validar engenharia do modulo'
      cmd_validar.status_bar_text = 'Verifica regras de engenharia e sugere correcoes'
      cmd_validar.small_icon = cmd_validar.large_icon = icon_path('validar')
      tb.add_item(cmd_validar)

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
