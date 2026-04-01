# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# components/identity_reconciler.rb — Reconciliação de identidades SketchUp
#
# O SketchUp não garante estabilidade de entityID (pode mudar ao salvar/reabrir).
# O IdentityReconciler resolve a vinculação entre o domínio (ornato_id estável)
# e as entities SketchUp (entityID volátil).
#
# Estratégia de reconciliação (4 camadas):
#   1. ornato_id nos atributos — fonte primária
#   2. persistent_id — salvo via Attributes
#   3. pid_path — caminho hierárquico (parent_id/child_id)
#   4. Heurística — por dimensões, tipo, posição
#
# Chamado ao abrir arquivo .skp ou após operações destrutivas.

module Ornato
  module Components
    class IdentityReconciler
      # Resultado da reconciliação.
      ReconciliationReport = Struct.new(
        :matched,      # Integer: entities reconhecidas por ornato_id
        :recovered,    # Integer: entities recuperadas por heurística
        :orphaned,     # Integer: entities com ornato_id sem domínio correspondente
        :missing,      # Integer: domínios sem entity correspondente
        :reassigned,   # Integer: entityIDs reatribuídos
        :details,      # Array<Hash>: detalhes das reconciliações
        :duration_ms,  # Float
        keyword_init: true
      )

      # Reconcilia entities SketchUp com dados de domínio.
      #
      # @param model [Sketchup::Model] modelo ativo
      # @param domain_modules [Array<Domain::ModEntity>] módulos do domínio
      # @return [ReconciliationReport]
      def reconcile(model, domain_modules)
        start_time = Time.now
        report = {
          matched: 0, recovered: 0, orphaned: 0,
          missing: 0, reassigned: 0, details: []
        }

        # 1. Encontrar todas as entities Ornato no modelo
        ornato_entities = Core::Attributes.find_all_ornato_entities(model)

        # 2. Criar mapa ornato_id → entity
        entity_map = {}
        ornato_entities.each do |entity|
          oid = Core::Attributes.ornato_id(entity)
          next unless oid
          entity_map[oid] = entity
        end

        # 3. Para cada módulo de domínio, encontrar a entity correspondente
        domain_modules.each do |mod|
          entity = entity_map.delete(mod.ornato_id)

          if entity
            # Match direto por ornato_id
            report[:matched] += 1
            update_persistent_id(entity, mod)
            report[:details] << {
              ornato_id: mod.ornato_id, name: mod.name,
              method: :ornato_id, status: :matched
            }
          else
            # Tentar recuperar por heurística
            recovered = find_by_heuristic(mod, ornato_entities, entity_map)
            if recovered
              report[:recovered] += 1
              report[:reassigned] += 1
              # Regravar ornato_id na entity
              Core::Attributes.write_one(
                recovered, Core::Config::DICT_IDENTITY,
                'ornato_id', mod.ornato_id
              )
              update_persistent_id(recovered, mod)
              report[:details] << {
                ornato_id: mod.ornato_id, name: mod.name,
                method: :heuristic, status: :recovered
              }
            else
              report[:missing] += 1
              report[:details] << {
                ornato_id: mod.ornato_id, name: mod.name,
                method: nil, status: :missing
              }
            end
          end
        end

        # 4. Entities restantes são órfãs (têm ornato_id mas sem domínio)
        entity_map.each do |oid, entity|
          report[:orphaned] += 1
          report[:details] << {
            ornato_id: oid,
            name: Core::Attributes.read(entity, Core::Config::DICT_DESIGN, 'name'),
            method: nil, status: :orphaned
          }
        end

        duration = ((Time.now - start_time) * 1000).round(1)

        result = ReconciliationReport.new(**report, duration_ms: duration)

        Core.events.emit(:identity_reconciled, report: result)
        Core.logger.info(
          "Reconciliação concluída em #{duration}ms: " \
          "#{report[:matched]} matched, #{report[:recovered]} recovered, " \
          "#{report[:orphaned]} orphaned, #{report[:missing]} missing"
        )

        result
      end

      # Verifica integridade: todas as entities Ornato têm ornato_id válido?
      # @param model [Sketchup::Model]
      # @return [Array<Hash>] problemas encontrados
      def check_integrity(model)
        problems = []
        entities = Core::Attributes.find_all_ornato_entities(model)

        seen_ids = {}
        entities.each do |entity|
          oid = Core::Attributes.ornato_id(entity)

          unless oid
            problems << { entity: entity, problem: :missing_ornato_id }
            next
          end

          unless Core::Ids.valid?(oid)
            problems << { entity: entity, ornato_id: oid, problem: :invalid_ornato_id }
            next
          end

          if seen_ids[oid]
            problems << { entity: entity, ornato_id: oid, problem: :duplicate_ornato_id }
          end
          seen_ids[oid] = entity

          # Verificar campos essenciais
          tipo = Core::Attributes.entity_type(entity)
          unless tipo
            problems << { entity: entity, ornato_id: oid, problem: :missing_type }
          end
        end

        problems
      end

      private

      # Atualiza persistent_id na entity (entityID atual + timestamp).
      def update_persistent_id(entity, mod)
        if entity.respond_to?(:entityID)
          Core::Attributes.write_one(
            entity, Core::Config::DICT_SYNC,
            'persistent_id', entity.entityID.to_s
          )
        end
      end

      # Tenta encontrar entity por heurística (dimensões + tipo + posição).
      def find_by_heuristic(mod, all_entities, already_matched)
        matched_ids = already_matched.values.map { |e| e.respond_to?(:entityID) ? e.entityID : nil }.compact

        candidates = all_entities.select do |entity|
          next false if matched_ids.include?(entity.entityID) if entity.respond_to?(:entityID)

          # Mesmo tipo?
          tipo = Core::Attributes.entity_type(entity)
          next false unless tipo == mod.module_type

          # Dimensões similares?
          data = Core::Attributes.load_domain_data(entity)
          next false unless data[:width_mm] && data[:height_mm] && data[:depth_mm]

          w_match = (data[:width_mm].to_f - mod.width_mm).abs < 1.0
          h_match = (data[:height_mm].to_f - mod.height_mm).abs < 1.0
          d_match = (data[:depth_mm].to_f - mod.depth_mm).abs < 1.0

          w_match && h_match && d_match
        end

        # Se encontrou exatamente 1 candidato, é um match
        candidates.length == 1 ? candidates.first : nil
      end
    end
  end
end
