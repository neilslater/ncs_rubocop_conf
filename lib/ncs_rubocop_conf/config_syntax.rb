# frozen_string_literal: true

require 'psych'

module NcsRuboCopConf
  # Reads YAML syntax without constructing objects or evaluating configuration.
  # @api private
  class ConfigSyntax
    # Carries the first unsupported construct's source location.
    class Unsupported < StandardError
      attr_reader :line

      def initialize(line, reason)
        @line = line
        super("Configuration not supported yet by the exception audit: #{reason}. " \
              'Use the documented subset or request support.')
      end
    end

    def self.reject(node, reason)
      raise Unsupported.new(node.start_line + 1, reason)
    end

    def initialize(source, path)
      @source = source
      @path = path
    end

    def parse
      reject_erb
      root = document_root(Psych.parse_stream(source, filename: path.to_s))
      return unless root

      visit(root, 0)
      root
    rescue Psych::SyntaxError => e
      raise Unsupported.new(e.line, "invalid YAML (#{e.problem})")
    end

    private

    attr_reader :source, :path

    def document_root(stream)
      return if stream.children.empty?

      self.class.reject(stream.children[1], 'multiple YAML documents') if stream.children.length > 1
      root = stream.children.first.root
      self.class.reject(root, 'expected a configuration mapping') unless root.is_a?(Psych::Nodes::Mapping)
      root
    end

    def reject_erb
      line = source.lines.find_index { |text| text.include?('<%') }
      raise Unsupported.new(line + 1, 'ERB') if line
    end

    def visit(node, indent)
      check_metadata(node)
      case node
      when Psych::Nodes::Mapping then check_mapping(node, indent)
      when Psych::Nodes::Sequence then node.children.each { |child| visit(child, node.start_column + 2) }
      when Psych::Nodes::Scalar then check_boolean(node)
      end
    end

    def check_metadata(node)
      self.class.reject(node, 'YAML aliases') if node.is_a?(Psych::Nodes::Alias)
      self.class.reject(node, 'YAML anchors') if node.anchor
      self.class.reject(node, 'explicit YAML tags') if node.tag
    end

    def check_mapping(node, indent)
      self.class.reject(node, 'flow mappings') if node.style == Psych::Nodes::Mapping::FLOW
      keys = []
      node.children.each_slice(2) do |key, value|
        check_key(key, indent, keys)
        keys << key.value
        visit(value, indent + 2)
      end
    end

    def check_key(key, indent, keys)
      check_key_style(key)
      self.class.reject(key, 'noncanonical mapping indentation') unless key.start_column == indent
      self.class.reject(key, 'duplicate mapping keys') if keys.include?(key.value)
      self.class.reject(key, 'YAML merge keys') if key.value == '<<'
    end

    def check_key_style(key)
      self.class.reject(key, 'complex mapping keys') unless key.is_a?(Psych::Nodes::Scalar)
      check_metadata(key)
      self.class.reject(key, 'quoted or non-plain mapping keys') unless key.plain
    end

    def check_boolean(node)
      return unless node.plain && /\A(?:y|yes|n|no|on|off|true|false)\z/i.match?(node.value)
      return if %w[true false].include?(node.value)

      self.class.reject(node, 'alternative boolean spelling')
    end
  end
end
