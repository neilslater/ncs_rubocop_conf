# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NcsRuboCopConf do
  it 'fails public documentation checking for a missing method description' do
    with_project('lib/example.rb' => "# Public example.\nclass Example\n  def undocumented; end\nend\n") do |root|
      stdout, stderr, status = run_control(root, 'documentation')
      expect([status.success?,
              stdout + stderr]).to match [false, /Undocumented public Ruby objects: Example#undocumented/]
    end
  end

  it 'rejects a controlled line coverage shortfall' do
    source = "def untested\n  work\nend\n"
    expect(coverage_failure(source)).to match [2, /Line coverage .* is below the expected minimum coverage/]
  end

  it 'rejects a branch shortfall even when every line runs' do
    source = "def example(flag); flag ? 1 : 2; end\nexample(true)\n"
    expect(coverage_failure(source)).to match [2, /Branch coverage .* is below the expected minimum coverage/]
  end

  def run_control(root, name, *arguments)
    Open3.capture3(Gem.ruby, FixtureHelpers::ROOT.join("tasks/#{name}.rb").to_s, *arguments, chdir: root.to_s)
  end

  def coverage_failure(source)
    with_project('lib/example.rb' => source) do |root|
      arguments = ['-r', FixtureHelpers::ROOT.join('tasks/coverage.rb').to_s, '-r', './lib/example', '-e', 'nil']
      stdout, stderr, status = Open3.capture3(Gem.ruby, *arguments, chdir: root.to_s)
      [status.exitstatus, stdout + stderr]
    end
  end
end
