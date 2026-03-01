# ornato_plugin/engines/motor_inteligencia.rb — Motor de inteligencia para selecao automatica de ferragens
# Seleciona automaticamente dobradicas, corredicas, fitas de borda, fixadores
# e sugere configuracoes otimizadas com base no modulo e nivel de orcamento.
# Densidade MDF padrao: 750 kg/m3 (NBR 15316)

module Ornato
  module Engines
    class MotorInteligencia

      # ═══════════════════════════════════════════════
      # CONSTANTES
      # ═══════════════════════════════════════════════

      # Densidade do MDF em kg/m3 (fonte: NBR 15316-2)
      MDF_DENSIDADE = 750

      # ─── Catalogo de dobradicas por marca e capacidade ───
      DOBRADICAS = {
        blum: {
          marca: 'Blum',
          nivel: :premium,
          modelos: {
            leve:   { modelo: 'CLIP top 110', angulo: 110, capacidade_kg: 6,  preco_ref: 28.0 },
            medio:  { modelo: 'CLIP top 110 Blumotion', angulo: 110, capacidade_kg: 12, preco_ref: 38.0 },
            pesado: { modelo: 'CLIP top 155 Blumotion', angulo: 155, capacidade_kg: 20, preco_ref: 52.0 }
          },
          calco: 'Calco Blum CLIP (37mm)',
          soft_close: true,
          ajuste_3d: true
        },
        hettich: {
          marca: 'Hettich',
          nivel: :padrao,
          modelos: {
            leve:   { modelo: 'Sensys 110', angulo: 110, capacidade_kg: 6,  preco_ref: 18.0 },
            medio:  { modelo: 'Sensys 110 Silent', angulo: 110, capacidade_kg: 12, preco_ref: 24.0 },
            pesado: { modelo: 'Sensys 155 Silent', angulo: 155, capacidade_kg: 18, preco_ref: 35.0 }
          },
          calco: 'Calco Hettich Sensys',
          soft_close: true,
          ajuste_3d: true
        },
        hardt: {
          marca: 'Hardt',
          nivel: :economico,
          modelos: {
            leve:   { modelo: 'Slide-On 110', angulo: 110, capacidade_kg: 5,  preco_ref: 8.0 },
            medio:  { modelo: 'Slide-On 110 c/ amort.', angulo: 110, capacidade_kg: 10, preco_ref: 12.0 },
            pesado: { modelo: 'Slide-On 165', angulo: 165, capacidade_kg: 15, preco_ref: 18.0 }
          },
          calco: 'Calco Hardt padrao',
          soft_close: :opcional,
          ajuste_3d: false
        },
        hd: {
          marca: 'HD',
          nivel: :basico,
          modelos: {
            leve:   { modelo: 'HD 110 Basica', angulo: 110, capacidade_kg: 4,  preco_ref: 4.0 },
            medio:  { modelo: 'HD 110 c/ mola', angulo: 110, capacidade_kg: 8,  preco_ref: 6.0 },
            pesado: { modelo: 'HD 165', angulo: 165, capacidade_kg: 12, preco_ref: 10.0 }
          },
          calco: 'Calco HD universal',
          soft_close: false,
          ajuste_3d: false
        }
      }.freeze

      # ─── Mapa de nivel de orcamento para marca preferencial ───
      MARCA_POR_NIVEL = {
        premium:   :blum,
        padrao:    :hettich,
        economico: :hardt,
        basico:    :hd
      }.freeze

      # ─── Corredica: mapa de tipo por nivel de orcamento ───
      CORREDICA_POR_NIVEL = {
        premium:   :tandembox,
        padrao:    :oculta,
        economico: :telescopica,
        basico:    :roller
      }.freeze

      # ─── Capacidade de carga por tipo de corredica (kg) ───
      CORREDICA_CAPACIDADE = {
        roller:       34,
        telescopica:  45,
        oculta:       50,
        tandembox:    65
      }.freeze

      # ─── Fixadores: especificacoes por tipo de junta ───
      FIXADORES = {
        minifix: {
          nome: 'Minifix + Cavilha',
          tipos_junta: [:lateral_base, :lateral_topo, :divisoria],
          carga_max_kg: 80,
          nivel_min: :padrao,
          desmontavel: true,
          furos_por_juncao: { minifix: 2, cavilha: 2 },
          descricao: 'Conexao oculta desmontavel — uso profissional'
        },
        confirmat: {
          nome: 'Confirmat 5x50mm',
          tipos_junta: [:lateral_base, :lateral_topo, :divisoria, :prateleira_fixa],
          carga_max_kg: 60,
          nivel_min: :economico,
          desmontavel: false,
          furos_por_juncao: { confirmat: 2 },
          descricao: 'Parafuso autoatarraxante — montagem rapida'
        },
        cavilha: {
          nome: 'Cavilha 8x35mm',
          tipos_junta: [:lateral_base, :lateral_topo, :divisoria, :prateleira_fixa],
          carga_max_kg: 40,
          nivel_min: :basico,
          desmontavel: false,
          furos_por_juncao: { cavilha: 3 },
          descricao: 'Encaixe colado — sem ferragem aparente'
        },
        vb: {
          nome: 'VB 35/16',
          tipos_junta: [:lateral_base, :lateral_topo],
          carga_max_kg: 100,
          nivel_min: :premium,
          desmontavel: true,
          furos_por_juncao: { vb: 2, cavilha: 1 },
          descricao: 'Conector excêntrico reforçado — moveis grandes'
        }
      }.freeze

      # ─── Fita de borda: regras de visibilidade ───
      FITA_VISIBILIDADE = {
        exposta:     { tipo: :premium,  espessura: 2.0, material: 'ABS' },
        visivel:     { tipo: :padrao,   espessura: 1.0, material: 'PVC' },
        semi_oculta: { tipo: :melamine, espessura: 0.4, material: 'PVC' },
        oculta:      { tipo: :nenhuma,  espessura: 0.0, material: nil }
      }.freeze

      # Mapeamento de tipo de peca para nivel de visibilidade das bordas
      VISIBILIDADE_POR_TIPO = {
        porta:          { frente: :exposta,     topo: :exposta,     tras: :exposta,     base: :exposta },
        frente_gaveta:  { frente: :exposta,     topo: :exposta,     tras: :exposta,     base: :exposta },
        tampo:          { frente: :exposta,     topo: :visivel,     tras: :oculta,      base: :oculta },
        painel:         { frente: :exposta,     topo: :exposta,     tras: :exposta,     base: :exposta },
        lateral:        { frente: :visivel,     topo: :semi_oculta, tras: :oculta,      base: :oculta },
        base:           { frente: :visivel,     topo: :oculta,      tras: :oculta,      base: :oculta },
        topo:           { frente: :visivel,     topo: :oculta,      tras: :oculta,      base: :oculta },
        prateleira:     { frente: :visivel,     topo: :oculta,      tras: :oculta,      base: :oculta },
        prateleira_adj: { frente: :visivel,     topo: :semi_oculta, tras: :visivel,     base: :semi_oculta },
        divisoria:      { frente: :visivel,     topo: :oculta,      tras: :oculta,      base: :oculta },
        fundo:          { frente: :oculta,      topo: :oculta,      tras: :oculta,      base: :oculta },
        rodape:         { frente: :visivel,     topo: :visivel,     tras: :oculta,      base: :oculta },
        ripa:           { frente: :visivel,     topo: :visivel,     tras: :visivel,     base: :visivel },
      }.freeze

      # ═══════════════════════════════════════════════
      # SELECAO AUTOMATICA DE DOBRADICAS
      # ═══════════════════════════════════════════════

      # Estima o peso de uma porta MDF (kg)
      # @param largura_mm [Numeric] largura da porta em mm
      # @param altura_mm [Numeric] altura da porta em mm
      # @param espessura_mm [Numeric] espessura do MDF em mm
      # @param densidade [Numeric] densidade em kg/m3 (padrao MDF 750)
      # @return [Float] peso estimado em kg
      def self.estimar_peso_porta(largura_mm, altura_mm, espessura_mm, densidade: MDF_DENSIDADE)
        # Volume em m3
        volume_m3 = (largura_mm / 1000.0) * (altura_mm / 1000.0) * (espessura_mm / 1000.0)
        peso = volume_m3 * densidade

        # Adiciona 5% para fita de borda e acabamento
        peso * 1.05
      end

      # Classifica o peso da porta
      # @param peso_kg [Float] peso estimado em kg
      # @return [Symbol] :leve, :medio ou :pesado
      def self.classificar_peso(peso_kg)
        if peso_kg < 6.0
          :leve
        elsif peso_kg <= 12.0
          :medio
        else
          :pesado
        end
      end

      # Seleciona dobradica ideal para uma porta
      # @param largura_mm [Numeric] largura da porta
      # @param altura_mm [Numeric] altura da porta
      # @param espessura_mm [Numeric] espessura do MDF
      # @param nivel [Symbol] :premium, :padrao, :economico, :basico
      # @param angulo_abertura [Integer] angulo necessario (110, 155, 170)
      # @return [Hash] recomendacao completa de dobradica
      def self.selecionar_dobradica(largura_mm, altura_mm, espessura_mm, nivel: :padrao, angulo_abertura: 110)
        peso = estimar_peso_porta(largura_mm, altura_mm, espessura_mm)
        categoria_peso = classificar_peso(peso)
        qtd = Utils.qtd_dobradicas(altura_mm)

        # Peso por dobradica
        peso_por_dob = peso / qtd.to_f

        # Se o peso por dobradica ultrapassa a capacidade da categoria, sobe a categoria
        marca_key = MARCA_POR_NIVEL[nivel] || :hettich
        catalogo = DOBRADICAS[marca_key]
        modelo_info = catalogo[:modelos][categoria_peso]

        # Verifica se o modelo suporta o peso por dobradica
        if peso_por_dob > modelo_info[:capacidade_kg]
          # Tenta subir para a proxima categoria de peso
          categoria_peso = proximo_peso(categoria_peso)
          modelo_info = catalogo[:modelos][categoria_peso]

          # Se ainda nao suporta, sobe a marca
          if peso_por_dob > modelo_info[:capacidade_kg]
            marca_key = :blum
            catalogo = DOBRADICAS[:blum]
            modelo_info = catalogo[:modelos][:pesado]
          end
        end

        # Se precisa angulo maior que 110, verifica disponibilidade
        if angulo_abertura > 110
          pesado_info = catalogo[:modelos][:pesado]
          if pesado_info[:angulo] >= angulo_abertura
            modelo_info = pesado_info
          end
        end

        {
          marca: catalogo[:marca],
          modelo: modelo_info[:modelo],
          angulo: modelo_info[:angulo],
          quantidade: qtd,
          calco: catalogo[:calco],
          peso_porta_kg: peso.round(2),
          peso_por_dobradica_kg: peso_por_dob.round(2),
          categoria_peso: categoria_peso,
          soft_close: catalogo[:soft_close],
          ajuste_3d: catalogo[:ajuste_3d],
          nivel: nivel,
          preco_estimado_total: (modelo_info[:preco_ref] * qtd).round(2),
          ferragens: [
            { nome: "Dobradica #{catalogo[:marca]} #{modelo_info[:modelo]}", tipo: :dobradica, qtd: qtd },
            { nome: catalogo[:calco], tipo: :calco, qtd: qtd }
          ]
        }
      end

      # ═══════════════════════════════════════════════
      # SELECAO AUTOMATICA DE CORREDICAS
      # ═══════════════════════════════════════════════

      # Estima peso total de uma gaveta (estrutura MDF + conteudo estimado)
      # @param largura_mm [Numeric] largura interna da gaveta
      # @param profundidade_mm [Numeric] profundidade da gaveta
      # @param altura_lateral_mm [Numeric] altura da lateral da gaveta
      # @param espessura_mm [Numeric] espessura do MDF da gaveta
      # @param conteudo_estimado_kg [Numeric] peso estimado do conteudo
      # @return [Float] peso total estimado em kg
      def self.estimar_peso_gaveta(largura_mm, profundidade_mm, altura_lateral_mm, espessura_mm, conteudo_estimado_kg: 10.0)
        # Peso da estrutura MDF (2 laterais + frente + traseira + fundo)
        esp_m = espessura_mm / 1000.0
        alt_m = altura_lateral_mm / 1000.0
        larg_m = largura_mm / 1000.0
        prof_m = profundidade_mm / 1000.0

        # 2 laterais
        peso_laterais = 2 * (prof_m * alt_m * esp_m * MDF_DENSIDADE)
        # frente + traseira
        peso_ft = 2 * (larg_m * alt_m * esp_m * MDF_DENSIDADE)
        # fundo (3mm HDF, densidade ~850 kg/m3)
        peso_fundo = larg_m * prof_m * 0.003 * 850

        peso_estrutura = peso_laterais + peso_ft + peso_fundo
        peso_estrutura + conteudo_estimado_kg
      end

      # Seleciona corredica ideal para uma gaveta
      # @param largura_vao_mm [Numeric] largura do vao do modulo
      # @param profundidade_mm [Numeric] profundidade do modulo
      # @param peso_total_kg [Numeric] peso total estimado (estrutura + conteudo)
      # @param nivel [Symbol] :premium, :padrao, :economico, :basico
      # @return [Hash] recomendacao completa de corredica
      def self.selecionar_corredica(largura_vao_mm, profundidade_mm, peso_total_kg: 25.0, nivel: :padrao)
        tipo_ideal = CORREDICA_POR_NIVEL[nivel] || :telescopica

        # Verifica capacidade de carga
        capacidade = CORREDICA_CAPACIDADE[tipo_ideal]
        if peso_total_kg > capacidade
          # Sobe para um tipo com maior capacidade
          tipo_ideal = tipo_com_capacidade_suficiente(peso_total_kg)
        end

        # Busca specs do tipo selecionado
        specs = Config::CORREDICA_SPECS[tipo_ideal]
        return nil unless specs

        # Calcula comprimento ideal da corredica (snap para tamanho comercial)
        prof_util = profundidade_mm - Config::RECUO_TRASEIRO_GAVETA
        comprimento = Utils.snap_corredica(prof_util)

        # Verifica se o comprimento esta disponivel para o tipo
        comprimentos_disponiveis = specs[:comprimentos]
        unless comprimentos_disponiveis.include?(comprimento)
          comprimento = comprimentos_disponiveis.select { |c| c <= prof_util }.max || comprimentos_disponiveis.first
        end

        # Verifica limites de largura do modulo
        larg_max = specs[:largura_max_gaveta] || specs[:largura_max_modulo] || 1200
        if largura_vao_mm > larg_max
          # Para vaos muito largos, tandembox suporta ate 1200mm
          tipo_ideal = :tandembox if larg_max < largura_vao_mm && Config::CORREDICA_SPECS[:tandembox][:largura_max_modulo] >= largura_vao_mm
        end

        # Recalcula specs se o tipo mudou
        specs = Config::CORREDICA_SPECS[tipo_ideal]
        folga = Config::CORREDICA_FOLGAS[tipo_ideal]

        # Calcula largura da gaveta
        if specs[:deducao_interna]
          largura_gaveta_interna = largura_vao_mm - specs[:deducao_interna]
        else
          largura_gaveta_interna = largura_vao_mm - (2 * folga)
        end

        {
          tipo: tipo_ideal,
          nome: specs[:nome],
          comprimento: comprimento,
          folga_por_lado: folga,
          largura_gaveta_interna: largura_gaveta_interna.round(1),
          montagem: specs[:montagem],
          extensao: specs[:extensao],
          soft_close: specs[:soft_close],
          capacidade_kg: CORREDICA_CAPACIDADE[tipo_ideal],
          peso_estimado_kg: peso_total_kg.round(2),
          nivel: nivel,
          lateral_metalica: specs[:lateral_metalica] || false,
          ferragens: [
            { nome: "Corredica #{specs[:nome]} #{comprimento}mm", tipo: :corredica, qtd: 1 }
          ]
        }
      end

      # ═══════════════════════════════════════════════
      # SELECAO AUTOMATICA DE FITA DE BORDA
      # ═══════════════════════════════════════════════

      # Seleciona fita de borda automaticamente por tipo de peca e material
      # @param tipo_peca [Symbol] tipo da peca (:lateral, :porta, :prateleira, etc.)
      # @param material_corpo [String] material do corpo (para correspondencia de cor)
      # @param material_frente [String] material da frente (para portas/gavetas)
      # @param nivel [Symbol] nivel do orcamento
      # @return [Hash] configuracao de fita por borda
      def self.selecionar_fita_borda(tipo_peca, material_corpo: nil, material_frente: nil, nivel: :padrao)
        vis = VISIBILIDADE_POR_TIPO[tipo_peca] || VISIBILIDADE_POR_TIPO[:lateral]

        # Determina material da fita (correspondencia de cor)
        material_fita = if [:porta, :frente_gaveta, :painel, :tampo].include?(tipo_peca)
                          material_frente || material_corpo || 'PVC 1mm Branco'
                        else
                          material_corpo || 'PVC 1mm Branco'
                        end

        # Gera especificacao por borda
        bordas = {}
        [:frente, :topo, :tras, :base].each do |borda|
          nivel_vis = vis[borda]
          spec_fita = FITA_VISIBILIDADE[nivel_vis]

          # Upgrade para premium se nivel do orcamento for premium
          if nivel == :premium && nivel_vis == :visivel
            spec_fita = FITA_VISIBILIDADE[:exposta]
          end

          # Downgrade para economico se nivel for basico
          if nivel == :basico && nivel_vis == :visivel
            spec_fita = FITA_VISIBILIDADE[:semi_oculta]
          end

          bordas[borda] = {
            aplicar: spec_fita[:espessura] > 0,
            espessura_mm: spec_fita[:espessura],
            material_tipo: spec_fita[:material],
            material_cor: extrair_cor_material(material_fita)
          }
        end

        {
          tipo_peca: tipo_peca,
          material_referencia: material_fita,
          bordas: bordas,
          metros_estimados: 0.0  # calculado externamente com dimensoes
        }
      end

      # Calcula metros lineares de fita necessarios para uma peca
      # @param comprimento_mm [Numeric] comprimento da peca
      # @param largura_mm [Numeric] largura da peca
      # @param config_fita [Hash] resultado de selecionar_fita_borda
      # @return [Float] metros lineares totais
      def self.calcular_metros_fita(comprimento_mm, largura_mm, config_fita)
        metros = 0.0
        bordas = config_fita[:bordas]

        metros += comprimento_mm / 1000.0 if bordas[:frente][:aplicar]
        metros += comprimento_mm / 1000.0 if bordas[:tras][:aplicar]
        metros += largura_mm / 1000.0 if bordas[:topo][:aplicar]
        metros += largura_mm / 1000.0 if bordas[:base][:aplicar]

        metros
      end

      # ═══════════════════════════════════════════════
      # SELECAO AUTOMATICA DE FIXADORES
      # ═══════════════════════════════════════════════

      # Seleciona fixador ideal para uma juncao
      # @param tipo_junta [Symbol] :lateral_base, :lateral_topo, :divisoria, :prateleira
      # @param carga_estimada_kg [Numeric] carga estimada na juncao
      # @param nivel [Symbol] nivel do orcamento
      # @param desmontavel [Boolean] se precisa ser desmontavel
      # @return [Hash] recomendacao de fixador
      def self.selecionar_fixador(tipo_junta, carga_estimada_kg: 30.0, nivel: :padrao, desmontavel: false)
        # Filtra fixadores que suportam esse tipo de junta
        candidatos = FIXADORES.select { |_k, v| v[:tipos_junta].include?(tipo_junta) }

        # Se precisa ser desmontavel, filtra
        if desmontavel
          candidatos = candidatos.select { |_k, v| v[:desmontavel] }
        end

        # Filtra por capacidade de carga
        candidatos = candidatos.select { |_k, v| v[:carga_max_kg] >= carga_estimada_kg }

        # Se nao ha candidatos, usa minifix como fallback
        if candidatos.empty?
          candidatos = { vb: FIXADORES[:vb] }
        end

        # Seleciona por nivel de orcamento (preferencia)
        niveis_ordem = [:basico, :economico, :padrao, :premium]
        nivel_idx = niveis_ordem.index(nivel) || 2

        melhor = nil
        melhor_key = nil

        candidatos.each do |key, spec|
          nivel_fix_idx = niveis_ordem.index(spec[:nivel_min]) || 0
          # Prefere o fixador cujo nivel minimo e mais proximo do nivel do orcamento
          if melhor.nil? || (nivel_fix_idx - nivel_idx).abs < (niveis_ordem.index(melhor[:nivel_min]) - nivel_idx).abs
            melhor = spec
            melhor_key = key
          end
        end

        furos = melhor[:furos_por_juncao]
        ferragens = furos.map do |tipo_furo, qtd|
          { nome: nome_ferragem_fixador(tipo_furo), tipo: tipo_furo, qtd: qtd }
        end

        {
          tipo: melhor_key,
          nome: melhor[:nome],
          desmontavel: melhor[:desmontavel],
          carga_max_kg: melhor[:carga_max_kg],
          furos_por_juncao: furos,
          nivel: nivel,
          descricao: melhor[:descricao],
          ferragens: ferragens
        }
      end

      # ═══════════════════════════════════════════════
      # SUGESTAO DE CONFIGURACAO COMPLETA
      # ═══════════════════════════════════════════════

      # Sugere configuracao otimizada para um modulo completo
      # @param modulo_info [ModuloInfo] informacoes do modulo
      # @param nivel [Symbol] :premium, :padrao, :economico, :basico (default: :padrao)
      # @return [Hash] configuracao completa recomendada
      def self.sugerir_configuracao(modulo_info, nivel: :padrao)
        mi = modulo_info
        config = {
          modulo: mi.nome,
          tipo: mi.tipo,
          dimensoes: "#{mi.largura}x#{mi.altura}x#{mi.profundidade}mm",
          nivel: nivel,
          dobradicas: nil,
          corredicas: nil,
          fixadores: [],
          fitas_borda: [],
          ferragens_totais: [],
          resumo: {}
        }

        # ─── Dobradicas (se o modulo tem portas) ───
        portas = mi.pecas.select { |p| p.tipo == :porta }
        if portas.any?
          porta = portas.first
          dob = selecionar_dobradica(
            porta.largura, porta.comprimento, porta.espessura,
            nivel: nivel
          )
          config[:dobradicas] = dob
          config[:ferragens_totais] += dob[:ferragens]
        end

        # ─── Corredicas (se o modulo tem gavetas) ───
        gavetas = mi.pecas.select { |p| p.tipo == :lateral_gaveta || p.tipo == :frente_gaveta }
        if gavetas.any?
          # Usa a largura interna do modulo e a profundidade
          largura_vao = mi.largura_interna
          corr = selecionar_corredica(
            largura_vao, mi.profundidade_interna,
            nivel: nivel
          )
          config[:corredicas] = corr
          # Uma corredica por gaveta (par esquerdo + direito conta como 1 par)
          qtd_gavetas = mi.pecas.count { |p| p.tipo == :frente_gaveta }
          qtd_gavetas = 1 if qtd_gavetas == 0
          corr[:ferragens].each do |f|
            config[:ferragens_totais] << f.merge(qtd: f[:qtd] * qtd_gavetas)
          end
        end

        # ─── Fixadores por tipo de juncao ───
        juncoes = identificar_juncoes(mi)
        juncoes.each do |juncao|
          fix = selecionar_fixador(
            juncao[:tipo],
            carga_estimada_kg: juncao[:carga_kg],
            nivel: nivel,
            desmontavel: nivel != :basico
          )
          fix[:quantidade_juncoes] = juncao[:qtd]
          config[:fixadores] << fix

          fix[:ferragens].each do |f|
            config[:ferragens_totais] << f.merge(qtd: f[:qtd] * juncao[:qtd])
          end
        end

        # ─── Fita de borda por peca ───
        mi.pecas.each do |peca|
          fita = selecionar_fita_borda(
            peca.tipo,
            material_corpo: mi.material_corpo,
            material_frente: mi.material_frente,
            nivel: nivel
          )
          metros = calcular_metros_fita(peca.comprimento, peca.largura, fita)
          fita[:metros_estimados] = (metros * (peca.quantidade || 1)).round(3)
          fita[:peca_nome] = peca.nome
          config[:fitas_borda] << fita
        end

        # ─── Resumo ───
        total_metros_fita = config[:fitas_borda].sum { |f| f[:metros_estimados] }
        total_ferragens = config[:ferragens_totais].length

        config[:resumo] = {
          total_dobradicas: config[:dobradicas] ? config[:dobradicas][:quantidade] : 0,
          total_corredicas: config[:corredicas] ? (mi.pecas.count { |p| p.tipo == :frente_gaveta } || 0) : 0,
          total_metros_fita: total_metros_fita.round(2),
          total_itens_ferragem: total_ferragens,
          nivel_orcamento: nivel,
          observacoes: gerar_observacoes(mi, config, nivel)
        }

        config
      end

      # ═══════════════════════════════════════════════
      # COMPARACAO DE NIVEIS DE ORCAMENTO
      # ═══════════════════════════════════════════════

      # Compara configuracoes entre niveis de orcamento
      # @param modulo_info [ModuloInfo] informacoes do modulo
      # @return [Hash] comparacao entre :economico, :padrao e :premium
      def self.comparar_niveis(modulo_info)
        comparacao = {}

        [:economico, :padrao, :premium].each do |nivel|
          config = sugerir_configuracao(modulo_info, nivel: nivel)

          preco_total = 0.0
          preco_total += config[:dobradicas][:preco_estimado_total] if config[:dobradicas]
          config[:ferragens_totais].each do |f|
            # Estimativa grosseira de preco por ferragem
            preco_total += f[:qtd] * 5.0
          end

          comparacao[nivel] = {
            config: config,
            preco_estimado_ferragens: preco_total.round(2),
            qualidade: case nivel
                       when :premium   then 'Alta durabilidade, soft-close, ajuste 3D'
                       when :padrao    then 'Boa durabilidade, soft-close'
                       when :economico then 'Funcional, custo reduzido'
                       end
          }
        end

        comparacao
      end

      # ═══════════════════════════════════════════════
      # RELATORIO TEXTO FORMATADO
      # ═══════════════════════════════════════════════

      # Gera relatorio texto da sugestao
      # @param modulo_info [ModuloInfo] informacoes do modulo
      # @param nivel [Symbol] nivel de orcamento
      # @return [String] relatorio formatado
      def self.relatorio_texto(modulo_info, nivel: :padrao)
        config = sugerir_configuracao(modulo_info, nivel: nivel)

        linhas = []
        linhas << "=" * 60
        linhas << "  SUGESTAO DE FERRAGENS — MOTOR INTELIGENCIA"
        linhas << "=" * 60
        linhas << ""
        linhas << "Modulo: #{config[:modulo]} (#{config[:tipo]})"
        linhas << "Dimensoes: #{config[:dimensoes]}"
        linhas << "Nivel: #{config[:nivel].to_s.upcase}"
        linhas << ""

        if config[:dobradicas]
          d = config[:dobradicas]
          linhas << "── DOBRADICAS ──"
          linhas << "  Marca: #{d[:marca]}"
          linhas << "  Modelo: #{d[:modelo]}"
          linhas << "  Quantidade: #{d[:quantidade]}"
          linhas << "  Angulo: #{d[:angulo]} graus"
          linhas << "  Peso porta: #{d[:peso_porta_kg]} kg (#{d[:categoria_peso]})"
          linhas << "  Soft-close: #{d[:soft_close] ? 'Sim' : 'Nao'}"
          linhas << "  Calco: #{d[:calco]}"
          linhas << "  Preco estimado: R$ #{d[:preco_estimado_total]}"
          linhas << ""
        end

        if config[:corredicas]
          c = config[:corredicas]
          linhas << "── CORREDICAS ──"
          linhas << "  Tipo: #{c[:nome]}"
          linhas << "  Comprimento: #{c[:comprimento]}mm"
          linhas << "  Montagem: #{c[:montagem]}"
          linhas << "  Extensao: #{c[:extensao]}"
          linhas << "  Capacidade: #{c[:capacidade_kg]} kg"
          linhas << "  Soft-close: #{c[:soft_close]}"
          linhas << ""
        end

        if config[:fixadores].any?
          linhas << "── FIXADORES ──"
          config[:fixadores].each do |f|
            linhas << "  #{f[:nome]} — #{f[:quantidade_juncoes]} juncoes"
            linhas << "    Desmontavel: #{f[:desmontavel] ? 'Sim' : 'Nao'}"
            linhas << "    Carga max: #{f[:carga_max_kg]} kg"
          end
          linhas << ""
        end

        r = config[:resumo]
        linhas << "── RESUMO ──"
        linhas << "  Dobradicas: #{r[:total_dobradicas]}"
        linhas << "  Corredicas (pares): #{r[:total_corredicas]}"
        linhas << "  Fita de borda: #{r[:total_metros_fita]} metros"
        linhas << "  Itens ferragem: #{r[:total_itens_ferragem]}"
        linhas << ""

        if r[:observacoes].any?
          linhas << "── OBSERVACOES ──"
          r[:observacoes].each { |obs| linhas << "  * #{obs}" }
        end

        linhas << "=" * 60
        linhas.join("\n")
      end

      # ═══════════════════════════════════════════════
      # METODOS PRIVADOS (HELPERS)
      # ═══════════════════════════════════════════════
      private

      # Retorna a proxima categoria de peso (escala)
      def self.proximo_peso(categoria)
        case categoria
        when :leve  then :medio
        when :medio then :pesado
        else :pesado
        end
      end

      # Encontra o tipo de corredica com capacidade suficiente
      def self.tipo_com_capacidade_suficiente(peso_kg)
        ordem = [:roller, :telescopica, :oculta, :tandembox]
        ordem.each do |tipo|
          return tipo if CORREDICA_CAPACIDADE[tipo] >= peso_kg
        end
        :tandembox  # fallback para o mais resistente
      end

      # Extrai a cor principal do nome do material
      # Ex: 'MDF Carvalho 15mm' => 'Carvalho'
      #     'MDF Branco TX 18mm' => 'Branco TX'
      def self.extrair_cor_material(material_nome)
        return 'Branco' unless material_nome

        nome = material_nome.to_s
        # Remove prefixo (MDF, MDP, HDF) e sufixo (espessura)
        nome = nome.sub(/^(MDF|MDP|HDF|Compensado|PVC|ABS)\s*/i, '')
        nome = nome.sub(/\s*\d+mm\s*$/, '')
        nome = nome.strip
        nome.empty? ? 'Branco' : nome
      end

      # Identifica as juncoes estruturais de um modulo
      def self.identificar_juncoes(mi)
        juncoes = []

        # Juncoes lateral-base (2 laterais x base)
        juncoes << { tipo: :lateral_base, qtd: 2, carga_kg: estimar_carga_juncao(mi, :lateral_base) }

        # Juncoes lateral-topo (2 laterais x topo)
        juncoes << { tipo: :lateral_topo, qtd: 2, carga_kg: estimar_carga_juncao(mi, :lateral_topo) }

        # Divisorias (se houver)
        qtd_divisorias = mi.pecas.count { |p| p.tipo == :divisoria }
        if qtd_divisorias > 0
          juncoes << { tipo: :divisoria, qtd: qtd_divisorias * 2, carga_kg: estimar_carga_juncao(mi, :divisoria) }
        end

        # Prateleiras fixas (se houver)
        qtd_prat_fixas = mi.pecas.count { |p| p.tipo == :prateleira && p.respond_to?(:fixa?) && p.fixa? }
        if qtd_prat_fixas > 0
          juncoes << { tipo: :prateleira, qtd: qtd_prat_fixas * 2, carga_kg: 20.0 }
        end

        juncoes
      end

      # Estima a carga em uma juncao estrutural (kg)
      def self.estimar_carga_juncao(mi, tipo_junta)
        case tipo_junta
        when :lateral_base
          # Peso do modulo inteiro apoiado nas 2 juncoes base
          peso_modulo = estimar_peso_modulo(mi)
          peso_modulo / 2.0
        when :lateral_topo
          # Topo carrega portas/objetos em cima (menor carga)
          15.0
        when :divisoria
          # Divisoria divide carga de prateleiras
          25.0
        else
          20.0
        end
      end

      # Estima o peso total do modulo montado (kg)
      def self.estimar_peso_modulo(mi)
        peso = 0.0
        mi.pecas.each do |peca|
          vol_m3 = (peca.comprimento / 1000.0) * (peca.largura / 1000.0) * (peca.espessura / 1000.0)
          peso += vol_m3 * MDF_DENSIDADE * (peca.quantidade || 1)
        end
        # Adiciona 15% para ferragens e acabamentos
        peso * 1.15
      end

      # Gera nome padrao de ferragem para um tipo de fixador
      def self.nome_ferragem_fixador(tipo_furo)
        case tipo_furo
        when :minifix   then 'Minifix 15mm'
        when :confirmat then 'Confirmat 5x50mm'
        when :cavilha   then 'Cavilha 8x35mm'
        when :vb        then 'VB 35/16'
        else "Fixador #{tipo_furo}"
        end
      end

      # Gera lista de observacoes contextuais para o relatorio
      def self.gerar_observacoes(mi, config, nivel)
        obs = []

        # Observacoes sobre peso
        if config[:dobradicas] && config[:dobradicas][:categoria_peso] == :pesado
          obs << "Porta pesada (>12kg): verificar reforco na lateral do modulo."
        end

        # Observacoes sobre corredica
        if config[:corredicas]
          if config[:corredicas][:tipo] == :tandembox
            obs << "Tandembox usa lateral metalica — nao precisa de lateral MDF na gaveta."
          end
          if config[:corredicas][:tipo] == :roller
            obs << "Corredica roller tem extensao parcial (3/4) — acesso limitado ao fundo da gaveta."
          end
        end

        # Observacoes sobre modulo
        if mi.altura > 2000
          obs << "Modulo alto (>2m): considerar fixacao na parede para seguranca."
        end

        if mi.largura > 900
          obs << "Modulo largo (>900mm): considerar fundo dividido ou reforco estrutural."
        end

        if mi.tipo == :torre
          obs << "Modulo torre: verificar ancoragem na parede (norma ABNT NBR 14535)."
        end

        if nivel == :basico
          obs << "Nivel basico: ferragens sem soft-close e sem ajuste 3D."
        end

        if nivel == :premium
          obs << "Nivel premium: todas as ferragens com soft-close e ajuste tridimensional."
        end

        obs
      end
    end
  end
end
