# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NcsRuboCopConf::ConfigAudit do
  unsupported = {
    "# Dynamic input\n<%= 'AllCops:' %>\n" => [2, 'ERB'],
    "'Style/GlobalVars':\n  Enabled: false\n" => [1, 'quoted or non-plain mapping keys'],
    "Style/GlobalVars:\n  'Enabled': false\n" => [2, 'quoted or non-plain mapping keys'],
    "Style/GlobalVars: {Enabled: false}\n" => [1, 'flow mappings'],
    "Style/GlobalVars:\n    Enabled: false\n" => [2, 'noncanonical mapping indentation'],
    "  Style/GlobalVars:\n    Enabled: false\n" => [1, 'noncanonical mapping indentation'],
    "Style/GlobalVars:\n  Enabled: no\n" => [2, 'alternative boolean spelling'],
    "AllCops: &settings\n  NewCops: enable\n" => [1, 'YAML anchors'],
    "Style/GlobalVars: *missing\n" => [1, 'YAML aliases'],
    "Style/GlobalVars:\n  <<: other\n" => [2, 'YAML merge keys'],
    "AllCops: !ruby/object:Example\n  NewCops: enable\n" => [1, 'explicit YAML tags'],
    "AllCops:\n  NewCops: !!str enable\n" => [2, 'explicit YAML tags'],
    "!!str AllCops:\n  NewCops: enable\n" => [1, 'explicit YAML tags'],
    "AllCops:\n  NewCops: enable\n---\nAllCops:\n  NewCops: enable\n" => [3, 'multiple YAML documents'],
    "AllCops:\n  NewCops: enable\n  NewCops: disable\n" => [3, 'duplicate mapping keys'],
    "? [Style, GlobalVars]\n: false\n" => [1, 'complex mapping keys'],
    "--- false\n" => [1, 'expected a configuration mapping'],
    "- config/base.yml\n" => [1, 'expected a configuration mapping'],
    "Style/GlobalVars: false\n" => [1, 'expected a section mapping'],
    "Style:\n  Enabled: false\n" => [2, 'whole-department exception settings'],
    "Style:\n  Exclude: []\n" => [2, 'whole-department exception settings'],
    "AllCops:\n  DisabledByDefault: true\n" => [2, 'global default-enable/disable switches'],
    "AllCops:\n  EnabledByDefault: false\n" => [2, 'global default-enable/disable switches'],
    "require: ./custom.rb\n" => [1, 'custom Ruby loading through require'],
    "inherit_from: missing.yml\n" => [1, 'inheritance outside this gem\'s known profiles'],
    "inherit_from: https://example.invalid/config.yml\n" => [1, 'inheritance outside this gem\'s known profiles'],
    "inherit_from: config/*.yml\n" => [1, 'inheritance outside this gem\'s known profiles'],
    "inherit_from:\n  local: config/base.yml\n" => [2, 'expected a scalar or list of scalar references'],
    "inherit_gem:\n  another_gem: config/base.yml\n" => [2, 'inheritance from another gem'],
    "inherit_gem:\n  ncs_rubocop_conf: config/unknown.yml\n" => [2, 'unknown gem profile'],
    "inherit_gem:\n  ncs_rubocop_conf: config/*.yml\n" => [2, 'unknown gem profile'],
    "inherit_gem: ncs_rubocop_conf\n" => [1, 'expected an inherit_gem mapping'],
    "inherit_gem:\n  ncs_rubocop_conf:\n" => [2, 'expected a scalar or list of scalar references'],
    "plugins:\n  - name: custom\n" => [2, 'expected a scalar or list of scalar references']
  }

  unsupported.each do |source, (line, reason)|
    it "reports #{reason} in #{source.inspect}" do
      expect(findings(source)).to eq [[line, unsupported_message(reason)]]
    end
  end

  %w[y Y yes YES n N No NO on On off OFF TRUE False].each do |boolean|
    it "reports noncanonical boolean #{boolean}" do
      expect(findings("Example/Cop:\n  Enabled: #{boolean}\n"))
        .to eq [[2, unsupported_message('alternative boolean spelling')]]
    end
  end

  it 'reports malformed YAML at its parser location' do
    expect(findings("Style/GlobalVars: [\n")).to match [[2, /not supported yet.*invalid YAML/]]
  end

  it 'does not let a rationale authorize unsupported syntax' do
    expect(findings("# RuboCop rationale: external DSL\n'Style/GlobalVars':\n  Enabled: false\n"))
      .to eq [[2, unsupported_message('quoted or non-plain mapping keys')]]
  end

  it 'stops exception interpretation for the whole unsupported configuration' do
    source = "Style/GlobalVars:\n  Exclude: []\nOther/Cop: {Enabled: false}\n"
    expect(findings(source)).to eq [[3, unsupported_message('flow mappings')]]
  end

  ['', "# No local settings\n", "plugins: rubocop-performance\n",
   "plugins: [rubocop-rspec, rubocop-performance]\n", "Style:\n  Enabled: true\n",
   "Example/Cop:\n  Enabled: 'false'\n", "Example/Cop:\n  Enabled: []\n",
   "Example/Cop:\n  Custom:\n    - Name: value\n", "inherit_from: []\n"].each do |source|
    it "accepts supported syntax #{source.inspect}" do
      expect(findings(source)).to be_empty
    end
  end

  %w[Exclude Max Enabled].each do |setting|
    it "retains rationale checking for #{setting}" do
      value = { 'Exclude' => '[]', 'Max' => '10', 'Enabled' => 'false' }.fetch(setting)
      expect(findings("Example/Nested/Cop:\n  #{setting}: #{value}\n"))
        .to eq [[1, 'local RuboCop exception needs an immediately preceding rationale']]
    end
  end

  it 'accepts the documented ordinary settings, plugins, and inheritance forms' do
    expect(findings(ordinary_configuration)).to be_empty
  end

  it 'accepts known packaged profiles by scalar or list reference' do
    expect(findings("inherit_gem:\n  ncs_rubocop_conf: config/base.yml\n")).to be_empty
  end

  it 'accepts the tracked profiles and source-repository self-hosting' do
    paths = Dir[FixtureHelpers::CONFIG_ROOT.join('*.yml')] + [FixtureHelpers::ROOT.join('.rubocop.yml')]
    expect(paths.flat_map { |path| described_class.new(Pathname(path)).offenses }).to be_empty
  end

  it 'accepts source-profile fixtures using absolute paths' do
    with_rubocop_project(%w[base rspec], {}) do |root|
      expect(described_class.new(root.join('.rubocop.yml')).offenses).to be_empty
    end
  end

  it 'does not trust similarly named local profiles' do
    expect(findings("inherit_from: config/base.yml\n"))
      .to eq [[1, unsupported_message('inheritance outside this gem\'s known profiles')]]
  end

  it 'does not open an unsupported inheritance target' do
    with_project('.rubocop.yml' => "inherit_from: local.yml\n", 'local.yml' => "Style:\n  Enabled: false\n") do |root|
      File.chmod(0, root.join('local.yml'))
      expect(described_class.new(root.join('.rubocop.yml')).offenses.map(&:line)).to eq [1]
    end
  end

  %w[require erb plugin].each do |kind|
    it "does not execute #{kind} configuration" do
      expect(execution_probe(kind)).to be false
    end
  end

  def findings(source)
    with_project('.rubocop.yml' => source) do |root|
      described_class.new(root.join('.rubocop.yml')).offenses.map { |item| [item.line, item.message] }
    end
  end

  def unsupported_message(reason)
    "Configuration not supported yet by the exception audit: #{reason}. Use the documented subset or request support."
  end

  def ordinary_configuration
    <<~YAML
      inherit_gem:
        ncs_rubocop_conf:
          - config/base.yml
          - config/rake.yml
          - config/rspec.yml
          - config/native_extension.yml
      plugins:
        - rubocop-performance
      inherit_mode:
        merge:
          - Exclude
      # RuboCop rationale: exclude local research from product linting.
      AllCops:
        Exclude: ['docs/agent/**/*']
      # RuboCop rationale: external DSL uses this form.
      Example/Cop:
        Exclude:
          - 'lib/adapter.rb'
    YAML
  end

  def execution_probe(kind)
    with_project({}) do |root|
      marker = root.join('executed')
      code = "File.write(#{marker.to_s.dump}, 'executed')"
      root.join('custom.rb').write(code)
      source = { 'require' => "require: #{root.join('custom.rb')}\n", 'erb' => "<%= #{code} %>\n",
                 'plugin' => "plugins: #{root.join('custom.rb')}\n" }.fetch(kind)
      root.join('.rubocop.yml').write(source)
      described_class.new(root.join('.rubocop.yml')).offenses
      marker.exist?
    end
  end
end
