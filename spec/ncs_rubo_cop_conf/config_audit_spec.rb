# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NcsRuboCopConf::ConfigAudit do
  it 'does not attach a later section exception to the previous section' do
    source = "AllCops:\n  TargetRubyVersion: 3.3\nStyle/GlobalVars:\n  Enabled: false\n"
    with_project('.rubocop.yml' => source) do |root|
      expect(described_class.new(root.join('.rubocop.yml')).offenses.map(&:line)).to eq [3]
    end
  end

  it 'requires the rationale before the header rather than the setting' do
    source = "Style/GlobalVars:\n  # RuboCop rationale: external DSL\n  Exclude: []\n"
    with_project('.rubocop.yml' => source) do |root|
      expect(described_class.new(root.join('.rubocop.yml')).offenses.map(&:line)).to eq [1]
    end
  end
end
