# frozen_string_literal: true

require 'pathname'

module NcsRuboCopConf
  # Audits repository-local RuboCop exceptions and their rationale comments.
  class ExceptionAudit
    TODO_CONFIG = '.rubocop_todo.yml'

    def initialize(root: Dir.pwd, config_paths: nil)
      @root = Pathname(root).expand_path
      @configured_paths = config_paths&.map { |path| expand(path) }
    end

    def offenses
      @offenses ||= begin
        files = ProjectFiles.new(root).to_a
        todo_offenses(files) + config_offenses(files) + directive_offenses(files)
      end
    end

    def report(out: $stdout)
      offenses.each { |offense| out.puts offense.format(root:) }
      out.puts(offenses.empty? ? 'RuboCop exception audit passed' : "#{offenses.length} exception audit offense(s)")
      nil
    end

    def success?
      offenses.empty?
    end

    private

    attr_reader :configured_paths, :root

    def expand(path)
      pathname = Pathname(path)
      pathname.absolute? ? pathname : root.join(pathname)
    end

    def todo_offenses(files)
      files.filter_map do |path|
        next unless path.basename.to_s == TODO_CONFIG

        PolicyOffense.new(path:, line: 1, message: '.rubocop_todo.yml is not permitted')
      end
    end

    def config_offenses(files)
      paths = configured_paths || files.select { |path| rubocop_config?(path) }
      paths.flat_map { |path| ConfigAudit.new(path).offenses }
    end

    def directive_offenses(files)
      files.select { |path| ruby_source?(path) }
           .flat_map { |path| DirectiveAudit.new(path).offenses }
    end

    def rubocop_config?(path)
      %w[.rubocop.yml .rubocop.yaml].include?(path.basename.to_s)
    end

    def ruby_source?(path)
      %w[.rb .rake .gemspec].include?(path.extname) || %w[Gemfile Rakefile].include?(path.basename.to_s)
    end
  end
end
