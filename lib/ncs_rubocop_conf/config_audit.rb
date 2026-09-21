# frozen_string_literal: true

require_relative 'config_syntax'
require_relative 'config_inheritance'
require_relative 'config_shape'

module NcsRuboCopConf
  # Checks supported RuboCop YAML and adjacent exception rationales.
  # @api private
  class ConfigAudit
    RATIONALE = /^\s*# RuboCop rationale: \S/

    def initialize(path)
      @path = path
    end

    def offenses
      source = path.read
      root = ConfigSyntax.new(source, path).parse
      return [] unless root

      ConfigShape.new(path).check(root)
      exception_offenses(root, source.lines)
    rescue ConfigSyntax::Unsupported => e
      [PolicyOffense.new(path:, line: e.line, message: e.message)]
    end

    private

    attr_reader :path

    def exception_section?(key, value)
      return false unless key.value == 'AllCops' || key.value.include?('/')

      value.children.each_slice(2).any? { |setting, data| ConfigShape.exception?(setting, data) }
    end

    def rationale?(key, lines)
      key.start_line.positive? && lines[key.start_line - 1].match?(RATIONALE)
    end

    def exception_offenses(root, lines)
      root.children.each_slice(2).filter_map do |key, value|
        next unless exception_section?(key, value)
        next if rationale?(key, lines)

        PolicyOffense.new(path:, line: key.start_line + 1,
                          message: 'local RuboCop exception needs an immediately preceding rationale')
      end
    end
  end
end
