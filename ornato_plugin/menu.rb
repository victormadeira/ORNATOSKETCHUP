# ornato_plugin/menu.rb — Menu completo no SketchUp

module Ornato
  module MenuSetup
    def self.criar
      menu = ::UI.menu('Plugins').add_submenu(PLUGIN_NAME)

      # ─── Criar ───
      menu.add_item('Nova Caixa') {
        Sketchup.active_model.select_tool(Tools::CaixaTool.new)
      }

      # ─── Templates ───
      sub_templates = menu.add_submenu('Templates')
      sub_templates.add_item('Catalogo Completo...') {
        Sketchup.active_model.select_tool(Tools::TemplateTool.new)
      }
      sub_templates.add_separator

      # Sub-menus por categoria
      categorias_templates.each do |cat, templates|
        sub_cat = sub_templates.add_submenu(cat)
        templates.each do |id, tmpl|
          sub_cat.add_item(tmpl[:nome]) {
            Sketchup.active_model.select_tool(Tools::TemplateTool.new(id))
          }
        end
      end

      menu.add_separator

      # ─── Agregados ───
      sub_agreg = menu.add_submenu('Agregados')
      sub_agreg.add_item('Porta')       { Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:porta)) }
      sub_agreg.add_item('Porta Dupla') { Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:porta_dupla)) }
      sub_agreg.add_item('Gaveta')      { Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:gaveta)) }
      sub_agreg.add_item('Prateleira')  { Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:prateleira)) }
      sub_agreg.add_item('Divisoria')   { Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:divisoria)) }

      # ─── Portas Especiais ───
      sub_portas = menu.add_submenu('Portas Especiais')
      Engines::MotorPortas::TIPOS_PORTA.each do |tipo, info|
        sub_portas.add_item(info[:nome]) {
          Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:porta_especial, tipo))
        }
      end

      # ─── Pecas Avulsas ───
      sub_pecas = menu.add_submenu('Pecas Avulsas')
      sub_pecas.add_item('Tampo / Bancada')    { Sketchup.active_model.select_tool(Tools::PecasAvulsasTool.new(:tampo)) }
      sub_pecas.add_item('Rodape')             { Sketchup.active_model.select_tool(Tools::PecasAvulsasTool.new(:rodape)) }
      sub_pecas.add_item('Requadro')           { Sketchup.active_model.select_tool(Tools::PecasAvulsasTool.new(:requadro)) }
      sub_pecas.add_item('Painel Lateral')     { Sketchup.active_model.select_tool(Tools::PecasAvulsasTool.new(:painel_lateral)) }
      sub_pecas.add_item('Painel Cavilhado')   { Sketchup.active_model.select_tool(Tools::PecasAvulsasTool.new(:painel_cavilhado)) }
      sub_pecas.add_item('Moldura / Cornija')  { Sketchup.active_model.select_tool(Tools::PecasAvulsasTool.new(:moldura)) }
      sub_pecas.add_item('Canaleta LED')       { Sketchup.active_model.select_tool(Tools::PecasAvulsasTool.new(:canaleta_led)) }

      menu.add_separator

      # ─── Edicao ───
      menu.add_item('Editar Modulo') {
        Sketchup.active_model.select_tool(Tools::EditorTool.new)
      }

      menu.add_item('Propriedades...') {
        sel = Sketchup.active_model.selection
        if sel.length == 1 && Utils.modulo_ornato?(sel.first)
          UI::Propriedades.mostrar(sel.first)
        else
          ::UI.messagebox('Selecione um modulo Ornato primeiro.', MB_OK)
        end
      }

      menu.add_item('Salvar como Template...') {
        sel = Sketchup.active_model.selection
        if sel.length == 1 && Utils.modulo_ornato?(sel.first)
          salvar_modulo_como_template(sel.first)
        else
          ::UI.messagebox('Selecione um modulo Ornato para salvar como template.', MB_OK)
        end
      }

      menu.add_separator

      # ─── Alinhamento ───
      sub_alinhar = menu.add_submenu('Alinhar / Distribuir')
      sub_alinhar.add_item('Alinhar Horizontalmente') { Engines::MotorAlinhamento.alinhar_horizontal }
      sub_alinhar.add_item('Alinhar Profundidade') { Engines::MotorAlinhamento.alinhar_profundidade }
      sub_alinhar.add_item('Alinhar Altura') { Engines::MotorAlinhamento.alinhar_altura }
      sub_alinhar.add_item('Empilhar Vertical') { Engines::MotorAlinhamento.empilhar_vertical }
      sub_alinhar.add_separator
      sub_alinhar.add_item('Distribuir (sem espaco)') { Engines::MotorAlinhamento.distribuir_horizontal(nil, 0) }
      sub_alinhar.add_item('Distribuir (3mm)') { Engines::MotorAlinhamento.distribuir_horizontal(nil, 3) }
      sub_alinhar.add_item('Espelhar Modulo') {
        sel = Sketchup.active_model.selection
        if sel.length == 1 && Utils.modulo_ornato?(sel.first)
          Engines::MotorAlinhamento.espelhar(sel.first)
        else
          ::UI.messagebox('Selecione um modulo Ornato para espelhar.', MB_OK)
        end
      }

      menu.add_separator

      # ─── Painel ───
      menu.add_item('Painel Ornato') { Ornato.mostrar_painel }

      menu.add_separator

      # ─── Exportar ───
      sub_export = menu.add_submenu('Exportar')
      sub_export.add_item('Lista de Corte (CSV)') { exportar_lista_corte }
      sub_export.add_item('Plano de Corte Otimizado') { exportar_plano_corte }
      sub_export.add_item('Sequencia Esquadrejadeira') { exportar_sequencia_esquadrejadeira }
      sub_export.add_separator
      sub_export.add_item('Mapa de Furacao') { exportar_mapa_furacao }
      sub_export.add_item('Lista de Ferragens') { exportar_lista_ferragens }
      sub_export.add_item('Resumo Fita de Borda') { exportar_resumo_fita }
      sub_export.add_item('Resumo de Usinagens') { exportar_resumo_usinagens }
      sub_export.add_separator
      sub_export.add_item('Orcamento Completo') { exportar_orcamento }
      sub_export.add_item('Orcamento (CSV)') { exportar_orcamento_csv }
      sub_export.add_separator
      sub_export.add_item('Exportar XML (OpenCutList)') { exportar_xml_opencutlist }
      sub_export.add_item('Exportar Corte Certo') { exportar_corte_certo }

      menu.add_separator
      menu.add_item('Sobre') { mostrar_sobre }
    end

    # ═══ Helpers ═══

    def self.categorias_templates
      result = {}
      Engines::MotorTemplates::CATALOGO.each do |id, tmpl|
        cat = tmpl[:categoria].to_s.capitalize
        result[cat] ||= {}
        result[cat][id] = tmpl
      end
      result
    end

    def self.salvar_modulo_como_template(grupo)
      prompts = ['Nome do Template', 'Categoria']
      defaults = ['Meu Template', 'Customizado']
      lists = ['', 'Customizado|Cozinha|Quarto|Banheiro|Escritorio|Sala|Lavanderia']

      result = ::UI.inputbox(prompts, defaults, lists, 'Salvar Template')
      return unless result

      nome, categoria = result
      id = Engines::MotorTemplates.salvar_template(grupo, nome, categoria.downcase.to_sym)
      if id
        ::UI.messagebox("Template '#{nome}' salvo com sucesso!\nID: #{id}", MB_OK)
      else
        ::UI.messagebox("Erro ao salvar template.", MB_OK)
      end
    end

    # ═══ Exportacoes ═══

    def self.verificar_modulos
      modulos = Utils.listar_modulos
      if modulos.empty?
        ::UI.messagebox('Nenhum modulo Ornato encontrado no modelo.', MB_OK)
        return nil
      end
      modulos
    end

    def self.exportar_lista_corte
      modulos = verificar_modulos
      return unless modulos

      path = ::UI.savepanel('Salvar Lista de Corte', '', 'lista_corte.csv')
      return unless path

      File.open(path, 'w') do |f|
        f.puts '#,Peca,Comprimento,Largura,Esp,Qtd,Material,Fita,Fita(m),Modulo,Ambiente'
        num = 0
        modulos.each do |grupo|
          mi = Models::ModuloInfo.carregar_do_grupo(grupo)
          next unless mi
          mi.pecas.each do |peca|
            num += 1
            f.puts "#{num},#{peca.nome},#{peca.comprimento},#{peca.largura},#{peca.espessura},#{peca.quantidade},#{peca.material},#{peca.fita_codigo},#{peca.fita_metros.round(3)},#{mi.nome},#{mi.ambiente}"
          end
        end
      end
      ::UI.messagebox("Lista de corte exportada:\n#{path}", MB_OK)
    end

    def self.exportar_plano_corte
      modulos = verificar_modulos
      return unless modulos

      prompts = ['Chapa', 'Margem Serra (mm)', 'Margem Refilo (mm)']
      defaults = ['2750x1850', '4', '10']
      chapa_opts = Engines::MotorPlanoCorte::CHAPAS_PADRAO.keys.join('|')
      lists = [chapa_opts, '', '']

      result = ::UI.inputbox(prompts, defaults, lists, 'Plano de Corte')
      return unless result

      chapa_id, margem_serra, margem_refilo = result

      path = ::UI.savepanel('Salvar Plano de Corte', '', 'plano_corte.csv')
      return unless path

      pecas = Engines::MotorPlanoCorte.coletar_pecas_projeto
      plano = Engines::MotorPlanoCorte.otimizar_corte(pecas, chapa_id)
      Engines::MotorPlanoCorte.exportar_csv(plano, path)

      resumo = Engines::MotorPlanoCorte.gerar_resumo_texto(plano)
      ::UI.messagebox("Plano de corte exportado!\n\n#{resumo}", MB_OK)
    end

    def self.exportar_sequencia_esquadrejadeira
      modulos = verificar_modulos
      return unless modulos

      path = ::UI.savepanel('Salvar Sequencia Esquadrejadeira', '', 'esquadrejadeira.txt')
      return unless path

      pecas = Engines::MotorPlanoCorte.coletar_pecas_projeto
      plano = Engines::MotorPlanoCorte.otimizar_corte(pecas)
      Engines::MotorPlanoCorte.exportar_esquadrejadeira(plano, path)

      ::UI.messagebox("Sequencia de cortes exportada:\n#{path}", MB_OK)
    end

    def self.exportar_mapa_furacao
      modulos = verificar_modulos
      return unless modulos

      path = ::UI.savepanel('Salvar Mapa de Furacao', '', 'furacao.csv')
      return unless path

      File.open(path, 'w') do |f|
        f.puts '#,Modulo,Peca,Tipo Furo,X,Y,Diametro,Profundidade,Face'
        num = 0
        modulos.each do |grupo|
          mi = Models::ModuloInfo.carregar_do_grupo(grupo)
          next unless mi
          mapa = Engines::MotorFuracao.gerar_mapa(mi)
          mapa.each do |peca_nome, furos|
            furos.each do |furo|
              num += 1
              f.puts "#{num},#{mi.nome},#{peca_nome},#{furo.tipo},#{furo.x.round(1)},#{furo.y.round(1)},#{furo.diametro},#{furo.profundidade},#{furo.face}"
            end
          end
        end
      end
      ::UI.messagebox("Mapa de furacao exportado:\n#{path}", MB_OK)
    end

    def self.exportar_lista_ferragens
      modulos = verificar_modulos
      return unless modulos

      path = ::UI.savepanel('Salvar Lista de Ferragens', '', 'ferragens.csv')
      return unless path

      consolidado = {}
      modulos.each do |grupo|
        mi = Models::ModuloInfo.carregar_do_grupo(grupo)
        next unless mi
        mi.ferragens.each do |f|
          key = f[:nome]
          consolidado[key] ||= { nome: f[:nome], tipo: f[:tipo], qtd: 0 }
          consolidado[key][:qtd] += f[:qtd]
        end
      end

      File.open(path, 'w') do |f|
        f.puts '#,Descricao,Tipo,Qtd'
        consolidado.values.each_with_index do |item, i|
          f.puts "#{i + 1},#{item[:nome]},#{item[:tipo]},#{item[:qtd]}"
        end
      end
      ::UI.messagebox("Lista de ferragens exportada:\n#{path}", MB_OK)
    end

    def self.exportar_resumo_fita
      modulos = verificar_modulos
      return unless modulos

      relatorio = Engines::MotorFitaBorda.relatorio_projeto
      msg = "RESUMO FITA DE BORDA\n\n"
      relatorio.each do |tipo, metros|
        msg += "#{tipo}: #{metros.round(2)}m\n"
      end
      msg += "\nTotal: #{relatorio.values.sum.round(2)}m"
      ::UI.messagebox(msg, MB_OK)
    end

    def self.exportar_resumo_usinagens
      modulos = verificar_modulos
      return unless modulos

      path = ::UI.savepanel('Salvar Resumo de Usinagens', '', 'usinagens.csv')
      return unless path

      File.open(path, 'w') do |f|
        f.puts '#,Modulo,Peca,Tipo Usinagem,Descricao,X,Y,Largura,Altura,Prof,Face,Ferramenta'
        num = 0
        modulos.each do |grupo|
          mi = Models::ModuloInfo.carregar_do_grupo(grupo)
          next unless mi
          usinagens = Engines::MotorUsinagem.gerar_usinagens_modulo(mi)
          usinagens.each do |u|
            num += 1
            f.puts "#{num},#{mi.nome},#{u.peca || ''},#{u.tipo},#{u.descricao || ''},#{u.x.round(1)},#{u.y.round(1)},#{u.largura.round(1)},#{u.altura.round(1)},#{u.profundidade.round(1)},#{u.face || ''},#{u.ferramenta || ''}"
          end
        end
      end
      ::UI.messagebox("Resumo de usinagens exportado:\n#{path}", MB_OK)
    end

    def self.exportar_xml_opencutlist
      modulos = verificar_modulos
      return unless modulos

      path = ::UI.savepanel('Exportar XML (OpenCutList)', '', 'ornato_opencutlist.xml')
      return unless path

      pecas = Engines::MotorPlanoCorte.coletar_pecas_projeto
      plano = Engines::MotorPlanoCorte.otimizar_corte(pecas)
      Engines::MotorPlanoCorte.exportar_xml(plano, path)

      ::UI.messagebox("Arquivo XML exportado:\n#{path}", MB_OK)
    end

    def self.exportar_corte_certo
      modulos = verificar_modulos
      return unless modulos

      path = ::UI.savepanel('Exportar Corte Certo', '', 'ornato_cortecerto.txt')
      return unless path

      pecas = Engines::MotorPlanoCorte.coletar_pecas_projeto
      plano = Engines::MotorPlanoCorte.otimizar_corte(pecas)
      Engines::MotorPlanoCorte.exportar_corte_certo(plano, path)

      ::UI.messagebox("Arquivo Corte Certo exportado:\n#{path}", MB_OK)
    end

    def self.exportar_orcamento
      modulos = verificar_modulos
      return unless modulos

      texto = Engines::MotorPrecificacao.gerar_orcamento_texto
      ::UI.messagebox(texto, MB_MULTILINE)
    end

    def self.exportar_orcamento_csv
      modulos = verificar_modulos
      return unless modulos

      path = ::UI.savepanel('Salvar Orcamento', '', 'orcamento.csv')
      return unless path

      Engines::MotorPrecificacao.exportar_csv(path)
      ::UI.messagebox("Orcamento exportado:\n#{path}", MB_OK)
    end

    def self.mostrar_sobre
      ::UI.messagebox(
        "#{PLUGIN_NAME} v#{PLUGIN_VERSION}\n\n" \
        "Plugin de marcenaria parametrica para SketchUp\n\n" \
        "Recursos:\n" \
        "- Caixas parametricas com montagem Brasil/Europa\n" \
        "- 9 tipos de portas (lisa, provencal, vidro, veneziana...)\n" \
        "- Gavetas com 4 tipos de corredica (Blum specs)\n" \
        "- #{Engines::MotorTemplates::CATALOGO.size} templates pre-configurados\n" \
        "- Plano de corte otimizado + esquadrejadeira\n" \
        "- Motor de usinagem CNC completo\n" \
        "- Fita de borda inteligente\n" \
        "- Pecas avulsas (tampo, painel cavilhado...)\n" \
        "- Integracao Ornato ERP\n\n" \
        "2026 Ornato",
        MB_OK
      )
    end
  end

  MenuSetup.criar unless file_loaded?(File.join(PLUGIN_DIR, 'menu.rb'))
  file_loaded(File.join(PLUGIN_DIR, 'menu.rb'))
end
