# ornato_plugin/tools/transformar_peca_tool.rb — Converter Face/Grupo em Peça Ornato
# Semelhante ao "Converter face em peça" do UpMobb
# Permite clicar em qualquer Face ou Group e transformá-lo em peça reconhecida pelo sistema

module Ornato
  module Tools
    class TransformarPecaTool
      CURSOR_LABEL = 'Ornato: Transformar em Peça'

      # Tipos de peça disponíveis para seleção
      TIPOS_PECA = {
        'Lateral'          => :lateral,
        'Base'             => :base,
        'Topo'             => :topo,
        'Fundo'            => :fundo,
        'Prateleira'       => :prateleira,
        'Divisoria'        => :divisoria,
        'Porta'            => :porta,
        'Frente Gaveta'    => :frente_gaveta,
        'Lateral Gaveta'   => :lateral_gaveta,
        'Traseira Gaveta'  => :traseira_gaveta,
        'Fundo Gaveta'     => :fundo_gaveta,
        'Tampo'            => :tampo,
        'Painel'           => :painel,
        'Rodape'           => :rodape,
        'Requadro'         => :requadro,
        'Moldura'          => :moldura,
        'Custom'           => :custom
      }.freeze

      ESPESSURAS_DISPONIVEIS = [3, 6, 9, 12, 15, 18, 20, 25].freeze

      def initialize
        @mouse_ip = nil
        @hovering = nil       # entidade sob o cursor
        @estado = :selecionando
      end

      def activate
        Sketchup.status_text = "#{CURSOR_LABEL}: Clique em uma Face ou Grupo para transformar em peça"
        @mouse_ip = Sketchup::InputPoint.new
      end

      def deactivate(view)
        view.invalidate
      end

      def resume(view)
        Sketchup.status_text = "#{CURSOR_LABEL}: Clique em uma Face ou Grupo para transformar em peça"
      end

      def onMouseMove(flags, x, y, view)
        @mouse_ip.pick(view, x, y)

        # Detectar entidade sob o cursor
        ph = view.pick_helper
        ph.do_pick(x, y)
        entity = ph.best_picked

        if entity != @hovering
          @hovering = entity
          view.invalidate
        end
      end

      def onLButtonDown(flags, x, y, view)
        return unless @estado == :selecionando

        ph = view.pick_helper
        ph.do_pick(x, y)
        entity = ph.best_picked

        return unless entity

        # Aceita: Group, ComponentInstance, ou Face
        case entity
        when Sketchup::Group, Sketchup::ComponentInstance
          transformar_grupo(entity, view)
        when Sketchup::Face
          transformar_face(entity, view)
        else
          Sketchup.status_text = "#{CURSOR_LABEL}: Selecione uma Face ou Grupo (não #{entity.class})"
        end
      end

      def onKeyDown(key, repeat, flags, view)
        if key == VK_ESCAPE
          Sketchup.active_model.select_tool(nil)
        end
      end

      def draw(view)
        return unless @hovering

        # Highlight da entidade sob o cursor
        if @hovering.is_a?(Sketchup::Group) || @hovering.is_a?(Sketchup::ComponentInstance)
          bb = @hovering.bounds
          if bb.valid?
            pts = [
              bb.corner(0), bb.corner(1), bb.corner(3), bb.corner(2),
              bb.corner(0),
              bb.corner(4), bb.corner(5), bb.corner(7), bb.corner(6),
              bb.corner(4)
            ]
            view.drawing_color = Sketchup::Color.new(46, 204, 113, 100) # verde
            view.line_width = 3
            view.draw(GL_LINE_STRIP, pts[0..4])
            view.draw(GL_LINE_STRIP, pts[5..9])
            4.times do |i|
              view.draw(GL_LINES, [bb.corner(i), bb.corner(i + 4)])
            end
          end
        elsif @hovering.is_a?(Sketchup::Face)
          pts = @hovering.vertices.map(&:position)
          pts << pts.first
          view.drawing_color = Sketchup::Color.new(46, 204, 113, 120)
          view.line_width = 3
          view.draw(GL_LINE_STRIP, pts)
        end
      end

      def getExtents
        bb = Sketchup.active_model.bounds
        bb
      end

      private

      # ═══ Transformar Face em Peça (cria grupo e marca) ═══
      def transformar_face(face, view)
        # Medir a face
        bb = face.bounds
        dims = dimensoes_face(face)

        # Perguntar tipo, espessura, material
        opts = dialog_configuracao(dims)
        return unless opts

        model = Sketchup.active_model
        model.start_operation('Ornato: Transformar Face em Peça', true)

        begin
          # Criar grupo a partir da face
          ents = face.parent.entities rescue model.active_entities
          grupo = ents.add_group(face)
          grupo.name = opts[:nome]

          # Se espessura > 0 e face é plana, fazer pushpull para dar volume
          if opts[:espessura] > 0 && grupo.entities.grep(Sketchup::Face).any?
            peca_face = grupo.entities.grep(Sketchup::Face).first
            esp_su = Utils.mm(Config.espessura_real(opts[:espessura]))
            peca_face.pushpull(-esp_su) if peca_face
          end

          # Marcar como peça Ornato
          marcar_grupo_como_peca(grupo, opts, dims)

          # Selecionar o grupo criado
          model.selection.clear
          model.selection.add(grupo)

          model.commit_operation
          Sketchup.status_text = "#{CURSOR_LABEL}: '#{opts[:nome]}' criado! Clique em outra face ou ESC"
          puts "[Ornato] Face transformada em peça: #{opts[:nome]} (#{opts[:tipo]})"

        rescue => e
          model.abort_operation
          puts "[Ornato] ERRO ao transformar face: #{e.message}"
          puts e.backtrace.first(3).join("\n")
          ::UI.messagebox("Erro: #{e.message}")
        end
      end

      # ═══ Transformar Grupo existente em Peça Ornato ═══
      def transformar_grupo(grupo, view)
        # Verificar se já é peça Ornato
        if Utils.get_attr(grupo, Config::DICT_PECA, 'tipo')
          resp = ::UI.messagebox("Este grupo já é uma peça Ornato (#{Utils.get_attr(grupo, Config::DICT_PECA, 'nome')}). Reconfigurar?", MB_YESNO)
          return unless resp == IDYES
        end

        # Medir o grupo
        dims = dimensoes_grupo(grupo)

        # Perguntar tipo, espessura, material
        opts = dialog_configuracao(dims, grupo.name)
        return unless opts

        model = Sketchup.active_model
        model.start_operation('Ornato: Identificar Peça', true)

        begin
          grupo.name = opts[:nome]
          marcar_grupo_como_peca(grupo, opts, dims)

          model.selection.clear
          model.selection.add(grupo)

          model.commit_operation
          Sketchup.status_text = "#{CURSOR_LABEL}: '#{opts[:nome]}' identificado! Clique em outra peça ou ESC"
          puts "[Ornato] Grupo identificado como peça: #{opts[:nome]} (#{opts[:tipo]})"

        rescue => e
          model.abort_operation
          puts "[Ornato] ERRO ao identificar grupo: #{e.message}"
          ::UI.messagebox("Erro: #{e.message}")
        end
      end

      # ═══ Dialog de configuração ═══
      def dialog_configuracao(dims, nome_atual = nil)
        tipos_lista = TIPOS_PECA.keys.join('|')
        espessuras_lista = ESPESSURAS_DISPONIVEIS.join('|')

        # Materiais disponíveis
        materiais = Models::BibliotecaMateriais.listar.map { |m| m[:nome] }
        materiais_lista = materiais.join('|')

        # Detectar espessura mais próxima
        esp_detectada = detectar_espessura(dims[:espessura_mm])

        prompts = [
          'Nome da Peça',
          'Tipo',
          'Espessura nominal (mm)',
          'Material',
          'Incluir na lista de corte?'
        ]
        defaults = [
          nome_atual || "Peça #{dims[:comp_mm].round(0)}x#{dims[:larg_mm].round(0)}",
          'Custom',
          esp_detectada.to_s,
          'MDF Branco 15mm',
          'Sim'
        ]
        lists = [
          '',
          tipos_lista,
          espessuras_lista,
          materiais_lista,
          'Sim|Nao'
        ]

        result = ::UI.inputbox(prompts, defaults, lists, 'Ornato: Configurar Peça')
        return nil unless result

        tipo_sym = TIPOS_PECA[result[1]] || :custom

        {
          nome: result[0],
          tipo: tipo_sym,
          espessura: result[2].to_i,
          material: result[3],
          incluir_corte: result[4] == 'Sim',
          comprimento: dims[:comp_mm].round(1),
          largura: dims[:larg_mm].round(1)
        }
      end

      # ═══ Marca grupo com atributos DICT_PECA ═══
      def marcar_grupo_como_peca(grupo, opts, dims)
        dict = Config::DICT_PECA

        grupo.set_attribute(dict, 'nome', opts[:nome])
        grupo.set_attribute(dict, 'tipo', opts[:tipo].to_s)
        grupo.set_attribute(dict, 'comprimento', opts[:comprimento] || dims[:comp_mm].round(1))
        grupo.set_attribute(dict, 'largura', opts[:largura] || dims[:larg_mm].round(1))
        grupo.set_attribute(dict, 'espessura', opts[:espessura])
        grupo.set_attribute(dict, 'espessura_real', Config.espessura_real(opts[:espessura]))
        grupo.set_attribute(dict, 'material', opts[:material])
        grupo.set_attribute(dict, 'incluir_corte', opts[:incluir_corte])
        grupo.set_attribute(dict, 'origem', 'manual')  # marca que foi criado manualmente

        # Extrair contorno 2D (se não for retangular simples)
        begin
          contorno = Engines::MotorContorno.extrair(grupo)
          if contorno
            grupo.set_attribute(dict, 'tem_contorno', true)
            grupo.set_attribute(dict, 'contorno_json', Utils.to_json(contorno))
          else
            grupo.set_attribute(dict, 'tem_contorno', false)
          end
        rescue => e
          puts "[Ornato] Aviso: contorno não extraído: #{e.message}"
          grupo.set_attribute(dict, 'tem_contorno', false)
        end

        # Aplicar cor visual de identificação
        model = Sketchup.active_model
        cor = cor_por_tipo(opts[:tipo])
        mat = Utils.criar_material(model, "Ornato_Peca_#{opts[:tipo]}", cor)
        grupo.material = mat
      end

      # ═══ Medir dimensões de uma Face ═══
      def dimensoes_face(face)
        bb = face.bounds
        w = bb.width.to_mm
        h = bb.height.to_mm
        d = bb.depth.to_mm

        # A face é 2D, então uma dimensão será ~0
        dims = [w, h, d].sort.reverse
        {
          comp_mm: dims[0],         # maior dimensão
          larg_mm: dims[1],         # segunda dimensão
          espessura_mm: dims[2]     # menor (quase 0 para faces planas)
        }
      end

      # ═══ Medir dimensões de um Grupo ═══
      def dimensoes_grupo(grupo)
        bb = grupo.bounds
        w = bb.width.to_mm
        h = bb.height.to_mm
        d = bb.depth.to_mm

        # Ordenar: comprimento > largura > espessura
        dims = [w, h, d].sort.reverse
        {
          comp_mm: dims[0],
          larg_mm: dims[1],
          espessura_mm: dims[2]
        }
      end

      # ═══ Detecta espessura nominal mais próxima ═══
      def detectar_espessura(esp_mm)
        return 15 if esp_mm < 1  # face plana, assumir 15mm

        # Verificar espessuras reais (15.5, 18.5, etc.)
        Config::ESPESSURA_REAL.each do |nominal, real|
          return nominal if (esp_mm - real).abs < 1.0
        end

        # Se não encontrou, pegar a mais próxima
        ESPESSURAS_DISPONIVEIS.min_by { |e| (Config.espessura_real(e) - esp_mm).abs }
      end

      # ═══ Cor de identificação por tipo ═══
      def cor_por_tipo(tipo)
        case tipo
        when :lateral         then Sketchup::Color.new(240, 235, 220)   # bege
        when :base, :topo     then Sketchup::Color.new(220, 215, 200)   # bege escuro
        when :fundo           then Sketchup::Color.new(255, 255, 255)   # branco
        when :prateleira      then Sketchup::Color.new(200, 220, 240)   # azul claro
        when :divisoria       then Sketchup::Color.new(220, 240, 200)   # verde claro
        when :porta           then Sketchup::Color.new(180, 140, 100)   # carvalho
        when :frente_gaveta   then Sketchup::Color.new(180, 140, 100)
        when :lateral_gaveta, :traseira_gaveta, :fundo_gaveta
          Sketchup::Color.new(240, 230, 210)
        when :tampo           then Sketchup::Color.new(160, 160, 160)   # cinza
        when :painel          then Sketchup::Color.new(210, 200, 180)
        when :rodape          then Sketchup::Color.new(200, 180, 160)
        when :custom          then Sketchup::Color.new(230, 126, 34)    # laranja Ornato
        else
          Sketchup::Color.new(230, 126, 34)
        end
      end
    end
  end
end
