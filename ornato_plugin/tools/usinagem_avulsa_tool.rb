# ornato_plugin/tools/usinagem_avulsa_tool.rb — Usinagem avulsa (click-to-place)
# Semelhante ao "Usinagens ponto a ponto" do UpMobb
# Permite clicar em uma peça e posicionar usinagens manualmente (furo, canal, pocket, etc.)

module Ornato
  module Tools
    class UsinagemAvulsaTool
      CURSOR_LABEL = 'Ornato: Usinagem Avulsa'

      # Tipos de usinagem disponíveis
      TIPOS_USINAGEM = {
        'Furo passante'       => :furo_passante,
        'Furo cego'           => :furo_cego,
        'Caneco Ø35mm'        => :caneco,
        'Canal reto'          => :canal,
        'Rebaixo (rabbet)'    => :rebaixo,
        'Pocket retangular'   => :pocket,
        'Fresagem gola'       => :gola,
        'Furo puxador'        => :furo_puxador,
        'Furo minifix face'   => :minifix_face,
        'Furo minifix borda'  => :minifix_borda,
        'Furo cavilha'        => :cavilha,
        'Canal p/ fundo'      => :canal_fundo
      }.freeze

      # Ferramentas CNC padrão (diâmetro mm)
      FERRAMENTAS = [3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 35].freeze

      def initialize
        @estado = :selecionando_peca  # :selecionando_peca → :configurando → :posicionando
        @peca_grupo = nil       # grupo da peça selecionada
        @tipo_usinagem = nil    # tipo selecionado
        @params = {}            # parâmetros da usinagem
        @mouse_ip = nil
        @preview_pts = nil      # pontos do preview
        @usinagens_adicionadas = []
      end

      def activate
        Sketchup.status_text = "#{CURSOR_LABEL}: Clique em uma peça Ornato para adicionar usinagem"
        @mouse_ip = Sketchup::InputPoint.new
      end

      def deactivate(view)
        view.invalidate
      end

      def resume(view)
        case @estado
        when :selecionando_peca
          Sketchup.status_text = "#{CURSOR_LABEL}: Clique em uma peça Ornato"
        when :posicionando
          Sketchup.status_text = "#{CURSOR_LABEL}: Clique para posicionar #{@tipo_usinagem} | ESC para cancelar"
        end
      end

      def onMouseMove(flags, x, y, view)
        @mouse_ip.pick(view, x, y)

        if @estado == :posicionando && @peca_grupo
          calcular_preview(view, x, y)
        end

        view.invalidate
      end

      def onLButtonDown(flags, x, y, view)
        case @estado
        when :selecionando_peca
          selecionar_peca(x, y, view)
        when :posicionando
          posicionar_usinagem(x, y, view)
        end
      end

      def onKeyDown(key, repeat, flags, view)
        if key == VK_ESCAPE
          case @estado
          when :posicionando
            # Volta para seleção de peça
            @estado = :selecionando_peca
            @peca_grupo = nil
            @preview_pts = nil
            Sketchup.status_text = "#{CURSOR_LABEL}: Clique em outra peça ou ESC para sair"
            view.invalidate
          else
            Sketchup.active_model.select_tool(nil)
          end
        end
      end

      def draw(view)
        # Highlight da peça selecionada
        if @peca_grupo && @peca_grupo.valid?
          bb = @peca_grupo.bounds
          if bb.valid?
            pts = [
              bb.corner(0), bb.corner(1), bb.corner(3), bb.corner(2), bb.corner(0)
            ]
            view.drawing_color = Sketchup::Color.new(52, 152, 219, 80) # azul
            view.line_width = 2
            view.draw(GL_LINE_STRIP, pts)
          end
        end

        # Preview da usinagem no cursor
        if @preview_pts && @estado == :posicionando
          case @tipo_usinagem
          when :furo_passante, :furo_cego, :caneco, :furo_puxador, :minifix_face, :minifix_borda, :cavilha
            # Desenhar círculo no cursor
            draw_circle_preview(view, @preview_pts[:center], @preview_pts[:raio])
          when :canal, :rebaixo, :canal_fundo, :pocket, :gola
            # Desenhar retângulo no cursor
            draw_rect_preview(view, @preview_pts[:pts])
          end

          # Mostrar info no tooltip
          view.tooltip = @preview_pts[:tooltip] || ''
        end

        # Desenhar usinagens já adicionadas nesta sessão
        @usinagens_adicionadas.each do |ua|
          if ua[:tipo] == :circle
            draw_circle_preview(view, ua[:center], ua[:raio], Sketchup::Color.new(231, 76, 60, 150))
          elsif ua[:tipo] == :rect
            draw_rect_preview(view, ua[:pts], Sketchup::Color.new(231, 76, 60, 150))
          end
        end
      end

      def getExtents
        Sketchup.active_model.bounds
      end

      private

      # ═══ ETAPA 1: Selecionar peça ═══
      def selecionar_peca(x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        entity = ph.best_picked

        unless entity
          Sketchup.status_text = "#{CURSOR_LABEL}: Nenhuma entidade encontrada. Clique em uma peça."
          return
        end

        # Aceita grupos com DICT_PECA ou sub-grupos dentro de módulos Ornato
        grupo = nil
        if entity.is_a?(Sketchup::Group)
          if Utils.get_attr(entity, Config::DICT_PECA, 'tipo')
            grupo = entity
          elsif Utils.modulo_ornato?(entity)
            # É um módulo, pedir para selecionar sub-peça
            Sketchup.status_text = "#{CURSOR_LABEL}: Selecione uma peça individual (sub-grupo), não o módulo inteiro"
            return
          end
        end

        unless grupo
          Sketchup.status_text = "#{CURSOR_LABEL}: Esta entidade não é uma peça Ornato. Use 'Transformar em Peça' primeiro."
          return
        end

        @peca_grupo = grupo
        peca_nome = Utils.get_attr(grupo, Config::DICT_PECA, 'nome') || grupo.name

        # Mostrar diálogo de configuração
        configurar_usinagem(peca_nome)
      end

      # ═══ ETAPA 2: Configurar tipo e parâmetros ═══
      def configurar_usinagem(peca_nome)
        tipos_lista = TIPOS_USINAGEM.keys.join('|')
        ferramentas_lista = FERRAMENTAS.join('|')

        prompts = ['Tipo de Usinagem', 'Ferramenta Ø (mm)', 'Profundidade (mm)', 'Face']
        defaults = ['Furo cego', '8', '12', 'superior']
        lists = [
          tipos_lista,
          ferramentas_lista,
          '',
          'superior|inferior|frontal|traseira|borda_esquerda|borda_direita|borda_topo|borda_base'
        ]

        result = ::UI.inputbox(prompts, defaults, lists, "Ornato: Usinagem em '#{peca_nome}'")
        unless result
          @estado = :selecionando_peca
          @peca_grupo = nil
          return
        end

        @tipo_usinagem = TIPOS_USINAGEM[result[0]] || :furo_cego
        @params = {
          ferramenta: result[1].to_f,
          profundidade: result[2].to_f,
          face: result[3].to_sym
        }

        # Parâmetros adicionais para canais/pockets
        if [:canal, :rebaixo, :canal_fundo, :pocket, :gola].include?(@tipo_usinagem)
          dialog_parametros_canal
        elsif @tipo_usinagem == :caneco
          @params[:ferramenta] = 35.0
          @params[:profundidade] = Config::CANECO_PROF
        elsif @tipo_usinagem == :minifix_face
          @params[:ferramenta] = Config::FURO_MINIFIX_FACE_D
          @params[:profundidade] = Config::FURO_MINIFIX_FACE_PROF
        elsif @tipo_usinagem == :minifix_borda
          @params[:ferramenta] = Config::FURO_MINIFIX_BORDA_D
          @params[:profundidade] = Config::FURO_MINIFIX_BORDA_PROF
        elsif @tipo_usinagem == :cavilha
          @params[:ferramenta] = Config::FURO_CAVILHA_D
          @params[:profundidade] = Config::FURO_CAVILHA_PROF
        elsif @tipo_usinagem == :furo_puxador
          @params[:ferramenta] = Config::FURO_PUXADOR_D
          @params[:profundidade] = 15.0  # passante na maioria dos casos
        end

        @estado = :posicionando
        @usinagens_adicionadas.clear
        Sketchup.status_text = "#{CURSOR_LABEL}: Clique para posicionar #{@tipo_usinagem} | ESC para voltar"
      end

      # Diálogo adicional para canal/pocket
      def dialog_parametros_canal
        prompts = ['Comprimento (mm)', 'Largura do canal (mm)']
        defaults = ['200', '6']

        result = ::UI.inputbox(prompts, defaults, [], 'Ornato: Dimensões da usinagem')
        if result
          @params[:comprimento] = result[0].to_f
          @params[:largura_canal] = result[1].to_f
        else
          @params[:comprimento] = 200.0
          @params[:largura_canal] = 6.0
        end
      end

      # ═══ ETAPA 3: Preview visual no cursor ═══
      def calcular_preview(view, x, y)
        return unless @peca_grupo && @peca_grupo.valid?

        ip = @mouse_ip
        pos = ip.position
        tr = @peca_grupo.transformation.inverse
        local_pos = pos.transform(tr)

        # Converter para mm
        pos_x_mm = local_pos.x.to_mm
        pos_y_mm = local_pos.y.to_mm
        pos_z_mm = local_pos.z.to_mm

        case @tipo_usinagem
        when :furo_passante, :furo_cego, :caneco, :furo_puxador, :minifix_face, :minifix_borda, :cavilha
          raio = Utils.mm(@params[:ferramenta] / 2.0)
          @preview_pts = {
            center: pos,
            raio: raio,
            tooltip: "#{@tipo_usinagem} Ø#{@params[:ferramenta]}mm × #{@params[:profundidade]}mm | (#{pos_x_mm.round(1)}, #{pos_y_mm.round(1)})",
            pos_mm: { x: pos_x_mm, y: pos_y_mm, z: pos_z_mm }
          }
        when :canal, :rebaixo, :canal_fundo, :pocket, :gola
          comp_su = Utils.mm(@params[:comprimento] || 200)
          larg_su = Utils.mm(@params[:largura_canal] || 6)
          pts = [
            Geom::Point3d.new(pos.x, pos.y, pos.z),
            Geom::Point3d.new(pos.x + comp_su, pos.y, pos.z),
            Geom::Point3d.new(pos.x + comp_su, pos.y + larg_su, pos.z),
            Geom::Point3d.new(pos.x, pos.y + larg_su, pos.z),
            Geom::Point3d.new(pos.x, pos.y, pos.z)
          ]
          @preview_pts = {
            pts: pts,
            tooltip: "#{@tipo_usinagem} #{@params[:comprimento]}×#{@params[:largura_canal]}mm × #{@params[:profundidade]}mm",
            pos_mm: { x: pos_x_mm, y: pos_y_mm, z: pos_z_mm }
          }
        end
      end

      # ═══ ETAPA 4: Posicionar usinagem ═══
      def posicionar_usinagem(x, y, view)
        return unless @peca_grupo && @peca_grupo.valid? && @preview_pts

        pos = @mouse_ip.position
        tr = @peca_grupo.transformation.inverse
        local_pos = pos.transform(tr)

        pos_x_mm = local_pos.x.to_mm.round(1)
        pos_y_mm = local_pos.y.to_mm.round(1)

        model = Sketchup.active_model
        model.start_operation("Ornato: Usinagem #{@tipo_usinagem}", true)

        begin
          # Criar a usinagem como dado no dicionário
          usinagem_data = {
            tipo: @tipo_usinagem.to_s,
            x: pos_x_mm,
            y: pos_y_mm,
            ferramenta: @params[:ferramenta],
            profundidade: @params[:profundidade],
            face: @params[:face].to_s,
            origem: 'manual'
          }

          # Parâmetros adicionais
          if @params[:comprimento]
            usinagem_data[:comprimento] = @params[:comprimento]
            usinagem_data[:largura] = @params[:largura_canal]
          end

          if @tipo_usinagem == :caneco
            usinagem_data[:diametro] = Config::CANECO_D
          else
            usinagem_data[:diametro] = @params[:ferramenta]
          end

          # Salvar no dicionário da peça
          salvar_usinagem_no_grupo(@peca_grupo, usinagem_data)

          # Criar representação visual (cilindro para furos, caixa para canais)
          criar_visual_usinagem(@peca_grupo, usinagem_data, local_pos)

          # Registrar para feedback visual
          if [:furo_passante, :furo_cego, :caneco, :furo_puxador, :minifix_face, :minifix_borda, :cavilha].include?(@tipo_usinagem)
            @usinagens_adicionadas << {
              tipo: :circle,
              center: pos,
              raio: Utils.mm(@params[:ferramenta] / 2.0)
            }
          else
            @usinagens_adicionadas << {
              tipo: :rect,
              pts: @preview_pts[:pts]
            }
          end

          model.commit_operation

          peca_nome = Utils.get_attr(@peca_grupo, Config::DICT_PECA, 'nome')
          Sketchup.status_text = "#{CURSOR_LABEL}: Usinagem adicionada em '#{peca_nome}' (#{pos_x_mm}, #{pos_y_mm}) | Clique para mais | ESC"
          puts "[Ornato] Usinagem #{@tipo_usinagem} adicionada: (#{pos_x_mm}, #{pos_y_mm})"

        rescue => e
          model.abort_operation
          puts "[Ornato] ERRO ao adicionar usinagem: #{e.message}"
          puts e.backtrace.first(3).join("\n")
          ::UI.messagebox("Erro: #{e.message}")
        end

        view.invalidate
      end

      # ═══ Salvar usinagem no dicionário do grupo ═══
      def salvar_usinagem_no_grupo(grupo, usinagem_data)
        dict = Config::DICT_PECA

        # Ler usinagens existentes
        usinagens_json = Utils.get_attr(grupo, dict, 'usinagens_manuais')
        usinagens = if usinagens_json && !usinagens_json.empty?
                      begin
                        Utils.parse_json(usinagens_json)
                      rescue
                        []
                      end
                    else
                      []
                    end

        # Garantir que é array
        usinagens = [] unless usinagens.is_a?(Array)

        # Adicionar nova usinagem
        usinagens << usinagem_data

        # Salvar
        grupo.set_attribute(dict, 'usinagens_manuais', Utils.to_json(usinagens))
        grupo.set_attribute(dict, 'usinagens_count', usinagens.length)
      end

      # ═══ Criar visual 3D da usinagem ═══
      def criar_visual_usinagem(grupo, data, local_pos)
        ents = grupo.entities

        # Cor de usinagem (vermelho semi-transparente)
        model = Sketchup.active_model
        mat_usi = Utils.criar_material(model, 'Ornato_Usinagem', Sketchup::Color.new(231, 76, 60, 150))

        case @tipo_usinagem
        when :furo_passante, :furo_cego, :caneco, :furo_puxador, :minifix_face, :minifix_borda, :cavilha
          # Criar cilindro (circulo + pushpull)
          raio_su = Utils.mm(data[:diametro] / 2.0)
          prof_su = Utils.mm(data[:profundidade])

          begin
            # Adicionar sub-grupo para a usinagem
            sub = ents.add_group
            sub.name = "USI_#{data[:tipo]}_#{data[:x].round(0)}x#{data[:y].round(0)}"

            center_pt = Geom::Point3d.new(local_pos.x, local_pos.y, local_pos.z)
            normal = Geom::Vector3d.new(0, 0, 1)

            circle_edges = sub.entities.add_circle(center_pt, normal, raio_su, 24)
            if circle_edges && !circle_edges.empty?
              face = sub.entities.add_face(circle_edges)
              face.pushpull(-prof_su) if face
              sub.material = mat_usi
            end

            # Marcar sub-grupo como usinagem
            sub.set_attribute(Config::DICT_PECA, 'usinagem', true)
            sub.set_attribute(Config::DICT_PECA, 'usinagem_tipo', data[:tipo])
          rescue => e
            puts "[Ornato] Visual usinagem furo: #{e.message}"
          end

        when :canal, :rebaixo, :canal_fundo, :pocket, :gola
          # Criar caixa retangular
          comp_su = Utils.mm(data[:comprimento] || 200)
          larg_su = Utils.mm(data[:largura] || 6)
          prof_su = Utils.mm(data[:profundidade])

          begin
            sub = ents.add_group
            sub.name = "USI_#{data[:tipo]}_#{data[:x].round(0)}x#{data[:y].round(0)}"

            pts = [
              Geom::Point3d.new(local_pos.x, local_pos.y, local_pos.z),
              Geom::Point3d.new(local_pos.x + comp_su, local_pos.y, local_pos.z),
              Geom::Point3d.new(local_pos.x + comp_su, local_pos.y + larg_su, local_pos.z),
              Geom::Point3d.new(local_pos.x, local_pos.y + larg_su, local_pos.z)
            ]

            face = sub.entities.add_face(pts)
            face.pushpull(-prof_su) if face
            sub.material = mat_usi

            sub.set_attribute(Config::DICT_PECA, 'usinagem', true)
            sub.set_attribute(Config::DICT_PECA, 'usinagem_tipo', data[:tipo])
          rescue => e
            puts "[Ornato] Visual usinagem canal: #{e.message}"
          end
        end
      end

      # ═══ Desenhar preview de círculo ═══
      def draw_circle_preview(view, center, raio, cor = nil)
        return unless center
        cor ||= Sketchup::Color.new(230, 126, 34, 180) # laranja

        # Desenhar círculo com 24 segmentos
        pts = []
        24.times do |i|
          angle = (i * 2 * Math::PI) / 24.0
          px = center.x + raio * Math.cos(angle)
          py = center.y + raio * Math.sin(angle)
          pts << Geom::Point3d.new(px, py, center.z)
        end
        pts << pts.first

        view.drawing_color = cor
        view.line_width = 2
        view.draw(GL_LINE_STRIP, pts)

        # Cruz central
        cr = raio * 0.3
        view.draw(GL_LINES, [
          Geom::Point3d.new(center.x - cr, center.y, center.z),
          Geom::Point3d.new(center.x + cr, center.y, center.z),
          Geom::Point3d.new(center.x, center.y - cr, center.z),
          Geom::Point3d.new(center.x, center.y + cr, center.z)
        ])
      end

      # ═══ Desenhar preview de retângulo ═══
      def draw_rect_preview(view, pts, cor = nil)
        return unless pts && pts.length >= 4
        cor ||= Sketchup::Color.new(230, 126, 34, 180)

        view.drawing_color = cor
        view.line_width = 2
        view.draw(GL_LINE_STRIP, pts)

        # Hachura diagonal simples
        view.line_width = 1
        cor_hachura = Sketchup::Color.new(cor.red, cor.green, cor.blue, 80)
        view.drawing_color = cor_hachura
      end
    end
  end
end
