# ornato_plugin/engines/motor_portas.rb — Modelos de portas especiais
# Specs construtivas reais: Blum CLIP top, Hettich, padrões industriais

module Ornato
  module Engines
    class MotorPortas

      # Tipos de porta disponíveis com specs construtivas reais
      TIPOS_PORTA = {
        lisa: {
          nome: 'Lisa (Slab)',
          descricao: 'Porta inteira, sem fresagem. Fita 4 lados.',
          usa_quadro: false,
          usinagem: :nenhuma,
          # Somente caneco + fita. Opção de gola/J-pull no topo.
          fita_bordas: 4   # todas as bordas
        },
        provencal: {
          nome: 'Provençal (Shaker)',
          descricao: 'Quadro fresado simulando moldura. MDF peça única.',
          usa_quadro: false,
          usinagem: :fresagem_quadro,
          # Specs Config::PORTA_PROVENCAL
          largura_stile: 60,      # mm (55-65)
          largura_rail: 60,       # mm
          pocket_prof: 7,         # mm (fresagem na face)
          raio_canto: 8,          # mm
          fita_bordas: 4
        },
        almofadada: {
          nome: 'Almofadada (Raised Panel)',
          descricao: 'Fresagem almofada em relevo. MDF peça única.',
          usa_quadro: false,
          usinagem: :fresagem_almofada,
          # Specs Config::PORTA_ALMOFADADA
          largura_stile: 60,      # mm (55-70)
          profundidade_fresa: 4,  # mm
          fita_bordas: 4
        },
        vidro: {
          nome: 'Vidro (quadro MDF + vidro)',
          descricao: 'Quadro MDF com recorte central e vidro encaixado.',
          usa_quadro: true,
          usinagem: :recorte_vidro,
          # Specs Config::PORTA_VIDRO
          largura_quadro: 70,     # mm — stile/rail (padrão industrial 60-80)
          esp_vidro: 4,           # mm
          canal_vidro_larg: 5,    # mm (vidro + 1mm folga)
          canal_vidro_prof: 11,   # mm (10-12mm)
          fita_bordas: 4          # quadro tem fita nas 4 bordas externas
        },
        vidro_inteiro: {
          nome: 'Vidro Inteiro',
          descricao: 'Porta 100% vidro temperado, sem moldura MDF.',
          usa_quadro: false,
          usinagem: :nenhuma,
          material: :vidro,
          esp_vidro_padrao: 6,    # mm — temperado
          fita_bordas: 0          # vidro não leva fita
        },
        perfil_aluminio: {
          nome: 'Perfil Alumínio',
          descricao: 'Moldura alumínio com vidro ou MDF interno.',
          usa_quadro: false,
          usinagem: :nenhuma,
          material_moldura: :aluminio,
          # Specs Config::PORTA_PERFIL_AL
          larguras_perfil: [3, 8, 19],  # mm — slim, standard, wide (Hettich)
          esp_vidro: [4, 5, 6],         # mm aceitos
          acabamentos: %w[Natural Preto Creme Cinza],
          fita_bordas: 0                # alumínio não leva fita
        },
        veneziana: {
          nome: 'Veneziana (Louvered)',
          descricao: 'Quadro MDF com ripas inclinadas para ventilação.',
          usa_quadro: true,
          usinagem: :rasgos_veneziana,
          # Specs Config::PORTA_VENEZIANA
          largura_quadro: 55,     # mm
          angulo_ripa: 20,        # graus (17-25, padrão 20)
          esp_ripa: 6,            # mm
          largura_ripa: 30,       # mm
          mortise_prof: 11,       # mm (7/16")
          fita_bordas: 4
        },
        ripada: {
          nome: 'Ripada Vertical',
          descricao: 'Ripas verticais coladas sobre base MDF.',
          usa_quadro: false,
          usinagem: :ripado,
          largura_ripa_padrao: 30,   # mm
          espessura_ripa_padrao: 15, # mm
          espaco_ripas_padrao: 10,   # mm
          fita_bordas: 0             # ripas não levam fita individual
        },
        cego: {
          nome: 'Cego (sem porta)',
          descricao: 'Vão aberto, sem porta instalada.',
          usa_quadro: false,
          fita_bordas: 0
        }
      }.freeze

      # ═══════════════════════════════════════════════
      # CONSTRUTOR PRINCIPAL
      # ═══════════════════════════════════════════════
      def self.construir_porta(modulo_info, vao, tipo_porta, opts = {})
        case tipo_porta
        when :lisa       then construir_porta_lisa(modulo_info, vao, opts)
        when :provencal  then construir_porta_provencal(modulo_info, vao, opts)
        when :almofadada then construir_porta_almofadada(modulo_info, vao, opts)
        when :vidro      then construir_porta_vidro(modulo_info, vao, opts)
        when :vidro_inteiro then construir_porta_vidro_inteiro(modulo_info, vao, opts)
        when :perfil_aluminio then construir_porta_perfil_aluminio(modulo_info, vao, opts)
        when :veneziana  then construir_porta_veneziana(modulo_info, vao, opts)
        when :ripada     then construir_porta_ripada(modulo_info, vao, opts)
        when :cego       then nil  # sem porta
        else construir_porta_lisa(modulo_info, vao, opts)
        end
      end

      # Calcula dimensões da porta conforme sobreposição
      def self.calcular_dim_porta(mi, vao, opts = {})
        folga = opts[:folga] || Config::FOLGA_PORTA
        sobreposicao = opts[:sobreposicao] || Config::SOBREP_TOTAL

        case sobreposicao
        when Config::SOBREP_TOTAL
          {
            larg: vao.largura + (2 * mi.espessura_corpo) - (2 * folga),
            alt:  vao.altura + (2 * mi.espessura_corpo) - (2 * folga),
            x:    vao.x - mi.espessura_corpo + folga,
            z:    vao.z - mi.espessura_corpo + folga
          }
        when Config::SOBREP_MEIA
          {
            larg: vao.largura + mi.espessura_corpo - (2 * folga),
            alt:  vao.altura + (2 * mi.espessura_corpo) - (2 * folga),
            x:    vao.x - (mi.espessura_corpo / 2.0) + folga,
            z:    vao.z - mi.espessura_corpo + folga
          }
        when Config::SOBREP_INTERNA
          {
            larg: vao.largura - (2 * folga),
            alt:  vao.altura - (2 * folga),
            x:    vao.x + folga,
            z:    vao.z + folga
          }
        end
      end

      private

      # ─── PORTA LISA ───
      def self.construir_porta_lisa(mi, vao, opts)
        grupo_porta = MotorAgregados.adicionar_porta(mi, vao, opts)
        return nil unless grupo_porta

        peca_porta = mi.pecas.select { |p| p.tipo == :porta }.last
        if peca_porta && peca_porta.grupo_ref
          peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'lisa')

          # Gera usinagens: caneco dobradiça
          qtd_dob = Utils.qtd_dobradicas(peca_porta.comprimento)
          posicoes = MotorUsinagem.send(:calcular_posicoes_dobradica, peca_porta.comprimento, qtd_dob)
          usinagens = MotorUsinagem.pocket_dobradica(peca_porta, posicoes)
          peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'usinagens_count', usinagens.length)
        end

        grupo_porta
      end

      # ─── PORTA PROVENÇAL / SHAKER ───
      # MDF peça única com pocket na face simulando moldura
      # Specs: stile 60mm, pocket 7mm prof, raio canto 8mm
      def self.construir_porta_provencal(mi, vao, opts)
        grupo_porta = MotorAgregados.adicionar_porta(mi, vao, opts)
        return nil unless grupo_porta

        peca_porta = mi.pecas.select { |p| p.tipo == :porta }.last
        if peca_porta
          spec = Config::PORTA_PROVENCAL
          margem = opts[:margem_provencal] || spec[:largura_stile]

          # Usinagens: fresagem provençal + caneco
          usinagens = MotorUsinagem.fresagem_provencal(peca_porta,
            margem: margem,
            largura: opts[:largura_fresa] || 10,
            profundidade: opts[:profundidade_fresa] || spec[:pocket_prof],
            raio_canto: opts[:raio_canto] || spec[:raio_canto]
          )

          # Caneco de dobradiça
          qtd_dob = Utils.qtd_dobradicas(peca_porta.comprimento)
          posicoes = MotorUsinagem.send(:calcular_posicoes_dobradica, peca_porta.comprimento, qtd_dob)
          usinagens += MotorUsinagem.pocket_dobradica(peca_porta, posicoes)

          if peca_porta.grupo_ref
            peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'provencal')
            peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'usinagens_count', usinagens.length)
            peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'fresagem_margem', margem)
          end

          desenhar_fresagem_provencal(grupo_porta, peca_porta, margem, mi) if grupo_porta
        end

        grupo_porta
      end

      # ─── PORTA ALMOFADADA ───
      # MDF peça única com fresagem almofadada (raised panel simulado)
      def self.construir_porta_almofadada(mi, vao, opts)
        grupo_porta = MotorAgregados.adicionar_porta(mi, vao, opts)
        return nil unless grupo_porta

        peca_porta = mi.pecas.select { |p| p.tipo == :porta }.last
        if peca_porta
          spec = Config::PORTA_ALMOFADADA

          # Usinagens: fresagem almofadada + caneco
          usinagens = MotorUsinagem.fresagem_almofadada(peca_porta,
            margem: opts[:margem] || spec[:largura_stile],
            profundidade: opts[:profundidade] || 4
          )

          qtd_dob = Utils.qtd_dobradicas(peca_porta.comprimento)
          posicoes = MotorUsinagem.send(:calcular_posicoes_dobradica, peca_porta.comprimento, qtd_dob)
          usinagens += MotorUsinagem.pocket_dobradica(peca_porta, posicoes)

          if peca_porta.grupo_ref
            peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'almofadada')
            peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'usinagens_count', usinagens.length)
          end
        end

        grupo_porta
      end

      # ─── PORTA COM VIDRO (quadro MDF) ───
      # Specs reais: quadro 70mm, canal vidro 5mm × 11mm prof
      def self.construir_porta_vidro(mi, vao, opts)
        grupo = mi.grupo_ref
        return nil unless grupo

        spec         = Config::PORTA_VIDRO
        esp          = opts[:espessura] || mi.espessura_corpo
        material     = opts[:material] || mi.material_frente
        esp_vidro    = opts[:esp_vidro] || spec[:esp_vidro]          # 4mm
        larg_quadro  = opts[:largura_quadro] || spec[:largura_quadro] # 70mm
        folga        = opts[:folga] || Config::FOLGA_PORTA
        sobreposicao = opts[:sobreposicao] || Config::SOBREP_TOTAL
        material_vidro = opts[:material_vidro] || 'Vidro Incolor 4mm'

        dim = calcular_dim_porta(mi, vao, opts)
        porta_larg = dim[:larg]
        porta_alt  = dim[:alt]
        porta_x    = dim[:x]
        porta_z    = dim[:z]
        porta_y    = -esp

        model = Sketchup.active_model
        mat_frente = Utils.criar_material(model, "Ornato_Frente_#{material}", Config::COR_FRENTE)
        mat_vidro  = Utils.criar_material(model, "Ornato_Vidro_#{material_vidro}",
          Sketchup::Color.new(220, 240, 245, 80))

        porta_grupo = grupo.entities.add_group
        porta_grupo.name = 'Porta Vidro'

        # QUADRO MDF (4 peças: 2 montantes + 2 travessas)
        # Montante esquerdo
        MotorAgregados.criar_sub_peca(porta_grupo, mat_frente,
          x: porta_x, y: porta_y, z: porta_z,
          larg: larg_quadro, prof: esp, alt: porta_alt,
          nome: 'Montante ESQ')

        # Montante direito
        MotorAgregados.criar_sub_peca(porta_grupo, mat_frente,
          x: porta_x + porta_larg - larg_quadro, y: porta_y, z: porta_z,
          larg: larg_quadro, prof: esp, alt: porta_alt,
          nome: 'Montante DIR')

        # Travessa superior (entre montantes)
        trav_larg = porta_larg - (2 * larg_quadro)
        MotorAgregados.criar_sub_peca(porta_grupo, mat_frente,
          x: porta_x + larg_quadro, y: porta_y, z: porta_z + porta_alt - larg_quadro,
          larg: trav_larg, prof: esp, alt: larg_quadro,
          nome: 'Travessa SUP')

        # Travessa inferior
        MotorAgregados.criar_sub_peca(porta_grupo, mat_frente,
          x: porta_x + larg_quadro, y: porta_y, z: porta_z,
          larg: trav_larg, prof: esp, alt: larg_quadro,
          nome: 'Travessa INF')

        # VIDRO (encaixado no canal do quadro)
        encaixe = spec[:canal_vidro_prof]  # 11mm — quanto o vidro entra no canal
        vidro_larg = porta_larg - (2 * larg_quadro) + (2 * (encaixe - 1))  # -1mm folga
        vidro_alt  = porta_alt - (2 * larg_quadro) + (2 * (encaixe - 1))
        vidro_x    = porta_x + larg_quadro - (encaixe - 1)
        vidro_z    = porta_z + larg_quadro - (encaixe - 1)
        vidro_y    = porta_y + (esp - esp_vidro) / 2.0

        MotorAgregados.criar_sub_peca(porta_grupo, mat_vidro,
          x: vidro_x, y: vidro_y, z: vidro_z,
          larg: vidro_larg, prof: esp_vidro, alt: vidro_alt,
          nome: 'Vidro')

        # Atributos
        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'tipo', 'porta')
        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'vidro')
        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'vao_id', vao.id)

        # Peças de corte — quadro MDF
        mi.pecas << Models::Peca.new(
          nome: 'Montante Porta Vidro', comprimento: porta_alt.round(1), largura: larg_quadro,
          espessura: esp, material: material, tipo: :porta, quantidade: 2,
          fita_frente: true, fita_topo: true, fita_tras: true, fita_base: true,
          fita_material: mi.fita_frente)

        mi.pecas << Models::Peca.new(
          nome: 'Travessa Porta Vidro', comprimento: trav_larg.round(1), largura: larg_quadro,
          espessura: esp, material: material, tipo: :porta, quantidade: 2,
          fita_frente: true, fita_topo: true, fita_tras: true, fita_base: true,
          fita_material: mi.fita_frente)

        # Vidro e ferragens
        mi.ferragens << { nome: "#{material_vidro} #{vidro_larg.round(0)}x#{vidro_alt.round(0)}mm", tipo: :vidro, qtd: 1 }
        mi.ferragens << { nome: 'Grapas p/ vidro', tipo: :acessorio, qtd: 8 }

        # Dobradiças (Blum CLIP top 110° c/ amortecedor)
        qtd_dob = Utils.qtd_dobradicas(porta_alt)
        mi.ferragens << { nome: 'Dobradica Blum CLIP top 110 c/ amort.', tipo: :dobradica, qtd: qtd_dob }
        mi.ferragens << { nome: 'Calco Blum CLIP (37mm)', tipo: :calco, qtd: qtd_dob }

        # Usinagens registradas
        mi.ferragens << { nome: "Usinagem: canal vidro #{spec[:canal_vidro_largura]}x#{spec[:canal_vidro_prof]}mm", tipo: :usinagem, qtd: 4 }
        mi.ferragens << { nome: "Usinagem: caneco 35mm (#{qtd_dob}x)", tipo: :usinagem, qtd: qtd_dob }

        vao.adicionar_agregado({ tipo: :porta, subtipo: :vidro, grupo: porta_grupo })
        porta_grupo
      end

      # ─── PORTA VIDRO INTEIRO ───
      # Vidro temperado sem moldura — dobradiça especial para vidro
      def self.construir_porta_vidro_inteiro(mi, vao, opts)
        grupo = mi.grupo_ref
        return nil unless grupo

        esp_vidro = opts[:esp_vidro] || 6  # temperado 6mm
        material_vidro = opts[:material_vidro] || 'Vidro Temperado Incolor 6mm'
        folga = opts[:folga] || Config::FOLGA_PORTA

        dim = calcular_dim_porta(mi, vao, folga: folga, sobreposicao: Config::SOBREP_TOTAL)
        porta_larg = dim[:larg]
        porta_alt  = dim[:alt]
        porta_x    = dim[:x]
        porta_z    = dim[:z]
        porta_y    = -esp_vidro

        model = Sketchup.active_model
        mat_vidro = Utils.criar_material(model, "Ornato_Vidro_#{material_vidro}",
          Sketchup::Color.new(220, 240, 245, 100))

        porta_grupo = grupo.entities.add_group
        porta_grupo.name = 'Porta Vidro Inteiro'

        MotorAgregados.criar_sub_peca(porta_grupo, mat_vidro,
          x: porta_x, y: porta_y, z: porta_z,
          larg: porta_larg, prof: esp_vidro, alt: porta_alt,
          nome: 'Vidro Temperado')

        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'tipo', 'porta')
        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'vidro_inteiro')
        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'vao_id', vao.id)

        qtd_dob = Utils.qtd_dobradicas(porta_alt)
        mi.ferragens << { nome: "#{material_vidro} #{porta_larg.round(0)}x#{porta_alt.round(0)}mm", tipo: :vidro, qtd: 1 }
        mi.ferragens << { nome: 'Dobradica p/ vidro 110 c/ amort.', tipo: :dobradica, qtd: qtd_dob }
        mi.ferragens << { nome: 'Puxador p/ vidro', tipo: :puxador, qtd: 1 }

        vao.adicionar_agregado({ tipo: :porta, subtipo: :vidro_inteiro, grupo: porta_grupo })
        porta_grupo
      end

      # ─── PORTA PERFIL ALUMÍNIO ───
      # Perfis cortados e montados com conectores de canto
      # Specs: Hettich — perfis 3/8/19mm, acabamentos Natural/Preto/Creme/Cinza
      def self.construir_porta_perfil_aluminio(mi, vao, opts)
        grupo = mi.grupo_ref
        return nil unless grupo

        spec = Config::PORTA_PERFIL_AL
        cor_perfil     = opts[:cor_perfil] || 'Natural'
        largura_perfil = opts[:largura_perfil] || 19  # mm — wide (padrão)
        material_vidro = opts[:material_vidro] || 'Vidro Incolor 4mm'
        folga          = opts[:folga] || Config::FOLGA_PORTA
        esp_vidro      = opts[:esp_vidro] || 4

        dim = calcular_dim_porta(mi, vao, folga: folga, sobreposicao: Config::SOBREP_TOTAL)
        porta_larg = dim[:larg]
        porta_alt  = dim[:alt]
        porta_x    = dim[:x]
        porta_z    = dim[:z]
        porta_y    = -largura_perfil

        model = Sketchup.active_model
        mat_al = Utils.criar_material(model, "Ornato_Aluminio_#{cor_perfil}",
          Sketchup::Color.new(195, 195, 200))
        mat_vidro = Utils.criar_material(model, "Ornato_Vidro_#{material_vidro}",
          Sketchup::Color.new(220, 240, 245, 80))

        porta_grupo = grupo.entities.add_group
        porta_grupo.name = "Porta Perfil Al #{cor_perfil}"

        # Perfis do quadro
        MotorAgregados.criar_sub_peca(porta_grupo, mat_al,
          x: porta_x, y: porta_y, z: porta_z,
          larg: largura_perfil, prof: largura_perfil, alt: porta_alt,
          nome: 'Perfil ESQ')
        MotorAgregados.criar_sub_peca(porta_grupo, mat_al,
          x: porta_x + porta_larg - largura_perfil, y: porta_y, z: porta_z,
          larg: largura_perfil, prof: largura_perfil, alt: porta_alt,
          nome: 'Perfil DIR')
        MotorAgregados.criar_sub_peca(porta_grupo, mat_al,
          x: porta_x + largura_perfil, y: porta_y, z: porta_z + porta_alt - largura_perfil,
          larg: porta_larg - (2 * largura_perfil), prof: largura_perfil, alt: largura_perfil,
          nome: 'Perfil SUP')
        MotorAgregados.criar_sub_peca(porta_grupo, mat_al,
          x: porta_x + largura_perfil, y: porta_y, z: porta_z,
          larg: porta_larg - (2 * largura_perfil), prof: largura_perfil, alt: largura_perfil,
          nome: 'Perfil INF')

        # Vidro
        vidro_larg = porta_larg - (2 * largura_perfil) + 10
        vidro_alt  = porta_alt - (2 * largura_perfil) + 10
        MotorAgregados.criar_sub_peca(porta_grupo, mat_vidro,
          x: porta_x + largura_perfil - 5, y: porta_y + (largura_perfil - esp_vidro) / 2.0,
          z: porta_z + largura_perfil - 5,
          larg: vidro_larg, prof: esp_vidro, alt: vidro_alt,
          nome: 'Vidro')

        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'tipo', 'porta')
        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'perfil_aluminio')
        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'vao_id', vao.id)

        # Ferragens
        mi.ferragens << { nome: "Perfil aluminio #{cor_perfil} #{largura_perfil}mm — #{porta_larg.round(0)}x#{porta_alt.round(0)}", tipo: :perfil_aluminio, qtd: 1 }
        mi.ferragens << { nome: "#{material_vidro} #{vidro_larg.round(0)}x#{vidro_alt.round(0)}mm", tipo: :vidro, qtd: 1 }
        mi.ferragens << { nome: 'Conector canto perfil aluminio', tipo: :conector, qtd: 4 }
        mi.ferragens << { nome: 'Dobradica Blum CLIP top aluminio 95', tipo: :dobradica, qtd: Utils.qtd_dobradicas(porta_alt) }

        vao.adicionar_agregado({ tipo: :porta, subtipo: :perfil_aluminio, grupo: porta_grupo })
        porta_grupo
      end

      # ─── PORTA VENEZIANA ───
      # Quadro MDF com rasgos para ripas inclinadas
      # Specs: ângulo 20°, ripa 6mm × 30mm, mortise 11mm prof
      def self.construir_porta_veneziana(mi, vao, opts)
        spec = Config::PORTA_VENEZIANA
        grupo_porta = MotorAgregados.adicionar_porta(mi, vao, opts)
        return nil unless grupo_porta

        peca_porta = mi.pecas.select { |p| p.tipo == :porta }.last
        if peca_porta && peca_porta.grupo_ref
          peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'veneziana')

          # Calcula quantidade de ripas com espaçamento real
          angulo_rad = spec[:angulo_ripa] * Math::PI / 180.0
          espacamento = ((spec[:esp_stile] + spec[:esp_ripa]) / Math.sin(angulo_rad)).round(1)

          alt_util = peca_porta.comprimento - (2 * spec[:largura_quadro]) - 30  # margens
          qtd_ripas = (alt_util / espacamento).floor

          # Largura da ripa = largura útil interna (entre montantes)
          larg_ripa = peca_porta.largura - (2 * spec[:largura_quadro]) + (2 * (spec[:mortise_prof] - 2))

          mi.ferragens << { nome: "Ripa veneziana #{larg_ripa.round(0)}x#{spec[:largura_ripa]}x#{spec[:esp_ripa]}mm", tipo: :ripa, qtd: qtd_ripas }
          mi.ferragens << { nome: "Usinagem: rasgos veneziana #{spec[:angulo_ripa]} (#{qtd_ripas * 2}x)", tipo: :usinagem, qtd: qtd_ripas * 2 }

          # Registra usinagens
          usinagens = MotorUsinagem.rasgos_veneziana(peca_porta,
            angulo: spec[:angulo_ripa],
            espessura_ripa: spec[:esp_ripa],
            largura_ripa: spec[:largura_ripa],
            profundidade: spec[:mortise_prof],
            largura_quadro: spec[:largura_quadro]
          )
          peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'usinagens_count', usinagens.length)
        end

        grupo_porta
      end

      # ─── PORTA RIPADA ───
      # Ripas verticais coladas sobre base MDF
      def self.construir_porta_ripada(mi, vao, opts)
        grupo_porta = MotorAgregados.adicionar_porta(mi, vao, opts)
        return nil unless grupo_porta

        peca_porta = mi.pecas.select { |p| p.tipo == :porta }.last
        if peca_porta && peca_porta.grupo_ref
          peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'ripada')

          larg_ripa  = opts[:largura_ripa]   || 30
          esp_ripa   = opts[:espessura_ripa] || 15
          espaco     = opts[:espaco_ripas]   || 10
          qtd_ripas  = ((peca_porta.largura) / (larg_ripa + espaco)).floor

          mi.ferragens << { nome: "Ripa #{peca_porta.comprimento.round(0)}x#{larg_ripa}x#{esp_ripa}mm", tipo: :ripa, qtd: qtd_ripas }
          mi.ferragens << { nome: 'Cola PVA ripas', tipo: :acessorio, qtd: 1 }
        end

        grupo_porta
      end

      # ─── Helper: marca fresagem provençal na geometria ───
      def self.desenhar_fresagem_provencal(grupo_porta, peca, margem, mi)
        grupo_porta.set_attribute(Config::DICT_AGREGADO, 'fresagem', 'provencal')
        grupo_porta.set_attribute(Config::DICT_AGREGADO, 'fresagem_margem', margem)
      end

      # ─── Helper: lista de tipos disponíveis (para UI) ───
      def self.lista_tipos
        TIPOS_PORTA.map { |k, v| [k, v[:nome]] }
      end

      # ─── Helper: info de um tipo (para UI) ───
      def self.info_tipo(tipo)
        TIPOS_PORTA[tipo]
      end
    end
  end
end
