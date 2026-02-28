# ornato_plugin/engines/motor_portas.rb — Modelos de portas especiais

module Ornato
  module Engines
    class MotorPortas

      # Tipos de porta disponíveis
      TIPOS_PORTA = {
        lisa: {
          nome: 'Lisa (Slab)',
          descricao: 'Porta inteira, sem fresagem. Fita 4 lados.',
          usa_quadro: false,
          usinagem: :nenhuma
        },
        provencal: {
          nome: 'Provençal (Shaker)',
          descricao: 'Quadro fresado na face frontal, simulando moldura e almofada.',
          usa_quadro: false,
          usinagem: :fresagem_quadro,
          margem_padrao: 80,
          largura_fresa: 10,
          profundidade_fresa: 6,
          raio_canto: 8
        },
        almofadada: {
          nome: 'Almofadada',
          descricao: 'Fresagem de almofada em relevo na face frontal.',
          usa_quadro: false,
          usinagem: :fresagem_almofada,
          margem_padrao: 60,
          profundidade_fresa: 4
        },
        vidro: {
          nome: 'Vidro (quadro + vidro)',
          descricao: 'Porta em MDF com recorte central e vidro encaixado.',
          usa_quadro: true,
          usinagem: :recorte_vidro,
          largura_quadro: 60,
          esp_vidro: 4,
          prof_canal_vidro: 10
        },
        vidro_inteiro: {
          nome: 'Vidro Inteiro',
          descricao: 'Porta 100% vidro temperado, sem moldura MDF.',
          usa_quadro: false,
          usinagem: :nenhuma,
          material: :vidro
        },
        perfil_aluminio: {
          nome: 'Perfil Alumínio',
          descricao: 'Moldura de alumínio com vidro ou MDF interno.',
          usa_quadro: false,
          usinagem: :nenhuma,
          material_moldura: :aluminio
        },
        veneziana: {
          nome: 'Veneziana (Louvered)',
          descricao: 'Quadro MDF com ripas inclinadas para ventilação.',
          usa_quadro: true,
          usinagem: :rasgos_veneziana,
          largura_quadro: 50,
          angulo_ripa: 17,
          esp_ripa: 6,
          espacamento_ripa: 25
        },
        ripada: {
          nome: 'Ripada Vertical',
          descricao: 'Ripas verticais coladas sobre base MDF ou sem base.',
          usa_quadro: false,
          usinagem: :ripado
        },
        cego: {
          nome: 'Cego (sem porta)',
          descricao: 'Vão aberto, sem porta instalada.',
          usa_quadro: false
        }
      }.freeze

      # Constrói porta 3D conforme o tipo
      def self.construir_porta(modulo_info, vao, tipo_porta, opts = {})
        case tipo_porta
        when :lisa
          construir_porta_lisa(modulo_info, vao, opts)
        when :provencal
          construir_porta_provencal(modulo_info, vao, opts)
        when :almofadada
          construir_porta_almofadada(modulo_info, vao, opts)
        when :vidro
          construir_porta_vidro(modulo_info, vao, opts)
        when :vidro_inteiro
          construir_porta_vidro_inteiro(modulo_info, vao, opts)
        when :perfil_aluminio
          construir_porta_perfil_aluminio(modulo_info, vao, opts)
        when :veneziana
          construir_porta_veneziana(modulo_info, vao, opts)
        when :ripada
          construir_porta_ripada(modulo_info, vao, opts)
        else
          construir_porta_lisa(modulo_info, vao, opts)
        end
      end

      private

      # ─── PORTA LISA ───
      def self.construir_porta_lisa(mi, vao, opts)
        # Delega para o MotorAgregados existente
        MotorAgregados.adicionar_porta(mi, vao, opts)
      end

      # ─── PORTA PROVENÇAL ───
      def self.construir_porta_provencal(mi, vao, opts)
        grupo_porta = MotorAgregados.adicionar_porta(mi, vao, opts)
        return nil unless grupo_porta

        # Adiciona usinagem provençal
        peca_porta = mi.pecas.select { |p| p.tipo == :porta }.last
        if peca_porta
          config = TIPOS_PORTA[:provencal]
          margem = opts[:margem_provencal] || config[:margem_padrao]
          usinagens = MotorUsinagem.fresagem_provencal(peca_porta,
            margem: margem,
            largura: opts[:largura_fresa] || config[:largura_fresa],
            profundidade: opts[:profundidade_fresa] || config[:profundidade_fresa],
            raio_canto: opts[:raio_canto] || config[:raio_canto]
          )

          # Registra usinagens na peça (atributo no SketchUp)
          if peca_porta.grupo_ref
            peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'provencal')
            peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'usinagens_count', usinagens.length)
          end

          # Representação visual — fresa canais na geometria 3D
          desenhar_fresagem_provencal(grupo_porta, peca_porta, margem, mi) if grupo_porta
        end

        grupo_porta
      end

      # ─── PORTA ALMOFADADA ───
      def self.construir_porta_almofadada(mi, vao, opts)
        grupo_porta = MotorAgregados.adicionar_porta(mi, vao, opts)
        return nil unless grupo_porta

        peca_porta = mi.pecas.select { |p| p.tipo == :porta }.last
        if peca_porta && peca_porta.grupo_ref
          peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'almofadada')
        end

        grupo_porta
      end

      # ─── PORTA COM VIDRO ───
      def self.construir_porta_vidro(mi, vao, opts)
        grupo = mi.grupo_ref
        return nil unless grupo

        config = TIPOS_PORTA[:vidro]
        esp         = opts[:espessura] || mi.espessura_corpo
        material    = opts[:material] || mi.material_frente
        esp_vidro   = opts[:esp_vidro] || config[:esp_vidro]
        larg_quadro = opts[:largura_quadro] || config[:largura_quadro]
        folga       = opts[:folga] || Config::FOLGA_PORTA
        sobreposicao = opts[:sobreposicao] || Config::SOBREP_TOTAL
        material_vidro = opts[:material_vidro] || 'Vidro Incolor 4mm'

        # Calcula dimensões da porta (igual porta normal)
        case sobreposicao
        when Config::SOBREP_TOTAL
          porta_larg = vao.largura + (2 * mi.espessura_corpo) - (2 * folga)
          porta_alt  = vao.altura + (2 * mi.espessura_corpo) - (2 * folga)
          porta_x    = vao.x - mi.espessura_corpo + folga
          porta_z    = vao.z - mi.espessura_corpo + folga
        when Config::SOBREP_MEIA
          porta_larg = vao.largura + mi.espessura_corpo - (2 * folga)
          porta_alt  = vao.altura + (2 * mi.espessura_corpo) - (2 * folga)
          porta_x    = vao.x - (mi.espessura_corpo / 2.0) + folga
          porta_z    = vao.z - mi.espessura_corpo + folga
        when Config::SOBREP_INTERNA
          porta_larg = vao.largura - (2 * folga)
          porta_alt  = vao.altura - (2 * folga)
          porta_x    = vao.x + folga
          porta_z    = vao.z + folga
        end

        porta_y = -esp

        model = Sketchup.active_model
        mat_frente = Utils.criar_material(model, "Ornato_Frente_#{material}", Config::COR_FRENTE)
        mat_vidro  = Utils.criar_material(model, "Ornato_Vidro_#{material_vidro}",
          Sketchup::Color.new(220, 240, 245, 80))  # translúcido

        # Grupo porta com vidro
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

        # Travessa superior
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

        # VIDRO (no centro, mais fino)
        vidro_larg = porta_larg - (2 * larg_quadro) + 20  # 10mm encaixe cada lado
        vidro_alt  = porta_alt - (2 * larg_quadro) + 20
        vidro_x    = porta_x + larg_quadro - 10
        vidro_z    = porta_z + larg_quadro - 10
        vidro_y    = porta_y + (esp - esp_vidro) / 2.0

        MotorAgregados.criar_sub_peca(porta_grupo, mat_vidro,
          x: vidro_x, y: vidro_y, z: vidro_z,
          larg: vidro_larg, prof: esp_vidro, alt: vidro_alt,
          nome: 'Vidro')

        # Atributos
        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'tipo', 'porta')
        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'vidro')
        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'vao_id', vao.id)

        # Peças de corte — quadro
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

        # Vidro como material (não peça de corte MDF)
        mi.ferragens << { nome: "#{material_vidro} #{vidro_larg.round(0)}×#{vidro_alt.round(0)}mm", tipo: :vidro, qtd: 1 }
        mi.ferragens << { nome: 'Grapas p/ vidro', tipo: :acessorio, qtd: 8 }

        # Dobradiças
        qtd_dob = Utils.qtd_dobradicas(porta_alt)
        mi.ferragens << { nome: 'Dobradiça 110° c/ amort.', tipo: :dobradica, qtd: qtd_dob }

        # Usinagens
        mi.ferragens << { nome: 'Usinagem: canal vidro quadro', tipo: :usinagem, qtd: 4 }

        vao.adicionar_agregado({ tipo: :porta, subtipo: :vidro, grupo: porta_grupo })
        porta_grupo
      end

      # ─── PORTA VIDRO INTEIRO ───
      def self.construir_porta_vidro_inteiro(mi, vao, opts)
        grupo = mi.grupo_ref
        return nil unless grupo

        esp_vidro = opts[:esp_vidro] || 6
        material_vidro = opts[:material_vidro] || 'Vidro Incolor 4mm'
        folga = opts[:folga] || Config::FOLGA_PORTA

        porta_larg = vao.largura + (2 * mi.espessura_corpo) - (2 * folga)
        porta_alt  = vao.altura + (2 * mi.espessura_corpo) - (2 * folga)
        porta_x    = vao.x - mi.espessura_corpo + folga
        porta_z    = vao.z - mi.espessura_corpo + folga
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

        mi.ferragens << { nome: "#{material_vidro} Temperado #{porta_larg.round(0)}×#{porta_alt.round(0)}mm", tipo: :vidro, qtd: 1 }
        mi.ferragens << { nome: 'Dobradiça p/ vidro 110°', tipo: :dobradica, qtd: Utils.qtd_dobradicas(porta_alt) }
        mi.ferragens << { nome: 'Puxador p/ vidro', tipo: :puxador, qtd: 1 }

        vao.adicionar_agregado({ tipo: :porta, subtipo: :vidro_inteiro, grupo: porta_grupo })
        porta_grupo
      end

      # ─── PORTA PERFIL ALUMÍNIO ───
      def self.construir_porta_perfil_aluminio(mi, vao, opts)
        grupo = mi.grupo_ref
        return nil unless grupo

        cor_perfil = opts[:cor_perfil] || 'Natural'
        material_vidro = opts[:material_vidro] || 'Vidro Incolor 4mm'
        folga = opts[:folga] || Config::FOLGA_PORTA
        esp_perfil = 20  # mm — largura visível do perfil
        esp_vidro = 4

        porta_larg = vao.largura + (2 * mi.espessura_corpo) - (2 * folga)
        porta_alt  = vao.altura + (2 * mi.espessura_corpo) - (2 * folga)
        porta_x    = vao.x - mi.espessura_corpo + folga
        porta_z    = vao.z - mi.espessura_corpo + folga
        porta_y    = -esp_perfil

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
          larg: esp_perfil, prof: esp_perfil, alt: porta_alt,
          nome: 'Perfil ESQ')
        MotorAgregados.criar_sub_peca(porta_grupo, mat_al,
          x: porta_x + porta_larg - esp_perfil, y: porta_y, z: porta_z,
          larg: esp_perfil, prof: esp_perfil, alt: porta_alt,
          nome: 'Perfil DIR')
        MotorAgregados.criar_sub_peca(porta_grupo, mat_al,
          x: porta_x + esp_perfil, y: porta_y, z: porta_z + porta_alt - esp_perfil,
          larg: porta_larg - (2 * esp_perfil), prof: esp_perfil, alt: esp_perfil,
          nome: 'Perfil SUP')
        MotorAgregados.criar_sub_peca(porta_grupo, mat_al,
          x: porta_x + esp_perfil, y: porta_y, z: porta_z,
          larg: porta_larg - (2 * esp_perfil), prof: esp_perfil, alt: esp_perfil,
          nome: 'Perfil INF')

        # Vidro
        vidro_larg = porta_larg - (2 * esp_perfil) + 10
        vidro_alt  = porta_alt - (2 * esp_perfil) + 10
        MotorAgregados.criar_sub_peca(porta_grupo, mat_vidro,
          x: porta_x + esp_perfil - 5, y: porta_y + (esp_perfil - esp_vidro) / 2.0,
          z: porta_z + esp_perfil - 5,
          larg: vidro_larg, prof: esp_vidro, alt: vidro_alt,
          nome: 'Vidro')

        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'tipo', 'porta')
        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'perfil_aluminio')
        porta_grupo.set_attribute(Config::DICT_AGREGADO, 'vao_id', vao.id)

        mi.ferragens << { nome: "Perfil alumínio #{cor_perfil} — porta #{porta_larg.round(0)}×#{porta_alt.round(0)}", tipo: :perfil_aluminio, qtd: 1 }
        mi.ferragens << { nome: "#{material_vidro} #{vidro_larg.round(0)}×#{vidro_alt.round(0)}mm", tipo: :vidro, qtd: 1 }
        mi.ferragens << { nome: 'Roldana p/ perfil alumínio', tipo: :roldana, qtd: 2 }

        vao.adicionar_agregado({ tipo: :porta, subtipo: :perfil_aluminio, grupo: porta_grupo })
        porta_grupo
      end

      # ─── PORTA VENEZIANA ───
      def self.construir_porta_veneziana(mi, vao, opts)
        config = TIPOS_PORTA[:veneziana]
        grupo_porta = MotorAgregados.adicionar_porta(mi, vao, opts)
        return nil unless grupo_porta

        peca_porta = mi.pecas.select { |p| p.tipo == :porta }.last
        if peca_porta && peca_porta.grupo_ref
          peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'veneziana')

          # Calcula quantidade de ripas
          alt_util = peca_porta.comprimento - (2 * config[:largura_quadro])
          qtd_ripas = (alt_util / config[:espacamento_ripa]).floor
          mi.ferragens << { nome: "Ripa veneziana #{peca_porta.largura - 20}×#{config[:esp_ripa]}mm", tipo: :ripa, qtd: qtd_ripas }
          mi.ferragens << { nome: 'Usinagem: rasgos veneziana', tipo: :usinagem, qtd: qtd_ripas * 2 }
        end

        grupo_porta
      end

      # ─── PORTA RIPADA ───
      def self.construir_porta_ripada(mi, vao, opts)
        grupo_porta = MotorAgregados.adicionar_porta(mi, vao, opts)
        return nil unless grupo_porta

        peca_porta = mi.pecas.select { |p| p.tipo == :porta }.last
        if peca_porta && peca_porta.grupo_ref
          peca_porta.grupo_ref.set_attribute(Config::DICT_AGREGADO, 'tipo_porta', 'ripada')

          larg_ripa = opts[:largura_ripa] || 30
          esp_ripa = opts[:espessura_ripa] || 15
          espaco = opts[:espaco_ripas] || 10
          qtd_ripas = ((peca_porta.largura) / (larg_ripa + espaco)).floor

          mi.ferragens << { nome: "Ripa #{peca_porta.comprimento}×#{larg_ripa}×#{esp_ripa}mm", tipo: :ripa, qtd: qtd_ripas }
        end

        grupo_porta
      end

      # ─── Helper: desenha fresagem provençal na geometria ───
      def self.desenhar_fresagem_provencal(grupo_porta, peca, margem, mi)
        # Simplificado: marca visual no grupo (a fresagem real é nos dados de usinagem)
        grupo_porta.set_attribute(Config::DICT_AGREGADO, 'fresagem', 'provencal')
        grupo_porta.set_attribute(Config::DICT_AGREGADO, 'fresagem_margem', margem)
      end
    end
  end
end
