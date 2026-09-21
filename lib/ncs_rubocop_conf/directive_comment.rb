# frozen_string_literal: true

require 'ripper'
require 'rubocop'

module NcsRuboCopConf
  # Isolates the reviewed RuboCop private grammar API from exception policy.
  # @api private
  class DirectiveComment
    Comment = Struct.new(:text)

    attr_reader :line, :column

    def self.parse(source)
      comments = []
      Ripper.lex(source).each do |position, event, token, _state|
        case event
        when :on_comment, :on_embdoc_beg
          comments << [position, token.dup]
        when :on_embdoc, :on_embdoc_end
          comments.last.last << token
        end
      end
      comments.map { |position, text| new(position, text) }
    end

    def initialize(position, text)
      @line, @column = position
      @directive = RuboCop::DirectiveComment.new(Comment.new(text))
    end

    def mode
      directive.mode
    end

    def suppressed_names
      mode == 'push' ? directive.push_args.fetch('-', []) : directive.raw_cop_names.map(&:strip)
    end

    def suppression?
      %w[disable todo].include?(mode) || (mode == 'push' && suppressed_names.any?)
    end

    def malformed?
      directive.malformed?
    end

    def standalone?(lines)
      directive.start_with_marker? && lines.fetch(line - 1).byteslice(0, column).strip.empty?
    end

    private

    attr_reader :directive
  end
end
