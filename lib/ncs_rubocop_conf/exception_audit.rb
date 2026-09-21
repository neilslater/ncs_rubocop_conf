# frozen_string_literal: true

require 'pathname'

module NcsRuboCopConf
  # Audits repository-local RuboCop exceptions and their rationale comments.
  class ExceptionAudit
    # Prohibited generated TODO configuration filename.
    TODO_CONFIG = '.rubocop_todo.yml'

    # Creates an audit; findings are evaluated lazily and cached.
    # @param root [String, Pathname] repository root (defaults to the working directory)
    # @param config_paths [Array<String, Pathname>, nil] explicit configuration
    #   paths replacing discovery; relative paths resolve against root
    def initialize(root: Dir.pwd, config_paths: nil)
      @root = Pathname(root).expand_path
      @configured_paths = config_paths&.map { |path| expand(path) }
    end

    # Returns findings from selected configuration, TODO files, and Ruby sources.
    # @return [Array<PolicyOffense>] cached findings; construct a new audit after edits
    def offenses
      @offenses ||= begin
        files = ProjectFiles.new(root).to_a
        todo_offenses(files) + config_offenses(files) + directive_offenses(files)
      end
    end

    # Writes relative locations and the pass/offense-count summary.
    # @param out [IO] destination for diagnostics
    # @return [nil]
    def report(out: $stdout)
      offenses.each { |offense| out.puts offense.format(root:) }
      out.puts(offenses.empty? ? 'RuboCop exception audit passed' : "#{offenses.length} exception audit offense(s)")
      nil
    end

    # Whether the selected inputs yielded no policy findings.
    # @return [Boolean]
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
