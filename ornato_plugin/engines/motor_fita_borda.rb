# ornato_plugin/engines/motor_fita_borda.rb — Motor de fita de borda inteligente

module Ornato
  module Engines
    class MotorFitaBorda

      # Regras automáticas de fita de borda por tipo de peça
      # Retorna hash { frente: bool, topo: bool, tras: bool, base: bool }
      REGRAS = {
        # Carcaça
        lateral:        { frente: true,  topo: false, tras: false, base: false },
        base:           { frente: true,  topo: false, tras: false, base: false },
        topo:           { frente: true,  topo: false, tras: false, base: false },
        fundo:          { frente: false, topo: false, tras: false, base: false },

        # Prateleira
        prateleira:     { frente: true,  topo: false, tras: false, base: false },

        # Divisória
        divisoria:      { frente: true,  topo: false, tras: false, base: false },

        # Porta (todas as bordas visíveis)
        porta:          { frente: true,  topo: true,  tras: true,  base: true  },

        # Gaveta
        frente_gaveta:  { frente: true,  topo: true,  tras: true,  base: true  },
        lateral_gaveta: { frente: false, topo: true,  tras: false, base: false },
        traseira_gaveta:{ frente: false, topo: true,  tras: false, base: false },
        fundo_gaveta:   { frente: false, topo: false, tras: false, base: false },

        # Peças especiais
        painel:         { frente: true,  topo: true,  tras: true,  base: true  },
        tampo:          { frente: true,  topo: false, tras: false, base: false },
        rodape:         { frente: true,  topo: true,  tras: false, base: false },
        requadro:       { frente: true,  topo: true,  tras: false, base: true  },
        moldura:        { frente: true,  topo: false, tras: false, base: false },

        # Painel cavilhado / ripado
        ripa:           { frente: true,  topo: true,  tras: true,  base: true  },
        montante:       { frente: true,  topo: true,  tras: true,  base: true  },

        # Genérica
        generica:       { frente: true,  topo: false, tras: false, base: false },
      }.freeze

      # Aplica regras automáticas de fita a uma peça
      def self.aplicar_regra(peca, material_corpo: nil, material_frente: nil)
        regra = REGRAS[peca.tipo] || REGRAS[:generica]

        peca.fita_frente = regra[:frente]
        peca.fita_topo   = regra[:topo]
        peca.fita_tras   = regra[:tras]
        peca.fita_base   = regra[:base]

        # Determina material da fita baseado no tipo da peça
        if [:porta, :frente_gaveta, :painel].include?(peca.tipo)
          peca.fita_material = material_frente || peca.fita_material
        else
          peca.fita_material = material_corpo || peca.fita_material
        end

        peca
      end

      # Aplica regras com override manual por aresta
      # overrides: { frente: true/false, topo: true/false, ... }
      def self.aplicar_com_override(peca, overrides = {})
        regra = REGRAS[peca.tipo] || REGRAS[:generica]

        peca.fita_frente = overrides.key?(:frente) ? overrides[:frente] : regra[:frente]
        peca.fita_topo   = overrides.key?(:topo)   ? overrides[:topo]   : regra[:topo]
        peca.fita_tras   = overrides.key?(:tras)    ? overrides[:tras]   : regra[:tras]
        peca.fita_base   = overrides.key?(:base)    ? overrides[:base]   : regra[:base]

        peca
      end

      # Recalcula fita baseado em adjacências (aresta encostada = sem fita)
      # adjacencias: { frente: false, topo: true, tras: true, base: true }
      #   true = aresta encostada em outra peça → sem fita
      #   false = aresta livre/visível → com fita (se regra permitir)
      def self.aplicar_com_adjacencia(peca, adjacencias = {})
        regra = REGRAS[peca.tipo] || REGRAS[:generica]

        peca.fita_frente = regra[:frente] && !adjacencias[:frente]
        peca.fita_topo   = regra[:topo]   && !adjacencias[:topo]
        peca.fita_tras   = regra[:tras]   && !adjacencias[:tras]
        peca.fita_base   = regra[:base]   && !adjacencias[:base]

        peca
      end

      # Gera relatório consolidado de fita para um módulo
      def self.relatorio(modulo_info)
        por_material = {}

        modulo_info.pecas.each do |peca|
          next if peca.fita_metros <= 0

          key = peca.fita_material
          por_material[key] ||= { metros: 0.0, pecas: [] }
          por_material[key][:metros] += peca.fita_metros
          por_material[key][:pecas] << {
            nome: peca.nome,
            metros: peca.fita_metros,
            codigo: peca.fita_codigo
          }
        end

        por_material
      end

      # Gera relatório para todo o projeto (todos os módulos)
      def self.relatorio_projeto
        modulos = Utils.listar_modulos
        total = {}

        modulos.each do |grupo|
          mi = Models::ModuloInfo.carregar_do_grupo(grupo)
          next unless mi

          rel = relatorio(mi)
          rel.each do |mat, dados|
            total[mat] ||= { metros: 0.0, pecas: [] }
            total[mat][:metros] += dados[:metros]
            total[mat][:pecas] += dados[:pecas]
          end
        end

        total
      end

      # Impacto da espessura da fita na dimensão final
      # A fita 2mm ABS adiciona 2mm na largura final da peça (1mm por lado)
      # Isso deve ser considerado no corte para que a peça final tenha a medida certa
      def self.ajuste_dimensao_fita(comprimento, largura, fita_info)
        esp = fita_info ? (fita_info[:espessura] || 0) : 0
        return [comprimento, largura] if esp <= 0.5  # PVC 0.4mm: sem ajuste

        # Para fitas >= 1mm: desconta a espessura da fita da dimensão de corte
        # A peça é cortada menor, depois a fita é colada e a dimensão final fica correta
        ajuste = esp >= 1.0 ? esp : 0
        [comprimento, largura]  # Na prática, a coladeira faz o ajuste; registramos para CNC
      end
    end
  end
end
