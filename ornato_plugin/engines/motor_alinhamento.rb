# ornato_plugin/engines/motor_alinhamento.rb — Snap e alinhamento entre modulos

module Ornato
  module Engines
    class MotorAlinhamento

      # Tolerancia de snap (mm)
      SNAP_TOLERANCE = 50.0

      # Alinha modulos selecionados ao longo do eixo X (lado a lado)
      def self.alinhar_horizontal(modulos = nil)
        modulos ||= selecionar_modulos
        return if modulos.empty?

        model = Sketchup.active_model
        model.start_operation('Ornato: Alinhar Horizontal', true)

        # Ordena da esquerda para direita pela posicao X
        modulos.sort_by! { |g| g.transformation.origin.x }

        x_atual = Utils.to_mm(modulos.first.transformation.origin.x)
        y_ref = Utils.to_mm(modulos.first.transformation.origin.y)
        z_ref = Utils.to_mm(modulos.first.transformation.origin.z)

        modulos.each_with_index do |grupo, i|
          next if i == 0  # primeiro fica no lugar

          mi = Models::ModuloInfo.carregar_do_grupo(grupo)
          next unless mi

          # Posiciona adjacente ao modulo anterior
          mi_anterior = Models::ModuloInfo.carregar_do_grupo(modulos[i - 1])
          x_atual += mi_anterior.largura if mi_anterior

          nova_pos = Geom::Point3d.new(Utils.mm(x_atual), Utils.mm(y_ref), Utils.mm(z_ref))
          mover_para(grupo, nova_pos)
        end

        model.commit_operation
        puts "[Ornato] #{modulos.length} modulos alinhados horizontalmente"
      end

      # Alinha modulos na mesma profundidade (Y)
      def self.alinhar_profundidade(modulos = nil)
        modulos ||= selecionar_modulos
        return if modulos.empty?

        model = Sketchup.active_model
        model.start_operation('Ornato: Alinhar Profundidade', true)

        y_ref = Utils.to_mm(modulos.first.transformation.origin.y)

        modulos[1..].each do |grupo|
          pos = grupo.transformation.origin
          nova_pos = Geom::Point3d.new(pos.x, Utils.mm(y_ref), pos.z)
          mover_para(grupo, nova_pos)
        end

        model.commit_operation
      end

      # Alinha modulos na mesma altura (Z)
      def self.alinhar_altura(modulos = nil)
        modulos ||= selecionar_modulos
        return if modulos.empty?

        model = Sketchup.active_model
        model.start_operation('Ornato: Alinhar Altura', true)

        z_ref = Utils.to_mm(modulos.first.transformation.origin.z)

        modulos[1..].each do |grupo|
          pos = grupo.transformation.origin
          nova_pos = Geom::Point3d.new(pos.x, pos.y, Utils.mm(z_ref))
          mover_para(grupo, nova_pos)
        end

        model.commit_operation
      end

      # Empilha modulos verticalmente (superior sobre inferior)
      def self.empilhar_vertical(modulos = nil)
        modulos ||= selecionar_modulos
        return if modulos.empty?

        model = Sketchup.active_model
        model.start_operation('Ornato: Empilhar Vertical', true)

        modulos.sort_by! { |g| g.transformation.origin.z }

        modulos.each_with_index do |grupo, i|
          next if i == 0

          mi_abaixo = Models::ModuloInfo.carregar_do_grupo(modulos[i - 1])
          next unless mi_abaixo

          pos_abaixo = modulos[i - 1].transformation.origin
          z_topo = Utils.to_mm(pos_abaixo.z) + mi_abaixo.altura

          nova_pos = Geom::Point3d.new(pos_abaixo.x, pos_abaixo.y, Utils.mm(z_topo))
          mover_para(grupo, nova_pos)
        end

        model.commit_operation
      end

      # Distribui modulos com espacamento igual
      def self.distribuir_horizontal(modulos = nil, espacamento = 0)
        modulos ||= selecionar_modulos
        return if modulos.length < 2

        model = Sketchup.active_model
        model.start_operation('Ornato: Distribuir', true)

        modulos.sort_by! { |g| g.transformation.origin.x }

        x_atual = Utils.to_mm(modulos.first.transformation.origin.x)
        y_ref = Utils.to_mm(modulos.first.transformation.origin.y)
        z_ref = Utils.to_mm(modulos.first.transformation.origin.z)

        modulos.each_with_index do |grupo, i|
          next if i == 0

          mi_anterior = Models::ModuloInfo.carregar_do_grupo(modulos[i - 1])
          x_atual += (mi_anterior ? mi_anterior.largura : 600) + espacamento

          nova_pos = Geom::Point3d.new(Utils.mm(x_atual), Utils.mm(y_ref), Utils.mm(z_ref))
          mover_para(grupo, nova_pos)
        end

        model.commit_operation
      end

      # Espelha um modulo (inverte eixo X)
      def self.espelhar(grupo)
        return unless Utils.modulo_ornato?(grupo)

        mi = Models::ModuloInfo.carregar_do_grupo(grupo)
        return unless mi

        model = Sketchup.active_model
        model.start_operation('Ornato: Espelhar', true)

        pos = grupo.transformation.origin
        centro_x = pos.x + Utils.mm(mi.largura / 2.0)

        # Espelhamento no eixo YZ passando pelo centro do modulo
        tr_espelho = Geom::Transformation.scaling(
          Geom::Point3d.new(centro_x, pos.y, pos.z),
          -1, 1, 1
        )
        grupo.transform!(tr_espelho)

        model.commit_operation
      end

      # Detecta se dois modulos estao adjacentes (para snap automatico)
      def self.adjacentes?(grupo_a, grupo_b)
        mi_a = Models::ModuloInfo.carregar_do_grupo(grupo_a)
        mi_b = Models::ModuloInfo.carregar_do_grupo(grupo_b)
        return false unless mi_a && mi_b

        pos_a = grupo_a.transformation.origin
        pos_b = grupo_b.transformation.origin

        # Verifica se estao lado a lado no eixo X
        borda_dir_a = Utils.to_mm(pos_a.x) + mi_a.largura
        borda_esq_b = Utils.to_mm(pos_b.x)

        dist = (borda_dir_a - borda_esq_b).abs
        dist <= SNAP_TOLERANCE
      end

      # Encontra ponto de snap mais proximo para um modulo
      def self.snap_point(grupo_movendo, ponto_cursor)
        modulos = Utils.listar_modulos.reject { |g| g == grupo_movendo }
        mi_mov = Models::ModuloInfo.carregar_do_grupo(grupo_movendo)
        return ponto_cursor unless mi_mov

        melhor_snap = nil
        menor_dist = SNAP_TOLERANCE

        modulos.each do |outro|
          mi_out = Models::ModuloInfo.carregar_do_grupo(outro)
          next unless mi_out

          pos_out = outro.transformation.origin
          larg_out = mi_out.largura

          # Pontos de snap: borda direita, borda esquerda, alinhamento Z
          pontos_snap = [
            # Direita do outro (encosta na esquerda do movendo)
            Geom::Point3d.new(pos_out.x + Utils.mm(larg_out), pos_out.y, pos_out.z),
            # Esquerda do outro (encosta na direita do movendo)
            Geom::Point3d.new(pos_out.x - Utils.mm(mi_mov.largura), pos_out.y, pos_out.z),
            # Em cima do outro
            Geom::Point3d.new(pos_out.x, pos_out.y, pos_out.z + Utils.mm(mi_out.altura)),
          ]

          pontos_snap.each do |snap_pt|
            dist = ponto_cursor.distance(snap_pt)
            if Utils.to_mm(dist) < menor_dist
              menor_dist = Utils.to_mm(dist)
              melhor_snap = snap_pt
            end
          end
        end

        melhor_snap || ponto_cursor
      end

      private

      def self.mover_para(grupo, nova_posicao)
        pos_atual = grupo.transformation.origin
        vetor = Geom::Vector3d.new(
          nova_posicao.x - pos_atual.x,
          nova_posicao.y - pos_atual.y,
          nova_posicao.z - pos_atual.z
        )
        tr = Geom::Transformation.translation(vetor)
        grupo.transform!(tr)
      end

      def self.selecionar_modulos
        sel = Sketchup.active_model.selection
        sel.select { |e| Utils.modulo_ornato?(e) }
      end
    end
  end
end
