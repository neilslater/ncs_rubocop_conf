# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe NcsRuboCopConf::ExceptionAudit do
  it 'reports a clean audit to the supplied output' do
    with_project({}) do |root|
      output = StringIO.new
      expect(clean_report(root, output))
        .to eq [true, nil, "RuboCop exception audit passed\n"]
    end
  end

  it 'reports relative paths, source lines, and the offense count' do
    with_project('nested/.rubocop.yml' => "Style/GlobalVars:\n  Enabled: false\n") do |root|
      output = StringIO.new
      expect(failed_report(root, output)).to eq [false, violation_report]
    end
  end

  it 'reuses its findings and requires a new audit after an edit' do
    with_project('.rubocop.yml' => "Style/GlobalVars:\n  Max: 1\n") do |root|
      audit = described_class.new(root:)
      findings = audit.offenses
      expect(after_edit(root, audit, findings)).to eq [true, true]
    end
  end

  it 'resolves explicit relative and absolute configurations while replacing discovery' do
    with_project(selected_configs) do |root|
      audit = described_class.new(root:, config_paths: ['config/relative.yml', root.join('config/absolute.yml')])
      expect(audit.offenses.map { |item| item.path.relative_path_from(root).to_s })
        .to contain_exactly('config/relative.yml', 'config/absolute.yml')
    end
  end

  it 'keeps TODO and source scanning with an explicit empty configuration list' do
    with_project('.rubocop_todo.yml' => '{}', 'sample.rb' => '# rubocop:todo Style/GlobalVars') do |root|
      expect(described_class.new(root:, config_paths: []).offenses.map(&:message)).to contain_exactly(
        '.rubocop_todo.yml is not permitted', 'rubocop:todo directives are not permitted'
      )
    end
  end

  it 'defaults to the working directory' do
    with_project({}) do |root|
      Dir.chdir(root) { expect(described_class.new.success?).to be true }
    end
  end

  def clean_report(root, output)
    audit = described_class.new(root:)
    [audit.success?, audit.report(out: output), output.string]
  end

  def failed_report(root, output)
    audit = described_class.new(root:)
    audit.report(out: output)
    [audit.success?, output.string]
  end

  def after_edit(root, audit, findings)
    root.join('.rubocop.yml').write('--- {}')
    [audit.offenses.equal?(findings), described_class.new(root:).success?]
  end

  def selected_configs
    %w[.rubocop.yml config/relative.yml config/absolute.yml].to_h do |path|
      [path, "Style/GlobalVars:\n  Exclude: []\n"]
    end
  end

  def violation_report
    "nested/.rubocop.yml:1: local RuboCop exception needs an immediately preceding rationale\n" \
      "1 exception audit offense(s)\n"
  end
end
