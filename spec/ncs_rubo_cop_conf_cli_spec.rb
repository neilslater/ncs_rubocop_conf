# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe NcsRuboCopConf do
  def invoke(arguments)
    original = ARGV.dup
    original_stdout = $stdout
    $stdout = StringIO.new
    ARGV.replace(arguments)
    load FixtureHelpers::ROOT.join('exe/ncs-rubocop-conf-audit')
  rescue SystemExit => e
    [e.status, $stdout.string]
  ensure
    ARGV.replace(original)
    $stdout = original_stdout
  end

  it 'accepts a clean explicit root with a success exit and summary' do
    with_project({}) do |root|
      expect(invoke(['--root', root.to_s])).to eq [0, "RuboCop exception audit passed\n"]
    end
  end

  it 'rejects an offense with a failure exit and diagnostic' do
    with_project('.rubocop_todo.yml' => '{}') do |root|
      expect(invoke(['--root', root.to_s]))
        .to eq [1, ".rubocop_todo.yml:1: .rubocop_todo.yml is not permitted\n1 exception audit offense(s)\n"]
    end
  end

  it 'describes the root option in help' do
    expect(invoke(['--help'])).to match [0, /Usage: ncs-rubocop-conf-audit \[--root PATH\].*Repository root to audit/m]
  end
end
