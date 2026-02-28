# ornato_plugin/engines/motor_agregados.rb — Motor de agregados (porta, gaveta, prateleira, divisória)

module Ornato
  module Engines
    class MotorAgregados

      # ═══════════════════════════════════════════════
      # PORTA
      # ═══════════════════════════════════════════════
      def self.adicionar_porta(modulo_info, vao, opts = {})
        mi = modulo_info
        grupo = mi.grupo_ref
        return nil unless grupo

        tipo        = opts[:tipo] || Config::PORTA_ABRIR
        abertura    = opts[:abertura] || :esquerda
        sobreposicao = opts[:sobreposicao] || Config::SOBREP_TOTAL
        folga       = opts[:folga] || Config::FOLGA_PORTA
        material    = opts[:material] || mi.material_frente
        fita_mat    = opts[:fita_material] || mi.fita_frente
        esp         = opts[:espessura] || mi.espessura_corpo

        # Calcula dimensões da porta
        case sobreposicao
        when Config::SOBREP_TOTAL
          # Porta cobre a lateral — soma a espessura do corpo
          porta_larg = vao.largura + mi.espessura_corpo + (mi.espessura_corpo) - (2 * folga)
          porta_alt  = vao.altura + mi.espessura_corpo + (mi.espessura_corpo) - (2 * folga)
          porta_x    = vao.x - mi.espessura_corpo + folga
          porta_z    = vao.z - mi.espessura_corpo + folga
        when Config::SOBREP_MEIA
          porta_larg = vao.largura + (mi.espessura_corpo / 2.0) - (2 * folga)
          porta_alt  = vao.altura + mi.espessura_corpo - (2 * folga)
          porta_x    = vao.x - (mi.espessura_corpo / 2.0) + folga
          porta_z    = vao.z - mi.espessura_corpo + folga  # geralmente total no vertical
        when Config::SOBREP_INTERNA
          porta_larg = vao.largura - (2 * folga)
          porta_alt  = vao.altura - (2 * folga)
          porta_x    = vao.x + folga
          porta_z    = vao.z + folga
        end

        # Posição Y: na frente do módulo
        porta_y = -esp  # à frente da carcaça

        model = Sketchup.active_model
        mat_frente = Utils.criar_material(model, "Ornato_Frente_#{material}", Config::COR_FRENTE)

        # Cria a porta como sub-grupo dentro do módulo
        sub = grupo.entities.add_group
        sub.name = "Porta #{abertura == :esquerda ? 'ESQ' : 'DIR'}"

        x = Utils.mm(porta_x)
        y = Utils.mm(porta_y)
        z = Utils.mm(porta_z)
        larg = Utils.mm(porta_larg)
        prof = Utils.mm(esp)
        alt  = Utils.mm(porta_alt)

        pts = [
          Geom::Point3d.new(x, y, z),
          Geom::Point3d.new(x + larg, y, z),
          Geom::Point3d.new(x + larg, y + prof, z),
          Geom::Point3d.new(x, y + prof, z)
        ]
        face = sub.entities.add_face(pts)
        face.pushpull(-alt) if face
        sub.material = mat_frente

        # Atributos
        sub.set_attribute(Config::DICT_AGREGADO, 'tipo', 'porta')
        sub.set_attribute(Config::DICT_AGREGADO, 'subtipo', tipo.to_s)
        sub.set_attribute(Config::DICT_AGREGADO, 'abertura', abertura.to_s)
        sub.set_attribute(Config::DICT_AGREGADO, 'sobreposicao', sobreposicao.to_s)
        sub.set_attribute(Config::DICT_AGREGADO, 'vao_id', vao.id)

        # Peça de corte
        peca = Models::Peca.new(
          nome:        sub.name,
          comprimento: porta_alt.round(1),
          largura:     porta_larg.round(1),
          espessura:   esp,
          material:    material,
          tipo:        :porta,
          fita_frente: true, fita_topo: true, fita_tras: true, fita_base: true,
          fita_material: fita_mat,
          grupo_ref:   sub
        )
        mi.pecas << peca

        # Ferragens — dobradiças
        qtd_dob = Utils.qtd_dobradicas(porta_alt)
        mi.ferragens << { nome: 'Dobradiça 110° c/ amort.', tipo: :dobradica, qtd: qtd_dob }

        # Registra no vão
        vao.adicionar_agregado({ tipo: :porta, grupo: sub, peca: peca })

        sub
      end

      # Adiciona duas portas dividindo o vão ao meio
      def self.adicionar_porta_dupla(modulo_info, vao, opts = {})
        mi = modulo_info
        folga = opts[:folga] || Config::FOLGA_PORTA
        folga_entre = opts[:folga_entre] || Config::FOLGA_ENTRE_PORTAS

        # Cada porta cobre metade do vão
        meio = vao.largura / 2.0

        opts_esq = opts.merge(
          abertura: :esquerda,
          sobreposicao: Config::SOBREP_MEIA
        )
        opts_dir = opts.merge(
          abertura: :direita,
          sobreposicao: Config::SOBREP_MEIA
        )

        # Cria sub-vãos virtuais para posicionar cada porta
        vao_esq = Models::Vao.new(
          x: vao.x, y: vao.y, z: vao.z,
          largura: meio - (folga_entre / 2.0),
          altura: vao.altura, profundidade: vao.profundidade
        )
        vao_dir = Models::Vao.new(
          x: vao.x + meio + (folga_entre / 2.0), y: vao.y, z: vao.z,
          largura: meio - (folga_entre / 2.0),
          altura: vao.altura, profundidade: vao.profundidade
        )

        porta_esq = adicionar_porta(mi, vao_esq, opts_esq)
        porta_dir = adicionar_porta(mi, vao_dir, opts_dir)

        [porta_esq, porta_dir]
      end

      # ═══════════════════════════════════════════════
      # PRATELEIRA
      # ═══════════════════════════════════════════════
      def self.adicionar_prateleira(modulo_info, vao, opts = {})
        mi = modulo_info
        grupo = mi.grupo_ref
        return nil unless grupo

        posicao_z    = opts[:posicao] || (vao.altura / 2.0)  # mm a partir da base do vão
        recuo_frontal = opts[:recuo_frontal] || Config::RECUO_PRATELEIRA_FRONTAL
        recuo_traseiro = opts[:recuo_traseiro] || 0
        espessura    = opts[:espessura] || mi.espessura_corpo
        material     = opts[:material] || mi.material_corpo
        fita_mat     = opts[:fita_material] || mi.fita_corpo
        fixa         = opts[:fixa].nil? ? false : opts[:fixa]

        # Dimensões
        prat_larg = vao.largura
        prat_prof = vao.profundidade - recuo_frontal - recuo_traseiro
        prat_x    = vao.x
        prat_y    = recuo_traseiro
        prat_z    = vao.z + posicao_z

        # Snap para sistema 32mm se removível
        unless fixa
          prat_z_from_base = posicao_z
          prat_z_from_base = Utils.snap_32(prat_z_from_base)
          prat_z = vao.z + prat_z_from_base
        end

        model = Sketchup.active_model
        mat_corpo = Utils.criar_material(model, "Ornato_Corpo_#{material}", Config::COR_CORPO)

        sub = grupo.entities.add_group
        sub.name = fixa ? 'Prateleira Fixa' : 'Prateleira'

        x = Utils.mm(prat_x)
        y = Utils.mm(prat_y)
        z = Utils.mm(prat_z)
        larg = Utils.mm(prat_larg)
        prof = Utils.mm(prat_prof)
        alt  = Utils.mm(espessura)

        pts = [
          Geom::Point3d.new(x, y, z),
          Geom::Point3d.new(x + larg, y, z),
          Geom::Point3d.new(x + larg, y + prof, z),
          Geom::Point3d.new(x, y + prof, z)
        ]
        face = sub.entities.add_face(pts)
        face.pushpull(-alt) if face
        sub.material = mat_corpo

        # Atributos
        sub.set_attribute(Config::DICT_AGREGADO, 'tipo', 'prateleira')
        sub.set_attribute(Config::DICT_AGREGADO, 'fixa', fixa)
        sub.set_attribute(Config::DICT_AGREGADO, 'posicao', posicao_z)
        sub.set_attribute(Config::DICT_AGREGADO, 'vao_id', vao.id)

        # Peça de corte
        peca = Models::Peca.new(
          nome:        sub.name,
          comprimento: prat_larg.round(1),
          largura:     prat_prof.round(1),
          espessura:   espessura,
          material:    material,
          tipo:        :prateleira,
          fita_frente: true, fita_topo: false, fita_tras: false, fita_base: false,
          fita_material: fita_mat,
          grupo_ref:   sub
        )
        mi.pecas << peca

        # Ferragens — suportes
        if fixa
          mi.ferragens << { nome: "Minifix #{espessura}mm", tipo: :minifix, qtd: 4 }
          mi.ferragens << { nome: 'Cavilha 8x30mm', tipo: :cavilha, qtd: 4 }
        else
          mi.ferragens << { nome: 'Suporte prateleira Ø5mm', tipo: :pin, qtd: 4 }
        end

        vao.adicionar_agregado({ tipo: :prateleira, grupo: sub, peca: peca })

        sub
      end

      # ═══════════════════════════════════════════════
      # GAVETA — com suporte completo a tipos de corrediça
      # ═══════════════════════════════════════════════

      # Calcula todas as dimensões da gaveta baseado no tipo de corrediça
      # Retorna hash com todas as medidas calculadas
      def self.calcular_dimensoes_gaveta(vao, modulo_info, opts = {})
        mi = modulo_info
        tipo_corredica  = opts[:tipo_corredica] || Config::CORR_TELESCOPICA
        altura_frente   = opts[:altura_frente] || 150
        esp             = opts[:espessura] || mi.espessura_corpo
        esp_fundo       = opts[:espessura_fundo] || 3
        recuo_traseiro  = opts[:recuo_traseiro] || Config::RECUO_TRASEIRO_GAVETA
        folga           = opts[:folga] || Config::FOLGA_PORTA

        specs = Config::CORREDICA_SPECS[tipo_corredica]
        return nil unless specs

        result = {
          tipo_corredica: tipo_corredica,
          specs: specs,
          usa_lateral_mdf: true,  # padrão: gaveta tem lateral de MDF
        }

        case tipo_corredica

        # ── TELESCÓPICA (lateral, ball-bearing) ──
        when :telescopica
          folga_corr = specs[:folga_por_lado]  # 12.7mm por lado

          # Largura externa da gaveta = vão - (2 × 12.7) = vão - 25.4mm
          result[:larg_ext]     = vao.largura - (2 * folga_corr)
          result[:larg_int]     = result[:larg_ext] - (2 * esp)
          result[:alt_lateral]  = [altura_frente - Config::GAVETA_FRENTE_MAIOR_CAIXA, Config::GAVETA_ALTURA_LATERAL_MIN].max
          result[:alt_traseira] = result[:alt_lateral] - esp_fundo  # menor (fundo encaixa)
          result[:prof_gaveta]  = vao.profundidade - recuo_traseiro
          result[:prof_corr]    = snap_corredica_tipo(result[:prof_gaveta], specs[:comprimentos])

          # Posição X das laterais: centralizado no vão com folga da corrediça
          result[:lat_x_esq]    = vao.x + folga_corr
          result[:lat_x_dir]    = vao.x + folga_corr + result[:larg_ext] - esp

          # Posição corrediça: centro da lateral da gaveta (montagem lateral)
          result[:corr_pos_z]   = result[:alt_lateral] / 2.0

          # Fundo: encaixado em canal nas laterais
          result[:fundo_larg]   = result[:larg_int]
          result[:fundo_prof]   = result[:prof_gaveta]
          result[:esp_fundo]    = esp_fundo

        # ── OCULTA (undermount — Blum TANDEM) ──
        when :oculta
          deducao = specs[:deducao_interna]  # 42mm (Blum TANDEM)

          # Largura INTERNA da gaveta = vão - 42mm
          result[:larg_int]     = vao.largura - deducao
          # Largura EXTERNA = interna + 2 × espessura lateral
          result[:larg_ext]     = result[:larg_int] + (2 * esp)
          # Folga real por lado = (vão - larg_ext) / 2
          result[:folga_real]   = (vao.largura - result[:larg_ext]) / 2.0

          result[:alt_lateral]  = [altura_frente - Config::GAVETA_FRENTE_MAIOR_CAIXA, Config::GAVETA_ALTURA_LATERAL_MIN].max
          result[:alt_traseira] = result[:alt_lateral]  # oculta: traseira = lateral
          result[:prof_gaveta]  = vao.profundidade - recuo_traseiro

          # Comprimento gaveta = comprimento corrediça - 10mm (regra Blum)
          result[:prof_corr]    = snap_corredica_tipo(result[:prof_gaveta], specs[:comprimentos])
          result[:prof_gaveta]  = result[:prof_corr] - 10  # gaveta é 10mm menor que corrediça

          # Posição X: gaveta centralizada no vão
          result[:lat_x_esq]   = vao.x + result[:folga_real]
          result[:lat_x_dir]   = vao.x + result[:folga_real] + result[:larg_ext] - esp

          # Fundo: ESTRUTURAL — precisa suportar o peso (mín 12mm)
          # Fundo extende além das laterais para apoiar nos trilhos
          result[:esp_fundo]    = [esp_fundo, specs[:espessura_fundo_min]].max
          result[:fundo_larg]   = result[:larg_ext]  # fundo = largura externa (apoio nos trilhos)
          result[:fundo_prof]   = result[:prof_gaveta]

          # Folgas de montagem no módulo
          result[:folga_inferior] = specs[:folga_inferior]  # 14mm abaixo
          result[:folga_superior] = specs[:folga_superior]  # 7mm acima

          result[:lateral_limpa] = true  # sem corrediça aparente

        # ── TANDEMBOX (caixa metálica — Blum) ──
        when :tandembox
          deducao_base = specs[:deducao_base]  # 75mm
          perfil = specs[:perfil_lateral]       # 16.5mm

          result[:usa_lateral_mdf] = false  # perfil metálico no lugar de MDF

          # Base (fundo) da gaveta = vão - 75mm
          result[:fundo_larg]   = vao.largura - deducao_base
          result[:fundo_prof]   = vao.profundidade - recuo_traseiro

          # Largura externa = fundo + 2 × perfil metálico
          result[:larg_ext]     = result[:fundo_larg] + (2 * perfil)
          result[:larg_int]     = result[:fundo_larg]
          result[:folga_real]   = (vao.largura - result[:larg_ext]) / 2.0

          # Altura: usa código do perfil (N, M, K, D)
          codigo_perfil = opts[:perfil_tandembox] || 'M'
          perfil_info = specs[:alturas_perfil][codigo_perfil]
          result[:alt_perfil]   = perfil_info[:perfil]
          result[:alt_sistema]  = perfil_info[:sistema]
          result[:alt_util]     = perfil_info[:util]
          result[:alt_lateral]  = perfil_info[:perfil]
          result[:alt_traseira] = perfil_info[:perfil]

          result[:prof_corr]    = snap_corredica_tipo(result[:fundo_prof], specs[:comprimentos])
          result[:prof_gaveta]  = result[:prof_corr] - 10

          result[:lat_x_esq]   = vao.x + result[:folga_real]
          result[:lat_x_dir]   = vao.x + result[:folga_real] + result[:larg_ext] - perfil

          result[:esp_fundo]    = [esp_fundo, 16].max  # Tandembox precisa fundo robusto

          result[:lateral_limpa] = true  # perfil metálico integrado

        # ── ROLLER (econômica, nylon) ──
        when :roller
          folga_corr = specs[:folga_por_lado]  # 12.5mm

          result[:larg_ext]     = vao.largura - (2 * folga_corr)
          result[:larg_int]     = result[:larg_ext] - (2 * esp)
          result[:alt_lateral]  = [altura_frente - Config::GAVETA_FRENTE_MAIOR_CAIXA, Config::GAVETA_ALTURA_LATERAL_MIN].max
          result[:alt_traseira] = result[:alt_lateral] - esp_fundo
          result[:prof_gaveta]  = vao.profundidade - recuo_traseiro
          result[:prof_corr]    = snap_corredica_tipo(result[:prof_gaveta], specs[:comprimentos])

          result[:lat_x_esq]   = vao.x + folga_corr
          result[:lat_x_dir]   = vao.x + folga_corr + result[:larg_ext] - esp

          result[:fundo_larg]   = result[:larg_int]
          result[:fundo_prof]   = result[:prof_gaveta]
          result[:esp_fundo]    = esp_fundo
          result[:extensao_parcial] = true  # abre só 3/4
        end

        # Frente: sobreposição total (cobre o vão + espessura lateral)
        result[:frente_larg]  = vao.largura + (2 * mi.espessura_corpo) - (2 * folga)
        result[:frente_alt]   = altura_frente
        result[:frente_x]     = vao.x - mi.espessura_corpo + folga
        result[:frente_esp]   = esp

        result
      end

      # Encontra comprimento padrão de corrediça mais próximo (inferior)
      def self.snap_corredica_tipo(prof_mm, comprimentos)
        comprimentos.select { |c| c <= prof_mm }.max || comprimentos.first
      end

      # Constrói a gaveta 3D no SketchUp
      def self.adicionar_gaveta(modulo_info, vao, opts = {})
        mi = modulo_info
        grupo = mi.grupo_ref
        return nil unless grupo

        tipo_corredica  = opts[:tipo_corredica] || Config::CORR_TELESCOPICA
        altura_frente   = opts[:altura_frente] || 150
        material_frente = opts[:material_frente] || mi.material_frente
        material_lateral = opts[:material_lateral] || mi.material_corpo
        material_fundo_gav = opts[:material_fundo] || mi.material_fundo
        fita_frente_mat = opts[:fita_frente] || mi.fita_frente
        fita_corpo_mat  = opts[:fita_corpo] || mi.fita_corpo
        esp             = opts[:espessura] || mi.espessura_corpo
        posicao_z       = opts[:posicao_z] || vao.z
        folga           = opts[:folga] || Config::FOLGA_PORTA

        # Calcula todas as dimensões
        dims = calcular_dimensoes_gaveta(vao, mi, opts.merge(altura_frente: altura_frente))
        return nil unless dims

        specs = dims[:specs]

        model = Sketchup.active_model
        mat_frente_sk = Utils.criar_material(model, "Ornato_Frente_#{material_frente}", Config::COR_FRENTE)
        mat_corpo_sk  = Utils.criar_material(model, "Ornato_Corpo_#{material_lateral}", Config::COR_CORPO)

        nome_corr = specs[:nome] || tipo_corredica.to_s.capitalize
        gav_grupo = grupo.entities.add_group
        gav_grupo.name = "Gaveta #{nome_corr} (#{altura_frente}mm)"

        base_z = posicao_z

        # Offset Z para corrediça oculta (gaveta fica elevada)
        z_offset_corr = 0
        if tipo_corredica == :oculta
          z_offset_corr = dims[:folga_inferior]  # 14mm acima do fundo do módulo
        end

        # ─── FRENTE DA GAVETA ───
        criar_sub_peca(gav_grupo, mat_frente_sk,
          x: dims[:frente_x], y: -dims[:frente_esp], z: base_z,
          larg: dims[:frente_larg], prof: dims[:frente_esp], alt: dims[:frente_alt],
          nome: 'Frente Gaveta')

        mi.pecas << Models::Peca.new(
          nome: 'Frente Gaveta', comprimento: dims[:frente_alt].round(1),
          largura: dims[:frente_larg].round(1), espessura: esp,
          material: material_frente, tipo: :frente_gaveta,
          fita_frente: true, fita_topo: true, fita_tras: true, fita_base: true,
          fita_material: fita_frente_mat)

        if dims[:usa_lateral_mdf]
          # ─── LATERAL ESQ ───
          lat_z = base_z + z_offset_corr + (dims[:frente_alt] - dims[:alt_lateral])
          criar_sub_peca(gav_grupo, mat_corpo_sk,
            x: dims[:lat_x_esq], y: 0, z: lat_z,
            larg: esp, prof: dims[:prof_gaveta], alt: dims[:alt_lateral],
            nome: 'Lateral ESQ Gaveta')

          # ─── LATERAL DIR ───
          criar_sub_peca(gav_grupo, mat_corpo_sk,
            x: dims[:lat_x_dir], y: 0, z: lat_z,
            larg: esp, prof: dims[:prof_gaveta], alt: dims[:alt_lateral],
            nome: 'Lateral DIR Gaveta')

          # ─── TRASEIRA ───
          tras_x = dims[:lat_x_esq] + esp
          tras_y = dims[:prof_gaveta] - esp
          criar_sub_peca(gav_grupo, mat_corpo_sk,
            x: tras_x, y: tras_y, z: lat_z,
            larg: dims[:larg_int], prof: esp, alt: dims[:alt_traseira],
            nome: 'Traseira Gaveta')

          # Peças de corte — laterais e traseira
          mi.pecas << Models::Peca.new(
            nome: 'Lateral Gaveta', comprimento: dims[:prof_gaveta].round(1),
            largura: dims[:alt_lateral].round(1), espessura: esp,
            material: material_lateral, tipo: :lateral_gaveta,
            quantidade: 2, fita_topo: true, fita_material: fita_corpo_mat)

          mi.pecas << Models::Peca.new(
            nome: 'Traseira Gaveta', comprimento: dims[:larg_int].round(1),
            largura: dims[:alt_traseira].round(1), espessura: esp,
            material: material_lateral, tipo: :traseira_gaveta,
            fita_topo: true, fita_material: fita_corpo_mat)
        else
          # TANDEMBOX: perfis metálicos — não gera peça de corte para laterais
          # Os perfis são ferragem, não MDF
          lat_z = base_z + z_offset_corr

          # Representação visual dos perfis (cor diferente)
          mat_metal = Utils.criar_material(model, 'Ornato_Metal', Sketchup::Color.new(180, 180, 190))

          criar_sub_peca(gav_grupo, mat_metal,
            x: dims[:lat_x_esq], y: 0, z: lat_z,
            larg: dims[:specs][:perfil_lateral], prof: dims[:prof_gaveta], alt: dims[:alt_perfil],
            nome: 'Perfil ESQ Tandembox')

          criar_sub_peca(gav_grupo, mat_metal,
            x: dims[:lat_x_dir], y: 0, z: lat_z,
            larg: dims[:specs][:perfil_lateral], prof: dims[:prof_gaveta], alt: dims[:alt_perfil],
            nome: 'Perfil DIR Tandembox')

          # Traseira metálica
          tras_x = dims[:lat_x_esq] + dims[:specs][:perfil_lateral]
          tras_y = dims[:prof_gaveta] - 10  # traseira fina metálica
          criar_sub_peca(gav_grupo, mat_metal,
            x: tras_x, y: tras_y, z: lat_z,
            larg: dims[:fundo_larg], prof: 10, alt: dims[:alt_perfil],
            nome: 'Traseira Tandembox')
        end

        # ─── FUNDO DA GAVETA ───
        fundo_x = dims[:usa_lateral_mdf] ? (dims[:lat_x_esq] + esp) : dims[:lat_x_esq] + (dims[:specs][:perfil_lateral] || 0)
        fundo_z = base_z + z_offset_corr
        if dims[:usa_lateral_mdf] && tipo_corredica != :oculta
          fundo_z = base_z + z_offset_corr + (dims[:frente_alt] - dims[:alt_lateral])
        end

        # Para oculta: fundo na base da gaveta (fica apoiado nos trilhos)
        fundo_larg = dims[:fundo_larg]
        if tipo_corredica == :oculta
          fundo_x = dims[:lat_x_esq]  # fundo extende para apoiar nos trilhos
          fundo_larg = dims[:larg_ext]
        end

        criar_sub_peca(gav_grupo, mat_corpo_sk,
          x: fundo_x, y: 0, z: fundo_z,
          larg: fundo_larg, prof: dims[:fundo_prof], alt: dims[:esp_fundo],
          nome: 'Fundo Gaveta')

        mi.pecas << Models::Peca.new(
          nome: 'Fundo Gaveta', comprimento: fundo_larg.round(1),
          largura: dims[:fundo_prof].round(1), espessura: dims[:esp_fundo],
          material: material_fundo_gav, tipo: :fundo_gaveta)

        # ─── ATRIBUTOS ───
        gav_grupo.set_attribute(Config::DICT_AGREGADO, 'tipo', 'gaveta')
        gav_grupo.set_attribute(Config::DICT_AGREGADO, 'tipo_corredica', tipo_corredica.to_s)
        gav_grupo.set_attribute(Config::DICT_AGREGADO, 'altura_frente', altura_frente)
        gav_grupo.set_attribute(Config::DICT_AGREGADO, 'vao_id', vao.id)
        gav_grupo.set_attribute(Config::DICT_AGREGADO, 'comp_corredica', dims[:prof_corr])

        # ─── FERRAGENS ───
        mi.ferragens << {
          nome: "Corrediça #{nome_corr} #{dims[:prof_corr]}mm",
          tipo: :corredica, qtd: 1  # 1 par
        }

        if tipo_corredica == :tandembox
          codigo_perfil = opts[:perfil_tandembox] || 'M'
          mi.ferragens << {
            nome: "Perfil Tandembox #{codigo_perfil} #{dims[:prof_corr]}mm",
            tipo: :perfil_tandembox, qtd: 1  # 1 par
          }
          mi.ferragens << { nome: 'Bracket traseiro Tandembox', tipo: :bracket, qtd: 1 }  # 1 par
          mi.ferragens << { nome: 'Fixação frontal INSERTA', tipo: :fixacao_frontal, qtd: 1 }  # 1 par
        elsif tipo_corredica == :oculta
          mi.ferragens << { nome: 'Bracket traseiro TANDEM', tipo: :bracket, qtd: 1 }  # 1 par
          mi.ferragens << { nome: 'Locking device (fixação frontal)', tipo: :fixacao_frontal, qtd: 1 }  # 1 par
        else
          mi.ferragens << { nome: 'Parafuso p/ corrediça 4×16mm', tipo: :parafuso, qtd: specs[:furos_por_trilho] ? specs[:furos_por_trilho] * 4 : 8 }
        end

        vao.adicionar_agregado({ tipo: :gaveta, grupo: gav_grupo })
        gav_grupo
      end

      # Cria sub-grupo com geometria 3D (helper)
      def self.criar_sub_peca(parent_group, material, opts)
        sub = parent_group.entities.add_group
        sub.name = opts[:nome]
        pts = [
          Geom::Point3d.new(Utils.mm(opts[:x]), Utils.mm(opts[:y]), Utils.mm(opts[:z])),
          Geom::Point3d.new(Utils.mm(opts[:x] + opts[:larg]), Utils.mm(opts[:y]), Utils.mm(opts[:z])),
          Geom::Point3d.new(Utils.mm(opts[:x] + opts[:larg]), Utils.mm(opts[:y] + opts[:prof]), Utils.mm(opts[:z])),
          Geom::Point3d.new(Utils.mm(opts[:x]), Utils.mm(opts[:y] + opts[:prof]), Utils.mm(opts[:z]))
        ]
        face = sub.entities.add_face(pts)
        face.pushpull(-Utils.mm(opts[:alt])) if face
        sub.material = material
        sub
      end

      # Adiciona múltiplas gavetas empilhadas no vão
      def self.adicionar_gavetas(modulo_info, vao, quantidade, opts = {})
        tipo_corredica = opts[:tipo_corredica] || Config::CORR_TELESCOPICA
        folga_v = opts[:folga_vertical] || Config::GAVETA_FOLGA_ENTRE_FRENTES

        # Valida quantidade
        quantidade = [quantidade, Config::GAVETA_MAX_POR_VAO].min

        alt_total = vao.altura
        alt_por_gaveta = (alt_total - ((quantidade - 1) * folga_v)) / quantidade.to_f
        alt_frente = [alt_por_gaveta.round(0), Config::GAVETA_ALTURA_FRENTE_MIN].max

        # Para corrediça oculta: considera folgas extra no cálculo
        if tipo_corredica == :oculta
          specs = Config::CORREDICA_SPECS[:oculta]
          espaco_util = alt_total - specs[:folga_inferior] - specs[:folga_superior]
          alt_frente = [(espaco_util - ((quantidade - 1) * folga_v)) / quantidade.to_f, Config::GAVETA_ALTURA_FRENTE_MIN].max.round(0)
        end

        gavetas = []
        (0...quantidade).each do |i|
          pos_z = vao.z + (i * (alt_frente + folga_v))

          g = adicionar_gaveta(modulo_info, vao,
            opts.merge(
              altura_frente: alt_frente,
              posicao_z: pos_z
            ))
          gavetas << g if g
        end
        gavetas
      end

      # Valida se a corrediça escolhida é compatível com o vão
      def self.validar_corredica(vao, tipo_corredica, espessura_corpo = 15)
        specs = Config::CORREDICA_SPECS[tipo_corredica]
        return { valido: false, erros: ["Tipo de corrediça '#{tipo_corredica}' não encontrado"] } unless specs

        erros = []
        avisos = []

        case tipo_corredica
        when :telescopica
          larg_gaveta = vao.largura - (2 * specs[:folga_por_lado])
          if larg_gaveta < (specs[:largura_min_gaveta] || 0)
            erros << "Vão muito estreito (#{vao.largura}mm). Mínimo para telescópica: #{(specs[:largura_min_gaveta] || 0) + (2 * specs[:folga_por_lado])}mm"
          end
          if larg_gaveta > (specs[:largura_max_gaveta] || 9999)
            erros << "Vão muito largo (#{vao.largura}mm). Máximo para telescópica: #{(specs[:largura_max_gaveta] || 9999) + (2 * specs[:folga_por_lado])}mm"
          end

        when :oculta
          larg_int = vao.largura - specs[:deducao_interna]
          if larg_int < (specs[:largura_min_interna] || 0)
            erros << "Vão muito estreito para oculta. Largura interna ficaria #{larg_int}mm (mín: #{specs[:largura_min_interna]}mm)"
          end
          if vao.largura > (specs[:largura_max_modulo] || 9999)
            erros << "Vão muito largo para oculta TANDEM (máx: #{specs[:largura_max_modulo]}mm). Considere Tandembox."
          end
          avisos << "Fundo da gaveta será #{specs[:espessura_fundo_min]}mm (mín. para oculta)" if espessura_corpo < 15

        when :tandembox
          if vao.largura < (specs[:largura_min_modulo] || 0)
            erros << "Vão muito estreito para Tandembox (mín: #{specs[:largura_min_modulo]}mm)"
          end
          if vao.largura > (specs[:largura_max_modulo] || 9999)
            erros << "Vão muito largo para Tandembox (máx: #{specs[:largura_max_modulo]}mm)"
          end

        when :roller
          larg_gaveta = vao.largura - (2 * specs[:folga_por_lado])
          if larg_gaveta > (specs[:largura_max_gaveta] || 9999)
            erros << "Vão muito largo para roller (máx: #{(specs[:largura_max_gaveta] || 9999) + (2 * specs[:folga_por_lado])}mm)"
          end
          avisos << "Roller abre apenas 3/4 — gaveta não abre totalmente"
        end

        # Verifica comprimento disponível
        comp_disp = vao.profundidade - Config::RECUO_TRASEIRO_GAVETA
        comps = specs[:comprimentos] || Config::CORREDICA_COMPRIMENTOS
        comp_corr = comps.select { |c| c <= comp_disp }.max
        unless comp_corr
          erros << "Profundidade insuficiente (#{comp_disp}mm) para qualquer corrediça #{tipo_corredica}. Mínimo: #{comps.min}mm"
        end

        { valido: erros.empty?, erros: erros, avisos: avisos, comprimento_corredica: comp_corr }
      end

      # ═══════════════════════════════════════════════
      # DIVISÓRIA
      # ═══════════════════════════════════════════════
      def self.adicionar_divisoria(modulo_info, vao, direcao, opts = {})
        mi = modulo_info
        grupo = mi.grupo_ref
        return nil unless grupo

        posicao   = opts[:posicao]  # mm da borda esquerda (vertical) ou base (horizontal)
        espessura = opts[:espessura] || mi.espessura_corpo
        material  = opts[:material] || mi.material_corpo
        fita_mat  = opts[:fita_material] || mi.fita_corpo

        model = Sketchup.active_model
        mat_corpo = Utils.criar_material(model, "Ornato_Corpo_#{material}", Config::COR_CORPO)

        case direcao
        when :vertical
          posicao ||= vao.largura / 2.0  # centro por padrão
          div_x = vao.x + posicao - (espessura / 2.0)
          div_y = 0
          div_z = vao.z
          div_larg = espessura
          div_prof = vao.profundidade
          div_alt  = vao.altura

          comp_corte = vao.altura
          larg_corte = vao.profundidade
          nome = 'Divisória Vertical'

          # Subdivide o vão
          vao.dividir_vertical(posicao, espessura)

        when :horizontal
          posicao ||= vao.altura / 2.0
          div_x = vao.x
          div_y = 0
          div_z = vao.z + posicao - (espessura / 2.0)
          div_larg = vao.largura
          div_prof = vao.profundidade
          div_alt  = espessura

          comp_corte = vao.largura
          larg_corte = vao.profundidade
          nome = 'Divisória Horizontal'

          vao.dividir_horizontal(posicao, espessura)
        else
          return nil
        end

        sub = grupo.entities.add_group
        sub.name = nome

        pts = [
          Geom::Point3d.new(Utils.mm(div_x), Utils.mm(div_y), Utils.mm(div_z)),
          Geom::Point3d.new(Utils.mm(div_x + div_larg), Utils.mm(div_y), Utils.mm(div_z)),
          Geom::Point3d.new(Utils.mm(div_x + div_larg), Utils.mm(div_y + div_prof), Utils.mm(div_z)),
          Geom::Point3d.new(Utils.mm(div_x), Utils.mm(div_y + div_prof), Utils.mm(div_z))
        ]
        face = sub.entities.add_face(pts)
        face.pushpull(-Utils.mm(div_alt)) if face
        sub.material = mat_corpo

        sub.set_attribute(Config::DICT_AGREGADO, 'tipo', 'divisoria')
        sub.set_attribute(Config::DICT_AGREGADO, 'direcao', direcao.to_s)
        sub.set_attribute(Config::DICT_AGREGADO, 'posicao', posicao)
        sub.set_attribute(Config::DICT_AGREGADO, 'vao_id', vao.id)

        peca = Models::Peca.new(
          nome:        nome,
          comprimento: comp_corte.round(1),
          largura:     larg_corte.round(1),
          espessura:   espessura,
          material:    material,
          tipo:        :divisoria,
          fita_frente: true,
          fita_material: fita_mat,
          grupo_ref:   sub
        )
        mi.pecas << peca

        mi.ferragens << { nome: "Minifix #{espessura}mm", tipo: :minifix, qtd: 4 }
        mi.ferragens << { nome: 'Cavilha 8x30mm', tipo: :cavilha, qtd: 4 }

        vao.adicionar_agregado({ tipo: :divisoria, grupo: sub, peca: peca })

        sub
      end
    end
  end
end
