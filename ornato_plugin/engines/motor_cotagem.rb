# ornato_plugin/engines/motor_cotagem.rb — Cotagem automatica 3D para modulos de marcenaria
#
# Adiciona cotas (dimension lines) aos modulos do projeto, permitindo
# visualizar largura, altura, profundidade e dimensoes internas diretamente
# no modelo 3D do SketchUp. Utiliza entidades DimensionLinear nativas.

module Ornato
  module Engines
    class MotorCotagem

      # ─── Constantes de cotagem ───

      # Distancia da linha de cota ao objeto (mm)
      OFFSET_LINHA = 80

      # Prolongamento das linhas de extensao alem do ponto (mm)
      EXTENSAO = 15

      # Altura do texto das cotas (mm)
      ALTURA_TEXTO = 50

      # Cor das cotas — laranja Ornato (#e67e22)
      COR_COTA = Sketchup::Color.new(230, 126, 34)

      # Layer/Tag dedicado para cotas
      LAYER_COTAS = 'Ornato_Cotas'.freeze

      # ─── Metodo principal: cotar um modulo ───
      # Adiciona cotas dimensionais a um grupo de modulo Ornato.
      #
      # @param grupo [Sketchup::Group] grupo do modulo
      # @param opts [Hash] opcoes de cotagem
      # @option opts :externas [Boolean] cotas externas (largura, altura, profundidade) — padrao true
      # @option opts :internas [Boolean] cotas internas (largura e altura internas) — padrao false
      # @option opts :pecas [Boolean] cotas individuais em cada peca — padrao false
      # @return [Array<Sketchup::DimensionLinear>] lista de cotas criadas
      def self.cotar_modulo(grupo, opts = {})
        return [] unless Utils.modulo_ornato?(grupo)

        externas = opts.fetch(:externas, true)
        internas = opts.fetch(:internas, false)
        pecas    = opts.fetch(:pecas, false)

        model = Sketchup.active_model
        model.start_operation('Ornato: Cotar Modulo', true)

        layer = setup_layer(model)
        cotas = []

        # Bounding box do modulo em coordenadas do modelo
        bb = grupo.bounds
        min_pt = bb.min
        max_pt = bb.max

        # Dimensoes em mm para log
        larg_mm = Utils.to_mm(max_pt.x - min_pt.x)
        alt_mm  = Utils.to_mm(max_pt.z - min_pt.z)
        prof_mm = Utils.to_mm(max_pt.y - min_pt.y)

        entities = model.active_entities

        if externas
          # Cota horizontal — largura (eixo X), na base, deslocada para frente
          cotas << criar_cota_horizontal(
            entities, min_pt, max_pt,
            -Utils.mm(OFFSET_LINHA),  # offset em Y (para frente do modulo)
            0                          # offset em Z (na base)
          )

          # Cota vertical — altura (eixo Z), na face esquerda, deslocada para frente
          cotas << criar_cota_vertical(
            entities, min_pt, max_pt,
            -Utils.mm(OFFSET_LINHA)   # offset em X (a esquerda do modulo)
          )

          # Cota de profundidade — profundidade (eixo Y), na base, deslocada para a esquerda
          cotas << criar_cota_profundidade(
            entities, min_pt, max_pt,
            -Utils.mm(OFFSET_LINHA)   # offset em X (a esquerda do modulo)
          )
        end

        if internas
          cotas += cotar_internas(entities, grupo, min_pt, max_pt, layer)
        end

        if pecas
          cotar_pecas(grupo)
        end

        # Aplica estilo e layer a todas as cotas criadas
        cotas.compact.each do |dim|
          aplicar_estilo(dim, layer)
        end

        model.commit_operation
        puts "[Ornato] Cotagem: #{cotas.compact.length} cotas adicionadas (#{larg_mm.round}x#{alt_mm.round}x#{prof_mm.round}mm)"
        cotas.compact
      end

      # ─── Cotar pecas individuais ───
      # Adiciona cotas de largura e altura a cada sub-grupo (peca) dentro do modulo.
      #
      # @param grupo [Sketchup::Group] grupo do modulo
      # @return [Array<Sketchup::DimensionLinear>] lista de cotas criadas
      def self.cotar_pecas(grupo)
        return [] unless Utils.modulo_ornato?(grupo)

        model = Sketchup.active_model
        model.start_operation('Ornato: Cotar Pecas', true) unless model.active_path

        layer = setup_layer(model)
        cotas = []
        entities = model.active_entities

        # Itera sobre sub-grupos que sao pecas Ornato
        grupo.entities.each do |ent|
          next unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)

          # Verifica se e uma peca Ornato
          tipo_peca = Utils.get_attr(ent, Config::DICT_PECA, 'tipo')
          next unless tipo_peca

          bb = ent.bounds
          next if bb.empty?

          # Transforma pontos do bounding box para coordenadas do modelo
          tr = grupo.transformation
          min_local = bb.min
          max_local = bb.max

          # Pontos transformados no espaco do modelo
          min_pt = tr * min_local
          max_pt = tr * max_local

          offset_peca = Utils.mm(OFFSET_LINHA * 0.5)

          # Cota de largura da peca (eixo X)
          largura_peca = max_pt.x - min_pt.x
          if Utils.to_mm(largura_peca) > 10  # ignora pecas muito pequenas
            pt_ini = Geom::Point3d.new(min_pt.x, min_pt.y - offset_peca, min_pt.z)
            pt_fim = Geom::Point3d.new(max_pt.x, min_pt.y - offset_peca, min_pt.z)
            vector = Geom::Vector3d.new(0, -offset_peca, 0)

            dim = entities.add_dimension_linear(pt_ini, pt_fim, vector)
            aplicar_estilo(dim, layer)
            cotas << dim
          end

          # Cota de altura da peca (eixo Z)
          altura_peca = max_pt.z - min_pt.z
          if Utils.to_mm(altura_peca) > 10
            pt_ini = Geom::Point3d.new(min_pt.x - offset_peca, min_pt.y, min_pt.z)
            pt_fim = Geom::Point3d.new(min_pt.x - offset_peca, min_pt.y, max_pt.z)
            vector = Geom::Vector3d.new(-offset_peca, 0, 0)

            dim = entities.add_dimension_linear(pt_ini, pt_fim, vector)
            aplicar_estilo(dim, layer)
            cotas << dim
          end
        end

        model.commit_operation unless model.active_path
        puts "[Ornato] Cotagem pecas: #{cotas.length} cotas adicionadas"
        cotas
      end

      # ─── Cotar todo o projeto ───
      # Aplica cotagem a todos os modulos Ornato encontrados no modelo.
      #
      # @param modulos [Array<Sketchup::Group>, nil] lista de modulos ou nil para todos
      # @param opts [Hash] opcoes de cotagem (mesmas de cotar_modulo)
      # @return [Integer] total de cotas criadas
      def self.cotar_projeto(modulos = nil, opts = {})
        modulos ||= Utils.listar_modulos
        return 0 if modulos.empty?

        total_cotas = 0

        modulos.each do |grupo|
          resultado = cotar_modulo(grupo, opts)
          total_cotas += resultado.length
        end

        puts "[Ornato] Cotagem projeto: #{total_cotas} cotas em #{modulos.length} modulos"
        total_cotas
      end

      # ─── Remover cotas ───
      # Remove todas as cotas Ornato de um grupo ou do modelo inteiro.
      #
      # @param grupo_ou_model [Sketchup::Group, Sketchup::Model, nil] escopo de remocao
      # @return [Integer] quantidade de cotas removidas
      def self.remover_cotas(grupo_ou_model = nil)
        model = Sketchup.active_model
        grupo_ou_model ||= model

        model.start_operation('Ornato: Remover Cotas', true)

        removidas = 0

        if grupo_ou_model.is_a?(Sketchup::Model)
          # Remove todas as cotas no layer Ornato_Cotas do modelo
          entities = model.active_entities
          removidas = remover_cotas_entities(entities)
        elsif grupo_ou_model.is_a?(Sketchup::Group) || grupo_ou_model.is_a?(Sketchup::ComponentInstance)
          # Remove cotas associadas ao bounding box deste grupo
          entities = model.active_entities
          bb = grupo_ou_model.bounds
          removidas = remover_cotas_por_regiao(entities, bb)
        end

        model.commit_operation
        puts "[Ornato] #{removidas} cotas removidas"
        removidas
      end

      # ─── Toggle visibilidade ───
      # Mostra ou esconde o layer Ornato_Cotas.
      #
      # @param visivel [Boolean, nil] true/false para forcar, nil para alternar
      # @return [Boolean] estado final do layer (visivel ou nao)
      def self.toggle_cotas(visivel = nil)
        model = Sketchup.active_model
        layer = model.layers[LAYER_COTAS]

        unless layer
          puts "[Ornato] Layer '#{LAYER_COTAS}' nao encontrado. Nenhuma cota no projeto."
          return false
        end

        if visivel.nil?
          # Alterna visibilidade
          layer.visible = !layer.visible?
        else
          layer.visible = visivel
        end

        estado = layer.visible? ? 'visivel' : 'oculto'
        puts "[Ornato] Cotas: #{estado}"
        layer.visible?
      end

      # ─── Helpers de criacao de cotas ───

      # Cria cota horizontal (largura — eixo X)
      # A cota mede a distancia entre min_pt.x e max_pt.x
      #
      # @param entities [Sketchup::Entities] colecao de entidades
      # @param min_pt [Geom::Point3d] ponto minimo do bounding box
      # @param max_pt [Geom::Point3d] ponto maximo do bounding box
      # @param offset_y [Length] deslocamento em Y (para frente/tras)
      # @param offset_z [Length] deslocamento em Z (acima/abaixo)
      # @return [Sketchup::DimensionLinear] a cota criada
      def self.criar_cota_horizontal(entities, min_pt, max_pt, offset_y, offset_z)
        pt_inicio = Geom::Point3d.new(min_pt.x, min_pt.y + offset_y, min_pt.z + offset_z)
        pt_fim    = Geom::Point3d.new(max_pt.x, min_pt.y + offset_y, min_pt.z + offset_z)

        # Vetor de offset perpendicular a linha de cota (para baixo/frente)
        vector = Geom::Vector3d.new(0, offset_y, 0)

        dim = entities.add_dimension_linear(pt_inicio, pt_fim, vector)
        dim
      rescue => e
        puts "[Ornato] Erro ao criar cota horizontal: #{e.message}"
        nil
      end

      # Cria cota vertical (altura — eixo Z)
      # A cota mede a distancia entre min_pt.z e max_pt.z
      #
      # @param entities [Sketchup::Entities] colecao de entidades
      # @param min_pt [Geom::Point3d] ponto minimo do bounding box
      # @param max_pt [Geom::Point3d] ponto maximo do bounding box
      # @param offset_x [Length] deslocamento em X (para a esquerda)
      # @return [Sketchup::DimensionLinear] a cota criada
      def self.criar_cota_vertical(entities, min_pt, max_pt, offset_x)
        pt_inicio = Geom::Point3d.new(min_pt.x + offset_x, min_pt.y, min_pt.z)
        pt_fim    = Geom::Point3d.new(min_pt.x + offset_x, min_pt.y, max_pt.z)

        # Vetor de offset perpendicular (para a esquerda)
        vector = Geom::Vector3d.new(offset_x, 0, 0)

        dim = entities.add_dimension_linear(pt_inicio, pt_fim, vector)
        dim
      rescue => e
        puts "[Ornato] Erro ao criar cota vertical: #{e.message}"
        nil
      end

      # Cria cota de profundidade (eixo Y)
      # A cota mede a distancia entre min_pt.y e max_pt.y
      #
      # @param entities [Sketchup::Entities] colecao de entidades
      # @param min_pt [Geom::Point3d] ponto minimo do bounding box
      # @param max_pt [Geom::Point3d] ponto maximo do bounding box
      # @param offset [Length] deslocamento em X (para a esquerda)
      # @return [Sketchup::DimensionLinear] a cota criada
      def self.criar_cota_profundidade(entities, min_pt, max_pt, offset)
        pt_inicio = Geom::Point3d.new(min_pt.x + offset, min_pt.y, min_pt.z)
        pt_fim    = Geom::Point3d.new(min_pt.x + offset, max_pt.y, min_pt.z)

        # Vetor de offset perpendicular (para a esquerda e para baixo)
        vector = Geom::Vector3d.new(offset, 0, 0)

        dim = entities.add_dimension_linear(pt_inicio, pt_fim, vector)
        dim
      rescue => e
        puts "[Ornato] Erro ao criar cota profundidade: #{e.message}"
        nil
      end

      # ─── Setup do layer de cotas ───
      # Cria ou retorna o layer Ornato_Cotas.
      #
      # @param model [Sketchup::Model] modelo ativo
      # @return [Sketchup::Layer] o layer de cotas
      def self.setup_layer(model)
        layer = model.layers[LAYER_COTAS]
        unless layer
          layer = model.layers.add(LAYER_COTAS)
          layer.visible = true
          puts "[Ornato] Layer '#{LAYER_COTAS}' criado"
        end
        layer
      end

      private

      # ─── Cotas internas do modulo ───
      # Calcula largura e altura internas baseado na espessura das laterais e
      # base/topo, e adiciona cotas posicionadas internamente.
      #
      # @param entities [Sketchup::Entities] entidades do modelo
      # @param grupo [Sketchup::Group] grupo do modulo
      # @param min_pt [Geom::Point3d] ponto minimo do bounding box
      # @param max_pt [Geom::Point3d] ponto maximo do bounding box
      # @param layer [Sketchup::Layer] layer de cotas
      # @return [Array<Sketchup::DimensionLinear>] cotas internas criadas
      def self.cotar_internas(entities, grupo, min_pt, max_pt, layer)
        cotas = []

        # Le espessura do corpo do modulo (nominal -> real)
        esp_nominal = Utils.get_attr(grupo, Config::DICT_MODULO, 'espessura_corpo', Config::ESPESSURA_CORPO_PADRAO)
        esp_real = Config.espessura_real(esp_nominal)
        esp_su = Utils.mm(esp_real)

        # Le tipo de montagem para determinar onde ficam as laterais
        montagem = Utils.get_attr(grupo, Config::DICT_MODULO, 'montagem', :laterais_entre)

        # Calcula pontos internos baseado na montagem
        if montagem.to_s == 'laterais_entre' || montagem.to_s == Config::MONTAGEM_BRASIL.to_s
          # Montagem Brasil: laterais entre base e topo
          # Largura interna = largura total - 2 * espessura lateral
          int_min_x = min_pt.x + esp_su
          int_max_x = max_pt.x - esp_su
          # Altura interna = altura total - base - topo
          int_min_z = min_pt.z + esp_su
          int_max_z = max_pt.z - esp_su
        else
          # Montagem Europa: base/topo entre laterais
          int_min_x = min_pt.x + esp_su
          int_max_x = max_pt.x - esp_su
          int_min_z = min_pt.z + esp_su
          int_max_z = max_pt.z - esp_su
        end

        # Offset menor para cotas internas (ficam mais perto do modulo)
        offset_int = Utils.mm(OFFSET_LINHA * 0.4)

        # Cota interna horizontal — largura interna
        pt_ini_h = Geom::Point3d.new(int_min_x, min_pt.y - offset_int, int_min_z)
        pt_fim_h = Geom::Point3d.new(int_max_x, min_pt.y - offset_int, int_min_z)
        vector_h = Geom::Vector3d.new(0, -offset_int, 0)

        begin
          dim_h = entities.add_dimension_linear(pt_ini_h, pt_fim_h, vector_h)
          cotas << dim_h
        rescue => e
          puts "[Ornato] Erro cota interna horizontal: #{e.message}"
        end

        # Cota interna vertical — altura interna
        pt_ini_v = Geom::Point3d.new(min_pt.x - offset_int, min_pt.y, int_min_z)
        pt_fim_v = Geom::Point3d.new(min_pt.x - offset_int, min_pt.y, int_max_z)
        vector_v = Geom::Vector3d.new(-offset_int, 0, 0)

        begin
          dim_v = entities.add_dimension_linear(pt_ini_v, pt_fim_v, vector_v)
          cotas << dim_v
        rescue => e
          puts "[Ornato] Erro cota interna vertical: #{e.message}"
        end

        cotas
      end

      # ─── Aplica estilo visual a uma cota ───
      # Define cor, layer e fonte da cota.
      #
      # @param dim [Sketchup::DimensionLinear] a entidade de dimensao
      # @param layer [Sketchup::Layer] o layer de cotas
      def self.aplicar_estilo(dim, layer)
        return unless dim

        dim.layer = layer

        # Aplica cor laranja Ornato ao texto da cota
        if dim.respond_to?(:leader_type=)
          dim.leader_type = Sketchup::Dimension::LEADER_NONE rescue nil
        end

        # Define tamanho e cor do texto se a API suportar
        if dim.respond_to?(:has_aligned_text=)
          dim.has_aligned_text = true rescue nil
        end

        # Aplica cor ao texto (via entity color se disponivel)
        if dim.respond_to?(:set_attribute)
          dim.set_attribute(Config::DICT_ORNATO, 'tipo_cota', 'ornato')
          dim.set_attribute(Config::DICT_ORNATO, 'cor_hex', '#e67e22')
        end
      end

      # ─── Remove cotas de um conjunto de entities ───
      # Remove todas as entidades DimensionLinear que estao no layer Ornato_Cotas.
      #
      # @param entities [Sketchup::Entities] colecao de entidades
      # @return [Integer] quantidade removida
      def self.remover_cotas_entities(entities)
        removidas = 0
        a_remover = []

        entities.each do |ent|
          next unless ent.is_a?(Sketchup::DimensionLinear)
          next unless ent.layer.name == LAYER_COTAS

          a_remover << ent
        end

        a_remover.each do |ent|
          ent.erase!
          removidas += 1
        end

        removidas
      end

      # ─── Remove cotas por regiao (bounding box) ───
      # Remove cotas do layer Ornato_Cotas que estao dentro ou proximas
      # da regiao definida pelo bounding box.
      #
      # @param entities [Sketchup::Entities] colecao de entidades
      # @param bb [Geom::BoundingBox] bounding box de referencia
      # @return [Integer] quantidade removida
      def self.remover_cotas_por_regiao(entities, bb)
        removidas = 0
        margem = Utils.mm(OFFSET_LINHA * 2)
        a_remover = []

        # Expande o bounding box pela margem para incluir cotas deslocadas
        bb_expandido = Geom::BoundingBox.new
        bb_expandido.add(
          Geom::Point3d.new(bb.min.x - margem, bb.min.y - margem, bb.min.z - margem),
          Geom::Point3d.new(bb.max.x + margem, bb.max.y + margem, bb.max.z + margem)
        )

        entities.each do |ent|
          next unless ent.is_a?(Sketchup::DimensionLinear)
          next unless ent.layer.name == LAYER_COTAS

          # Verifica se a cota esta na regiao expandida
          # Usa o ponto de texto ou o ponto medio da cota como referencia
          if ent.respond_to?(:start) && ent.respond_to?(:end)
            pt_ref = ponto_medio_cota(ent)
            if pt_ref && bb_expandido.contains?(pt_ref)
              a_remover << ent
            end
          else
            # Fallback: verifica via atributo ornato
            tipo_cota = ent.get_attribute(Config::DICT_ORNATO, 'tipo_cota')
            a_remover << ent if tipo_cota == 'ornato'
          end
        end

        a_remover.each do |ent|
          ent.erase!
          removidas += 1
        end

        removidas
      end

      # ─── Ponto medio de uma cota ───
      # Retorna o ponto medio entre os dois pontos de uma DimensionLinear.
      #
      # @param dim [Sketchup::DimensionLinear] a entidade de dimensao
      # @return [Geom::Point3d, nil] o ponto medio ou nil
      def self.ponto_medio_cota(dim)
        # DimensionLinear usa start/end como ConnectionPoints
        # Tenta extrair posicoes a partir dos attached_to
        begin
          arr_start = dim.start
          arr_end   = dim.end

          # start/end retornam Array [entity, point] ou Geom::Point3d
          pt1 = arr_start.is_a?(Array) ? arr_start.last : arr_start
          pt2 = arr_end.is_a?(Array)   ? arr_end.last   : arr_end

          return nil unless pt1.is_a?(Geom::Point3d) && pt2.is_a?(Geom::Point3d)

          Geom::Point3d.new(
            (pt1.x + pt2.x) / 2.0,
            (pt1.y + pt2.y) / 2.0,
            (pt1.z + pt2.z) / 2.0
          )
        rescue
          nil
        end
      end

      # ─── Verifica se cotas ja existem para um modulo ───
      # Evita duplicacao de cotas ao re-executar cotagem.
      #
      # @param grupo [Sketchup::Group] grupo do modulo
      # @param entities [Sketchup::Entities] entidades do modelo
      # @return [Boolean] true se ja existem cotas nessa regiao
      def self.cotas_existentes?(grupo, entities)
        bb = grupo.bounds
        margem = Utils.mm(OFFSET_LINHA * 2)

        bb_busca = Geom::BoundingBox.new
        bb_busca.add(
          Geom::Point3d.new(bb.min.x - margem, bb.min.y - margem, bb.min.z - margem),
          Geom::Point3d.new(bb.max.x + margem, bb.max.y + margem, bb.max.z + margem)
        )

        entities.each do |ent|
          next unless ent.is_a?(Sketchup::DimensionLinear)
          next unless ent.layer.name == LAYER_COTAS

          tipo_cota = ent.get_attribute(Config::DICT_ORNATO, 'tipo_cota')
          return true if tipo_cota == 'ornato'
        end

        false
      end

    end
  end
end
