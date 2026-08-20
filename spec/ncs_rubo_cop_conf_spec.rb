# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NcsRuboCopConf do
  it 'folds array and hash literals and ignores keyword parameters' do
    with_rubocop_project(%w[base], 'sample.rb' => folded_method_source) do |root|
      offenses = rubocop_offenses(root, %w[sample.rb], only: %w[Metrics/MethodLength Metrics/ParameterLists])
      expect(offenses).to be_empty
    end
  end

  it 'retains upstream RSpec example and expectation limits' do
    with_rubocop_project(%w[base rspec], 'spec/defaults_spec.rb' => long_example_source) do |root|
      expect(rubocop_cop_names(root, %w[spec/defaults_spec.rb], only: rspec_length_cops)).to contain_exactly(
        'RSpec/ExampleLength', 'RSpec/MultipleExpectations'
      )
    end
  end

  it 'folds array and hash literals in RSpec examples' do
    with_rubocop_project(%w[base rspec], 'spec/folded_spec.rb' => folded_example_source) do |root|
      expect(rubocop_offenses(root, %w[spec/folded_spec.rb], only: rspec_length_cops)).to be_empty
    end
  end

  it 'allows long Rake namespace containers' do
    with_rubocop_project(%w[base rake], 'Rakefile' => long_rake_block('namespace')) do |root|
      expect(rubocop_offenses(root, %w[Rakefile], only: %w[Metrics/BlockLength])).to be_empty
    end
  end

  it 'continues to measure ordinary Rake task blocks' do
    with_rubocop_project(%w[base rake], 'Rakefile' => long_rake_block('task')) do |root|
      offenses = rubocop_offenses(root, %w[Rakefile], only: %w[Metrics/BlockLength])
      expect(offenses.map { |offense| offense.fetch('cop_name') }).to eq ['Metrics/BlockLength']
    end
  end

  it 'excludes only global-variable checks for native extconf files' do
    source = "$CFLAGS = \"-Wall\"\n"
    with_rubocop_project(%w[base native_extension], 'ext/demo/extconf.rb' => source) do |root|
      names = rubocop_cop_names(root, %w[ext/demo/extconf.rb], only: native_profile_cops)
      expect(names).to eq ['Style/StringLiterals']
    end
  end

  def rspec_length_cops
    %w[RSpec/ExampleLength RSpec/MultipleExpectations]
  end

  def native_profile_cops
    %w[Style/GlobalVars Style/StringLiterals]
  end

  def folded_method_source
    <<~RUBY
      def configure(one:, two:, three:, four:, five:, six:)
        values = [
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10
        ]
        options = {
          one: one,
          two: two,
          three: three,
          four: four,
          five: five,
          six: six
        }
        [values, options]
      end
    RUBY
  end

  def long_example_source
    <<~RUBY
      describe Example do
        it 'uses upstream limits' do
          one = 1
          two = 2
          three = 3
          four = 4
          five = 5
          six = 6
          expect(one + two + three).to eq(6)
          expect(four + five + six).to eq(15)
        end
      end
    RUBY
  end

  def folded_example_source
    <<~RUBY
      describe Example do
        it 'folds literals' do
          values = [
            1,
            2,
            3,
            4,
            5,
            6
          ]
          options = {
            low: 1,
            high: 6
          }
          expect(values.minmax).to eq([options[:low], options[:high]])
        end
      end
    RUBY
  end

  def long_rake_block(method_name)
    body = Array.new(26) { |index| "  work(#{index})" }
    (["#{method_name} :example do"] + body + ['end']).join("\n")
  end
end
