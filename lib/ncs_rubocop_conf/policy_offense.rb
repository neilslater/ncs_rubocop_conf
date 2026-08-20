# frozen_string_literal: true

module NcsRuboCopConf
  # One exception-audit finding with source location and explanation.
  PolicyOffense = Struct.new(:path, :line, :message, keyword_init: true) do
    def format(root:)
      relative_path = Pathname(path).relative_path_from(Pathname(root))
      "#{relative_path}:#{line}: #{message}"
    end
  end
end
