# ornato_plugin/engines/motor_ficha_tecnica.rb — Motor de ficha técnica
# Gera fichas técnicas completas para módulos de marcenaria
# Inclui: lista de peças, ferragens, fita de borda, furação, usinagem,
# notas de montagem, peso estimado e geração de HTML para impressão.

module Ornato
  module Engines
    class MotorFichaTecnica

      # ═══════════════════════════════════════════════
      # CLASSE DE DADOS — FICHA TÉCNICA
      # ═══════════════════════════════════════════════
      class FichaTecnica
        attr_accessor :modulo_nome, :modulo_id, :ambiente, :tipo, :data_geracao,
                      :largura, :altura, :profundidade,
                      :largura_interna, :altura_interna, :profundidade_interna,
                      :montagem, :tipo_fundo, :tipo_base, :fixacao,
                      :material_corpo, :material_frente, :material_fundo,
                      :espessura_corpo_nominal, :espessura_corpo_real,
                      :espessura_fundo_nominal, :espessura_fundo_real,
                      :lista_pecas, :lista_ferragens,
                      :resumo_fita, :resumo_furacao, :resumo_usinagem,
                      :notas_montagem, :peso_estimado, :area_total_m2,
                      :altura_rodape, :recuo_rodape,
                      :fita_corpo, :fita_frente,
                      :total_pecas, :total_fita_metros

        def initialize
          @data_geracao       = Time.now.strftime('%d/%m/%Y %H:%M')
          @lista_pecas        = []
          @lista_ferragens    = []
          @resumo_fita        = []
          @resumo_furacao      = []
          @resumo_usinagem    = []
          @notas_montagem     = []
          @peso_estimado      = 0.0
          @area_total_m2      = 0.0
          @total_pecas        = 0
          @total_fita_metros  = 0.0
        end

        def to_hash
          {
            modulo_nome: @modulo_nome, modulo_id: @modulo_id,
            ambiente: @ambiente, tipo: @tipo, data_geracao: @data_geracao,
            largura: @largura, altura: @altura, profundidade: @profundidade,
            largura_interna: @largura_interna, altura_interna: @altura_interna,
            profundidade_interna: @profundidade_interna,
            montagem: @montagem, tipo_fundo: @tipo_fundo, tipo_base: @tipo_base,
            fixacao: @fixacao,
            material_corpo: @material_corpo, material_frente: @material_frente,
            material_fundo: @material_fundo,
            espessura_corpo_nominal: @espessura_corpo_nominal,
            espessura_corpo_real: @espessura_corpo_real,
            espessura_fundo_nominal: @espessura_fundo_nominal,
            espessura_fundo_real: @espessura_fundo_real,
            lista_pecas: @lista_pecas.map { |p| p.is_a?(Hash) ? p : p.to_hash },
            lista_ferragens: @lista_ferragens,
            resumo_fita: @resumo_fita, resumo_furacao: @resumo_furacao,
            resumo_usinagem: @resumo_usinagem,
            notas_montagem: @notas_montagem,
            peso_estimado: @peso_estimado, area_total_m2: @area_total_m2,
            total_pecas: @total_pecas, total_fita_metros: @total_fita_metros
          }
        end
      end

      # ═══════════════════════════════════════════════
      # CONSTANTES
      # ═══════════════════════════════════════════════

      # Densidade média do MDF (kg/m³) para estimativa de peso
      DENSIDADE_MDF = 750.0

      # Nomes legíveis para tipos de montagem
      NOMES_MONTAGEM = {
        laterais_entre: 'Laterais entre base e topo (Brasil)',
        base_topo_entre: 'Base e topo entre laterais (Europa)'
      }.freeze

      # Nomes legíveis para tipos de fundo
      NOMES_FUNDO = {
        rebaixado:  'Rebaixado (canal fresado)',
        sobreposto: 'Sobreposto (grampeado)',
        sem_fundo:  'Sem fundo'
      }.freeze

      # Nomes legíveis para tipos de base
      NOMES_BASE = {
        rodape:         'Rodapé',
        pes_regulaveis: 'Pés reguláveis',
        direta:         'Direta (sem base)',
        suspensa:       'Suspensa (fixação parede)'
      }.freeze

      # Nomes legíveis para tipos de fixação
      NOMES_FIXACAO = {
        minifix:   'Minifix',
        vb:        'VB (parafuso de conexão)',
        cavilha:   'Cavilha',
        confirmat: 'Confirmat'
      }.freeze

      # Nomes legíveis para tipos de módulo
      NOMES_TIPO_MODULO = {
        inferior:   'Inferior',
        superior:   'Superior',
        torre:      'Torre / Coluna',
        bancada:    'Bancada',
        estante:    'Estante',
        gaveteiro:  'Gaveteiro',
        painel:     'Painel'
      }.freeze

      # Nomes legíveis para tipos de peça
      NOMES_TIPO_PECA = {
        lateral:         'Lateral',
        base:            'Base',
        topo:            'Topo',
        fundo:           'Fundo',
        prateleira:      'Prateleira',
        prateleira_adj:  'Prateleira ajustável',
        divisoria:       'Divisória',
        porta:           'Porta',
        frente_gaveta:   'Frente gaveta',
        lateral_gaveta:  'Lateral gaveta',
        traseira_gaveta: 'Traseira gaveta',
        fundo_gaveta:    'Fundo gaveta',
        tampo:           'Tampo',
        rodape:          'Rodapé',
        painel:          'Painel',
        generica:        'Peça genérica'
      }.freeze

      # ═══════════════════════════════════════════════
      # GERAR FICHA — módulo individual
      # ═══════════════════════════════════════════════

      # Gera ficha técnica completa a partir de um ModuloInfo
      # @param modulo_info [Models::ModuloInfo] dados do módulo
      # @return [FichaTecnica] ficha preenchida
      def self.gerar_ficha(modulo_info)
        mi = modulo_info
        ficha = FichaTecnica.new

        # ─── Cabeçalho ───
        ficha.modulo_nome = mi.nome
        ficha.modulo_id   = mi.id
        ficha.ambiente    = mi.ambiente
        ficha.tipo        = mi.tipo

        # ─── Dimensões ───
        ficha.largura            = mi.largura
        ficha.altura             = mi.altura
        ficha.profundidade       = mi.profundidade
        ficha.largura_interna    = mi.largura_interna
        ficha.altura_interna     = mi.altura_interna
        ficha.profundidade_interna = mi.profundidade_interna

        # ─── Estrutura ───
        ficha.montagem    = mi.montagem
        ficha.tipo_fundo  = mi.tipo_fundo
        ficha.tipo_base   = mi.tipo_base
        ficha.fixacao     = mi.fixacao
        ficha.altura_rodape = mi.altura_rodape
        ficha.recuo_rodape  = mi.recuo_rodape

        # ─── Materiais ───
        ficha.material_corpo  = mi.material_corpo
        ficha.material_frente = mi.material_frente
        ficha.material_fundo  = mi.material_fundo
        ficha.fita_corpo      = mi.fita_corpo
        ficha.fita_frente     = mi.fita_frente

        # ─── Espessuras ───
        ficha.espessura_corpo_nominal = mi.espessura_corpo
        ficha.espessura_corpo_real    = mi.espessura_corpo_real
        ficha.espessura_fundo_nominal = mi.espessura_fundo
        ficha.espessura_fundo_real    = mi.espessura_fundo_real

        # ─── Lista de peças ───
        ficha.lista_pecas = extrair_lista_pecas(mi)
        ficha.total_pecas = ficha.lista_pecas.inject(0) { |soma, p| soma + (p[:quantidade] || 1) }

        # ─── Lista de ferragens ───
        ficha.lista_ferragens = extrair_lista_ferragens(mi)

        # ─── Resumo fita de borda ───
        ficha.resumo_fita = calcular_resumo_fita(ficha.lista_pecas)
        ficha.total_fita_metros = ficha.resumo_fita.inject(0.0) { |soma, r| soma + r[:metros] }

        # ─── Resumo furação ───
        ficha.resumo_furacao = calcular_resumo_furacao(mi)

        # ─── Resumo usinagem ───
        ficha.resumo_usinagem = calcular_resumo_usinagem(mi)

        # ─── Notas de montagem ───
        ficha.notas_montagem = gerar_notas_montagem(mi)

        # ─── Peso estimado ───
        ficha.peso_estimado = calcular_peso(mi)

        # ─── Área total ───
        ficha.area_total_m2 = ficha.lista_pecas.inject(0.0) do |soma, p|
          soma + (p[:area_m2] || 0.0)
        end.round(3)

        ficha
      end

      # ═══════════════════════════════════════════════
      # GERAR FICHA PROJETO — todos os módulos
      # ═══════════════════════════════════════════════

      # Gera fichas para todos os módulos e retorna com resumo do projeto
      # @param modulos [Array<Models::ModuloInfo>] lista de módulos
      # @return [Hash] { fichas: [...], resumo: {...} }
      def self.gerar_ficha_projeto(modulos)
        fichas = modulos.map { |mi| gerar_ficha(mi) }
        {
          fichas: fichas,
          resumo: resumo_projeto(fichas),
          data_geracao: Time.now.strftime('%d/%m/%Y %H:%M'),
          total_modulos: modulos.size
        }
      end

      # ═══════════════════════════════════════════════
      # RESUMO DO PROJETO — consolidação
      # ═══════════════════════════════════════════════

      # Gera resumo consolidado de todas as fichas do projeto
      # @param fichas [Array<FichaTecnica>] fichas individuais
      # @return [Hash] dados consolidados
      def self.resumo_projeto(fichas)
        return {} if fichas.nil? || fichas.empty?

        # Total de módulos por ambiente
        modulos_por_ambiente = fichas.group_by(&:ambiente).transform_values(&:size)

        # Total de módulos por tipo
        modulos_por_tipo = fichas.group_by(&:tipo).transform_values(&:size)

        # Total de peças
        total_pecas = fichas.inject(0) { |soma, f| soma + f.total_pecas }

        # Área total por material (m²)
        area_por_material = {}
        fichas.each do |f|
          f.lista_pecas.each do |p|
            mat = p[:material] || 'Indefinido'
            area_por_material[mat] ||= 0.0
            area_por_material[mat] += (p[:area_m2] || 0.0)
          end
        end
        area_por_material.each { |k, v| area_por_material[k] = v.round(3) }

        # Fita de borda total por tipo (metros)
        fita_por_tipo = {}
        fichas.each do |f|
          f.resumo_fita.each do |rf|
            tipo = rf[:fita] || 'Indefinida'
            fita_por_tipo[tipo] ||= 0.0
            fita_por_tipo[tipo] += (rf[:metros] || 0.0)
          end
        end
        fita_por_tipo.each { |k, v| fita_por_tipo[k] = v.round(2) }

        # Ferragens total por tipo
        ferragens_total = {}
        fichas.each do |f|
          f.lista_ferragens.each do |fg|
            chave = fg[:nome] || fg[:tipo] || 'Indefinida'
            ferragens_total[chave] ||= 0
            ferragens_total[chave] += (fg[:quantidade] || fg[:qtd] || 0)
          end
        end

        # Peso total estimado
        peso_total = fichas.inject(0.0) { |soma, f| soma + f.peso_estimado }.round(2)

        # Área total do projeto
        area_total = fichas.inject(0.0) { |soma, f| soma + f.area_total_m2 }.round(3)

        # Lista de compras (agrupada por material)
        lista_compras = gerar_lista_compras(fichas, area_por_material, fita_por_tipo, ferragens_total)

        {
          modulos_por_ambiente: modulos_por_ambiente,
          modulos_por_tipo: modulos_por_tipo,
          total_pecas: total_pecas,
          area_por_material: area_por_material,
          fita_por_tipo: fita_por_tipo,
          ferragens_total: ferragens_total,
          peso_total_kg: peso_total,
          area_total_m2: area_total,
          lista_compras: lista_compras
        }
      end

      # ═══════════════════════════════════════════════
      # CALCULAR PESO — estimativa baseada em densidade
      # ═══════════════════════════════════════════════

      # Calcula peso estimado do módulo em kg
      # Usa densidade de MDF = 750 kg/m³
      # @param modulo_info [Models::ModuloInfo] dados do módulo
      # @return [Float] peso em kg
      def self.calcular_peso(modulo_info)
        mi = modulo_info
        peso_total = 0.0

        mi.pecas.each do |peca|
          # Volume em m³: comp(mm) × larg(mm) × esp_real(mm) / 10^9
          esp_real = peca.espessura_real
          volume_m3 = (peca.comprimento * peca.largura * esp_real * peca.quantidade) / 1_000_000_000.0
          peso_total += volume_m3 * DENSIDADE_MDF
        end

        peso_total.round(2)
      end

      # ═══════════════════════════════════════════════
      # GERAR HTML — ficha para impressão
      # ═══════════════════════════════════════════════

      # Gera HTML formatado para impressão da ficha técnica
      # @param ficha [FichaTecnica] ficha técnica do módulo
      # @param opts [Hash] opções de geração
      #   :formato => :completa (A4 inteiro) ou :resumida (meia página)
      #   :incluir_imagem => true/false (placeholder para captura 3D)
      # @return [String] HTML completo
      def self.gerar_html_ficha(ficha, opts = {})
        formato = opts[:formato] || :completa
        incluir_imagem = opts.fetch(:incluir_imagem, false)

        html = []
        html << html_head(ficha, formato)
        html << '<body>'
        html << html_cabecalho(ficha)
        html << html_dimensoes(ficha)
        html << html_estrutura(ficha)
        html << html_materiais(ficha)

        if incluir_imagem
          html << html_imagem_placeholder(ficha)
        end

        html << html_tabela_pecas(ficha)
        html << html_tabela_ferragens(ficha)
        html << html_tabela_fita(ficha)

        if formato == :completa
          html << html_resumo_furacao(ficha)
          html << html_resumo_usinagem(ficha)
          html << html_notas_montagem(ficha)
        end

        html << html_totais(ficha)
        html << html_rodape(ficha)
        html << '</body></html>'

        html.join("\n")
      end

      # Gera HTML do resumo do projeto para impressão
      # @param resumo [Hash] dados do resumo do projeto
      # @return [String] HTML completo
      def self.gerar_html_resumo_projeto(resumo, fichas = [])
        html = []
        html << html_head_resumo
        html << '<body>'
        html << html_cabecalho_resumo(resumo)
        html << html_modulos_por_ambiente(resumo)
        html << html_modulos_por_tipo(resumo)
        html << html_area_materiais(resumo)
        html << html_fita_total(resumo)
        html << html_ferragens_total(resumo)
        html << html_lista_compras(resumo)
        html << html_totais_projeto(resumo)
        html << html_rodape_resumo
        html << '</body></html>'
        html.join("\n")
      end

      # ═══════════════════════════════════════════════
      # MÉTODOS PRIVADOS — extração de dados
      # ═══════════════════════════════════════════════
      private

      # Extrai lista de peças formatada a partir do ModuloInfo
      def self.extrair_lista_pecas(mi)
        mi.pecas.map do |peca|
          {
            nome:            peca.nome,
            tipo:            peca.tipo,
            comprimento:     peca.comprimento,
            largura:         peca.largura,
            espessura:       peca.espessura,
            espessura_real:  peca.espessura_real,
            material:        peca.material,
            quantidade:      peca.quantidade,
            fita_codigo:     peca.fita_codigo,
            fita_frente:     peca.fita_frente,
            fita_topo:       peca.fita_topo,
            fita_tras:       peca.fita_tras,
            fita_base:       peca.fita_base,
            fita_material:   peca.fita_material,
            fita_metros:     peca.fita_metros.round(3),
            area_m2:         peca.area_m2.round(4)
          }
        end
      end

      # Extrai lista de ferragens formatada
      def self.extrair_lista_ferragens(mi)
        # Usa as ferragens já registradas no módulo
        ferragens = mi.ferragens.map do |fg|
          {
            nome:       fg[:nome] || 'Ferragem',
            tipo:       fg[:tipo] || :geral,
            quantidade: fg[:qtd] || fg[:quantidade] || 1
          }
        end

        # Adiciona ferragens implícitas se não estiverem na lista
        ferragens = adicionar_ferragens_implicitas(mi, ferragens)
        ferragens
      end

      # Adiciona ferragens que podem ser inferidas da estrutura do módulo
      def self.adicionar_ferragens_implicitas(mi, ferragens_existentes)
        nomes_existentes = ferragens_existentes.map { |f| f[:nome] }
        extras = []

        # Minifix — 4 por junção de base/topo com lateral (mín. 8 para módulo padrão)
        if mi.fixacao == :minifix && !nomes_existentes.any? { |n| n.downcase.include?('minifix') }
          qtd_minifix = 8  # 2 por canto × 4 cantos
          extras << { nome: 'Minifix 15mm', tipo: :conexao, quantidade: qtd_minifix }
          extras << { nome: 'Bucha Minifix', tipo: :conexao, quantidade: qtd_minifix }
        end

        # Confirmat
        if mi.fixacao == :confirmat && !nomes_existentes.any? { |n| n.downcase.include?('confirmat') }
          qtd_confirmat = 12  # ~3 por junção × 4 junções
          extras << { nome: 'Confirmat 7×50mm', tipo: :conexao, quantidade: qtd_confirmat }
        end

        # Cavilha
        if mi.fixacao == :cavilha && !nomes_existentes.any? { |n| n.downcase.include?('cavilha') }
          qtd_cavilha = 16  # ~4 por junção × 4 junções
          extras << { nome: 'Cavilha 8×35mm', tipo: :conexao, quantidade: qtd_cavilha }
        end

        # Suportes de prateleira (pinos) — 4 por prateleira ajustável
        prateleiras_adj = mi.pecas.count { |p| p.tipo == :prateleira || p.tipo == :prateleira_adj }
        if prateleiras_adj > 0 && !nomes_existentes.any? { |n| n.downcase.include?('suporte') || n.downcase.include?('pino') }
          extras << { nome: 'Suporte prateleira (pino 5mm)', tipo: :suporte, quantidade: prateleiras_adj * 4 }
        end

        ferragens_existentes + extras
      end

      # Calcula resumo de fita de borda agrupado por tipo
      def self.calcular_resumo_fita(lista_pecas)
        agrupado = {}

        lista_pecas.each do |p|
          fita = p[:fita_material] || 'Sem fita'
          next if p[:fita_metros].nil? || p[:fita_metros] <= 0

          agrupado[fita] ||= { metros: 0.0, pecas: 0 }
          agrupado[fita][:metros] += p[:fita_metros]
          agrupado[fita][:pecas] += p[:quantidade] || 1
        end

        agrupado.map do |fita, dados|
          { fita: fita, metros: dados[:metros].round(2), pecas: dados[:pecas] }
        end
      end

      # Calcula resumo de furação agrupado por tipo
      def self.calcular_resumo_furacao(mi)
        contagem = Hash.new(0)

        # Tenta usar o MotorFuracao se as peças já foram geradas
        begin
          if mi.pecas.any?
            mapa = MotorFuracao.gerar_mapa(mi)
            mapa.each do |_peca_nome, furos|
              furos.each { |f| contagem[f.tipo] += 1 }
            end
          end
        rescue => _e
          # Se MotorFuracao não estiver disponível, estima pela estrutura
          contagem = estimar_furacao(mi)
        end

        contagem.map do |tipo, qtd|
          { tipo: tipo.to_s, quantidade: qtd, descricao: descricao_furo(tipo) }
        end
      end

      # Estimativa de furação quando o motor não está disponível
      def self.estimar_furacao(mi)
        contagem = Hash.new(0)

        # Furos de conexão (base/topo com laterais)
        case mi.fixacao
        when :minifix
          contagem[:minifix_face] += 8
          contagem[:minifix_borda] += 8
        when :confirmat
          contagem[:confirmat] += 12
        when :cavilha
          contagem[:cavilha] += 16
        end

        # Furos de caneco para portas
        portas = mi.pecas.select { |p| p.tipo == :porta }
        portas.each do |porta|
          qtd_dobr = Utils.qtd_dobradicas(porta.comprimento)
          contagem[:caneco_35mm] += qtd_dobr
          contagem[:placa_dobradica] += qtd_dobr
        end

        # Furos de pin para prateleiras
        prateleiras = mi.pecas.count { |p| p.tipo == :prateleira || p.tipo == :prateleira_adj }
        contagem[:pin_5mm] += prateleiras * 4 if prateleiras > 0

        # Linha de furação sistema 32mm nas laterais
        laterais = mi.pecas.select { |p| p.tipo == :lateral }
        laterais.each do |lat|
          qtd_furos_32 = ((lat.comprimento - 2 * Config::SISTEMA_32_INICIO) / Config::SISTEMA_32_PASSO).floor + 1
          contagem[:sistema_32] += [qtd_furos_32, 0].max
        end

        contagem
      end

      # Descrição legível para tipo de furo
      def self.descricao_furo(tipo)
        descricoes = {
          minifix_face:    'Minifix (face) - D15mm, prof 12.7mm',
          minifix_borda:   'Minifix (borda) - D8mm, prof 34mm',
          confirmat:       'Confirmat - D5mm borda / D8mm face',
          cavilha:         'Cavilha - D8mm, prof 16mm',
          caneco_35mm:     'Caneco dobradiça - D35mm, prof 12.5mm',
          placa_dobradica: 'Placa dobradiça (fixação lateral)',
          pin_5mm:         'Pino prateleira - D5mm, prof 10mm',
          sistema_32:      'Sistema 32mm (linha de furação)',
          puxador:         'Puxador - D5mm (passante)',
        }
        descricoes[tipo] || tipo.to_s.gsub('_', ' ').capitalize
      end

      # Calcula resumo de usinagem
      def self.calcular_resumo_usinagem(mi)
        operacoes = []

        # Canal do fundo (se rebaixado)
        if mi.tipo_fundo == :rebaixado
          esp_fundo = mi.espessura_fundo
          spec = esp_fundo <= 3 ? Config::CANAL_FUNDO_3MM : Config::CANAL_FUNDO_6MM
          operacoes << {
            tipo: 'Canal fundo',
            descricao: spec[:descricao],
            detalhes: "#{spec[:largura]}mm larg. × #{spec[:profundidade]}mm prof.",
            pecas_afetadas: 'Laterais, base, topo'
          }
        end

        # Canal para fundo de gaveta
        gavetas = mi.pecas.select { |p| p.tipo == :lateral_gaveta }
        if gavetas.any?
          operacoes << {
            tipo: 'Canal gaveta',
            descricao: 'Canal para fundo de gaveta',
            detalhes: "#{Config::CANAL_GAVETA_PROF}mm prof., #{Config::CANAL_GAVETA_DIST_BASE}mm da base",
            pecas_afetadas: 'Laterais e traseira de gaveta'
          }
        end

        # Rebaixo de fundo (se sobreposto com rebaixo)
        if mi.tipo_fundo == :sobreposto
          operacoes << {
            tipo: 'Rebaixo fundo',
            descricao: 'Rebaixo para fundo sobreposto',
            detalhes: "#{Config::REBAIXO_FUNDO_PADRAO}mm prof.",
            pecas_afetadas: 'Laterais, base'
          }
        end

        operacoes
      end

      # Gera notas de montagem passo a passo
      def self.gerar_notas_montagem(mi)
        notas = []
        passo = 1

        # Identificação da montagem
        nome_montagem = NOMES_MONTAGEM[mi.montagem] || mi.montagem.to_s
        notas << "#{passo}. Sistema de montagem: #{nome_montagem}"
        passo += 1

        # Furação
        nome_fixacao = NOMES_FIXACAO[mi.fixacao] || mi.fixacao.to_s
        notas << "#{passo}. Realizar furação de conexão (#{nome_fixacao}) conforme mapa de furação"
        passo += 1

        # Canal do fundo
        if mi.tipo_fundo == :rebaixado
          notas << "#{passo}. Fresar canal do fundo nas laterais, base e topo (#{mi.espessura_fundo}mm)"
          passo += 1
        end

        # Fita de borda
        notas << "#{passo}. Aplicar fita de borda conforme tabela (verificar bordas visíveis)"
        passo += 1

        # Sequência de montagem por tipo
        case mi.montagem
        when :laterais_entre
          notas << "#{passo}. Montar base entre as duas laterais"
          passo += 1
          notas << "#{passo}. Montar topo entre as duas laterais"
          passo += 1
          notas << "#{passo}. Encaixar fundo no canal (deslizar pela traseira)"
          passo += 1
        when :base_topo_entre
          notas << "#{passo}. Fixar base na lateral esquerda"
          passo += 1
          notas << "#{passo}. Fixar topo na lateral esquerda"
          passo += 1
          notas << "#{passo}. Encaixar fundo no canal"
          passo += 1
          notas << "#{passo}. Fixar lateral direita na base e topo"
          passo += 1
        end

        # Divisórias
        divisorias = mi.pecas.count { |p| p.tipo == :divisoria }
        if divisorias > 0
          notas << "#{passo}. Instalar #{divisorias} divisória(s) interna(s)"
          passo += 1
        end

        # Prateleiras
        prateleiras = mi.pecas.count { |p| p.tipo == :prateleira || p.tipo == :prateleira_adj }
        if prateleiras > 0
          notas << "#{passo}. Instalar suportes e colocar #{prateleiras} prateleira(s)"
          passo += 1
        end

        # Portas
        portas = mi.pecas.select { |p| p.tipo == :porta }
        if portas.any?
          portas.each do |porta|
            qtd_dobr = Utils.qtd_dobradicas(porta.comprimento)
            notas << "#{passo}. Instalar #{qtd_dobr} dobradiça(s) na porta '#{porta.nome}' (caneco D35mm, recuo #{Config::CANECO_RECUO_BORDA}mm)"
            passo += 1
          end
        end

        # Gavetas
        gavetas = mi.pecas.select { |p| p.tipo == :frente_gaveta }
        if gavetas.any?
          notas << "#{passo}. Montar caixa(s) de gaveta e instalar corrediça(s)"
          passo += 1
          notas << "#{passo}. Aplicar frente(s) de gaveta com regulagem"
          passo += 1
        end

        # Base / rodapé
        nome_base = NOMES_BASE[mi.tipo_base] || mi.tipo_base.to_s
        notas << "#{passo}. Instalar base: #{nome_base}"
        if mi.tipo_base == :rodape
          notas[-1] += " (H=#{mi.altura_rodape}mm, recuo=#{mi.recuo_rodape}mm)"
        end
        passo += 1

        # Verificação final
        notas << "#{passo}. Verificar esquadro, nível e ajustes finais"

        notas
      end

      # Gera lista de compras consolidada
      def self.gerar_lista_compras(fichas, area_por_material, fita_por_tipo, ferragens_total)
        compras = []

        # Chapas por material (arredonda para cima em chapas inteiras)
        # Chapa padrão MDF: 2,75 × 1,83m = 5.0325 m²
        area_chapa_padrao = 5.0325
        area_por_material.each do |material, area|
          qtd_chapas = (area / area_chapa_padrao).ceil
          qtd_chapas = [qtd_chapas, 1].max if area > 0
          compras << {
            categoria: 'Chapa',
            item: material,
            quantidade: qtd_chapas,
            unidade: 'chapa(s)',
            detalhe: "#{area} m² / #{area_chapa_padrao} m² por chapa"
          }
        end

        # Fita de borda (vende em rolos de 50m ou 20m)
        fita_por_tipo.each do |tipo, metros|
          qtd_rolos = (metros / 50.0).ceil
          qtd_rolos = [qtd_rolos, 1].max if metros > 0
          compras << {
            categoria: 'Fita de Borda',
            item: tipo,
            quantidade: qtd_rolos,
            unidade: 'rolo(s) 50m',
            detalhe: "#{metros} metros lineares"
          }
        end

        # Ferragens
        ferragens_total.each do |nome, qtd|
          compras << {
            categoria: 'Ferragem',
            item: nome,
            quantidade: qtd,
            unidade: 'un.',
            detalhe: ''
          }
        end

        compras
      end

      # ═══════════════════════════════════════════════
      # MÉTODOS PRIVADOS — geração HTML
      # ═══════════════════════════════════════════════

      # Cabeçalho HTML e CSS
      def self.html_head(ficha, formato)
        tamanho_pagina = formato == :resumida ? 'width: 210mm; min-height: 148.5mm;' : 'width: 210mm; min-height: 297mm;'
        <<~HTML
          <!DOCTYPE html>
          <html lang="pt-BR">
          <head>
            <meta charset="UTF-8">
            <title>Ficha Técnica — #{ficha.modulo_nome}</title>
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              body {
                font-family: 'Segoe UI', Tahoma, Arial, sans-serif;
                font-size: 11px;
                color: #333;
                background: #fff;
                #{tamanho_pagina}
                padding: 12mm;
              }
              .header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                border-bottom: 3px solid #e67e22;
                padding-bottom: 8px;
                margin-bottom: 12px;
              }
              .header h1 {
                font-size: 18px;
                color: #e67e22;
                font-weight: 700;
              }
              .header .logo {
                font-size: 22px;
                font-weight: 800;
                color: #e67e22;
                letter-spacing: 2px;
              }
              .header .meta {
                font-size: 9px;
                color: #888;
                text-align: right;
              }
              .section {
                margin-bottom: 10px;
              }
              .section h2 {
                font-size: 13px;
                color: #e67e22;
                border-bottom: 1px solid #f0c89e;
                padding-bottom: 3px;
                margin-bottom: 6px;
                text-transform: uppercase;
                letter-spacing: 0.5px;
              }
              .grid-2 {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 4px 16px;
              }
              .grid-3 {
                display: grid;
                grid-template-columns: 1fr 1fr 1fr;
                gap: 4px 16px;
              }
              .campo {
                display: flex;
                gap: 4px;
              }
              .campo .label {
                font-weight: 600;
                color: #666;
                white-space: nowrap;
              }
              .campo .valor {
                color: #222;
              }
              table {
                width: 100%;
                border-collapse: collapse;
                margin-bottom: 8px;
                font-size: 10px;
              }
              table th {
                background: #e67e22;
                color: #fff;
                padding: 4px 6px;
                text-align: left;
                font-weight: 600;
                font-size: 9px;
                text-transform: uppercase;
                letter-spacing: 0.3px;
              }
              table td {
                padding: 3px 6px;
                border-bottom: 1px solid #eee;
              }
              table tr:nth-child(even) {
                background: #fdf5ec;
              }
              table tr:hover {
                background: #fce8d0;
              }
              .num { text-align: right; font-variant-numeric: tabular-nums; }
              .fita-code { font-family: monospace; font-size: 12px; letter-spacing: 1px; }
              .totais {
                background: #fdf5ec;
                border: 1px solid #e67e22;
                border-radius: 4px;
                padding: 8px 12px;
                margin-top: 10px;
              }
              .totais .grid-3 { font-weight: 600; }
              .notas {
                font-size: 10px;
                line-height: 1.6;
              }
              .notas li {
                margin-bottom: 2px;
              }
              .img-placeholder {
                border: 2px dashed #e67e22;
                background: #fdf5ec;
                height: 120px;
                display: flex;
                align-items: center;
                justify-content: center;
                color: #c47018;
                font-size: 12px;
                margin-bottom: 10px;
                border-radius: 4px;
              }
              .rodape {
                margin-top: 12px;
                padding-top: 6px;
                border-top: 1px solid #ddd;
                font-size: 8px;
                color: #aaa;
                display: flex;
                justify-content: space-between;
              }
              @media print {
                body { padding: 8mm; }
                .header { page-break-after: avoid; }
                table { page-break-inside: avoid; }
              }
            </style>
          </head>
        HTML
      end

      # Cabeçalho do documento
      def self.html_cabecalho(ficha)
        tipo_nome = NOMES_TIPO_MODULO[ficha.tipo] || ficha.tipo.to_s
        <<~HTML
          <div class="header">
            <div>
              <span class="logo">ORNATO</span>
              <h1>Ficha T#{"\u00E9"}cnica</h1>
            </div>
            <div class="meta">
              <div><strong>#{ficha.modulo_nome}</strong></div>
              <div>ID: #{ficha.modulo_id}</div>
              <div>Tipo: #{tipo_nome} | Ambiente: #{ficha.ambiente}</div>
              <div>Data: #{ficha.data_geracao}</div>
            </div>
          </div>
        HTML
      end

      # Seção de dimensões
      def self.html_dimensoes(ficha)
        <<~HTML
          <div class="section">
            <h2>Dimens#{"\u00F5"}es (mm)</h2>
            <div class="grid-3">
              <div class="campo"><span class="label">Largura:</span> <span class="valor">#{ficha.largura}</span></div>
              <div class="campo"><span class="label">Altura:</span> <span class="valor">#{ficha.altura}</span></div>
              <div class="campo"><span class="label">Profundidade:</span> <span class="valor">#{ficha.profundidade}</span></div>
              <div class="campo"><span class="label">Larg. Interna:</span> <span class="valor">#{ficha.largura_interna}</span></div>
              <div class="campo"><span class="label">Alt. Interna:</span> <span class="valor">#{ficha.altura_interna}</span></div>
              <div class="campo"><span class="label">Prof. Interna:</span> <span class="valor">#{ficha.profundidade_interna}</span></div>
            </div>
          </div>
        HTML
      end

      # Seção de estrutura
      def self.html_estrutura(ficha)
        montagem = NOMES_MONTAGEM[ficha.montagem] || ficha.montagem.to_s
        fundo = NOMES_FUNDO[ficha.tipo_fundo] || ficha.tipo_fundo.to_s
        base = NOMES_BASE[ficha.tipo_base] || ficha.tipo_base.to_s
        fixacao = NOMES_FIXACAO[ficha.fixacao] || ficha.fixacao.to_s

        rodape_info = ''
        if ficha.tipo_base == :rodape || ficha.tipo_base == :pes_regulaveis
          rodape_info = " (H=#{ficha.altura_rodape}mm, recuo=#{ficha.recuo_rodape}mm)"
        end

        <<~HTML
          <div class="section">
            <h2>Estrutura</h2>
            <div class="grid-2">
              <div class="campo"><span class="label">Montagem:</span> <span class="valor">#{montagem}</span></div>
              <div class="campo"><span class="label">Fixa#{"\u00E7\u00E3"}o:</span> <span class="valor">#{fixacao}</span></div>
              <div class="campo"><span class="label">Fundo:</span> <span class="valor">#{fundo}</span></div>
              <div class="campo"><span class="label">Base:</span> <span class="valor">#{base}#{rodape_info}</span></div>
            </div>
          </div>
        HTML
      end

      # Seção de materiais
      def self.html_materiais(ficha)
        <<~HTML
          <div class="section">
            <h2>Materiais</h2>
            <div class="grid-2">
              <div class="campo"><span class="label">Corpo:</span> <span class="valor">#{ficha.material_corpo} (#{ficha.espessura_corpo_nominal}mm → #{ficha.espessura_corpo_real}mm real)</span></div>
              <div class="campo"><span class="label">Frente:</span> <span class="valor">#{ficha.material_frente}</span></div>
              <div class="campo"><span class="label">Fundo:</span> <span class="valor">#{ficha.material_fundo} (#{ficha.espessura_fundo_nominal}mm → #{ficha.espessura_fundo_real}mm real)</span></div>
              <div class="campo"><span class="label">Fita corpo:</span> <span class="valor">#{ficha.fita_corpo}</span></div>
              <div class="campo"><span class="label">Fita frente:</span> <span class="valor">#{ficha.fita_frente}</span></div>
            </div>
          </div>
        HTML
      end

      # Placeholder de imagem 3D
      def self.html_imagem_placeholder(ficha)
        <<~HTML
          <div class="img-placeholder">
            Vista 3D — #{ficha.modulo_nome} (#{ficha.largura} × #{ficha.altura} × #{ficha.profundidade} mm)
          </div>
        HTML
      end

      # Tabela de peças
      def self.html_tabela_pecas(ficha)
        linhas = ficha.lista_pecas.map do |p|
          tipo_nome = NOMES_TIPO_PECA[p[:tipo]] || p[:tipo].to_s
          <<~ROW
            <tr>
              <td>#{p[:nome]}</td>
              <td>#{tipo_nome}</td>
              <td class="num">#{p[:comprimento]}</td>
              <td class="num">#{p[:largura]}</td>
              <td class="num">#{p[:espessura]}</td>
              <td class="num">#{p[:espessura_real]}</td>
              <td>#{p[:material]}</td>
              <td class="fita-code">#{p[:fita_codigo]}</td>
              <td class="num">#{p[:quantidade]}</td>
            </tr>
          ROW
        end.join

        <<~HTML
          <div class="section">
            <h2>Lista de Pe#{"\u00E7"}as</h2>
            <table>
              <thead>
                <tr>
                  <th>Pe#{"\u00E7"}a</th>
                  <th>Tipo</th>
                  <th class="num">Comp(mm)</th>
                  <th class="num">Larg(mm)</th>
                  <th class="num">Esp(mm)</th>
                  <th class="num">Esp.Real(mm)</th>
                  <th>Material</th>
                  <th>Fita</th>
                  <th class="num">Qtd</th>
                </tr>
              </thead>
              <tbody>
                #{linhas}
              </tbody>
            </table>
            <div style="font-size: 9px; color: #888;">
              Fita: ■ = com fita | □ = sem fita (ordem: frente, topo, tr#{"\u00E1"}s, base)
            </div>
          </div>
        HTML
      end

      # Tabela de ferragens
      def self.html_tabela_ferragens(ficha)
        return '' if ficha.lista_ferragens.empty?

        linhas = ficha.lista_ferragens.map do |fg|
          <<~ROW
            <tr>
              <td>#{fg[:nome]}</td>
              <td>#{fg[:tipo]}</td>
              <td class="num">#{fg[:quantidade]}</td>
            </tr>
          ROW
        end.join

        <<~HTML
          <div class="section">
            <h2>Ferragens</h2>
            <table>
              <thead>
                <tr>
                  <th>Ferragem</th>
                  <th>Tipo</th>
                  <th class="num">Qtd</th>
                </tr>
              </thead>
              <tbody>
                #{linhas}
              </tbody>
            </table>
          </div>
        HTML
      end

      # Tabela de resumo de fita de borda
      def self.html_tabela_fita(ficha)
        return '' if ficha.resumo_fita.empty?

        linhas = ficha.resumo_fita.map do |rf|
          <<~ROW
            <tr>
              <td>#{rf[:fita]}</td>
              <td class="num">#{rf[:metros]}</td>
              <td class="num">#{rf[:pecas]}</td>
            </tr>
          ROW
        end.join

        <<~HTML
          <div class="section">
            <h2>Resumo Fita de Borda</h2>
            <table>
              <thead>
                <tr>
                  <th>Fita</th>
                  <th class="num">Metros</th>
                  <th class="num">Pe#{"\u00E7"}as</th>
                </tr>
              </thead>
              <tbody>
                #{linhas}
              </tbody>
            </table>
          </div>
        HTML
      end

      # Resumo de furação
      def self.html_resumo_furacao(ficha)
        return '' if ficha.resumo_furacao.empty?

        linhas = ficha.resumo_furacao.map do |rf|
          <<~ROW
            <tr>
              <td>#{rf[:tipo]}</td>
              <td>#{rf[:descricao]}</td>
              <td class="num">#{rf[:quantidade]}</td>
            </tr>
          ROW
        end.join

        <<~HTML
          <div class="section">
            <h2>Resumo Fura#{"\u00E7\u00E3"}o</h2>
            <table>
              <thead>
                <tr>
                  <th>Tipo</th>
                  <th>Descri#{"\u00E7\u00E3"}o</th>
                  <th class="num">Qtd</th>
                </tr>
              </thead>
              <tbody>
                #{linhas}
              </tbody>
            </table>
          </div>
        HTML
      end

      # Resumo de usinagem
      def self.html_resumo_usinagem(ficha)
        return '' if ficha.resumo_usinagem.empty?

        linhas = ficha.resumo_usinagem.map do |ru|
          <<~ROW
            <tr>
              <td>#{ru[:tipo]}</td>
              <td>#{ru[:descricao]}</td>
              <td>#{ru[:detalhes]}</td>
              <td>#{ru[:pecas_afetadas]}</td>
            </tr>
          ROW
        end.join

        <<~HTML
          <div class="section">
            <h2>Resumo Usinagem</h2>
            <table>
              <thead>
                <tr>
                  <th>Tipo</th>
                  <th>Descri#{"\u00E7\u00E3"}o</th>
                  <th>Detalhes</th>
                  <th>Pe#{"\u00E7"}as Afetadas</th>
                </tr>
              </thead>
              <tbody>
                #{linhas}
              </tbody>
            </table>
          </div>
        HTML
      end

      # Notas de montagem
      def self.html_notas_montagem(ficha)
        return '' if ficha.notas_montagem.empty?

        itens = ficha.notas_montagem.map { |n| "<li>#{n}</li>" }.join("\n")

        <<~HTML
          <div class="section">
            <h2>Notas de Montagem</h2>
            <ol class="notas">
              #{itens}
            </ol>
          </div>
        HTML
      end

      # Totais
      def self.html_totais(ficha)
        <<~HTML
          <div class="totais">
            <div class="grid-3">
              <div class="campo"><span class="label">Total pe#{"\u00E7"}as:</span> <span class="valor">#{ficha.total_pecas}</span></div>
              <div class="campo"><span class="label">#{"\u00C1"}rea total:</span> <span class="valor">#{ficha.area_total_m2} m#{"\u00B2"}</span></div>
              <div class="campo"><span class="label">Peso estimado:</span> <span class="valor">#{ficha.peso_estimado} kg</span></div>
              <div class="campo"><span class="label">Fita total:</span> <span class="valor">#{ficha.total_fita_metros.round(2)} m</span></div>
              <div class="campo"><span class="label">Ferragens:</span> <span class="valor">#{ficha.lista_ferragens.inject(0) { |s, f| s + (f[:quantidade] || 0) }} itens</span></div>
            </div>
          </div>
        HTML
      end

      # Rodapé
      def self.html_rodape(ficha)
        <<~HTML
          <div class="rodape">
            <span>Ornato Plugin — Ficha T#{"\u00E9"}cnica gerada automaticamente</span>
            <span>#{ficha.modulo_nome} | #{ficha.modulo_id}</span>
            <span>#{ficha.data_geracao}</span>
          </div>
        HTML
      end

      # ═══════════════════════════════════════════════
      # HTML DO RESUMO DO PROJETO
      # ═══════════════════════════════════════════════

      def self.html_head_resumo
        <<~HTML
          <!DOCTYPE html>
          <html lang="pt-BR">
          <head>
            <meta charset="UTF-8">
            <title>Resumo do Projeto — Ornato</title>
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              body {
                font-family: 'Segoe UI', Tahoma, Arial, sans-serif;
                font-size: 11px;
                color: #333;
                background: #fff;
                width: 210mm;
                min-height: 297mm;
                padding: 12mm;
              }
              .header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                border-bottom: 3px solid #e67e22;
                padding-bottom: 8px;
                margin-bottom: 14px;
              }
              .header h1 { font-size: 20px; color: #e67e22; font-weight: 700; }
              .header .logo { font-size: 24px; font-weight: 800; color: #e67e22; letter-spacing: 2px; }
              .header .meta { font-size: 9px; color: #888; text-align: right; }
              .section { margin-bottom: 12px; }
              .section h2 {
                font-size: 13px; color: #e67e22;
                border-bottom: 1px solid #f0c89e;
                padding-bottom: 3px; margin-bottom: 6px;
                text-transform: uppercase; letter-spacing: 0.5px;
              }
              table {
                width: 100%; border-collapse: collapse;
                margin-bottom: 8px; font-size: 10px;
              }
              table th {
                background: #e67e22; color: #fff;
                padding: 4px 6px; text-align: left;
                font-weight: 600; font-size: 9px;
                text-transform: uppercase;
              }
              table td { padding: 3px 6px; border-bottom: 1px solid #eee; }
              table tr:nth-child(even) { background: #fdf5ec; }
              .num { text-align: right; font-variant-numeric: tabular-nums; }
              .totais {
                background: #fdf5ec; border: 2px solid #e67e22;
                border-radius: 4px; padding: 10px 14px; margin-top: 12px;
              }
              .totais .grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 6px 16px; }
              .campo { display: flex; gap: 4px; }
              .campo .label { font-weight: 600; color: #666; }
              .campo .valor { color: #222; }
              .rodape {
                margin-top: 14px; padding-top: 6px;
                border-top: 1px solid #ddd; font-size: 8px; color: #aaa;
                display: flex; justify-content: space-between;
              }
              @media print { body { padding: 8mm; } table { page-break-inside: avoid; } }
            </style>
          </head>
        HTML
      end

      def self.html_cabecalho_resumo(resumo)
        <<~HTML
          <div class="header">
            <div>
              <span class="logo">ORNATO</span>
              <h1>Resumo do Projeto</h1>
            </div>
            <div class="meta">
              <div>Data: #{Time.now.strftime('%d/%m/%Y %H:%M')}</div>
            </div>
          </div>
        HTML
      end

      def self.html_modulos_por_ambiente(resumo)
        return '' unless resumo[:modulos_por_ambiente]
        linhas = resumo[:modulos_por_ambiente].map do |amb, qtd|
          "<tr><td>#{amb}</td><td class=\"num\">#{qtd}</td></tr>"
        end.join("\n")

        <<~HTML
          <div class="section">
            <h2>M#{"\u00F3"}dulos por Ambiente</h2>
            <table>
              <thead><tr><th>Ambiente</th><th class="num">Qtd</th></tr></thead>
              <tbody>#{linhas}</tbody>
            </table>
          </div>
        HTML
      end

      def self.html_modulos_por_tipo(resumo)
        return '' unless resumo[:modulos_por_tipo]
        linhas = resumo[:modulos_por_tipo].map do |tipo, qtd|
          nome = NOMES_TIPO_MODULO[tipo] || tipo.to_s
          "<tr><td>#{nome}</td><td class=\"num\">#{qtd}</td></tr>"
        end.join("\n")

        <<~HTML
          <div class="section">
            <h2>M#{"\u00F3"}dulos por Tipo</h2>
            <table>
              <thead><tr><th>Tipo</th><th class="num">Qtd</th></tr></thead>
              <tbody>#{linhas}</tbody>
            </table>
          </div>
        HTML
      end

      def self.html_area_materiais(resumo)
        return '' unless resumo[:area_por_material]
        linhas = resumo[:area_por_material].map do |mat, area|
          "<tr><td>#{mat}</td><td class=\"num\">#{area} m\u00B2</td></tr>"
        end.join("\n")

        <<~HTML
          <div class="section">
            <h2>#{"\u00C1"}rea por Material</h2>
            <table>
              <thead><tr><th>Material</th><th class="num">#{"\u00C1"}rea (m#{"\u00B2"})</th></tr></thead>
              <tbody>#{linhas}</tbody>
            </table>
          </div>
        HTML
      end

      def self.html_fita_total(resumo)
        return '' unless resumo[:fita_por_tipo]
        linhas = resumo[:fita_por_tipo].map do |tipo, metros|
          "<tr><td>#{tipo}</td><td class=\"num\">#{metros} m</td></tr>"
        end.join("\n")

        <<~HTML
          <div class="section">
            <h2>Fita de Borda Total</h2>
            <table>
              <thead><tr><th>Tipo</th><th class="num">Metros</th></tr></thead>
              <tbody>#{linhas}</tbody>
            </table>
          </div>
        HTML
      end

      def self.html_ferragens_total(resumo)
        return '' unless resumo[:ferragens_total]
        linhas = resumo[:ferragens_total].map do |nome, qtd|
          "<tr><td>#{nome}</td><td class=\"num\">#{qtd}</td></tr>"
        end.join("\n")

        <<~HTML
          <div class="section">
            <h2>Ferragens Total</h2>
            <table>
              <thead><tr><th>Ferragem</th><th class="num">Qtd</th></tr></thead>
              <tbody>#{linhas}</tbody>
            </table>
          </div>
        HTML
      end

      def self.html_lista_compras(resumo)
        return '' unless resumo[:lista_compras]
        linhas = resumo[:lista_compras].map do |item|
          <<~ROW
            <tr>
              <td>#{item[:categoria]}</td>
              <td>#{item[:item]}</td>
              <td class="num">#{item[:quantidade]}</td>
              <td>#{item[:unidade]}</td>
              <td>#{item[:detalhe]}</td>
            </tr>
          ROW
        end.join

        <<~HTML
          <div class="section">
            <h2>Lista de Compras</h2>
            <table>
              <thead>
                <tr>
                  <th>Categoria</th>
                  <th>Item</th>
                  <th class="num">Qtd</th>
                  <th>Unidade</th>
                  <th>Detalhe</th>
                </tr>
              </thead>
              <tbody>
                #{linhas}
              </tbody>
            </table>
          </div>
        HTML
      end

      def self.html_totais_projeto(resumo)
        <<~HTML
          <div class="totais">
            <div class="grid">
              <div class="campo"><span class="label">Total pe#{"\u00E7"}as:</span> <span class="valor">#{resumo[:total_pecas]}</span></div>
              <div class="campo"><span class="label">#{"\u00C1"}rea total:</span> <span class="valor">#{resumo[:area_total_m2]} m#{"\u00B2"}</span></div>
              <div class="campo"><span class="label">Peso total:</span> <span class="valor">#{resumo[:peso_total_kg]} kg</span></div>
            </div>
          </div>
        HTML
      end

      def self.html_rodape_resumo
        <<~HTML
          <div class="rodape">
            <span>Ornato Plugin — Resumo do Projeto gerado automaticamente</span>
            <span>#{Time.now.strftime('%d/%m/%Y %H:%M')}</span>
          </div>
        HTML
      end

    end
  end
end
