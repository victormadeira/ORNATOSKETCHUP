# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# domain/opening.rb — Vão paramétrico (espaço interno de um módulo)
#
# Um Opening representa um espaço retangular 3D dentro de um módulo
# que pode conter agregados (prateleiras, gavetas, portas) ou ser
# subdividido por divisórias verticais/horizontais em sub-openings.
#
# Hierarquia:
#   Module → Opening (raiz) → sub-openings (recursivo)
#                            → aggregates (folhas)
#
# Divisão:
#   - divide_vertical   → corta na largura (esquerda/direita)
#   - divide_horizontal → corta na altura  (inferior/superior)
#   - Cada divisão cria exatamente 2 sub-openings
#   - Divisórias têm espessura real (mm) que consome espaço
#
# Coordenadas:
#   x_mm, y_mm, z_mm são posições relativas ao canto inferior-esquerdo-frontal
#   do módulo pai. x = largura, y = profundidade, z = altura.

module Ornato
  module Domain
    class Opening
      include EntityContract

      attr_accessor :ornato_id, :parent_id, :x_mm, :y_mm, :z_mm,
                    :width_mm, :height_mm, :depth_mm,
                    :aggregates, :sub_openings,
                    :parent_opening_id, :division_type, :division_position_mm,
                    :created_at, :updated_at

      # Cria um novo Opening (vão).
      #
      # @param parent_id [String] ornato_id do módulo ou entidade pai
      # @param x_mm [Numeric] posição X relativa ao módulo (mm)
      # @param y_mm [Numeric] posição Y relativa ao módulo (mm)
      # @param z_mm [Numeric] posição Z relativa ao módulo (mm)
      # @param width_mm [Numeric] largura do vão (mm)
      # @param height_mm [Numeric] altura do vão (mm)
      # @param depth_mm [Numeric] profundidade do vão (mm)
      # @param parent_opening_id [String, nil] ornato_id do opening pai (se sub-opening)
      def initialize(parent_id:, x_mm:, y_mm:, z_mm:,
                     width_mm:, height_mm:, depth_mm:,
                     parent_opening_id: nil)
        @ornato_id = Core::Ids.generate
        @parent_id = parent_id
        @x_mm = x_mm.to_f
        @y_mm = y_mm.to_f
        @z_mm = z_mm.to_f
        @width_mm = width_mm.to_f
        @height_mm = height_mm.to_f
        @depth_mm = depth_mm.to_f
        @aggregates = []
        @sub_openings = []
        @parent_opening_id = parent_opening_id
        @division_type = nil            # :vertical ou :horizontal (nil se não dividido)
        @division_position_mm = nil     # posição da divisória em mm (do lado esquerdo ou da base)
        @created_at = Time.now.iso8601
        @updated_at = @created_at
      end

      def entity_type; :opening; end
      def schema_version; 1; end

      # ── Consultas geométricas ──────────────────────────────────────────

      # Opening é folha (não subdividido)?
      # Um opening folha pode receber agregados.
      #
      # @return [Boolean]
      def leaf?
        @sub_openings.empty?
      end

      # Retorna todos os openings-folha recursivamente.
      # Se este opening é folha, retorna [self].
      # Se subdividido, desce recursivamente nos sub-openings.
      #
      # @return [Array<Opening>]
      def leaf_openings
        return [self] if leaf?
        @sub_openings.flat_map(&:leaf_openings)
      end

      # Área da face frontal em mm2.
      #
      # @return [Float]
      def area_mm2
        @width_mm * @height_mm
      end

      # Volume interno em mm3.
      #
      # @return [Float]
      def volume_mm3
        @width_mm * @height_mm * @depth_mm
      end

      # Verifica se um ponto 2D (px, pz) está dentro do opening.
      # Usa coordenadas X (largura) e Z (altura) relativas ao módulo.
      #
      # @param px [Numeric] coordenada X em mm
      # @param pz [Numeric] coordenada Z em mm
      # @return [Boolean]
      def contains_point?(px, pz)
        px >= @x_mm && px <= (@x_mm + @width_mm) &&
          pz >= @z_mm && pz <= (@z_mm + @height_mm)
      end

      # Altura livre restante após subtrair agregados que ocupam altura
      # (prateleiras fixas, divisórias horizontais).
      # Em openings folha, desconta a altura dos agregados que possuem
      # o atributo :height_mm (prateleiras, gavetas com frente).
      #
      # @return [Float] altura livre em mm
      def free_height_mm
        return @height_mm unless leaf?
        occupied = @aggregates.sum do |agg|
          agg.respond_to?(:height_mm) ? agg.height_mm.to_f : 0.0
        end
        @height_mm - occupied
      end

      # ── Divisão ────────────────────────────────────────────────────────

      # Divide o opening verticalmente (cria esquerdo e direito).
      # A divisória fica na posição indicada, medida a partir do lado esquerdo.
      #
      # @param position_mm [Numeric] posição da divisória (mm do lado esquerdo)
      # @param divider_thickness [Numeric] espessura da divisória (mm, default 18)
      # @return [Array<Opening>] [opening_esquerdo, opening_direito]
      # @raise [Core::DomainError] se posição inválida ou já subdividido
      def divide_vertical(position_mm, divider_thickness: 18.0)
        validate_division!(:vertical, position_mm, @width_mm, divider_thickness)

        @division_type = :vertical
        @division_position_mm = position_mm.to_f

        half_div = divider_thickness.to_f / 2.0
        width_left = position_mm.to_f - half_div
        width_right = @width_mm - position_mm.to_f - half_div

        left = Opening.new(
          parent_id: @parent_id,
          x_mm: @x_mm,
          y_mm: @y_mm,
          z_mm: @z_mm,
          width_mm: width_left,
          height_mm: @height_mm,
          depth_mm: @depth_mm,
          parent_opening_id: @ornato_id
        )

        right = Opening.new(
          parent_id: @parent_id,
          x_mm: @x_mm + position_mm.to_f + half_div,
          y_mm: @y_mm,
          z_mm: @z_mm,
          width_mm: width_right,
          height_mm: @height_mm,
          depth_mm: @depth_mm,
          parent_opening_id: @ornato_id
        )

        @sub_openings = [left, right]
        @updated_at = Time.now.iso8601
        [left, right]
      end

      # Divide o opening horizontalmente (cria inferior e superior).
      # A divisória fica na posição indicada, medida a partir da base.
      #
      # @param position_mm [Numeric] posição da divisória (mm da base)
      # @param divider_thickness [Numeric] espessura da divisória (mm, default 18)
      # @return [Array<Opening>] [opening_inferior, opening_superior]
      # @raise [Core::DomainError] se posição inválida ou já subdividido
      def divide_horizontal(position_mm, divider_thickness: 18.0)
        validate_division!(:horizontal, position_mm, @height_mm, divider_thickness)

        @division_type = :horizontal
        @division_position_mm = position_mm.to_f

        half_div = divider_thickness.to_f / 2.0
        height_bottom = position_mm.to_f - half_div
        height_top = @height_mm - position_mm.to_f - half_div

        bottom = Opening.new(
          parent_id: @parent_id,
          x_mm: @x_mm,
          y_mm: @y_mm,
          z_mm: @z_mm,
          width_mm: @width_mm,
          height_mm: height_bottom,
          depth_mm: @depth_mm,
          parent_opening_id: @ornato_id
        )

        top = Opening.new(
          parent_id: @parent_id,
          x_mm: @x_mm,
          y_mm: @y_mm,
          z_mm: @z_mm + position_mm.to_f + half_div,
          width_mm: @width_mm,
          height_mm: height_top,
          depth_mm: @depth_mm,
          parent_opening_id: @ornato_id
        )

        @sub_openings = [bottom, top]
        @updated_at = Time.now.iso8601
        [bottom, top]
      end

      # ── Busca recursiva ────────────────────────────────────────────────

      # Encontra um opening por ornato_id, buscando recursivamente
      # nos sub-openings.
      #
      # @param id [String] ornato_id do opening procurado
      # @return [Opening, nil]
      def find_opening(id)
        return self if @ornato_id == id
        @sub_openings.each do |sub|
          found = sub.find_opening(id)
          return found if found
        end
        nil
      end

      # Encontra o opening-folha que contém o ponto 2D (px, pz).
      # Busca recursivamente nos sub-openings.
      #
      # @param px [Numeric] coordenada X em mm
      # @param pz [Numeric] coordenada Z em mm
      # @return [Opening, nil]
      def find_leaf_at(px, pz)
        return nil unless contains_point?(px, pz)
        if leaf?
          self
        else
          @sub_openings.each do |sub|
            found = sub.find_leaf_at(px, pz)
            return found if found
          end
          nil
        end
      end

      # ── Agregados ──────────────────────────────────────────────────────

      # Adiciona um agregado a este opening (somente se folha).
      #
      # @param aggregate [Object] entidade de agregado
      # @raise [Core::DomainError] se o opening não é folha
      def add_aggregate(aggregate)
        unless leaf?
          raise Core::DomainError,
            "Não é possível adicionar agregado a um opening subdividido (#{@ornato_id})"
        end
        @aggregates << aggregate
        @updated_at = Time.now.iso8601
        aggregate
      end

      # Remove um agregado pelo ornato_id.
      #
      # @param aggregate_id [String] ornato_id do agregado
      # @return [Object, nil] agregado removido ou nil
      def remove_aggregate(aggregate_id)
        removed = nil
        @aggregates.reject! do |agg|
          if agg.respond_to?(:ornato_id) && agg.ornato_id == aggregate_id
            removed = agg
            true
          else
            false
          end
        end
        @updated_at = Time.now.iso8601 if removed
        removed
      end

      # Retorna todos os agregados deste opening e de todos os
      # sub-openings recursivamente.
      #
      # @return [Array<Object>]
      def all_aggregates
        own = @aggregates.dup
        @sub_openings.each do |sub|
          own.concat(sub.all_aggregates)
        end
        own
      end

      # ── Serialização ───────────────────────────────────────────────────

      def to_hash
        {
          ornato_id: @ornato_id,
          parent_id: @parent_id,
          parent_opening_id: @parent_opening_id,
          x_mm: @x_mm,
          y_mm: @y_mm,
          z_mm: @z_mm,
          width_mm: @width_mm,
          height_mm: @height_mm,
          depth_mm: @depth_mm,
          area_mm2: area_mm2,
          volume_mm3: volume_mm3,
          leaf: leaf?,
          division_type: @division_type,
          division_position_mm: @division_position_mm,
          aggregate_ids: @aggregates.map { |a| a.respond_to?(:ornato_id) ? a.ornato_id : a.to_s },
          aggregate_count: @aggregates.length,
          sub_opening_ids: @sub_openings.map(&:ornato_id),
          sub_openings: @sub_openings.map(&:to_hash),
          created_at: @created_at,
          updated_at: @updated_at,
          schema_version: schema_version
        }
      end

      # ── Validação de schema ────────────────────────────────────────────

      def validate_schema
        errors = super
        errors << { field: :width_mm,  msg: 'deve ser positivo' } unless @width_mm > 0
        errors << { field: :height_mm, msg: 'deve ser positivo' } unless @height_mm > 0
        errors << { field: :depth_mm,  msg: 'deve ser positivo' } unless @depth_mm > 0
        errors << { field: :parent_id, msg: 'ausente' } if @parent_id.nil? || @parent_id.to_s.empty?
        errors
      end

      private

      # Valida se a divisão é possível.
      #
      # @param direction [Symbol] :vertical ou :horizontal
      # @param position_mm [Numeric] posição da divisória
      # @param total_mm [Numeric] dimensão total (largura ou altura)
      # @param divider_thickness [Numeric] espessura da divisória
      # @raise [Core::DomainError] se divisão inválida
      def validate_division!(direction, position_mm, total_mm, divider_thickness)
        unless leaf?
          raise Core::DomainError,
            "Opening #{@ornato_id} já foi subdividido (#{@division_type}). " \
            "Não é possível dividir novamente."
        end

        half_div = divider_thickness.to_f / 2.0
        min_pos = half_div + 1.0   # mínimo 1mm de espaço útil
        max_pos = total_mm - half_div - 1.0

        if position_mm.to_f < min_pos || position_mm.to_f > max_pos
          label = direction == :vertical ? 'largura' : 'altura'
          raise Core::DomainError,
            "Posição de divisão #{direction} inválida: #{position_mm}mm. " \
            "Faixa válida para #{label} #{total_mm}mm com divisória de " \
            "#{divider_thickness}mm: #{min_pos.round(1)}–#{max_pos.round(1)}mm."
        end
      end
    end
  end
end
