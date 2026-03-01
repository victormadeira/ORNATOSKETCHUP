# ornato_plugin/engines/motor_validacao.rb — Motor de validação de engenharia
# Valida módulos contra regras construtivas reais de marcenaria.
# Verifica dimensões, deflexão de prateleiras, capacidade de carga,
# viabilidade de montagem e integridade estrutural.

module Ornato
  module Engines
    class MotorValidacao

      # ─── Constantes de material (MDF) ───
      DENSIDADE_MDF        = 750.0    # kg/m³ — densidade média MDF
      MODULO_ELASTICIDADE  = 3500.0   # MPa — módulo de elasticidade MDF (E)
      DEFLEXAO_MAX_RATIO   = 300.0    # L/300 — deflexão máxima aceitável
      DENSIDADE_VIDRO      = 2500.0   # kg/m³ — vidro float/temperado

      # ─── Regras de validação (limites construtivos) ───
      REGRAS = {
        # Dimensões externas do módulo (mm)
        largura_min:            200,
        largura_max:            2400,
        altura_min:             150,
        altura_max:             2700,
        profundidade_min:       150,
        profundidade_max:       700,

        # Prateleiras
        vao_prateleira_max:     1000,   # mm sem apoio lateral
        peso_prateleira_max:    25,     # kg carga distribuída
        espessura_prat_min:     15,     # mm nominal mínimo

        # Gavetas
        vao_gaveta_max:         1200,   # mm largura máxima do vão
        vao_gaveta_min:         200,    # mm largura mínima do vão
        altura_gaveta_min:      60,     # mm altura mínima da caixa da gaveta
        gavetas_max_empilhadas: 8,      # máximo de gavetas em um vão

        # Portas
        peso_porta_max_total:   40,     # kg — peso máximo por folha de porta
        largura_porta_max:      600,    # mm — largura máxima recomendada por folha
        altura_porta_max:       2400,   # mm — altura máxima recomendada
        sobrecarga_dobradica_max: 15,   # kg por dobradiça

        # Estrutural
        espessura_min_lateral:  15,     # mm nominal
        distancia_min_furo_borda: 8,    # mm
        razao_esbeltez_max:     60,     # altura/espessura lateral máx antes de reforço

        # Fundo
        largura_fundo_dividir:  900,    # mm — acima disso, dividir o fundo
        espessura_fundo_min:    3,      # mm

        # Montagem
        peso_modulo_max:        80,     # kg — acima disso, precisa de dois montadores
        altura_parede_max:      2200,   # mm — módulo superior máximo para instalação segura
      }.freeze

      # ═══════════════════════════════════════════════
      # VALIDAÇÃO COMPLETA DO MÓDULO
      # ═══════════════════════════════════════════════

      # Executa todas as validações de engenharia em um ModuloInfo.
      # Retorna hash com { valido:, erros:, avisos:, sugestoes:, peso_estimado: }
      def self.validar_modulo(modulo_info)
        mi = modulo_info
        resultado = {
          valido:         true,
          erros:          [],
          avisos:         [],
          sugestoes:      [],
          peso_estimado:  0.0
        }

        # Validações individuais
        validar_dimensoes(mi, resultado)
        validar_estrutural(mi, resultado)
        validar_fundo(mi, resultado)
        validar_montagem(mi, resultado)

        # Validações dos agregados (prateleiras, gavetas, portas)
        validar_agregados(mi, resultado)

        # Peso estimado do módulo completo
        resultado[:peso_estimado] = calcular_peso_estimado(mi)

        # Peso total influencia avisos de montagem
        if resultado[:peso_estimado] > REGRAS[:peso_modulo_max]
          adicionar(resultado, :aviso,
            "Peso estimado #{resultado[:peso_estimado].round(1)}kg excede #{REGRAS[:peso_modulo_max]}kg. " \
            "Recomenda-se dois montadores para instalacao.")
        end

        # Determina validade final (erros bloqueiam)
        resultado[:valido] = resultado[:erros].empty?
        resultado
      end

      # ═══════════════════════════════════════════════
      # VALIDAÇÃO DE DIMENSÕES
      # ═══════════════════════════════════════════════

      # Verifica se as dimensões externas estão dentro dos limites construtivos
      def self.validar_dimensoes(mi, resultado = nil)
        resultado ||= resultado_vazio
        l = mi.largura
        a = mi.altura
        p = mi.profundidade

        # Largura
        if l < REGRAS[:largura_min]
          adicionar(resultado, :erro,
            "Largura #{l}mm menor que o minimo de #{REGRAS[:largura_min]}mm.")
        elsif l > REGRAS[:largura_max]
          adicionar(resultado, :erro,
            "Largura #{l}mm excede o maximo de #{REGRAS[:largura_max]}mm.")
        end

        # Altura
        if a < REGRAS[:altura_min]
          adicionar(resultado, :erro,
            "Altura #{a}mm menor que o minimo de #{REGRAS[:altura_min]}mm.")
        elsif a > REGRAS[:altura_max]
          adicionar(resultado, :erro,
            "Altura #{a}mm excede o maximo de #{REGRAS[:altura_max]}mm.")
        end

        # Profundidade
        if p < REGRAS[:profundidade_min]
          adicionar(resultado, :erro,
            "Profundidade #{p}mm menor que o minimo de #{REGRAS[:profundidade_min]}mm.")
        elsif p > REGRAS[:profundidade_max]
          adicionar(resultado, :erro,
            "Profundidade #{p}mm excede o maximo de #{REGRAS[:profundidade_max]}mm.")
        end

        # Proporções extremas (sugestão)
        if l > 0 && a > 0
          proporcao = [l / a.to_f, a / l.to_f].max
          if proporcao > 6.0
            adicionar(resultado, :sugestao,
              "Proporcao largura/altura (#{proporcao.round(1)}:1) muito extrema. " \
              "Considere dividir em modulos menores.")
          end
        end

        # Espessura mínima do corpo
        if mi.espessura_corpo < REGRAS[:espessura_min_lateral]
          adicionar(resultado, :erro,
            "Espessura do corpo #{mi.espessura_corpo}mm menor que o minimo estrutural de #{REGRAS[:espessura_min_lateral]}mm.")
        end

        resultado
      end

      # ═══════════════════════════════════════════════
      # VALIDAÇÃO DE PRATELEIRAS
      # ═══════════════════════════════════════════════

      # Valida uma prateleira quanto a deflexão e capacidade de carga.
      # vao_mm: largura do vão (span) em mm
      # espessura_nominal: espessura nominal da prateleira em mm (15, 18, 25)
      # profundidade_mm: profundidade da prateleira em mm
      # carga_kg: carga prevista em kg (default: peso_prateleira_max)
      def self.validar_prateleira(vao_mm, espessura_nominal, profundidade_mm = 400, carga_kg = nil)
        resultado = resultado_vazio
        carga_kg ||= REGRAS[:peso_prateleira_max]

        # Espessura real da chapa
        esp_real = Config.espessura_real(espessura_nominal)

        # Verificação básica do vão
        if vao_mm > REGRAS[:vao_prateleira_max]
          adicionar(resultado, :aviso,
            "Vao de prateleira #{vao_mm}mm excede #{REGRAS[:vao_prateleira_max]}mm. " \
            "Risco de deflexao excessiva.")
        end

        if espessura_nominal < REGRAS[:espessura_prat_min]
          adicionar(resultado, :erro,
            "Espessura de prateleira #{espessura_nominal}mm menor que o minimo de #{REGRAS[:espessura_prat_min]}mm.")
        end

        # Cálculo de deflexão (viga simplesmente apoiada, carga distribuída)
        deflexao = calcular_deflexao_prateleira(vao_mm, esp_real, profundidade_mm, carga_kg)
        deflexao_max = vao_mm / DEFLEXAO_MAX_RATIO

        if deflexao > deflexao_max
          adicionar(resultado, :erro,
            "Deflexao calculada #{deflexao.round(2)}mm excede o limite de #{deflexao_max.round(2)}mm (L/#{DEFLEXAO_MAX_RATIO.to_i}) " \
            "para vao #{vao_mm}mm com espessura #{espessura_nominal}mm e carga #{carga_kg}kg.")

          # Sugere espessura necessária
          espessura_sugerida = sugerir_espessura_prateleira(vao_mm, profundidade_mm, carga_kg)
          if espessura_sugerida
            adicionar(resultado, :sugestao,
              "Use espessura de #{espessura_sugerida}mm ou adicione um apoio central " \
              "para reduzir o vao efetivo.")
          end
        elsif deflexao > deflexao_max * 0.7
          adicionar(resultado, :aviso,
            "Deflexao calculada #{deflexao.round(2)}mm esta a 70%+ do limite (#{deflexao_max.round(2)}mm). " \
            "Considere aumentar a espessura ou reduzir o vao.")
        end

        # Peso próprio da prateleira
        peso_proprio = calcular_peso_peca(vao_mm, profundidade_mm, esp_real)
        if peso_proprio + carga_kg > REGRAS[:peso_prateleira_max] * 2
          adicionar(resultado, :aviso,
            "Carga total (#{(peso_proprio + carga_kg).round(1)}kg incluindo peso proprio) " \
            "excede duas vezes a carga recomendada.")
        end

        resultado[:deflexao_mm] = deflexao.round(3)
        resultado[:deflexao_max_mm] = deflexao_max.round(3)
        resultado[:peso_proprio_kg] = peso_proprio.round(3)
        resultado[:valido] = resultado[:erros].empty?
        resultado
      end

      # ═══════════════════════════════════════════════
      # VALIDAÇÃO DE GAVETAS
      # ═══════════════════════════════════════════════

      # Valida compatibilidade de gaveta com tipo de corrediça
      # vao_mm: largura interna do módulo onde a gaveta será instalada
      # tipo_corredica: :telescopica, :oculta, :tandembox, :roller
      # altura_gaveta: altura da caixa da gaveta (mm)
      # profundidade_gaveta: profundidade da gaveta (mm)
      def self.validar_gaveta(vao_mm, tipo_corredica, altura_gaveta = nil, profundidade_gaveta = nil)
        resultado = resultado_vazio
        spec = Config::CORREDICA_SPECS[tipo_corredica]

        unless spec
          adicionar(resultado, :erro,
            "Tipo de corredica '#{tipo_corredica}' nao reconhecido. " \
            "Tipos validos: #{Config::CORREDICA_SPECS.keys.join(', ')}.")
          resultado[:valido] = false
          return resultado
        end

        # Largura do vão
        if vao_mm > REGRAS[:vao_gaveta_max]
          adicionar(resultado, :erro,
            "Vao #{vao_mm}mm excede largura maxima de #{REGRAS[:vao_gaveta_max]}mm para gavetas.")
        end

        if vao_mm < REGRAS[:vao_gaveta_min]
          adicionar(resultado, :erro,
            "Vao #{vao_mm}mm menor que largura minima de #{REGRAS[:vao_gaveta_min]}mm para gavetas.")
        end

        # Verificações específicas por tipo de corrediça
        case tipo_corredica
        when :telescopica
          larg_gaveta = vao_mm - (2 * spec[:folga_por_lado])
          if larg_gaveta < spec[:largura_min_gaveta]
            adicionar(resultado, :erro,
              "Largura resultante da gaveta (#{larg_gaveta.round(1)}mm) menor que o minimo " \
              "de #{spec[:largura_min_gaveta]}mm para corredica telescopica.")
          end
          if spec[:largura_max_gaveta] && larg_gaveta > spec[:largura_max_gaveta]
            adicionar(resultado, :erro,
              "Largura resultante da gaveta (#{larg_gaveta.round(1)}mm) excede o maximo " \
              "de #{spec[:largura_max_gaveta]}mm para corredica telescopica.")
          end

        when :oculta
          if spec[:largura_max_modulo] && vao_mm > spec[:largura_max_modulo]
            adicionar(resultado, :aviso,
              "Vao #{vao_mm}mm excede largura maxima recomendada de #{spec[:largura_max_modulo]}mm " \
              "para corredica oculta (TANDEM). Verificar modelo especifico.")
          end
          larg_interna = vao_mm - spec[:deducao_interna]
          if larg_interna < spec[:largura_min_interna]
            adicionar(resultado, :erro,
              "Largura interna resultante (#{larg_interna.round(1)}mm) menor que o minimo " \
              "de #{spec[:largura_min_interna]}mm para corredica oculta.")
          end

        when :tandembox
          if spec[:largura_min_modulo] && vao_mm < spec[:largura_min_modulo]
            adicionar(resultado, :erro,
              "Vao #{vao_mm}mm menor que largura minima de #{spec[:largura_min_modulo]}mm " \
              "para Tandembox.")
          end
          if spec[:largura_max_modulo] && vao_mm > spec[:largura_max_modulo]
            adicionar(resultado, :erro,
              "Vao #{vao_mm}mm excede largura maxima de #{spec[:largura_max_modulo]}mm " \
              "para Tandembox.")
          end

        when :roller
          larg_gaveta = vao_mm - (2 * spec[:folga_por_lado])
          if spec[:largura_max_gaveta] && larg_gaveta > spec[:largura_max_gaveta]
            adicionar(resultado, :erro,
              "Largura resultante da gaveta (#{larg_gaveta.round(1)}mm) excede o maximo " \
              "de #{spec[:largura_max_gaveta]}mm para corredica roller.")
          end
        end

        # Altura mínima da gaveta
        if altura_gaveta
          if altura_gaveta < REGRAS[:altura_gaveta_min]
            adicionar(resultado, :erro,
              "Altura da gaveta #{altura_gaveta}mm menor que o minimo de #{REGRAS[:altura_gaveta_min]}mm.")
          end
          # Verificar se a altura comporta o mecanismo da corrediça
          if altura_gaveta < spec[:altura_mecanismo]
            adicionar(resultado, :aviso,
              "Altura da gaveta #{altura_gaveta}mm menor que a altura do mecanismo " \
              "da corredica (#{spec[:altura_mecanismo]}mm). Pode haver interferencia.")
          end
        end

        # Comprimento disponível da corrediça
        if profundidade_gaveta && spec[:comprimentos]
          comp_corredica = Utils.snap_corredica(profundidade_gaveta)
          if comp_corredica.nil? || comp_corredica < spec[:comprimentos].min
            adicionar(resultado, :aviso,
              "Profundidade #{profundidade_gaveta}mm nao possui comprimento de corredica compativel. " \
              "Comprimentos disponiveis: #{spec[:comprimentos].join(', ')}mm.")
          end
        end

        resultado[:valido] = resultado[:erros].empty?
        resultado
      end

      # ═══════════════════════════════════════════════
      # VALIDAÇÃO DE PORTAS
      # ═══════════════════════════════════════════════

      # Valida uma porta quanto a peso, dimensões e capacidade das dobradiças
      # vao: objeto Vao ou hash { largura:, altura: }
      # tipo_porta: :lisa, :provencal, :almofadada, :vidro, etc.
      # espessura_nominal: espessura nominal da porta em mm
      def self.validar_porta(vao, tipo_porta, espessura_nominal = 15)
        resultado = resultado_vazio

        larg = vao.respond_to?(:largura) ? vao.largura : vao[:largura]
        alt  = vao.respond_to?(:altura)  ? vao.altura  : vao[:altura]

        # Dimensões de sobreposição total (padrão)
        esp_corpo = Config::ESPESSURA_CORPO_PADRAO
        porta_larg = larg + (2 * esp_corpo) - (2 * Config::FOLGA_PORTA)
        porta_alt  = alt + (2 * esp_corpo) - (2 * Config::FOLGA_PORTA)

        # Largura máxima por folha
        if porta_larg > REGRAS[:largura_porta_max]
          adicionar(resultado, :aviso,
            "Largura da porta #{porta_larg.round(1)}mm excede recomendacao de #{REGRAS[:largura_porta_max]}mm. " \
            "Considere usar duas folhas.")
        end

        # Altura máxima
        if porta_alt > REGRAS[:altura_porta_max]
          adicionar(resultado, :aviso,
            "Altura da porta #{porta_alt.round(1)}mm excede recomendacao de #{REGRAS[:altura_porta_max]}mm.")
        end

        # Peso estimado da porta
        esp_real = Config.espessura_real(espessura_nominal)
        peso_porta = calcular_peso_peca(porta_larg, porta_alt, esp_real)

        # Portas de vidro: peso diferente
        if tipo_porta == :vidro_inteiro
          peso_porta = calcular_peso_vidro(porta_larg, porta_alt, 6)
        elsif tipo_porta == :vidro
          # Quadro MDF + vidro no centro
          spec_vidro = Config::PORTA_VIDRO
          lq = spec_vidro[:largura_quadro]
          area_quadro = (porta_larg * porta_alt) - ((porta_larg - 2 * lq) * (porta_alt - 2 * lq))
          peso_quadro = (area_quadro / 1_000_000.0) * (esp_real / 1000.0) * DENSIDADE_MDF
          area_vidro = (porta_larg - 2 * lq) * (porta_alt - 2 * lq)
          peso_vidro_peca = (area_vidro / 1_000_000.0) * (spec_vidro[:esp_vidro] / 1000.0) * DENSIDADE_VIDRO
          peso_porta = peso_quadro + peso_vidro_peca
        elsif tipo_porta == :ripada
          # Painel base + ripas coladas
          peso_base = calcular_peso_peca(porta_larg, porta_alt, esp_real)
          qtd_ripas = (porta_larg / 40.0).floor  # ripa 30mm + espaco 10mm
          peso_ripas = qtd_ripas * calcular_peso_peca(porta_alt, 30, 15)
          peso_porta = peso_base + peso_ripas
        end

        if peso_porta > REGRAS[:peso_porta_max_total]
          adicionar(resultado, :erro,
            "Peso estimado da porta #{peso_porta.round(1)}kg excede o maximo de #{REGRAS[:peso_porta_max_total]}kg.")
        end

        # Capacidade das dobradiças
        qtd_dob = Utils.qtd_dobradicas(porta_alt)
        carga_por_dobradica = peso_porta / qtd_dob.to_f

        if carga_por_dobradica > REGRAS[:sobrecarga_dobradica_max]
          adicionar(resultado, :aviso,
            "Carga por dobradica #{carga_por_dobradica.round(1)}kg excede #{REGRAS[:sobrecarga_dobradica_max]}kg. " \
            "Considere adicionar mais dobradicas (atualmente #{qtd_dob}).")
          # Calcula dobradiças necessárias
          dob_necessarias = (peso_porta / REGRAS[:sobrecarga_dobradica_max].to_f).ceil
          if dob_necessarias > qtd_dob
            adicionar(resultado, :sugestao,
              "Recomendacao: usar #{dob_necessarias} dobradicas em vez de #{qtd_dob}.")
          end
        end

        resultado[:peso_porta_kg] = peso_porta.round(2)
        resultado[:qtd_dobradicas] = qtd_dob
        resultado[:carga_por_dobradica_kg] = carga_por_dobradica.round(2)
        resultado[:valido] = resultado[:erros].empty?
        resultado
      end

      # ═══════════════════════════════════════════════
      # VALIDAÇÃO DO FUNDO
      # ═══════════════════════════════════════════════

      # Verifica adequação do painel de fundo
      def self.validar_fundo(mi, resultado = nil)
        resultado ||= resultado_vazio

        # Sem fundo: apenas sugestão
        if mi.tipo_fundo == Config::FUNDO_SEM
          adicionar(resultado, :sugestao,
            "Modulo sem fundo. Garanta que a estrutura sera fixada na parede " \
            "para evitar perda de esquadro.")
          return resultado
        end

        # Espessura mínima do fundo
        if mi.espessura_fundo < REGRAS[:espessura_fundo_min]
          adicionar(resultado, :erro,
            "Espessura do fundo #{mi.espessura_fundo}mm menor que o minimo de #{REGRAS[:espessura_fundo_min]}mm.")
        end

        # Fundo largo precisa ser dividido
        larg_interna = mi.largura_interna
        if larg_interna > REGRAS[:largura_fundo_dividir]
          adicionar(resultado, :aviso,
            "Largura interna #{larg_interna.round(1)}mm excede #{REGRAS[:largura_fundo_dividir]}mm. " \
            "Recomenda-se dividir o fundo com montante central.")
        end

        # Fundo rebaixado com espessura insuficiente de rebaixo
        if mi.tipo_fundo == Config::FUNDO_REBAIXADO
          if mi.rebaixo_fundo < mi.espessura_fundo_real + 2
            adicionar(resultado, :aviso,
              "Rebaixo do fundo #{mi.rebaixo_fundo}mm muito raso para painel de #{mi.espessura_fundo}mm " \
              "(real: #{mi.espessura_fundo_real}mm). Minimo recomendado: #{(mi.espessura_fundo_real + 3).round(1)}mm.")
          end
        end

        # Fundo HDF 3mm em módulo grande (aviso)
        if mi.espessura_fundo <= 3 && (larg_interna > 600 || mi.altura_interna > 600)
          adicionar(resultado, :sugestao,
            "Fundo HDF 3mm em modulo com mais de 600mm. " \
            "Considere usar MDF 6mm para maior rigidez.")
        end

        resultado
      end

      # ═══════════════════════════════════════════════
      # VALIDAÇÃO ESTRUTURAL
      # ═══════════════════════════════════════════════

      # Verifica integridade estrutural (caminhos de carga, esbeltez)
      def self.validar_estrutural(mi, resultado = nil)
        resultado ||= resultado_vazio
        esp_real = mi.espessura_corpo_real

        # Razão de esbeltez das laterais (altura / espessura)
        altura_efetiva = mi.altura_interna
        razao_esbeltez = altura_efetiva / esp_real

        if razao_esbeltez > REGRAS[:razao_esbeltez_max]
          adicionar(resultado, :aviso,
            "Razao de esbeltez da lateral #{razao_esbeltez.round(1)} (#{altura_efetiva.round(0)}mm / #{esp_real}mm) " \
            "excede #{REGRAS[:razao_esbeltez_max]}. Considere espessura #{largura_necessaria_esbeltez(altura_efetiva)}mm " \
            "ou adicione travessa de rigidez.")
        end

        # Módulo torre alto sem travessa intermediária
        if mi.tipo == :torre && mi.altura > 1800
          adicionar(resultado, :sugestao,
            "Modulo torre com #{mi.altura}mm de altura. " \
            "Recomenda-se travessa fixa intermediaria para rigidez estrutural.")
        end

        # Módulo suspenso largo sem reforço
        if mi.tipo_base == Config::BASE_SUSPENSA && mi.largura > 900
          adicionar(resultado, :aviso,
            "Modulo suspenso com #{mi.largura}mm de largura. " \
            "Verifique capacidade de carga da fixacao de parede.")
        end

        # Módulo superior muito profundo
        if mi.tipo == :superior && mi.profundidade > 400
          adicionar(resultado, :aviso,
            "Modulo superior com profundidade de #{mi.profundidade}mm. " \
            "Profundidade maxima recomendada para aéreos: 400mm.")
        end

        # Verificação de distância mínima furo-borda
        # Em peças estreitas, furos de minifix ficam muito próximos da borda
        if mi.espessura_corpo_real < REGRAS[:distancia_min_furo_borda] * 2
          adicionar(resultado, :aviso,
            "Espessura real #{esp_real}mm pode nao comportar furos de fixacao " \
            "com distancia minima de #{REGRAS[:distancia_min_furo_borda]}mm da borda.")
        end

        # Montagem Europa em módulo estreito pode ser problemática
        if mi.montagem == Config::MONTAGEM_EUROPA && mi.largura < 300
          adicionar(resultado, :sugestao,
            "Montagem Europa em modulo estreito (#{mi.largura}mm). " \
            "Montagem Brasil pode oferecer melhor fixacao para modulos estreitos.")
        end

        resultado
      end

      # ═══════════════════════════════════════════════
      # VALIDAÇÃO DE MONTAGEM
      # ═══════════════════════════════════════════════

      # Verifica viabilidade de montagem e instalação
      def self.validar_montagem(mi, resultado = nil)
        resultado ||= resultado_vazio

        # Módulo alto demais para instalar na parede
        if mi.tipo == :superior
          if mi.altura > REGRAS[:altura_parede_max]
            adicionar(resultado, :aviso,
              "Modulo superior com #{mi.altura}mm pode ser dificil de instalar. " \
              "Altura maxima recomendada: #{REGRAS[:altura_parede_max]}mm.")
          end
        end

        # Rodapé: verificação de acessibilidade para limpeza
        if mi.tipo_base == Config::BASE_RODAPE && mi.altura_rodape < 80
          adicionar(resultado, :sugestao,
            "Rodape de #{mi.altura_rodape}mm. " \
            "Altura minima recomendada de 80mm para facilitar limpeza.")
        end

        # Pés reguláveis: quantidade vs. largura
        if mi.tipo_base == Config::BASE_PES
          qtd_pes_necessarios = mi.largura > 800 ? 6 : 4
          peso_est = calcular_peso_estimado(mi)
          carga_por_pe = peso_est / qtd_pes_necessarios.to_f
          if carga_por_pe > 30
            adicionar(resultado, :aviso,
              "Carga estimada por pe: #{carga_por_pe.round(1)}kg. " \
              "Verifique capacidade dos pes regulaveis.")
          end
        end

        # Fixação confirmat em espessura grossa pode ser excessiva
        if mi.fixacao == Config::FIXACAO_CONFIRMAT && mi.espessura_corpo >= 25
          adicionar(resultado, :sugestao,
            "Fixacao confirmat em espessura #{mi.espessura_corpo}mm. " \
            "Considere minifix para melhor acabamento e desmontagem.")
        end

        # Módulo muito largo sem divisória interna
        if mi.largura > 1200
          tem_divisoria = false
          if mi.vao_principal && mi.vao_principal.subdividido?
            tem_divisoria = true
          end
          unless tem_divisoria
            adicionar(resultado, :sugestao,
              "Modulo com #{mi.largura}mm de largura sem divisoria interna. " \
              "Considere adicionar divisoria vertical para rigidez.")
          end
        end

        resultado
      end

      # ═══════════════════════════════════════════════
      # CÁLCULOS DE DEFLEXÃO
      # ═══════════════════════════════════════════════

      # Calcula deflexão de uma prateleira sob carga distribuída.
      # Fórmula: delta = (5 * W * L^4) / (384 * E * I)
      # Onde:
      #   W = carga por unidade de comprimento (N/mm)
      #   L = vão livre (mm)
      #   E = módulo de elasticidade (MPa = N/mm²)
      #   I = momento de inércia (mm⁴) = b * h³ / 12
      #
      # vao_mm: vão livre em mm
      # espessura_real_mm: espessura REAL da prateleira em mm (ex: 15.5, 18.5, 25.5)
      # profundidade_mm: profundidade (largura da seção transversal) em mm
      # carga_kg: carga total distribuída em kg
      def self.calcular_deflexao_prateleira(vao_mm, espessura_real_mm, profundidade_mm, carga_kg)
        return 0.0 if vao_mm <= 0 || espessura_real_mm <= 0 || profundidade_mm <= 0

        # Converter carga para N/mm (distribuída uniformemente)
        carga_n = carga_kg * 9.81  # kg → N
        w = carga_n / vao_mm.to_f  # N/mm (carga por mm de comprimento)

        # Momento de inércia da seção retangular
        # I = b * h³ / 12  (b = profundidade, h = espessura)
        i = profundidade_mm * (espessura_real_mm ** 3) / 12.0

        # Deflexão máxima (viga simplesmente apoiada, carga uniformemente distribuída)
        # delta = (5 * w * L^4) / (384 * E * I)
        deflexao = (5.0 * w * (vao_mm ** 4)) / (384.0 * MODULO_ELASTICIDADE * i)

        deflexao
      end

      # Retorna a deflexão máxima aceitável para um dado vão
      def self.deflexao_maxima(vao_mm)
        vao_mm / DEFLEXAO_MAX_RATIO
      end

      # Sugere a espessura nominal necessária para atender ao critério L/300
      # Testa espessuras padrão disponíveis (15, 18, 25mm)
      def self.sugerir_espessura_prateleira(vao_mm, profundidade_mm, carga_kg)
        espessuras_disponiveis = [15, 18, 25]
        deflexao_max = vao_mm / DEFLEXAO_MAX_RATIO

        espessuras_disponiveis.each do |esp_nominal|
          esp_real = Config.espessura_real(esp_nominal)
          deflexao = calcular_deflexao_prateleira(vao_mm, esp_real, profundidade_mm, carga_kg)
          return esp_nominal if deflexao <= deflexao_max
        end

        # Nenhuma espessura padrão resolve — sugerir engrossado
        esp_engrossado = Config::ESPESSURA_ENGROSSADO
        deflexao = calcular_deflexao_prateleira(vao_mm, esp_engrossado, profundidade_mm, carga_kg)
        return 'engrossado (31mm)' if deflexao <= deflexao_max

        nil  # Precisa de apoio central
      end

      # Calcula o vão máximo seguro para uma dada espessura e carga
      def self.vao_maximo_prateleira(espessura_nominal, profundidade_mm = 400, carga_kg = nil)
        carga_kg ||= REGRAS[:peso_prateleira_max]
        esp_real = Config.espessura_real(espessura_nominal)

        # Busca iterativa do vão máximo (bisseção)
        vao_min = 100.0
        vao_max = 2000.0
        tolerancia = 1.0  # mm

        while (vao_max - vao_min) > tolerancia
          vao_teste = (vao_min + vao_max) / 2.0
          deflexao = calcular_deflexao_prateleira(vao_teste, esp_real, profundidade_mm, carga_kg)
          deflexao_limite = vao_teste / DEFLEXAO_MAX_RATIO

          if deflexao <= deflexao_limite
            vao_min = vao_teste
          else
            vao_max = vao_teste
          end
        end

        vao_min.round(0)
      end

      # ═══════════════════════════════════════════════
      # CÁLCULO DE PESO
      # ═══════════════════════════════════════════════

      # Calcula peso estimado do módulo completo (corpo + agregados)
      # Usa densidade MDF 750 kg/m³
      def self.calcular_peso_estimado(mi)
        peso_total = 0.0

        # Peso das peças registradas
        if mi.pecas && !mi.pecas.empty?
          mi.pecas.each do |peca|
            next unless peca.respond_to?(:comprimento) && peca.respond_to?(:largura)
            esp_mm = peca.respond_to?(:espessura_real) ? peca.espessura_real : Config.espessura_real(peca.espessura)
            peso_total += calcular_peso_peca(peca.comprimento, peca.largura, esp_mm) * (peca.quantidade || 1)
          end
        else
          # Estimativa pelo envelope do módulo (quando não há lista de peças)
          peso_total = estimar_peso_envelope(mi)
        end

        peso_total.round(2)
      end

      # Calcula peso de uma peça individual de MDF
      # comprimento, largura, espessura em mm
      def self.calcular_peso_peca(comprimento_mm, largura_mm, espessura_mm)
        # Volume em m³
        volume_m3 = (comprimento_mm / 1000.0) * (largura_mm / 1000.0) * (espessura_mm / 1000.0)
        volume_m3 * DENSIDADE_MDF
      end

      private

      # ─── Calcula peso de painel de vidro ───
      def self.calcular_peso_vidro(largura_mm, altura_mm, espessura_mm)
        volume_m3 = (largura_mm / 1000.0) * (altura_mm / 1000.0) * (espessura_mm / 1000.0)
        volume_m3 * DENSIDADE_VIDRO
      end

      # ─── Estimativa de peso pelo envelope (sem lista de peças) ───
      def self.estimar_peso_envelope(mi)
        esp = mi.espessura_corpo_real
        esp_f = mi.espessura_fundo_real
        l = mi.largura
        a = mi.altura
        p = mi.profundidade

        peso = 0.0

        # 2 laterais
        peso += 2 * calcular_peso_peca(a, p, esp)

        # Base + topo
        larg_bt = l - (2 * esp)  # montagem Brasil (conservador)
        peso += 2 * calcular_peso_peca(larg_bt, p, esp)

        # Fundo
        if mi.tipo_fundo != Config::FUNDO_SEM
          peso += calcular_peso_peca(l, a, esp_f)
        end

        peso
      end

      # ─── Validação dos agregados (prateleiras, gavetas, portas nos vãos) ───
      def self.validar_agregados(mi, resultado)
        return unless mi.vao_principal

        vaos = mi.vao_principal.vaos_folha

        vaos.each do |vao|
          next unless vao.agregados && !vao.agregados.empty?

          vao.agregados.each do |agreg|
            tipo = agreg.is_a?(Hash) ? agreg[:tipo] : nil
            next unless tipo

            case tipo
            when :prateleira
              res_prat = validar_prateleira(
                vao.largura,
                mi.espessura_corpo,
                vao.profundidade > 0 ? vao.profundidade : mi.profundidade_interna
              )
              resultado[:erros].concat(res_prat[:erros])
              resultado[:avisos].concat(res_prat[:avisos])
              resultado[:sugestoes].concat(res_prat[:sugestoes])

            when :gaveta
              tipo_corr = agreg[:corredica] || :telescopica
              res_gav = validar_gaveta(vao.largura, tipo_corr)
              resultado[:erros].concat(res_gav[:erros])
              resultado[:avisos].concat(res_gav[:avisos])
              resultado[:sugestoes].concat(res_gav[:sugestoes])

            when :porta
              subtipo = agreg[:subtipo] || :lisa
              res_porta = validar_porta(vao, subtipo, mi.espessura_corpo)
              resultado[:erros].concat(res_porta[:erros])
              resultado[:avisos].concat(res_porta[:avisos])
              resultado[:sugestoes].concat(res_porta[:sugestoes])
            end
          end
        end
      end

      # ─── Calcula espessura necessária para razão de esbeltez ───
      def self.largura_necessaria_esbeltez(altura_mm)
        esp_necessaria = altura_mm / REGRAS[:razao_esbeltez_max].to_f
        # Arredonda para espessura comercial acima
        espessuras = [15, 18, 25]
        espessuras.find { |e| Config.espessura_real(e) >= esp_necessaria } || 25
      end

      # ─── Helper: cria resultado vazio ───
      def self.resultado_vazio
        { valido: true, erros: [], avisos: [], sugestoes: [] }
      end

      # ─── Helper: adiciona mensagem ao resultado ───
      def self.adicionar(resultado, nivel, mensagem)
        case nivel
        when :erro
          resultado[:erros] << mensagem
        when :aviso
          resultado[:avisos] << mensagem
        when :sugestao
          resultado[:sugestoes] << mensagem
        end
      end

      # ─── Relatório formatado para console ───
      public

      def self.relatorio(modulo_info)
        res = validar_modulo(modulo_info)
        mi = modulo_info

        linhas = []
        linhas << "=" * 60
        linhas << "RELATORIO DE VALIDACAO — #{mi.nome}"
        linhas << "#{mi.largura} x #{mi.altura} x #{mi.profundidade}mm | #{mi.tipo}"
        linhas << "=" * 60
        linhas << ""

        if res[:valido]
          linhas << "[OK] Modulo aprovado na validacao de engenharia."
        else
          linhas << "[REPROVADO] Modulo possui #{res[:erros].size} erro(s) que impedem a fabricacao."
        end
        linhas << "Peso estimado: #{res[:peso_estimado]}kg"
        linhas << ""

        if res[:erros].any?
          linhas << "--- ERROS (#{res[:erros].size}) ---"
          res[:erros].each_with_index { |e, i| linhas << "  #{i + 1}. #{e}" }
          linhas << ""
        end

        if res[:avisos].any?
          linhas << "--- AVISOS (#{res[:avisos].size}) ---"
          res[:avisos].each_with_index { |a, i| linhas << "  #{i + 1}. #{a}" }
          linhas << ""
        end

        if res[:sugestoes].any?
          linhas << "--- SUGESTOES (#{res[:sugestoes].size}) ---"
          res[:sugestoes].each_with_index { |s, i| linhas << "  #{i + 1}. #{s}" }
          linhas << ""
        end

        linhas << "=" * 60
        texto = linhas.join("\n")
        puts texto
        texto
      end

      # ─── Tabela de vãos máximos por espessura (para referência rápida) ───
      def self.tabela_vaos_maximos(carga_kg = nil)
        carga_kg ||= REGRAS[:peso_prateleira_max]
        profundidades = [300, 400, 500, 600]
        espessuras = [15, 18, 25]

        linhas = []
        linhas << "TABELA DE VAOS MAXIMOS PARA PRATELEIRAS (carga: #{carga_kg}kg)"
        linhas << "-" * 50

        header = "Espessura".ljust(12)
        profundidades.each { |p| header += "Prof #{p}mm".rjust(12) }
        linhas << header

        espessuras.each do |esp|
          linha = "#{esp}mm".ljust(12)
          profundidades.each do |prof|
            vao_max = vao_maximo_prateleira(esp, prof, carga_kg)
            linha += "#{vao_max}mm".rjust(12)
          end
          linhas << linha
        end

        linhas << "-" * 50
        texto = linhas.join("\n")
        puts texto
        texto
      end
    end
  end
end
