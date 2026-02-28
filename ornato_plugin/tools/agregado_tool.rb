# ornato_plugin/tools/agregado_tool.rb — Ferramenta de mira para adicionar agregados

module Ornato
  module Tools
    class AgregadoTool
      def initialize(tipo_agregado, subtipo = nil)
        @tipo = tipo_agregado  # :porta, :porta_dupla, :gaveta, :prateleira, :divisoria, :porta_especial
        @subtipo = subtipo     # tipo de porta especial (ex: :provencal, :vidro, etc.)
        @modulo_alvo = nil
        @vao_alvo = nil
        @mouse_ip = nil
        @highlight_vao = nil
      end

      def activate
        Sketchup.status_text = "Ornato [#{nome_tipo}]: Passe o cursor sobre um modulo e clique no vao desejado"
      end

      def deactivate(view)
        view.invalidate
      end

      def onMouseMove(flags, x, y, view)
        @mouse_ip = Sketchup::InputPoint.new
        @mouse_ip.pick(view, x, y)

        ph = view.pick_helper
        ph.do_pick(x, y)
        entity = ph.best_picked

        @modulo_alvo = nil
        @vao_alvo = nil

        if entity
          grupo = encontrar_modulo_pai(entity)
          if grupo && Utils.modulo_ornato?(grupo)
            @modulo_alvo = grupo
            mi = Models::ModuloInfo.carregar_do_grupo(grupo)
            if mi && mi.vao_principal
              local_pt = grupo.transformation.inverse * @mouse_ip.position
              px = Utils.to_mm(local_pt.x)
              pz = Utils.to_mm(local_pt.z)

              @vao_alvo = mi.vao_principal.encontrar_vao(px, pz)
              @highlight_vao = @vao_alvo

              if @vao_alvo
                Sketchup.status_text = "Ornato [#{nome_tipo}]: Vao #{@vao_alvo.largura.round(0)}x#{@vao_alvo.altura.round(0)}mm — Clique para inserir"
              end
            end
          end
        end

        Sketchup.status_text = "Ornato [#{nome_tipo}]: Passe sobre um modulo Ornato" unless @modulo_alvo
        view.invalidate
      end

      def onLButtonDown(flags, x, y, view)
        return unless @modulo_alvo && @vao_alvo

        mi = Models::ModuloInfo.carregar_do_grupo(@modulo_alvo)
        return unless mi

        mi.grupo_ref = @modulo_alvo

        model = Sketchup.active_model
        model.start_operation("Ornato: Adicionar #{nome_tipo}", true)

        begin
          case @tipo
          when :porta
            mostrar_dialog_porta(mi, @vao_alvo)
          when :porta_dupla
            mostrar_dialog_porta_dupla(mi, @vao_alvo)
          when :porta_especial
            mostrar_dialog_porta_especial(mi, @vao_alvo, @subtipo)
          when :gaveta
            mostrar_dialog_gaveta(mi, @vao_alvo)
          when :prateleira
            mostrar_dialog_prateleira(mi, @vao_alvo)
          when :divisoria
            mostrar_dialog_divisoria(mi, @vao_alvo)
          end

          Ornato.painel.atualizar if Ornato.painel.visivel?

        rescue => e
          model.abort_operation
          puts "[Ornato] ERRO ao adicionar #{nome_tipo}: #{e.message}"
          puts e.backtrace.first(5).join("\n")
        end

        view.invalidate
      end

      def onKeyDown(key, repeat, flags, view)
        Sketchup.active_model.select_tool(nil) if key == VK_ESCAPE
      end

      def draw(view)
        return unless @modulo_alvo && @highlight_vao

        grupo = @modulo_alvo
        vao = @highlight_vao
        tr = grupo.transformation

        x1 = Utils.mm(vao.x)
        x2 = Utils.mm(vao.x + vao.largura)
        z1 = Utils.mm(vao.z)
        z2 = Utils.mm(vao.z + vao.altura)
        y  = Utils.mm(0)

        pts = [
          tr * Geom::Point3d.new(x1, y, z1),
          tr * Geom::Point3d.new(x2, y, z1),
          tr * Geom::Point3d.new(x2, y, z2),
          tr * Geom::Point3d.new(x1, y, z2)
        ]

        # Cor diferente por tipo de agregado
        cor = case @tipo
              when :porta, :porta_dupla, :porta_especial
                Sketchup::Color.new(230, 126, 34, 80)
              when :gaveta
                Sketchup::Color.new(52, 152, 219, 80)
              when :prateleira
                Sketchup::Color.new(46, 204, 113, 80)
              when :divisoria
                Sketchup::Color.new(155, 89, 182, 80)
              else
                Config::COR_HIGHLIGHT
              end

        view.drawing_color = cor
        view.draw(GL_QUADS, pts)

        view.drawing_color = Sketchup::Color.new(cor.red, cor.green, cor.blue, 255)
        view.line_width = 2
        view.draw(GL_LINE_LOOP, pts)
      end

      private

      def nome_tipo
        if @tipo == :porta_especial && @subtipo
          info = Engines::MotorPortas::TIPOS_PORTA[@subtipo]
          info ? info[:nome] : @subtipo.to_s.capitalize
        else
          @tipo.to_s.gsub('_', ' ').capitalize
        end
      end

      def encontrar_modulo_pai(entity)
        current = entity
        while current
          return current if Utils.modulo_ornato?(current)
          current = current.respond_to?(:parent) ? current.parent : nil
          current = current.respond_to?(:instances) ? nil : current
        end
        nil
      end

      # ═══════════════════════════════════════
      # DIALOGS
      # ═══════════════════════════════════════

      def mostrar_dialog_porta(mi, vao)
        prompts = ['Tipo de Porta', 'Abertura', 'Sobreposicao']
        defaults = ['Lisa (Slab)', 'Esquerda', 'Total']

        tipos_lista = Engines::MotorPortas::TIPOS_PORTA.values.map { |t| t[:nome] }.join('|')
        lists = [tipos_lista, 'Esquerda|Direita|Dupla', 'Total|Meia|Interna']

        result = ::UI.inputbox(prompts, defaults, lists, 'Configurar Porta')
        return Sketchup.active_model.abort_operation unless result

        tipo_nome, abertura_str, sobrep_str = result

        tipo_porta = Engines::MotorPortas::TIPOS_PORTA.find { |_, v| v[:nome] == tipo_nome }&.first || :lisa
        sobrep = sobrep_map(sobrep_str)

        if abertura_str == 'Dupla'
          if tipo_porta == :lisa
            Engines::MotorAgregados.adicionar_porta_dupla(mi, vao, sobreposicao: sobrep)
          else
            Engines::MotorPortas.construir_porta(mi, vao, tipo_porta,
              abertura: :esquerda, sobreposicao: sobrep, dupla: true, lado: :esquerda)
            Engines::MotorPortas.construir_porta(mi, vao, tipo_porta,
              abertura: :direita, sobreposicao: sobrep, dupla: true, lado: :direita)
          end
        else
          abertura = abertura_str == 'Esquerda' ? :esquerda : :direita
          if tipo_porta == :lisa
            Engines::MotorAgregados.adicionar_porta(mi, vao, abertura: abertura, sobreposicao: sobrep)
          else
            Engines::MotorPortas.construir_porta(mi, vao, tipo_porta,
              abertura: abertura, sobreposicao: sobrep)
          end
        end

        Sketchup.active_model.commit_operation
      end

      def mostrar_dialog_porta_dupla(mi, vao)
        prompts = ['Tipo de Porta', 'Sobreposicao']
        defaults = ['Lisa (Slab)', 'Total']

        tipos_lista = Engines::MotorPortas::TIPOS_PORTA.values.map { |t| t[:nome] }.join('|')
        lists = [tipos_lista, 'Total|Meia|Interna']

        result = ::UI.inputbox(prompts, defaults, lists, 'Porta Dupla')
        return Sketchup.active_model.abort_operation unless result

        tipo_nome, sobrep_str = result
        tipo_porta = Engines::MotorPortas::TIPOS_PORTA.find { |_, v| v[:nome] == tipo_nome }&.first || :lisa
        sobrep = sobrep_map(sobrep_str)

        if tipo_porta == :lisa
          Engines::MotorAgregados.adicionar_porta_dupla(mi, vao, sobreposicao: sobrep)
        else
          Engines::MotorPortas.construir_porta(mi, vao, tipo_porta,
            abertura: :esquerda, sobreposicao: sobrep, dupla: true, lado: :esquerda)
          Engines::MotorPortas.construir_porta(mi, vao, tipo_porta,
            abertura: :direita, sobreposicao: sobrep, dupla: true, lado: :direita)
        end

        Sketchup.active_model.commit_operation
      end

      def mostrar_dialog_porta_especial(mi, vao, tipo_porta)
        info = Engines::MotorPortas::TIPOS_PORTA[tipo_porta]
        return Sketchup.active_model.abort_operation unless info

        prompts = ['Abertura', 'Sobreposicao']
        defaults = ['Esquerda', 'Total']
        lists = ['Esquerda|Direita|Dupla', 'Total|Meia|Interna']

        # Opcoes extras por tipo de porta
        if tipo_porta == :vidro || tipo_porta == :vidro_inteiro
          prompts << 'Material Vidro'
          defaults << 'Vidro Incolor 4mm'
          lists << 'Vidro Incolor 4mm|Vidro Fume 4mm|Vidro Serigrafado 4mm|Vidro Canelado 4mm'
        elsif tipo_porta == :veneziana
          prompts << 'Largura Ripa (mm)'
          defaults << '50'
          lists << ''
        elsif tipo_porta == :provencal || tipo_porta == :almofadada
          prompts << 'Margem Quadro (mm)'
          defaults << (info[:margem_padrao] || 80).to_s
          lists << ''
        elsif tipo_porta == :perfil_aluminio
          prompts << 'Perfil'
          defaults << 'Retangular'
          lists << 'Retangular|Quadrado|Slim'
        end

        result = ::UI.inputbox(prompts, defaults, lists, "Porta #{info[:nome]}")
        return Sketchup.active_model.abort_operation unless result

        abertura_str, sobrep_str = result[0], result[1]
        sobrep = sobrep_map(sobrep_str)
        opts = { sobreposicao: sobrep }

        # Params extras conforme tipo
        case tipo_porta
        when :vidro, :vidro_inteiro
          opts[:material_vidro] = result[2]
        when :veneziana
          opts[:largura_ripa] = result[2].to_i
        when :provencal, :almofadada
          opts[:margem] = result[2].to_i
        when :perfil_aluminio
          opts[:perfil] = result[2].downcase.to_sym
        end

        if abertura_str == 'Dupla'
          opts[:dupla] = true
          Engines::MotorPortas.construir_porta(mi, vao, tipo_porta,
            opts.merge(abertura: :esquerda, lado: :esquerda))
          Engines::MotorPortas.construir_porta(mi, vao, tipo_porta,
            opts.merge(abertura: :direita, lado: :direita))
        else
          opts[:abertura] = abertura_str == 'Esquerda' ? :esquerda : :direita
          Engines::MotorPortas.construir_porta(mi, vao, tipo_porta, opts)
        end

        Sketchup.active_model.commit_operation
      end

      def mostrar_dialog_gaveta(mi, vao)
        prompts = ['Quantidade', 'Tipo Corredica', 'Altura Frente (mm)']
        defaults = ['3', 'Telescopica', '150']
        lists = ['1|2|3|4|5|6', 'Telescopica|Oculta (Undermount)|Tandembox|Roller', '']

        result = ::UI.inputbox(prompts, defaults, lists, 'Configurar Gaveta')
        return Sketchup.active_model.abort_operation unless result

        qtd_str, tipo_str, alt_str = result
        qtd = qtd_str.to_i

        tipo_map = {
          'Telescopica' => :telescopica,
          'Oculta (Undermount)' => :oculta,
          'Tandembox' => :tandembox,
          'Roller' => :roller
        }
        tipo_corredica = tipo_map[tipo_str] || :telescopica

        validacao = Engines::MotorAgregados.validar_corredica(vao, tipo_corredica, mi.espessura_corpo)
        unless validacao[:valido]
          msg = "Corredica incompativel:\n\n" + validacao[:erros].join("\n")
          ::UI.messagebox(msg, MB_OK)
          Sketchup.active_model.abort_operation
          return
        end

        unless validacao[:avisos].empty?
          msg = "Avisos:\n\n" + validacao[:avisos].join("\n") + "\n\nContinuar?"
          return Sketchup.active_model.abort_operation if ::UI.messagebox(msg, MB_YESNO) == IDNO
        end

        alt_frente = alt_str.to_i
        opts = { tipo_corredica: tipo_corredica }
        opts[:altura_frente] = alt_frente if alt_frente > 0

        if qtd > 1
          Engines::MotorAgregados.adicionar_gavetas(mi, vao, qtd, opts)
        else
          opts[:altura_frente] ||= 150
          Engines::MotorAgregados.adicionar_gaveta(mi, vao, opts)
        end

        Sketchup.active_model.commit_operation
      end

      def mostrar_dialog_prateleira(mi, vao)
        prompts = ['Posicao (mm da base do vao)', 'Espessura (mm)', 'Removivel?']
        defaults = [(vao.altura / 2.0).round(0).to_s, mi.espessura_corpo.to_s, 'Sim']
        lists = ['', '15|18|25', 'Sim|Nao']

        result = ::UI.inputbox(prompts, defaults, lists, 'Configurar Prateleira')
        return Sketchup.active_model.abort_operation unless result

        posicao = result[0].to_f
        espessura = result[1].to_i
        removivel = result[2] == 'Sim'

        opts = { posicao: posicao }
        opts[:espessura] = espessura if espessura > 0
        opts[:removivel] = removivel

        Engines::MotorAgregados.adicionar_prateleira(mi, vao, opts)
        Sketchup.active_model.commit_operation
      end

      def mostrar_dialog_divisoria(mi, vao)
        prompts = ['Direcao', 'Posicao (mm)']
        defaults = ['Vertical', (vao.largura / 2.0).round(0).to_s]
        lists = ['Vertical|Horizontal', '']

        result = ::UI.inputbox(prompts, defaults, lists, 'Configurar Divisoria')
        return Sketchup.active_model.abort_operation unless result

        dir_str, pos_str = result
        direcao = dir_str == 'Vertical' ? :vertical : :horizontal
        posicao = pos_str.to_f

        Engines::MotorAgregados.adicionar_divisoria(mi, vao, direcao, posicao: posicao)
        Sketchup.active_model.commit_operation
      end

      def sobrep_map(str)
        { 'Total' => Config::SOBREP_TOTAL, 'Meia' => Config::SOBREP_MEIA, 'Interna' => Config::SOBREP_INTERNA }[str] || Config::SOBREP_TOTAL
      end
    end
  end
end
