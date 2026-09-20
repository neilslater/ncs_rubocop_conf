# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NcsRuboCopConf::DirectiveAudit do
  # Each fixture checks both exception policy and actual RuboCop offenses.
  # Keep this contract when upgrading the private DirectiveComment adapter.
  shared_examples 'directive conformance' do |directive, audit_message, reported_lines|
    it "agrees on #{directive.inspect}" do
      source = "# #{directive}\n$example = 1\n"
      expect(conformance(source)).to eq [audit_message ? [[1, audit_message]] : [], reported_lines]
    end
  end

  {
    'rubocop:disable Style/GlobalVars' => 'disable',
    'rubocop : disable Style/GlobalVars' => 'disable',
    "rubocop\t:\tdisable Style/GlobalVars" => 'disable',
    'rubocop : todo Style/GlobalVars' => 'todo',
    'rubocop:push -Style/GlobalVars' => 'push',
    'rubocop : push +Layout/LineLength -Style/GlobalVars' => 'push',
    'rubocop:push -Style/GlobalVars +Layout/LineLength' => 'push',
    'rubocop:push +Style/GlobalVars -Style/GlobalVars' => 'push',
    'rubocop:disable Style/GlobalVars -- annotation' => 'disable',
    'rubocop:disable Style/GlobalVars, Layout/LineLength -- annotation' => 'disable',
    'rubocop:push -Style/GlobalVars -- annotation' => 'push'
  }.each do |directive, mode|
    message = mode == 'todo' ? 'directives are not permitted' : 'needs an immediately preceding rationale'
    it_behaves_like 'directive conformance', directive, "rubocop:#{mode} #{message}", []
  end

  ['-Style', '+Layout/LineLength -Style', '-Style +Layout/LineLength'].each do |operands|
    it_behaves_like 'directive conformance', "rubocop:push #{operands}",
                    'rubocop:push must name only specific cops', []
  end

  ['# rubocop:disable Style/GlobalVars', '# rubocop : todo Style/GlobalVars',
   'rubocop:unknown Style/GlobalVars', 'rubocop:disablex Style/GlobalVars',
   'rubocop:push', 'rubocop:push +Style/GlobalVars', 'rubocop:pop'].each do |directive|
    it_behaves_like 'directive conformance', directive, nil, [2]
  end

  it_behaves_like 'directive conformance', 'rubocop:disable Style/GlobalVars garbage',
                  'rubocop:disable directive is malformed', []
  it_behaves_like 'directive conformance', 'rubocop:push -Style/GlobalVars garbage',
                  'rubocop:push directive is malformed', []
  it_behaves_like 'directive conformance', 'rubocop:push ??? -Style/GlobalVars',
                  'rubocop:push directive is malformed', [2]
  it_behaves_like 'directive conformance', 'rubocop:disable',
                  'rubocop:disable must name only specific cops', [2]
  it_behaves_like 'directive conformance', 'rubocop:push -Style/GlobalVars +Style/GlobalVars',
                  'rubocop:push needs an immediately preceding rationale', [2]

  it 'accepts documented multiple-cop suppression and restoration' do
    expect(conformance(documented_source)).to eq [[], [6]]
  end

  it 'tracks nested positive pushes and restoration of an earlier disable' do
    expect(conformance(nested_source)).to eq [[], [6, 12, 16]]
  end

  it 'still audits the original undocumented exception when pop restores it' do
    source = nested_source.sub('# RuboCop rationale: external DSL', '# no rationale')
    expect(conformance(source)).to eq [[[2, 'rubocop:disable needs an immediately preceding rationale']], [6, 12, 16]]
  end

  it 'rejects inline suppressing push operands' do
    source = "$example = 1 # rubocop:push -Style/GlobalVars\n$example = 2\n"
    expect(conformance(source)).to eq [[[1, 'rubocop:push must appear on its own line']], []]
  end

  it 'ignores strings and heredocs containing apparent directives' do
    expect(conformance(literal_source)).to eq [[], [5]]
  end

  it 'matches block comments without mistaking them for standalone suppressions' do
    source = "=begin\n# rubocop:disable Style/GlobalVars\n=end\n$example = 1\n"
    expect(conformance(source)).to eq [[[1, 'rubocop:disable must appear on its own line']], [4]]
  end

  it 'checks suppressing pushes inside block comments' do
    source = "=begin\n# rubocop:push -Style/GlobalVars\n=end\n$example = 1\n"
    expect(conformance(source)).to eq [[[1, 'rubocop:push must appear on its own line']], []]
  end

  it 'rejects TODO directives inside block comments' do
    source = "=begin\n# rubocop:todo Style/GlobalVars\n=end\n$example = 1\n"
    expect(conformance(source)).to eq [[[1, 'rubocop:todo directives are not permitted']], [4]]
  end

  def conformance(source)
    with_rubocop_project(%w[base], 'sample.rb' => source) do |root|
      findings = NcsRuboCopConf::ExceptionAudit.new(root:).offenses
      offenses = rubocop_offenses(root, %w[sample.rb], only: %w[Style/GlobalVars])
      [findings.map { |offense| [offense.line, offense.message] },
       offenses.map { |offense| offense.fetch('location').fetch('start_line') }]
    end
  end

  def documented_source
    <<~RUBY
      # RuboCop rationale: external DSL
      # rubocop : disable Style/GlobalVars, Layout/LineLength -- annotation
      $example = 1
      # rubocop : enable Style/GlobalVars, Layout/LineLength
      # restored
      $example = 2
    RUBY
  end

  def nested_source
    <<~RUBY
      # RuboCop rationale: external DSL
      # rubocop:disable Style/GlobalVars
      $example = 1
      # rubocop:push +Style/GlobalVars
      # positive push enables the cop
      $example = 2
      # RuboCop rationale: nested DSL
      # rubocop:push +Layout/LineLength -Style/GlobalVars -- annotation
      $example = 3
      # rubocop:pop
      # restored positive push
      $example = 4
      # rubocop:pop
      $example = 5
      # rubocop:enable Style/GlobalVars
      $example = 6
    RUBY
  end

  def literal_source
    <<~RUBY
      text = '# rubocop:disable Style/GlobalVars'
      text = <<~TEXT
        # rubocop:push -Style/GlobalVars
      TEXT
      $example = 1
    RUBY
  end
end
