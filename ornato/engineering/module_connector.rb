# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/module_connector.rb — Conexao entre modulos
#
# Gerencia a relacao entre modulos lado-a-lado:
#   - Lateral compartilhada (2 modulos dividem 1 lateral)
#   - Parafusos de uniao entre modulos
#   - Tampo passante cobrindo multiplos modulos
#   - Alinhamento automatico (snap)
#   - Enchimento/testeira entre modulo e parede
#
# CONCEITOS:
#   - Grupo de Modulos: conjunto de modulos alinhados (ex: cozinha linear)
#   - Lateral Compartilhada: quando 2 modulos se encostam, economiza 1 lateral
#   - Tampo Passante: 1 tampo cobre varios modulos (bancada de cozinha)
#   - Testeira: peça fina entre módulo e parede/teto

module Ornato
  module Engineering
    class ModuleConnector

      # ================================================================
      # Tipos de conexao
      # ================================================================
      CONEXAO_TIPOS = {
        independente: {
          descricao: 'Independente (cada modulo com suas laterais)',
          lateral_compartilhada: false,
          parafuso_uniao: false,
        },
        uniao_simples: {
          descricao: 'Uniao com Parafuso (mantém ambas laterais)',
          lateral_compartilhada: false,
          parafuso_uniao: true,
          parafuso_tipo: :confirmat,
          parafuso_qty: 3,    # 3 parafusos por junta
        },
        lateral_compartilhada: {
          descricao: 'Lateral Compartilhada (remove 1 lateral)',
          lateral_compartilhada: true,
          parafuso_uniao: true,
          parafuso_tipo: :confirmat,
          parafuso_qty: 4,
        },
      }.freeze

      # ================================================================
      # Interface publica — Conectar modulos
      # ================================================================

      # Conecta dois modulos lado-a-lado.
      # @param modulo_esq [Sketchup::ComponentInstance] modulo a esquerda
      # @param modulo_dir [Sketchup::ComponentInstance] modulo a direita
      # @param tipo [Symbol] :independente, :uniao_simples, :lateral_compartilhada
      # @return [Hash] info da conexao criada
      def self.conectar(modulo_esq, modulo_dir, tipo: :uniao_simples)
        config = CONEXAO_TIPOS[tipo]
        raise "Tipo de conexao desconhecido: #{tipo}" unless config

        model = Sketchup.active_model
        model.start_operation("Conectar Modulos (#{config[:descricao]})", true)

        begin
          # 1. Alinhar modulo_dir ao lado de modulo_esq
          alinhar_ao_lado(modulo_esq, modulo_dir)

          # 2. Se lateral compartilhada, remover lateral_dir de esq e lateral_esq de dir
          if config[:lateral_compartilhada]
            remover_lateral(modulo_esq, :direita)
            remover_lateral(modulo_dir, :esquerda)

            # Marcar a lateral remanescente como compartilhada
            marcar_lateral_compartilhada(modulo_esq, modulo_dir)
          end

          # 3. Registrar conexao nos atributos
          registrar_conexao(modulo_esq, modulo_dir, tipo)

          # 4. Recalcular DCs
          [modulo_esq, modulo_dir].each do |mod|
            $dc_observers&.get_latest_class&.redraw_with_undo(mod) if defined?($dc_observers) && $dc_observers
          end

          model.commit_operation

          {
            tipo: tipo,
            modulo_esq: modulo_esq.definition.name,
            modulo_dir: modulo_dir.definition.name,
            lateral_compartilhada: config[:lateral_compartilhada],
          }

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # Desconecta dois modulos (restaura laterais se necessario).
      def self.desconectar(modulo_esq, modulo_dir)
        model = Sketchup.active_model
        model.start_operation('Desconectar Modulos', true)

        begin
          # Verificar se tem lateral compartilhada para restaurar
          conexao = ler_conexao(modulo_esq, :direita)
          if conexao && conexao['lateral_compartilhada']
            restaurar_lateral(modulo_esq, :direita)
            restaurar_lateral(modulo_dir, :esquerda)
          end

          # Limpar atributos de conexao
          limpar_conexao(modulo_esq, :direita)
          limpar_conexao(modulo_dir, :esquerda)

          model.commit_operation
          true

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # ================================================================
      # Tampo Passante — cobre multiplos modulos
      # ================================================================

      # Cria um tampo que cobre todos os modulos de um grupo linear.
      # @param modulos [Array<Sketchup::ComponentInstance>] modulos em ordem
      # @param espessura_mm [Float] espessura do tampo
      # @param sobra_lateral_mm [Float] sobra de cada lado (overhang)
      # @param sobra_frontal_mm [Float] sobra na frente
      # @param material [String]
      # @return [Sketchup::ComponentInstance]
      def self.criar_tampo_passante(modulos, espessura_mm: 25, sobra_lateral_mm: 0,
                                     sobra_frontal_mm: 20, material: 'MDF 25mm Branco TX')
        modulos = modulos.to_a if modulos.respond_to?(:to_a) && !modulos.is_a?(Array)
        raise 'Necessario pelo menos 1 modulo' if modulos.empty?

        # Validar que alturas sao compativeis (tolerancia 1cm)
        alturas = modulos.map { |m|
          (m.definition.get_attribute('dynamic_attributes', 'orn_altura') || 72).to_f
        }
        if alturas.max - alturas.min > 1.0
          puts "[ModuleConnector] AVISO: Modulos com alturas diferentes " \
               "(#{alturas.map(&:round).uniq.join(', ')}cm). Tampo posicionado na altura maxima."
        end

        model = Sketchup.active_model
        model.start_operation('Criar Tampo Passante', true)

        begin
          # Calcular dimensoes totais
          largura_total_cm = calcular_largura_total(modulos)
          profundidade_cm = max_profundidade(modulos)
          altura_cm = max_altura(modulos)

          sobra_lat_cm = sobra_lateral_mm / 10.0
          sobra_frt_cm = sobra_frontal_mm / 10.0
          esp_cm = espessura_mm / 10.0
          esp_real = Core::Config.real_thickness(espessura_mm) / 10.0

          # Posicao: no topo do modulo mais alto, estendendo sobras
          x_base = modulos.first.transformation.origin.x.to_cm - sobra_lat_cm
          y_base = modulos.first.transformation.origin.y.to_cm - sobra_frt_cm
          z_base = altura_cm

          tampo_w = largura_total_cm + 2 * sobra_lat_cm
          tampo_d = profundidade_cm + sobra_frt_cm

          nome = "Tampo Passante #{tampo_w.round}x#{tampo_d.round}"
          nome_unico = "#{nome}_#{Time.now.to_i}_#{rand(10000).to_s.rjust(4, '0')}"
          tampo_def = model.definitions.add(nome_unico)

          # Geometria
          pts = [
            Geom::Point3d.new(0, 0, 0),
            Geom::Point3d.new(tampo_w.cm, 0, 0),
            Geom::Point3d.new(tampo_w.cm, tampo_d.cm, 0),
            Geom::Point3d.new(0, tampo_d.cm, 0)
          ]
          face = tampo_def.entities.add_face(pts)
          face.pushpull(esp_cm.cm) if face

          # Marcar como peca Ornato
          dc = 'dynamic_attributes'
          attrs = {
            orn_marcado: true,
            orn_tipo_peca: 'tampo',
            orn_subtipo: 'passante',
            orn_codigo: 'CM_TAM_PASS',
            orn_nome: nome,
            orn_na_lista_corte: true,
            orn_grao: 'comprimento',
            orn_material: material,
            orn_espessura: espessura_mm,
            orn_espessura_real: Core::Config.real_thickness(espessura_mm),  # mm (consistente com export)
            orn_corte_comp: (tampo_w * 10).round(1),
            orn_corte_larg: (tampo_d * 10).round(1),
            orn_borda_frontal: true,
            orn_borda_traseira: false,
            orn_borda_esquerda: sobra_lateral_mm > 0,
            orn_borda_direita: sobra_lateral_mm > 0,
            orn_face_visivel: 'face_a',
          }

          attrs.each do |key, value|
            tampo_def.set_attribute(dc, key.to_s, value)
            tampo_def.set_attribute('ornato', key.to_s, value)
          end
          tampo_def.set_attribute(dc, '_has_behaviors', true)

          # Inserir no modelo
          ponto = Geom::Point3d.new(x_base.cm, y_base.cm, z_base.cm)
          instance = model.active_entities.add_instance(tampo_def, ponto)

          # Registrar modulos cobertos
          ids = modulos.map { |m| m.definition.get_attribute('ornato', 'orn_id') }.compact
          tampo_def.set_attribute('ornato', 'orn_modulos_cobertos_json', ids.to_json)

          model.commit_operation
          instance

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # ================================================================
      # Testeira — peca de acabamento entre modulo e parede/teto
      # ================================================================

      # Cria testeira (enchimento) entre modulo e parede.
      # @param modulo [Sketchup::ComponentInstance]
      # @param lado [Symbol] :esquerda, :direita, :superior
      # @param largura_mm [Float] largura da testeira
      # @param material [String]
      def self.criar_testeira(modulo, lado:, largura_mm:, material: nil)
        model = Sketchup.active_model
        model.start_operation("Criar Testeira #{lado}", true)

        begin
          parent_def = modulo.definition
          larg_cm = largura_mm / 10.0

          nome = "Testeira #{lado.to_s.capitalize}"
          nome_unico = "#{nome}_#{Time.now.to_i}_#{rand(10000).to_s.rjust(4, '0')}"
          test_def = model.definitions.add(nome_unico)

          case lado
          when :esquerda, :direita
            # Testeira vertical (preenche gap lateral ate parede)
            AggregateBuilder.send(:criar_geometria_caixa, test_def, larg_cm.cm, 55.cm, 72.cm)
            formulas = {
              lenx: "#{larg_cm}",
              leny: 'Parent!orn_profundidade',
              lenz: 'Parent!orn_altura',
              x: lado == :esquerda ? "-#{larg_cm}" : 'Parent!orn_largura',
              y: '0',
              z: '0',
              corte_comp: 'Parent!orn_altura*10',
              corte_larg: 'Parent!orn_profundidade*10',
            }
          when :superior
            # Testeira horizontal (preenche gap entre modulo e teto)
            AggregateBuilder.send(:criar_geometria_caixa, test_def, 60.cm, 55.cm, larg_cm.cm)
            formulas = {
              lenx: 'Parent!orn_largura',
              leny: 'Parent!orn_profundidade',
              lenz: "#{larg_cm}",
              x: '0',
              y: '0',
              z: 'Parent!orn_altura',
              corte_comp: 'Parent!orn_largura*10',
              corte_larg: 'Parent!orn_profundidade*10',
            }
          end

          BoxBuilder.send(:configurar_peca_dc, test_def, {
            orn_marcado: true,
            orn_tipo_peca: 'testeira',
            orn_subtipo: lado.to_s,
            orn_codigo: "TEST_#{lado.to_s.upcase[0..2]}",
            orn_nome: nome,
            orn_na_lista_corte: true,
            orn_grao: 'comprimento',
            orn_borda_frontal: true,
            orn_material: material,
            orn_face_visivel: 'face_a',
          }, formulas)

          parent_def.entities.add_instance(test_def, ORIGIN)

          $dc_observers&.get_latest_class&.redraw_with_undo(modulo) if defined?($dc_observers) && $dc_observers

          model.commit_operation

        rescue => e
          model.abort_operation
          raise e
        end
      end

      private

      # ================================================================
      # Helpers
      # ================================================================

      def self.alinhar_ao_lado(mod_esq, mod_dir)
        # Posicionar mod_dir rente a lateral direita de mod_esq
        origin_esq = mod_esq.transformation.origin
        def_esq = mod_esq.respond_to?(:definition) ? mod_esq.definition : nil
        largura_esq = def_esq ? (def_esq.get_attribute('dynamic_attributes', 'orn_largura') || 60) : 60
        x_dir = origin_esq.x + largura_esq.cm
        y_dir = origin_esq.y
        z_dir = origin_esq.z

        nova_pos = Geom::Transformation.new(Geom::Point3d.new(x_dir, y_dir, z_dir))
        mod_dir.transformation = nova_pos
      end

      def self.remover_lateral(modulo, lado)
        parent_def = modulo.respond_to?(:definition) ? modulo.definition : nil
        return unless parent_def
        subtipo_alvo = lado.to_s
        parent_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          tipo = entity.definition.get_attribute('dynamic_attributes', 'orn_tipo_peca')
          subtipo = entity.definition.get_attribute('dynamic_attributes', 'orn_subtipo')
          if tipo == 'lateral' && subtipo == subtipo_alvo
            parent_def.entities.erase_entities(entity)
            return
          end
        end
      end

      def self.restaurar_lateral(modulo, lado)
        # Recriar lateral removida
        parent_def = modulo.respond_to?(:definition) ? modulo.definition : nil
        return unless parent_def
        config_tipo = parent_def.get_attribute('dynamic_attributes', 'orn_tipo_modulo')
        config = BoxBuilder::CONFIGS[config_tipo.to_sym] rescue nil
        return unless config

        esp_real = parent_def.get_attribute('dynamic_attributes', 'orn_espessura_real') || 1.85
        formula_key = lado == :esquerda ? :lateral_esq : :lateral_dir
        formulas = BoxBuilder::FORMULAS[formula_key]

        nome = "Lateral #{lado == :esquerda ? 'Esq' : 'Dir'}"
        nome_unico = "#{nome}_#{Time.now.to_i}_#{rand(10000).to_s.rjust(4, '0')}"
        lat_def = Sketchup.active_model.definitions.add(nome_unico)
        prof_cm = (parent_def.get_attribute('dynamic_attributes', 'orn_profundidade') || 55).to_f
        alt_cm = (parent_def.get_attribute('dynamic_attributes', 'orn_altura') || 72).to_f
        AggregateBuilder.send(:criar_geometria_caixa, lat_def, esp_real.cm, prof_cm.cm, alt_cm.cm)

        BoxBuilder.send(:configurar_peca_dc, lat_def, {
          orn_marcado: true,
          orn_tipo_peca: 'lateral',
          orn_subtipo: lado.to_s,
          orn_codigo: lado == :esquerda ? 'LAT_ESQ' : 'LAT_DIR',
          orn_nome: nome,
          orn_na_lista_corte: true,
          orn_grao: 'comprimento',
          orn_borda_frontal: true,
          orn_face_visivel: 'face_a',
        }, formulas)

        parent_def.entities.add_instance(lat_def, ORIGIN)
      end

      def self.marcar_lateral_compartilhada(mod_esq, mod_dir)
        # Marcar a lateral direita de mod_esq como compartilhada
        id_dir = mod_dir.definition.get_attribute('ornato', 'orn_id') || ''
        id_esq = mod_esq.definition.get_attribute('ornato', 'orn_id') || ''
        mod_esq.definition.set_attribute('ornato', 'orn_lateral_compartilhada_dir', id_dir)
        mod_dir.definition.set_attribute('ornato', 'orn_lateral_compartilhada_esq', id_esq)
      end

      def self.registrar_conexao(mod_esq, mod_dir, tipo)
        id_esq = mod_esq.definition.get_attribute('ornato', 'orn_id') || ''
        id_dir = mod_dir.definition.get_attribute('ornato', 'orn_id') || ''

        conexao_data = {
          tipo: tipo.to_s,
          lateral_compartilhada: CONEXAO_TIPOS[tipo][:lateral_compartilhada],
          timestamp: Time.now.to_i,
        }

        mod_esq.definition.set_attribute('ornato', 'orn_conexao_direita', id_dir)
        mod_esq.definition.set_attribute('ornato', 'orn_conexao_direita_json', conexao_data.to_json)
        mod_dir.definition.set_attribute('ornato', 'orn_conexao_esquerda', id_esq)
        mod_dir.definition.set_attribute('ornato', 'orn_conexao_esquerda_json', conexao_data.to_json)
      end

      def self.ler_conexao(modulo, lado)
        json = modulo.definition.get_attribute('ornato', "orn_conexao_#{lado}_json")
        return nil unless json
        JSON.parse(json) rescue nil
      end

      def self.limpar_conexao(modulo, lado)
        modulo.definition.set_attribute('ornato', "orn_conexao_#{lado}", nil)
        modulo.definition.set_attribute('ornato', "orn_conexao_#{lado}_json", nil)
        modulo.definition.set_attribute('ornato', "orn_lateral_compartilhada_#{lado}", nil)
      end

      def self.calcular_largura_total(modulos)
        modulos.sum do |m|
          next 60.0 unless m.respond_to?(:definition) && m.definition
          (m.definition.get_attribute('dynamic_attributes', 'orn_largura') || 60).to_f
        end
      end

      def self.max_profundidade(modulos)
        modulos.map { |m| (m.definition.get_attribute('dynamic_attributes', 'orn_profundidade') || 55).to_f }.max
      end

      def self.max_altura(modulos)
        modulos.map { |m| (m.definition.get_attribute('dynamic_attributes', 'orn_altura') || 72).to_f }.max
      end

    end
  end
end
