# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# catalog/default_rulesets.rb — RuleSets padrao por ambiente
#
# Conjuntos de regras de construcao pre-configurados.
# Cada ruleset define: tipo de montagem, espessuras, fitas, hardware padrao, etc.

module Ornato
  module Catalog
    module DefaultRuleSets
      # Cozinha Economica — montagem brasileira, MDF 15mm, fita 1mm
      def self.cozinha_economica
        Domain::Ruleset.new(
          name: 'Cozinha Economica',
          rules: {
            construction: {
              assembly_type: :brasil,
              back_type: :encaixado,
              back_thickness: 3,
              base_type: :rodape,
              base_height_mm: 100.0,
              back_groove_depth: 8.0,
              body_thickness: 15
            },
            edging: {
              default_thickness: 1.0,
              default_width: 22.0
            },
            front: {
              thickness: 15,
              edge_thickness: 1.0,
              edge_width: 22.0
            },
            hardware: {
              hinge_type: 'dob_35mm_clip',
              slide_type: :telescopica,
              default_handle: 'pux_96mm',
              shelf_support: 'sup_prat_5mm',
              connector: 'minifix_15mm'
            },
            constraints: {
              max_door_width: 600.0,
              max_drawer_width: 900.0,
              min_shelf_span: 150.0
            }
          }
        )
      end

      # Cozinha Premium — montagem europeia, MDF 18mm, fita 2mm
      def self.cozinha_premium
        Domain::Ruleset.new(
          name: 'Cozinha Premium',
          rules: {
            construction: {
              assembly_type: :europa,
              back_type: :encaixado,
              back_thickness: 6,
              base_type: :rodape,
              base_height_mm: 100.0,
              back_groove_depth: 10.0,
              body_thickness: 18
            },
            edging: {
              default_thickness: 2.0,
              default_width: 22.0
            },
            front: {
              thickness: 18,
              edge_thickness: 2.0,
              edge_width: 45.0
            },
            hardware: {
              hinge_type: 'dob_35mm_soft',
              slide_type: :oculta,
              default_handle: 'pux_128mm',
              shelf_support: 'sup_prat_5mm',
              connector: 'minifix_15mm'
            },
            constraints: {
              max_door_width: 600.0,
              max_drawer_width: 1000.0,
              min_shelf_span: 150.0
            }
          }
        )
      end

      # Roupeiro Convencional — montagem brasileira, MDF 18mm
      def self.roupeiro_convencional
        Domain::Ruleset.new(
          name: 'Roupeiro Convencional',
          rules: {
            construction: {
              assembly_type: :brasil,
              back_type: :encaixado,
              back_thickness: 3,
              base_type: :rodape,
              base_height_mm: 100.0,
              back_groove_depth: 8.0,
              body_thickness: 18
            },
            edging: {
              default_thickness: 1.0,
              default_width: 22.0
            },
            front: {
              thickness: 18,
              edge_thickness: 1.0,
              edge_width: 22.0
            },
            hardware: {
              hinge_type: 'dob_35mm_clip',
              slide_type: :telescopica,
              default_handle: 'pux_128mm',
              shelf_support: 'sup_prat_5mm',
              connector: 'minifix_15mm'
            },
            constraints: {
              max_door_width: 600.0,
              max_drawer_width: 900.0,
              min_shelf_span: 200.0
            }
          }
        )
      end

      # Closet Sem Fundo — sem fundo, sem rodape
      def self.closet_sem_fundo
        Domain::Ruleset.new(
          name: 'Closet Sem Fundo',
          rules: {
            construction: {
              assembly_type: :brasil,
              back_type: :nenhum,
              back_thickness: 0,
              base_type: :direto,
              base_height_mm: 0.0,
              back_groove_depth: 0.0,
              body_thickness: 18
            },
            edging: {
              default_thickness: 1.0,
              default_width: 22.0
            },
            front: {
              thickness: 18,
              edge_thickness: 1.0,
              edge_width: 22.0
            },
            hardware: {
              hinge_type: 'dob_35mm_clip',
              slide_type: :telescopica,
              default_handle: 'pux_128mm',
              shelf_support: 'sup_prat_5mm',
              connector: 'minifix_15mm'
            },
            constraints: {
              max_door_width: 600.0,
              max_drawer_width: 900.0,
              min_shelf_span: 200.0
            }
          }
        )
      end

      # Banheiro Umido — montagem europeia, MDF 18mm, fita 2mm (resistencia a umidade)
      def self.banheiro_umido
        Domain::Ruleset.new(
          name: 'Banheiro Umido',
          rules: {
            construction: {
              assembly_type: :europa,
              back_type: :sobreposto,
              back_thickness: 6,
              base_type: :pes,
              base_height_mm: 150.0,
              back_groove_depth: 0.0,
              body_thickness: 18
            },
            edging: {
              default_thickness: 2.0,
              default_width: 22.0
            },
            front: {
              thickness: 18,
              edge_thickness: 2.0,
              edge_width: 45.0
            },
            hardware: {
              hinge_type: 'dob_35mm_soft',
              slide_type: :oculta,
              default_handle: 'pux_96mm',
              shelf_support: 'sup_prat_5mm',
              connector: 'minifix_15mm'
            },
            constraints: {
              max_door_width: 500.0,
              max_drawer_width: 800.0,
              min_shelf_span: 150.0
            }
          }
        )
      end

      # Retorna todos os rulesets disponiveis.
      def self.all
        [
          cozinha_economica,
          cozinha_premium,
          roupeiro_convencional,
          closet_sem_fundo,
          banheiro_umido
        ]
      end

      # Busca ruleset por nome.
      def self.find_by_name(name)
        all.find { |rs| rs.name == name }
      end
    end
  end
end
