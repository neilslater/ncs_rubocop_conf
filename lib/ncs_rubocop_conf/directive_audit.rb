# frozen_string_literal: true

require 'ripper'

module NcsRuboCopConf
  # Checks inline RuboCop control comments in one Ruby source file.
  class DirectiveAudit
    RATIONALE = /^\s*# RuboCop rationale: \S/
    DIRECTIVE = /#\s*rubocop:(disable|todo)\b(?:\s+([^\n]+))?/
    COP_NAME = %r{\A[A-Z][A-Za-z0-9_]*/[A-Z][A-Za-z0-9_]*\z}

    def initialize(path)
      @path = path
    end

    def offenses
      comments.filter_map { |position, token| offense_for(position, token) }
    end

    private

    attr_reader :path

    def comments
      Ripper.lex(path.read).filter_map do |(position, event, token, _state)|
        [position, token] if event == :on_comment && token.match?(DIRECTIVE)
      end
    end

    def offense_for(position, token)
      line_number, column = position
      action, cop_list = token.match(DIRECTIVE).captures
      message = directive_error(action, cop_list, line_number, column)
      return unless message

      PolicyOffense.new(path:, line: line_number, message:)
    end

    def directive_error(action, cop_list, line_number, column)
      return 'rubocop:todo directives are not permitted' if action == 'todo'
      return 'rubocop:disable must appear on its own line' unless standalone?(line_number, column)
      return 'rubocop:disable must name only specific cops' unless specific_cops?(cop_list)
      return if rationale?(line_number)

      'rubocop:disable needs an immediately preceding rationale'
    end

    def standalone?(line_number, column)
      path.readlines.fetch(line_number - 1)[0...column].strip.empty?
    end

    def specific_cops?(cop_list)
      names = cop_list.to_s.split(',').map(&:strip)
      names.any? && names.all? { |name| name.match?(COP_NAME) }
    end

    def rationale?(line_number)
      line_number > 1 && path.readlines.fetch(line_number - 2).match?(RATIONALE)
    end
  end
end
