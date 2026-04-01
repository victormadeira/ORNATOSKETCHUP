# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# visualization/drill_markers.rb — Marcadores visuais de furação
#
# Cria marcadores 3D nos pontos de furação para visualização no SketchUp.
# Cada furo é representado como um cilindro colorido:
#   - Verde: furação S32
#   - Azul: minifix/cavilha
#   - Vermelho: caneco de dobradiça
#   - Amarelo: operações especiais
#
# Furos passantes são cilindros vazados; furos cegos são sólidos.

module Ornato
  module Visualization
    class DrillMarkers
      COLORS = {
        furacao:   [60, 180, 75],     # Verde
        canal:    [255, 193, 7],      # Amarelo
        rebaixo:  [255, 152, 0],      # Laranja
        fresagem: [156, 39, 176],     # Roxo
        pocket:   [33, 150, 243],     # Azul
        cava:     [0, 188, 212],      # Ciano
        default:  [158, 158, 158]     # Cinza
      }.freeze

      MARKER_SEGMENTS = 12  # Segmentos do cilindro (polígono)
      HOLLOW_WALL_RATIO = 0.2  # Espessura da parede do cilindro vazado (20% do raio)

      # Cria marcadores de furação em um módulo.
      #
      # @param mod [Domain::ModEntity]
      # @param mod_group [Sketchup::Group] grupo SketchUp do módulo
      # @param model [Sketchup::Model]
      # @return [Sketchup::Group] grupo contendo todos os marcadores
      def create_markers(mod, mod_group, model)
        return unless Core::FeatureFlags.enabled?(:drill_markers)

        ensure_tag(model, Core::Config::TAG_FURACOES)

        markers_group = mod_group.entities.add_group
        markers_group.name = "#{mod.name} — Furações"
        markers_group.layer = model.layers[Core::Config::TAG_FURACOES]

        mod.operations.each do |op|
          next unless op.cnc_required?
          begin
            create_single_marker(op, markers_group, model)
          rescue => e
            Core.logger.warn("Falha ao criar marcador para op #{op.name rescue '?'}: #{e.message}")
            next
          end
        end

        Core.logger.info("#{mod.operations.length} marcadores de furação criados para #{mod.name}")
        markers_group
      rescue => e
        Core.logger.warn("Falha ao criar marcadores de furação: #{e.message}")
        nil
      end

      # Remove todos os marcadores de furação de um módulo.
      def remove_markers(mod_group)
        mod_group.entities.each do |entity|
          if entity.is_a?(Sketchup::Group) && entity.name =~ /Furações$/
            entity.erase!
          end
        end
      rescue => e
        Core.logger.warn("Falha ao remover marcadores: #{e.message}")
      end

      # Atualiza marcadores (remove e recria).
      def update_markers(mod, mod_group, model)
        remove_markers(mod_group)
        create_markers(mod, mod_group, model)
      end

      private

      def create_single_marker(operation, parent_group, model)
        group = parent_group.entities.add_group
        group.name = operation.name

        # Posição do marcador — use face data from operation to set Z
        x = Core::Config.to_mm(operation.x_mm)
        y = Core::Config.to_mm(operation.y_mm)
        z = resolve_z_position(operation)

        center = Geom::Point3d.new(x, y, z)
        radius = Core::Config.to_mm(operation.tool_diameter_mm / 2.0)
        depth  = Core::Config.to_mm(operation.depth_mm)

        # Determine drill direction based on face
        normal = resolve_drill_normal(operation)

        is_through = through_hole?(operation)

        if is_through
          # Hollow cylinder for through holes (visual distinction)
          create_hollow_cylinder(group, center, normal, radius, depth)
        else
          # Solid cylinder for blind holes
          circle = group.entities.add_circle(center, normal, radius, MARKER_SEGMENTS)
          face = group.entities.add_face(circle)
          face.pushpull(depth) if face
        end

        # Colorir — check if material already exists to avoid collision
        mat_name = "ornato_marker_#{operation.operation_type}"
        material = model.materials[mat_name]
        unless material
          material = model.materials.add(mat_name)
          color = COLORS[operation.operation_type] || COLORS[:default]
          material.color = Sketchup::Color.new(*color)
          material.alpha = 0.6
        end

        # Apply material to all faces in the group
        group.entities.grep(Sketchup::Face).each do |f|
          f.material = material
        end

        # Atributos para identificação
        Core::Attributes.write(group, Core::Config::DICT_IDENTITY, {
          ornato_id: operation.ornato_id,
          tipo: 'drill_marker'
        })

        group
      end

      # Resolve Z position based on operation's face data.
      # Falls back to 0 if face info is unavailable.
      def resolve_z_position(operation)
        if operation.respond_to?(:face) && operation.face
          case operation.face.to_s.downcase
          when 'top', 'face5'
            # Top face: Z at the part thickness
            Core::Config.to_mm(operation.respond_to?(:part_thickness_mm) ? operation.part_thickness_mm : 0)
          when 'bottom', 'face6'
            0
          when 'front', 'face1'
            Core::Config.to_mm(operation.respond_to?(:z_mm) ? operation.z_mm : 0)
          when 'back', 'face2'
            Core::Config.to_mm(operation.respond_to?(:z_mm) ? operation.z_mm : 0)
          when 'left', 'face3'
            Core::Config.to_mm(operation.respond_to?(:z_mm) ? operation.z_mm : 0)
          when 'right', 'face4'
            Core::Config.to_mm(operation.respond_to?(:z_mm) ? operation.z_mm : 0)
          else
            Core::Config.to_mm(operation.respond_to?(:z_mm) ? operation.z_mm : 0)
          end
        elsif operation.respond_to?(:z_mm) && operation.z_mm
          Core::Config.to_mm(operation.z_mm)
        else
          0
        end
      rescue => e
        Core.logger.warn("Falha ao resolver Z para operação #{operation.name rescue '?'}: #{e.message}")
        0
      end

      # Resolve drill direction normal based on operation face.
      def resolve_drill_normal(operation)
        if operation.respond_to?(:face) && operation.face
          case operation.face.to_s.downcase
          when 'top', 'face5'
            Geom::Vector3d.new(0, 0, -1)
          when 'bottom', 'face6'
            Geom::Vector3d.new(0, 0, 1)
          when 'front', 'face1'
            Geom::Vector3d.new(0, -1, 0)
          when 'back', 'face2'
            Geom::Vector3d.new(0, 1, 0)
          when 'left', 'face3'
            Geom::Vector3d.new(-1, 0, 0)
          when 'right', 'face4'
            Geom::Vector3d.new(1, 0, 0)
          else
            Geom::Vector3d.new(0, 0, -1)
          end
        else
          Geom::Vector3d.new(0, 0, -1)  # Default: drill from top
        end
      end

      # Detect if a hole is through (passante) based on operation data.
      def through_hole?(operation)
        return operation.through? if operation.respond_to?(:through?)
        return operation.passante if operation.respond_to?(:passante)
        false
      end

      # Create a hollow cylinder (ring extrusion) for through holes.
      def create_hollow_cylinder(group, center, normal, radius, depth)
        wall = radius * HOLLOW_WALL_RATIO
        inner_radius = radius - wall
        inner_radius = radius * 0.5 if inner_radius <= 0  # safety floor

        # Outer circle
        outer_edges = group.entities.add_circle(center, normal, radius, MARKER_SEGMENTS)
        # Inner circle (creates the hollow)
        inner_edges = group.entities.add_circle(center, normal, inner_radius, MARKER_SEGMENTS)

        # The annular face between inner and outer circles
        face = group.entities.grep(Sketchup::Face).first
        face.pushpull(depth) if face
      rescue => e
        # Fallback to solid cylinder if hollow fails
        Core.logger.warn("Hollow cylinder falhou, usando sólido: #{e.message}")
        circle = group.entities.add_circle(center, normal, radius, MARKER_SEGMENTS)
        face = group.entities.add_face(circle)
        face.pushpull(depth) if face
      end

      def ensure_tag(model, tag_name)
        model.layers.add(tag_name) unless model.layers[tag_name]
      end
    end
  end
end
