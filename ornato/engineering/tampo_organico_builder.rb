# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/tampo_organico_builder.rb — Construtor de Tampos Organicos
#
# Converte uma Face 2D desenhada pelo usuario em uma peca de tampo
# com espessura e material configuraveis. O contorno organico (curvas,
# arcos, splines) e preservado para exportacao DXF/SVG para CNC router.
#
# FLUXO:
#   1. Usuario desenha contorno 2D no SketchUp (linhas, arcos, curvas)
#   2. Seleciona a Face resultante
#   3. Executa TampoOrganicoBuilder.criar_de_face(face, espessura: 25, material: 'MDF')
#   4. Plugin faz pushpull para espessura configurada
#   5. Marca como peca Ornato com atributos de corte
#   6. Contorno 2D e armazenado como polyline para exportacao CNC
#
# EXPORTACAO CNC:
#   O contorno organico e exportado como lista de pontos (polyline) e
#   arcos no atributo orn_contorno_json. O sistema web/CNC optimizer
#   usa esse contorno para gerar o toolpath do router.
#
# ESPESSURAS DISPONIVEIS:
#   15, 18, 20, 25, 30, 36mm (MDF/MDP)
#   Granitos e pedras: via contorno apenas (sem pushpull)

require 'json'

module Ornato
  module Engineering
    class TampoOrganicoBuilder

      # Espessuras disponiveis para selecao
      # Espessuras padrão marcenaria BR (nominal)
      # 15mm → 15.5 real, 18mm → 18.5, 25mm → 25.5
      # 30mm (2x15) → 31.0, 36mm (2x18) → 37.0
      ESPESSURAS = [6, 15, 18, 25, 30, 36].freeze

      # ================================================================
      # Interface publica
      # ================================================================

      # Cria tampo a partir de uma Face selecionada.
      # A face e extrudada (pushpull) e marcada como peca Ornato.
      #
      # @param face [Sketchup::Face] face 2D selecionada
      # @param espessura [Float] espessura nominal em mm
      # @param material [String] nome do material
      # @param bordas [Hash] quais bordas tem fita { frontal: true, ... }
      # @param nome [String] nome do tampo
      # @return [Sketchup::ComponentInstance] componente criado
      def self.criar_de_face(face, espessura: 25.0, material: 'MDF 25mm Branco TX',
                              bordas: nil, nome: 'Tampo Organico')
        unless face.is_a?(Sketchup::Face)
          raise ArgumentError, 'Selecione uma Face para criar o tampo'
        end

        model = Sketchup.active_model
        model.start_operation('Criar Tampo Organico', true)

        begin
          # 1. Extrair contorno da face ANTES do pushpull
          contorno = extrair_contorno(face)
          bb = face.bounds
          # face.area retorna em polegadas quadradas. Converter para mm2:
          # 1 polegada = 25.4mm, entao 1 sq inch = 645.16 sq mm
          area_mm2 = face.area * (25.4 ** 2)

          # Bounding box para dimensoes de corte (mm)
          bb_width_mm = bb.width.to_mm.round(1)
          bb_height_mm = bb.height.to_mm.round(1)
          bb_depth_mm = bb.depth.to_mm.round(1)

          # Dimensoes de corte = 2 maiores dimensoes do bounding box (peca bruta para nesting)
          sorted_dims = [bb_width_mm, bb_height_mm, bb_depth_mm].sort.reverse
          corte_comp = sorted_dims[0]  # maior
          corte_larg = sorted_dims[1]  # segundo maior

          # 2. Espessura real
          unless ESPESSURAS.include?(espessura.to_f.to_i) || ESPESSURAS.include?(espessura.to_f)
            raise ArgumentError, "Espessura #{espessura}mm invalida. Opcoes: #{ESPESSURAS.join(', ')}"
          end
          esp_real = Core::Config.real_thickness(espessura)
          esp_cm = esp_real / 10.0

          # 3. Criar grupo/componente a partir da face
          # Fazer pushpull na face para criar volume
          parent = face.parent
          if parent.is_a?(Sketchup::ComponentDefinition)
            # Face ja esta dentro de um componente
            face.pushpull(esp_cm.cm)
            definition = parent
          else
            # Face esta no modelo raiz — criar componente
            grupo = model.active_entities.add_group(face, *face.edges)
            face_in_group = grupo.entities.grep(Sketchup::Face).first
            unless face_in_group
              model.abort_operation
              raise "Falha ao converter face para peca: geometria perdida apos agrupamento"
            end
            face_in_group.pushpull(esp_cm.cm)
            definition = grupo.definition
          end

          # 4. Renomear definition
          nome_unico = "#{nome}_#{Time.now.to_i}_#{rand(10000).to_s.rjust(4, '0')}"
          definition.name = nome_unico

          # 5. Marcar como peca Ornato
          dc_dict = 'dynamic_attributes'
          ornato_dict = 'ornato'

          attrs = {
            orn_marcado: true,
            orn_tipo_peca: 'tampo',
            orn_subtipo: 'organico',
            orn_codigo: 'CM_TAM_ORG',
            orn_nome: nome,
            orn_na_lista_corte: true,
            orn_grao: 'sem',
            orn_material: material,
            orn_espessura: espessura,
            orn_espessura_real: esp_real,
            orn_corte_comp: corte_comp,
            orn_corte_larg: corte_larg,
            orn_face_visivel: 'face_a',
            orn_organico: true,
            orn_contorno_json: contorno.to_json,
          }

          # Bordas — se nao especificadas, todas as bordas
          bordas ||= { frontal: true, traseira: true, esquerda: true, direita: true }
          attrs[:orn_borda_frontal] = bordas[:frontal] || false
          attrs[:orn_borda_traseira] = bordas[:traseira] || false
          attrs[:orn_borda_esquerda] = bordas[:esquerda] || false
          attrs[:orn_borda_direita] = bordas[:direita] || false

          attrs.each do |key, value|
            definition.set_attribute(dc_dict, key.to_s, value)
            definition.set_attribute(ornato_dict, key.to_s, value)
          end

          definition.set_attribute(dc_dict, '_has_behaviors', true)

          # 6. Metadata para Component Options
          definition.set_attribute(dc_dict, 'orn_espessura_label', 'Espessura (mm)')
          definition.set_attribute(dc_dict, 'orn_espessura_access', 'LIST')
          definition.set_attribute(dc_dict, 'orn_espessura_options',
            ESPESSURAS.map { |e| "#{e}mm=#{e}" }.join('&'))

          definition.set_attribute(dc_dict, 'orn_material_label', 'Material')
          definition.set_attribute(dc_dict, 'orn_material_access', 'LIST')

          definition.set_attribute(dc_dict, 'orn_nome_label', 'Nome')
          definition.set_attribute(dc_dict, 'orn_nome_access', 'TEXTBOX')

          model.commit_operation

          # Retornar a instancia
          instances = definition.instances
          instances.first

        rescue => e
          model.abort_operation
          raise e
        end
      end

      # Cria tampo organico a partir da selecao atual.
      # Mostra dialogo de configuracao (espessura, material).
      def self.criar_de_selecao
        model = Sketchup.active_model
        face = model.selection.grep(Sketchup::Face).first

        unless face
          UI.messagebox('Selecione uma Face para criar o tampo organico.')
          return nil
        end

        # Dialogo de configuracao
        prompts = ['Espessura (mm):', 'Material:', 'Nome:',
                   'Borda em todo contorno?']
        defaults = ['25', 'MDF 25mm Branco TX', 'Tampo Organico', 'Sim']
        lista = [ESPESSURAS.join('|'), '', '', 'Sim|Nao']

        result = UI.inputbox(prompts, defaults, lista, 'Tampo Organico')
        return nil unless result

        espessura = result[0].to_f
        material = result[1]
        nome = result[2]
        todas_bordas = result[3] == 'Sim'

        bordas = if todas_bordas
          { frontal: true, traseira: true, esquerda: true, direita: true }
        else
          { frontal: true, traseira: false, esquerda: false, direita: false }
        end

        criar_de_face(face, espessura: espessura, material: material,
                      bordas: bordas, nome: nome)
      end

      # ================================================================
      # Alterar espessura de um tampo existente
      # ================================================================

      def self.alterar_espessura(componente, nova_espessura_mm)
        return unless componente.is_a?(Sketchup::ComponentInstance)
        definition = componente.definition

        organico = definition.get_attribute('dynamic_attributes', 'orn_organico')
        return unless organico

        model = Sketchup.active_model
        model.start_operation('Alterar Espessura Tampo', true)

        begin
          esp_real = Core::Config.real_thickness(nova_espessura_mm)

          # Atualizar atributos
          definition.set_attribute('dynamic_attributes', 'orn_espessura', nova_espessura_mm)
          definition.set_attribute('dynamic_attributes', 'orn_espessura_real', esp_real)
          definition.set_attribute('ornato', 'orn_espessura', nova_espessura_mm)
          definition.set_attribute('ornato', 'orn_espessura_real', esp_real)

          # Reconstruir geometria — encontrar faces e ajustar pushpull
          # Para tampos organicos, a espessura e o eixo Z (menor dimensao)
          # Remover geometria existente e recriar com nova espessura
          faces = definition.entities.grep(Sketchup::Face)

          # Encontrar a face do contorno (a face horizontal mais baixa)
          base_face = faces.min_by { |f| f.bounds.min.z }
          if base_face
            # Pegar altura atual e calcular delta
            altura_atual = definition.bounds.depth  # Z range em polegadas
            nova_altura = (esp_real / 10.0).cm       # mm → cm → polegadas

            if altura_atual > 0 && base_face.respond_to?(:pushpull)
              # Nao e possivel fazer pushpull negativo diretamente,
              # entao apenas atualizamos os atributos e a geometria
              # sera recriada pelo usuario se necessario
            end
          end

          model.commit_operation
          true

        rescue => e
          model.abort_operation
          raise e
        end
      end

      private

      # ================================================================
      # Extracao de contorno
      # ================================================================

      # Extrai o contorno de uma face como array de pontos e arcos.
      # O contorno e usado para exportacao CNC (router segue esse path).
      #
      # @param face [Sketchup::Face]
      # @return [Hash] { tipo: 'polyline', pontos: [...], arcos: [...], ... }
      def self.extrair_contorno(face)
        contorno = {
          tipo: 'polyline',
          pontos: [],
          arcos: [],
          fechado: true,
        }

        # Loop externo (contorno principal)
        outer_loop = face.outer_loop
        return contorno unless outer_loop

        outer_loop.edgeuses.each do |edgeuse|
          edge = edgeuse.edge
          curve = edge.curve

          if curve.is_a?(Sketchup::ArcCurve)
            # Arco — extrair centro, raio, angulos
            unless contorno[:arcos].any? { |a| a[:curve_id] == curve.object_id }
              contorno[:arcos] << {
                curve_id: curve.object_id,
                centro: ponto_para_mm(curve.center),
                raio: curve.radius.to_mm.round(2),
                angulo_inicio: curve.start_angle,
                angulo_fim: curve.end_angle,
                normal: [curve.normal.x, curve.normal.y, curve.normal.z],
              }
            end
          end

          # Adicionar vertices como pontos
          pt = edgeuse.reversed? ? edge.end.position : edge.start.position
          contorno[:pontos] << ponto_para_mm(pt)
        end

        # Inner loops (furos/aberturas no tampo)
        if face.loops.length > 1
          contorno[:furos] = []
          face.loops.each do |loop|
            next if loop == outer_loop
            furo_pontos = []
            loop.edgeuses.each do |eu|
              pt = eu.reversed? ? eu.edge.end.position : eu.edge.start.position
              furo_pontos << ponto_para_mm(pt)
            end
            contorno[:furos] << furo_pontos
          end
        end

        contorno
      end

      def self.ponto_para_mm(point)
        {
          x: point.x.to_mm.round(2),
          y: point.y.to_mm.round(2),
          z: point.z.to_mm.round(2),
        }
      end
    end
  end
end
