# ornato_plugin/tools/template_tool.rb — Ferramenta para criar módulos a partir de templates

module Ornato
  module Tools
    class TemplateTool
      def initialize(template_id = nil)
        @template_id = template_id
        @mouse_ip = nil
        @estado = :aguardando_clique
        @template_data = nil
      end

      def activate
        if @template_id
          @template_data = Engines::MotorTemplates::CATALOGO[@template_id]
          unless @template_data
            ::UI.messagebox("Template '#{@template_id}' nao encontrado.", MB_OK)
            Sketchup.active_model.select_tool(nil)
            return
          end
          @estado = :aguardando_clique
          Sketchup.status_text = "Ornato Template [#{@template_data[:nome]}]: Clique para posicionar"
        else
          mostrar_catalogo
        end
      end

      def deactivate(view)
        view.invalidate
      end

      def onMouseMove(flags, x, y, view)
        @mouse_ip = Sketchup::InputPoint.new
        @mouse_ip.pick(view, x, y)
        view.invalidate
      end

      def onLButtonDown(flags, x, y, view)
        return unless @estado == :aguardando_clique && @template_data

        ip = Sketchup::InputPoint.new
        ip.pick(view, x, y)
        posicao = ip.position

        model = Sketchup.active_model
        model.start_operation("Ornato: Template #{@template_data[:nome]}", true)

        begin
          grupo = Engines::MotorTemplates.criar_de_template(@template_id, posicao)
          if grupo
            model.selection.clear
            model.selection.add(grupo)
            Sketchup.status_text = "Ornato: '#{@template_data[:nome]}' criado — Clique para outro ou ESC"
            Ornato.painel.atualizar if Ornato.painel.visivel?
          end
          model.commit_operation
        rescue => e
          model.abort_operation
          puts "[Ornato] ERRO template: #{e.message}"
          puts e.backtrace.first(3).join("\n")
        end

        view.invalidate
      end

      def onKeyDown(key, repeat, flags, view)
        Sketchup.active_model.select_tool(nil) if key == VK_ESCAPE
      end

      def draw(view)
        return unless @mouse_ip && @template_data && @estado == :aguardando_clique

        pos = @mouse_ip.position
        l = Utils.mm(@template_data[:largura])
        a = Utils.mm(@template_data[:altura])
        p = Utils.mm(@template_data[:profundidade])

        # Wireframe preview
        pts_base = [
          Geom::Point3d.new(pos.x, pos.y, pos.z),
          Geom::Point3d.new(pos.x + l, pos.y, pos.z),
          Geom::Point3d.new(pos.x + l, pos.y + p, pos.z),
          Geom::Point3d.new(pos.x, pos.y + p, pos.z),
          Geom::Point3d.new(pos.x, pos.y, pos.z)
        ]
        pts_top = pts_base[0..3].map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + a) }
        pts_top << pts_top[0]

        # Verde para templates
        view.drawing_color = Sketchup::Color.new(46, 204, 113, 180)
        view.line_width = 2
        view.draw(GL_LINE_STRIP, pts_base)
        view.draw(GL_LINE_STRIP, pts_top)
        4.times { |i| view.draw(GL_LINES, [pts_base[i], pts_top[i]]) }

        view.tooltip = "#{@template_data[:nome]} (#{@template_data[:largura]}x#{@template_data[:altura]}x#{@template_data[:profundidade]}mm)"
      end

      def getExtents
        bb = Geom::BoundingBox.new
        if @mouse_ip && @template_data
          bb.add(@mouse_ip.position)
          l = Utils.mm(@template_data[:largura])
          a = Utils.mm(@template_data[:altura])
          p = Utils.mm(@template_data[:profundidade])
          bb.add(@mouse_ip.position.offset(Geom::Vector3d.new(l, p, a)))
        end
        bb
      end

      private

      def mostrar_catalogo
        Ornato::UI::CatalogoTemplates.mostrar do |template_id|
          @template_id = template_id
          @template_data = Engines::MotorTemplates::CATALOGO[template_id]
          if @template_data
            @estado = :aguardando_clique
            Sketchup.status_text = "Ornato Template [#{@template_data[:nome]}]: Clique para posicionar"
          end
        end
      end
    end
  end
end
