# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NcsRuboCopConf::ExceptionAudit do
  it 'accepts documented YAML and inline exceptions' do
    with_project(valid_exception_files) do |root|
      expect(described_class.new(root:).offenses).to be_empty
    end
  end

  it 'reports an undocumented YAML exception' do
    with_project('.rubocop.yml' => "Style/GlobalVars:\n  Exclude:\n    - extconf.rb\n") do |root|
      expect(described_class.new(root:).offenses.map(&:message))
        .to eq ['local RuboCop exception needs an immediately preceding rationale']
    end
  end

  it 'reports an undocumented inline disable' do
    directive = ['#', ' rubocop:disable Style/GlobalVars'].join
    with_project('sample.rb' => "#{directive}\nvalue = $example\n") do |root|
      expect(described_class.new(root:).offenses.map(&:message))
        .to eq ['rubocop:disable needs an immediately preceding rationale']
    end
  end

  it 'rejects TODO configuration and directives' do
    with_project(todo_exception_files) do |root|
      expect(described_class.new(root:).offenses.map(&:message)).to contain_exactly(
        '.rubocop_todo.yml is not permitted', 'rubocop:todo directives are not permitted'
      )
    end
  end

  def valid_exception_files
    rationale = '# RuboCop rationale: the external DSL requires this form.'
    directive = ['#', ' rubocop:disable Style/GlobalVars'].join
    {
      '.rubocop.yml' => "#{rationale}\nStyle/GlobalVars:\n  Exclude:\n    - extconf.rb\n",
      'sample.rb' => "#{rationale}\n#{directive}\nvalue = $example\n# rubocop:enable Style/GlobalVars\n"
    }
  end

  def todo_exception_files
    directive = ['#', ' rubocop:todo Style/GlobalVars'].join
    { '.rubocop_todo.yml' => "Style/GlobalVars:\n  Exclude: []\n", 'sample.rb' => directive }
  end
end
