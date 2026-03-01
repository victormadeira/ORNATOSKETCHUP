# ornato_plugin/engines/motor_caixa.rb — Motor de construção de carcaças

module Ornato
  module Engines
    class MotorCaixa
      # Constrói um módulo completo no SketchUp a partir de um ModuloInfo
      # Retorna o Group do SketchUp com todas as peças
      def self.construir(modulo_info, position = nil)
        model = Sketchup.active_model
        model.start_operation('Ornato: Criar Módulo', true)

        begin
          mi = modulo_info
          position ||= Geom::Point3d.new(0, 0, 0)

          # Grupo principal do módulo
          grupo = model.active_entities.add_group
          grupo.name = "#{mi.nome} (#{mi.largura}×#{mi.altura}×#{mi.profundidade})"
          ents = grupo.entities

          # Materiais
          mat_corpo = Utils.criar_material(model, "Ornato_Corpo_#{mi.material_corpo}", Config::COR_CORPO)
          mat_fundo = Utils.criar_material(model, "Ornato_Fundo_#{mi.material_fundo}", Config::COR_FUNDO)

          # Limpa peças anteriores
          mi.pecas.clear
          mi.ferragens.clear

          # ─── Calcula dimensões das peças (usa espessura REAL) ───
          # MDF 15mm → real 15.5mm, 18mm → 18.5mm, 25mm → 25.5mm
          esp = mi.espessura_corpo_real   # espessura REAL do corpo
          esp_f = mi.espessura_fundo_real # espessura REAL do fundo
          esp_nominal = mi.espessura_corpo  # nominal para referência de material
          l = mi.largura
          a = mi.altura
          p = mi.profundidade

          # Offset Z para rodapé/pés (módulos inferiores)
          z_offset = 0
          if (mi.tipo == :inferior || mi.tipo == :gaveteiro) &&
             (mi.tipo_base == Config::BASE_RODAPE || mi.tipo_base == Config::BASE_PES)
            z_offset = mi.altura_rodape
            a = a - mi.altura_rodape  # altura do corpo (sem rodapé)
          end

          # Profundidade do corpo (desconta rebaixo do fundo)
          prof_corpo = mi.tipo_fundo == Config::FUNDO_REBAIXADO ? p - mi.rebaixo_fundo : p

          # ─── Montagem Brasil: laterais entre base e topo ───
          if mi.montagem == Config::MONTAGEM_BRASIL
            larg_bt = l - (2 * esp)  # largura da base e topo

            # LATERAL ESQUERDA
            criar_peca_3d(ents, mi, mat_corpo,
              nome: 'Lateral ESQ', tipo: :lateral,
              x: 0, y: 0, z: z_offset,
              larg_peca: esp, prof_peca: prof_corpo, alt_peca: a,
              comp_corte: a, larg_corte: prof_corpo,
              fita_frente: true)

            # LATERAL DIREITA
            criar_peca_3d(ents, mi, mat_corpo,
              nome: 'Lateral DIR', tipo: :lateral,
              x: l - esp, y: 0, z: z_offset,
              larg_peca: esp, prof_peca: prof_corpo, alt_peca: a,
              comp_corte: a, larg_corte: prof_corpo,
              fita_frente: true)

            # BASE
            criar_peca_3d(ents, mi, mat_corpo,
              nome: 'Base', tipo: :base,
              x: esp, y: 0, z: z_offset,
              larg_peca: larg_bt, prof_peca: prof_corpo, alt_peca: esp,
              comp_corte: larg_bt, larg_corte: prof_corpo,
              fita_frente: true)

            # TOPO
            criar_peca_3d(ents, mi, mat_corpo,
              nome: 'Topo', tipo: :topo,
              x: esp, y: 0, z: z_offset + a - esp,
              larg_peca: larg_bt, prof_peca: prof_corpo, alt_peca: esp,
              comp_corte: larg_bt, larg_corte: prof_corpo,
              fita_frente: true)

            # Vão interno
            vao_x = esp
            vao_z = z_offset + esp
            vao_larg = larg_bt
            vao_alt = a - (2 * esp)
            vao_prof = prof_corpo

          else
            # ─── Montagem Europa: base e topo entre laterais ───
            alt_lat = a - (2 * esp)

            # LATERAL ESQUERDA
            criar_peca_3d(ents, mi, mat_corpo,
              nome: 'Lateral ESQ', tipo: :lateral,
              x: 0, y: 0, z: z_offset + esp,
              larg_peca: esp, prof_peca: prof_corpo, alt_peca: alt_lat,
              comp_corte: alt_lat, larg_corte: prof_corpo,
              fita_frente: true)

            # LATERAL DIREITA
            criar_peca_3d(ents, mi, mat_corpo,
              nome: 'Lateral DIR', tipo: :lateral,
              x: l - esp, y: 0, z: z_offset + esp,
              larg_peca: esp, prof_peca: prof_corpo, alt_peca: alt_lat,
              comp_corte: alt_lat, larg_corte: prof_corpo,
              fita_frente: true)

            # BASE
            criar_peca_3d(ents, mi, mat_corpo,
              nome: 'Base', tipo: :base,
              x: 0, y: 0, z: z_offset,
              larg_peca: l, prof_peca: prof_corpo, alt_peca: esp,
              comp_corte: l, larg_corte: prof_corpo,
              fita_frente: true)

            # TOPO
            criar_peca_3d(ents, mi, mat_corpo,
              nome: 'Topo', tipo: :topo,
              x: 0, y: 0, z: z_offset + a - esp,
              larg_peca: l, prof_peca: prof_corpo, alt_peca: esp,
              comp_corte: l, larg_corte: prof_corpo,
              fita_frente: true)

            vao_x = esp
            vao_z = z_offset + esp
            vao_larg = l - (2 * esp)
            vao_alt = a - (2 * esp)
            vao_prof = prof_corpo
          end

          # ─── FUNDO ───
          if mi.tipo_fundo != Config::FUNDO_SEM
            if mi.tipo_fundo == Config::FUNDO_REBAIXADO
              # Fundo encaixado em canal — posicionado no fundo do módulo
              fundo_l = l - (2 * (esp - mi.rebaixo_fundo))
              fundo_a = a - (2 * (esp - mi.rebaixo_fundo))
              fundo_x = esp - mi.rebaixo_fundo
              fundo_z = z_offset + (esp - mi.rebaixo_fundo)
            else
              # Fundo sobreposto — na traseira
              fundo_l = l
              fundo_a = a
              fundo_x = 0
              fundo_z = z_offset
            end

            criar_peca_3d(ents, mi, mat_fundo,
              nome: 'Fundo', tipo: :fundo,
              x: fundo_x, y: prof_corpo, z: fundo_z,
              larg_peca: fundo_l, prof_peca: esp_f, alt_peca: fundo_a,
              comp_corte: fundo_l, larg_corte: fundo_a,
              espessura_override: esp_f,
              material_override: mi.material_fundo,
              fita_frente: false)
          end

          # ─── Vão principal ───
          mi.vao_principal = Models::Vao.new(
            x: vao_x, y: 0, z: vao_z,
            largura: vao_larg, altura: vao_alt, profundidade: vao_prof
          )

          # ─── Ferragens de fixação (minifix corpo) ───
          qtd_fixacoes = 4  # 2 por junção lateral-base, 2 por junção lateral-topo
          mi.ferragens << { nome: "Minifix #{esp}mm", tipo: :minifix, qtd: qtd_fixacoes * 2 }
          mi.ferragens << { nome: "Cavilha 8x30mm", tipo: :cavilha, qtd: qtd_fixacoes * 2 }

          # ─── Pés / Rodapé ───
          if mi.tipo_base == Config::BASE_PES && (mi.tipo == :inferior || mi.tipo == :gaveteiro)
            qtd_pes = l > 800 ? 6 : 4
            mi.ferragens << { nome: "Pé regulável #{mi.altura_rodape}mm", tipo: :pe, qtd: qtd_pes }
          end

          # ─── Aplica usinagens automaticas (canal fundo, etc.) ───
          begin
            usinagens = MotorUsinagem.gerar_usinagens_modulo(mi)
            mi.set_attribute_extra('usinagens_count', usinagens.length) if usinagens.any?
          rescue => usi_err
            puts "[Ornato] Aviso: usinagens nao geradas: #{usi_err.message}"
          end

          # ─── Aplica fita de borda automatica ───
          begin
            MotorFitaBorda.aplicar_regra(mi)
          rescue => fita_err
            puts "[Ornato] Aviso: fita de borda nao aplicada: #{fita_err.message}"
          end

          # ─── Salva metadata no grupo SketchUp ───
          mi.salvar_no_grupo(grupo)

          # ─── Posiciona o grupo ───
          tr = Geom::Transformation.new(position)
          grupo.transform!(tr)

          model.commit_operation
          grupo

        rescue => e
          model.abort_operation
          puts "[Ornato] ERRO ao construir módulo: #{e.message}"
          puts e.backtrace.first(5).join("\n")
          nil
        end
      end

      # Reconstrói o módulo 3D a partir dos atributos do grupo existente
      def self.reconstruir(grupo)
        mi = Models::ModuloInfo.carregar_do_grupo(grupo)
        return nil unless mi

        model = Sketchup.active_model
        model.start_operation('Ornato: Reconstruir Módulo', true)

        begin
          pos = grupo.transformation.origin
          model.active_entities.erase_entities(grupo)
          novo_grupo = construir(mi, pos)
          model.commit_operation
          novo_grupo
        rescue => e
          model.abort_operation
          puts "[Ornato] ERRO ao reconstruir: #{e.message}"
          nil
        end
      end

      private

      # Cria uma peça 3D (sub-grupo) e registra na lista de peças do módulo
      def self.criar_peca_3d(entities, modulo_info, material, opts)
        x = Utils.mm(opts[:x])
        y = Utils.mm(opts[:y])
        z = Utils.mm(opts[:z])
        larg = Utils.mm(opts[:larg_peca])
        prof = Utils.mm(opts[:prof_peca])
        alt  = Utils.mm(opts[:alt_peca])

        # Cria sub-grupo para a peça
        sub = entities.add_group
        sub.name = opts[:nome]

        pts = [
          Geom::Point3d.new(x, y, z),
          Geom::Point3d.new(x + larg, y, z),
          Geom::Point3d.new(x + larg, y + prof, z),
          Geom::Point3d.new(x, y + prof, z)
        ]

        face = sub.entities.add_face(pts)
        face.pushpull(-alt) if face

        # Aplica material
        if material
          sub.material = material
        end

        # Marca como peça Ornato
        esp_real = opts[:espessura_override] || modulo_info.espessura_corpo
        mat_real = opts[:material_override] || modulo_info.material_corpo
        fita_mat = opts[:fita_material] || modulo_info.fita_corpo

        sub.set_attribute(Config::DICT_PECA, 'nome', opts[:nome])
        sub.set_attribute(Config::DICT_PECA, 'tipo', opts[:tipo].to_s)
        sub.set_attribute(Config::DICT_PECA, 'comprimento', opts[:comp_corte])
        sub.set_attribute(Config::DICT_PECA, 'largura', opts[:larg_corte])
        sub.set_attribute(Config::DICT_PECA, 'espessura', esp_real)
        sub.set_attribute(Config::DICT_PECA, 'material', mat_real)

        # Registra peça no módulo
        peca = Models::Peca.new(
          nome:        opts[:nome],
          comprimento: opts[:comp_corte],
          largura:     opts[:larg_corte],
          espessura:   esp_real,
          quantidade:  1,
          material:    mat_real,
          tipo:        opts[:tipo],
          fita_frente: opts[:fita_frente] || false,
          fita_topo:   opts[:fita_topo] || false,
          fita_tras:   opts[:fita_tras] || false,
          fita_base:   opts[:fita_base] || false,
          fita_material: fita_mat,
          grupo_ref:   sub
        )
        modulo_info.pecas << peca

        sub
      end
    end
  end
end
