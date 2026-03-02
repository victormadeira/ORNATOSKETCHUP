# ornato_plugin/engines/motor_contorno.rb — Extração de contorno 2D
#
# Extrai o contorno 2D de qualquer peça (Face do SketchUp) para exportação CNC.
# Suporta: retângulos, cantos arredondados, formas orgânicas, furos circulares (passa-fio),
# recortes arbitrários.
#
# Formato de saída:
#   { 'outer' => [ { 'type' => 'line', 'x2' => ..., 'y2' => ... }, ... ],
#     'holes' => [ { 'type' => 'circle', 'cx' => ..., 'cy' => ..., 'r' => ... }, ... ] }
#
# Retorna nil para peças retangulares simples (4 arestas retas, sem furos) — retrocompatível.

require 'set'

module Ornato
  module Engines
    class MotorContorno

      # ═══════════════════════════════════════════════════════════
      # API PÚBLICA
      # ═══════════════════════════════════════════════════════════

      # Extrai contorno 2D de um grupo/component SketchUp
      # @param grupo [Sketchup::Group, Sketchup::ComponentInstance]
      # @return [Hash, nil] Hash com 'outer' e 'holes', ou nil se retangular simples
      def self.extrair(grupo)
        return nil unless grupo

        face = encontrar_face_principal(grupo)
        return nil unless face

        # Se retangular simples (4 edges retas, sem inner loops), retorna nil
        # O sistema usa comprimento×largura como fallback (retrocompatível)
        return nil if retangular_simples?(face)

        # Obter transformação do grupo para converter coordenadas locais → globais relativas
        # Na prática, queremos coordenadas relativas à peça (origin no canto inferior-esquerdo)
        contour = { 'outer' => [], 'holes' => [] }

        # Contorno externo
        outer_segs = extrair_loop(face.outer_loop)
        return nil if outer_segs.empty?

        # Normalizar: transladar para que min(x,y) = (0,0)
        all_points = coletar_pontos(outer_segs)
        min_x = all_points.map { |p| p[0] }.min || 0
        min_y = all_points.map { |p| p[1] }.min || 0

        contour['outer'] = normalizar_segmentos(outer_segs, min_x, min_y)

        # Furos/recortes internos
        face.loops.each do |loop|
          next if loop == face.outer_loop

          if circulo_completo?(loop)
            arc = loop.edges.first.curve
            center = arc.center
            contour['holes'] << {
              'type' => 'circle',
              'cx' => (center.x.to_mm - min_x).round(3),
              'cy' => (center.y.to_mm - min_y).round(3),
              'r' => arc.radius.to_mm.round(3)
            }
          else
            segments = extrair_loop(loop)
            next if segments.empty?
            segments = normalizar_segmentos(segments, min_x, min_y)
            contour['holes'] << { 'type' => 'polygon', 'segments' => segments }
          end
        end

        contour
      end

      # Calcula bounding box de um contorno extraído
      # @return [Hash] { w: largura, h: altura }
      def self.bounding_box(contour)
        return nil unless contour && contour['outer']

        pts = coletar_pontos(contour['outer'])

        # Incluir pontos de furos circulares
        (contour['holes'] || []).each do |hole|
          if hole['type'] == 'circle'
            pts << [hole['cx'] + hole['r'], hole['cy'] + hole['r']]
            pts << [hole['cx'] - hole['r'], hole['cy'] - hole['r']]
          elsif hole['segments']
            pts.concat(coletar_pontos(hole['segments']))
          end
        end

        return nil if pts.empty?

        {
          'w' => (pts.map { |p| p[0] }.max || 0).round(3),
          'h' => (pts.map { |p| p[1] }.max || 0).round(3)
        }
      end

      # ═══════════════════════════════════════════════════════════
      # MÉTODOS PRIVADOS
      # ═══════════════════════════════════════════════════════════
      class << self
        private

        # Encontra a face principal (maior face no plano XY ou com normal Z)
        # A face de corte CNC é sempre a face superior/inferior da peça
        def encontrar_face_principal(grupo)
          ents = if grupo.respond_to?(:definition)
                   grupo.definition.entities
                 else
                   grupo.entities
                 end

          faces = ents.grep(Sketchup::Face)
          return nil if faces.empty?

          # Preferir face com normal [0,0,-1] ou [0,0,1] (plano XY)
          xy_faces = faces.select { |f|
            n = f.normal
            n.z.abs > 0.99
          }

          # Se tem faces XY, usar a maior delas. Senão, maior face qualquer.
          target = xy_faces.any? ? xy_faces : faces
          target.max_by { |f| f.area }
        end

        # Verifica se a face é um retângulo simples (4 edges retas, sem furos)
        def retangular_simples?(face)
          return false if face.loops.length > 1  # tem furos/recortes internos
          edges = face.outer_loop.edges
          return false if edges.length != 4
          # Todas as edges devem ser retas (sem curva)
          edges.all? { |e| e.curve.nil? }
        end

        # Verifica se um loop é um círculo completo (360°)
        def circulo_completo?(loop)
          edges = loop.edges
          return false if edges.empty?

          first_curve = edges.first.curve
          return false unless first_curve.is_a?(Sketchup::ArcCurve)

          # Todas as edges pertencem ao mesmo arco
          return false unless edges.all? { |e| e.curve == first_curve }

          # É um arco de ~360° (2π ≈ 6.283)
          angle_span = (first_curve.end_angle - first_curve.start_angle).abs
          angle_span > 6.2  # tolerância para erros de floating point
        end

        # Extrai segmentos de um loop (outer ou inner)
        # Agrupa edges que pertencem ao mesmo ArcCurve em um único segmento 'arc'
        # @return [Array<Hash>] Array de segmentos { 'type' => 'line'|'arc', ... }
        def extrair_loop(loop)
          segments = []
          processed_curves = Set.new

          loop.edgeuses.each do |eu|
            edge = eu.edge
            reversed = eu.reversed?

            if edge.curve.is_a?(Sketchup::ArcCurve)
              # Edge pertence a um arco
              arc = edge.curve

              # Se já processamos este arco, pular (as múltiplas edges do arco
              # são agrupadas na primeira vez que encontramos o arco)
              next if processed_curves.include?(arc.object_id)
              processed_curves.add(arc.object_id)

              # Coletar todas as edgeuses deste arco no loop (na ordem do loop)
              arc_edgeuses = loop.edgeuses.select { |e2| e2.edge.curve == arc }
              next if arc_edgeuses.empty?

              # Determinar ponto final do arco (último edge na sequência do loop)
              last_eu = arc_edgeuses.last
              end_pt = last_eu.reversed? ? last_eu.edge.start.position : last_eu.edge.end.position

              center = arc.center

              segments << {
                'type' => 'arc',
                'x2' => end_pt.x.to_mm.round(3),
                'y2' => end_pt.y.to_mm.round(3),
                'cx' => center.x.to_mm.round(3),
                'cy' => center.y.to_mm.round(3),
                'r' => arc.radius.to_mm.round(3),
                'dir' => determinar_direcao(arc, reversed)
              }

            elsif edge.curve.nil?
              # Edge reta (linha)
              pt = reversed ? edge.start.position : edge.end.position

              # Filtrar segmentos muito pequenos (< 0.5mm)
              segments << {
                'type' => 'line',
                'x2' => pt.x.to_mm.round(3),
                'y2' => pt.y.to_mm.round(3)
              }

            else
              # Outro tipo de curva (raro no SketchUp) — tratar como edges individuais
              pt = reversed ? edge.start.position : edge.end.position
              segments << {
                'type' => 'line',
                'x2' => pt.x.to_mm.round(3),
                'y2' => pt.y.to_mm.round(3)
              }
            end
          end

          segments
        end

        # Determina direção do arco (CW ou CCW)
        # No SketchUp, arcos criados com o Arc tool são CCW por padrão.
        # EdgeUse.reversed? indica se a edge é percorrida na direção oposta no loop.
        def determinar_direcao(arc, reversed)
          # Em faces com normal [0,0,-1] (face inferior), a direção aparente inverte
          # Para CNC (vista de cima), queremos a direção real no plano XY
          reversed ? 'cw' : 'ccw'
        end

        # Coleta todos os pontos de um array de segmentos
        # @return [Array<Array<Float>>] [[x, y], [x, y], ...]
        def coletar_pontos(segments)
          segments.map do |seg|
            if seg['type'] == 'arc'
              # Para arcos, incluir ponto final e extremos do arco (centro ± raio)
              [
                [seg['x2'], seg['y2']],
                [seg['cx'] + seg['r'], seg['cy']],
                [seg['cx'] - seg['r'], seg['cy']],
                [seg['cx'], seg['cy'] + seg['r']],
                [seg['cx'], seg['cy'] - seg['r']],
              ]
            else
              [[seg['x2'], seg['y2']]]
            end
          end.flatten(1)
        end

        # Normaliza segmentos transladando para origin (0,0)
        def normalizar_segmentos(segments, offset_x, offset_y)
          segments.map do |seg|
            result = seg.dup
            result['x2'] = (result['x2'] - offset_x).round(3) if result['x2']
            result['y2'] = (result['y2'] - offset_y).round(3) if result['y2']
            if result['cx']
              result['cx'] = (result['cx'] - offset_x).round(3)
              result['cy'] = (result['cy'] - offset_y).round(3)
            end
            result
          end
        end

      end  # class << self

    end
  end
end
