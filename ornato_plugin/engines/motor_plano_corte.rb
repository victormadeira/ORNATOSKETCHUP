# ornato_plugin/engines/motor_plano_corte.rb — Plano de corte para esquadrejadeira e otimização

module Ornato
  module Engines
    class MotorPlanoCorte

      # Tamanhos padrão de chapas comerciais (mm)
      CHAPAS_PADRAO = {
        '2750×1850' => { largura: 2750, altura: 1850 },
        '2750×1840' => { largura: 2750, altura: 1840 },
        '2440×1830' => { largura: 2440, altura: 1830 },
        '2440×1220' => { largura: 2440, altura: 1220 },
        '2750×1830' => { largura: 2750, altura: 1830 },
        '1850×2750' => { largura: 1850, altura: 2750 },  # chapa girada
      }.freeze

      CHAPA_PADRAO = '2750×1850'

      # Margem de corte da serra (espessura da lâmina)
      MARGEM_SERRA = 4  # mm — serra de esquadrejadeira padrão

      # Margem de refilamento (esquadrejamento da chapa)
      MARGEM_REFILO = 10  # mm por lado (total 20mm perdido na largura e 20mm na altura)

      # Coleta todas as peças de todos os módulos do projeto
      def self.coletar_pecas_projeto
        modulos = Utils.listar_modulos
        todas_pecas = []

        modulos.each do |grupo|
          mi = Models::ModuloInfo.carregar_do_grupo(grupo)
          next unless mi

          mi.pecas.each do |peca|
            peca.quantidade.times do
              todas_pecas << {
                nome: peca.nome,
                comprimento: peca.comprimento,
                largura: peca.largura,
                espessura: peca.espessura,
                material: peca.material,
                fita: peca.fita_codigo,
                fita_metros: peca.fita_metros / peca.quantidade.to_f,
                modulo: mi.nome,
                ambiente: mi.ambiente,
                rotacionavel: true  # pode girar 90° no plano de corte
              }
            end
          end
        end

        todas_pecas
      end

      # Agrupa peças por material/espessura (cada chapa = 1 material)
      def self.agrupar_por_material(pecas)
        grupos = {}
        pecas.each do |peca|
          key = "#{peca[:material]}"
          grupos[key] ||= { material: peca[:material], espessura: peca[:espessura], pecas: [] }
          grupos[key][:pecas] << peca
        end
        grupos
      end

      # Algoritmo de otimização de corte (First Fit Decreasing Height)
      # Retorna array de chapas com peças posicionadas
      def self.otimizar_corte(pecas, tamanho_chapa = CHAPA_PADRAO, margem_serra: MARGEM_SERRA)
        chapa = CHAPAS_PADRAO[tamanho_chapa]
        return nil unless chapa

        chapa_l = chapa[:largura] - (2 * MARGEM_REFILO)
        chapa_a = chapa[:altura] - (2 * MARGEM_REFILO)

        # Ordena peças por área decrescente (maior primeiro)
        ordenadas = pecas.sort_by { |p| -(p[:comprimento] * p[:largura]) }

        chapas_usadas = []
        current_chapa = nova_chapa(chapa_l, chapa_a)

        ordenadas.each do |peca|
          colocada = false

          # Tenta colocar na chapa atual
          chapas_usadas.each do |ch|
            if posicionar_peca(ch, peca, margem_serra)
              colocada = true
              break
            end
          end

          # Se não coube, nova chapa
          unless colocada
            current_chapa = nova_chapa(chapa_l, chapa_a)
            chapas_usadas << current_chapa
            posicionar_peca(current_chapa, peca, margem_serra)
          end
        end

        # Calcula aproveitamento
        chapas_usadas.each do |ch|
          area_total = ch[:largura] * ch[:altura]
          area_usada = ch[:pecas].sum { |p| p[:comprimento] * p[:largura] }
          ch[:aproveitamento] = ((area_usada.to_f / area_total) * 100).round(1)
          ch[:area_util] = area_usada
          ch[:area_total] = area_total
          ch[:sobra] = area_total - area_usada
        end

        chapas_usadas
      end

      # Posiciona uma peça numa chapa (algoritmo shelf/guillotine simplificado)
      def self.posicionar_peca(chapa, peca, margem)
        c = peca[:comprimento]
        l = peca[:largura]

        # Tenta posição normal
        pos = encontrar_espaco(chapa, c, l, margem)
        if pos
          chapa[:pecas] << peca.merge(pos_x: pos[:x], pos_y: pos[:y], rotacionada: false)
          atualizar_ocupacao(chapa, pos[:x], pos[:y], c, l, margem)
          return true
        end

        # Tenta rotacionada (90°)
        if peca[:rotacionavel]
          pos = encontrar_espaco(chapa, l, c, margem)
          if pos
            chapa[:pecas] << peca.merge(pos_x: pos[:x], pos_y: pos[:y], rotacionada: true,
              comprimento: l, largura: c)  # inverte dimensões
            atualizar_ocupacao(chapa, pos[:x], pos[:y], l, c, margem)
            return true
          end
        end

        false
      end

      # Encontra espaço livre na chapa (shelf algorithm)
      def self.encontrar_espaco(chapa, comp, larg, margem)
        # Shelf: tenta encaixar na prateleira atual
        chapa[:shelves].each do |shelf|
          if shelf[:x] + comp + margem <= chapa[:largura] &&
             shelf[:y] + larg <= shelf[:y] + shelf[:altura_max]
            return { x: shelf[:x], y: shelf[:y] }
          end
        end

        # Nova prateleira
        if chapa[:next_y] + larg <= chapa[:altura]
          pos = { x: 0, y: chapa[:next_y] }
          chapa[:shelves] << { x: 0, y: chapa[:next_y], altura_max: larg }
          return pos
        end

        nil
      end

      def self.atualizar_ocupacao(chapa, x, y, comp, larg, margem)
        shelf = chapa[:shelves].find { |s| s[:y] == y }
        if shelf
          shelf[:x] = x + comp + margem
          shelf[:altura_max] = [shelf[:altura_max], larg].max
        end
        novo_y = y + larg + margem
        chapa[:next_y] = novo_y if novo_y > chapa[:next_y]
      end

      def self.nova_chapa(largura, altura)
        {
          largura: largura,
          altura: altura,
          pecas: [],
          shelves: [],
          next_y: 0,
          aproveitamento: 0
        }
      end

      # ═══════════════════════════════════════════════
      # EXPORTADORES
      # ═══════════════════════════════════════════════

      # Exporta lista de corte em CSV (para esquadrejadeira manual)
      def self.exportar_csv(path, pecas = nil)
        pecas ||= coletar_pecas_projeto
        por_material = agrupar_por_material(pecas)

        File.open(path, 'w:UTF-8') do |f|
          f.puts "LISTA DE CORTE — ORNATO PLUGIN"
          f.puts "Data: #{Time.now.strftime('%d/%m/%Y %H:%M')}"
          f.puts ""

          por_material.each do |key, grupo|
            f.puts "=" * 80
            f.puts "MATERIAL: #{grupo[:material]} (#{grupo[:espessura]}mm)"
            f.puts "Quantidade de peças: #{grupo[:pecas].length}"
            f.puts "-" * 80
            f.puts "#;Peça;Comp(mm);Larg(mm);Esp;Módulo;Ambiente;Fita;Fita(m)"

            grupo[:pecas].each_with_index do |p, i|
              f.puts "#{i+1};#{p[:nome]};#{p[:comprimento]};#{p[:largura]};#{p[:espessura]};#{p[:modulo]};#{p[:ambiente]};#{p[:fita]};#{p[:fita_metros].round(3)}"
            end

            f.puts ""
          end

          # Resumo
          f.puts "=" * 80
          f.puts "RESUMO"
          f.puts "Total de peças: #{pecas.length}"
          f.puts "Materiais: #{por_material.keys.join(', ')}"
        end
      end

      # Exporta XML para OpenCutList (plugin SketchUp de otimização)
      def self.exportar_xml(path, pecas = nil)
        pecas ||= coletar_pecas_projeto

        File.open(path, 'w:UTF-8') do |f|
          f.puts '<?xml version="1.0" encoding="UTF-8"?>'
          f.puts '<cutlist>'
          f.puts '  <project>'
          f.puts "    <name>Ornato Export #{Time.now.strftime('%d/%m/%Y')}</name>"
          f.puts '  </project>'
          f.puts '  <parts>'

          pecas.each_with_index do |p, i|
            f.puts '    <part>'
            f.puts "      <id>#{i + 1}</id>"
            f.puts "      <name>#{p[:nome]}</name>"
            f.puts "      <length>#{p[:comprimento]}</length>"
            f.puts "      <width>#{p[:largura]}</width>"
            f.puts "      <thickness>#{p[:espessura]}</thickness>"
            f.puts "      <material>#{p[:material]}</material>"
            f.puts "      <quantity>1</quantity>"
            f.puts "      <grain>1</grain>"  # 1 = com sentido de veio
            f.puts "      <edge_front>#{p[:fita][0] == '■' ? 1 : 0}</edge_front>"
            f.puts "      <edge_back>#{p[:fita][2] == '■' ? 1 : 0}</edge_back>"
            f.puts "      <edge_left>#{p[:fita][3] == '■' ? 1 : 0}</edge_left>"
            f.puts "      <edge_right>#{p[:fita][1] == '■' ? 1 : 0}</edge_right>"
            f.puts '    </part>'
          end

          f.puts '  </parts>'
          f.puts '</cutlist>'
        end
      end

      # Exporta plano de corte visual para esquadrejadeira (CSV com posições)
      def self.exportar_plano_esquadrejadeira(path, tamanho_chapa = CHAPA_PADRAO)
        pecas = coletar_pecas_projeto
        por_material = agrupar_por_material(pecas)

        File.open(path, 'w:UTF-8') do |f|
          f.puts "PLANO DE CORTE PARA ESQUADREJADEIRA — ORNATO PLUGIN"
          f.puts "Data: #{Time.now.strftime('%d/%m/%Y %H:%M')}"
          f.puts "Chapa: #{tamanho_chapa}"
          f.puts "Margem serra: #{MARGEM_SERRA}mm"
          f.puts "Margem refilo: #{MARGEM_REFILO}mm/lado"
          f.puts ""

          por_material.each do |key, grupo|
            chapas = otimizar_corte(grupo[:pecas], tamanho_chapa)
            next unless chapas

            f.puts "=" * 80
            f.puts "MATERIAL: #{grupo[:material]}"
            f.puts "Chapas necessárias: #{chapas.length}"
            f.puts ""

            chapas.each_with_index do |chapa, ci|
              f.puts "--- CHAPA #{ci + 1} (#{chapa[:aproveitamento]}% aproveitamento) ---"
              f.puts "Peça;Comp;Larg;Pos X;Pos Y;Rotacionada"

              chapa[:pecas].each do |p|
                rot = p[:rotacionada] ? 'SIM' : 'NÃO'
                f.puts "#{p[:nome]};#{p[:comprimento]};#{p[:largura]};#{p[:pos_x]};#{p[:pos_y]};#{rot}"
              end

              # Instruções de corte para esquadrejadeira
              f.puts ""
              f.puts "SEQUÊNCIA DE CORTES:"
              gerar_sequencia_cortes(chapa).each_with_index do |corte, i|
                f.puts "  #{i + 1}. #{corte}"
              end
              f.puts ""
            end
          end
        end
      end

      # Gera sequência de cortes otimizada para esquadrejadeira
      # (cortes longitudinais primeiro, depois transversais)
      def self.gerar_sequencia_cortes(chapa)
        cortes = []

        # Agrupa peças por faixas horizontais (mesmo Y)
        faixas = chapa[:pecas].group_by { |p| p[:pos_y] }

        faixas_ordenadas = faixas.sort_by { |y, _| y }

        faixas_ordenadas.each_with_index do |(y, pecas_faixa), fi|
          altura_faixa = pecas_faixa.map { |p| p[:largura] }.max

          # Corte longitudinal (separa a faixa da chapa)
          if fi < faixas_ordenadas.length - 1
            pos_corte = y + altura_faixa + (MARGEM_SERRA / 2.0)
            cortes << "LONGITUDINAL: Cortar a #{pos_corte.round(0)}mm da borda inferior (faixa #{fi + 1}, #{altura_faixa}mm de altura)"
          end

          # Cortes transversais dentro da faixa
          pecas_ordenadas = pecas_faixa.sort_by { |p| p[:pos_x] }
          pecas_ordenadas.each_with_index do |peca, pi|
            if pi < pecas_ordenadas.length - 1
              pos_corte = peca[:pos_x] + peca[:comprimento] + (MARGEM_SERRA / 2.0)
              cortes << "  TRANSVERSAL: #{peca[:nome]} — cortar a #{pos_corte.round(0)}mm (#{peca[:comprimento]}×#{peca[:largura]}mm)"
            else
              cortes << "  TRANSVERSAL: #{peca[:nome]} — última peça da faixa (#{peca[:comprimento]}×#{peca[:largura]}mm)"
            end
          end
        end

        cortes
      end

      # Exporta para Corte Certo (formato proprietário CSV)
      def self.exportar_corte_certo(path)
        pecas = coletar_pecas_projeto
        por_material = agrupar_por_material(pecas)

        File.open(path, 'w:UTF-8') do |f|
          # Formato Corte Certo: Material;Comprimento;Largura;Quantidade;Nome
          por_material.each do |key, grupo|
            grupo[:pecas].each do |p|
              f.puts "#{p[:material]};#{p[:comprimento]};#{p[:largura]};1;#{p[:nome]} (#{p[:modulo]})"
            end
          end
        end
      end

      # Exporta resumo para impressão (texto formatado)
      def self.gerar_resumo_texto
        pecas = coletar_pecas_projeto
        por_material = agrupar_por_material(pecas)

        linhas = []
        linhas << "╔═══════════════════════════════════════════════════════════╗"
        linhas << "║  LISTA DE CORTE — ORNATO MARCENARIA                     ║"
        linhas << "║  #{Time.now.strftime('%d/%m/%Y %H:%M')}                                         ║"
        linhas << "╠═══════════════════════════════════════════════════════════╣"

        num_global = 0
        por_material.each do |key, grupo|
          linhas << "║                                                           ║"
          linhas << "║  MATERIAL: #{grupo[:material].ljust(45)}║"
          linhas << "╠════╦════════════════════╦═══════╦═══════╦════╦══════════╣"
          linhas << "║  # ║ Peça               ║ Comp  ║ Larg  ║ Qt ║ Fita     ║"
          linhas << "╠════╬════════════════════╬═══════╬═══════╬════╬══════════╣"

          grupo[:pecas].each do |p|
            num_global += 1
            nome = p[:nome][0..17].ljust(18)
            linhas << "║ #{num_global.to_s.rjust(2)} ║ #{nome} ║ #{p[:comprimento].to_s.rjust(5)} ║ #{p[:largura].to_s.rjust(5)} ║  1 ║ #{p[:fita].ljust(8)} ║"
          end

          linhas << "╠════╩════════════════════╩═══════╩═══════╩════╩══════════╣"
        end

        linhas << "║                                                           ║"
        linhas << "║  Total de peças: #{pecas.length.to_s.ljust(40)}║"
        linhas << "╚═══════════════════════════════════════════════════════════╝"

        linhas.join("\n")
      end
    end
  end
end
