# ornato_plugin/tools/editor_tool.rb — Ferramenta para editar módulos existentes

module Ornato
  module Tools
    class EditorTool
      def activate
        sel = Sketchup.active_model.selection
        if sel.length == 1 && Utils.modulo_ornato?(sel.first)
          editar_modulo(sel.first)
        else
          Sketchup.status_text = 'Ornato Editor: Selecione um módulo Ornato para editar'
        end
      end

      def deactivate(view)
        view.invalidate
      end

      def onLButtonDown(flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        entity = ph.best_picked

        # Procura módulo pai
        grupo = encontrar_modulo(entity)
        if grupo
          editar_modulo(grupo)
        else
          Sketchup.status_text = 'Ornato Editor: Clique em um módulo Ornato'
        end
      end

      def onKeyDown(key, repeat, flags, view)
        Sketchup.active_model.select_tool(nil) if key == VK_ESCAPE
      end

      private

      def encontrar_modulo(entity)
        current = entity
        while current
          return current if Utils.modulo_ornato?(current)
          if current.respond_to?(:parent) && current.parent.is_a?(Sketchup::ComponentDefinition)
            # Navegar para instância
            current.parent.instances.each do |inst|
              return inst if Utils.modulo_ornato?(inst)
            end
          end
          break
        end
        nil
      end

      def editar_modulo(grupo)
        mi = Models::ModuloInfo.carregar_do_grupo(grupo)
        return unless mi

        prompts = [
          'Nome', 'Ambiente',
          'Largura (mm)', 'Altura (mm)', 'Profundidade (mm)',
          'Espessura Corpo', 'Montagem', 'Fundo', 'Base', 'Fixação'
        ]
        defaults = [
          mi.nome, mi.ambiente,
          mi.largura.to_s, mi.altura.to_s, mi.profundidade.to_s,
          mi.espessura_corpo.to_s,
          mi.montagem == Config::MONTAGEM_BRASIL ? 'Brasil' : 'Europa',
          mi.tipo_fundo.to_s.gsub('_', ' ').capitalize,
          mi.tipo_base.to_s.gsub('_', ' ').capitalize,
          mi.fixacao.to_s.capitalize
        ]
        lists = [
          '', '',
          '', '', '',
          '15|18|25',
          'Brasil|Europa',
          'Rebaixado|Sobreposto|Sem fundo',
          'Pes regulaveis|Rodape|Direta|Suspensa',
          'Minifix|Vb|Cavilha|Confirmat'
        ]

        result = ::UI.inputbox(prompts, defaults, lists, "Editar: #{mi.nome}")
        return unless result

        nome, ambiente, l, a, p, esp, mont, fundo, base, fix = result

        mi.nome = nome
        mi.ambiente = ambiente
        mi.largura = l.to_i
        mi.altura = a.to_i
        mi.profundidade = p.to_i
        mi.espessura_corpo = esp.to_i

        montagem_map = { 'Brasil' => Config::MONTAGEM_BRASIL, 'Europa' => Config::MONTAGEM_EUROPA }
        mi.montagem = montagem_map[mont] || Config::MONTAGEM_BRASIL

        fundo_map = { 'Rebaixado' => Config::FUNDO_REBAIXADO, 'Sobreposto' => Config::FUNDO_SOBREPOSTO, 'Sem fundo' => Config::FUNDO_SEM }
        mi.tipo_fundo = fundo_map[fundo] || Config::FUNDO_REBAIXADO

        base_map = { 'Pes regulaveis' => Config::BASE_PES, 'Rodape' => Config::BASE_RODAPE, 'Direta' => Config::BASE_DIRETA, 'Suspensa' => Config::BASE_SUSPENSA }
        mi.tipo_base = base_map[base] || Config::BASE_PES

        fix_map = { 'Minifix' => Config::FIXACAO_MINIFIX, 'Vb' => Config::FIXACAO_VB, 'Cavilha' => Config::FIXACAO_CAVILHA, 'Confirmat' => Config::FIXACAO_CONFIRMAT }
        mi.fixacao = fix_map[fix] || Config::FIXACAO_MINIFIX

        # Reconstrói o módulo
        model = Sketchup.active_model
        model.start_operation('Ornato: Editar Módulo', true)

        pos = grupo.transformation.origin
        model.active_entities.erase_entities(grupo)
        novo_grupo = Engines::MotorCaixa.construir(mi, pos)

        if novo_grupo
          model.selection.clear
          model.selection.add(novo_grupo)
          Sketchup.status_text = "Ornato: Módulo '#{nome}' atualizado"
          Ornato.painel.atualizar if Ornato.painel.visivel?
        end

        model.commit_operation
      end
    end
  end
end
