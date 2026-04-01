# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# domain/mod_entity.rb — Entidade de módulo (caixa paramétrica)
#
# ModEntity representa um módulo de marcenaria completo: balcão, aéreo,
# torre, roupeiro, gaveteiro, nicho, painel, tampo, rodapé ou canto.
#
# NOTA: O nome "ModEntity" evita colisão com a palavra reservada "Module"
# do Ruby. Em toda a documentação e UI, usar "módulo" normalmente.
#
# Hierarquia: Project → Environment → ModEntity → Openings → Aggregates → Parts
#
# O módulo é o nó central do grafo paramétrico. Ele contém:
#   - Openings (vãos internos que recebem agregados)
#   - Parts (peças de corte geradas pela receita + agregados)
#   - HardwareItems (ferragens geradas pelos agregados)
#   - Operations (operações CNC geradas pelos agregados)
#
# Tipos (Core::Constants::MODULE_TYPES):
#   :balcao, :aereo, :torre, :roupeiro, :gaveteiro,
#   :nicho, :painel, :tampo, :rodape, :canto
#
# Estados (Core::Constants::MODULE_STATES):
#   :draft       — em edição, pode ser alterado livremente
#   :validated   — passou na validação, pronto para exportar
#   :ready_for_export — exportável, não pode ser editado sem nova revisão
#
# Tipos de montagem (Core::Constants::ASSEMBLY_TYPES):
#   :brasil — laterais ENTRE base e topo (padrão brasileiro)
#   :europa — base e topo ENTRE laterais (padrão europeu)
#
# Tipos de fundo (Core::Constants::BACK_TYPES):
#   :encaixado  — em canal (rasgo nas laterais/base)
#   :sobreposto — parafusado na traseira
#   :nenhum     — sem fundo (closet aberto)
#
# Tipos de base (Core::Constants::BASE_TYPES):
#   :rodape — rodapé de MDF
#   :pes    — pés reguláveis
#   :direto — apoiado diretamente no chão/parede

module Ornato
  module Domain
    class ModEntity
      include EntityContract

      # ── Constantes reexportadas ──────────────────────────────────────

      MODULE_TYPES = Core::Constants::MODULE_TYPES
      STATES       = Core::Constants::MODULE_STATES

      # ── Atributos de identidade ──────────────────────────────────────

      attr_accessor :ornato_id, :project_id, :environment_id,
                    :recipe_id, :ruleset_id, :ruleset_version,
                    :persistent_id, :pid_path, :revision_id

      # ── Atributos de design ──────────────────────────────────────────

      attr_accessor :name, :module_type,
                    :width_mm, :height_mm, :depth_mm,
                    :position, :rotation_deg, :mirrored

      # ── Atributos de construção ──────────────────────────────────────

      attr_accessor :assembly_type,
                    :body_material_id, :front_material_id, :back_material_id,
                    :body_thickness, :back_type, :back_thickness,
                    :base_type, :base_height_mm

      # ── Coleções internas ────────────────────────────────────────────

      attr_accessor :openings, :parts, :hardware_items, :operations

      # ── Estado e metadados ───────────────────────────────────────────

      attr_accessor :state, :validation_result, :export_hash,
                    :created_at, :updated_at

      # Cria um novo módulo paramétrico.
      #
      # @param name [String] nome descritivo do módulo (ex: "Balcão Cozinha 80cm")
      # @param module_type [Symbol] tipo do módulo (ver MODULE_TYPES)
      # @param width_mm [Numeric] largura externa em mm
      # @param height_mm [Numeric] altura externa em mm
      # @param depth_mm [Numeric] profundidade externa em mm
      # @param project_id [String, nil] ornato_id do projeto pai
      # @param environment_id [String, nil] ornato_id do ambiente pai
      # @param recipe_id [String, nil] ornato_id da receita que gerou este módulo
      # @param ruleset_id [String, nil] ornato_id do ruleset ativo
      # @param ruleset_version [Integer] versão do ruleset usada
      # @param assembly_type [Symbol] tipo de montagem (:brasil ou :europa)
      # @param body_material_id [String, nil] material do corpo (laterais, base, topo)
      # @param front_material_id [String, nil] material das frentes (portas, gavetas)
      # @param back_material_id [String, nil] material do fundo
      # @param body_thickness [Numeric] espessura nominal do corpo em mm
      # @param back_type [Symbol] tipo de fundo (:encaixado, :sobreposto, :nenhum)
      # @param back_thickness [Numeric] espessura nominal do fundo em mm
      # @param base_type [Symbol] tipo de base (:rodape, :pes, :direto)
      # @param base_height_mm [Numeric] altura da base/rodapé em mm
      # @param position [Hash, nil] posição 3D { x:, y:, z: } em mm (relativa ao ambiente)
      # @param rotation_deg [Numeric] rotação em graus no plano horizontal
      # @param mirrored [Boolean] espelhado horizontalmente?
      def initialize(name:, module_type:, width_mm:, height_mm:, depth_mm:,
                     project_id: nil, environment_id: nil,
                     recipe_id: nil, ruleset_id: nil, ruleset_version: 0,
                     assembly_type: :brasil,
                     body_material_id: nil, front_material_id: nil, back_material_id: nil,
                     body_thickness: 15, back_type: :encaixado, back_thickness: 3,
                     base_type: :rodape, base_height_mm: 100.0,
                     position: nil, rotation_deg: 0.0, mirrored: false)
        unless MODULE_TYPES.include?(module_type.to_sym)
          raise Core::DomainError,
            "Tipo de módulo inválido: #{module_type}. Válidos: #{MODULE_TYPES.join(', ')}",
            code: 'INVALID_MODULE_TYPE',
            context: { given: module_type, valid: MODULE_TYPES }
        end

        # Identidade
        @ornato_id       = Core::Ids.generate
        @project_id      = project_id
        @environment_id  = environment_id
        @recipe_id       = recipe_id
        @ruleset_id      = ruleset_id
        @ruleset_version = ruleset_version.to_i
        @persistent_id   = nil
        @pid_path        = nil
        @revision_id     = nil

        # Design
        @name         = name
        @module_type  = module_type.to_sym
        @width_mm     = width_mm.to_f
        @height_mm    = height_mm.to_f
        @depth_mm     = depth_mm.to_f
        @position     = position || { x: 0.0, y: 0.0, z: 0.0 }
        @rotation_deg = rotation_deg.to_f
        @mirrored     = mirrored

        # Construção
        @assembly_type    = assembly_type.to_sym
        @body_material_id = body_material_id
        @front_material_id = front_material_id
        @back_material_id = back_material_id
        @body_thickness   = body_thickness.to_i
        @back_type        = back_type.to_sym
        @back_thickness   = back_thickness.to_i
        @base_type        = base_type.to_sym
        @base_height_mm   = base_height_mm.to_f

        # Coleções
        @openings       = []
        @parts          = []
        @hardware_items = []
        @operations     = []

        # Estado
        @state             = :draft
        @validation_result = nil
        @export_hash       = nil
        @created_at        = Time.now.iso8601
        @updated_at        = @created_at
      end

      # ── EntityContract ───────────────────────────────────────────────

      def entity_type; :module; end
      def schema_version; 1; end

      # ── Dimensões internas (descontando espessuras reais) ────────────

      # Largura interna útil em mm.
      # Desconta 2 laterais (espessura real) no modo europa,
      # ou 2 laterais no modo brasil.
      # @return [Float]
      def internal_width_mm
        real_body = Core::Config.real_thickness(@body_thickness)
        @width_mm - (2.0 * real_body)
      end

      # Altura interna útil em mm.
      # Desconta base + topo (espessura real) no modo europa (base/topo entre laterais),
      # ou base + topo no modo brasil (laterais entre base e topo).
      # @return [Float]
      def internal_height_mm
        real_body = Core::Config.real_thickness(@body_thickness)
        base_deduction = @base_type == :rodape ? @base_height_mm : 0.0
        @height_mm - (2.0 * real_body) - base_deduction
      end

      # Profundidade interna útil em mm.
      # Desconta fundo (se encaixado ou sobreposto) da profundidade total.
      # @return [Float]
      def internal_depth_mm
        back_deduction = case @back_type
                         when :encaixado
                           Core::Config.real_thickness(@back_thickness)
                         when :sobreposto
                           Core::Config.real_thickness(@back_thickness)
                         when :nenhum
                           0.0
                         else
                           0.0
                         end
        @depth_mm - back_deduction
      end

      # ── Contagens e métricas ─────────────────────────────────────────

      # Total de peças de corte neste módulo (incluindo quantidade > 1).
      # @return [Integer]
      def total_parts_count
        @parts.sum { |p| p.respond_to?(:quantity) ? p.quantity : 1 }
      end

      # Área total de chapa em m2 (considerando quantidade de cada peça).
      # @return [Float]
      def total_area_m2
        @parts.sum do |p|
          w = p.respond_to?(:width_mm) ? p.width_mm : 0.0
          h = p.respond_to?(:height_mm) ? p.height_mm : 0.0
          qty = p.respond_to?(:quantity) ? p.quantity : 1
          (w * h / 1_000_000.0) * qty
        end
      end

      # Metros lineares totais de fita de borda neste módulo.
      # Soma perímetros das bordas com fita, considerando quantidade.
      # @return [Float]
      def total_edgeband_meters
        @parts.sum do |p|
          next 0.0 unless p.respond_to?(:edgeband) && p.respond_to?(:width_mm) && p.respond_to?(:height_mm)
          eb = p.edgeband
          next 0.0 unless eb.is_a?(Hash)
          qty = p.respond_to?(:quantity) ? p.quantity : 1
          w = p.width_mm.to_f
          h = p.height_mm.to_f
          linear = 0.0
          linear += w if eb[:front]
          linear += w if eb[:back]
          linear += h if eb[:top]
          linear += h if eb[:bottom]
          (linear / 1000.0) * qty
        end
      end

      # ── Filtragem de peças ───────────────────────────────────────────

      # Peças estruturais (laterais, base, topo, divisórias fixas).
      # @return [Array]
      def structural_parts
        @parts.select { |p| p.respond_to?(:part_type) && p.part_type == :structural }
      end

      # Peças de frente (portas, frentes de gaveta).
      # @return [Array]
      def front_parts
        @parts.select do |p|
          p.respond_to?(:part_type) && %i[front drawer].include?(p.part_type)
        end
      end

      # ── Agregados (de todas as aberturas) ────────────────────────────

      # Coleta todos os agregados de todas as aberturas recursivamente.
      # @return [Array<Aggregate>]
      def all_aggregates
        @openings.flat_map do |opening|
          if opening.respond_to?(:all_aggregates)
            opening.all_aggregates
          elsif opening.respond_to?(:aggregates)
            opening.aggregates
          else
            []
          end
        end
      end

      # ── Busca por ID ─────────────────────────────────────────────────

      # Encontra uma peça pelo ornato_id.
      # @param id [String] ornato_id da peça
      # @return [Part, nil]
      def find_part(id)
        @parts.find { |p| p.respond_to?(:ornato_id) && p.ornato_id == id }
      end

      # Encontra uma abertura pelo ornato_id.
      # @param id [String] ornato_id da abertura
      # @return [Opening, nil]
      def find_opening(id)
        @openings.find { |o| o.respond_to?(:ornato_id) && o.ornato_id == id }
      end

      # Encontra um agregado pelo ornato_id em qualquer abertura.
      # @param id [String] ornato_id do agregado
      # @return [Aggregate, nil]
      def find_aggregate(id)
        all_aggregates.find { |a| a.respond_to?(:ornato_id) && a.ornato_id == id }
      end

      # Encontra uma ferragem pelo ornato_id.
      # @param id [String] ornato_id da ferragem
      # @return [HardwareItem, nil]
      def find_hardware(id)
        @hardware_items.find { |h| h.respond_to?(:ornato_id) && h.ornato_id == id }
      end

      # Encontra uma operação pelo ornato_id.
      # @param id [String] ornato_id da operação
      # @return [Operation, nil]
      def find_operation(id)
        @operations.find { |o| o.respond_to?(:ornato_id) && o.ornato_id == id }
      end

      # ── Gestão de estado ─────────────────────────────────────────────

      # O módulo pode ser editado?
      # @return [Boolean]
      def editable?
        @state == :draft
      end

      # O módulo está validado?
      # @return [Boolean]
      def validated?
        %i[validated ready_for_export].include?(@state)
      end

      # Transiciona estado do módulo.
      # @param new_state [Symbol]
      # @raise [Core::DomainError] se transição inválida
      def transition_to!(new_state)
        new_state = new_state.to_sym
        valid_transitions = {
          draft:            %i[validated],
          validated:        %i[draft ready_for_export],
          ready_for_export: %i[draft validated]
        }
        allowed = valid_transitions[@state] || []
        unless allowed.include?(new_state)
          raise Core::DomainError,
            "Transição de módulo inválida: #{@state} → #{new_state}. Permitidas: #{allowed}",
            code: 'INVALID_MODULE_TRANSITION',
            context: { from: @state, to: new_state, allowed: allowed }
        end
        @state = new_state
        @updated_at = Time.now.iso8601
      end

      # ── Validação de schema ──────────────────────────────────────────

      # Valida estrutura do módulo (não regras de negócio).
      # @return [Array<Hash>] erros encontrados ({ field:, msg: })
      def validate_schema
        errors = super

        # Dimensões devem ser positivas
        errors << { field: :width_mm, msg: 'deve ser > 0' } unless @width_mm > 0
        errors << { field: :height_mm, msg: 'deve ser > 0' } unless @height_mm > 0
        errors << { field: :depth_mm, msg: 'deve ser > 0' } unless @depth_mm > 0

        # Tipo deve ser válido
        unless MODULE_TYPES.include?(@module_type)
          errors << { field: :module_type, msg: "inválido: #{@module_type}" }
        end

        # Nome obrigatório
        errors << { field: :name, msg: 'ausente' } if @name.nil? || @name.empty?

        # Tipo de montagem válido
        unless Core::Constants::ASSEMBLY_TYPES.include?(@assembly_type)
          errors << { field: :assembly_type, msg: "inválido: #{@assembly_type}" }
        end

        # Tipo de fundo válido
        unless Core::Constants::BACK_TYPES.include?(@back_type)
          errors << { field: :back_type, msg: "inválido: #{@back_type}" }
        end

        # Tipo de base válido
        unless Core::Constants::BASE_TYPES.include?(@base_type)
          errors << { field: :base_type, msg: "inválido: #{@base_type}" }
        end

        # Estado válido
        unless STATES.include?(@state)
          errors << { field: :state, msg: "inválido: #{@state}" }
        end

        # Espessuras válidas
        errors << { field: :body_thickness, msg: 'deve ser > 0' } unless @body_thickness > 0
        if @back_type != :nenhum
          errors << { field: :back_thickness, msg: 'deve ser > 0' } unless @back_thickness > 0
        end

        # Dimensões máximas razoáveis (evitar erros de input)
        errors << { field: :width_mm, msg: 'excede 6000mm' } if @width_mm > 6000
        errors << { field: :height_mm, msg: 'excede 3000mm' } if @height_mm > 3000
        errors << { field: :depth_mm, msg: 'excede 1200mm' } if @depth_mm > 1200

        errors
      end

      # ── Serialização ────────────────────────────────────────────────

      def to_hash
        {
          # Identidade
          ornato_id:       @ornato_id,
          project_id:      @project_id,
          environment_id:  @environment_id,
          recipe_id:       @recipe_id,
          ruleset_id:      @ruleset_id,
          ruleset_version: @ruleset_version,
          persistent_id:   @persistent_id,
          pid_path:        @pid_path,
          revision_id:     @revision_id,

          # Design
          name:         @name,
          module_type:  @module_type,
          width_mm:     @width_mm,
          height_mm:    @height_mm,
          depth_mm:     @depth_mm,
          position:     @position,
          rotation_deg: @rotation_deg,
          mirrored:     @mirrored,

          # Construção
          assembly_type:    @assembly_type,
          body_material_id: @body_material_id,
          front_material_id: @front_material_id,
          back_material_id: @back_material_id,
          body_thickness:   @body_thickness,
          back_type:        @back_type,
          back_thickness:   @back_thickness,
          base_type:        @base_type,
          base_height_mm:   @base_height_mm,

          # Coleções (IDs apenas para serialização leve)
          opening_ids:    @openings.map { |o| o.respond_to?(:ornato_id) ? o.ornato_id : o.to_s },
          part_ids:       @parts.map { |p| p.respond_to?(:ornato_id) ? p.ornato_id : p.to_s },
          hardware_ids:   @hardware_items.map { |h| h.respond_to?(:ornato_id) ? h.ornato_id : h.to_s },
          operation_ids:  @operations.map { |o| o.respond_to?(:ornato_id) ? o.ornato_id : o.to_s },

          # Contagens
          opening_count:   @openings.length,
          part_count:      @parts.length,
          hardware_count:  @hardware_items.length,
          operation_count: @operations.length,

          # Métricas calculadas
          internal_width_mm:     internal_width_mm.round(1),
          internal_height_mm:    internal_height_mm.round(1),
          internal_depth_mm:     internal_depth_mm.round(1),
          total_area_m2:         total_area_m2.round(4),
          total_edgeband_meters: total_edgeband_meters.round(3),

          # Estado
          state:             @state,
          validation_result: @validation_result,
          export_hash:       @export_hash,
          created_at:        @created_at,
          updated_at:        @updated_at,
          schema_version:    schema_version
        }
      end

      # Reconstrói um ModEntity a partir de hash serializado.
      # Coleções (openings, parts, hardware, operations) devem ser
      # reconstruídas separadamente e atribuídas após from_hash.
      #
      # @param data [Hash] dados serializados
      # @return [ModEntity]
      def self.from_hash(data)
        mod = allocate

        # Identidade
        mod.instance_variable_set(:@ornato_id,       data[:ornato_id])
        mod.instance_variable_set(:@project_id,      data[:project_id])
        mod.instance_variable_set(:@environment_id,  data[:environment_id])
        mod.instance_variable_set(:@recipe_id,       data[:recipe_id])
        mod.instance_variable_set(:@ruleset_id,      data[:ruleset_id])
        mod.instance_variable_set(:@ruleset_version, data[:ruleset_version].to_i)
        mod.instance_variable_set(:@persistent_id,   data[:persistent_id])
        mod.instance_variable_set(:@pid_path,        data[:pid_path])
        mod.instance_variable_set(:@revision_id,     data[:revision_id])

        # Design
        mod.instance_variable_set(:@name,         data[:name] || '')
        mod.instance_variable_set(:@module_type,  (data[:module_type] || :balcao).to_sym)
        mod.instance_variable_set(:@width_mm,     data[:width_mm].to_f)
        mod.instance_variable_set(:@height_mm,    data[:height_mm].to_f)
        mod.instance_variable_set(:@depth_mm,     data[:depth_mm].to_f)
        mod.instance_variable_set(:@position,     data[:position] || { x: 0.0, y: 0.0, z: 0.0 })
        mod.instance_variable_set(:@rotation_deg, data[:rotation_deg].to_f)
        mod.instance_variable_set(:@mirrored,     data[:mirrored] || false)

        # Construção
        mod.instance_variable_set(:@assembly_type,    (data[:assembly_type] || :brasil).to_sym)
        mod.instance_variable_set(:@body_material_id, data[:body_material_id])
        mod.instance_variable_set(:@front_material_id, data[:front_material_id])
        mod.instance_variable_set(:@back_material_id, data[:back_material_id])
        mod.instance_variable_set(:@body_thickness,   data[:body_thickness].to_i)
        mod.instance_variable_set(:@back_type,        (data[:back_type] || :encaixado).to_sym)
        mod.instance_variable_set(:@back_thickness,   data[:back_thickness].to_i)
        mod.instance_variable_set(:@base_type,        (data[:base_type] || :rodape).to_sym)
        mod.instance_variable_set(:@base_height_mm,   data[:base_height_mm].to_f)

        # Coleções vazias (a serem preenchidas pelo chamador)
        mod.instance_variable_set(:@openings,       [])
        mod.instance_variable_set(:@parts,          [])
        mod.instance_variable_set(:@hardware_items, [])
        mod.instance_variable_set(:@operations,     [])

        # Estado
        mod.instance_variable_set(:@state,             (data[:state] || :draft).to_sym)
        mod.instance_variable_set(:@validation_result, data[:validation_result])
        mod.instance_variable_set(:@export_hash,       data[:export_hash])
        mod.instance_variable_set(:@created_at,        data[:created_at])
        mod.instance_variable_set(:@updated_at,        data[:updated_at])

        mod
      end
    end
  end
end
