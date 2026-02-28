# ornato_plugin/tools/pecas_avulsas_tool.rb — Ferramenta para peças avulsas

module Ornato
  module Tools
    class PecasAvulsasTool
      def initialize(tipo_peca = nil)
        @tipo = tipo_peca  # :tampo, :rodape, :requadro, :painel_lateral, :painel_cavilhado, :moldura, :canaleta_led
        @mouse_ip = nil
        @estado = :aguardando_config
      end

      def activate
        if @tipo
          mostrar_dialog_peca
        else
          mostrar_selecao_tipo
        end
      end

      def deactivate(view)
        view.invalidate
        @dialog.close if @dialog && @dialog.visible?
      end

      def onMouseMove(flags, x, y, view)
        @mouse_ip = Sketchup::InputPoint.new
        @mouse_ip.pick(view, x, y)
        view.invalidate
      end

      def onLButtonDown(flags, x, y, view)
        return unless @estado == :aguardando_clique && @opts

        ip = Sketchup::InputPoint.new
        ip.pick(view, x, y)
        @opts[:posicao] = ip.position

        model = Sketchup.active_model
        model.start_operation("Ornato: #{nome_tipo}", true)

        begin
          resultado = nil
          case @tipo
          when :tampo
            resultado = Engines::MotorPecasAvulsas.criar_tampo(@opts)
          when :rodape
            resultado = Engines::MotorPecasAvulsas.criar_rodape(@opts)
          when :requadro
            resultado = Engines::MotorPecasAvulsas.criar_requadro(@opts)
          when :painel_lateral
            resultado = Engines::MotorPecasAvulsas.criar_painel_lateral(@opts)
          when :painel_cavilhado
            resultado = Engines::MotorPecasAvulsas.criar_painel_cavilhado(@opts)
          when :moldura
            resultado = Engines::MotorPecasAvulsas.criar_moldura(@opts)
          when :canaleta_led
            resultado = Engines::MotorPecasAvulsas.criar_canaleta_led(@opts)
          end

          if resultado
            model.selection.clear
            model.selection.add(resultado) if resultado.is_a?(Sketchup::Group)
            Sketchup.status_text = "Ornato: #{nome_tipo} criado — Clique para outro ou ESC"
            Ornato.painel.atualizar if Ornato.painel.visivel?
          end
          model.commit_operation
        rescue => e
          model.abort_operation
          puts "[Ornato] ERRO peca avulsa: #{e.message}"
          puts e.backtrace.first(3).join("\n")
        end

        view.invalidate
      end

      def onKeyDown(key, repeat, flags, view)
        Sketchup.active_model.select_tool(nil) if key == VK_ESCAPE
      end

      def draw(view)
        return unless @mouse_ip && @estado == :aguardando_clique && @opts

        pos = @mouse_ip.position
        l = Utils.mm(@opts[:largura] || 600)
        a = Utils.mm(@opts[:altura] || @opts[:espessura] || 30)
        p = Utils.mm(@opts[:profundidade] || @opts[:comprimento] || 400)

        pts_base = [
          Geom::Point3d.new(pos.x, pos.y, pos.z),
          Geom::Point3d.new(pos.x + l, pos.y, pos.z),
          Geom::Point3d.new(pos.x + l, pos.y + p, pos.z),
          Geom::Point3d.new(pos.x, pos.y + p, pos.z),
          Geom::Point3d.new(pos.x, pos.y, pos.z)
        ]
        pts_top = pts_base[0..3].map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + a) }
        pts_top << pts_top[0]

        view.drawing_color = Sketchup::Color.new(155, 89, 182, 180)  # roxo para pecas avulsas
        view.line_width = 2
        view.draw(GL_LINE_STRIP, pts_base)
        view.draw(GL_LINE_STRIP, pts_top)
        4.times { |i| view.draw(GL_LINES, [pts_base[i], pts_top[i]]) }

        view.tooltip = "#{nome_tipo}: #{@opts[:largura]}x#{a}mm"
      end

      private

      def nome_tipo
        nomes = {
          tampo: 'Tampo/Bancada',
          rodape: 'Rodape',
          requadro: 'Requadro',
          painel_lateral: 'Painel Lateral',
          painel_cavilhado: 'Painel Cavilhado/Ripado',
          moldura: 'Moldura/Cornija',
          canaleta_led: 'Canaleta LED'
        }
        nomes[@tipo] || @tipo.to_s.capitalize
      end

      def mostrar_selecao_tipo
        prompts = ['Tipo de Peca']
        defaults = ['Tampo/Bancada']
        lists = ['Tampo/Bancada|Rodape|Requadro|Painel Lateral|Painel Cavilhado|Moldura|Canaleta LED']

        result = ::UI.inputbox(prompts, defaults, lists, 'Ornato: Peca Avulsa')
        unless result
          Sketchup.active_model.select_tool(nil)
          return
        end

        tipo_map = {
          'Tampo/Bancada' => :tampo,
          'Rodape' => :rodape,
          'Requadro' => :requadro,
          'Painel Lateral' => :painel_lateral,
          'Painel Cavilhado' => :painel_cavilhado,
          'Moldura' => :moldura,
          'Canaleta LED' => :canaleta_led
        }
        @tipo = tipo_map[result[0]] || :tampo
        mostrar_dialog_peca
      end

      def mostrar_dialog_peca
        case @tipo
        when :tampo
          dialog_tampo
        when :rodape
          dialog_rodape
        when :requadro
          dialog_requadro
        when :painel_lateral
          dialog_painel_lateral
        when :painel_cavilhado
          dialog_painel_cavilhado
        when :moldura
          dialog_moldura
        when :canaleta_led
          dialog_canaleta_led
        end
      end

      def dialog_tampo
        prompts = ['Largura (mm)', 'Profundidade (mm)', 'Espessura (mm)', 'Material',
                   'Sobre-medida frontal (mm)', 'Sobre-medida lateral (mm)',
                   'Recorte Cuba?', 'Recorte Cooktop?']
        defaults = ['2000', '600', '30', 'Granito Preto', '20', '0', 'Nao', 'Nao']
        lists = ['', '', '15|20|25|30|40', '', '', '', 'Sim|Nao', 'Sim|Nao']

        result = ::UI.inputbox(prompts, defaults, lists, 'Ornato: Tampo/Bancada')
        return Sketchup.active_model.select_tool(nil) unless result

        @opts = {
          largura: result[0].to_i, profundidade: result[1].to_i,
          espessura: result[2].to_i, material: result[3],
          sobre_frontal: result[4].to_i, sobre_lateral: result[5].to_i
        }

        if result[6] == 'Sim'
          @opts[:recortes] = [{ tipo: :cuba, largura: 400, profundidade: 350, x: 400, y: 120 }]
        end
        if result[7] == 'Sim'
          @opts[:recortes] ||= []
          @opts[:recortes] << { tipo: :cooktop, largura: 560, profundidade: 490, x: 800, y: 55 }
        end

        @estado = :aguardando_clique
        Sketchup.status_text = "Ornato [#{nome_tipo}]: Clique para posicionar"
      end

      def dialog_rodape
        prompts = ['Comprimento (mm)', 'Altura (mm)', 'Espessura (mm)', 'Recuo frontal (mm)']
        defaults = ['800', '100', '15', '50']
        lists = ['', '', '15|18', '']

        result = ::UI.inputbox(prompts, defaults, lists, 'Ornato: Rodape')
        return Sketchup.active_model.select_tool(nil) unless result

        @opts = {
          comprimento: result[0].to_i, altura_rodape: result[1].to_i,
          espessura: result[2].to_i, recuo: result[3].to_i,
          largura: result[0].to_i
        }
        @estado = :aguardando_clique
        Sketchup.status_text = "Ornato [#{nome_tipo}]: Clique para posicionar"
      end

      def dialog_requadro
        prompts = ['Comprimento (mm)', 'Largura (mm)', 'Espessura (mm)']
        defaults = ['700', '80', '15']
        lists = ['', '', '15|18']

        result = ::UI.inputbox(prompts, defaults, lists, 'Ornato: Requadro')
        return Sketchup.active_model.select_tool(nil) unless result

        @opts = {
          comprimento: result[0].to_i, largura_requadro: result[1].to_i,
          espessura: result[2].to_i, largura: result[1].to_i
        }
        @estado = :aguardando_clique
        Sketchup.status_text = "Ornato [#{nome_tipo}]: Clique para posicionar"
      end

      def dialog_painel_lateral
        prompts = ['Altura (mm)', 'Profundidade (mm)', 'Espessura (mm)', 'Material']
        defaults = ['850', '560', '18', 'MDF Branco TX 18mm']
        lists = ['', '', '15|18|25', '']

        result = ::UI.inputbox(prompts, defaults, lists, 'Ornato: Painel Lateral')
        return Sketchup.active_model.select_tool(nil) unless result

        @opts = {
          altura: result[0].to_i, profundidade: result[1].to_i,
          espessura: result[2].to_i, material: result[3],
          largura: result[2].to_i
        }
        @estado = :aguardando_clique
        Sketchup.status_text = "Ornato [#{nome_tipo}]: Clique para posicionar"
      end

      def dialog_painel_cavilhado
        prompts = ['Largura total (mm)', 'Altura (mm)', 'Largura ripa (mm)',
                   'Espessura ripa (mm)', 'Espacamento (mm)', 'Material']
        defaults = ['1200', '2400', '40', '18', '20', 'MDF Carvalho Hanover 18mm']
        lists = ['', '', '', '15|18', '', '']

        result = ::UI.inputbox(prompts, defaults, lists, 'Ornato: Painel Cavilhado')
        return Sketchup.active_model.select_tool(nil) unless result

        @opts = {
          largura: result[0].to_i, altura: result[1].to_i,
          largura_ripa: result[2].to_i, espessura_ripa: result[3].to_i,
          espacamento: result[4].to_i, material: result[5]
        }
        @estado = :aguardando_clique
        Sketchup.status_text = "Ornato [#{nome_tipo}]: Clique para posicionar"
      end

      def dialog_moldura
        prompts = ['Comprimento (mm)', 'Altura perfil (mm)', 'Profundidade perfil (mm)']
        defaults = ['2000', '60', '40']

        result = ::UI.inputbox(prompts, defaults, [], 'Ornato: Moldura/Cornija')
        return Sketchup.active_model.select_tool(nil) unless result

        @opts = {
          comprimento: result[0].to_i, altura_perfil: result[1].to_i,
          profundidade_perfil: result[2].to_i, largura: result[0].to_i
        }
        @estado = :aguardando_clique
        Sketchup.status_text = "Ornato [#{nome_tipo}]: Clique para posicionar"
      end

      def dialog_canaleta_led
        prompts = ['Comprimento (mm)', 'Largura perfil (mm)', 'Altura perfil (mm)']
        defaults = ['1000', '17', '7']

        result = ::UI.inputbox(prompts, defaults, [], 'Ornato: Canaleta LED')
        return Sketchup.active_model.select_tool(nil) unless result

        @opts = {
          comprimento: result[0].to_i, largura_perfil: result[1].to_i,
          altura_perfil: result[2].to_i, largura: result[0].to_i
        }
        @estado = :aguardando_clique
        Sketchup.status_text = "Ornato [#{nome_tipo}]: Clique para posicionar"
      end
    end
  end
end
