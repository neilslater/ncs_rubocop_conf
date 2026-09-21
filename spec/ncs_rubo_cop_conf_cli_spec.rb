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

  it 'fails unsupported configuration with a distinct location and explanation' do
    with_project('.rubocop.yml' => "'Style/GlobalVars':\n  Enabled: false\n") do |root|
      expect(invoke(['--root', root.to_s]))
        .to match [1, /\A\.rubocop.yml:1: Configuration not supported yet.*quoted.*\n1 exception audit offense\(s\)\n$/]
    end
  end

  it 'reports a skipped-before-0.3 Ruby bin script through the CLI' do
    with_project('bin/console' => "#!/usr/bin/env ruby\n# rubocop:todo all\n") do |root|
      expect(invoke(['--root', root.to_s]))
        .to eq [1, "bin/console:2: rubocop:todo directives are not permitted\n1 exception audit offense(s)\n"]
    end
  end

  it 'describes the root option in help' do
    expect(invoke(['--help'])).to match [0, /Usage: ncs-rubocop-conf-audit \[--root PATH\].*Repository root to audit/m]
  end
end
