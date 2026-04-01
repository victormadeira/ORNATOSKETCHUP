# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# tools/module_tool.rb — Ferramenta de posicionamento de modulo
#
# Ferramenta interativa para posicionar modulos no modelo SketchUp.
# O usuario clica para definir a posicao de insercao.
#
# Fluxo:
#   1. Usuario seleciona tipo de modulo e parametros
#   2. Ferramenta ativada — cursor de posicionamento
#   3. Preview do modulo segue o cursor
#   4. Clique = inserir modulo naquela posicao
#   5. ESC = cancelar

module Ornato
  module Tools
    class ModuleTool
      CURSOR_PENCIL = 632  # ID do cursor pencil no SketchUp

      # @param module_type [Symbol] tipo do modulo
      # @param params [Hash] parametros dimensionais
      # @param ruleset [Domain::Ruleset] regras de construcao
      def initialize(module_type, params, ruleset)
        @module_type = module_type
        @params = params
        @ruleset = ruleset
        @position = nil
        @preview_group = nil
        @factory = Components::ModuleFactory.new
        @geometry = Geometry::GeometryBuilder.new
      end

      # -- SketchUp Tool Interface -----------------------------------------------

      def activate
        @ip = Sketchup::InputPoint.new
        Sketchup.active_model.active_view.invalidate
        Sketchup.status_text = "ORNATO: Clique para posicionar #{@module_type}. ESC para cancelar."
        Core.logger.info("ModuleTool ativado: #{@module_type}")
      end

      def deactivate(view)
        cleanup_preview
        view.invalidate
        Sketchup.status_text = ''
        Core.logger.info('ModuleTool desativado')
      end

      def resume(view)
        view.invalidate
        Sketchup.status_text = "ORNATO: Clique para posicionar #{@module_type}. ESC para cancelar."
      end

      def suspend(view)
        view.invalidate
      end

      def onMouseMove(flags, x, y, view)
        @ip.pick(view, x, y)
        @position = @ip.position if @ip.valid?
        view.tooltip = format_tooltip
        view.invalidate
      end

      def onLButtonDown(flags, x, y, view)
        return unless @position

        begin
          model = Sketchup.active_model

          # Criar modulo no dominio
          mod = @factory.create(@module_type, @params, @ruleset)

          # Criar geometria na posicao clicada
          @geometry.build_module(mod, model, position: @position)

          # Registrar no painel
          panel = UI::MainPanel.instance
          if panel.visible? && panel.bridge
            panel.bridge.register_module(mod)
          end

          Core.logger.info("Modulo inserido: #{mod.name} em #{@position}")
          Sketchup.status_text = "Modulo #{mod.name} inserido!"

          # Desativar ferramenta apos insercao
          Sketchup.active_model.select_tool(nil)

        rescue => e
          ::UI.messagebox("Erro ao criar modulo: #{e.message}")
          Core.logger.error("ModuleTool: falha", error: e.message)
        end
      end

      def onKeyDown(key, repeat, flags, view)
        if key == VK_ESCAPE
          Sketchup.active_model.select_tool(nil)
        end
      end

      def draw(view)
        return unless @position

        # Desenhar crosshair no ponto de insercao
        view.drawing_color = Sketchup::Color.new(230, 126, 34, 180)  # #e67e22
        view.line_width = 2

        size = 50  # mm
        size_in = size.mm

        # Cruz 3D no ponto
        p = @position
        view.draw_line(
          [p.x - size_in, p.y, p.z],
          [p.x + size_in, p.y, p.z]
        )
        view.draw_line(
          [p.x, p.y - size_in, p.z],
          [p.x, p.y + size_in, p.z]
        )

        # Retangulo de footprint do modulo
        w = (@params[:width_mm] || 600).mm
        d = (@params[:depth_mm] || 560).mm

        pts = [
          Geom::Point3d.new(p.x, p.y, p.z),
          Geom::Point3d.new(p.x + w, p.y, p.z),
          Geom::Point3d.new(p.x + w, p.y + d, p.z),
          Geom::Point3d.new(p.x, p.y + d, p.z),
          Geom::Point3d.new(p.x, p.y, p.z)
        ]

        view.drawing_color = Sketchup::Color.new(230, 126, 34, 100)
        view.draw_polyline(pts)
      end

      def getExtents
        bb = Geom::BoundingBox.new
        if @position
          bb.add(@position)
          w = (@params[:width_mm] || 600).mm
          d = (@params[:depth_mm] || 560).mm
          h = (@params[:height_mm] || 720).mm
          bb.add(Geom::Point3d.new(@position.x + w, @position.y + d, @position.z + h))
        end
        bb
      end

      private

      def format_tooltip
        return '' unless @position
        x = @position.x.to_mm.round(1)
        y = @position.y.to_mm.round(1)
        z = @position.z.to_mm.round(1)
        "#{@module_type} — Posicao: #{x}, #{y}, #{z} mm"
      end

      def cleanup_preview
        @preview_group&.erase! if @preview_group&.valid?
        @preview_group = nil
      end
    end
  end
end
