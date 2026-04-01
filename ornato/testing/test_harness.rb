# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# testing/test_harness.rb — Harness de testes para validação rápida
#
# Permite testar o domínio ORNATO fora do SketchUp.
# Roda no console Ruby puro com mocks das APIs do SketchUp.
#
# Uso:
#   ruby testing/test_harness.rb

module Ornato
  module Testing
    class TestHarness
      attr_reader :results

      def initialize
        @results = []
        @pass_count = 0
        @fail_count = 0
      end

      # Executa todos os testes.
      def run_all
        puts "\n=========================================="
        puts "  ORNATO Test Harness v1.0"
        puts "==========================================\n\n"

        test_core_ids
        test_core_config
        test_domain_part
        test_domain_opening
        test_domain_mod_entity
        test_domain_aggregate
        test_domain_machine_profile
        test_recipe_registry
        test_catalog_defaults
        test_validator

        puts "\n=========================================="
        puts "  Resultados: #{@pass_count} ✓  #{@fail_count} ✗"
        puts "==========================================\n"

        @fail_count == 0
      end

      private

      def assert(description, condition)
        if condition
          @pass_count += 1
          puts "  ✓ #{description}"
        else
          @fail_count += 1
          puts "  ✗ #{description}"
        end
        @results << { description: description, pass: condition }
      end

      def section(name)
        puts "\n── #{name} ──"
      end

      # ── Testes ──────────────────────────────────────────────────

      def test_core_ids
        section('Core::Ids')
        id = Core::Ids.generate
        assert('Gera ID com prefixo orn_', id.start_with?('orn_'))
        assert('ID tem 16 caracteres', id.length == 16)
        assert('IDs são únicos', Core::Ids.generate != Core::Ids.generate)
        assert('Valida ID correto', Core::Ids.valid?(id))
        assert('Rejeita ID inválido', !Core::Ids.valid?('abc'))
        assert('Rejeita nil', !Core::Ids.valid?(nil))
      end

      def test_core_config
        section('Core::Config')
        assert('Espessura real 18 = 18.5', Core::Config.real_thickness(18) == 18.5)
        assert('Espessura real 15 = 15.5', Core::Config.real_thickness(15) == 15.5)
        assert('Espessura real 3 = 3.0', Core::Config.real_thickness(3) == 3.0)
        assert('Espessura real 25 = 25.5', Core::Config.real_thickness(25) == 25.5)
        assert('Snap 32mm arredonda', Core::Config.snap_32(100) > 0)
        assert('SYSTEM_32 pitch = 32', Core::Config::SYSTEM_32[:pitch_mm] == 32)
        assert('SHEET width = 2750', Core::Config::SHEET[:width_mm] == 2750)
      end

      def test_domain_part
        section('Domain::Part')
        part = Domain::Part.new(name: 'Lateral Esquerda', part_type: :structural, code: 'CM_LAT_ESQ')
        part.length_mm = 700.0
        part.width_mm = 560.0
        part.thickness_nominal = 18
        part.thickness_real = 18.5

        assert('Part tem ornato_id', Core::Ids.valid?(part.ornato_id))
        assert('Part é estrutural', part.structural?)
        assert('Part não é front', !part.front?)
        assert('cut_length = length', part.cut_length == 700.0)
        assert('cut_width = width', part.cut_width == 560.0)
        assert('area_m2 calculado', part.area_m2 > 0)

        # Fita de borda
        part.edge_front = Domain::EdgeSpec.new(applied: true, thickness_mm: 1.0, width_mm: 22.0, material_id: nil, finish: nil)
        assert('EdgeSpec criado', part.edge_front.thickness_mm == 1.0)
        assert('edgeband_finish_code = 1C', part.edgeband_finish_code == '1C')

        hash = part.to_hash
        assert('to_hash retorna Hash', hash.is_a?(Hash))
        assert('to_hash tem ornato_id', hash[:ornato_id] == part.ornato_id)
      end

      def test_domain_opening
        section('Domain::Opening')
        opening = Domain::Opening.new(name: 'Vão Principal', width_mm: 500.0, height_mm: 600.0, depth_mm: 530.0)

        assert('Opening tem ornato_id', Core::Ids.valid?(opening.ornato_id))
        assert('É folha sem sub-openings', opening.leaf?)
        assert('Não tem agregados', opening.aggregates.empty?)

        # Dividir horizontalmente
        top, bottom = opening.divide_horizontal(300.0)
        assert('Divisão horizontal cria 2 sub-openings', opening.sub_openings.length == 2)
        assert('Top tem 300mm', top.height_mm == 300.0)
        assert('Bottom tem restante', bottom.height_mm == 300.0)
        assert('Não é mais folha', !opening.leaf?)
      end

      def test_domain_mod_entity
        section('Domain::ModEntity')
        mod = Domain::ModEntity.new(
          name: 'Balcão Teste',
          module_type: :balcao,
          width_mm: 800.0,
          height_mm: 720.0,
          depth_mm: 560.0
        )

        assert('Mod tem ornato_id', Core::Ids.valid?(mod.ornato_id))
        assert('Tipo é balcao', mod.module_type == :balcao)
        assert('internal_width < width', mod.internal_width_mm < mod.width_mm)
        assert('internal_height < height', mod.internal_height_mm < mod.height_mm)
        assert('Estado inicial é draft', mod.state == :draft)
        assert('É editável', mod.editable?)

        hash = mod.to_hash
        assert('to_hash retorna Hash', hash.is_a?(Hash))
        assert('to_hash tem internal_width', hash.key?(:internal_width_mm))
      end

      def test_domain_aggregate
        section('Domain::Aggregate')
        agg = Domain::Aggregate.new(
          name: 'Porta Lisa',
          aggregate_type: :porta_abrir,
          door_subtype: :lisa,
          overlap: :total
        )

        assert('Aggregate tem ornato_id', Core::Ids.valid?(agg.ornato_id))
        assert('É porta', agg.door?)
        assert('Não é gaveta', !agg.drawer?)
        assert('Ocupa altura', agg.occupies_height?)
      end

      def test_domain_machine_profile
        section('Domain::MachineProfile')
        profile = Domain::MachineProfile.default_cnc

        assert('Perfil tem nome', profile.name == 'CNC Padrão')
        assert('Tem 8 ferramentas', profile.tools.length == 8)
        assert('Encontra broca 5mm', profile.find_tool_by_spec(type: :broca, diameter_mm: 5.0) != nil)
        assert('Encontra fresa 6mm', profile.find_tool_by_spec(type: :fresa, diameter_mm: 6.0) != nil)
        assert('Encontra forstner 35mm', profile.find_tool_by_spec(type: :forstner, diameter_mm: 35.0) != nil)
        assert('Suporta espessura 18', profile.supports_thickness?(18))
        assert('Não suporta espessura 20', !profile.supports_thickness?(20))
        assert('Suporta operação furacao', profile.supports_operation?(:furacao))
      end

      def test_recipe_registry
        section('Recipes::RecipeRegistry')
        registry = Recipes::RecipeRegistry.instance
        registry.clear
        registry.register_defaults

        assert('10 receitas registradas', registry.count == 10)
        assert('Encontra balcao', registry.find(:balcao) != nil)
        assert('Encontra aereo', registry.find(:aereo) != nil)
        assert('Encontra gaveteiro', registry.find(:gaveteiro) != nil)
        assert('Encontra torre', registry.find(:torre) != nil)
        assert('Encontra roupeiro', registry.find(:roupeiro) != nil)
        assert('Catálogo retorna array', registry.catalog.is_a?(Array))
      end

      def test_catalog_defaults
        section('Catalog::DefaultCatalog')
        materials = Catalog::DefaultCatalog.materials
        edgebands = Catalog::DefaultCatalog.edgebands
        hardware = Catalog::DefaultCatalog.hardware

        assert('Tem materiais', materials.length > 10)
        assert('Tem fitas', edgebands.length > 5)
        assert('Tem ferragens', hardware.length > 10)

        branco_18 = materials.find { |m| m[:id] == 'mdf_branco_tx_18' }
        assert('MDF Branco 18mm existe', branco_18 != nil)
        assert('Espessura real = 18.5', branco_18[:thickness_real] == 18.5) if branco_18
      end

      def test_validator
        section('Engineering::Validator')
        validator = Engineering::Validator.new
        mod = Domain::ModEntity.new(
          name: 'Teste Validação',
          module_type: :balcao,
          width_mm: 600.0,
          height_mm: 720.0,
          depth_mm: 560.0
        )

        result = validator.validate(mod)
        assert('Validação retorna resultado', result != nil)
        assert('Resultado tem issues', result.issues.is_a?(Array))
        # Módulo vazio deve ter warnings (sem material, etc.)
        assert('Tem warnings (sem material)', result.warning_count > 0 || result.suggestion_count > 0)
      end
    end
  end
end

# Executar se chamado diretamente
if __FILE__ == $PROGRAM_NAME
  # Carregar subsistemas necessários
  base_dir = File.expand_path('..', File.dirname(__FILE__))

  %w[
    core/errors core/config core/ids core/logger core/events
    core/constants core/attributes core/feature_flags
    domain/contracts domain/project domain/environment domain/opening
    domain/part domain/hardware_item domain/operation domain/revision
    domain/aggregate domain/mod_entity domain/ruleset domain/diff_report
    domain/machine_profile
    catalog/default_catalog catalog/catalog_manager catalog/catalog_snapshot
    catalog/default_rulesets
    recipes/recipe_base recipes/recipe_registry
    recipes/balcao_simples recipes/aereo_simples recipes/gaveteiro
    recipes/torre_forno recipes/roupeiro recipes/nicho
    recipes/painel recipes/tampo recipes/rodape recipes/canto
    components/module_factory components/rebuild_orchestrator
    components/module_updater components/aggregate_engine
    components/identity_reconciler components/state_bridge
    engineering/drilling_engine engineering/edging_engine
    engineering/machining_engine engineering/validator
    engineering/readiness_evaluator
    export/export_engine
  ].each do |f|
    path = File.join(base_dir, "#{f}.rb")
    require path if File.exist?(path)
  end

  harness = Ornato::Testing::TestHarness.new
  success = harness.run_all
  exit(success ? 0 : 1)
end
