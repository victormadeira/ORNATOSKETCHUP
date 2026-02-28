# ornato_plugin/engines/motor_pecas_avulsas.rb — Peças complementares e painéis

module Ornato
  module Engines
    class MotorPecasAvulsas

      # ═══════════════════════════════════════════════
      # TAMPO / BANCADA
      # ═══════════════════════════════════════════════
      def self.criar_tampo(opts = {})
        model = Sketchup.active_model
        largura    = opts[:largura] || 2000
        profundidade = opts[:profundidade] || 600
        espessura  = opts[:espessura] || 30
        material   = opts[:material] || 'Granito Preto'
        sobre_frontal = opts[:sobre_frontal] || 20
        sobre_lateral = opts[:sobre_lateral] || 0
        posicao    = opts[:posicao] || Geom::Point3d.new(0, 0, 0)

        model.start_operation('Ornato: Criar Tampo', true)

        mat = Utils.criar_material(model, "Ornato_Tampo_#{material}",
          Sketchup::Color.new(60, 60, 65))

        grupo = model.active_entities.add_group
        grupo.name = "Tampo #{largura}×#{profundidade}"

        x = Utils.mm(-sobre_lateral)
        y = Utils.mm(-sobre_frontal)
        z = Utils.mm(0)
        l = Utils.mm(largura + (2 * sobre_lateral))
        p = Utils.mm(profundidade + sobre_frontal)
        a = Utils.mm(espessura)

        pts = [
          Geom::Point3d.new(x, y, z),
          Geom::Point3d.new(x + l, y, z),
          Geom::Point3d.new(x + l, y + p, z),
          Geom::Point3d.new(x, y + p, z)
        ]
        face = grupo.entities.add_face(pts)
        face.pushpull(-a) if face
        grupo.material = mat

        # Recortes (cuba, cooktop)
        if opts[:recortes]
          opts[:recortes].each do |recorte|
            criar_recorte(grupo, recorte)
          end
        end

        grupo.set_attribute(Config::DICT_PECA, 'tipo', 'tampo')
        grupo.set_attribute(Config::DICT_PECA, 'nome', "Tampo #{material}")
        grupo.set_attribute(Config::DICT_PECA, 'largura', largura + (2 * sobre_lateral))
        grupo.set_attribute(Config::DICT_PECA, 'comprimento', profundidade + sobre_frontal)
        grupo.set_attribute(Config::DICT_PECA, 'espessura', espessura)

        tr = Geom::Transformation.new(posicao)
        grupo.transform!(tr)

        model.commit_operation
        grupo
      end

      # Recorte no tampo (cuba, cooktop)
      def self.criar_recorte(grupo_tampo, recorte)
        x = Utils.mm(recorte[:x])
        y = Utils.mm(recorte[:y])
        larg = Utils.mm(recorte[:largura])
        prof = Utils.mm(recorte[:profundidade])

        pts = [
          Geom::Point3d.new(x, y, 0),
          Geom::Point3d.new(x + larg, y, 0),
          Geom::Point3d.new(x + larg, y + prof, 0),
          Geom::Point3d.new(x, y + prof, 0)
        ]

        # Adiciona a face de recorte (vai "furar" o tampo)
        face = grupo_tampo.entities.add_face(pts)
        if face
          esp = grupo_tampo.get_attribute(Config::DICT_PECA, 'espessura') || 30
          face.pushpull(Utils.mm(esp))
        end
      end

      # ═══════════════════════════════════════════════
      # RODAPÉ
      # ═══════════════════════════════════════════════
      def self.criar_rodape(opts = {})
        model = Sketchup.active_model
        largura   = opts[:largura] || 800
        altura    = opts[:altura] || Config::ALTURA_RODAPE_PADRAO
        espessura = opts[:espessura] || 15
        recuo     = opts[:recuo] || Config::RECUO_RODAPE_PADRAO
        material  = opts[:material] || 'MDF Branco 15mm'
        posicao   = opts[:posicao] || Geom::Point3d.new(0, 0, 0)

        model.start_operation('Ornato: Criar Rodapé', true)

        mat = Utils.criar_material(model, "Ornato_Corpo_#{material}", Config::COR_CORPO)

        grupo = model.active_entities.add_group
        grupo.name = "Rodapé #{largura}mm"

        x = Utils.mm(0)
        y = Utils.mm(recuo)
        z = Utils.mm(0)
        l = Utils.mm(largura)
        p = Utils.mm(espessura)
        a = Utils.mm(altura)

        pts = [
          Geom::Point3d.new(x, y, z),
          Geom::Point3d.new(x + l, y, z),
          Geom::Point3d.new(x + l, y + p, z),
          Geom::Point3d.new(x, y + p, z)
        ]
        face = grupo.entities.add_face(pts)
        face.pushpull(-a) if face
        grupo.material = mat

        grupo.set_attribute(Config::DICT_PECA, 'tipo', 'rodape')
        grupo.set_attribute(Config::DICT_PECA, 'nome', 'Rodapé')

        tr = Geom::Transformation.new(posicao)
        grupo.transform!(tr)

        model.commit_operation
        grupo
      end

      # ═══════════════════════════════════════════════
      # REQUADRO / FILLER
      # ═══════════════════════════════════════════════
      def self.criar_requadro(opts = {})
        model = Sketchup.active_model
        largura   = opts[:largura] || 50
        altura    = opts[:altura] || 700
        espessura = opts[:espessura] || 15
        material  = opts[:material] || 'MDF Branco 15mm'
        posicao   = opts[:posicao] || Geom::Point3d.new(0, 0, 0)

        model.start_operation('Ornato: Criar Requadro', true)

        mat = Utils.criar_material(model, "Ornato_Corpo_#{material}", Config::COR_CORPO)

        grupo = model.active_entities.add_group
        grupo.name = "Requadro #{largura}mm"

        pts = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(Utils.mm(largura), 0, 0),
          Geom::Point3d.new(Utils.mm(largura), Utils.mm(espessura), 0),
          Geom::Point3d.new(0, Utils.mm(espessura), 0)
        ]
        face = grupo.entities.add_face(pts)
        face.pushpull(-Utils.mm(altura)) if face
        grupo.material = mat

        grupo.set_attribute(Config::DICT_PECA, 'tipo', 'requadro')

        tr = Geom::Transformation.new(posicao)
        grupo.transform!(tr)

        model.commit_operation
        grupo
      end

      # ═══════════════════════════════════════════════
      # PAINEL LATERAL DE ACABAMENTO
      # ═══════════════════════════════════════════════
      def self.criar_painel_lateral(opts = {})
        model = Sketchup.active_model
        largura   = opts[:profundidade] || 560
        altura    = opts[:altura] || 700
        espessura = opts[:espessura] || 3  # lâmina fina
        material  = opts[:material] || 'MDF Carvalho 3mm'
        posicao   = opts[:posicao] || Geom::Point3d.new(0, 0, 0)

        model.start_operation('Ornato: Criar Painel Lateral', true)

        mat = Utils.criar_material(model, "Ornato_Frente_#{material}", Config::COR_FRENTE)

        grupo = model.active_entities.add_group
        grupo.name = "Painel Lateral #{material}"

        pts = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(Utils.mm(espessura), 0, 0),
          Geom::Point3d.new(Utils.mm(espessura), Utils.mm(largura), 0),
          Geom::Point3d.new(0, Utils.mm(largura), 0)
        ]
        face = grupo.entities.add_face(pts)
        face.pushpull(-Utils.mm(altura)) if face
        grupo.material = mat

        grupo.set_attribute(Config::DICT_PECA, 'tipo', 'painel')

        tr = Geom::Transformation.new(posicao)
        grupo.transform!(tr)

        model.commit_operation
        grupo
      end

      # ═══════════════════════════════════════════════
      # PAINEL CAVILHADO (RIPADO)
      # ═══════════════════════════════════════════════
      def self.criar_painel_cavilhado(opts = {})
        model = Sketchup.active_model
        largura_total = opts[:largura] || 1200
        altura        = opts[:altura] || 2400
        larg_ripa     = opts[:largura_ripa] || 40
        esp_ripa      = opts[:espessura_ripa] || 20
        espaco        = opts[:espaco] || 20
        material      = opts[:material] || 'MDF Carvalho Hanover 15mm'
        com_base      = opts[:com_base] != false  # base MDF para colar ripas
        esp_base      = opts[:espessura_base] || 9
        posicao       = opts[:posicao] || Geom::Point3d.new(0, 0, 0)
        diametro_cav  = opts[:diametro_cavilha] || 8
        esp_cav       = opts[:espacamento_cavilha] || 200

        model.start_operation('Ornato: Criar Painel Cavilhado', true)

        mat_ripa = Utils.criar_material(model, "Ornato_Ripa_#{material}", Config::COR_FRENTE)
        mat_base = Utils.criar_material(model, 'Ornato_Base_Ripado', Sketchup::Color.new(240, 235, 220))

        grupo = model.active_entities.add_group
        grupo.name = "Painel Cavilhado #{largura_total}×#{altura}"

        pecas = []
        usinagens_total = []

        # BASE MDF (se aplicável)
        if com_base
          pts_base = [
            Geom::Point3d.new(0, 0, 0),
            Geom::Point3d.new(Utils.mm(largura_total), 0, 0),
            Geom::Point3d.new(Utils.mm(largura_total), Utils.mm(esp_base), 0),
            Geom::Point3d.new(0, Utils.mm(esp_base), 0)
          ]
          face_base = grupo.entities.add_face(pts_base)
          face_base.pushpull(-Utils.mm(altura)) if face_base

          pecas << Models::Peca.new(
            nome: 'Base Ripado', comprimento: altura, largura: largura_total,
            espessura: esp_base, material: 'MDF Branco 9mm', tipo: :painel,
            fita_frente: false)
        end

        # RIPAS
        qtd_ripas = ((largura_total + espaco) / (larg_ripa + espaco).to_f).floor
        larg_real_total = (qtd_ripas * larg_ripa) + ((qtd_ripas - 1) * espaco)
        offset_x = (largura_total - larg_real_total) / 2.0

        y_ripa = com_base ? esp_base : 0

        qtd_ripas.times do |i|
          x_ripa = offset_x + (i * (larg_ripa + espaco))

          sub = grupo.entities.add_group
          sub.name = "Ripa #{i + 1}"

          pts = [
            Geom::Point3d.new(Utils.mm(x_ripa), Utils.mm(y_ripa), 0),
            Geom::Point3d.new(Utils.mm(x_ripa + larg_ripa), Utils.mm(y_ripa), 0),
            Geom::Point3d.new(Utils.mm(x_ripa + larg_ripa), Utils.mm(y_ripa + esp_ripa), 0),
            Geom::Point3d.new(Utils.mm(x_ripa), Utils.mm(y_ripa + esp_ripa), 0)
          ]
          face = sub.entities.add_face(pts)
          face.pushpull(-Utils.mm(altura)) if face
          sub.material = mat_ripa

          # Furação cavilha (na base da ripa, para fixar na base MDF)
          if com_base
            peca_ripa = Models::Peca.new(
              nome: "Ripa #{i + 1}", comprimento: altura, largura: larg_ripa,
              espessura: esp_ripa, material: material, tipo: :ripa,
              fita_frente: true, fita_topo: true, fita_tras: true, fita_base: true)

            furos = MotorUsinagem.furacao_cavilha_painel(peca_ripa,
              diametro: diametro_cav, espacamento: esp_cav,
              bordas: [:base])  # furos na base para encaixar na base MDF
            usinagens_total += furos
          end
        end

        # Peça de corte consolidada para ripas (todas iguais)
        pecas << Models::Peca.new(
          nome: 'Ripa', comprimento: altura, largura: larg_ripa,
          espessura: esp_ripa, material: material, tipo: :ripa,
          quantidade: qtd_ripas,
          fita_frente: true, fita_topo: true, fita_tras: true, fita_base: true,
          fita_material: 'ABS 2mm Carvalho')

        # Atributos
        grupo.set_attribute(Config::DICT_MODULO, 'tipo', 'painel_cavilhado')
        grupo.set_attribute(Config::DICT_MODULO, 'id', Utils.gerar_id)
        grupo.set_attribute(Config::DICT_MODULO, 'nome', "Painel Cavilhado #{largura_total}×#{altura}")
        grupo.set_attribute(Config::DICT_MODULO, 'largura', largura_total)
        grupo.set_attribute(Config::DICT_MODULO, 'altura', altura)
        grupo.set_attribute(Config::DICT_MODULO, 'qtd_ripas', qtd_ripas)
        grupo.set_attribute(Config::DICT_MODULO, 'larg_ripa', larg_ripa)
        grupo.set_attribute(Config::DICT_MODULO, 'espaco', espaco)

        tr = Geom::Transformation.new(posicao)
        grupo.transform!(tr)

        model.commit_operation

        { grupo: grupo, pecas: pecas, usinagens: usinagens_total, qtd_ripas: qtd_ripas }
      end

      # ═══════════════════════════════════════════════
      # MOLDURA / CORNIJA
      # ═══════════════════════════════════════════════
      def self.criar_moldura(opts = {})
        model = Sketchup.active_model
        largura   = opts[:largura] || 800
        altura    = opts[:altura] || 60
        profundidade = opts[:profundidade] || 30
        material  = opts[:material] || 'MDF Branco 15mm'
        posicao   = opts[:posicao] || Geom::Point3d.new(0, 0, 0)

        model.start_operation('Ornato: Criar Moldura', true)

        mat = Utils.criar_material(model, "Ornato_Frente_#{material}", Config::COR_FRENTE)

        grupo = model.active_entities.add_group
        grupo.name = "Moldura #{largura}mm"

        pts = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(Utils.mm(largura), 0, 0),
          Geom::Point3d.new(Utils.mm(largura), Utils.mm(profundidade), 0),
          Geom::Point3d.new(0, Utils.mm(profundidade), 0)
        ]
        face = grupo.entities.add_face(pts)
        face.pushpull(-Utils.mm(altura)) if face
        grupo.material = mat

        grupo.set_attribute(Config::DICT_PECA, 'tipo', 'moldura')

        tr = Geom::Transformation.new(posicao)
        grupo.transform!(tr)

        model.commit_operation
        grupo
      end

      # ═══════════════════════════════════════════════
      # CANALETA DE LED
      # ═══════════════════════════════════════════════
      def self.criar_canaleta_led(opts = {})
        model = Sketchup.active_model
        largura   = opts[:largura] || 800
        posicao   = opts[:posicao] || Geom::Point3d.new(0, 0, 0)

        model.start_operation('Ornato: Criar Canaleta LED', true)

        mat = Utils.criar_material(model, 'Ornato_Aluminio_LED', Sketchup::Color.new(200, 200, 205))

        grupo = model.active_entities.add_group
        grupo.name = "Canaleta LED #{largura}mm"

        # Perfil U: 18mm larg × 10mm alt
        pts = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(Utils.mm(largura), 0, 0),
          Geom::Point3d.new(Utils.mm(largura), Utils.mm(18), 0),
          Geom::Point3d.new(0, Utils.mm(18), 0)
        ]
        face = grupo.entities.add_face(pts)
        face.pushpull(-Utils.mm(10)) if face
        grupo.material = mat

        grupo.set_attribute(Config::DICT_PECA, 'tipo', 'canaleta_led')

        tr = Geom::Transformation.new(posicao)
        grupo.transform!(tr)

        model.commit_operation
        grupo
      end
    end
  end
end
