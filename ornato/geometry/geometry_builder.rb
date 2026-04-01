# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# geometry/geometry_builder.rb — Construtor de geometria 3D SketchUp
#
# Transforma entidades de domínio em geometria SketchUp (grupos, faces, edges).
# A geometria é CONSEQUÊNCIA do domínio, nunca fonte de verdade.
#
# DA-01: Geometria é consequência, não fonte de verdade.
# DA-08: Separação visual/técnica/industrial.
#
# Responsabilidades:
#   - Criar grupo SketchUp para módulo
#   - Criar sub-grupos para cada peça
#   - Aplicar materiais e camadas (tags)
#   - Posicionar peças conforme tipo de montagem

module Ornato
  module Geometry
    class GeometryBuilder
      # Constrói geometria SketchUp para um módulo completo.
      #
      # @param mod [Domain::ModEntity] módulo de domínio
      # @param model [Sketchup::Model] modelo ativo
      # @param position [Geom::Point3d] posição no modelo (opcional)
      # @return [Sketchup::Group] grupo SketchUp do módulo
      def build_module(mod, model, position: nil)
        Core.logger.measure('GeometryBuilder.build_module') do
          position ||= Geom::Point3d.new(0, 0, 0)

          model.start_operation('Ornato: Criar Módulo', true)

          # Criar grupo principal do módulo
          mod_group = model.active_entities.add_group
          mod_group.name = mod.name

          # Tag do módulo
          ensure_tag(model, Core::Config::TAG_MODULOS)
          mod_group.layer = model.layers[Core::Config::TAG_MODULOS]

          # Posicionar
          t = Geom::Transformation.translation(position)
          mod_group.transform!(t)

          # Persistir identidade
          Core::Attributes.persist_domain_entity(mod_group, mod)

          # Construir peças estruturais
          build_structural_parts(mod, mod_group, model)

          # Construir peças de agregados
          build_aggregate_parts(mod, mod_group, model)

          model.commit_operation

          Core.logger.info("Geometria criada: #{mod.name} — #{mod.parts.length} peças")
          mod_group
        end
      rescue => e
        model.abort_operation
        Core.logger.error("Falha ao criar geometria", error: e.message)
        raise Core::RebuildError.new("Geometria: #{e.message}", code: :geometry_failed)
      end

      # Atualiza geometria existente de um módulo.
      #
      # @param mod [Domain::ModEntity]
      # @param mod_group [Sketchup::Group]
      # @param model [Sketchup::Model]
      def update_module(mod, mod_group, model)
        Core.logger.measure('GeometryBuilder.update_module') do
          model.start_operation('Ornato: Atualizar Módulo', true)

          # Limpar geometria interna
          mod_group.entities.clear!

          # Reconstruir
          build_structural_parts(mod, mod_group, model)
          build_aggregate_parts(mod, mod_group, model)

          # Atualizar atributos
          Core::Attributes.persist_domain_entity(mod_group, mod)

          model.commit_operation
        end
      rescue => e
        model.abort_operation
        Core.logger.error("Falha ao atualizar geometria", error: e.message)
        raise Core::RebuildError.new("Geometria update: #{e.message}", code: :geometry_update_failed)
      end

      # Remove geometria de um módulo.
      def delete_module(mod_group, model)
        model.start_operation('Ornato: Remover Módulo', true)
        mod_group.erase!
        model.commit_operation
      end

      private

      # Constrói geometria das peças estruturais.
      def build_structural_parts(mod, mod_group, model)
        mod.parts.select(&:structural?).each do |part|
          build_part_geometry(part, mod, mod_group, model)
        end
      end

      # Constrói geometria das peças de agregados.
      def build_aggregate_parts(mod, mod_group, model)
        mod.parts.reject(&:structural?).each do |part|
          build_part_geometry(part, mod, mod_group, model)
        end
      end

      # Cria geometria 3D de uma peça individual.
      def build_part_geometry(part, mod, parent_group, model)
        group = parent_group.entities.add_group
        group.name = part.name

        # Tag de peça
        ensure_tag(model, Core::Config::TAG_PECAS)
        group.layer = model.layers[Core::Config::TAG_PECAS]

        # Dimensões em polegadas (SketchUp internamente usa polegadas)
        l = Core::Config.to_mm(part.cut_length)   # length → X
        w = Core::Config.to_mm(part.cut_width)     # width → Y
        t = Core::Config.to_mm(part.thickness_real) # thickness → Z

        # Criar sólido (box)
        pts = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(l, 0, 0),
          Geom::Point3d.new(l, w, 0),
          Geom::Point3d.new(0, w, 0)
        ]
        face = group.entities.add_face(pts)
        face.pushpull(-t) if face

        # Posicionar peça dentro do módulo
        position = calculate_part_position(part, mod)
        if position
          t_move = Geom::Transformation.translation(position)
          group.transform!(t_move)
        end

        # Persistir identidade da peça
        Core::Attributes.write(group, Core::Config::DICT_IDENTITY, {
          ornato_id: part.ornato_id,
          tipo: 'part',
          schema_version: 1
        })

        Core::Attributes.write(group, Core::Config::DICT_MANUFACTURING, {
          code: part.code,
          part_type: part.part_type.to_s,
          material_id: part.material_id
        })

        group
      end

      # Calcula posição de uma peça dentro do módulo.
      # @return [Geom::Point3d]
      def calculate_part_position(part, mod)
        bt = Core::Config.real_thickness(mod.body_thickness)
        bt_in = Core::Config.to_mm(bt)

        case part.code
        when 'CM_LAT_ESQ'
          Geom::Point3d.new(0, 0, 0)
        when 'CM_LAT_DIR'
          w = Core::Config.to_mm(mod.width_mm - bt)
          Geom::Point3d.new(w, 0, 0)
        when 'CM_BAS'
          base_h = mod.base_type == :rodape ? Core::Config.to_mm(mod.base_height_mm) : 0
          if mod.assembly_type == :brasil
            Geom::Point3d.new(0, 0, base_h)
          else
            Geom::Point3d.new(bt_in, 0, base_h)
          end
        when 'CM_REG'
          h = Core::Config.to_mm(mod.height_mm - bt)
          if mod.assembly_type == :brasil
            Geom::Point3d.new(0, 0, h)
          else
            Geom::Point3d.new(bt_in, 0, h)
          end
        when 'CM_FUN'
          bt_back = Core::Config.to_mm(Core::Config.real_thickness(mod.back_thickness))
          base_h = mod.base_type == :rodape ? Core::Config.to_mm(mod.base_height_mm) : 0
          depth = Core::Config.to_mm(mod.depth_mm)
          Geom::Point3d.new(bt_in, depth - bt_back, base_h + bt_in)
        else
          nil  # Posição default (0,0,0) — será ajustada pela lógica de agregados
        end
      end

      # Garante que uma tag/layer existe no modelo.
      def ensure_tag(model, tag_name)
        unless model.layers[tag_name]
          model.layers.add(tag_name)
        end
      end
    end
  end
end
