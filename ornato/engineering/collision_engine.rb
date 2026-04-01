# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/collision_engine.rb — Motor de deteccao de colisao e geracao de usinagem
#
# Detecta contatos entre pecas de um modulo e gera automaticamente:
#   - Furacoes de fixacao (minifix, cavilha, confirmat)
#   - Furacoes de dobradica (copa + base)
#   - Rasgos para fundos
#   - Furacoes System32
#
# Algoritmo:
#   1. Expandir BoundingBox de cada peca em epsilon (0.5mm)
#   2. Testar interseccao entre todos os pares
#   3. Classificar tipo de contato (face-a-face, topo-a-face, etc.)
#   4. Resolver hardware necessario (HardwareResolver)
#   5. Gerar operacoes CNC correspondentes
#
# Tipos de contato:
#   :face_face    — duas faces planas encostadas (lateral+lateral = raro, lateral+fundo)
#   :topo_face    — topo de uma peca encosta na face da outra (base na lateral)
#   :borda_face   — borda de uma peca encosta na face da outra (prateleira na lateral)
#   :sobreposto   — uma peca sobre a outra (porta na frente do corpo)
#   :encaixado    — uma peca dentro de rasgo da outra (fundo encaixado)
#
# Pares semanticos com regras de usinagem:
#   lateral + base/topo      → minifix ou confirmat
#   lateral + prateleira     → minifix + cavilha
#   lateral + fundo          → rasgo 6x10mm a 7mm da traseira
#   porta + lateral          → dobradica (copa O35 + base)
#   frente_gaveta + lateral  → corrediça (sem furacao automatica — ferragem externa)
#   lateral + divisoria      → minifix
#   prateleira + divisoria   → minifix + cavilha

module Ornato
  module Engineering
    class CollisionEngine

      # ================================================================
      # Resultado de contato entre duas pecas
      # ================================================================
      ContatoResult = Struct.new(
        :peca_a_id,          # String: ornato_id da peca A
        :peca_b_id,          # String: ornato_id da peca B
        :tipo_contato,       # Symbol: :face_face, :topo_face, :borda_face, :sobreposto, :encaixado
        :face_a,             # Symbol: qual face da peca A (:top, :bottom, :left, :right, :front, :back)
        :face_b,             # Symbol: qual face da peca B
        :area_contato_mm2,   # Float: area de sobreposicao em mm2
        :profundidade_mm,    # Float: profundidade de penetracao (overlap)
        :eixo_contato,       # Symbol: :x, :y, :z — eixo normal ao contato
        :ponto_medio,        # Hash: { x:, y:, z: } centro do contato
        :confianca,          # Float: 0.0 a 1.0
        keyword_init: true
      )

      # ================================================================
      # Operacao gerada a partir de um contato
      # ================================================================
      OperacaoGerada = Struct.new(
        :peca_id,            # String: ornato_id da peca alvo
        :tipo_operacao,      # Symbol: :furo_passante, :furo_cego, :rasgo, :rebaixo, :copa_dobradica
        :ferramenta,         # String: codigo da ferramenta (ex: 'BROCA_8', 'FRESA_35')
        :diametro_mm,        # Float
        :profundidade_mm,    # Float
        :x_mm,               # Float: posicao X relativa a peca
        :y_mm,               # Float: posicao Y relativa a peca
        :face,               # Symbol: :top, :bottom, :face_a, :face_b
        :descricao,          # String: descricao legivel
        :grupo_montagem,     # String: assembly_group (ex: 'LAT_ESQ-BAS')
        keyword_init: true
      )

      # ================================================================
      # Constantes de usinagem (em mm)
      # ================================================================

      # Epsilon para expansao de bounding box na deteccao de contato
      EPSILON = 0.5

      # ================================================================
      # Parametros de usinagem — lidos de GlobalConfig
      # ================================================================
      # Metodos de classe que retornam hashes com os parametros atuais.
      # Assim qualquer alteracao em GlobalConfig reflete automaticamente.

      def self.minifix_params
        cfg = GlobalConfig.get(:minifix)
        {
          diametro_furo_lateral: cfg[:diametro_furo_lateral] || 8.0,
          profundidade_lateral: cfg[:profundidade_lateral] || 34.0,
          diametro_bucha: cfg[:diametro_bucha] || 15.0,
          profundidade_bucha: cfg[:profundidade_bucha] || 13.0,
          setback_mm: cfg[:setback_frontal] || 37.0,
          espacamento_mm: cfg[:espac_preferencial] || 128.0,
          min_distancia_borda: cfg[:dist_borda] || 50.0,
        }
      end

      def self.cavilha_params
        cfg = GlobalConfig.get(:cavilha)
        {
          diametro: cfg[:diametro] || 8.0,
          profundidade_peca: cfg[:profundidade_peca] || 12.0,
          setback_mm: cfg[:setback_frontal] || 32.0,
          espacamento_mm: cfg[:espac_preferencial] || 128.0,
          min_distancia_borda: cfg[:dist_borda] || 50.0,
        }
      end

      def self.confirmat_params
        cfg = GlobalConfig.get(:confirmat)
        {
          diametro_passante: cfg[:diametro_passante] || 7.0,
          diametro_piloto: cfg[:diametro_piloto] || 5.0,
          profundidade_piloto: cfg[:profundidade_piloto] || 40.0,
          setback_mm: cfg[:setback_frontal] || 37.0,
          espacamento_mm: cfg[:espac_preferencial] || 128.0,
        }
      end

      def self.dobradica_params
        cfg = GlobalConfig.get(:dobradica)
        {
          diametro_copa: cfg[:diametro_copa],
          profundidade_copa: cfg[:profundidade_copa],
          setback_copa: cfg[:centro_copa],
          diametro_base: cfg[:diametro_base],
          profundidade_base: cfg[:profundidade_base],
          distancia_base: cfg[:distancia_base],
          margem_topo_mm: cfg[:setback_vertical_topo],
          margem_base_mm: cfg[:setback_vertical_base],
          max_espaco_entre: cfg[:max_espaco_entre],
        }
      end

      def self.rasgo_fundo_params
        cfg = GlobalConfig.get(:rasgo_fundo)
        {
          largura: cfg[:largura_fresa] || 6.0,
          profundidade: cfg[:profundidade] || 10.0,
          distancia_traseira: cfg[:distancia_traseira] || 7.0,
          tipo_padrao: :passante,
        }
      end

      # ================================================================
      # Interface publica
      # ================================================================

      def initialize
        @contatos = []
        @operacoes = []
      end

      # Detecta todos os contatos entre pecas de um modulo e gera operacoes.
      #
      # @param modulo [Domain::ModEntity] modulo com pecas
      # @return [Hash] { contatos: Array<ContatoResult>, operacoes: Array<OperacaoGerada> }
      def processar(modulo)
        @contatos.clear
        @operacoes.clear

        pecas = modulo.parts
        return { contatos: [], operacoes: [] } if pecas.length < 2

        # Fase 1: Detectar contatos
        detectar_contatos(pecas)

        # Fase 2: Gerar operacoes para cada contato
        @contatos.each do |contato|
          peca_a = pecas.find { |p| p.ornato_id == contato.peca_a_id }
          peca_b = pecas.find { |p| p.ornato_id == contato.peca_b_id }
          next unless peca_a && peca_b

          gerar_operacoes_contato(contato, peca_a, peca_b)
        end

        { contatos: @contatos.dup, operacoes: @operacoes.dup }
      end

      # Detecta contatos para pecas com bounding boxes fornecidos externamente.
      # Util quando pecas vem de geometria pura (ClassificadorAutomatico).
      #
      # @param pecas_com_bb [Array<Hash>] [{ peca:, bb_min:, bb_max:, tipo:, subtipo: }, ...]
      # @return [Hash] { contatos:, operacoes: }
      def processar_com_bounds(pecas_com_bb)
        @contatos.clear
        @operacoes.clear

        return { contatos: [], operacoes: [] } if pecas_com_bb.length < 2

        # Fase 1: Detectar contatos usando bounding boxes
        detectar_contatos_bb(pecas_com_bb)

        # Fase 2: Gerar operacoes
        @contatos.each do |contato|
          info_a = pecas_com_bb.find { |p| p[:peca].ornato_id == contato.peca_a_id }
          info_b = pecas_com_bb.find { |p| p[:peca].ornato_id == contato.peca_b_id }
          next unless info_a && info_b

          gerar_operacoes_contato(contato, info_a[:peca], info_b[:peca])
        end

        { contatos: @contatos.dup, operacoes: @operacoes.dup }
      end

      private

      # ================================================================
      # Deteccao de contatos
      # ================================================================

      def detectar_contatos(pecas)
        # Teste par-a-par com BoundingBox expandido
        pecas.combination(2).each do |peca_a, peca_b|
          contato = testar_contato(peca_a, peca_b)
          @contatos << contato if contato
        end
      end

      def detectar_contatos_bb(pecas_com_bb)
        pecas_com_bb.combination(2).each do |info_a, info_b|
          contato = testar_contato_bb(info_a, info_b)
          @contatos << contato if contato
        end
      end

      # Testa contato entre duas pecas usando seus bounding boxes.
      # Expande epsilon em cada direcao para pegar pecas encostadas.
      def testar_contato(peca_a, peca_b)
        # Calcular bounding boxes a partir das dimensoes e posicao das pecas
        # (Em uso real, as posicoes vem da geometria SketchUp)
        bb_a = calcular_bb(peca_a)
        bb_b = calcular_bb(peca_b)

        return nil unless bb_a && bb_b
        testar_interseccao(peca_a.ornato_id, peca_b.ornato_id, bb_a, bb_b,
                           peca_a.part_type, peca_b.part_type)
      end

      def testar_contato_bb(info_a, info_b)
        bb_a = { min: info_a[:bb_min], max: info_a[:bb_max] }
        bb_b = { min: info_b[:bb_min], max: info_b[:bb_max] }

        testar_interseccao(info_a[:peca].ornato_id, info_b[:peca].ornato_id,
                           bb_a, bb_b, info_a[:tipo], info_b[:tipo])
      end

      def testar_interseccao(id_a, id_b, bb_a, bb_b, tipo_a, tipo_b)
        # Expandir por epsilon
        a_min = { x: bb_a[:min][:x] - EPSILON, y: bb_a[:min][:y] - EPSILON, z: bb_a[:min][:z] - EPSILON }
        a_max = { x: bb_a[:max][:x] + EPSILON, y: bb_a[:max][:y] + EPSILON, z: bb_a[:max][:z] + EPSILON }
        b_min = { x: bb_b[:min][:x] - EPSILON, y: bb_b[:min][:y] - EPSILON, z: bb_b[:min][:z] - EPSILON }
        b_max = { x: bb_b[:max][:x] + EPSILON, y: bb_b[:max][:y] + EPSILON, z: bb_b[:max][:z] + EPSILON }

        # Teste AABB (Axis-Aligned Bounding Box)
        overlap_x = [0, [a_max[:x], b_max[:x]].min - [a_min[:x], b_min[:x]].max].max
        overlap_y = [0, [a_max[:y], b_max[:y]].min - [a_min[:y], b_min[:y]].max].max
        overlap_z = [0, [a_max[:z], b_max[:z]].min - [a_min[:z], b_min[:z]].max].max

        # Sem interseccao
        return nil if overlap_x <= 0 || overlap_y <= 0 || overlap_z <= 0

        # Classificar tipo de contato pelo eixo de menor overlap
        eixo_contato, profundidade = classificar_eixo_contato(overlap_x, overlap_y, overlap_z)
        tipo_contato = classificar_tipo_contato(eixo_contato, profundidade, tipo_a, tipo_b)

        # Calcular ponto medio do contato
        inter_min = {
          x: [a_min[:x], b_min[:x]].max,
          y: [a_min[:y], b_min[:y]].max,
          z: [a_min[:z], b_min[:z]].max
        }
        inter_max = {
          x: [a_max[:x], b_max[:x]].min,
          y: [a_max[:y], b_max[:y]].min,
          z: [a_max[:z], b_max[:z]].min
        }
        ponto_medio = {
          x: (inter_min[:x] + inter_max[:x]) / 2.0,
          y: (inter_min[:y] + inter_max[:y]) / 2.0,
          z: (inter_min[:z] + inter_max[:z]) / 2.0
        }

        # Area de contato (nos 2 eixos que NAO sao o eixo de contato)
        area = case eixo_contato
               when :x then overlap_y * overlap_z
               when :y then overlap_x * overlap_z
               when :z then overlap_x * overlap_y
               end

        ContatoResult.new(
          peca_a_id: id_a,
          peca_b_id: id_b,
          tipo_contato: tipo_contato,
          face_a: face_do_contato(eixo_contato, bb_a, bb_b, :a),
          face_b: face_do_contato(eixo_contato, bb_a, bb_b, :b),
          area_contato_mm2: area.round(1),
          profundidade_mm: profundidade.round(2),
          eixo_contato: eixo_contato,
          ponto_medio: ponto_medio,
          confianca: profundidade <= (EPSILON * 4) ? 0.9 : 0.6
        )
      end

      def classificar_eixo_contato(ox, oy, oz)
        min_val = [ox, oy, oz].min
        if min_val == ox
          [:x, ox]
        elsif min_val == oy
          [:y, oy]
        else
          [:z, oz]
        end
      end

      def classificar_tipo_contato(eixo, profundidade, tipo_a, tipo_b)
        # Se profundidade e muito pequena (< 2mm) = face-a-face (encostado)
        # Se profundidade e media (2-20mm) = topo-a-face ou borda-a-face
        # Se profundidade e grande (> 20mm) = encaixado

        if profundidade <= 2.0
          # Pecas encostadas
          if porta_ou_frente?(tipo_a) || porta_ou_frente?(tipo_b)
            :sobreposto
          else
            :face_face
          end
        elsif profundidade <= 20.0
          :topo_face
        else
          :encaixado
        end
      end

      def face_do_contato(eixo, bb_a, bb_b, lado)
        # Determinar qual face da peca esta em contato
        case eixo
        when :x
          if lado == :a
            bb_a[:max][:x] <= bb_b[:max][:x] ? :right : :left
          else
            bb_b[:max][:x] <= bb_a[:max][:x] ? :right : :left
          end
        when :y
          if lado == :a
            bb_a[:max][:y] <= bb_b[:max][:y] ? :front : :back
          else
            bb_b[:max][:y] <= bb_a[:max][:y] ? :front : :back
          end
        when :z
          if lado == :a
            bb_a[:max][:z] <= bb_b[:max][:z] ? :top : :bottom
          else
            bb_b[:max][:z] <= bb_a[:max][:z] ? :top : :bottom
          end
        end
      end

      def porta_ou_frente?(tipo)
        [:porta, :front, :frente_gaveta, :drawer].include?(tipo)
      end

      # ================================================================
      # Geracao de operacoes CNC
      # ================================================================

      def gerar_operacoes_contato(contato, peca_a, peca_b)
        par = par_semantico(peca_a.part_type, peca_b.part_type)

        case par
        when :lateral_base, :lateral_topo
          gerar_minifix_lateral_horizontal(contato, peca_a, peca_b)
        when :lateral_prateleira
          gerar_minifix_e_cavilha(contato, peca_a, peca_b)
        when :lateral_fundo
          gerar_rasgo_fundo(contato, peca_a, peca_b)
        when :porta_lateral
          gerar_dobradica(contato, peca_a, peca_b)
        when :lateral_divisoria
          gerar_minifix_lateral_horizontal(contato, peca_a, peca_b)
        when :prateleira_divisoria
          gerar_minifix_e_cavilha(contato, peca_a, peca_b)
        when :frente_gaveta_lateral
          # Gaveta: sem furacao automatica — corrediça e ferragem externa
          # que nao gera furos CNC na peca
          nil
        else
          # Par sem regra de usinagem automatica
          nil
        end
      end

      # Identifica o par semantico independente da ordem A/B.
      def par_semantico(tipo_a, tipo_b)
        # Normalizar tipos para o sistema de classificacao
        na = normalizar_tipo(tipo_a)
        nb = normalizar_tipo(tipo_b)

        pares = [na, nb].sort
        key = pares.join('_').to_sym

        # Mapear para pares conhecidos
        PARES_CONHECIDOS[key]
      end

      PARES_CONHECIDOS = {
        base_lateral:             :lateral_base,
        lateral_topo:             :lateral_topo,
        lateral_prateleira:       :lateral_prateleira,
        fundo_lateral:            :lateral_fundo,
        lateral_porta:            :porta_lateral,
        frente_gaveta_lateral:    :frente_gaveta_lateral,  # gaveta: sem furacao automatica (corredica externa)
        divisoria_lateral:        :lateral_divisoria,
        divisoria_prateleira:     :prateleira_divisoria,
        base_divisoria:           :lateral_base,  # divisoria funciona como lateral para base
        divisoria_topo:           :lateral_topo,
        divisoria_fundo:          :lateral_fundo,
        divisoria_divisoria:      nil,  # sem usinagem automatica
        lateral_lateral:          nil,
        lateral_travessa:         :lateral_base,  # travessa fixada como base
      }.freeze

      def normalizar_tipo(tipo)
        case tipo
        when :structural then 'lateral'  # fallback
        when :front, :porta then 'porta'
        when :drawer, :frente_gaveta then 'frente_gaveta'
        when :back, :fundo then 'fundo'
        when :shelf, :prateleira then 'prateleira'
        when :divider, :divisoria then 'divisoria'
        when :lateral then 'lateral'
        when :base then 'base'
        when :topo then 'topo'
        when :tampo then 'topo'
        when :travessa then 'travessa'
        else tipo.to_s
        end
      end

      # ── Minifix (lateral + base/topo) ─────────────────────────────

      def gerar_minifix_lateral_horizontal(contato, peca_a, peca_b)
        lateral, horizontal = ordenar_par(peca_a, peca_b, [:lateral, :structural, :divisoria, :divider])
        return unless lateral && horizontal

        mf = self.class.minifix_params
        grupo = "#{lateral.code}-#{horizontal.code}"
        comprimento_h = horizontal.cut_length

        posicoes = calcular_posicoes_fixacao(
          comprimento_h, mf[:setback_mm], mf[:espacamento_mm], mf[:min_distancia_borda]
        )

        posicoes.each_with_index do |pos_x, i|
          @operacoes << OperacaoGerada.new(
            peca_id: lateral.ornato_id,
            tipo_operacao: :furo_cego,
            ferramenta: 'BROCA_8',
            diametro_mm: mf[:diametro_furo_lateral],
            profundidade_mm: mf[:profundidade_lateral],
            x_mm: pos_x, y_mm: mf[:setback_mm],
            face: contato.face_a == :top ? :top : :bottom,
            descricao: "Minifix lateral #{i + 1}/#{posicoes.length}",
            grupo_montagem: grupo
          )

          @operacoes << OperacaoGerada.new(
            peca_id: horizontal.ornato_id,
            tipo_operacao: :furo_cego,
            ferramenta: 'BROCA_15',
            diametro_mm: mf[:diametro_bucha],
            profundidade_mm: mf[:profundidade_bucha],
            x_mm: pos_x, y_mm: mf[:setback_mm],
            face: :face_a,
            descricao: "Bucha minifix #{i + 1}/#{posicoes.length}",
            grupo_montagem: grupo
          )
        end
      end

      # ── Minifix + Cavilha (lateral + prateleira) ──────────────────

      def gerar_minifix_e_cavilha(contato, peca_a, peca_b)
        lateral, prateleira = ordenar_par(peca_a, peca_b, [:lateral, :structural, :divisoria, :divider])
        return unless lateral && prateleira

        mf = self.class.minifix_params
        cv = self.class.cavilha_params
        grupo = "#{lateral.code}-#{prateleira.code}"
        comprimento_p = prateleira.cut_length

        posicoes_minifix = calcular_posicoes_fixacao(
          comprimento_p, mf[:setback_mm], mf[:espacamento_mm], mf[:min_distancia_borda]
        )

        posicoes_minifix.each_with_index do |pos_x, i|
          @operacoes << OperacaoGerada.new(
            peca_id: lateral.ornato_id,
            tipo_operacao: :furo_cego, ferramenta: 'BROCA_8',
            diametro_mm: mf[:diametro_furo_lateral],
            profundidade_mm: mf[:profundidade_lateral],
            x_mm: pos_x, y_mm: mf[:setback_mm],
            face: :face_a,
            descricao: "Minifix lat-prat #{i + 1}",
            grupo_montagem: grupo
          )

          @operacoes << OperacaoGerada.new(
            peca_id: prateleira.ornato_id,
            tipo_operacao: :furo_cego, ferramenta: 'BROCA_15',
            diametro_mm: mf[:diametro_bucha],
            profundidade_mm: mf[:profundidade_bucha],
            x_mm: pos_x, y_mm: mf[:setback_mm],
            face: :face_a,
            descricao: "Bucha minifix prat #{i + 1}",
            grupo_montagem: grupo
          )
        end

        posicoes_cavilha = calcular_posicoes_cavilha(
          comprimento_p, cv[:setback_mm], cv[:espacamento_mm], cv[:min_distancia_borda]
        )

        posicoes_cavilha.each_with_index do |pos_x, i|
          @operacoes << OperacaoGerada.new(
            peca_id: lateral.ornato_id,
            tipo_operacao: :furo_cego, ferramenta: 'BROCA_8',
            diametro_mm: cv[:diametro],
            profundidade_mm: cv[:profundidade_peca],
            x_mm: pos_x, y_mm: cv[:setback_mm],
            face: :face_a,
            descricao: "Cavilha lat #{i + 1}",
            grupo_montagem: grupo
          )

          @operacoes << OperacaoGerada.new(
            peca_id: prateleira.ornato_id,
            tipo_operacao: :furo_cego, ferramenta: 'BROCA_8',
            diametro_mm: cv[:diametro],
            profundidade_mm: cv[:profundidade_peca],
            x_mm: pos_x, y_mm: cv[:setback_mm],
            face: :face_b,
            descricao: "Cavilha prat #{i + 1}",
            grupo_montagem: grupo
          )
        end
      end

      # ── Rasgo para fundo ──────────────────────────────────────────

      def gerar_rasgo_fundo(contato, peca_a, peca_b)
        lateral, fundo = ordenar_par(peca_a, peca_b, [:lateral, :structural, :divisoria, :divider])
        return unless lateral && fundo

        grupo = "#{lateral.code}-#{fundo.code}"
        comprimento_l = lateral.cut_length

        # Rasgo na lateral para encaixar o fundo
        # Passante nas laterais (entra pela borda, sai pela outra)
        rf = self.class.rasgo_fundo_params
        @operacoes << OperacaoGerada.new(
          peca_id: lateral.ornato_id,
          tipo_operacao: :rasgo,
          ferramenta: "FRESA_#{rf[:largura].to_i}",
          diametro_mm: rf[:largura],
          profundidade_mm: rf[:profundidade],
          x_mm: rf[:distancia_traseira],
          y_mm: 0,
          face: :face_a,
          descricao: "Rasgo fundo #{rf[:largura]}x#{rf[:profundidade]}mm passante",
          grupo_montagem: grupo
        )
      end

      # ── Dobradica (porta + lateral) ───────────────────────────────

      def gerar_dobradica(contato, peca_a, peca_b)
        lateral = [peca_a, peca_b].find { |p| tipo_lateral?(p.part_type) }
        porta = [peca_a, peca_b].find { |p| porta_ou_frente?(p.part_type) }
        return unless lateral && porta

        db = self.class.dobradica_params
        grupo = "#{porta.code}-#{lateral.code}"
        altura_porta = porta.cut_length

        posicoes = calcular_posicoes_dobradica(altura_porta)

        posicoes.each_with_index do |pos_y, i|
          @operacoes << OperacaoGerada.new(
            peca_id: porta.ornato_id,
            tipo_operacao: :copa_dobradica,
            ferramenta: "FRESA_#{db[:diametro_copa].to_i}",
            diametro_mm: db[:diametro_copa],
            profundidade_mm: db[:profundidade_copa],
            x_mm: db[:setback_copa],
            y_mm: pos_y,
            face: :face_b,
            descricao: "Copa dobradica #{i + 1}/#{posicoes.length}",
            grupo_montagem: grupo
          )

          [-db[:distancia_base] / 2.0, db[:distancia_base] / 2.0].each_with_index do |offset, j|
            @operacoes << OperacaoGerada.new(
              peca_id: lateral.ornato_id,
              tipo_operacao: :furo_cego,
              ferramenta: "BROCA_#{db[:diametro_base].to_i}",
              diametro_mm: db[:diametro_base],
              profundidade_mm: db[:profundidade_base],
              x_mm: pos_y + offset,
              y_mm: db[:setback_copa],
              face: :face_a,
              descricao: "Base dobradica #{i + 1} furo #{j + 1}",
              grupo_montagem: grupo
            )
          end
        end
      end

      # ================================================================
      # Helpers de posicionamento
      # ================================================================

      # Calcula posicoes de fixacao (minifix/confirmat) ao longo de um comprimento.
      def calcular_posicoes_fixacao(comprimento, setback, espacamento, margem_borda)
        posicoes = []
        return [comprimento / 2.0] if comprimento < margem_borda * 3

        # Primeira e ultima posicao
        pos_ini = margem_borda
        pos_fim = comprimento - margem_borda

        if (pos_fim - pos_ini) < espacamento
          # So cabe 2 furos
          posicoes = [pos_ini, pos_fim]
        else
          # Calcular intermediarios a cada espacamento
          pos = pos_ini
          while pos <= pos_fim
            posicoes << pos
            pos += espacamento
          end
          # Garantir que o ultimo esta perto do fim
          posicoes[-1] = pos_fim if (pos_fim - posicoes.last) > 30
          posicoes << pos_fim unless posicoes.last >= (pos_fim - 5)
        end

        posicoes.uniq.sort
      end

      # Calcula posicoes de cavilha (System 32) — complementar aos minifix.
      def calcular_posicoes_cavilha(comprimento, setback, espacamento, margem_borda)
        # Cavilhas ficam entre os minifix, a cada 128mm (4 x System32)
        todas = []
        pos = margem_borda + espacamento / 2.0
        while pos < (comprimento - margem_borda)
          todas << pos
          pos += espacamento
        end
        todas
      end

      # Calcula posicoes de dobradicas baseado na altura da porta.
      # Delega para GlobalConfig (regras editaveis de quantidade).
      def calcular_posicoes_dobradica(altura)
        db = self.class.dobradica_params

        # Guard clause: GlobalConfig pode nao estar carregado
        qty = if defined?(GlobalConfig) && GlobalConfig.respond_to?(:quantidade_dobradicas)
                GlobalConfig.quantidade_dobradicas(altura)
              else
                # Regra padrao: 2 dobradicas ate 1200mm, 3 ate 1800mm, 4 acima
                altura <= 1200 ? 2 : (altura <= 1800 ? 3 : 4)
              end

        margem_topo = db[:margem_topo_mm] || 100.0
        margem_base = db[:margem_base_mm] || 100.0

        # Portas muito baixas (< 250mm): apenas 2 dobradicas com margens reduzidas
        if altura < 250
          margem_min = [altura * 0.15, 50.0].max
          return [margem_min, altura - margem_min]
        end

        if qty <= 2
          [margem_base, altura - margem_topo]
        else
          posicoes = [margem_base, altura - margem_topo]
          espaco_util = altura - margem_base - margem_topo
          intermediarias = qty - 2
          step = espaco_util / (intermediarias + 1).to_f
          intermediarias.times { |i| posicoes << margem_base + step * (i + 1) }
          posicoes.sort
        end
      end

      def ordenar_par(peca_a, peca_b, tipos_primeiro)
        primeiro = [peca_a, peca_b].find { |p| tipos_primeiro.include?(p.part_type) }
        segundo = [peca_a, peca_b].find { |p| p != primeiro }
        [primeiro, segundo]
      end

      def tipo_lateral?(tipo)
        [:lateral, :structural, :divisoria, :divider].include?(tipo)
      end

      def calcular_bb(peca)
        # Tentar obter BoundingBox da geometria SketchUp (entity.bounds)
        # IMPORTANTE: entity.bounds retorna coordenadas locais — precisamos
        # aplicar a transformação da instância para obter coordenadas do módulo.
        entity = peca.respond_to?(:entity) ? peca.entity : nil
        if entity && entity.respond_to?(:bounds)
          bb = entity.bounds
          unless bb.empty?
            # Se a entidade tem transformação (instância dentro do módulo),
            # aplicar para obter posição real relativa ao módulo pai
            if entity.respond_to?(:transformation)
              tr = entity.transformation
              # Transformar os 8 vértices do BB e recalcular
              corners = [
                Geom::Point3d.new(bb.min.x, bb.min.y, bb.min.z),
                Geom::Point3d.new(bb.max.x, bb.min.y, bb.min.z),
                Geom::Point3d.new(bb.min.x, bb.max.y, bb.min.z),
                Geom::Point3d.new(bb.max.x, bb.max.y, bb.min.z),
                Geom::Point3d.new(bb.min.x, bb.min.y, bb.max.z),
                Geom::Point3d.new(bb.max.x, bb.min.y, bb.max.z),
                Geom::Point3d.new(bb.min.x, bb.max.y, bb.max.z),
                Geom::Point3d.new(bb.max.x, bb.max.y, bb.max.z)
              ].map { |pt| tr * pt }

              xs = corners.map(&:x)
              ys = corners.map(&:y)
              zs = corners.map(&:z)
              return {
                min: { x: xs.min.to_mm, y: ys.min.to_mm, z: zs.min.to_mm },
                max: { x: xs.max.to_mm, y: ys.max.to_mm, z: zs.max.to_mm }
              }
            else
              return {
                min: { x: bb.min.x.to_mm, y: bb.min.y.to_mm, z: bb.min.z.to_mm },
                max: { x: bb.max.x.to_mm, y: bb.max.y.to_mm, z: bb.max.z.to_mm }
              }
            end
          end
        end

        # Fallback: construir BB a partir de dimensoes e posicao conhecidas
        if peca.respond_to?(:position) && peca.respond_to?(:cut_length) && peca.respond_to?(:cut_width)
          pos = peca.position || { x: 0, y: 0, z: 0 }
          comp = peca.cut_length || 0
          larg = peca.cut_width || 0
          esp = peca.respond_to?(:thickness_real) ? (peca.thickness_real || 0) : 0

          # Ordenar: maior = comprimento, menor = espessura
          dims = [comp, larg, esp].sort.reverse
          return {
            min: { x: pos[:x], y: pos[:y], z: pos[:z] },
            max: { x: pos[:x] + dims[0], y: pos[:y] + dims[1], z: pos[:z] + dims[2] }
          }
        end

        nil
      end
    end
  end
end
