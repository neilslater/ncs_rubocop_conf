# frozen_string_literal: true

module NcsRuboCopConf
  # Recognizes references to this package's profiles without following them.
  # @api private
  class ConfigInheritance
    PROFILES = %w[config/base.yml config/rake.yml config/rspec.yml config/native_extension.yml].freeze
    SOURCE_PROFILES = PROFILES.map { |name| File.expand_path("../../#{name}", __dir__) }.freeze

    def initialize(path)
      @directory = File.dirname(File.expand_path(path))
    end

    def check_files(node)
      values(node).each do |value|
        next if SOURCE_PROFILES.include?(File.expand_path(value.value, directory))

        ConfigSyntax.reject(value, 'inheritance outside this gem\'s known profiles')
      end
    end

    def check_gems(node)
      ConfigSyntax.reject(node, 'expected an inherit_gem mapping') unless node.is_a?(Psych::Nodes::Mapping)
      node.children.each_slice(2) do |key, value|
        ConfigSyntax.reject(key, 'inheritance from another gem') unless key.value == 'ncs_rubocop_conf'
        values(value).each do |profile|
          ConfigSyntax.reject(profile, 'unknown gem profile') unless PROFILES.include?(profile.value)
        end
      end
    end

    def values(node)
      list = node.is_a?(Psych::Nodes::Sequence) ? node.children : [node]
      list.each do |value|
        next if value.is_a?(Psych::Nodes::Scalar) && !value.value.empty?

        ConfigSyntax.reject(value, 'expected a scalar or list of scalar references')
      end
      list
    end

    private

    attr_reader :directory
  end
end
