# ornato_plugin/models/modulo_info.rb — Metadata completo de um módulo

module Ornato
  module Models
    class ModuloInfo
      attr_accessor :id, :nome, :tipo, :ambiente,
                    :largura, :altura, :profundidade,
                    :espessura_corpo, :espessura_fundo,
                    :tipo_fundo, :rebaixo_fundo,
                    :montagem, :tipo_base,
                    :altura_rodape, :recuo_rodape,
                    :fixacao,
                    :material_corpo, :material_frente, :material_fundo,
                    :fita_corpo, :fita_frente,
                    :vao_principal, :pecas, :ferragens,
                    :grupo_ref

      def initialize(opts = {})
        @id                = opts[:id] || Utils.gerar_id
        @nome              = opts[:nome] || 'Módulo'
        @tipo              = opts[:tipo] || :inferior
        @ambiente          = opts[:ambiente] || 'Geral'

        # Dimensões externas (mm)
        @largura           = opts[:largura] || 600
        @altura            = opts[:altura] || 700
        @profundidade      = opts[:profundidade] || 560

        # Estrutura (espessura_corpo é o valor NOMINAL — usar espessura_corpo_real para cálculos)
        @espessura_corpo   = opts[:espessura_corpo] || Config::ESPESSURA_CORPO_PADRAO
        @espessura_fundo   = opts[:espessura_fundo] || Config::ESPESSURA_FUNDO_PADRAO
        @tipo_fundo        = opts[:tipo_fundo] || Config::FUNDO_REBAIXADO
        @rebaixo_fundo     = opts[:rebaixo_fundo] || Config::REBAIXO_FUNDO_PADRAO
        @montagem          = opts[:montagem] || Config::MONTAGEM_BRASIL
        @tipo_base         = opts[:tipo_base] || Config::BASE_PES
        @altura_rodape     = opts[:altura_rodape] || Config::ALTURA_RODAPE_PADRAO
        @recuo_rodape      = opts[:recuo_rodape] || Config::RECUO_RODAPE_PADRAO
        @fixacao           = opts[:fixacao] || Config::FIXACAO_MINIFIX

        # Materiais
        @material_corpo    = opts[:material_corpo] || 'MDF Branco 15mm'
        @material_frente   = opts[:material_frente] || 'MDF Carvalho 15mm'
        @material_fundo    = opts[:material_fundo] || 'HDF Branco 3mm'

        # Fita de borda
        @fita_corpo        = opts[:fita_corpo] || 'PVC 1mm Branco'
        @fita_frente       = opts[:fita_frente] || 'ABS 2mm Carvalho'

        # Dados gerados
        @vao_principal     = nil  # Vao raiz (preenchido após construção)
        @pecas             = []   # Lista de Peca
        @ferragens         = []   # Lista de ferragens { nome:, qtd:, tipo: }
        @grupo_ref         = nil  # Referência ao Group do SketchUp
      end

      # ─── Espessura REAL do corpo (considera imperfeição do MDF) ───
      # MDF 15mm → real 15.5mm, 18mm → 18.5mm, 25mm → 25.5mm
      # Engrossado (2×15) → 31mm
      def espessura_corpo_real
        Config.espessura_real(@espessura_corpo)
      end

      def espessura_fundo_real
        Config.espessura_real(@espessura_fundo)
      end

      # Espessura para engrossado (duas chapas coladas)
      def espessura_engrossado
        Config::ESPESSURA_ENGROSSADO
      end

      # Dimensões internas calculadas (usando espessura REAL)
      def largura_interna
        esp = espessura_corpo_real
        case @montagem
        when Config::MONTAGEM_BRASIL
          @largura - (2 * esp)
        when Config::MONTAGEM_EUROPA
          @largura
        end
      end

      def altura_interna
        esp = espessura_corpo_real
        case @montagem
        when Config::MONTAGEM_BRASIL
          @altura
        when Config::MONTAGEM_EUROPA
          @altura - (2 * esp)
        end
      end

      def profundidade_interna
        if @tipo_fundo == Config::FUNDO_REBAIXADO
          @profundidade - @rebaixo_fundo
        else
          @profundidade
        end
      end

      # Altura útil (descontando rodapé para módulos inferiores)
      def altura_util
        case @tipo
        when :inferior, :gaveteiro
          if @tipo_base == Config::BASE_RODAPE || @tipo_base == Config::BASE_PES
            @altura - @altura_rodape
          else
            @altura
          end
        else
          @altura
        end
      end

      # Salva os atributos no grupo SketchUp
      def salvar_no_grupo(grupo)
        @grupo_ref = grupo
        dict = Config::DICT_MODULO
        attrs = {
          'id' => @id, 'nome' => @nome, 'tipo' => @tipo.to_s,
          'ambiente' => @ambiente,
          'largura' => @largura, 'altura' => @altura, 'profundidade' => @profundidade,
          'espessura_corpo' => @espessura_corpo, 'espessura_fundo' => @espessura_fundo,
          'tipo_fundo' => @tipo_fundo.to_s, 'rebaixo_fundo' => @rebaixo_fundo,
          'montagem' => @montagem.to_s, 'tipo_base' => @tipo_base.to_s,
          'altura_rodape' => @altura_rodape, 'recuo_rodape' => @recuo_rodape,
          'fixacao' => @fixacao.to_s,
          'material_corpo' => @material_corpo, 'material_frente' => @material_frente,
          'material_fundo' => @material_fundo,
          'fita_corpo' => @fita_corpo, 'fita_frente' => @fita_frente
        }
        attrs.each { |k, v| grupo.set_attribute(dict, k, v) }
      end

      # Carrega atributos de um grupo SketchUp existente
      def self.carregar_do_grupo(grupo)
        dict = Config::DICT_MODULO
        return nil unless grupo.get_attribute(dict, 'id')

        info = new(
          id:                grupo.get_attribute(dict, 'id'),
          nome:              grupo.get_attribute(dict, 'nome'),
          tipo:              grupo.get_attribute(dict, 'tipo')&.to_sym,
          ambiente:          grupo.get_attribute(dict, 'ambiente'),
          largura:           grupo.get_attribute(dict, 'largura'),
          altura:            grupo.get_attribute(dict, 'altura'),
          profundidade:      grupo.get_attribute(dict, 'profundidade'),
          espessura_corpo:   grupo.get_attribute(dict, 'espessura_corpo'),
          espessura_fundo:   grupo.get_attribute(dict, 'espessura_fundo'),
          tipo_fundo:        grupo.get_attribute(dict, 'tipo_fundo')&.to_sym,
          rebaixo_fundo:     grupo.get_attribute(dict, 'rebaixo_fundo'),
          montagem:          grupo.get_attribute(dict, 'montagem')&.to_sym,
          tipo_base:         grupo.get_attribute(dict, 'tipo_base')&.to_sym,
          altura_rodape:     grupo.get_attribute(dict, 'altura_rodape'),
          recuo_rodape:      grupo.get_attribute(dict, 'recuo_rodape'),
          fixacao:           grupo.get_attribute(dict, 'fixacao')&.to_sym,
          material_corpo:    grupo.get_attribute(dict, 'material_corpo'),
          material_frente:   grupo.get_attribute(dict, 'material_frente'),
          material_fundo:    grupo.get_attribute(dict, 'material_fundo'),
          fita_corpo:        grupo.get_attribute(dict, 'fita_corpo'),
          fita_frente:       grupo.get_attribute(dict, 'fita_frente')
        )
        info.grupo_ref = grupo
        info
      end

      def to_hash
        {
          id: @id, nome: @nome, tipo: @tipo, ambiente: @ambiente,
          largura: @largura, altura: @altura, profundidade: @profundidade,
          espessura_corpo: @espessura_corpo,
          espessura_corpo_real: espessura_corpo_real,
          largura_interna: largura_interna,
          altura_interna: altura_interna,
          profundidade_interna: profundidade_interna,
          material_corpo: @material_corpo, material_frente: @material_frente,
          pecas: @pecas.map(&:to_hash),
          ferragens: @ferragens
        }
      end
    end
  end
end
