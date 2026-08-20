# frozen_string_literal: true

module NcsRuboCopConf
  # Checks exception-like settings in one RuboCop YAML configuration.
  class ConfigAudit
    RATIONALE = /^\s*# RuboCop rationale: \S/
    SECTION = %r{^(?:AllCops|[A-Z][A-Za-z0-9]*/[A-Za-z0-9_]+):}
    TOP_LEVEL_KEY = %r{^[A-Za-z][A-Za-z0-9_/-]*:}
    EXCEPTION_SETTING = /^\s{2}(?:Exclude|Max):|^\s{2}Enabled:\s*false(?:\s|$)/

    def initialize(path)
      @path = path
    end

    def offenses
      lines = path.readlines
      section_lines(lines).filter_map { |line_number| offense_for(lines, line_number) }
    end

    private

    attr_reader :path

    def section_lines(lines)
      lines.each_index.select { |index| lines[index].match?(SECTION) }
    end

    def offense_for(lines, line_number)
      block = lines[line_number...section_end(lines, line_number)]
      return unless block.any? { |line| line.match?(EXCEPTION_SETTING) }
      return if line_number.positive? && lines[line_number - 1].match?(RATIONALE)

      PolicyOffense.new(
        path:,
        line: line_number + 1,
        message: 'local RuboCop exception needs an immediately preceding rationale'
      )
    end

    def section_end(lines, line_number)
      next_line = ((line_number + 1)...lines.length).find do |index|
        lines[index].match?(TOP_LEVEL_KEY)
      end
      next_line || lines.length
    end
  end
end
