# ornato_plugin/engines/motor_fita_borda.rb — Motor de fita de borda inteligente
# Regras reais de visibilidade e espessura por tipo de peça
# Specs: PVC 0.4mm (interna), PVC/ABS 1mm (visível padrão), ABS 2mm (premium/alto tráfego)

module Ornato
  module Engines
    class MotorFitaBorda

      # ═══════════════════════════════════════════════
      # ESPESSURAS DISPONÍVEIS E APLICAÇÃO
      # ═══════════════════════════════════════════════
      ESPESSURAS = {
        nenhuma:  { esp: 0,   descricao: 'Sem fita',                       impacto_dim: 0   },
        melamine: { esp: 0.4, descricao: 'Melamínico / PVC fino 0.4mm',    impacto_dim: 0   },
        padrao:   { esp: 1.0, descricao: 'PVC/ABS 1mm (padrão visível)',   impacto_dim: 1.0 },
        premium:  { esp: 2.0, descricao: 'ABS 2mm (alto tráfego)',         impacto_dim: 2.0 },
        pesada:   { esp: 3.0, descricao: 'ABS 3mm (pesado/decorativo)',    impacto_dim: 3.0 },
      }.freeze

      # ═══════════════════════════════════════════════
      # REGRAS DE FITA POR TIPO DE PEÇA
      # ═══════════════════════════════════════════════
      # Cada borda: false = sem fita, :melamine, :padrao, :premium
      # frente = borda frontal visível
      # topo/base = bordas compridas (superior/inferior)
      # tras = borda traseira (geralmente contra parede)
      REGRAS = {
        # ── Carcaça ──
        lateral:        { frente: :padrao,   topo: :melamine, tras: false,    base: false,
                          notas: 'Frente visível 1mm; topo visível se superior; tras contra parede' },
        base:           { frente: :padrao,   topo: false,     tras: false,    base: false,
                          notas: 'Somente frente visível' },
        topo:           { frente: :padrao,   topo: false,     tras: false,    base: false,
                          notas: 'Somente frente visível' },
        fundo:          { frente: false,      topo: false,     tras: false,    base: false,
                          notas: 'Fundo encaixado no canal — nenhuma borda visível' },

        # ── Prateleira ──
        prateleira:     { frente: :padrao,   topo: false,     tras: false,    base: false,
                          notas: 'Somente frente visível; ajustável: frente+tras' },
        prateleira_adj: { frente: :padrao,   topo: :melamine, tras: :padrao,  base: :melamine,
                          notas: 'Ajustável: frente+tras visíveis, longas opcionais' },

        # ── Divisória ──
        divisoria:      { frente: :padrao,   topo: false,     tras: false,    base: false,
                          notas: 'Somente frente visível' },

        # ── Porta (TODAS as bordas visíveis) ──
        porta:          { frente: :padrao,   topo: :padrao,   tras: :padrao,  base: :padrao,
                          notas: 'Todas 4 bordas visíveis — padrão 1mm' },

        # ── Gaveta ──
        frente_gaveta:  { frente: :padrao,   topo: :padrao,   tras: :padrao,  base: :padrao,
                          notas: 'Frente aplicada: todas 4 bordas visíveis' },
        lateral_gaveta: { frente: false,      topo: :melamine, tras: false,    base: false,
                          notas: 'Interior: topo opcional 0.4mm' },
        traseira_gaveta:{ frente: false,      topo: :melamine, tras: false,    base: false,
                          notas: 'Interior: topo opcional 0.4mm' },
        fundo_gaveta:   { frente: false,      topo: false,     tras: false,    base: false,
                          notas: 'Encaixado no canal — sem fita' },

        # ── Peças especiais ──
        painel:         { frente: :padrao,   topo: :padrao,   tras: :padrao,  base: :padrao,
                          notas: 'Painel solto: todas bordas visíveis' },
        tampo:          { frente: :premium,  topo: :padrao,   tras: false,    base: false,
                          notas: 'Frente 2mm (alto tráfego); laterais 1mm; tras contra parede' },
        rodape:         { frente: :padrao,   topo: :padrao,   tras: false,    base: false,
                          notas: 'Frente + topo visíveis' },
        requadro:       { frente: :padrao,   topo: :padrao,   tras: false,    base: :padrao,
                          notas: 'Frente + topo + base visíveis' },
        moldura:        { frente: :padrao,   topo: false,     tras: false,    base: false,
                          notas: 'Somente frente visível' },

        # ── Painel cavilhado / ripado ──
        ripa:           { frente: :padrao,   topo: :padrao,   tras: :padrao,  base: :padrao,
                          notas: 'Ripas soltas: todas bordas visíveis' },
        montante:       { frente: :padrao,   topo: :padrao,   tras: :padrao,  base: :padrao,
                          notas: 'Montantes: todas bordas visíveis' },

        # ── Genérica (fallback) ──
        generica:       { frente: :padrao,   topo: false,     tras: false,    base: false,
                          notas: 'Regra padrão: somente frente' },
      }.freeze

      # ═══════════════════════════════════════════════
      # APLICAR REGRA AUTOMÁTICA
      # ═══════════════════════════════════════════════
      def self.aplicar_regra(peca, material_corpo: nil, material_frente: nil)
        regra = REGRAS[peca.tipo] || REGRAS[:generica]

        peca.fita_frente = !!regra[:frente]
        peca.fita_topo   = !!regra[:topo]
        peca.fita_tras   = !!regra[:tras]
        peca.fita_base   = !!regra[:base]

        # Espessura da fita por borda (guarda nos atributos extras)
        peca.instance_variable_set(:@fita_esp_frente, espessura_mm(regra[:frente]))
        peca.instance_variable_set(:@fita_esp_topo,   espessura_mm(regra[:topo]))
        peca.instance_variable_set(:@fita_esp_tras,   espessura_mm(regra[:tras]))
        peca.instance_variable_set(:@fita_esp_base,   espessura_mm(regra[:base]))

        # Material da fita baseado no tipo
        if [:porta, :frente_gaveta, :painel].include?(peca.tipo)
          peca.fita_material = material_frente || peca.fita_material
        else
          peca.fita_material = material_corpo || peca.fita_material
        end

        peca
      end

      # ═══════════════════════════════════════════════
      # APLICAR COM OVERRIDE MANUAL POR ARESTA
      # ═══════════════════════════════════════════════
      def self.aplicar_com_override(peca, overrides = {})
        regra = REGRAS[peca.tipo] || REGRAS[:generica]

        peca.fita_frente = overrides.key?(:frente) ? !!overrides[:frente] : !!regra[:frente]
        peca.fita_topo   = overrides.key?(:topo)   ? !!overrides[:topo]   : !!regra[:topo]
        peca.fita_tras   = overrides.key?(:tras)    ? !!overrides[:tras]   : !!regra[:tras]
        peca.fita_base   = overrides.key?(:base)    ? !!overrides[:base]   : !!regra[:base]

        peca
      end

      # ═══════════════════════════════════════════════
      # APLICAR COM ADJACÊNCIA (borda encostada = sem fita)
      # ═══════════════════════════════════════════════
      def self.aplicar_com_adjacencia(peca, adjacencias = {})
        regra = REGRAS[peca.tipo] || REGRAS[:generica]

        peca.fita_frente = !!regra[:frente] && !adjacencias[:frente]
        peca.fita_topo   = !!regra[:topo]   && !adjacencias[:topo]
        peca.fita_tras   = !!regra[:tras]   && !adjacencias[:tras]
        peca.fita_base   = !!regra[:base]   && !adjacencias[:base]

        peca
      end

      # ═══════════════════════════════════════════════
      # AJUSTE DE DIMENSÃO DE CORTE
      # ═══════════════════════════════════════════════
      # Para fitas >= 1mm, o painel deve ser cortado menor
      # pois a fita será colada e completará a dimensão final.
      # Exemplo: peça final 500mm com fita 2mm nos 2 lados → cortar 496mm
      def self.dimensao_corte(peca)
        regra = REGRAS[peca.tipo] || REGRAS[:generica]

        # Ajuste no comprimento (bordas topo + base)
        desc_comp = 0.0
        desc_comp += espessura_mm(regra[:topo])  if espessura_mm(regra[:topo]) >= 1.0
        desc_comp += espessura_mm(regra[:base]) if espessura_mm(regra[:base]) >= 1.0

        # Ajuste na largura (bordas frente + tras)
        desc_larg = 0.0
        desc_larg += espessura_mm(regra[:frente]) if espessura_mm(regra[:frente]) >= 1.0
        desc_larg += espessura_mm(regra[:tras])   if espessura_mm(regra[:tras]) >= 1.0

        {
          comprimento_corte: peca.comprimento - desc_comp,
          largura_corte: peca.largura - desc_larg,
          desconto_comprimento: desc_comp,
          desconto_largura: desc_larg,
          nota: desc_comp > 0 || desc_larg > 0 ?
            "Cortar #{desc_comp > 0 ? "-#{desc_comp}mm comp" : ''} #{desc_larg > 0 ? "-#{desc_larg}mm larg" : ''} (fita >= 1mm)" :
            'Sem ajuste (fitas <= 0.4mm)'
        }
      end

      # ═══════════════════════════════════════════════
      # RELATÓRIO POR MÓDULO
      # ═══════════════════════════════════════════════
      def self.relatorio(modulo_info)
        por_material = {}

        modulo_info.pecas.each do |peca|
          next if peca.fita_metros <= 0

          key = peca.fita_material || 'Sem material'
          por_material[key] ||= { metros: 0.0, pecas: [], por_espessura: {} }
          por_material[key][:metros] += peca.fita_metros
          por_material[key][:pecas] << {
            nome: peca.nome,
            metros: peca.fita_metros,
            codigo: peca.fita_codigo,
            quantidade: peca.quantidade || 1
          }

          # Agrupa por espessura
          regra = REGRAS[peca.tipo] || REGRAS[:generica]
          [:frente, :topo, :tras, :base].each do |borda|
            esp = espessura_mm(regra[borda])
            next if esp <= 0

            esp_key = "#{esp}mm"
            por_material[key][:por_espessura][esp_key] ||= 0.0
            comp_borda = [:frente, :tras].include?(borda) ? peca.comprimento : peca.largura
            por_material[key][:por_espessura][esp_key] += (comp_borda / 1000.0) * (peca.quantidade || 1)
          end
        end

        por_material
      end

      # ═══════════════════════════════════════════════
      # RELATÓRIO DO PROJETO INTEIRO
      # ═══════════════════════════════════════════════
      def self.relatorio_projeto
        modulos = Utils.listar_modulos
        total = {}

        modulos.each do |grupo|
          mi = Models::ModuloInfo.carregar_do_grupo(grupo)
          next unless mi

          rel = relatorio(mi)
          rel.each do |mat, dados|
            total[mat] ||= { metros: 0.0, pecas: [], por_espessura: {} }
            total[mat][:metros] += dados[:metros]
            total[mat][:pecas] += dados[:pecas]

            dados[:por_espessura].each do |esp, metros|
              total[mat][:por_espessura][esp] ||= 0.0
              total[mat][:por_espessura][esp] += metros
            end
          end
        end

        total
      end

      # ═══════════════════════════════════════════════
      # RELATÓRIO TEXTO FORMATADO
      # ═══════════════════════════════════════════════
      def self.relatorio_texto(modulo_info = nil)
        rel = modulo_info ? relatorio(modulo_info) : relatorio_projeto
        return "Nenhuma fita de borda registrada." if rel.empty?

        linhas = ["═══ RELATÓRIO DE FITA DE BORDA ═══\n"]
        total_metros = 0.0

        rel.each do |mat, dados|
          linhas << "\n── Material: #{mat} ──"
          linhas << "   Total: #{dados[:metros].round(2)} metros"
          total_metros += dados[:metros]

          # Por espessura
          unless dados[:por_espessura].empty?
            linhas << "   Por espessura:"
            dados[:por_espessura].each do |esp, metros|
              linhas << "     #{esp}: #{metros.round(2)} m"
            end
          end

          # Peças
          linhas << "   Peças:"
          dados[:pecas].each do |p|
            linhas << "     - #{p[:nome]} (#{p[:quantidade]}x): #{p[:metros].round(2)} m"
          end
        end

        linhas << "\n═══ TOTAL GERAL: #{total_metros.round(2)} metros ═══"
        linhas.join("\n")
      end

      # ═══════════════════════════════════════════════
      # LISTA DE COMPRAS (agrupado por material + espessura)
      # ═══════════════════════════════════════════════
      def self.lista_compras
        rel = relatorio_projeto
        itens = []

        rel.each do |mat, dados|
          dados[:por_espessura].each do |esp, metros|
            # Rolos comerciais: 50m ou 100m
            rolos_50  = (metros / 50.0).ceil
            rolos_100 = (metros / 100.0).ceil

            itens << {
              material: mat,
              espessura: esp,
              metros: metros.round(2),
              rolos_50m: rolos_50,
              rolos_100m: rolos_100,
              sobra_50m: ((rolos_50 * 50) - metros).round(2),
              sobra_100m: ((rolos_100 * 100) - metros).round(2)
            }
          end
        end

        itens
      end

      # ═══════════════════════════════════════════════
      # HELPERS PRIVADOS
      # ═══════════════════════════════════════════════
      private

      def self.espessura_mm(tipo_fita)
        return 0 unless tipo_fita
        return 0 if tipo_fita == false

        case tipo_fita
        when :melamine then 0.4
        when :padrao   then 1.0
        when :premium  then 2.0
        when :pesada   then 3.0
        when Numeric   then tipo_fita
        else 0
        end
      end
    end
  end
end
