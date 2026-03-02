# ornato_plugin/context_menu.rb — Menu de contexto (right-click) em módulos Ornato
# Adiciona opções inteligentes ao clicar com botão direito em um módulo

module Ornato
  module ContextMenu

    def self.setup
      ::UI.add_context_menu_handler do |context_menu|
        sel = Sketchup.active_model.selection

        # ═══════════════════════════════════════════════
        # MENU PARA MÓDULO ORNATO SELECIONADO
        # ═══════════════════════════════════════════════
        if sel.length == 1 && Utils.modulo_ornato?(sel.first)
          grupo = sel.first
          mi = Models::ModuloInfo.carregar_do_grupo(grupo)
          next unless mi

          ornato_menu = context_menu.add_submenu("Ornato: #{mi.nome}")

          # ── Propriedades ──
          ornato_menu.add_item('Propriedades do Modulo') do
            Ornato.propriedades.mostrar(grupo)
          end

          ornato_menu.add_separator

          # ── Agregados ── submenu
          agreg_menu = ornato_menu.add_submenu('Adicionar Agregado')

          agreg_menu.add_item('Porta') do
            Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:porta))
          end

          agreg_menu.add_item('Porta Dupla') do
            Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:porta_dupla))
          end

          agreg_menu.add_item('Gaveta') do
            Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:gaveta))
          end

          agreg_menu.add_item('Prateleira') do
            Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:prateleira))
          end

          agreg_menu.add_item('Divisoria') do
            Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:divisoria))
          end

          # ── Portas Especiais ── submenu
          portas_menu = ornato_menu.add_submenu('Porta Especial')
          Engines::MotorPortas::TIPOS_PORTA.each do |tipo, info|
            next if tipo == :cego
            portas_menu.add_item(info[:nome]) do
              Sketchup.active_model.select_tool(Tools::AgregadoTool.new(:porta_especial, tipo))
            end
          end

          ornato_menu.add_separator

          # ── Vão ── subdivisão
          vao_menu = ornato_menu.add_submenu('Dividir Vao')

          vao_menu.add_item('Dividir Horizontal (lado a lado)') do
            dividir_vao_dialog(mi, grupo, :horizontal)
          end

          vao_menu.add_item('Dividir Vertical (empilhar)') do
            dividir_vao_dialog(mi, grupo, :vertical)
          end

          ornato_menu.add_separator

          # ── Informações / Relatórios ──
          info_menu = ornato_menu.add_submenu('Relatorios')

          info_menu.add_item('Lista de Pecas') do
            texto = gerar_lista_pecas(mi)
            ::UI.messagebox(texto, MB_MULTILINE)
          end

          info_menu.add_item('Ficha Tecnica') do
            ficha = Engines::MotorFichaTecnica.gerar_ficha(mi)
            html = Engines::MotorFichaTecnica.gerar_html_ficha(ficha, formato: :completa)
            MenuSetup.mostrar_html('Ficha Tecnica', html, 800, 1000)
          end

          info_menu.add_item('Etiquetas de Producao') do
            etiquetas = Engines::MotorEtiquetas.gerar_etiquetas(mi)
            html = Engines::MotorEtiquetas.gerar_html_etiquetas(etiquetas, formato: :folha)
            MenuSetup.mostrar_html('Etiquetas', html, 800, 1000)
          end

          info_menu.add_separator

          info_menu.add_item('Mapa de Furacao') do
            furos = Engines::MotorFuracao.gerar_mapa(mi)
            texto = Engines::MotorFuracao.relatorio_texto(furos)
            ::UI.messagebox(texto, MB_MULTILINE)
          end

          info_menu.add_item('Usinagens CNC') do
            usinagens = Engines::MotorUsinagem.gerar_usinagens_modulo(mi)
            texto = Engines::MotorUsinagem.relatorio_texto(usinagens)
            ::UI.messagebox(texto, MB_MULTILINE)
          end

          info_menu.add_item('Fita de Borda') do
            texto = Engines::MotorFitaBorda.relatorio_texto(mi)
            ::UI.messagebox(texto, MB_MULTILINE)
          end

          info_menu.add_item('Orcamento Modulo') do
            custo = Engines::MotorPrecificacao.calcular_modulo(mi)
            texto = formatar_orcamento_modulo(mi, custo)
            ::UI.messagebox(texto, MB_MULTILINE)
          end

          info_menu.add_separator

          info_menu.add_item('Validar Engenharia') do
            texto = Engines::MotorValidacao.relatorio(mi)
            ::UI.messagebox(texto, MB_MULTILINE)
          end

          info_menu.add_item('Sugerir Ferragens') do
            sugestao = Engines::MotorInteligencia.sugerir_configuracao(mi)
            texto = Engines::MotorInteligencia.relatorio_texto(sugestao)
            ::UI.messagebox(texto, MB_MULTILINE)
          end

          ornato_menu.add_separator

          # ── Alinhamento ──
          alinhar_menu = ornato_menu.add_submenu('Alinhar / Distribuir')

          alinhar_menu.add_item('Alinhar Horizontal (lado a lado)') do
            Engines::MotorAlinhamento.alinhar_horizontal
          end

          alinhar_menu.add_item('Alinhar Profundidade') do
            Engines::MotorAlinhamento.alinhar_profundidade
          end

          alinhar_menu.add_item('Alinhar Altura') do
            Engines::MotorAlinhamento.alinhar_altura
          end

          alinhar_menu.add_item('Empilhar Vertical') do
            Engines::MotorAlinhamento.empilhar_vertical
          end

          alinhar_menu.add_item('Distribuir c/ 3mm espaco') do
            Engines::MotorAlinhamento.distribuir_horizontal(nil, 3)
          end

          alinhar_menu.add_item('Espelhar') do
            Engines::MotorAlinhamento.espelhar
          end

          ornato_menu.add_separator

          # ── Exportar JSON ──
          ornato_menu.add_item('Exportar JSON (UpMobb)') do
            Engines::MotorExport.exportar_modulo(grupo)
          end

          ornato_menu.add_separator

          # ── Ações ──
          ornato_menu.add_item('Salvar como Template') do
            salvar_template_dialog(mi, grupo)
          end

          ornato_menu.add_item('Duplicar Modulo') do
            duplicar_modulo(grupo)
          end

          ornato_menu.add_item('Editar Dimensoes') do
            editar_dimensoes_dialog(mi, grupo)
          end

          ornato_menu.add_item('Trocar Material') do
            trocar_material_dialog(mi, grupo)
          end

          ornato_menu.add_separator

          # ── Cotagem ──
          cotas_menu = ornato_menu.add_submenu('Cotagem')

          cotas_menu.add_item('Cotar Externas') do
            Engines::MotorCotagem.cotar_modulo(grupo, externas: true, internas: false)
          end

          cotas_menu.add_item('Cotar Externas + Internas') do
            Engines::MotorCotagem.cotar_modulo(grupo, externas: true, internas: true)
          end

          cotas_menu.add_item('Cotar Pecas') do
            Engines::MotorCotagem.cotar_pecas(grupo)
          end

          cotas_menu.add_item('Remover Cotas') do
            Engines::MotorCotagem.remover_cotas(grupo)
          end

        # ═══════════════════════════════════════════════
        # MENU PARA PEÇA ORNATO (sub-grupo com DICT_PECA)
        # ═══════════════════════════════════════════════
        elsif sel.length == 1 && Utils.peca_ornato?(sel.first) && !Utils.modulo_ornato?(sel.first)
          peca_grupo = sel.first
          peca_info = Utils.info_peca(peca_grupo)
          next unless peca_info

          peca_menu = context_menu.add_submenu("Ornato Peca: #{peca_info[:nome]}")

          peca_menu.add_item('Visualizar Usinagens') do
            painel_usi = UI::PainelUsinagem.new
            painel_usi.mostrar(peca_grupo, nil)
          end

          peca_menu.add_item('Adicionar Usinagem...') do
            Sketchup.active_model.select_tool(Tools::UsinagemAvulsaTool.new)
          end

          peca_menu.add_separator

          peca_menu.add_item('Reconfigurar Peca...') do
            Sketchup.active_model.select_tool(Tools::TransformarPecaTool.new)
          end

          peca_menu.add_separator

          peca_menu.add_item('Info da Peca') do
            info = Utils.info_peca(peca_grupo)
            if info
              texto = "=== PECA: #{info[:nome]} ===\n\n"
              texto += "Tipo: #{info[:tipo]}\n"
              texto += "Dimensoes: #{info[:comprimento]}x#{info[:largura]}x#{info[:espessura]}mm\n"
              texto += "Material: #{info[:material]}\n"
              texto += "Origem: #{info[:origem]}\n"
              texto += "Usinagens: #{info[:usinagens]}\n"

              contorno = Utils.get_attr(peca_grupo, Config::DICT_PECA, 'tem_contorno')
              texto += "Contorno: #{contorno ? 'Especial' : 'Retangular'}\n"

              ::UI.messagebox(texto, MB_MULTILINE)
            end
          end

          peca_menu.add_item('Remover Identificacao Ornato') do
            resp = ::UI.messagebox("Remover atributos Ornato de '#{peca_info[:nome]}'?", MB_YESNO)
            if resp == IDYES
              model = Sketchup.active_model
              model.start_operation('Remover Identificacao Ornato', true)
              begin
                dict = peca_grupo.attribute_dictionary(Config::DICT_PECA)
                peca_grupo.delete_attribute(Config::DICT_PECA) if dict
                model.commit_operation
                ::UI.messagebox('Identificacao removida.')
              rescue => e
                model.abort_operation
                ::UI.messagebox("Erro: #{e.message}")
              end
            end
          end

        # ═══════════════════════════════════════════════
        # MENU PARA GRUPO/FACE NÃO IDENTIFICADO
        # ═══════════════════════════════════════════════
        elsif sel.length == 1 && (sel.first.is_a?(Sketchup::Group) || sel.first.is_a?(Sketchup::ComponentInstance)) && !Utils.modulo_ornato?(sel.first) && !Utils.peca_ornato?(sel.first)
          entity = sel.first
          context_menu.add_item('Ornato: Transformar em Peca...') do
            Sketchup.active_model.select_tool(Tools::TransformarPecaTool.new)
          end

        # ═══════════════════════════════════════════════
        # MENU PARA MÚLTIPLOS MÓDULOS SELECIONADOS
        # ═══════════════════════════════════════════════
        elsif sel.length > 1
          modulos = sel.to_a.select { |e| Utils.modulo_ornato?(e) }
          if modulos.length >= 2
            multi_menu = context_menu.add_submenu("Ornato: #{modulos.length} modulos")

            multi_menu.add_item('Alinhar Horizontal') do
              Engines::MotorAlinhamento.alinhar_horizontal(modulos)
            end

            multi_menu.add_item('Alinhar Profundidade') do
              Engines::MotorAlinhamento.alinhar_profundidade(modulos)
            end

            multi_menu.add_item('Alinhar Altura') do
              Engines::MotorAlinhamento.alinhar_altura(modulos)
            end

            multi_menu.add_item('Empilhar Vertical') do
              Engines::MotorAlinhamento.empilhar_vertical(modulos)
            end

            multi_menu.add_item('Distribuir c/ 3mm') do
              Engines::MotorAlinhamento.distribuir_horizontal(modulos, 3)
            end

            multi_menu.add_separator

            multi_menu.add_item('Orcamento Selecionados') do
              orcamento_multiplos(modulos)
            end
          end
        end
      end
    end

    private

    # ── Diálogo para dividir vão ──
    def self.dividir_vao_dialog(mi, grupo, direcao)
      prompts = ['Quantidade de divisoes']
      defaults = ['2']
      result = ::UI.inputbox(prompts, defaults, 'Dividir Vao')
      return unless result

      qtd = result[0].to_i
      return ::UI.messagebox('Quantidade deve ser >= 2') if qtd < 2

      begin
        vao = mi.vao_raiz
        if direcao == :horizontal
          vao.dividir_horizontal(qtd)
        else
          vao.dividir_vertical(qtd)
        end
        ::UI.messagebox("Vao dividido em #{qtd} partes (#{direcao}).")
      rescue => e
        ::UI.messagebox("Erro ao dividir vao: #{e.message}")
      end
    end

    # ── Lista de peças formatada ──
    def self.gerar_lista_pecas(mi)
      linhas = ["═══ LISTA DE PECAS: #{mi.nome} ═══\n"]
      linhas << "Modulo: #{mi.largura}x#{mi.altura}x#{mi.profundidade}mm"
      linhas << "Material corpo: #{mi.material_corpo}"
      linhas << "Material frente: #{mi.material_frente}\n"

      mi.pecas.each_with_index do |p, i|
        qtd = p.quantidade || 1
        linhas << "#{i + 1}. #{p.nome} (#{qtd}x)"
        linhas << "   #{p.comprimento.round(1)} x #{p.largura.round(1)} x #{p.espessura}mm"
        linhas << "   Material: #{p.material}"

        fitas = []
        fitas << 'F' if p.fita_frente
        fitas << 'T' if p.fita_topo
        fitas << 'TR' if p.fita_tras
        fitas << 'B' if p.fita_base
        linhas << "   Fita: #{fitas.any? ? fitas.join('+') : 'nenhuma'}"
      end

      if mi.ferragens.any?
        linhas << "\n── FERRAGENS ──"
        mi.ferragens.each do |f|
          linhas << "  - #{f[:nome]} (#{f[:qtd]}x)"
        end
      end

      linhas << "\n═══ Total: #{mi.pecas.length} pecas, #{mi.ferragens.length} ferragens ═══"
      linhas.join("\n")
    end

    # ── Orçamento formatado de um módulo ──
    def self.formatar_orcamento_modulo(mi, custo)
      linhas = ["═══ ORCAMENTO: #{mi.nome} ═══\n"]
      linhas << "Material:  R$ #{custo[:material].round(2)}"
      linhas << "Fita:      R$ #{custo[:fita].round(2)}"
      linhas << "Ferragens: R$ #{custo[:ferragens].round(2)}"
      linhas << "Usinagem:  R$ #{custo[:usinagem].round(2)}"
      linhas << "Mao obra:  R$ #{custo[:mao_obra].round(2)}"
      linhas << "─────────────────────"
      linhas << "Custo:     R$ #{custo[:total_custo].round(2)}"
      linhas << "Venda:     R$ #{custo[:total_venda].round(2)}"
      linhas << "(margem #{Engines::MotorPrecificacao::MARGEM_PADRAO}%)"
      linhas.join("\n")
    end

    # ── Orçamento de múltiplos módulos ──
    def self.orcamento_multiplos(modulos)
      total_custo = 0.0
      total_venda = 0.0
      linhas = ["═══ ORCAMENTO SELECIONADOS ═══\n"]

      modulos.each do |grupo|
        mi = Models::ModuloInfo.carregar_do_grupo(grupo)
        next unless mi
        custo = Engines::MotorPrecificacao.calcular_modulo(mi)
        total_custo += custo[:total_custo]
        total_venda += custo[:total_venda]
        linhas << "#{mi.nome}: R$ #{custo[:total_venda].round(2)}"
      end

      linhas << "\n─────────────────────"
      linhas << "Total Custo: R$ #{total_custo.round(2)}"
      linhas << "Total Venda: R$ #{total_venda.round(2)}"
      ::UI.messagebox(linhas.join("\n"), MB_MULTILINE)
    end

    # ── Salvar como template ──
    def self.salvar_template_dialog(mi, grupo)
      prompts = ['Nome do Template', 'Categoria']
      defaults = [mi.nome, 'customizado']
      listas = ['', 'cozinha|quarto|banheiro|escritorio|sala|lavanderia|customizado']
      result = ::UI.inputbox(prompts, defaults, listas, 'Salvar Template')
      return unless result

      begin
        Engines::MotorTemplates.salvar_template(grupo, result[0], result[1])
        ::UI.messagebox("Template '#{result[0]}' salvo com sucesso!")
      rescue => e
        ::UI.messagebox("Erro ao salvar template: #{e.message}")
      end
    end

    # ── Duplicar módulo ──
    def self.duplicar_modulo(grupo)
      model = Sketchup.active_model
      model.start_operation('Duplicar Modulo Ornato', true)

      begin
        tr = grupo.transformation
        # Posiciona a cópia ao lado (deslocamento = largura + 30mm)
        bb = grupo.bounds
        offset_x = bb.width + 30.mm
        novo_tr = Geom::Transformation.new([tr.origin.x + offset_x, tr.origin.y, tr.origin.z])

        novo = model.active_entities.add_instance(grupo.definition, novo_tr)
        novo.make_unique if novo.respond_to?(:make_unique)
        model.commit_operation
        ::UI.messagebox('Modulo duplicado com sucesso!')
      rescue => e
        model.abort_operation
        ::UI.messagebox("Erro ao duplicar: #{e.message}")
      end
    end

    # ── Editar dimensões ──
    def self.editar_dimensoes_dialog(mi, grupo)
      prompts = ['Largura (mm)', 'Altura (mm)', 'Profundidade (mm)']
      defaults = [mi.largura.to_s, mi.altura.to_s, mi.profundidade.to_s]
      result = ::UI.inputbox(prompts, defaults, 'Editar Dimensoes')
      return unless result

      nova_l = result[0].to_f
      nova_a = result[1].to_f
      nova_p = result[2].to_f

      if nova_l < 100 || nova_a < 100 || nova_p < 100
        return ::UI.messagebox('Dimensoes minimas: 100mm')
      end

      begin
        model = Sketchup.active_model
        model.start_operation('Redimensionar Modulo', true)

        # Escala proporcional
        sx = nova_l / mi.largura
        sy = nova_p / mi.profundidade
        sz = nova_a / mi.altura

        tr_scale = Geom::Transformation.scaling(grupo.transformation.origin, sx, sy, sz)
        grupo.transformation = tr_scale

        # Atualiza atributos
        grupo.set_attribute(Config::DICT_MODULO, 'largura', nova_l)
        grupo.set_attribute(Config::DICT_MODULO, 'altura', nova_a)
        grupo.set_attribute(Config::DICT_MODULO, 'profundidade', nova_p)

        model.commit_operation
        ::UI.messagebox("Redimensionado para #{nova_l}x#{nova_a}x#{nova_p}mm")
      rescue => e
        model.abort_operation
        ::UI.messagebox("Erro: #{e.message}")
      end
    end

    # ── Trocar material ──
    def self.trocar_material_dialog(mi, grupo)
      materiais = Models::BibliotecaMateriais.listar
      nomes = materiais.map { |m| m[:nome] }

      prompts = ['Material Corpo', 'Material Frente']
      defaults = [mi.material_corpo, mi.material_frente]
      listas = [nomes.join('|'), nomes.join('|')]
      result = ::UI.inputbox(prompts, defaults, listas, 'Trocar Material')
      return unless result

      begin
        model = Sketchup.active_model
        model.start_operation('Trocar Material', true)

        grupo.set_attribute(Config::DICT_MODULO, 'material_corpo', result[0])
        grupo.set_attribute(Config::DICT_MODULO, 'material_frente', result[1])

        # Aplica material visual
        mat_corpo = Models::BibliotecaMateriais.buscar(result[0])
        if mat_corpo
          cor = Sketchup::Color.new(mat_corpo[:cor_r], mat_corpo[:cor_g], mat_corpo[:cor_b])
          material_su = Utils.criar_material(model, "Ornato_#{result[0]}", cor)
          grupo.material = material_su
        end

        model.commit_operation
        ::UI.messagebox("Material alterado: corpo=#{result[0]}, frente=#{result[1]}")
      rescue => e
        model.abort_operation
        ::UI.messagebox("Erro: #{e.message}")
      end
    end
  end
end
