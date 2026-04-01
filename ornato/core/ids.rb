# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Paramétrica de Marcenaria Industrial
# core/ids.rb — Geração e validação de identidades
#
# Estratégia de identidade em 4 camadas:
#   1. ornato_id   — identidade de domínio (gerada aqui, nunca muda)
#   2. persistent_id — vínculo com entity SketchUp (pode mudar)
#   3. pid_path     — caminho aninhado de persistent_ids (recalculado)
#   4. heurística   — fallback por tipo+dimensões+posição (último recurso)
#
# Formato: orn_ + 8 hex (timestamp) + 4 hex (random) = 16 chars
# Collision probability: < 1 em 65.536 por segundo (aceitável para uso local)

require 'securerandom'
require 'digest'

module Ornato
  module Core
    module Ids
      ID_PREFIX   = 'orn_'.freeze
      ID_PATTERN  = /\Aorn_[0-9a-f]{12}\z/.freeze
      REV_PREFIX  = 'rev_'.freeze
      EXP_PREFIX  = 'exp_'.freeze

      # Gera ornato_id único.
      # Usa timestamp (4 bytes big-endian) + random (2 bytes) para:
      #   - Ordenação temporal natural
      #   - Baixa colisão sem coordenação central
      #   - Legibilidade em logs e debugging
      #
      # @return [String] ex: "orn_67c8a1b2f3d4"
      def self.generate
        timestamp_hex = [Time.now.to_i].pack('N').unpack1('H8')
        random_hex = SecureRandom.hex(2)
        "#{ID_PREFIX}#{timestamp_hex}#{random_hex}"
      end

      # Valida formato de ornato_id.
      # @param id [String]
      # @return [Boolean]
      def self.valid?(id)
        id.is_a?(String) && id.match?(ID_PATTERN)
      end

      # Constrói pid_path para hierarquias aninhadas.
      # @param parent_path [String, nil] caminho do pai
      # @param ornato_id [String] id da entidade
      # @return [String] ex: "orn_abc.../orn_def.../orn_ghi..."
      def self.build_path(parent_path, ornato_id)
        parent_path ? "#{parent_path}/#{ornato_id}" : ornato_id
      end

      # Decompõe pid_path em segmentos válidos.
      # @param pid_path [String]
      # @return [Array<String>] lista de ornato_ids
      def self.parse_path(pid_path)
        return [] unless pid_path.is_a?(String)
        pid_path.split('/').select { |seg| valid?(seg) }
      end

      # Retorna o ornato_id do pai a partir de um pid_path.
      # @param pid_path [String]
      # @return [String, nil]
      def self.parent_from_path(pid_path)
        segments = parse_path(pid_path)
        segments.length > 1 ? segments[-2] : nil
      end

      # Retorna o ornato_id raiz de um pid_path.
      # @param pid_path [String]
      # @return [String, nil]
      def self.root_from_path(pid_path)
        segments = parse_path(pid_path)
        segments.first
      end

      # Profundidade no pid_path (0 = raiz).
      # @param pid_path [String]
      # @return [Integer]
      def self.depth(pid_path)
        parse_path(pid_path).length - 1
      end

      # Gera ID para exportação.
      # @return [String] ex: "exp_a1b2c3d4e5f6"
      def self.generate_export_id
        "#{EXP_PREFIX}#{SecureRandom.hex(6)}"
      end

      # Gera ID para revisão.
      # @return [String] ex: "rev_a1b2c3d4e5f6"
      def self.generate_revision_id
        "#{REV_PREFIX}#{SecureRandom.hex(6)}"
      end

      # Gera hash SHA256 determinístico a partir de dados.
      # Usado para hashes de entidade na exportação.
      # @param data [Hash, String] dados para hash
      # @return [String] "sha256:xxxx..." (primeiros 16 chars do hex)
      def self.content_hash(data)
        content = data.is_a?(String) ? data : sorted_json(data)
        full_hash = Digest::SHA256.hexdigest(content)
        "sha256:#{full_hash[0, 16]}"
      end

      private

      # JSON determinístico com chaves ordenadas recursivamente.
      # Garante que o mesmo dado sempre produz o mesmo hash.
      def self.sorted_json(obj)
        case obj
        when Hash
          pairs = obj.sort_by { |k, _| k.to_s }.map do |k, v|
            "#{k.to_s.inspect}:#{sorted_json(v)}"
          end
          "{#{pairs.join(',')}}"
        when Array
          "[#{obj.map { |v| sorted_json(v) }.join(',')}]"
        when Symbol
          obj.to_s.inspect
        when NilClass
          'null'
        when TrueClass, FalseClass
          obj.to_s
        when Numeric
          obj.to_s
        else
          obj.to_s.inspect
        end
      end
    end
  end
end
