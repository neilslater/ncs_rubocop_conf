# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NcsRuboCopConf::DirectiveAudit do
  def audit(source)
    with_project('sample.rb' => source) do |root|
      described_class.new(root.join('sample.rb')).offenses.map { |offense| [offense.line, offense.message] }
    end
  end

  def documented(text)
    "# RuboCop rationale: the external DSL requires this form.\n# #{text}\n"
  end

  %w[disable todo].each do |mode|
    ["rubocop:#{mode}", "rubocop : #{mode}", "rubocop:\t#{mode}"].each do |header|
      it "rejects undocumented #{header}" do
        message = mode == 'todo' ? 'directives are not permitted' : 'needs an immediately preceding rationale'
        expect(audit("# #{header} Style/GlobalVars\n")).to eq [[1, "rubocop:#{mode} #{message}"]]
      end
    end
  end

  ['disable Style/GlobalVars', 'push -Style/GlobalVars'].each do |operand|
    context "with #{operand}" do
      let(:mode) { operand.split.first }

      it 'accepts a documented standalone suppression' do
        expect(audit(documented("rubocop:#{operand}"))).to be_empty
      end

      it 'accepts indentation and a trailing annotation' do
        expect(audit(documented("rubocop : #{operand} -- external DSL").gsub(/^#/, '  #'))).to be_empty
      end

      it 'does not use an annotation as the rationale' do
        expect(audit("# rubocop:#{operand} -- external DSL\n"))
          .to eq [[1, "rubocop:#{mode} needs an immediately preceding rationale"]]
      end

      ['', ' ', "\t"].each do |blank|
        it "rejects a blank rationale #{blank.inspect}" do
          expect(audit("# RuboCop rationale: #{blank}\n# rubocop:#{operand}\n"))
            .to eq [[2, "rubocop:#{mode} needs an immediately preceding rationale"]]
        end
      end

      it 'rejects a displaced rationale' do
        expect(audit("# RuboCop rationale: reason\n\n# rubocop:#{operand}\n"))
          .to eq [[3, "rubocop:#{mode} needs an immediately preceding rationale"]]
      end

      it 'rejects inline placement with a rationale' do
        expect(audit(documented("rubocop:#{operand}").sub("\n#", "\n$example = 1 #")))
          .to eq [[2, "rubocop:#{mode} must appear on its own line"]]
      end

      it 'rejects directives embedded after other comment text' do
        expect(audit(documented("rubocop:#{operand}").sub("\n#", "\n# explanation #")))
          .to eq [[2, "rubocop:#{mode} must appear on its own line"]]
      end

      it 'rejects malformed trailing text even with a rationale' do
        expect(audit(documented("rubocop:#{operand} extra")))
          .to eq [[2, "rubocop:#{mode} directive is malformed"]]
      end
    end
  end

  ['all', 'Style', 'GlobalVars', 'Style/GlobalVars, Style'].each do |names|
    it "rejects broad disable operands #{names}" do
      expect(audit(documented("rubocop:disable #{names}")))
        .to eq [[2, 'rubocop:disable must name only specific cops']]
    end
  end

  ['-all', '-Style', '-GlobalVars', '+Style/GlobalVars -Style', '-Style/GlobalVars -Layout'].each do |names|
    it "rejects broad negative push operands #{names}" do
      expect(audit(documented("rubocop:push #{names}")))
        .to eq [[2, 'rubocop:push must name only specific cops']]
    end
  end

  ['disable', 'disable -- annotation'].each do |operand|
    it "rejects missing cop names in #{operand}" do
      expect(audit(documented("rubocop:#{operand}")))
        .to eq [[2, 'rubocop:disable must name only specific cops']]
    end
  end

  ['disable Style/GlobalVars, Layout/LineLength', 'push +Style -Style/GlobalVars -Layout/LineLength',
   'disable Example/Nested/Cop', 'push -Example/Nested/Cop'].each do |operand|
    it "accepts specific names in #{operand}" do
      expect(audit(documented("rubocop:#{operand}"))).to be_empty
    end
  end

  ['push', 'push +Style', 'push +Style/GlobalVars', 'pop', 'enable all', 'unknown Style/GlobalVars',
   'disablex Style/GlobalVars'].each do |operand|
    it "does not treat #{operand} as a suppression" do
      expect(audit("# rubocop:#{operand}\n")).to be_empty
    end
  end

  it 'rejects a malformed push whose negative operand was not parsed' do
    expect(audit('# rubocop:push ?? -Style/GlobalVars')).to eq [[1, 'rubocop:push directive is malformed']]
  end

  it 'rejects malformed TODO directives' do
    expect(audit('# rubocop : todo ???')).to eq [[1, 'rubocop:todo directives are not permitted']]
  end

  it 'ignores escaped example comments' do
    expect(audit("# # rubocop:disable Style/GlobalVars\n#\t# rubocop : todo Style/GlobalVars\n")).to be_empty
  end

  it 'ignores directive text in strings and heredocs' do
    expect(audit("text = '# rubocop:disable Style/GlobalVars'\ntext = <<~TEXT\n# rubocop:todo all\nTEXT\n"))
      .to be_empty
  end

  it 'treats an embedded document as one Ruby comment at its opening line' do
    expect(audit("=begin\n# rubocop:todo Style/GlobalVars\n=end\n"))
      .to eq [[1, 'rubocop:todo directives are not permitted']]
  end

  it 'does not mistake embedded document directives for standalone directives' do
    expect(audit("=begin\n# rubocop:disable Style/GlobalVars\n=end\n"))
      .to eq [[1, 'rubocop:disable must appear on its own line']]
  end

  it 'uses one source read per invocation without reading lines separately' do
    path = instance_double(Pathname, read: '# rubocop:disable Style/GlobalVars')
    described_class.new(path).offenses
    expect(path).to have_received(:read).once
  end

  it 'refreshes the source on subsequent invocations' do
    path = instance_double(Pathname)
    allow(path).to receive(:read).and_return('# rubocop:disable Style/GlobalVars', documented('rubocop:push'))
    auditor = described_class.new(path)
    auditor.offenses
    expect(auditor.offenses).to be_empty
  end
end
