# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/classificador_automatico.rb — Motor de classificacao automatica
#
# Analisa geometria pura (grupos/componentes SketchUp sem atributos Ornato)
# e infere automaticamente:
#   - Tipo de peca (lateral, base, topo, fundo, prateleira, divisoria, porta, gaveta...)
#   - Material provavel
#   - Fita de borda (quais lados sao visiveis)
#   - Direcao do grao
#   - Espessura nominal/real
#   - Posicao semantica dentro do modulo (esquerda, direita, frontal, traseiro)
#
# Estrategia de classificacao em 4 camadas:
#   1. ESPESSURA — classifica por espessura (3mm=fundo, 15mm=porta, 18mm=corpo)
#   2. PROPORCAO — analisa ratio comprimento/largura/espessura
#   3. POSICAO   — analisa bounding box relativo ao modulo pai
#   4. CONTEXTO  — analisa vizinhanca (pecas adjacentes, simetrias)
#
# Uso:
#   classificador = Ornato::Engineering::ClassificadorAutomatico.new
#   resultado = classificador.classificar(grupo_sketchup, contexto_modulo)
#   # => ClassificacaoResult com tipo, material, bordas, confianca
#
# O classificador NAO modifica a geometria. Retorna sugestoes que o
# usuario pode aceitar ou corrigir via UI.

module Ornato
  module Engineering
    class ClassificadorAutomatico

      # ================================================================
      # Resultado da classificacao
      # ================================================================
      ClassificacaoResult = Struct.new(
        :tipo,               # Symbol: :lateral, :base, :topo, :fundo, :prateleira, :divisoria,
                             #         :porta, :frente_gaveta, :lateral_gaveta, :traseira_gaveta,
                             #         :fundo_gaveta, :tampo, :rodape, :travessa, :desconhecido
        :subtipo,            # Symbol, nil: :esquerda, :direita, :fixa, :regulavel, etc.
        :material_sugerido,  # String, nil: codigo do material sugerido
        :espessura_nominal,  # Float: espessura nominal em mm
        :espessura_real,     # Float: espessura real em mm
        :comprimento_mm,     # Float: maior dimensao
        :largura_mm,         # Float: menor dimensao (exceto espessura)
        :grao,               # Symbol: :length, :width, :none
        :bordas,             # Hash<Symbol, Boolean>: { top: true, bottom: false, left: true, right: false }
        :face_visivel,       # Symbol: :face_a, :face_b, :ambas, :nenhuma
        :confianca,          # Float: 0.0 a 1.0 — nivel de confianca da classificacao
        :regras_aplicadas,   # Array<String>: quais regras levaram a esta classificacao
        :posicao_relativa,   # Hash: { x: Float, y: Float, z: Float } posicao no modulo
        :orientacao,         # Symbol: :vertical, :horizontal, :profundidade
        keyword_init: true
      ) do
        def confiante?; confianca >= 0.7; end
        def incerto?; confianca < 0.5; end
      end

      # ================================================================
      # Contexto do modulo — informacoes sobre o modulo pai para
      # classificacao posicional
      # ================================================================
      ContextoModulo = Struct.new(
        :bounds_min,         # Geom::Point3d — canto inferior esquerdo traseiro
        :bounds_max,         # Geom::Point3d — canto superior direito frontal
        :largura_mm,         # Float — largura total do modulo (eixo X)
        :altura_mm,          # Float — altura total do modulo (eixo Z)
        :profundidade_mm,    # Float — profundidade total (eixo Y)
        :pecas_existentes,   # Array<ClassificacaoResult> — pecas ja classificadas
        :tipo_modulo,        # Symbol, nil: :inferior, :superior, :torre, :gaveteiro, :estante
        keyword_init: true
      )

      # ================================================================
      # Constantes de referencia
      # ================================================================

      # Espessuras nominais padrao do mercado (mm)
      # Espessuras padrão marcenaria brasileira (nominal → real)
      ESPESSURAS_CONHECIDAS = {
        3.0  => { real: 3.0,   uso: :fundo_fino },
        6.0  => { real: 6.0,   uso: :fundo_encaixado },
        9.0  => { real: 9.0,   uso: :fundo_medio },
        12.0 => { real: 12.5,  uso: :prateleira_fina },
        15.0 => { real: 15.5,  uso: :porta_fina },
        18.0 => { real: 18.5,  uso: :corpo },
        25.0 => { real: 25.5,  uso: :tampo },
        30.0 => { real: 31.0,  uso: :tampo_pesado },
        36.0 => { real: 37.0,  uso: :tampo_pesado },
      }.freeze

      # Tolerancia para snap de espessura (mm)
      TOLERANCIA_ESPESSURA = 1.0

      # Proporcoes tipicas (ratio maior/menor dimensao)
      PROPORCAO_LAMINAR = 3.0   # ratio > 3 = muito provavelmente painel plano
      PROPORCAO_QUADRADA = 1.5  # ratio < 1.5 = quase quadrado

      # Margens de posicao para classificacao espacial (mm)
      MARGEM_BORDA = 5.0    # proximidade ao extremo do modulo
      MARGEM_CENTRO = 50.0  # faixa central

      # ================================================================
      # Interface publica
      # ================================================================

      def initialize(catalogo_materiais: nil)
        @catalogo = catalogo_materiais || catalogo_padrao
        @log = []
      end

      # Classifica um unico grupo/componente SketchUp.
      #
      # @param entity [Sketchup::Group, Sketchup::ComponentInstance]
      # @param contexto [ContextoModulo, nil] contexto do modulo pai
      # @return [ClassificacaoResult]
      def classificar(entity, contexto = nil)
        @log.clear
        dims = extrair_dimensoes(entity)
        return resultado_desconhecido("Geometria sem dimensoes validas") unless dims

        espessura = identificar_espessura(dims)
        orientacao = identificar_orientacao(dims, espessura)
        tipo, subtipo, regras = inferir_tipo(dims, espessura, orientacao, contexto)
        bordas = inferir_bordas(tipo, subtipo, contexto)
        grao = inferir_grao(tipo, dims)
        face = inferir_face_visivel(tipo, subtipo, contexto)
        material = inferir_material(tipo, espessura)
        confianca = calcular_confianca(tipo, regras, contexto)

        # Dimensoes finais (comprimento = maior, largura = intermediaria)
        sorted = dims[:sorted_dims] # [maior, medio, menor]
        comprimento = sorted[0]
        largura = sorted[1]

        ClassificacaoResult.new(
          tipo: tipo,
          subtipo: subtipo,
          material_sugerido: material,
          espessura_nominal: espessura[:nominal],
          espessura_real: espessura[:real],
          comprimento_mm: comprimento,
          largura_mm: largura,
          grao: grao,
          bordas: bordas,
          face_visivel: face,
          confianca: confianca,
          regras_aplicadas: regras,
          posicao_relativa: dims[:posicao],
          orientacao: orientacao
        )
      end

      # Classifica todos os grupos/componentes filhos de um grupo pai (modulo).
      # Constroi contexto progressivamente — pecas ja classificadas ajudam
      # na classificacao das seguintes.
      #
      # @param grupo_modulo [Sketchup::Group, Sketchup::ComponentInstance]
      # @return [Array<Hash>] array de { entity:, resultado: ClassificacaoResult }
      def classificar_modulo(grupo_modulo)
        contexto = construir_contexto(grupo_modulo)
        resultados = []

        # Coletar todos os sub-grupos/componentes
        entities = coletar_entidades(grupo_modulo)

        # Ordenar por Z descendente (laterais primeiro), depois por volume descendente
        entities.sort_by! { |e| [-volume_bb(e), -pos_z(e)] }

        entities.each do |entity|
          resultado = classificar(entity, contexto)
          resultados << { entity: entity, resultado: resultado }
          # Alimentar contexto para proximas classificacoes
          contexto.pecas_existentes << resultado
        end

        # Segunda passada: refinar com contexto completo
        refinar_classificacoes(resultados, contexto)

        resultados
      end

      # Classifica uma lista de blocos importados (bibliotecas externas, etc.)
      # Cada bloco e analisado isoladamente (sem contexto de modulo).
      #
      # @param blocos [Array<Sketchup::Group|Sketchup::ComponentInstance>]
      # @return [Array<Hash>] array de { entity:, resultado: ClassificacaoResult }
      def classificar_biblioteca(blocos)
        blocos.map do |bloco|
          { entity: bloco, resultado: classificar(bloco) }
        end
      end

      # Log de debug das regras aplicadas na ultima classificacao.
      # @return [Array<String>]
      def log_classificacao
        @log.dup
      end

      private

      # ================================================================
      # CAMADA 1: Extracao de dimensoes
      # ================================================================

      # Extrai dimensoes de um grupo/componente SketchUp.
      # Retorna as 3 dimensoes em mm + posicao do centro.
      #
      # @param entity [Sketchup::Group, Sketchup::ComponentInstance]
      # @return [Hash, nil] { width:, height:, depth:, sorted_dims:, posicao: }
      def extrair_dimensoes(entity)
        bb = entity.bounds
        return nil if bb.empty?

        # Converter de polegadas (unidade interna SketchUp) para mm
        w = bb.width.to_mm.round(1)
        h = bb.height.to_mm.round(1)
        d = bb.depth.to_mm.round(1)

        return nil if w <= 0 || h <= 0 || d <= 0

        sorted = [w, h, d].sort.reverse # [maior, medio, menor]
        centro = bb.center

        @log << "Dimensoes: #{w} x #{h} x #{d} mm (sorted: #{sorted.join(' x ')})"

        {
          width: w,   # eixo X (largura SketchUp)
          height: h,  # eixo Z (altura SketchUp)
          depth: d,   # eixo Y (profundidade SketchUp)
          sorted_dims: sorted,
          posicao: {
            x: centro.x.to_mm.round(1),
            y: centro.y.to_mm.round(1),
            z: centro.z.to_mm.round(1)
          },
          bounds_min: {
            x: bb.min.x.to_mm.round(1),
            y: bb.min.y.to_mm.round(1),
            z: bb.min.z.to_mm.round(1)
          },
          bounds_max: {
            x: bb.max.x.to_mm.round(1),
            y: bb.max.y.to_mm.round(1),
            z: bb.max.z.to_mm.round(1)
          }
        }
      end

      # ================================================================
      # CAMADA 2: Identificacao de espessura
      # ================================================================

      # Identifica a espessura nominal a partir da menor dimensao.
      # Faz snap para a espessura comercial mais proxima.
      #
      # @param dims [Hash] resultado de extrair_dimensoes
      # @return [Hash] { nominal:, real:, uso:, dim_index: }
      def identificar_espessura(dims)
        menor = dims[:sorted_dims][2] # menor dimensao = provavel espessura

        # Tentar snap para espessura conhecida
        melhor_match = nil
        melhor_diff = Float::INFINITY

        ESPESSURAS_CONHECIDAS.each do |nominal, info|
          diff = (menor - nominal).abs
          if diff < melhor_diff
            melhor_diff = diff
            melhor_match = { nominal: nominal, real: info[:real], uso: info[:uso] }
          end
          # Tambem testar contra espessura real
          diff_real = (menor - info[:real]).abs
          if diff_real < melhor_diff
            melhor_diff = diff_real
            melhor_match = { nominal: nominal, real: info[:real], uso: info[:uso] }
          end
        end

        if melhor_diff <= TOLERANCIA_ESPESSURA
          @log << "Espessura snap: #{menor}mm -> #{melhor_match[:nominal]}mm (#{melhor_match[:uso]})"
          # Qual indice da sorted_dims e a espessura?
          melhor_match[:dim_index] = 2
          melhor_match
        else
          @log << "Espessura nao-padrao: #{menor}mm (sem snap)"
          { nominal: menor.round(1), real: menor.round(1), uso: :desconhecido, dim_index: 2 }
        end
      end

      # ================================================================
      # CAMADA 3: Orientacao espacial
      # ================================================================

      # Determina se a peca esta orientada vertical, horizontal ou em profundidade.
      # Baseado em qual eixo corresponde a espessura (menor dimensao).
      #
      # @param dims [Hash]
      # @param espessura [Hash]
      # @return [Symbol] :vertical, :horizontal, :profundidade
      def identificar_orientacao(dims, espessura)
        esp_mm = espessura[:real]
        w = dims[:width]   # X
        h = dims[:height]  # Z
        d = dims[:depth]   # Y

        # A espessura e o eixo com valor mais proximo da espessura
        diffs = { x: (w - esp_mm).abs, z: (h - esp_mm).abs, y: (d - esp_mm).abs }
        eixo_esp = diffs.min_by { |_, v| v }[0]

        orient = case eixo_esp
                 when :x then :profundidade  # espessura no X = painel lateral (normal ao X)
                 when :z then :horizontal    # espessura no Z = painel horizontal (base/topo/prateleira)
                 when :y then :vertical      # espessura no Y = painel vertical (fundo/porta)
                 end

        @log << "Orientacao: #{orient} (espessura no eixo #{eixo_esp})"
        orient
      end

      # ================================================================
      # CAMADA 4: Inferencia de tipo
      # ================================================================

      # Motor principal de classificacao. Aplica regras em cascata.
      #
      # @param dims [Hash]
      # @param espessura [Hash]
      # @param orientacao [Symbol]
      # @param contexto [ContextoModulo, nil]
      # @return [Array] [tipo, subtipo, regras_aplicadas]
      def inferir_tipo(dims, espessura, orientacao, contexto)
        regras = []

        # ── Regra 1: Fundo por espessura ────────────────────────────
        if espessura[:uso] == :fundo_encaixado || espessura[:uso] == :fundo_fino
          regras << "R1: espessura #{espessura[:nominal]}mm = fundo"
          subtipo = espessura[:uso] == :fundo_encaixado ? :encaixado : :sobreposto
          return [:fundo, subtipo, regras]
        end

        # ── Regra 2: Fundo medio (9mm) ──────────────────────────────
        if espessura[:uso] == :fundo_medio
          regras << "R2: espessura 9mm = fundo medio"
          return [:fundo, :sobreposto, regras]
        end

        # ── Regra 3: Tampo por espessura ────────────────────────────
        if espessura[:uso] == :tampo || espessura[:uso] == :tampo_pesado
          regras << "R3: espessura #{espessura[:nominal]}mm = tampo"
          return [:tampo, nil, regras]
        end

        # ── Regra 4: Corpo padrao (18mm) — classificar por posicao ──
        if espessura[:nominal] == 18.0
          regras << "R4: espessura 18mm = corpo"
          return classificar_peca_corpo(dims, orientacao, contexto, regras)
        end

        # ── Regra 5: Porta/frente (15mm) ────────────────────────────
        if espessura[:uso] == :porta_fina
          regras << "R5: espessura 15mm = porta/frente"
          return classificar_porta_frente(dims, orientacao, contexto, regras)
        end

        # ── Regra 6: Prateleira fina (12mm) ─────────────────────────
        if espessura[:uso] == :prateleira_fina
          regras << "R6: espessura 12mm = prateleira fina"
          return [:prateleira, :fixa, regras]
        end

        # ── Regra fallback ──────────────────────────────────────────
        regras << "FALLBACK: espessura #{espessura[:nominal]}mm sem regra especifica"
        classificar_por_proporcao(dims, orientacao, contexto, regras)
      end

      # Classifica pecas de corpo (18mm) pela posicao e orientacao.
      def classificar_peca_corpo(dims, orientacao, contexto, regras)
        sorted = dims[:sorted_dims]
        maior = sorted[0]
        medio = sorted[1]

        case orientacao
        when :profundidade
          # Espessura no eixo X = painel visto de frente
          # Se esta no extremo esquerdo ou direito do modulo = LATERAL
          if contexto
            pos_x = dims[:posicao][:x]
            mod_w = contexto.largura_mm
            if pos_x < (mod_w * 0.15)
              regras << "CORPO: vertical no eixo X, extremo esquerdo = lateral esquerda"
              return [:lateral, :esquerda, regras]
            elsif pos_x > (mod_w * 0.85)
              regras << "CORPO: vertical no eixo X, extremo direito = lateral direita"
              return [:lateral, :direita, regras]
            else
              regras << "CORPO: vertical no eixo X, centro = divisoria"
              return [:divisoria, nil, regras]
            end
          else
            # Sem contexto: alta e profunda = lateral
            if maior > 400 && medio > 200
              regras << "CORPO: vertical, grande = lateral (sem contexto)"
              return [:lateral, nil, regras]
            else
              regras << "CORPO: vertical, pequena = divisoria (sem contexto)"
              return [:divisoria, nil, regras]
            end
          end

        when :horizontal
          # Espessura no eixo Z = painel horizontal
          if contexto
            pos_z = dims[:posicao][:z]
            mod_h = contexto.altura_mm
            if pos_z < (mod_h * 0.15)
              # Na base do modulo
              if dims[:bounds_min][:z] < MARGEM_BORDA
                regras << "CORPO: horizontal na base = base/rodape"
                return [:base, nil, regras]
              end
            elsif pos_z > (mod_h * 0.85)
              regras << "CORPO: horizontal no topo = topo/rega"
              return [:topo, nil, regras]
            else
              regras << "CORPO: horizontal no meio = prateleira"
              return [:prateleira, :fixa, regras]
            end
          end

          # Sem contexto: horizontal 18mm
          regras << "CORPO: horizontal = base/topo/prateleira (ambiguo)"
          return [:prateleira, :fixa, regras]

        when :vertical
          # Espessura no eixo Y = painel frontal/traseiro
          if contexto
            pos_y = dims[:posicao][:y]
            mod_d = contexto.profundidade_mm
            if pos_y < (mod_d * 0.2)
              regras << "CORPO: frontal no eixo Y, traseiro = fundo 18mm"
              return [:fundo, :sobreposto, regras]
            elsif pos_y > (mod_d * 0.8)
              # Frontal e 18mm = travessa ou porta
              if medio < 150 # estreito = travessa
                regras << "CORPO: frontal, estreito = travessa"
                return [:travessa, nil, regras]
              else
                regras << "CORPO: frontal, largo = porta (18mm raro)"
                return [:porta, nil, regras]
              end
            else
              regras << "CORPO: vertical meio Y = divisoria vertical"
              return [:divisoria, nil, regras]
            end
          end

          regras << "CORPO: vertical Y = fundo 18mm (sem contexto)"
          return [:fundo, :sobreposto, regras]
        end

        regras << "CORPO: fallback = desconhecido"
        [:desconhecido, nil, regras]
      end

      # Classifica portas e frentes de gaveta (15mm).
      def classificar_porta_frente(dims, orientacao, contexto, regras)
        sorted = dims[:sorted_dims]
        maior = sorted[0]
        medio = sorted[1]
        ratio = maior / [medio, 1].max

        # Frente de gaveta: larga e baixa (ratio > 2.5)
        if ratio > 2.5 && medio < 350
          regras << "PORTA: ratio #{ratio.round(1)}, medio #{medio}mm = frente de gaveta"
          return [:frente_gaveta, nil, regras]
        end

        # Porta: mais alta que larga ou quase quadrada
        regras << "PORTA: #{maior}x#{medio}mm = porta"
        [:porta, nil, regras]
      end

      # Classificacao generica por proporcao (fallback).
      def classificar_por_proporcao(dims, orientacao, contexto, regras)
        sorted = dims[:sorted_dims]
        maior = sorted[0]
        medio = sorted[1]
        menor = sorted[2] # espessura

        ratio_principal = maior / [medio, 1].max

        case orientacao
        when :profundidade
          if maior > 400
            regras << "PROPORCAO: vertical grande = lateral"
            [:lateral, nil, regras]
          else
            regras << "PROPORCAO: vertical pequena = divisoria"
            [:divisoria, nil, regras]
          end
        when :horizontal
          regras << "PROPORCAO: horizontal = prateleira/base"
          [:prateleira, :fixa, regras]
        when :vertical
          if ratio_principal > 3.0
            regras << "PROPORCAO: frontal estreito = travessa"
            [:travessa, nil, regras]
          else
            regras << "PROPORCAO: frontal largo = porta/fundo"
            [:porta, nil, regras]
          end
        else
          regras << "PROPORCAO: fallback = desconhecido"
          [:desconhecido, nil, regras]
        end
      end

      # ================================================================
      # Inferencia de bordas
      # ================================================================

      # Infere quais lados devem ter fita de borda baseado no tipo.
      # Convencao: top/bottom = comprimentos, left/right = larguras
      #
      # @param tipo [Symbol]
      # @param subtipo [Symbol, nil]
      # @param contexto [ContextoModulo, nil]
      # @return [Hash<Symbol, Boolean>]
      def inferir_bordas(tipo, subtipo, contexto)
        case tipo
        when :lateral
          # Lateral: fita na frente (top) sempre. Topo so se nao tem rega.
          { top: true, bottom: false, left: false, right: false }
        when :base
          # Base: fita na frente
          { top: true, bottom: false, left: false, right: false }
        when :topo
          # Topo/rega: fita na frente
          { top: true, bottom: false, left: false, right: false }
        when :prateleira
          # Prateleira: fita na frente, e possivelmente nos topos
          { top: true, bottom: false, left: false, right: false }
        when :divisoria
          # Divisoria: fita na frente
          { top: true, bottom: false, left: false, right: false }
        when :fundo
          # Fundo: sem fita (normalmente encaixado ou pregado)
          { top: false, bottom: false, left: false, right: false }
        when :porta
          # Porta: 4 lados (peca visivel)
          { top: true, bottom: true, left: true, right: true }
        when :frente_gaveta
          # Frente de gaveta: 4 lados
          { top: true, bottom: true, left: true, right: true }
        when :lateral_gaveta, :traseira_gaveta
          # Gaveta interna: fita no topo (visivel ao abrir)
          { top: true, bottom: false, left: false, right: false }
        when :fundo_gaveta
          # Fundo de gaveta: sem fita
          { top: false, bottom: false, left: false, right: false }
        when :tampo
          # Tampo: 4 lados (peca de exibicao)
          { top: true, bottom: true, left: true, right: true }
        when :travessa
          # Travessa: fita na frente (comprimento visivel)
          { top: true, bottom: false, left: false, right: false }
        when :rodape
          # Rodape: fita na frente
          { top: true, bottom: false, left: false, right: false }
        else
          { top: false, bottom: false, left: false, right: false }
        end
      end

      # ================================================================
      # Inferencia de grao
      # ================================================================

      def inferir_grao(tipo, dims)
        case tipo
        when :lateral, :divisoria, :porta
          # Verticais: grao no comprimento (sentido da altura)
          :length
        when :base, :topo, :prateleira, :tampo
          # Horizontais: grao no comprimento (sentido da largura do modulo)
          :length
        when :fundo
          # Fundo: sem grao definido (geralmente branco liso)
          :none
        when :frente_gaveta, :travessa, :rodape
          # Horizontais estreitas: grao no comprimento
          :length
        else
          :length
        end
      end

      # ================================================================
      # Inferencia de face visivel
      # ================================================================

      def inferir_face_visivel(tipo, subtipo, contexto)
        case tipo
        when :porta, :frente_gaveta, :tampo
          :face_a # Face decorativa externa
        when :lateral
          # Lateral esquerda: face_a (externa) e o lado esquerdo visivel
          # Lateral direita: face_b (lado externo do movel e a face oposta)
          subtipo == :esquerda ? :face_a : :face_b
        when :prateleira, :base, :topo
          :face_a # Face de cima e a visivel
        when :fundo
          :face_b # Face B (interna do movel e visivel, mas nao decorativa)
        else
          :ambas
        end
      end

      # ================================================================
      # Inferencia de material
      # ================================================================

      def inferir_material(tipo, espessura)
        case tipo
        when :fundo, :fundo_gaveta
          # Fundo: geralmente HDF ou MDF fino branco
          case espessura[:nominal]
          when 6.0 then 'HDF_6MM_BRANCO'
          when 15.0 then 'MDF_15MM_BRANCO'
          else 'MDF_BRANCO'
          end
        when :porta, :frente_gaveta, :tampo
          # Pecas visiveis: usar material decorativo
          'MDF_18MM_CORPO' # placeholder — usuario vai trocar
        when :lateral_gaveta, :traseira_gaveta
          # Gaveta interna: MDF branco
          'MDF_15MM_BRANCO'
        else
          # Corpo: material padrao do modulo
          "MDF_#{espessura[:nominal].to_i}MM_CORPO"
        end
      end

      # ================================================================
      # Calculo de confianca
      # ================================================================

      def calcular_confianca(tipo, regras, contexto)
        base = 0.3

        # Bonus por ter contexto de modulo
        base += 0.15 if contexto

        # Bonus por numero de regras concordantes
        base += [regras.length * 0.1, 0.2].min

        # Penalidade por ser fallback
        base -= 0.2 if regras.any? { |r| r.include?('fallback') || r.include?('FALLBACK') }
        base -= 0.1 if regras.any? { |r| r.include?('ambiguo') }

        # Bonus por tipos de alta confianca
        base += 0.2 if [:fundo, :tampo].include?(tipo) # espessura unica
        base += 0.1 if [:porta, :frente_gaveta].include?(tipo)

        # Clamp
        [[base, 0.0].max, 1.0].min
      end

      # ================================================================
      # Construcao de contexto
      # ================================================================

      def construir_contexto(grupo_modulo)
        bb = grupo_modulo.bounds
        return nil if bb.empty?

        # Tentar detectar tipo do módulo pelos atributos Ornato
        tipo_mod = nil
        if grupo_modulo.respond_to?(:definition)
          tipo_str = grupo_modulo.definition.get_attribute('dynamic_attributes', 'orn_tipo_modulo')
          tipo_mod = tipo_str&.to_sym
        end

        ContextoModulo.new(
          bounds_min: bb.min,
          bounds_max: bb.max,
          largura_mm: bb.width.to_mm.round(1),
          altura_mm: bb.height.to_mm.round(1),
          profundidade_mm: bb.depth.to_mm.round(1),
          pecas_existentes: [],
          tipo_modulo: tipo_mod
        )
      end

      # Coleta todos os grupos e componentes filhos diretos.
      def coletar_entidades(grupo)
        ents = grupo.respond_to?(:definition) ? grupo.definition.entities : grupo.entities
        ents.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      end

      # ================================================================
      # Refinamento por contexto completo
      # ================================================================

      # Segunda passada: com todas as pecas classificadas, refinar.
      # Ex: se tem 2 laterais e 0 divisorias, a "divisoria" pode ser lateral extra.
      def refinar_classificacoes(resultados, contexto)
        tipos = resultados.map { |r| r[:resultado].tipo }

        # Se nao tem nenhuma lateral mas tem divisorias, a divisoria nos extremos vira lateral
        laterais = resultados.select { |r| r[:resultado].tipo == :lateral }
        divisorias = resultados.select { |r| r[:resultado].tipo == :divisoria }

        if laterais.length < 2 && divisorias.length >= 2
          # Ordenar divisorias por posicao X
          divisorias.sort_by! { |r| r[:resultado].posicao_relativa[:x] }

          # A mais a esquerda vira lateral esquerda
          if laterais.none? { |r| r[:resultado].subtipo == :esquerda }
            div = divisorias.first
            div[:resultado] = reclassificar(div[:resultado], :lateral, :esquerda,
                                            "REFINO: divisoria extrema esquerda -> lateral")
          end

          # A mais a direita vira lateral direita
          if laterais.none? { |r| r[:resultado].subtipo == :direita }
            div = divisorias.last
            div[:resultado] = reclassificar(div[:resultado], :lateral, :direita,
                                            "REFINO: divisoria extrema direita -> lateral")
          end
        end

        # Se tem exatamente 1 horizontal na base e 1 no topo, garantir rotulacao
        horizontais = resultados.select { |r| [:base, :topo, :prateleira].include?(r[:resultado].tipo) }
        if horizontais.length >= 2
          sorted_by_z = horizontais.sort_by { |r| r[:resultado].posicao_relativa[:z] }
          if sorted_by_z.first[:resultado].tipo == :prateleira
            sorted_by_z.first[:resultado] = reclassificar(sorted_by_z.first[:resultado], :base, nil,
                                                          "REFINO: prateleira mais baixa -> base")
          end
          if sorted_by_z.last[:resultado].tipo == :prateleira
            sorted_by_z.last[:resultado] = reclassificar(sorted_by_z.last[:resultado], :topo, nil,
                                                         "REFINO: prateleira mais alta -> topo")
          end
        end
      end

      def reclassificar(resultado, novo_tipo, novo_subtipo, regra)
        ClassificacaoResult.new(
          tipo: novo_tipo,
          subtipo: novo_subtipo,
          material_sugerido: resultado.material_sugerido,
          espessura_nominal: resultado.espessura_nominal,
          espessura_real: resultado.espessura_real,
          comprimento_mm: resultado.comprimento_mm,
          largura_mm: resultado.largura_mm,
          grao: resultado.grao,
          bordas: inferir_bordas(novo_tipo, novo_subtipo, nil),
          face_visivel: inferir_face_visivel(novo_tipo, novo_subtipo, nil),
          confianca: [resultado.confianca + 0.1, 1.0].min, # bonus por refinamento
          regras_aplicadas: resultado.regras_aplicadas + [regra],
          posicao_relativa: resultado.posicao_relativa,
          orientacao: resultado.orientacao
        )
      end

      # ================================================================
      # Helpers
      # ================================================================

      def resultado_desconhecido(motivo)
        @log << "DESCONHECIDO: #{motivo}"
        ClassificacaoResult.new(
          tipo: :desconhecido, subtipo: nil,
          material_sugerido: nil,
          espessura_nominal: 0, espessura_real: 0,
          comprimento_mm: 0, largura_mm: 0,
          grao: :none,
          bordas: { top: false, bottom: false, left: false, right: false },
          face_visivel: :nenhuma,
          confianca: 0.0,
          regras_aplicadas: [motivo],
          posicao_relativa: { x: 0, y: 0, z: 0 },
          orientacao: :horizontal
        )
      end

      def volume_bb(entity)
        bb = entity.bounds
        bb.width * bb.height * bb.depth
      end

      def pos_z(entity)
        entity.bounds.center.z.to_mm
      end

      def catalogo_padrao
        {
          'HDF_6MM_BRANCO'   => { espessura: 6.0,  tipo: :hdf, cor: :branco },
          'MDF_15MM_BRANCO'  => { espessura: 15.0, tipo: :mdf, cor: :branco },
          'MDF_18MM_CORPO'   => { espessura: 18.0, tipo: :mdf, cor: :corpo },
          'MDF_25MM_TAMPO'   => { espessura: 25.0, tipo: :mdf, cor: :corpo },
          'MDF_30MM_DUPLO'   => { espessura: 30.0, tipo: :mdf, cor: :corpo },
          'MDF_36MM_DUPLO'   => { espessura: 36.0, tipo: :mdf, cor: :corpo },
        }
      end
    end
  end
end
