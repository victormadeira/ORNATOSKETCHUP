# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# engineering/edging_engine.rb — Motor de fita de borda
#
# Aplica regras de fita de borda nas peças:
#   - Peças estruturais: borda frontal sempre
#   - Portas: 4 lados
#   - Gavetas: frente 4 lados, laterais sem fita
#   - Prateleiras: borda frontal
#   - Fundos: sem fita
#
# Cada edge é um EdgeSpec na Part.

module Ornato
  module Engineering
    class EdgingEngine
      # Aplica fita de borda em todas as peças de um módulo.
      # @param mod [Domain::ModEntity]
      # @param ruleset [Domain::Ruleset]
      def apply_all(mod, ruleset)
        edge_t = ruleset.rule(:edging, :default_thickness, fallback: 1.0)
        edge_w = ruleset.rule(:edging, :default_width, fallback: 22.0)
        front_t = ruleset.rule(:front, :edge_thickness, fallback: edge_t)
        front_w = ruleset.rule(:front, :edge_width, fallback: edge_w)

        mod.parts.each do |part|
          apply_to_part(part, edge_t, edge_w, front_t, front_w)
        end
      rescue StandardError => e
        Core.logger&.error("EdgingEngine#apply_all falhou: #{e.message}")
        raise
      end

      # Aplica fita de borda em uma peça específica.
      def apply_to_part(part, edge_t, edge_w, front_edge_t, front_edge_w)
        case part.code
        # Estruturais: borda frontal (inclui peças de canto L)
        when 'CM_LAT_ESQ', 'CM_LAT_DIR', 'CM_LAT_RET', 'CM_BAS', 'CM_BAS_RET', 'CM_REG', 'CM_DIV'
          part.edge_front ||= make_edge(edge_t, edge_w, part)

        # Topo: borda frontal (inclui topo retorno)
        when 'CM_TOP', 'CM_TOP_RET'
          part.edge_front ||= make_edge(edge_t, edge_w, part)

        # Prateleiras: borda frontal
        when 'CM_PRA', 'CM_PRA_FIX', 'CM_PRA_REG'
          part.edge_front ||= make_edge(edge_t, edge_w, part)

        # Portas: 4 lados com fita de frente
        when /^CM_POR/
          part.edge_front ||= make_edge(front_edge_t, front_edge_w, part)
          part.edge_back  ||= make_edge(front_edge_t, front_edge_w, part)
          part.edge_left  ||= make_edge(front_edge_t, front_edge_w, part)
          part.edge_right ||= make_edge(front_edge_t, front_edge_w, part)

        # Frente de gaveta: 4 lados
        when 'CM_FRE_GAV'
          part.edge_front ||= make_edge(front_edge_t, front_edge_w, part)
          part.edge_back  ||= make_edge(front_edge_t, front_edge_w, part)
          part.edge_left  ||= make_edge(front_edge_t, front_edge_w, part)
          part.edge_right ||= make_edge(front_edge_t, front_edge_w, part)

        # Laterais e traseira de gaveta: sem fita (cobertas pela frente)
        when 'CM_LAT_GAV_E', 'CM_LAT_GAV_D', 'CM_TRAS_GAV'
          # Sem fita

        # Fundo: sem fita (modulo e gaveta)
        when 'CM_FUN', 'CM_FUN_GAV'
          # Sem fita

        # Painel: frontal
        when 'CM_PNL'
          part.edge_front ||= make_edge(edge_t, edge_w, part)

        # Tampo: frontal com fita grossa
        when 'CM_TAM', 'CM_TAM_ORG', 'CM_TAM_PASS'
          part.edge_front ||= make_edge(2.0, 45.0, part)

        # Rodape: frontal
        when 'CM_ROD'
          part.edge_front ||= make_edge(edge_t, edge_w, part)

        # Travessa: borda frontal
        when 'CM_TRA'
          part.edge_front ||= make_edge(edge_t, edge_w, part)

        # Testeira: borda frontal
        when 'CM_TEST', /^TEST_/
          part.edge_front ||= make_edge(edge_t, edge_w, part)

        # Divisoria: borda frontal
        when 'CM_DIV', 'DIV'
          part.edge_front ||= make_edge(edge_t, edge_w, part)

        # Acessorios (ACES_*): sem fita — itens comprados prontos
        when /^ACES_/
          # Sem fita (aramados, vidros, ferragens, etc.)

        else
          # Tipo desconhecido: aplicar borda frontal como default conservador
          Core.logger&.warn(
            "EdgingEngine: código de peça desconhecido '#{part.code}' — " \
            "aplicando borda frontal como default conservador"
          )
          part.edge_front ||= make_edge(edge_t, edge_w, part)
        end
      rescue StandardError => e
        Core.logger&.error(
          "EdgingEngine#apply_to_part falhou para peça '#{part.code}': #{e.message}"
        )
      end

      # Retorna array com o estado das 4 bordas de uma peça.
      # Útil para exportação e exibição.
      # @param part [Domain::Part]
      # @return [Array<Hash>] array de 4 hashes com :side, :edge (EdgeSpec ou nil), :active
      def all_edges(part)
        [
          { side: :front, edge: part.edge_front, active: !part.edge_front.nil? },
          { side: :back,  edge: part.edge_back,  active: !part.edge_back.nil? },
          { side: :left,  edge: part.edge_left,  active: !part.edge_left.nil? },
          { side: :right, edge: part.edge_right, active: !part.edge_right.nil? }
        ]
      rescue StandardError => e
        Core.logger&.error("EdgingEngine#all_edges falhou: #{e.message}")
        []
      end

      # Calcula código de acabamento de fita (UpMobb compatível).
      # @param part [Domain::Part]
      # @return [String] ex: "1C", "4Lados", "1C+2L"
      def edgeband_finish_code(part)
        sides = {
          front: part.edge_front, back: part.edge_back,
          left: part.edge_left, right: part.edge_right
        }
        active = sides.select { |_, v| v }

        case active.length
        when 0 then 'SEM_FITA'
        when 1
          active.key?(:front) || active.key?(:back) ? '1C' : '1L'
        when 2
          compridos = [:front, :back].count { |s| active.key?(s) }
          largos = [:left, :right].count { |s| active.key?(s) }
          if compridos == 2
            '2C'
          elsif compridos == 1 && largos == 1
            '1C+1L'
          else
            '2L'
          end
        when 3
          compridos = [:front, :back].count { |s| active.key?(s) }
          if compridos == 2
            '2C+1L'
          else
            '1C+2L'
          end
        when 4
          '4Lados'
        else
          'SEM_FITA'
        end
      rescue StandardError => e
        Core.logger&.error("EdgingEngine#edgeband_finish_code falhou: #{e.message}")
        'SEM_FITA'
      end

      # Calcula total de fita linear para uma peça.
      # @param part [Domain::Part]
      # @return [Float] metros lineares
      def edgeband_linear_meters(part)
        total = 0.0
        total += part.cut_length if part.edge_front
        total += part.cut_length if part.edge_back
        total += part.cut_width if part.edge_left
        total += part.cut_width if part.edge_right
        total / 1000.0
      rescue StandardError => e
        Core.logger&.error("EdgingEngine#edgeband_linear_meters falhou: #{e.message}")
        0.0
      end

      private

      # Resolve material/cor da fita de borda a partir do catálogo, se disponível.
      # @param part [Domain::Part, nil] peça para buscar material correspondente
      # @return [Array(String, String)] [material_id, color] ou [nil, nil]
      def resolve_edgeband_from_catalog(part)
        return [nil, nil] unless part&.material_id

        edgeband = Core.catalog&.edgebands_for_material(part.material_id)&.first
        return [nil, nil] unless edgeband

        [edgeband.material_id, edgeband.respond_to?(:finish) ? edgeband.finish : edgeband.respond_to?(:color) ? edgeband.color : nil]
      rescue StandardError
        [nil, nil]
      end

      def make_edge(thickness, width, part = nil)
        mat_id, finish = resolve_edgeband_from_catalog(part)

        Domain::EdgeSpec.new(
          applied: true,
          thickness_mm: thickness,
          width_mm: width,
          material_id: mat_id,
          finish: finish
        )
      rescue StandardError => e
        Core.logger&.error("EdgingEngine#make_edge falhou: #{e.message}")
        Domain::EdgeSpec.new(
          applied: true,
          thickness_mm: thickness,
          width_mm: width,
          material_id: nil,
          finish: nil
        )
      end
    end
  end
end
