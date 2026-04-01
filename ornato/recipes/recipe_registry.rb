# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# recipes/recipe_registry.rb — Registro central de receitas disponíveis
#
# O RecipeRegistry é o ponto de acesso para instanciar módulos.
# Cada receita se auto-registra ao ser carregada (require).
#
# Uso:
#   registry = Ornato::Recipes::RecipeRegistry.instance
#   recipe = registry.find(:balcao)
#   mod = recipe.execute({ width_mm: 800 }, ruleset)

module Ornato
  module Recipes
    class RecipeRegistry
      # Singleton
      @instance = nil

      def self.instance
        @instance ||= new
      end

      def initialize
        @recipes = {}
      end

      # Registra uma receita.
      # @param recipe [RecipeBase] instância de receita
      def register(recipe)
        unless recipe.is_a?(RecipeBase)
          raise ArgumentError, "Receita deve herdar de RecipeBase: #{recipe.class}"
        end

        key = recipe.module_type
        if @recipes.key?(key)
          Core.logger.warn("Receita #{key} sobrescrita por #{recipe.class}")
        end

        @recipes[key] = recipe
        Core.logger.info("Receita registrada: #{key} (#{recipe.name} v#{recipe.version})")
      end

      # Busca receita por tipo de módulo.
      # @param module_type [Symbol]
      # @return [RecipeBase, nil]
      def find(module_type)
        @recipes[module_type.to_sym]
      end

      # Busca receita, levanta erro se não encontrada.
      # @param module_type [Symbol]
      # @return [RecipeBase]
      def find!(module_type)
        recipe = find(module_type)
        unless recipe
          raise Core::DomainError.new(
            "Receita não encontrada: #{module_type}. Disponíveis: #{available_types.join(', ')}",
            code: :recipe_not_found
          )
        end
        recipe
      end

      # Lista tipos de módulo com receita registrada.
      # @return [Array<Symbol>]
      def available_types
        @recipes.keys.sort
      end

      # Lista todas as receitas com metadata.
      # @return [Array<Hash>]
      def catalog
        @recipes.map do |type, recipe|
          {
            type: type,
            name: recipe.name,
            description: recipe.description,
            version: recipe.version,
            parameters: recipe.all_parameters.keys
          }
        end
      end

      # Verifica se existe receita para um tipo.
      # @param module_type [Symbol]
      # @return [Boolean]
      def registered?(module_type)
        @recipes.key?(module_type.to_sym)
      end

      # Total de receitas registradas.
      # @return [Integer]
      def count
        @recipes.length
      end

      # Limpa todas as receitas (usado em testes).
      def clear
        @recipes.clear
      end

      # Registra todas as receitas padrão.
      # Chamado durante bootstrap do plugin.
      def register_defaults
        register(BalcaoSimples.new)
        register(AereoSimples.new)
        register(Gaveteiro.new)
        register(TorreForno.new)
        register(Roupeiro.new)
        register(Nicho.new)
        register(Painel.new)
        register(Tampo.new)
        register(Rodape.new)
        register(Canto.new)
        Core.logger.info("#{count} receitas padrão registradas")
      end
    end
  end
end
