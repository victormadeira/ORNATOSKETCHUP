# ornato_plugin/utils.rb — Funções utilitárias

module Ornato
  module Utils
    # Converte mm para unidade interna do SketchUp (polegadas)
    def self.mm(valor)
      valor.mm
    end

    # Converte unidade interna do SketchUp para mm
    def self.to_mm(valor)
      valor.to_mm
    end

    # Arredonda para o múltiplo de 32mm mais próximo (sistema 32)
    def self.snap_32(valor_mm)
      (valor_mm / 32.0).round * 32
    end

    # Arredonda para comprimento padrão de corrediça (inferior)
    def self.snap_corredica(prof_mm)
      Config::CORREDICA_COMPRIMENTOS.select { |c| c <= prof_mm }.max || Config::CORREDICA_COMPRIMENTOS.first
    end

    # Quantidade de dobradiças por altura da porta (mm)
    def self.qtd_dobradicas(altura_mm)
      regra = Config::DOBRADICA_REGRAS.find { |r| altura_mm <= r[:ate] }
      regra ? regra[:qtd] : 2
    end

    # Gera ID único para componentes
    def self.gerar_id
      "orn_#{Time.now.to_i}_#{rand(10000)}"
    end

    # Salva atributo no dicionário Ornato de uma entidade SketchUp
    def self.set_attr(entity, dict, key, value)
      entity.set_attribute(dict, key.to_s, value)
    end

    # Lê atributo do dicionário Ornato
    def self.get_attr(entity, dict, key, default = nil)
      entity.get_attribute(dict, key.to_s, default)
    end

    # Serializa hash para JSON simples (sem dependência externa)
    def self.to_json(obj)
      case obj
      when Hash
        pairs = obj.map { |k, v| "\"#{k}\":#{to_json(v)}" }
        "{#{pairs.join(',')}}"
      when Array
        items = obj.map { |v| to_json(v) }
        "[#{items.join(',')}]"
      when String
        "\"#{obj.gsub('"', '\\"')}\""
      when Symbol
        "\"#{obj}\""
      when Numeric
        obj.to_s
      when TrueClass, FalseClass
        obj.to_s
      when NilClass
        'null'
      else
        "\"#{obj}\""
      end
    end

    # Parse JSON simples (sem dependência externa)
    # Para dados complexos, usar json gem se disponível
    def self.parse_json(str)
      begin
        require 'json'
        JSON.parse(str, symbolize_names: true)
      rescue LoadError
        # Fallback básico — só para dados simples
        eval(str.gsub('null', 'nil').gsub('true', 'true').gsub('false', 'false'))
      end
    end

    # Cria um material SketchUp com cor
    def self.criar_material(model, nome, cor)
      mat = model.materials[nome]
      return mat if mat
      mat = model.materials.add(nome)
      mat.color = cor
      mat
    end

    # Verifica se uma entidade é um módulo Ornato
    def self.modulo_ornato?(entity)
      return false unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      get_attr(entity, Config::DICT_MODULO, 'tipo') != nil
    end

    # Encontra todos os módulos Ornato no modelo
    def self.listar_modulos(model = nil)
      model ||= Sketchup.active_model
      modulos = []
      model.active_entities.each do |e|
        modulos << e if modulo_ornato?(e)
      end
      modulos
    end

    # Retorna informações resumidas de um módulo
    def self.info_modulo(entity)
      return nil unless modulo_ornato?(entity)
      {
        id:       get_attr(entity, Config::DICT_MODULO, 'id'),
        tipo:     get_attr(entity, Config::DICT_MODULO, 'tipo'),
        nome:     get_attr(entity, Config::DICT_MODULO, 'nome'),
        largura:  get_attr(entity, Config::DICT_MODULO, 'largura'),
        altura:   get_attr(entity, Config::DICT_MODULO, 'altura'),
        profundidade: get_attr(entity, Config::DICT_MODULO, 'profundidade'),
        ambiente: get_attr(entity, Config::DICT_MODULO, 'ambiente', 'Geral')
      }
    end

    # Desenha um retângulo 3D (caixa) dentro de um grupo/entities
    # Retorna o grupo criado
    def self.criar_caixa_3d(entities, x, y, z, larg, alt, prof, nome: nil, material: nil)
      larg_su = mm(larg)
      alt_su  = mm(alt)
      prof_su = mm(prof)
      x_su    = mm(x)
      y_su    = mm(y)
      z_su    = mm(z)

      pts = [
        Geom::Point3d.new(x_su, y_su, z_su),
        Geom::Point3d.new(x_su + larg_su, y_su, z_su),
        Geom::Point3d.new(x_su + larg_su, y_su + prof_su, z_su),
        Geom::Point3d.new(x_su, y_su + prof_su, z_su)
      ]

      face = entities.add_face(pts)
      face.pushpull(-alt_su)

      if material
        face.material = material
        face.back_material = material
      end

      face
    end
  end
end
