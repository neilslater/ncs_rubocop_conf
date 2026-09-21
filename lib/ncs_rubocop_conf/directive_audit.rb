# frozen_string_literal: true

require_relative 'directive_comment'

module NcsRuboCopConf
  # Checks inline RuboCop control comments in one Ruby source file.
  # @api private
  class DirectiveAudit
    RATIONALE = /^\s*# RuboCop rationale: \S/
    COP_NAME = %r{\A[A-Z][A-Za-z0-9_]*(?:/[A-Z][A-Za-z0-9_]*)+\z}

    def initialize(path)
      @path = path
    end

    def offenses
      source = path.read
      lines = source.lines
      DirectiveComment.parse(source).filter_map { |directive| offense_for(directive, lines) }
    end

    private

    attr_reader :path

    def offense_for(directive, lines)
      message = directive_error(directive, lines)
      return unless message

      PolicyOffense.new(path:, line: directive.line, message:)
    end

    def directive_error(directive, lines)
      return 'rubocop:todo directives are not permitted' if directive.mode == 'todo'
      return suppression_error(directive, lines) if directive.suppression?
      return unless directive.mode == 'push' && directive.malformed?

      'rubocop:push directive is malformed'
    end

    def suppression_error(directive, lines)
      prefix = "rubocop:#{directive.mode}"
      return "#{prefix} must appear on its own line" unless directive.standalone?(lines)
      return "#{prefix} must name only specific cops" unless specific_cops?(directive.suppressed_names)
      return "#{prefix} directive is malformed" if directive.malformed?
      return if rationale?(directive.line, lines)

      "#{prefix} needs an immediately preceding rationale"
    end

    def specific_cops?(names)
      names.any? && names.all? { |name| name.match?(COP_NAME) }
    end

    def rationale?(line_number, lines)
      line_number > 1 && lines.fetch(line_number - 2).match?(RATIONALE)
    end
  end
end
