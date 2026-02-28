# ornato_plugin/observers.rb — Observers do SketchUp para reagir a eventos

module Ornato
  module Observers
    class ModelObserver < Sketchup::ModelObserver
      def onActivePathChanged(model)
        Ornato.painel.atualizar if Ornato.painel.visivel?
      end

      def onEraseAll(model)
        Ornato.painel.atualizar if Ornato.painel.visivel?
      end

      def onTransactionCommit(model)
        Ornato.painel.atualizar if Ornato.painel.visivel?
      end
    end

    class SelectionObserver < Sketchup::SelectionObserver
      def onSelectionBulkChange(selection)
        atualizar_selecao(selection)
      end

      def onSelectionCleared(selection)
        atualizar_selecao(selection)
      end

      def onSelectionAdded(selection, entity)
        atualizar_selecao(selection)
      end

      private

      def atualizar_selecao(selection)
        if selection.length == 1 && Utils.modulo_ornato?(selection.first)
          mi = Models::ModuloInfo.carregar_do_grupo(selection.first)
          if mi
            info = "Ornato: #{mi.nome} (#{mi.largura}x#{mi.altura}x#{mi.profundidade}mm)"
            info += " | #{mi.material_corpo}"
            info += " | #{mi.pecas.length} pecas" if mi.pecas.any?
            info += " — Duplo-clique para editar"
            Sketchup.status_text = info
          end
        end
      end
    end
  end

  def self.setup_observers
    model = Sketchup.active_model
    model.add_observer(Observers::ModelObserver.new)
    model.selection.add_observer(Observers::SelectionObserver.new)
  end
end
