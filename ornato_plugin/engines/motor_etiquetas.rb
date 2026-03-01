# ornato_plugin/engines/motor_etiquetas.rb — Motor de etiquetas de produção
# Gera etiquetas inteligentes para cada peça cortada, com informações
# completas para o marceneiro: dimensões, material, fita de borda,
# furação, usinagem, posição no módulo e sequência de montagem.
# Suporta impressão individual (100×70mm) e em folha A4 (grade).

module Ornato
  module Engines
    class MotorEtiquetas

      # ═══════════════════════════════════════════════
      # ESTRUTURA DA ETIQUETA
      # ═══════════════════════════════════════════════
      Etiqueta = Struct.new(
        :modulo_nome,       # nome do módulo (ex: "Inferior Cozinha 600")
        :modulo_id,         # ID único do módulo
        :peca_nome,         # nome da peça (ex: "Lateral Esquerda")
        :peca_tipo,         # tipo simbólico (:lateral, :base, :topo, :porta, etc.)
        :comprimento,       # mm — dimensão maior (nominal)
        :largura,           # mm — dimensão menor (nominal)
        :espessura,         # mm — espessura nominal (15, 18, 25)
        :espessura_real,    # mm — espessura real do MDF (15.5, 18.5, 25.5)
        :material,          # nome do material (ex: "MDF Branco 15mm")
        :fita_codigo,       # código visual: ■□□■ (frente/topo/tras/base)
        :fita_descricao,    # texto descritivo por borda
        :furacao_resumo,    # resumo da furação (texto)
        :usinagem_resumo,   # resumo das usinagens (texto)
        :posicao_modulo,    # posição no módulo (:esquerda, :direita, :topo, :base, :fundo, etc.)
        :ambiente,          # ambiente/cômodo (ex: "Cozinha", "Quarto")
        :codigo_barras,     # identificador único para código de barras/QR
        :sequencia,         # número de sequência para montagem (1 = primeira peça)
        :quantidade,        # quantidade de peças iguais
        :observacoes,       # notas e avisos para o marceneiro
        keyword_init: true
      )

      # ═══════════════════════════════════════════════
      # CONSTANTES
      # ═══════════════════════════════════════════════

      # Ordem de montagem por tipo de peça (menor = montar primeiro)
      ORDEM_MONTAGEM = {
        rodape:          1,
        base:            2,
        lateral:         3,
        divisoria:       4,
        prateleira:      5,
        topo:            6,
        fundo:           7,
        traseira_gaveta: 8,
        lateral_gaveta:  9,
        fundo_gaveta:    10,
        frente_gaveta:   11,
        porta:           12,
        tampo:           13,
        requadro:        14,
        moldura:         15,
        painel:          16,
        generica:        99
      }.freeze

      # Mapeamento tipo de peça → posição legível no módulo
      POSICAO_POR_TIPO = {
        lateral:         'Lateral',
        base:            'Base (inferior)',
        topo:            'Topo (superior)',
        fundo:           'Fundo (traseira)',
        prateleira:      'Prateleira interna',
        divisoria:       'Divisória vertical',
        porta:           'Porta frontal',
        frente_gaveta:   'Frente de gaveta',
        lateral_gaveta:  'Lateral de gaveta',
        traseira_gaveta: 'Traseira de gaveta',
        fundo_gaveta:    'Fundo de gaveta',
        rodape:          'Rodapé',
        tampo:           'Tampo',
        requadro:        'Requadro',
        moldura:         'Moldura',
        painel:          'Painel',
        ripa:            'Ripa',
        montante:        'Montante',
        generica:        'Peça genérica'
      }.freeze

      # Nomes das bordas para descrição de fita
      NOMES_BORDAS = {
        frente: 'Frente',
        topo:   'Topo',
        tras:   'Trás',
        base:   'Base'
      }.freeze

      # ═══════════════════════════════════════════════
      # GERAR ETIQUETAS PARA UM MÓDULO
      # ═══════════════════════════════════════════════
      # Recebe um ModuloInfo com pecas preenchidas.
      # Retorna array de Etiqueta, uma por peça (considerando quantidade).
      def self.gerar_etiquetas(modulo_info)
        mi = modulo_info
        return [] unless mi && mi.pecas && !mi.pecas.empty?

        # Obtém mapa de furação e usinagem se os motores estiverem disponíveis
        mapa_furacao = obter_mapa_furacao(mi)
        mapa_usinagem = obter_mapa_usinagem(mi)

        # Determina sequência de montagem
        seq_montagem = sequenciar_montagem(mi)

        etiquetas = []
        contador_lateral = 0

        mi.pecas.each do |peca|
          # Determina posição específica no módulo
          posicao = determinar_posicao(peca, mi, contador_lateral)
          contador_lateral += 1 if peca.tipo == :lateral

          # Resumo de furação para esta peça
          furacao = resumo_furacao(peca, mapa_furacao)

          # Resumo de usinagem para esta peça
          usinagem = resumo_usinagem(peca, mapa_usinagem)

          # Sequência de montagem
          seq = seq_montagem[peca.nome] || ORDEM_MONTAGEM[peca.tipo] || 99

          # Descrição detalhada da fita de borda
          fita_desc = descricao_fita(peca)

          # Observações inteligentes
          obs = gerar_observacoes(peca, mi)

          # Código de barras único
          codigo = gerar_codigo_barras(mi, peca)

          etiqueta = Etiqueta.new(
            modulo_nome:    mi.nome,
            modulo_id:      mi.id,
            peca_nome:      peca.nome,
            peca_tipo:      peca.tipo,
            comprimento:    peca.comprimento,
            largura:        peca.largura,
            espessura:      peca.espessura,
            espessura_real: peca.espessura_real,
            material:       peca.material,
            fita_codigo:    peca.fita_codigo,
            fita_descricao: fita_desc,
            furacao_resumo: furacao,
            usinagem_resumo: usinagem,
            posicao_modulo: posicao,
            ambiente:       mi.ambiente || 'Geral',
            codigo_barras:  codigo,
            sequencia:      seq,
            quantidade:     peca.quantidade || 1,
            observacoes:    obs
          )

          etiquetas << etiqueta
        end

        # Ordena por sequência de montagem
        etiquetas.sort_by! { |e| [e.sequencia, e.peca_nome] }

        etiquetas
      end

      # ═══════════════════════════════════════════════
      # GERAR ETIQUETAS PARA TODO O PROJETO
      # ═══════════════════════════════════════════════
      # Recebe array de ModuloInfo (ou nil para buscar do modelo ativo).
      # Retorna array de Etiqueta para todas as peças do projeto.
      def self.gerar_etiquetas_projeto(modulos = nil)
        modulos ||= carregar_modulos_do_modelo

        todas = []
        seq_global = 1

        modulos.each do |mi|
          etiquetas_modulo = gerar_etiquetas(mi)
          etiquetas_modulo.each do |et|
            et.sequencia = seq_global
            seq_global += 1
            todas << et
          end
        end

        todas
      end

      # ═══════════════════════════════════════════════
      # AGRUPAR PEÇAS IGUAIS
      # ═══════════════════════════════════════════════
      # Consolida peças com mesmas dimensões, material e fita de borda.
      # Retorna array de Etiqueta com quantidade acumulada,
      # ordenada por material → comprimento → largura.
      def self.agrupar_pecas_iguais(etiquetas)
        return [] if etiquetas.nil? || etiquetas.empty?

        grupos = {}

        etiquetas.each do |et|
          # Chave de agrupamento: dimensões + material + fita
          chave = [
            et.comprimento,
            et.largura,
            et.espessura,
            et.material,
            et.fita_codigo
          ].join('|')

          if grupos[chave]
            grupos[chave].quantidade += et.quantidade
            # Acumula módulos de origem nas observações
            if et.modulo_nome && !grupos[chave].observacoes.to_s.include?(et.modulo_nome)
              obs_existente = grupos[chave].observacoes.to_s
              modulos_lista = obs_existente.empty? ? et.modulo_nome : "#{obs_existente}, #{et.modulo_nome}"
              grupos[chave].observacoes = modulos_lista
            end
          else
            # Cria cópia para o grupo
            agrupada = Etiqueta.new(
              modulo_nome:     et.modulo_nome,
              modulo_id:       et.modulo_id,
              peca_nome:       et.peca_nome,
              peca_tipo:       et.peca_tipo,
              comprimento:     et.comprimento,
              largura:         et.largura,
              espessura:       et.espessura,
              espessura_real:  et.espessura_real,
              material:        et.material,
              fita_codigo:     et.fita_codigo,
              fita_descricao:  et.fita_descricao,
              furacao_resumo:  et.furacao_resumo,
              usinagem_resumo: et.usinagem_resumo,
              posicao_modulo:  et.posicao_modulo,
              ambiente:        et.ambiente,
              codigo_barras:   et.codigo_barras,
              sequencia:       et.sequencia,
              quantidade:      et.quantidade,
              observacoes:     et.modulo_nome
            )
            grupos[chave] = agrupada
          end
        end

        # Ordena por material, depois comprimento decrescente, depois largura
        grupos.values.sort_by { |e| [e.material, -e.comprimento, -e.largura] }
      end

      # ═══════════════════════════════════════════════
      # GERAR HTML PARA IMPRESSÃO DE ETIQUETAS
      # ═══════════════════════════════════════════════
      # Opções:
      #   formato:         :individual (100×70mm, uma por página) ou :folha (grade A4)
      #   incluir_qrcode:  true/false — incluir placeholder para QR code
      #   incluir_furacao:  true/false — mostrar resumo de furação
      #   titulo_projeto:  string — título do projeto no cabeçalho
      def self.gerar_html_etiquetas(etiquetas, opts = {})
        formato        = opts[:formato] || :individual
        incluir_qrcode = opts.fetch(:incluir_qrcode, true)
        incluir_furacao = opts.fetch(:incluir_furacao, true)
        titulo_projeto = opts[:titulo_projeto] || 'Projeto Ornato'

        return '<p>Nenhuma etiqueta para gerar.</p>' if etiquetas.nil? || etiquetas.empty?

        css = css_etiquetas(formato)

        cards = etiquetas.map do |et|
          html_etiqueta_card(et, incluir_qrcode: incluir_qrcode, incluir_furacao: incluir_furacao)
        end.join("\n")

        container_class = formato == :folha ? 'grade-a4' : 'individual'

        <<~HTML
          <!DOCTYPE html>
          <html lang="pt-BR">
          <head>
            <meta charset="UTF-8">
            <title>Etiquetas — #{titulo_projeto}</title>
            <style>#{css}</style>
          </head>
          <body>
            <div class="container #{container_class}">
              #{cards}
            </div>
          </body>
          </html>
        HTML
      end

      # ═══════════════════════════════════════════════
      # GERAR ROTEIRO DE PRODUÇÃO
      # ═══════════════════════════════════════════════
      # Organiza as etiquetas em um roteiro passo a passo
      # para a produção na marcenaria.
      # Retorna hash estruturado com etapas e peças por etapa.
      def self.gerar_roteiro_producao(etiquetas)
        return {} if etiquetas.nil? || etiquetas.empty?

        roteiro = {
          titulo: 'Roteiro de Produção',
          data_geracao: Time.now.strftime('%d/%m/%Y %H:%M'),
          total_pecas: etiquetas.sum { |e| e.quantidade },
          etapas: []
        }

        # ── Etapa 1: Plano de Corte ──
        pecas_corte = etiquetas.map do |et|
          {
            nome: et.peca_nome,
            modulo: et.modulo_nome,
            comprimento: et.comprimento,
            largura: et.largura,
            espessura: et.espessura,
            material: et.material,
            quantidade: et.quantidade,
            codigo: et.codigo_barras
          }
        end
        # Agrupa por material para corte eficiente
        por_material_corte = pecas_corte.group_by { |p| "#{p[:material]} (#{p[:espessura]}mm)" }
        roteiro[:etapas] << {
          numero: 1,
          nome: 'Plano de Corte',
          descricao: 'Cortar todas as peças na esquadrejadeira conforme o plano de corte',
          icone: 'corte',
          pecas_por_grupo: por_material_corte,
          total_pecas: pecas_corte.sum { |p| p[:quantidade] }
        }

        # ── Etapa 2: Fitagem (fita de borda) ──
        pecas_fitagem = etiquetas.select { |et| et.fita_codigo && et.fita_codigo.include?('■') }
        pecas_sem_fita = etiquetas.select { |et| et.fita_codigo.nil? || !et.fita_codigo.include?('■') }
        por_fita = pecas_fitagem.group_by { |et| et.fita_codigo }
        roteiro[:etapas] << {
          numero: 2,
          nome: 'Fitagem (Fita de Borda)',
          descricao: 'Aplicar fita de borda nas peças marcadas. Conferir código de fita na etiqueta.',
          icone: 'fita',
          pecas: pecas_fitagem.map { |et| resumo_peca_roteiro(et) },
          por_codigo_fita: por_fita.transform_values { |ets| ets.map { |et| resumo_peca_roteiro(et) } },
          pecas_sem_fita: pecas_sem_fita.map { |et| resumo_peca_roteiro(et) },
          total_pecas: pecas_fitagem.sum { |e| e.quantidade }
        }

        # ── Etapa 3: Furação ──
        pecas_furacao = etiquetas.select { |et| et.furacao_resumo && !et.furacao_resumo.empty? && et.furacao_resumo != 'Sem furação' }
        roteiro[:etapas] << {
          numero: 3,
          nome: 'Furação',
          descricao: 'Executar furação conforme mapa. Conferir diâmetro e profundidade.',
          icone: 'furacao',
          pecas: pecas_furacao.map { |et|
            r = resumo_peca_roteiro(et)
            r[:furacao] = et.furacao_resumo
            r
          },
          total_pecas: pecas_furacao.sum { |e| e.quantidade }
        }

        # ── Etapa 4: Usinagem (CNC / tupia) ──
        pecas_usinagem = etiquetas.select { |et| et.usinagem_resumo && !et.usinagem_resumo.empty? && et.usinagem_resumo != 'Sem usinagem' }
        roteiro[:etapas] << {
          numero: 4,
          nome: 'Usinagem',
          descricao: 'Executar usinagens CNC: canais, rebaixos, fresagem de perfil, pockets.',
          icone: 'usinagem',
          pecas: pecas_usinagem.map { |et|
            r = resumo_peca_roteiro(et)
            r[:usinagem] = et.usinagem_resumo
            r
          },
          total_pecas: pecas_usinagem.sum { |e| e.quantidade }
        }

        # ── Etapa 5: Pré-montagem (agrupar por módulo) ──
        por_modulo = etiquetas.group_by { |et| et.modulo_nome }
        grupos_pre = por_modulo.map do |nome_modulo, ets|
          {
            modulo: nome_modulo,
            ambiente: ets.first.ambiente,
            pecas: ets.sort_by { |e| e.sequencia }.map { |et| resumo_peca_roteiro(et) },
            total_pecas: ets.sum { |e| e.quantidade }
          }
        end
        roteiro[:etapas] << {
          numero: 5,
          nome: 'Pré-montagem',
          descricao: 'Separar peças por módulo. Conferir se todas as peças estão presentes.',
          icone: 'premontagem',
          grupos: grupos_pre,
          total_pecas: etiquetas.sum { |e| e.quantidade }
        }

        # ── Etapa 6: Montagem Final ──
        montagem_por_modulo = por_modulo.map do |nome_modulo, ets|
          ets_ordenadas = ets.sort_by { |e| ORDEM_MONTAGEM[e.peca_tipo] || 99 }
          {
            modulo: nome_modulo,
            ambiente: ets.first.ambiente,
            sequencia_montagem: ets_ordenadas.map { |et|
              {
                passo: ORDEM_MONTAGEM[et.peca_tipo] || 99,
                peca: et.peca_nome,
                tipo: et.peca_tipo,
                posicao: et.posicao_modulo,
                quantidade: et.quantidade,
                instrucao: instrucao_montagem(et)
              }
            }
          }
        end
        roteiro[:etapas] << {
          numero: 6,
          nome: 'Montagem Final',
          descricao: 'Montar módulos seguindo a sequência: base → laterais → divisórias → prateleiras → topo → fundo → portas/gavetas.',
          icone: 'montagem',
          modulos: montagem_por_modulo,
          total_pecas: etiquetas.sum { |e| e.quantidade }
        }

        roteiro
      end

      # ═══════════════════════════════════════════════
      # SEQUENCIAR MONTAGEM
      # ═══════════════════════════════════════════════
      # Determina a ordem de montagem das peças de um módulo.
      # Lógica: base → laterais → divisórias → prateleiras →
      #         topo → fundo → gavetas → portas
      # Retorna hash { peca_nome => numero_sequencia }
      def self.sequenciar_montagem(modulo_info)
        mi = modulo_info
        return {} unless mi && mi.pecas

        sequencia = {}
        seq = 1

        # Agrupa peças por tipo na ordem correta de montagem
        tipos_ordenados = mi.pecas
          .sort_by { |p| [ORDEM_MONTAGEM[p.tipo] || 99, p.nome] }

        tipos_ordenados.each do |peca|
          sequencia[peca.nome] = seq
          seq += 1
        end

        sequencia
      end

      # ═══════════════════════════════════════════════
      # EXPORTAR PARA JSON
      # ═══════════════════════════════════════════════
      def self.exportar_json(etiquetas)
        dados = etiquetas.map do |et|
          {
            modulo_nome:     et.modulo_nome,
            modulo_id:       et.modulo_id,
            peca_nome:       et.peca_nome,
            peca_tipo:       et.peca_tipo.to_s,
            comprimento:     et.comprimento,
            largura:         et.largura,
            espessura:       et.espessura,
            espessura_real:  et.espessura_real,
            material:        et.material,
            fita_codigo:     et.fita_codigo,
            fita_descricao:  et.fita_descricao,
            furacao_resumo:  et.furacao_resumo,
            usinagem_resumo: et.usinagem_resumo,
            posicao_modulo:  et.posicao_modulo,
            ambiente:        et.ambiente,
            codigo_barras:   et.codigo_barras,
            sequencia:       et.sequencia,
            quantidade:      et.quantidade,
            observacoes:     et.observacoes
          }
        end
        Utils.to_json(dados)
      end

      # ═══════════════════════════════════════════════
      # RELATÓRIO TEXTO FORMATADO
      # ═══════════════════════════════════════════════
      def self.relatorio_texto(etiquetas)
        return "Nenhuma etiqueta gerada." if etiquetas.nil? || etiquetas.empty?

        linhas = []
        linhas << "═══════════════════════════════════════════════"
        linhas << "  RELATÓRIO DE ETIQUETAS DE PRODUÇÃO"
        linhas << "  Gerado em: #{Time.now.strftime('%d/%m/%Y %H:%M')}"
        linhas << "  Total de peças: #{etiquetas.sum { |e| e.quantidade }}"
        linhas << "═══════════════════════════════════════════════"

        modulo_atual = nil
        etiquetas.each do |et|
          if et.modulo_nome != modulo_atual
            modulo_atual = et.modulo_nome
            linhas << ""
            linhas << "── Módulo: #{modulo_atual} (#{et.ambiente}) ──"
          end

          qtd_str = et.quantidade > 1 ? " (#{et.quantidade}x)" : ""
          linhas << "  #{et.sequencia}. #{et.peca_nome}#{qtd_str}"
          linhas << "     #{et.comprimento} × #{et.largura} × #{et.espessura}mm (real: #{et.espessura_real}mm)"
          linhas << "     Material: #{et.material}"
          linhas << "     Fita: #{et.fita_codigo} — #{et.fita_descricao}"
          linhas << "     Furação: #{et.furacao_resumo}" if et.furacao_resumo && et.furacao_resumo != 'Sem furação'
          linhas << "     Usinagem: #{et.usinagem_resumo}" if et.usinagem_resumo && et.usinagem_resumo != 'Sem usinagem'
          linhas << "     Posição: #{et.posicao_modulo}"
          linhas << "     Código: #{et.codigo_barras}"
          linhas << "     OBS: #{et.observacoes}" if et.observacoes && !et.observacoes.empty?
        end

        linhas << ""
        linhas << "═══════════════════════════════════════════════"
        linhas.join("\n")
      end

      # ═══════════════════════════════════════════════
      # MÉTODOS PRIVADOS
      # ═══════════════════════════════════════════════
      private

      # ── Obtém mapa de furação do motor, se disponível ──
      def self.obter_mapa_furacao(modulo_info)
        if defined?(MotorFuracao) && MotorFuracao.respond_to?(:gerar_mapa)
          MotorFuracao.gerar_mapa(modulo_info)
        else
          {}
        end
      rescue => e
        puts "MotorEtiquetas: Aviso — não foi possível gerar mapa de furação: #{e.message}"
        {}
      end

      # ── Obtém mapa de usinagem do motor, se disponível ──
      def self.obter_mapa_usinagem(modulo_info)
        if defined?(MotorUsinagem) && MotorUsinagem.respond_to?(:gerar_mapa)
          MotorUsinagem.gerar_mapa(modulo_info)
        else
          {}
        end
      rescue => e
        puts "MotorEtiquetas: Aviso — não foi possível gerar mapa de usinagem: #{e.message}"
        {}
      end

      # ── Carrega módulos do modelo SketchUp ativo ──
      def self.carregar_modulos_do_modelo
        modulos_info = []
        grupos = Utils.listar_modulos
        grupos.each do |grupo|
          mi = Models::ModuloInfo.carregar_do_grupo(grupo)
          modulos_info << mi if mi
        end
        modulos_info
      end

      # ── Determina posição específica da peça no módulo ──
      def self.determinar_posicao(peca, modulo_info, contador_lateral)
        case peca.tipo
        when :lateral
          contador_lateral == 0 ? 'Lateral esquerda' : 'Lateral direita'
        when :base
          'Base (inferior)'
        when :topo
          'Topo (superior)'
        when :fundo
          'Fundo (traseira)'
        when :prateleira
          POSICAO_POR_TIPO[:prateleira]
        when :divisoria
          'Divisória interna'
        when :porta
          'Porta frontal'
        when :frente_gaveta
          'Frente de gaveta'
        when :lateral_gaveta
          'Lateral de gaveta'
        when :traseira_gaveta
          'Traseira de gaveta'
        when :fundo_gaveta
          'Fundo de gaveta'
        else
          POSICAO_POR_TIPO[peca.tipo] || 'Peça genérica'
        end
      end

      # ── Gera resumo textual da furação de uma peça ──
      def self.resumo_furacao(peca, mapa_furacao)
        furos = mapa_furacao[peca.nome]
        return 'Sem furação' unless furos && !furos.empty?

        # Conta furos por tipo
        por_tipo = furos.group_by { |f| f.tipo.to_s }
        partes = por_tipo.map do |tipo, lista|
          nome_tipo = traduzir_tipo_furo(tipo)
          "#{lista.size}× #{nome_tipo}"
        end

        partes.join(', ')
      end

      # ── Traduz tipo de furo para português ──
      def self.traduzir_tipo_furo(tipo)
        case tipo.to_s
        when 'minifix_face'     then 'Minifix (face)'
        when 'minifix_borda'    then 'Minifix (borda)'
        when 'cavilha'          then 'Cavilha'
        when 'caneco'           then 'Caneco 35mm'
        when 'confirmat_face'   then 'Confirmat (face)'
        when 'confirmat_borda'  then 'Confirmat (borda)'
        when 'pin'              then 'Pino prateleira'
        when 'puxador'          then 'Puxador'
        when 'sistema32'        then 'Sistema 32'
        else tipo.to_s.gsub('_', ' ').capitalize
        end
      end

      # ── Gera resumo textual da usinagem de uma peça ──
      def self.resumo_usinagem(peca, mapa_usinagem)
        usinagens = mapa_usinagem[peca.nome]
        return 'Sem usinagem' unless usinagens && !usinagens.empty?

        # Conta usinagens por tipo
        por_tipo = usinagens.group_by { |u| u.tipo.to_s }
        partes = por_tipo.map do |tipo, lista|
          nome_tipo = traduzir_tipo_usinagem(tipo)
          "#{lista.size}× #{nome_tipo}"
        end

        partes.join(', ')
      end

      # ── Traduz tipo de usinagem para português ──
      def self.traduzir_tipo_usinagem(tipo)
        case tipo.to_s
        when 'canal'            then 'Canal'
        when 'rebaixo'          then 'Rebaixo'
        when 'fresagem_perfil'  then 'Fresagem perfil'
        when 'pocket'           then 'Pocket'
        when 'rasgo'            then 'Rasgo'
        when 'dado'             then 'Dado/Housing'
        when 'gola'             then 'Gola'
        when 'furo'             then 'Furação CNC'
        else tipo.to_s.gsub('_', ' ').capitalize
        end
      end

      # ── Descrição detalhada da fita de borda por aresta ──
      def self.descricao_fita(peca)
        bordas = []

        if peca.fita_frente
          bordas << "Frente: #{peca.fita_material || 'PVC 1mm'} (#{peca.comprimento}mm)"
        end
        if peca.fita_topo
          bordas << "Topo: #{peca.fita_material || 'PVC 1mm'} (#{peca.largura}mm)"
        end
        if peca.fita_tras
          bordas << "Trás: #{peca.fita_material || 'PVC 1mm'} (#{peca.comprimento}mm)"
        end
        if peca.fita_base
          bordas << "Base: #{peca.fita_material || 'PVC 1mm'} (#{peca.largura}mm)"
        end

        bordas.empty? ? 'Sem fita de borda' : bordas.join(' | ')
      end

      # ── Gera observações inteligentes para o marceneiro ──
      def self.gerar_observacoes(peca, modulo_info)
        obs = []

        # Aviso de espessura real vs nominal
        if peca.espessura_real != peca.espessura
          obs << "Esp. real #{peca.espessura_real}mm (nominal #{peca.espessura}mm)"
        end

        # Aviso para peças com 4 lados de fita (conferir dimensão de corte)
        todas_fitas = peca.fita_frente && peca.fita_topo && peca.fita_tras && peca.fita_base
        if todas_fitas
          obs << "4 bordas com fita — conferir dimensão de corte descontada"
        end

        # Aviso para fundos (espessura fina, cuidado no manuseio)
        if peca.tipo == :fundo || peca.tipo == :fundo_gaveta
          obs << "Peça fina — manuseio cuidadoso"
        end

        # Aviso para peças grandes (> 2000mm)
        if peca.comprimento > 2000 || peca.largura > 1000
          obs << "Peça grande — necessita apoio para corte"
        end

        # Aviso para peças com veio (MDF texturizado)
        if peca.material.to_s.downcase.include?('carvalho') ||
           peca.material.to_s.downcase.include?('nogueira') ||
           peca.material.to_s.downcase.include?('freijó')
          obs << "Material com veio — atenção ao sentido de corte"
        end

        # Aviso para portas (necessita caneco)
        if peca.tipo == :porta
          obs << "Porta — furar canecos antes da fitagem"
        end

        # Aviso para frentes de gaveta
        if peca.tipo == :frente_gaveta
          obs << "Frente de gaveta — furar puxador após montagem"
        end

        # Aviso de montagem para módulo europeu
        if modulo_info.montagem == Config::MONTAGEM_EUROPA && [:base, :topo].include?(peca.tipo)
          obs << "Montagem europeia — base/topo entre as laterais"
        end

        obs.join('; ')
      end

      # ── Gera código de barras único ──
      def self.gerar_codigo_barras(modulo_info, peca)
        # Formato: ORN-[ambiente_abrev]-[modulo_id_curto]-[tipo]-[seq]
        amb = (modulo_info.ambiente || 'GER')[0..2].upcase
        mod_id = (modulo_info.id || '000')[-4..]
        tipo_abrev = peca.tipo.to_s[0..2].upcase
        hash_peca = (peca.nome.hash.abs % 10000).to_s.rjust(4, '0')
        "ORN-#{amb}-#{mod_id}-#{tipo_abrev}-#{hash_peca}"
      end

      # ── Resumo compacto de uma peça para o roteiro ──
      def self.resumo_peca_roteiro(et)
        {
          nome: et.peca_nome,
          modulo: et.modulo_nome,
          dimensoes: "#{et.comprimento}×#{et.largura}×#{et.espessura}",
          material: et.material,
          fita: et.fita_codigo,
          quantidade: et.quantidade,
          codigo: et.codigo_barras
        }
      end

      # ── Instrução de montagem por tipo de peça ──
      def self.instrucao_montagem(etiqueta)
        case etiqueta.peca_tipo
        when :rodape
          'Posicionar rodapé na base. Fixar com parafusos/cavilhas.'
        when :base
          'Posicionar base horizontal. Aplicar cola + fixação (Minifix ou cavilha).'
        when :lateral
          'Encaixar lateral vertical. Conectar à base com Minifix/confirmat.'
        when :divisoria
          'Instalar divisória interna. Alinhar com furação existente.'
        when :prateleira
          'Inserir pinos de prateleira. Encaixar prateleira nos pinos.'
        when :topo
          'Posicionar topo sobre as laterais. Fixar com Minifix/confirmat.'
        when :fundo
          'Encaixar fundo no canal/rebaixo. Verificar esquadro do módulo.'
        when :traseira_gaveta
          'Montar caixa da gaveta: traseira entre laterais.'
        when :lateral_gaveta
          'Montar caixa da gaveta: fixar laterais na frente interna.'
        when :fundo_gaveta
          'Encaixar fundo da gaveta no canal. Verificar esquadro.'
        when :frente_gaveta
          'Fixar frente aplicada da gaveta após instalar corrediça.'
        when :porta
          'Instalar dobradiças (canecos). Fixar porta ao módulo. Regular.'
        when :tampo
          'Posicionar tampo sobre módulos. Fixar por baixo com cantoneiras.'
        else
          'Posicionar e fixar conforme projeto.'
        end
      end

      # ═══════════════════════════════════════════════
      # CSS PARA ETIQUETAS
      # ═══════════════════════════════════════════════
      def self.css_etiquetas(formato)
        css_base = <<~CSS
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: 'Segoe UI', Arial, Helvetica, sans-serif;
            font-size: 9pt;
            color: #333;
            background: #fff;
          }
          .container.individual .etiqueta-card {
            width: 100mm;
            height: 70mm;
            page-break-after: always;
            padding: 3mm;
            border: 0.5pt solid #999;
            margin: 0 auto 2mm auto;
            position: relative;
            overflow: hidden;
          }
          .container.grade-a4 {
            display: flex;
            flex-wrap: wrap;
            width: 210mm;
            margin: 0 auto;
            padding: 5mm;
          }
          .container.grade-a4 .etiqueta-card {
            width: 95mm;
            height: 65mm;
            border: 0.5pt solid #999;
            padding: 2.5mm;
            margin: 2mm;
            position: relative;
            overflow: hidden;
          }
          .etiqueta-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            border-bottom: 1.5pt solid #e67e22;
            padding-bottom: 1.5mm;
            margin-bottom: 1.5mm;
          }
          .etiqueta-header .modulo-nome {
            font-size: 8pt;
            font-weight: bold;
            color: #e67e22;
            max-width: 60%;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
          }
          .etiqueta-header .ambiente {
            font-size: 7pt;
            color: #777;
            text-align: right;
          }
          .etiqueta-header .sequencia {
            font-size: 10pt;
            font-weight: bold;
            color: #e67e22;
            background: #fef3e6;
            border-radius: 2mm;
            padding: 0.5mm 1.5mm;
            min-width: 7mm;
            text-align: center;
          }
          .peca-nome {
            font-size: 10pt;
            font-weight: bold;
            color: #222;
            margin-bottom: 1mm;
          }
          .dimensoes {
            font-size: 12pt;
            font-weight: bold;
            color: #000;
            letter-spacing: 0.5pt;
            margin-bottom: 1mm;
          }
          .dimensoes .unidade { font-size: 8pt; font-weight: normal; color: #666; }
          .info-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 0.5mm 2mm;
            font-size: 7.5pt;
            margin-bottom: 1mm;
          }
          .info-grid .label {
            color: #888;
            font-size: 6.5pt;
            text-transform: uppercase;
          }
          .info-grid .valor { color: #333; }
          .fita-visual {
            font-size: 11pt;
            letter-spacing: 1pt;
            font-weight: bold;
            margin-bottom: 0.5mm;
          }
          .fita-desc {
            font-size: 6.5pt;
            color: #666;
            margin-bottom: 1mm;
            line-height: 1.3;
          }
          .operacoes {
            font-size: 7pt;
            color: #555;
            border-top: 0.5pt dashed #ccc;
            padding-top: 1mm;
            margin-top: 1mm;
          }
          .operacoes .op-titulo {
            font-weight: bold;
            color: #444;
            font-size: 6.5pt;
            text-transform: uppercase;
          }
          .qr-placeholder {
            position: absolute;
            bottom: 2mm;
            right: 2mm;
            width: 14mm;
            height: 14mm;
            border: 0.5pt solid #ccc;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 5pt;
            color: #aaa;
          }
          .codigo-barras {
            font-family: 'Courier New', monospace;
            font-size: 6.5pt;
            color: #555;
            position: absolute;
            bottom: 2mm;
            left: 3mm;
          }
          .obs {
            font-size: 6.5pt;
            color: #c0392b;
            font-style: italic;
            margin-top: 0.5mm;
          }
          .quantidade-badge {
            position: absolute;
            top: 2mm;
            right: 2mm;
            background: #e67e22;
            color: #fff;
            font-size: 9pt;
            font-weight: bold;
            border-radius: 50%;
            width: 7mm;
            height: 7mm;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          @media print {
            body { margin: 0; }
            .container.individual .etiqueta-card {
              page-break-after: always;
              border: 0.3pt solid #bbb;
              margin: 0;
            }
            .container.grade-a4 {
              padding: 3mm;
            }
            .container.grade-a4 .etiqueta-card {
              border: 0.3pt solid #bbb;
            }
          }
        CSS

        css_base
      end

      # ── HTML de um card de etiqueta individual ──
      def self.html_etiqueta_card(et, incluir_qrcode: true, incluir_furacao: true)
        qtd_badge = et.quantidade > 1 ? "<div class=\"quantidade-badge\">#{et.quantidade}×</div>" : ""

        operacoes_html = ''
        if incluir_furacao
          if et.furacao_resumo && et.furacao_resumo != 'Sem furação'
            operacoes_html += "<div><span class=\"op-titulo\">Furação:</span> #{esc(et.furacao_resumo)}</div>"
          end
          if et.usinagem_resumo && et.usinagem_resumo != 'Sem usinagem'
            operacoes_html += "<div><span class=\"op-titulo\">Usinagem:</span> #{esc(et.usinagem_resumo)}</div>"
          end
        end
        operacoes_div = operacoes_html.empty? ? '' : "<div class=\"operacoes\">#{operacoes_html}</div>"

        qr_div = incluir_qrcode ? "<div class=\"qr-placeholder\">QR<br>#{esc(et.codigo_barras.to_s[-8..])}</div>" : ''

        obs_div = (et.observacoes && !et.observacoes.empty?) ? "<div class=\"obs\">#{esc(et.observacoes)}</div>" : ''

        esp_info = et.espessura_real != et.espessura ? " (real: #{et.espessura_real})" : ""

        <<~HTML
          <div class="etiqueta-card">
            #{qtd_badge}
            <div class="etiqueta-header">
              <div>
                <div class="modulo-nome">#{esc(et.modulo_nome)}</div>
                <div class="ambiente">#{esc(et.ambiente)}</div>
              </div>
              <div class="sequencia">##{et.sequencia}</div>
            </div>
            <div class="peca-nome">#{esc(et.peca_nome)}</div>
            <div class="dimensoes">
              #{et.comprimento} × #{et.largura} × #{et.espessura}<span class="unidade">mm#{esp_info}</span>
            </div>
            <div class="info-grid">
              <div><span class="label">Material</span><br><span class="valor">#{esc(et.material)}</span></div>
              <div><span class="label">Posição</span><br><span class="valor">#{esc(et.posicao_modulo.to_s)}</span></div>
            </div>
            <div class="fita-visual">#{esc(et.fita_codigo)}</div>
            <div class="fita-desc">#{esc(et.fita_descricao)}</div>
            #{operacoes_div}
            #{obs_div}
            <div class="codigo-barras">#{esc(et.codigo_barras)}</div>
            #{qr_div}
          </div>
        HTML
      end

      # ── Escape HTML básico ──
      def self.esc(str)
        return '' if str.nil?
        str.to_s
          .gsub('&', '&amp;')
          .gsub('<', '&lt;')
          .gsub('>', '&gt;')
          .gsub('"', '&quot;')
      end
    end
  end
end
