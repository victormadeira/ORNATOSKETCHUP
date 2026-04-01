# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# domain/machine_profile.rb — Perfil de máquina CNC de produção
#
# Modela as capacidades, limites e ferramental de uma máquina CNC.
# Usado para validação de elegibilidade CAM antes de exportar:
#   - A peça cabe na área de trabalho?
#   - A máquina tem a ferramenta necessária?
#   - A operação é suportada?
#   - A profundidade não excede o limite?

module Ornato
  module Domain
    class MachineProfile
      include EntityContract

      # Especificação de ferramenta disponível na máquina.
      ToolSpec = Struct.new(
        :id,                 # String: identificador único (ex: "f_5mm", "f_35mm_dob")
        :type,               # Symbol: :broca, :fresa, :disco, :forstner
        :diameter_mm,        # Float: diâmetro em mm
        :max_depth_mm,       # Float: profundidade máxima
        :rpm,                # Integer: rotação padrão
        :feed_rate,          # Float: avanço mm/min
        :magazine_position,  # Integer, nil: posição no magazine automático
        keyword_init: true
      ) do
        def to_hash
          {
            id: id, type: type, diameter_mm: diameter_mm,
            max_depth_mm: max_depth_mm, rpm: rpm,
            feed_rate: feed_rate, magazine_position: magazine_position
          }
        end
      end

      attr_accessor :ornato_id, :name, :version,
                    :work_area_x_mm, :work_area_y_mm,
                    :supported_thicknesses, :origin, :primary_face,
                    :tools, :max_depth_mm,
                    :allowed_operations, :forbidden_operations,
                    :tolerances, :post_processor, :properties

      def initialize(name:)
        @ornato_id = Core::Ids.generate
        @name = name
        @version = 1
        @work_area_x_mm = 3100.0   # mm — comprimento útil (padrão CNC)
        @work_area_y_mm = 1600.0   # mm — largura útil
        @supported_thicknesses = [3, 6, 9, 12, 15, 18, 25]
        @origin = :bottom_left     # :bottom_left, :top_left, :center
        @primary_face = :top       # face voltada para cima na máquina
        @tools = []
        @max_depth_mm = 50.0
        @allowed_operations = Core::Constants::OPERATION_TYPES.dup
        @forbidden_operations = []
        @tolerances = {
          position_mm: 0.1,    # tolerância de posicionamento
          depth_mm: 0.05,      # tolerância de profundidade
          diameter_mm: 0.02    # tolerância de diâmetro
        }
        @post_processor = :generic  # :generic, :biesse, :homag, :scm, :weeke, :morbidelli
        @properties = {}
      end

      def entity_type; :machine_profile; end
      def schema_version; 1; end

      # Adiciona ferramenta ao perfil.
      def add_tool(id:, type:, diameter_mm:, max_depth_mm: nil,
                   rpm: nil, feed_rate: nil, magazine_position: nil)
        tool = ToolSpec.new(
          id: id, type: type.to_sym, diameter_mm: diameter_mm.to_f,
          max_depth_mm: (max_depth_mm || @max_depth_mm).to_f,
          rpm: rpm&.to_i, feed_rate: feed_rate&.to_f,
          magazine_position: magazine_position&.to_i
        )
        @tools << tool
        tool
      end

      # Remove ferramenta por ID.
      def remove_tool(tool_id)
        @tools.reject! { |t| t.id == tool_id }
      end

      # Busca ferramenta por ID.
      # @return [ToolSpec, nil]
      def find_tool(tool_id)
        @tools.find { |t| t.id == tool_id }
      end

      # Busca ferramenta por diâmetro e tipo.
      # @return [ToolSpec, nil]
      def find_tool_by_spec(type:, diameter_mm:)
        @tools.find { |t| t.type == type.to_sym && (t.diameter_mm - diameter_mm).abs < 0.01 }
      end

      # Lista ferramentas por tipo.
      # @param type [Symbol]
      # @return [Array<ToolSpec>]
      def tools_by_type(type)
        @tools.select { |t| t.type == type.to_sym }
      end

      # Verifica se a máquina suporta uma espessura de material.
      def supports_thickness?(thickness)
        @supported_thicknesses.include?(thickness.to_i)
      end

      # Verifica se a máquina suporta um tipo de operação.
      def supports_operation?(operation_type)
        op = operation_type.to_sym
        @allowed_operations.include?(op) && !@forbidden_operations.include?(op)
      end

      # Valida se uma operação pode ser executada nesta máquina.
      # @param operation [Operation]
      # @return [Array<String>] lista de erros (vazia = OK)
      def validate_operation(operation)
        errors = []

        unless supports_operation?(operation.operation_type)
          errors << "Operação #{operation.operation_type} não suportada pela máquina #{@name}"
        end

        tool = find_tool(operation.tool_id)
        unless tool
          # Tentar encontrar ferramenta compatível
          compatible = find_tool_by_spec(
            type: operation.drilling? ? :broca : :fresa,
            diameter_mm: operation.tool_diameter_mm
          )
          if compatible
            errors << "Ferramenta #{operation.tool_id} não encontrada, mas #{compatible.id} é compatível"
          else
            errors << "Ferramenta #{operation.tool_id} (Ø#{operation.tool_diameter_mm}mm) não disponível na máquina #{@name}"
          end
        end

        if operation.depth_mm > @max_depth_mm
          errors << "Profundidade #{operation.depth_mm}mm excede máximo da máquina #{@max_depth_mm}mm"
        end

        if tool && operation.depth_mm > tool.max_depth_mm
          errors << "Profundidade #{operation.depth_mm}mm excede máximo da ferramenta #{tool.id} (#{tool.max_depth_mm}mm)"
        end

        errors
      end

      # Valida se uma peça cabe na área de trabalho.
      # @param part [Part]
      # @return [Array<String>] lista de erros (vazia = OK)
      def validate_part_dimensions(part)
        errors = []

        if part.cut_length > @work_area_x_mm
          errors << "Comprimento da peça #{part.cut_length}mm excede área X da máquina #{@work_area_x_mm}mm"
        end

        if part.cut_width > @work_area_y_mm
          errors << "Largura da peça #{part.cut_width}mm excede área Y da máquina #{@work_area_y_mm}mm"
        end

        unless supports_thickness?(part.thickness_nominal)
          errors << "Espessura #{part.thickness_nominal}mm não suportada. Suportadas: #{@supported_thicknesses.join(', ')}mm"
        end

        errors
      end

      # Avalia elegibilidade CAM completa de uma peça com suas operações.
      # @param part [Part]
      # @param operations [Array<Operation>] operações da peça
      # @return [Hash] { eligible: Boolean, errors: [], warnings: [] }
      def evaluate_cam_readiness(part, operations)
        errors = validate_part_dimensions(part)
        warnings = []

        operations.each do |op|
          op_errors = validate_operation(op)
          if op_errors.any?
            # Se tem ferramenta compatível, é warning; senão, é error
            compatible = find_tool_by_spec(
              type: op.drilling? ? :broca : :fresa,
              diameter_mm: op.tool_diameter_mm
            )
            if compatible
              warnings.concat(op_errors)
            else
              errors.concat(op_errors)
            end
          end
        end

        {
          eligible: errors.empty?,
          errors: errors,
          warnings: warnings
        }
      end

      def validate_schema
        errors = super
        errors << { field: :name, msg: 'ausente' } if @name.nil? || @name.empty?
        errors << { field: :work_area_x_mm, msg: 'deve ser > 0' } unless @work_area_x_mm > 0
        errors << { field: :work_area_y_mm, msg: 'deve ser > 0' } unless @work_area_y_mm > 0
        errors << { field: :tools, msg: 'nenhuma ferramenta definida' } if @tools.empty?
        errors
      end

      def to_hash
        {
          ornato_id: @ornato_id, name: @name, version: @version,
          work_area_x_mm: @work_area_x_mm, work_area_y_mm: @work_area_y_mm,
          supported_thicknesses: @supported_thicknesses,
          origin: @origin, primary_face: @primary_face,
          tools: @tools.map(&:to_hash),
          tool_count: @tools.length,
          max_depth_mm: @max_depth_mm,
          allowed_operations: @allowed_operations,
          forbidden_operations: @forbidden_operations,
          tolerances: @tolerances,
          post_processor: @post_processor,
          properties: @properties,
          schema_version: schema_version
        }
      end

      # Cria perfil padrão de uma CNC básica brasileira.
      def self.default_cnc
        profile = new(name: 'CNC Padrão')
        profile.add_tool(id: 'f_3mm_canal', type: :fresa, diameter_mm: 3.0, max_depth_mm: 20.0, rpm: 18000, feed_rate: 3.0)
        profile.add_tool(id: 'f_5mm', type: :broca, diameter_mm: 5.0, max_depth_mm: 30.0, rpm: 6000, feed_rate: 1.5)
        profile.add_tool(id: 'f_6mm_canal', type: :fresa, diameter_mm: 6.0, max_depth_mm: 25.0, rpm: 18000, feed_rate: 4.0)
        profile.add_tool(id: 'f_8mm_cavilha', type: :broca, diameter_mm: 8.0, max_depth_mm: 35.0, rpm: 6000, feed_rate: 1.5)
        profile.add_tool(id: 'f_10mm', type: :fresa, diameter_mm: 10.0, max_depth_mm: 30.0, rpm: 18000, feed_rate: 5.0)
        profile.add_tool(id: 'f_12mm', type: :fresa, diameter_mm: 12.0, max_depth_mm: 30.0, rpm: 18000, feed_rate: 5.0)
        profile.add_tool(id: 'f_15mm_tambor_min', type: :forstner, diameter_mm: 15.0, max_depth_mm: 14.0, rpm: 1500, feed_rate: 1.0)
        profile.add_tool(id: 'f_35mm_dob', type: :forstner, diameter_mm: 35.0, max_depth_mm: 13.0, rpm: 1500, feed_rate: 1.0)
        profile
      end
    end
  end
end
