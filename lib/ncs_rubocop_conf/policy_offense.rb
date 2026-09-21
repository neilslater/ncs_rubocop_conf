# frozen_string_literal: true

module NcsRuboCopConf
  # One exception-audit finding with source location and explanation.
  PolicyOffense = Struct.new(:path, :line, :message, keyword_init: true) do
    # @!attribute path
    #   Source file associated with the finding.
    #   @return [Pathname]
    # @!attribute line
    #   One-based source line of the finding.
    #   @return [Integer]
    # @!attribute message
    #   Explanation of the policy violation.
    #   @return [String]

    # Formats a finding as path:line:message relative to the supplied root.
    # @param root [String, Pathname] repository root for relative diagnostics
    # @return [String]
    def format(root:)
      relative_path = Pathname(path).relative_path_from(Pathname(root))
      "#{relative_path}:#{line}: #{message}"
    end
  end
end
