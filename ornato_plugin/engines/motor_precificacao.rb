# ornato_plugin/engines/motor_precificacao.rb — Motor de precificacao local
# Calcula custos de material, ferragens, mao de obra e acabamentos
# Preparado para futura integracao com Ornato ERP (calcItemV2/precoVendaV2)

module Ornato
  module Engines
    class MotorPrecificacao

      # Tabela de precos padrao (pode ser atualizada via ERP)
      PRECOS_PADRAO = {
        # Chapas (R$/m2)
        'MDF 15mm' => 85.0,
        'MDF 18mm' => 110.0,
        'MDF 25mm' => 160.0,
        'MDP 15mm' => 55.0,
        'MDP 18mm' => 70.0,
        'HDF 3mm'  => 25.0,
        'HDF 6mm'  => 40.0,
        'Compensado 3mm' => 22.0,
        'Compensado 6mm' => 35.0,
        'Laca' => 250.0,
        'Vidro 4mm' => 180.0,
        'Espelho 4mm' => 200.0,

        # Fita de borda (R$/metro linear)
        'PVC 0.4mm' => 1.20,
        'PVC 1mm' => 2.50,
        'ABS 2mm' => 4.80,

        # Ferragens (R$/unidade)
        'Minifix' => 3.50,
        'Cavilha 8x30mm' => 0.30,
        'Dobradica 35mm' => 12.00,
        'Puxador' => 18.00,
        'Corredica telescopica 350mm' => 28.00,
        'Corredica telescopica 400mm' => 32.00,
        'Corredica telescopica 450mm' => 35.00,
        'Corredica telescopica 500mm' => 38.00,
        'Corredica oculta 350mm' => 65.00,
        'Corredica oculta 400mm' => 72.00,
        'Corredica oculta 450mm' => 78.00,
        'Corredica oculta 500mm' => 85.00,
        'Corredica tandembox 350mm' => 120.00,
        'Corredica tandembox 450mm' => 140.00,
        'Corredica tandembox 500mm' => 155.00,
        'Pe regulavel' => 4.50,
        'Suporte prateleira' => 1.00,
        'Confirmat 5x50mm' => 0.25,

        # Mao de obra (R$/modulo ou R$/hora)
        'mao_obra_modulo_simples' => 80.0,
        'mao_obra_modulo_medio' => 120.0,
        'mao_obra_modulo_complexo' => 180.0,
        'mao_obra_usinagem_hora' => 60.0,
        'mao_obra_laca' => 150.0,  # por m2
      }.freeze

      # Margem de lucro padrao (%)
      MARGEM_PADRAO = 35.0

      # Calcula o custo de um modulo individual
      def self.calcular_modulo(mi)
        custo = {
          material: 0.0,
          fita: 0.0,
          ferragens: 0.0,
          mao_obra: 0.0,
          usinagem: 0.0,
          total_custo: 0.0,
          total_venda: 0.0
        }

        # Custo de material (chapas)
        mi.pecas.each do |peca|
          area_m2 = peca.area_m2
          preco_m2 = encontrar_preco_material(peca.material)
          custo[:material] += area_m2 * preco_m2
        end

        # Custo de fita de borda
        mi.pecas.each do |peca|
          metros = peca.fita_metros
          next if metros <= 0
          preco_ml = encontrar_preco_fita(peca.fita_material)
          custo[:fita] += metros * preco_ml
        end

        # Custo de ferragens
        mi.ferragens.each do |f|
          preco_unit = encontrar_preco_ferragem(f[:nome])
          custo[:ferragens] += preco_unit * f[:qtd]
        end

        # Mao de obra
        complexidade = calcular_complexidade(mi)
        custo[:mao_obra] = case complexidade
                           when :simples then PRECOS_PADRAO['mao_obra_modulo_simples']
                           when :medio   then PRECOS_PADRAO['mao_obra_modulo_medio']
                           when :complexo then PRECOS_PADRAO['mao_obra_modulo_complexo']
                           end

        # Usinagem
        begin
          usinagens = MotorUsinagem.gerar_usinagens_modulo(mi)
          tempo_estimado = usinagens.length * 0.05  # ~3 min por usinagem
          custo[:usinagem] = tempo_estimado * PRECOS_PADRAO['mao_obra_usinagem_hora']
        rescue
          custo[:usinagem] = 0
        end

        custo[:total_custo] = custo.values_at(:material, :fita, :ferragens, :mao_obra, :usinagem).sum
        custo[:total_venda] = custo[:total_custo] * (1 + MARGEM_PADRAO / 100.0)

        custo
      end

      # Calcula orcamento completo do projeto
      def self.calcular_projeto
        modulos = Utils.listar_modulos
        resumo = {
          modulos: [],
          total_material: 0.0,
          total_fita: 0.0,
          total_ferragens: 0.0,
          total_mao_obra: 0.0,
          total_usinagem: 0.0,
          total_custo: 0.0,
          total_venda: 0.0,
          por_ambiente: {}
        }

        modulos.each do |grupo|
          mi = Models::ModuloInfo.carregar_do_grupo(grupo)
          next unless mi

          custo = calcular_modulo(mi)
          item = {
            nome: mi.nome,
            ambiente: mi.ambiente,
            dimensoes: "#{mi.largura}x#{mi.altura}x#{mi.profundidade}",
            custo: custo
          }
          resumo[:modulos] << item

          # Acumula
          resumo[:total_material]  += custo[:material]
          resumo[:total_fita]      += custo[:fita]
          resumo[:total_ferragens] += custo[:ferragens]
          resumo[:total_mao_obra]  += custo[:mao_obra]
          resumo[:total_usinagem]  += custo[:usinagem]
          resumo[:total_custo]     += custo[:total_custo]
          resumo[:total_venda]     += custo[:total_venda]

          # Por ambiente
          amb = mi.ambiente || 'Geral'
          resumo[:por_ambiente][amb] ||= 0.0
          resumo[:por_ambiente][amb] += custo[:total_venda]
        end

        resumo
      end

      # Exporta orcamento em texto formatado
      def self.gerar_orcamento_texto
        resumo = calcular_projeto

        texto = "=" * 60 + "\n"
        texto += "  ORCAMENTO — ORNATO MARCENARIA\n"
        texto += "=" * 60 + "\n\n"

        resumo[:modulos].each_with_index do |item, i|
          c = item[:custo]
          texto += "#{i + 1}. #{item[:nome]} (#{item[:ambiente]})\n"
          texto += "   Dimensoes: #{item[:dimensoes]}mm\n"
          texto += "   Material: R$ #{c[:material].round(2)}\n"
          texto += "   Fita: R$ #{c[:fita].round(2)}\n"
          texto += "   Ferragens: R$ #{c[:ferragens].round(2)}\n"
          texto += "   Mao de obra: R$ #{c[:mao_obra].round(2)}\n"
          texto += "   Usinagem: R$ #{c[:usinagem].round(2)}\n"
          texto += "   SUBTOTAL: R$ #{c[:total_venda].round(2)}\n"
          texto += "-" * 40 + "\n"
        end

        texto += "\n" + "=" * 60 + "\n"
        texto += "  RESUMO POR AMBIENTE\n"
        texto += "=" * 60 + "\n"
        resumo[:por_ambiente].each do |amb, valor|
          texto += "  #{amb}: R$ #{valor.round(2)}\n"
        end

        texto += "\n" + "=" * 60 + "\n"
        texto += "  TOTAIS\n"
        texto += "=" * 60 + "\n"
        texto += "  Material:   R$ #{resumo[:total_material].round(2)}\n"
        texto += "  Fita Borda: R$ #{resumo[:total_fita].round(2)}\n"
        texto += "  Ferragens:  R$ #{resumo[:total_ferragens].round(2)}\n"
        texto += "  Mao Obra:   R$ #{resumo[:total_mao_obra].round(2)}\n"
        texto += "  Usinagem:   R$ #{resumo[:total_usinagem].round(2)}\n"
        texto += "-" * 40 + "\n"
        texto += "  CUSTO TOTAL:  R$ #{resumo[:total_custo].round(2)}\n"
        texto += "  Margem: #{MARGEM_PADRAO}%\n"
        texto += "  VALOR VENDA:  R$ #{resumo[:total_venda].round(2)}\n"
        texto += "=" * 60 + "\n"

        texto
      end

      # Exporta orcamento CSV
      def self.exportar_csv(path)
        resumo = calcular_projeto

        File.open(path, 'w') do |f|
          f.puts '#,Modulo,Ambiente,Dimensoes,Material,Fita,Ferragens,MaoObra,Usinagem,Custo,Venda'
          resumo[:modulos].each_with_index do |item, i|
            c = item[:custo]
            f.puts "#{i + 1},#{item[:nome]},#{item[:ambiente]},#{item[:dimensoes]},#{c[:material].round(2)},#{c[:fita].round(2)},#{c[:ferragens].round(2)},#{c[:mao_obra].round(2)},#{c[:usinagem].round(2)},#{c[:total_custo].round(2)},#{c[:total_venda].round(2)}"
          end
          f.puts ''
          f.puts "TOTAL,,,,,,,,,#{resumo[:total_custo].round(2)},#{resumo[:total_venda].round(2)}"
        end
      end

      private

      def self.encontrar_preco_material(nome)
        # Procura correspondencia aproximada
        return PRECOS_PADRAO['Laca'] if nome.downcase.include?('laca')
        return PRECOS_PADRAO['Vidro 4mm'] if nome.downcase.include?('vidro')
        return PRECOS_PADRAO['Espelho 4mm'] if nome.downcase.include?('espelho')

        if nome.include?('25mm')
          PRECOS_PADRAO['MDF 25mm']
        elsif nome.include?('18mm')
          nome.include?('MDP') ? PRECOS_PADRAO['MDP 18mm'] : PRECOS_PADRAO['MDF 18mm']
        elsif nome.include?('6mm')
          nome.include?('HDF') ? PRECOS_PADRAO['HDF 6mm'] : PRECOS_PADRAO['Compensado 6mm']
        elsif nome.include?('3mm')
          nome.include?('HDF') ? PRECOS_PADRAO['HDF 3mm'] : PRECOS_PADRAO['Compensado 3mm']
        else
          nome.include?('MDP') ? PRECOS_PADRAO['MDP 15mm'] : PRECOS_PADRAO['MDF 15mm']
        end
      end

      def self.encontrar_preco_fita(nome)
        return PRECOS_PADRAO['ABS 2mm'] if nome.to_s.downcase.include?('abs')
        return PRECOS_PADRAO['PVC 0.4mm'] if nome.to_s.include?('0.4')
        PRECOS_PADRAO['PVC 1mm']
      end

      def self.encontrar_preco_ferragem(nome)
        PRECOS_PADRAO.each do |key, valor|
          return valor if nome.downcase.include?(key.downcase.split(' ').first)
        end
        5.0  # preco generico
      end

      def self.calcular_complexidade(mi)
        score = 0
        score += 1 if mi.pecas.length > 6
        score += 1 if mi.ferragens.length > 8
        score += 1 if mi.altura > 1500
        score += 1 if mi.tipo == :torre

        case score
        when 0..1 then :simples
        when 2    then :medio
        else           :complexo
        end
      end
    end
  end
end
