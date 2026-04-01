# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# visualization/part_labels.rb — Labels visuais nas peças
#
# Exibe informações sobre peças diretamente no viewport do SketchUp:
#   - Código da peça (ex: CM_LAT_ESQ)
#   - Dimensões (ex: 700 x 560 x 18.5)
#   - Material
#   - Código de acabamento de fita
#
# Usa ScreenTextInput ou 3D Text para exibição.

module Ornato
  module Visualization
    class PartLabels
      FONT_HEIGHT = 8    # mm, tamanho do texto 3D
      LABEL_OFFSET = 5   # mm, offset da face
      TEXT_Z_CLEARANCE = 1  # mm, folga acima da face superior

      # Cria labels em todas as peças visíveis de um módulo.
      #
      # @param mod [Domain::ModEntity]
      # @param mod_group [Sketchup::Group]
      # @param model [Sketchup::Model]
      # @param style [Symbol] :compact, :detailed, :code_only
      # @return [Sketchup::Group] grupo contendo os labels
      def create_labels(mod, mod_group, model, style: :compact)
        return unless Core::FeatureFlags.enabled?(:part_labels)

        ensure_tag(model, Core::Config::TAG_PECAS)

        labels_group = mod_group.entities.add_group
        labels_group.name = "#{mod.name} — Labels"

        mod.parts.each do |part|
          begin
            text = format_label(part, style)
            center = calculate_part_center(part, mod)
            next unless center

            # add_3d_text returns an array of edges/faces added to entities
            text_entities = labels_group.entities.add_3d_text(
              text, TextAlignCenter, 'Arial',
              false, false, Core::Config.to_mm(FONT_HEIGHT), 0.0, 0.0, true
            )

            # Reposition text: add_3d_text anchors at origin (bottom-left),
            # so we move it to be centered on the part's top face.
            if text_entities && !text_entities.empty?
              # Calculate bounding box of the generated text
              bb = Geom::BoundingBox.new
              text_entities.each { |e| bb.add(e.bounds) rescue nil }

              text_width  = bb.width
              text_height = bb.height

              # Offset so text is centered on part center,
              # and sits on top of the visible face (thickness/2 + clearance)
              z_on_face = Core::Config.to_mm(part.thickness_real / 2.0 + TEXT_Z_CLEARANCE)
              offset_x = center.x - (text_width / 2.0)
              offset_y = center.y - (text_height / 2.0)
              offset_z = z_on_face

              move = Geom::Transformation.new([offset_x, offset_y, offset_z])
              text_entities.each do |ent|
                ent.move!(move) if ent.respond_to?(:move!)
              end
            end
          rescue => e
            Core.logger.warn("Falha ao criar label para peça #{part.code rescue '?'}: #{e.message}")
            next
          end
        end

        labels_group
      rescue => e
        Core.logger.warn("Falha ao criar labels: #{e.message}")
        nil
      end

      # Remove labels de um módulo.
      def remove_labels(mod_group)
        mod_group.entities.each do |entity|
          if entity.is_a?(Sketchup::Group) && entity.name =~ /Labels$/
            entity.erase!
          end
        end
      rescue => e
        Core.logger.warn("Falha ao remover labels: #{e.message}")
      end

      # Formata texto do label conforme estilo.
      def format_label(part, style)
        case style
        when :code_only
          part.code
        when :compact
          "#{part.code}\n#{part.cut_length.round(1)} x #{part.cut_width.round(1)} x #{part.thickness_real}"
        when :detailed
          lines = [
            part.code,
            "#{part.cut_length.round(1)} x #{part.cut_width.round(1)} x #{part.thickness_real}mm",
            part.material_id || 'Sem material',
            part.respond_to?(:edgeband_finish_code) ? part.edgeband_finish_code : ''
          ]
          lines.join("\n")
        else
          part.code
        end
      end

      private

      def calculate_part_center(part, mod)
        # Posição aproximada do centro da peça
        x = Core::Config.to_mm(part.length_mm / 2.0)
        y = Core::Config.to_mm(part.width_mm / 2.0)
        z = Core::Config.to_mm(part.thickness_real / 2.0)
        Geom::Point3d.new(x, y, z)
      rescue => e
        Core.logger.warn("Falha ao calcular centro da peça: #{e.message}")
        nil
      end

      def ensure_tag(model, tag_name)
        model.layers.add(tag_name) unless model.layers[tag_name]
      end
    end
  end
end
