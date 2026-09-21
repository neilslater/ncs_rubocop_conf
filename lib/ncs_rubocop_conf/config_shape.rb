# frozen_string_literal: true

module NcsRuboCopConf
  # Checks the small supported configuration vocabulary, not effective policy.
  # @api private
  class ConfigShape
    EXCEPTION_KEYS = %w[Exclude Max].freeze
    DEFAULT_SWITCHES = %w[DisabledByDefault EnabledByDefault].freeze

    def self.exception?(key, value)
      EXCEPTION_KEYS.include?(key.value) ||
        (key.value == 'Enabled' && value.is_a?(Psych::Nodes::Scalar) && value.plain && value.value == 'false')
    end

    def initialize(path)
      @inheritance = ConfigInheritance.new(path)
    end

    def check(root)
      root.children.each_slice(2) { |key, value| check_section(key, value) }
    end

    private

    attr_reader :inheritance

    def check_section(key, value)
      case key.value
      when 'inherit_from' then inheritance.check_files(value)
      when 'inherit_gem' then inheritance.check_gems(value)
      when 'plugins' then inheritance.values(value)
      when 'require' then ConfigSyntax.reject(key, 'custom Ruby loading through require')
      else check_settings(key, value)
      end
    end

    def check_settings(section, node)
      ConfigSyntax.reject(node, 'expected a section mapping') unless node.is_a?(Psych::Nodes::Mapping)
      node.children.each_slice(2) do |key, value|
        if section.value == 'AllCops' && DEFAULT_SWITCHES.include?(key.value)
          ConfigSyntax.reject(key, 'global default-enable/disable switches')
        end
        next unless department?(section.value) && self.class.exception?(key, value)

        ConfigSyntax.reject(key, 'whole-department exception settings')
      end
    end

    def department?(name)
      /\A[A-Z][A-Za-z0-9_]*\z/.match?(name) && name != 'AllCops'
    end
  end
end
