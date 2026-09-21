# frozen_string_literal: true

require 'find'
require 'pathname'

module NcsRuboCopConf
  # Enumerates maintained repository files while pruning generated directories.
  # @api private
  class ProjectFiles
    include Enumerable

    IGNORED_DIRECTORIES = %w[.bundle .git coverage pkg tmp vendor].freeze

    def initialize(root)
      @root = Pathname(root)
    end

    def each
      return enum_for(__method__) unless block_given?

      Find.find(root.to_s) do |name|
        path = Pathname(name)
        if path.directory?
          Find.prune if ignored_directory?(path)
        else
          yield path
        end
      end
    end

    private

    attr_reader :root

    def ignored_directory?(path)
      path != root && IGNORED_DIRECTORIES.include?(path.basename.to_s)
    end
  end
end
