# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NcsRuboCopConf do
  { 'Method' => ['def example', 10], 'Class' => ['class Example', 100],
    'Module' => ['module Example', 100], 'Block' => ['items.each do', 25] }.each do |kind, (opening, limit)|
    context "with Metrics/#{kind}Length" do
      let(:cop) { "Metrics/#{kind}Length" }

      %w[array hash].each do |literal|
        it "folds a multiline #{literal}" do
          source = literal_source(opening, literal, limit + 1)
          expect(length_offenses(source, cop)).to be_empty
        end
      end

      it 'still measures ordinary statements beyond the limit' do
        source = ([opening] + Array.new(limit + 1, 'work') + ['end']).join("\n")
        expect(length_offenses(source, cop)).to eq [cop]
      end
    end
  end

  [5, 6].each do |count|
    it "checks #{count} positional parameters against the five-parameter limit" do
      arguments = Array.new(count) { |index| "arg#{index}" }.join(', ')
      names = length_offenses("def example(#{arguments}); end", 'Metrics/ParameterLists')
      expect(names).to eq(count == 5 ? [] : ['Metrics/ParameterLists'])
    end
  end

  it 'retains the exact RSpec defaults' do
    with_rubocop_project(%w[base rspec], {}) do |root|
      config = rubocop_config(root)
      expect([config['RSpec/ExampleLength']['Max'], config['RSpec/MultipleExpectations']['Max']]).to eq [5, 1]
    end
  end

  [5, 6].each do |count|
    it "checks an RSpec example with #{count} ordinary lines" do
      body = Array.new(count - 1, 'work') + ['expect(result).to be(true)']
      expect(example_offenses(body, 'RSpec/ExampleLength')).to eq(count == 5 ? [] : ['RSpec/ExampleLength'])
    end
  end

  [1, 2].each do |count|
    it "checks an RSpec example with #{count} expectations" do
      body = Array.new(count, 'expect(result).to be(true)')
      names = example_offenses(body, 'RSpec/MultipleExpectations')
      expect(names).to eq(count == 1 ? [] : ['RSpec/MultipleExpectations'])
    end
  end

  it 'merges namespace with the upstream refine allowance' do
    with_rubocop_project(%w[base rake], {}) do |root|
      expect(rubocop_config(root)['Metrics/BlockLength']['AllowedMethods']).to contain_exactly('refine', 'namespace')
    end
  end

  it 'continues to allow a long refine block' do
    source = (['refine String do'] + Array.new(26, 'work') + ['end']).join("\n")
    with_rubocop_project(%w[base rake], 'sample.rb' => source) do |root|
      expect(rubocop_cop_names(root, %w[sample.rb], only: %w[Metrics/BlockLength])).to be_empty
    end
  end

  { 'base' => [], 'rake' => ['Rake/Desc'], 'rspec' => ['RSpec/ExampleLength'] }.each do |profile, expected|
    it "loads only the selected #{profile} plugin in a fresh process" do
      with_rubocop_project([profile], {}) do |root|
        expect(plugin_cops(root)).to eq expected
      end
    end
  end

  it 'does not allow long namespaces without the Rake profile' do
    source = (['namespace :example do'] + Array.new(26, 'work') + ['end']).join("\n")
    expect(length_offenses(source, 'Metrics/BlockLength')).to eq ['Metrics/BlockLength']
  end

  { 'ext/demo/extconf.rb' => false, 'ext/extconf.rb' => false, 'nested/ext/demo/extconf.rb' => false,
    'extconf.rb' => true, 'lib/sample.rb' => true, 'ext/demo/other.rb' => true }.each do |path, checked|
    it "#{checked ? 'checks' : 'excludes'} arbitrary globals in #{path}" do
      with_rubocop_project(%w[base native_extension], path => "$review_example = 1\n") do |root|
        expect(rubocop_cop_names(root, [path]).include?('Style/GlobalVars')).to be checked
      end
    end
  end

  it 'checks native globals when the optional profile is omitted' do
    with_rubocop_project(%w[base], 'ext/demo/extconf.rb' => "$review_example = 1\n") do |root|
      expect(rubocop_cop_names(root, %w[ext/demo/extconf.rb])).to include('Style/GlobalVars')
    end
  end

  def literal_source(opening, literal, count)
    entries = Array.new(count) { |index| literal == 'array' ? "#{index}," : "key#{index}: #{index}," }
    first, last = literal == 'array' ? ['[', ']'] : ['{', '}']
    ([opening, "values = #{first}"] + entries + [last, 'end']).join("\n")
  end

  def length_offenses(source, cop)
    with_rubocop_project(%w[base], 'sample.rb' => source) do |root|
      rubocop_cop_names(root, %w[sample.rb], only: [cop])
    end
  end

  def example_offenses(body, cop)
    source = (['describe Example do', "it 'checks the boundary' do"] + body + %w[end end]).join("\n")
    with_rubocop_project(%w[base rspec], 'spec/example_spec.rb' => source) do |root|
      rubocop_cop_names(root, %w[spec/example_spec.rb], only: [cop])
    end
  end

  def plugin_cops(root)
    source = <<~RUBY
      require 'rubocop'
      config = RuboCop::ConfigLoader.configuration_from_file('.rubocop.yml')
      puts JSON.generate(%w[Rake/Desc RSpec/ExampleLength].select { |name| config.key?(name) })
    RUBY
    stdout, stderr, status = Open3.capture3(Gem.ruby, '-rjson', '-e', source, chdir: root.to_s)
    raise stderr unless status.success?

    JSON.parse(stdout)
  end
end
