# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# engineering/capacity_validator.rb — Validador de peso e capacidade
#
# Valida automaticamente:
#   - Peso da porta → quantidade de dobradicas necessarias
#   - Carga da prateleira → tipo de suporte adequado
#   - Profundidade/peso gaveta → tipo de corredica adequado
#   - Vao minimo por tipo de modulo
#   - Dimensoes maximas por tipo de peca
#   - Compatibilidade entre ferragens e pecas
#
# DENSIDADES (kg/m3):
#   MDF:      720-780 (media 750)
#   MDP/Aglom: 600-680 (media 650)
#   HDF:      900-1000 (media 950)
#   Compensado: 500-600 (media 550)
#   Vidro temperado: 2500

module Ornato
  module Engineering
    class CapacityValidator

      # Densidades em kg/m3
      DENSIDADES = {
        'MDF'        => 750,
        'MDP'        => 650,
        'HDF'        => 950,
        'Compensado' => 550,
        'Vidro'      => 2500,
        'Espelho'    => 2600,
      }.freeze

      # Capacidade de carga por tipo de dobradica (kg por dobradica)
      CAPACIDADE_DOBRADICA = {
        reta_simples:     5.0,
        reta_amortecedor: 6.0,
        'reta_reforçada': 8.0,
        curva_amortecedor: 5.0,
        supercurva:       4.5,
      }.freeze

      # Regras de quantidade de dobradicas por peso de porta
      # ABNT/fabricantes: ate 9kg = 2, ate 15kg = 3, ate 20kg = 4, ate 28kg = 5
      REGRA_QTD_DOBRADICAS = [
        { peso_max_kg: 9,   qtd: 2 },
        { peso_max_kg: 15,  qtd: 3 },
        { peso_max_kg: 20,  qtd: 4 },
        { peso_max_kg: 28,  qtd: 5 },
        { peso_max_kg: 40,  qtd: 6 },
      ].freeze

      # Regras de quantidade de dobradicas por altura de porta
      # Complementar ao peso: portas altas flexionam e precisam mais dobradicas
      REGRA_QTD_POR_ALTURA = [
        { altura_max_mm: 700,  qtd_min: 2 },
        { altura_max_mm: 1100, qtd_min: 3 },
        { altura_max_mm: 1600, qtd_min: 4 },
        { altura_max_mm: 2000, qtd_min: 5 },
        { altura_max_mm: 2500, qtd_min: 6 },
      ].freeze

      # Capacidade de carga por tipo de corredica
      CAPACIDADE_CORREDICA = {
        telescopica:     { kg: 35,  prof_max_mm: 550 },
        oculta:          { kg: 50,  prof_max_mm: 650 },
        quadro_metalico: { kg: 25,  prof_max_mm: 500 },
        tandembox:       { kg: 65,  prof_max_mm: 650 },
      }.freeze

      # Capacidade de carga por tipo de suporte de prateleira (por prateleira)
      CAPACIDADE_SUPORTE = {
        pino_5mm:     15,
        pino_8mm:     30,
        suporte_metalico: 40,
        cremalheira:  50,
        confirmat:    80,
      }.freeze

      # Dimensoes maximas de chapa MDF/MDP padrao Brasil
      CHAPA_MAX = {
        comprimento_mm: 2750,
        largura_mm:     1850,
      }.freeze

      # Dimensoes maximas por tipo de modulo (mm) — inspirado Gabster/PolyBoard
      DIMENSAO_MAXIMA = {
        inferior:     { largura: 1200, altura: 900,  profundidade: 650 },
        superior:     { largura: 1200, altura: 900,  profundidade: 400 },
        torre:        { largura: 800,  altura: 2700, profundidade: 650 },
        gaveteiro:    { largura: 800,  altura: 900,  profundidade: 650 },
        roupeiro:     { largura: 1200, altura: 2700, profundidade: 650 },
        estante:      { largura: 1200, altura: 2700, profundidade: 450 },
        bancada:      { largura: 3000, altura: 100,  profundidade: 800 },
        pia:          { largura: 1200, altura: 900,  profundidade: 650 },
        nicho:        { largura: 1200, altura: 600,  profundidade: 400 },
        torre_quente: { largura: 800,  altura: 2700, profundidade: 650 },
        cooktop:      { largura: 1200, altura: 900,  profundidade: 650 },
        micro_ondas:  { largura: 800,  altura: 600,  profundidade: 500 },
        lava_louca:   { largura: 900,  altura: 900,  profundidade: 650 },
        canto_l:      { largura: 1200, altura: 900,  profundidade: 650 },
        canto_l_superior: { largura: 1000, altura: 900, profundidade: 400 },
        ilha:         { largura: 3000, altura: 1000, profundidade: 1000 },
        espelheira:   { largura: 1200, altura: 1000, profundidade: 200 },
        pia_banheiro: { largura: 1200, altura: 900,  profundidade: 550 },
      }.freeze

      # Categorias de alerta para inspetor (inspirado DinaBox)
      CATEGORIAS = {
        estrutural: 'Estrutural',
        material:   'Material',
        furacao:    'Furacao',
        bordas:     'Bordas',
        ferragem:   'Ferragem',
      }.freeze

      # Vaos minimos internos por tipo (mm)
      VAO_MINIMO = {
        inferior:    { largura: 200, altura: 250, profundidade: 250 },
        superior:    { largura: 200, altura: 200, profundidade: 200 },
        torre:       { largura: 300, altura: 1500, profundidade: 300 },
        gaveteiro:   { largura: 250, altura: 300, profundidade: 300 },
        roupeiro:    { largura: 400, altura: 1500, profundidade: 400 },
        estante:     { largura: 200, altura: 300, profundidade: 150 },
        pia:         { largura: 400, altura: 400, profundidade: 400 },
        cooktop:     { largura: 500, altura: 400, profundidade: 400 },
        lava_louca:  { largura: 550, altura: 400, profundidade: 400 },
        ilha:        { largura: 400, altura: 400, profundidade: 400 },
        nicho:       { largura: 150, altura: 150, profundidade: 100 },
        bancada:     { largura: 300, altura: 30,  profundidade: 250 },
        espelheira:  { largura: 200, altura: 200, profundidade: 80 },
        pia_banheiro:{ largura: 250, altura: 300, profundidade: 250 },
      }.freeze

      # Normaliza valores booleanos de dynamic_attributes.
      def self.to_bool(val)
        return false if val.nil? || val == false
        return false if val.to_s == 'false' || val.to_s == '0'
        true
      end

      # ================================================================
      # Interface publica — Validar modulo completo
      # ================================================================

      # Executa todas as validacoes em um modulo.
      # @param modulo [Sketchup::ComponentInstance]
      # @return [Array<Hash>] lista de alertas/erros { nivel:, mensagem:, peca:, sugestao: }
      def self.validar(modulo)
        alertas = []
        parent_def = modulo.definition

        # Ler dimensoes do modulo
        dims = ler_dimensoes_modulo(parent_def)
        tipo_modulo = parent_def.get_attribute('dynamic_attributes', 'orn_tipo_modulo') || 'inferior'
        tipo_sym = tipo_modulo.to_sym

        # 1. Validar dimensoes minimas
        alertas.concat(validar_dimensoes_minimas(dims, tipo_sym))

        # 2. Validar dimensoes maximas (limites por tipo)
        alertas.concat(validar_dimensoes_maximas(dims, tipo_sym))

        # 3. Validar cada peca
        parent_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          peca_def = entity.definition
          tipo_peca = peca_def.get_attribute('dynamic_attributes', 'orn_tipo_peca')
          next unless tipo_peca

          # 3a. Validar dimensoes maximas (chapa)
          alertas.concat(validar_dimensoes_chapa(peca_def, tipo_peca))

          # 3b. Validar peso de portas → qtd dobradicas
          if tipo_peca == 'porta'
            subtipo_peca = peca_def.get_attribute('dynamic_attributes', 'orn_subtipo')
            unless subtipo_peca == 'correr'
              alertas.concat(validar_porta(peca_def, dims))
            end
          end

          # 3c. Validar gavetas → capacidade corredica
          if tipo_peca == 'frente_gaveta'
            alertas.concat(validar_gaveta(peca_def, dims, parent_def))
          end

          # 3d. Validar prateleiras → capacidade suporte
          if tipo_peca == 'prateleira'
            alertas.concat(validar_prateleira(peca_def, dims, parent_def))
          end

          # 3e. Validar bordas faltantes (pecas visiveis sem borda)
          alertas.concat(validar_bordas(peca_def, tipo_peca))

          # 3f. Validar espessura inconsistente em pecas estruturais
          if %w[lateral base topo].include?(tipo_peca)
            esp_peca = (peca_def.get_attribute('dynamic_attributes', 'orn_espessura') || 0).to_f
            esp_peca_mm = esp_peca < 10 ? (esp_peca * 10).round : esp_peca.round
            esp_corpo_mm = (dims[:espessura_real_cm] * 10).round
            nome_p = peca_def.get_attribute('dynamic_attributes', 'orn_nome') || tipo_peca
            if esp_peca_mm > 0 && (esp_peca_mm - esp_corpo_mm).abs > 2
              alertas << {
                nivel: :aviso,
                categoria: :material,
                peca: nome_p,
                mensagem: "#{nome_p}: espessura #{esp_peca_mm}mm difere do corpo (#{esp_corpo_mm}mm)",
                sugestao: "Verifique se a espessura diferente e intencional"
              }
            end
          end
        end

        # 4. Validar basculante → articulador adequado
        alertas.concat(validar_basculante(parent_def, dims))

        # 5. Validar furacao S32 cabe na lateral
        alertas.concat(validar_furacao_s32(dims))

        # 6. Validar fundo vs espessura do corpo
        tipo_fundo = parent_def.get_attribute('dynamic_attributes', 'orn_tipo_fundo') || ''
        alertas.concat(validar_fundo(tipo_fundo, dims))

        alertas
      end

      # Valida dimensoes maximas por tipo de modulo (inspirado Gabster)
      def self.validar_dimensoes_maximas(dims, tipo_sym)
        alertas = []
        maximos = DIMENSAO_MAXIMA[tipo_sym]
        return alertas unless maximos

        if dims[:largura_mm] > maximos[:largura]
          alertas << {
            nivel: :erro,
            categoria: :estrutural,
            peca: 'Modulo',
            mensagem: "Largura #{dims[:largura_mm]}mm excede maximo de #{maximos[:largura]}mm para #{tipo_sym}",
            sugestao: "Reduza a largura ou divida em 2 modulos",
          }
        end

        if dims[:altura_mm] > maximos[:altura]
          alertas << {
            nivel: :erro,
            categoria: :estrutural,
            peca: 'Modulo',
            mensagem: "Altura #{dims[:altura_mm]}mm excede maximo de #{maximos[:altura]}mm para #{tipo_sym}",
            sugestao: "Reduza a altura ou use tipo torre/roupeiro",
          }
        end

        if dims[:profundidade_mm] > maximos[:profundidade]
          alertas << {
            nivel: :aviso,
            categoria: :estrutural,
            peca: 'Modulo',
            mensagem: "Profundidade #{dims[:profundidade_mm]}mm excede recomendado de #{maximos[:profundidade]}mm",
            sugestao: "Verifique se a profundidade e intencional",
          }
        end

        alertas
      end

      # Valida bordas em pecas visiveis
      def self.validar_bordas(peca_def, tipo_peca)
        alertas = []
        dc = 'dynamic_attributes'

        # Pecas que precisam de borda nas arestas visiveis
        tipos_com_borda = %w[lateral base topo prateleira divisoria porta frente_gaveta]
        return alertas unless tipos_com_borda.include?(tipo_peca)

        nome = peca_def.get_attribute(dc, 'orn_nome') || peca_def.name
        tem_alguma_borda = false

        %w[orn_borda_frontal orn_borda_traseira orn_borda_esquerda orn_borda_direita].each do |attr|
          tem_alguma_borda = true if to_bool(peca_def.get_attribute(dc, attr))
        end

        unless tem_alguma_borda
          alertas << {
            nivel: :aviso,
            categoria: :bordas,
            peca: nome,
            mensagem: "#{nome} (#{tipo_peca}) sem nenhuma borda aplicada",
            sugestao: "Adicione borda nas arestas visiveis",
          }
        end

        # Pecas frontais devem ter borda frontal obrigatoriamente
        frontais = %w[porta frente_gaveta]
        if tem_alguma_borda && frontais.include?(tipo_peca)
          unless to_bool(peca_def.get_attribute(dc, 'orn_borda_frontal'))
            alertas << {
              nivel: :aviso,
              categoria: :bordas,
              peca: nome,
              mensagem: "#{nome}: peca frontal sem borda frontal",
              sugestao: "Bordas visiveis ao usuario devem ter fita",
            }
          end
        end

        # Laterais devem ter borda frontal (aresta visivel)
        if tem_alguma_borda && tipo_peca == 'lateral'
          unless to_bool(peca_def.get_attribute(dc, 'orn_borda_frontal'))
            alertas << {
              nivel: :aviso,
              categoria: :bordas,
              peca: nome,
              mensagem: "#{nome}: lateral sem borda frontal",
              sugestao: "A aresta frontal da lateral fica exposta",
            }
          end
        end

        alertas
      end

      # Calcula peso de uma peca em kg.
      # @param peca_def [Sketchup::ComponentDefinition]
      # @return [Float] peso em kg
      def self.calcular_peso_kg(peca_def)
        material = peca_def.get_attribute('dynamic_attributes', 'orn_material') || 'MDF'
        comp_mm = (peca_def.get_attribute('dynamic_attributes', 'orn_corte_comp') || 0).to_f
        larg_mm = (peca_def.get_attribute('dynamic_attributes', 'orn_corte_larg') || 0).to_f
        esp_mm = (peca_def.get_attribute('dynamic_attributes', 'orn_espessura_real') || 18.5).to_f

        # Usar formulas se valores sao 0
        if comp_mm == 0 || larg_mm == 0
          # Fallback: ler do bounding box
          bb = peca_def.bounds
          comp_mm = bb.width.to_mm if comp_mm == 0
          larg_mm = bb.height.to_mm if larg_mm == 0
          esp_mm = bb.depth.to_mm if esp_mm == 0
        end

        # Converter para metros
        comp_m = comp_mm / 1000.0
        larg_m = larg_mm / 1000.0
        esp_m = esp_mm / 1000.0

        # Volume em m3
        volume_m3 = comp_m * larg_m * esp_m

        # Densidade
        densidade = DENSIDADES.find { |k, _| material.to_s.upcase.include?(k.upcase) }&.last || 750

        (volume_m3 * densidade).round(2)
      end

      # Calcula quantidade de dobradicas necessarias.
      # @param peso_kg [Float] peso da porta
      # @param altura_mm [Float] altura da porta
      # @return [Integer] quantidade recomendada
      def self.qtd_dobradicas_necessarias(peso_kg, altura_mm)
        qtd_peso = REGRA_QTD_DOBRADICAS.find { |r| peso_kg <= r[:peso_max_kg] }&.dig(:qtd) || 6
        qtd_altura = REGRA_QTD_POR_ALTURA.find { |r| altura_mm <= r[:altura_max_mm] }&.dig(:qtd_min) || 6
        [qtd_peso, qtd_altura].max
      end

      # Sugere tipo de corredica por peso e profundidade da gaveta
      def self.sugerir_corredica(peso_conteudo_kg, profundidade_mm)
        CAPACIDADE_CORREDICA.each do |tipo, specs|
          if peso_conteudo_kg <= specs[:kg] && profundidade_mm <= specs[:prof_max_mm]
            return tipo
          end
        end
        :tandembox  # fallback para o mais robusto
      end

      private

      def self.ler_dimensoes_modulo(parent_def)
        dc = 'dynamic_attributes'
        larg = (parent_def.get_attribute(dc, 'orn_largura') || 60).to_f
        prof = (parent_def.get_attribute(dc, 'orn_profundidade') || 55).to_f
        alt = (parent_def.get_attribute(dc, 'orn_altura') || 72).to_f
        esp = (parent_def.get_attribute(dc, 'orn_espessura_real') || 1.85).to_f
        rod = (parent_def.get_attribute(dc, 'orn_altura_rodape') || 0).to_f

        {
          largura_cm: larg,
          profundidade_cm: prof,
          altura_cm: alt,
          espessura_real_cm: esp,
          rodape_mm: rod,
          # Derivados em mm para validar_dimensoes_maximas
          largura_mm: (larg * 10).round,
          profundidade_mm: (prof * 10).round,
          altura_mm: (alt * 10).round,
        }
      end

      def self.validar_dimensoes_minimas(dims, tipo)
        alertas = []
        mins = VAO_MINIMO[tipo]
        return alertas unless mins

        vao_largura_mm = (dims[:largura_cm] - 2 * dims[:espessura_real_cm]) * 10
        vao_altura_mm = (dims[:altura_cm] * 10) - dims[:rodape_mm] - (dims[:espessura_real_cm] * 20)
        vao_prof_mm = dims[:profundidade_cm] * 10

        if vao_largura_mm < mins[:largura]
          alertas << {
            nivel: :erro,
            categoria: :estrutural,
            peca: 'Modulo',
            mensagem: "Vao interno largura (#{vao_largura_mm.round}mm) menor que minimo para #{tipo} (#{mins[:largura]}mm)",
            sugestao: "Aumentar largura do modulo para pelo menos #{((mins[:largura] + dims[:espessura_real_cm] * 20) / 10.0).round(1)}cm"
          }
        end

        if vao_altura_mm < mins[:altura]
          alertas << {
            nivel: :erro,
            categoria: :estrutural,
            peca: 'Modulo',
            mensagem: "Vao interno altura (#{vao_altura_mm.round}mm) menor que minimo para #{tipo} (#{mins[:altura]}mm)",
            sugestao: "Aumentar altura do modulo"
          }
        end

        if mins[:profundidade] && vao_prof_mm < mins[:profundidade]
          alertas << {
            nivel: :erro,
            categoria: :estrutural,
            peca: 'Modulo',
            mensagem: "Profundidade (#{vao_prof_mm.round}mm) menor que minimo para #{tipo} (#{mins[:profundidade]}mm)",
            sugestao: "Aumentar profundidade do modulo"
          }
        end

        alertas
      end

      def self.validar_dimensoes_chapa(peca_def, tipo_peca)
        alertas = []
        comp = (peca_def.get_attribute('dynamic_attributes', 'orn_corte_comp') || 0).to_f
        larg = (peca_def.get_attribute('dynamic_attributes', 'orn_corte_larg') || 0).to_f
        nome = peca_def.get_attribute('dynamic_attributes', 'orn_nome') || tipo_peca

        if comp > CHAPA_MAX[:comprimento_mm]
          alertas << {
            nivel: :aviso,
            categoria: :material,
            mensagem: "#{nome}: comprimento #{comp.round}mm excede chapa padrao (#{CHAPA_MAX[:comprimento_mm]}mm)",
            peca: nome,
            sugestao: 'Verificar se existe chapa disponivel ou dividir a peca'
          }
        end

        if larg > CHAPA_MAX[:largura_mm]
          alertas << {
            nivel: :aviso,
            categoria: :material,
            mensagem: "#{nome}: largura #{larg.round}mm excede chapa padrao (#{CHAPA_MAX[:largura_mm]}mm)",
            peca: nome,
            sugestao: 'Verificar dimensoes ou dividir a peca'
          }
        end

        # Validar viabilidade com grao (comprimento ao longo da chapa)
        grao = peca_def.get_attribute('dynamic_attributes', 'orn_grao')
        if grao && grao.to_s == 'comprimento' && comp > 0 && larg > 0
          # Com grao no comprimento: comp deve caber no comprimento da chapa
          if comp > CHAPA_MAX[:comprimento_mm] && larg <= CHAPA_MAX[:largura_mm]
            alertas << {
              nivel: :aviso,
              categoria: :material,
              peca: nome,
              mensagem: "#{nome}: com grao no comprimento, #{comp.round}mm nao cabe na chapa (#{CHAPA_MAX[:comprimento_mm]}mm)",
              sugestao: 'Considerar rotacionar o grao ou dividir a peca'
            }
          end
        elsif grao && grao.to_s == 'largura' && comp > 0 && larg > 0
          # Com grao na largura: comp cabe na largura da chapa (1850mm)
          if comp > CHAPA_MAX[:largura_mm]
            alertas << {
              nivel: :aviso,
              categoria: :material,
              peca: nome,
              mensagem: "#{nome}: com grao na largura, #{comp.round}mm nao cabe (max #{CHAPA_MAX[:largura_mm]}mm nessa direcao)",
              sugestao: 'Considerar rotacionar o grao ou dividir a peca'
            }
          end
        end

        alertas
      end

      def self.validar_porta(peca_def, dims)
        alertas = []
        peso = calcular_peso_kg(peca_def)
        altura_mm = (dims[:altura_cm] * 10) - dims[:rodape_mm]
        nome = peca_def.get_attribute('dynamic_attributes', 'orn_nome') || 'Porta'

        qtd_necessaria = qtd_dobradicas_necessarias(peso, altura_mm)

        # Contar dobradicas existentes no modulo pai
        # (isso seria lido do parent, simplificado aqui)
        if peso > 28
          alertas << {
            nivel: :aviso,
            categoria: :ferragem,
            mensagem: "#{nome}: peso estimado #{peso.round(1)}kg — verificar capacidade das dobradicas",
            peca: nome,
            sugestao: "Recomendado #{qtd_necessaria} dobradicas ou usar dobradica reforcada"
          }
        end

        if altura_mm > 2200
          alertas << {
            nivel: :aviso,
            categoria: :estrutural,
            mensagem: "#{nome}: altura #{altura_mm.round}mm — porta muito alta, risco de empenamento",
            peca: nome,
            sugestao: "Considerar dividir em 2 portas ou usar espessura 25mm"
          }
        end

        # Largura da porta: se muito larga, risco de empenamento e torque na dobradica
        largura_porta = (peca_def.get_attribute('dynamic_attributes', 'orn_corte_larg') || 0).to_f
        if largura_porta > 600
          alertas << {
            nivel: :aviso,
            categoria: :estrutural,
            mensagem: "#{nome}: largura #{largura_porta.round}mm — porta larga demais, risco de empenamento",
            peca: nome,
            sugestao: "Considerar dividir em 2 portas (max recomendado 600mm)"
          }
        end

        alertas
      end

      def self.validar_gaveta(peca_def, dims, parent_def)
        alertas = []
        prof_mm = dims[:profundidade_cm] * 10
        tipo_corr = parent_def.get_attribute('dynamic_attributes', 'orn_tipo_corredica') || 'telescopica'

        caps = CAPACIDADE_CORREDICA[tipo_corr.to_sym]
        if caps && prof_mm > caps[:prof_max_mm]
          alertas << {
            nivel: :aviso,
            categoria: :ferragem,
            peca: 'Gaveta',
            mensagem: "Gaveta: profundidade #{prof_mm.round}mm excede maximo da corredica #{tipo_corr} (#{caps[:prof_max_mm]}mm)",
            sugestao: "Trocar para corredica com maior profundidade (oculta ou tandembox)"
          }
        end

        # Validar peso estimado da gaveta vs capacidade da corredica
        if caps
          peso_frente = calcular_peso_kg(peca_def)
          # Gaveta cheia: peso frente * 5 (estimativa conservadora com conteudo)
          peso_estimado = peso_frente * 5
          if peso_estimado > caps[:kg]
            alertas << {
              nivel: :aviso,
              categoria: :ferragem,
              peca: 'Gaveta',
              mensagem: "Gaveta: peso estimado #{peso_estimado.round(1)}kg pode exceder capacidade da #{tipo_corr} (#{caps[:kg]}kg)",
              sugestao: sugerir_corredica(peso_estimado, prof_mm).to_s.gsub('_', ' ')
            }
          end
        end

        alertas
      end

      # Vao maximo seguro por espessura (mm) — MDF padrao com carga domestica (~30kg/m)
      VAO_MAX_SEGURO = {
        6  => 200,    # HDF — apenas fundo
        15 => 450,    # MDF 15mm
        18 => 650,    # MDF 18mm
        25 => 950,    # MDF 25mm
        30 => 1100,   # MDF 30mm
        36 => 1300,   # MDF 36mm
      }.freeze

      def self.validar_prateleira(peca_def, dims, parent_def)
        alertas = []
        nome = peca_def.get_attribute('dynamic_attributes', 'orn_nome') || 'Prateleira'

        # Calcular vao real considerando divisorias
        num_divisorias = contar_divisorias(parent_def)
        largura_interna_mm = (dims[:largura_cm] - 2 * dims[:espessura_real_cm]) * 10
        if num_divisorias > 0
          # Vao por compartimento: (largura_interna - N*espessura_divisoria) / (N+1)
          esp_div_mm = dims[:espessura_real_cm] * 10
          vao_largura_mm = (largura_interna_mm - num_divisorias * esp_div_mm) / (num_divisorias + 1)
        else
          vao_largura_mm = largura_interna_mm
        end

        # Espessura da prateleira (pode ser diferente do corpo)
        esp_prat = peca_def.get_attribute('dynamic_attributes', 'orn_espessura')
        if esp_prat.nil?
          # Fallback: usar espessura do corpo (em cm, converter para mm)
          esp_corpo_cm = (parent_def.get_attribute('dynamic_attributes', 'orn_espessura_corpo') || 1.8).to_f
          esp_prat = esp_corpo_cm * 10  # cm → mm
        end
        esp_prat_f = esp_prat.to_f
        # Se valor parece estar em cm (< 10), converter para mm
        esp_prat_mm = esp_prat_f < 10 ? (esp_prat_f * 10).round.to_i : esp_prat_f.round.to_i

        # Buscar vao maximo seguro para esta espessura
        vao_seguro = VAO_MAX_SEGURO[esp_prat_mm] || VAO_MAX_SEGURO.min_by { |k, _| (k - esp_prat_mm).abs }[1]

        if vao_largura_mm > vao_seguro * 1.3  # > 130% do seguro = erro
          alertas << {
            nivel: :erro,
            categoria: :estrutural,
            mensagem: "#{nome}: vao #{vao_largura_mm.round}mm EXCEDE limite seguro (#{vao_seguro}mm) para #{esp_prat_mm}mm",
            peca: nome,
            sugestao: "Adicionar divisoria central, usar espessura maior, ou reduzir vao"
          }
        elsif vao_largura_mm > vao_seguro  # > 100% = aviso
          alertas << {
            nivel: :aviso,
            categoria: :estrutural,
            mensagem: "#{nome}: vao #{vao_largura_mm.round}mm proximo do limite (#{vao_seguro}mm) para #{esp_prat_mm}mm",
            peca: nome,
            sugestao: "Considerar espessura maior ou divisoria de apoio"
          }
        end

        alertas
      end

      def self.validar_basculante(parent_def, dims)
        alertas = []
        # Verificar se tem porta basculante
        tem_basculante = false
        parent_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          subtipo = entity.definition.get_attribute('dynamic_attributes', 'orn_subtipo')
          if subtipo == 'basculante'
            tem_basculante = true
            peso = calcular_peso_kg(entity.definition)
            largura_mm = dims[:largura_cm] * 10
            altura_mm = (dims[:altura_cm] * 10) - dims[:rodape_mm]

            tipo_art = parent_def.get_attribute('dynamic_attributes', 'orn_tipo_articulador') || 'aventos_hf'
            receita = if defined?(HardwareSwapper::ARTICULADOR_RECEITAS)
                        HardwareSwapper::ARTICULADOR_RECEITAS[tipo_art.to_sym]
                      else
                        nil
                      end
            if receita
              if peso > receita[:peso_porta_max_kg]
                alertas << {
                  nivel: :aviso,
                  categoria: :ferragem,
                  peca: 'Basculante',
                  mensagem: "Basculante: peso #{peso.round(1)}kg excede maximo do #{receita[:descricao]} (#{receita[:peso_porta_max_kg]}kg)",
                  sugestao: "Trocar para articulador com maior capacidade"
                }
              end
              if altura_mm > receita[:altura_porta_max_mm]
                alertas << {
                  nivel: :aviso,
                  categoria: :ferragem,
                  peca: 'Basculante',
                  mensagem: "Basculante: altura #{altura_mm.round}mm excede maximo (#{receita[:altura_porta_max_mm]}mm)",
                  sugestao: "Reduzir altura ou trocar tipo de articulador"
                }
              end
            end
            break
          end
        end

        alertas
      end

      # Conta divisorias internas de um modulo.
      def self.contar_divisorias(parent_def)
        count = 0
        parent_def.entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.respond_to?(:definition)
          tipo = entity.definition.get_attribute('dynamic_attributes', 'orn_tipo_peca')
          count += 1 if tipo == 'divisoria'
        end
        count
      end

      # Valida fundo vs espessura do corpo
      def self.validar_fundo(tipo_fundo, dims)
        alertas = []
        return alertas if tipo_fundo.to_s.empty?

        esp_mm = dims[:espessura_real_cm] * 10

        # Fundo encaixado precisa de canal — lateral deve ter espessura suficiente
        if tipo_fundo == 'encaixado'
          # Canal padrao: 8mm profundidade, 3-6mm largura
          # Lateral precisa ter pelo menos 15mm para canal de 8mm + 7mm restante
          if esp_mm < 15
            alertas << {
              nivel: :aviso,
              categoria: :estrutural,
              peca: 'Fundo',
              mensagem: "Fundo encaixado com lateral de #{esp_mm.round}mm — canal pode enfraquecer a lateral",
              sugestao: "Use espessura minima de 15mm para fundo encaixado, ou troque para fundo sobreposto"
            }
          end
        end

        # Fundo sobreposto em modulos grandes pode precisar de reforco
        if tipo_fundo == 'sobreposto'
          larg_mm = dims[:largura_mm] || (dims[:largura_cm] * 10).round
          alt_mm = dims[:altura_mm] || (dims[:altura_cm] * 10).round
          diagonal = Math.sqrt(larg_mm**2 + alt_mm**2)
          if diagonal > 2000
            alertas << {
              nivel: :aviso,
              categoria: :material,
              peca: 'Fundo',
              mensagem: "Diagonal do fundo #{diagonal.round}mm — considere fundo em HDF 6mm ou travessa central",
              sugestao: "Fundos grandes em HDF 3mm tendem a estufar"
            }
          end
        end

        alertas
      end

      # Valida que furacao S32 cabe na lateral
      # Setback padrao 37mm; se profundidade interna < 2*setback, furos nao cabem
      def self.validar_furacao_s32(dims)
        alertas = []
        prof_interna_mm = (dims[:profundidade_cm] - dims[:espessura_real_cm]) * 10
        setback = 37.0 # GlobalConfig default

        if prof_interna_mm < setback * 2 + 10
          alertas << {
            nivel: :aviso,
            categoria: :furacao,
            peca: 'Lateral',
            mensagem: "Profundidade interna (#{prof_interna_mm.round}mm) insuficiente para 2 linhas S32 (min #{(setback * 2 + 10).round}mm)",
            sugestao: "Use 1 linha de furos ou aumente a profundidade"
          }
        end

        # Altura minima para ter pelo menos 4 furos S32
        altura_interna_mm = (dims[:altura_cm] * 10) - dims[:rodape_mm] - (dims[:espessura_real_cm] * 20)
        min_furos_mm = setback * 2 + 32 * 3 # 37 + 3*32 + 37 = 170mm
        if altura_interna_mm < min_furos_mm
          alertas << {
            nivel: :aviso,
            categoria: :furacao,
            peca: 'Lateral',
            mensagem: "Altura interna (#{altura_interna_mm.round}mm) permite menos de 4 furos S32",
            sugestao: "Prateleiras regulaveis podem nao ser viaveis neste modulo"
          }
        end

        alertas
      end

    end
  end
end
