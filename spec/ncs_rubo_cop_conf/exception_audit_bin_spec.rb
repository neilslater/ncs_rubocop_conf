# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NcsRuboCopConf::ExceptionAudit do
  ['#!/usr/bin/env ruby', '#!/usr/bin/env -S ruby -w', '#!/usr/local/bin/ruby -w', '#! /usr/bin/ruby'].each do |shebang|
    it "audits nested bin scripts using #{shebang}" do
      expect(audit_bin("#{shebang}\n# rubocop:disable Style/GlobalVars\n"))
        .to eq [[2, 'rubocop:disable needs an immediately preceding rationale']]
    end
  end

  it 'accepts documented exceptions in a bin script' do
    source = "#!/usr/bin/env ruby\n# RuboCop rationale: external DSL\n# rubocop:disable Style/GlobalVars\n"
    expect(audit_bin(source)).to be_empty
  end

  it 'accepts clean Ruby launchers' do
    expect(audit_bin("#!/usr/bin/env ruby\nrequire 'irb'\nIRB.start\n")).to be_empty
  end

  it 'rejects prohibited directives in a bin script' do
    expect(audit_bin("#!/usr/bin/env ruby\n# rubocop:todo Style/GlobalVars\n"))
      .to eq [[2, 'rubocop:todo directives are not permitted']]
  end

  ['', "#!/bin/sh\n", "#!/bin/sh ruby\n", "#!/usr/bin/env python\n", '# no shebang',
   "#!/usr/bin/env ruby\n\0binary\n"].each do |prefix|
    it "skips non-Ruby or binary bin content #{prefix.inspect}" do
      expect(audit_bin("#{prefix}\n# rubocop:todo all\n")).to be_empty
    end
  end

  it 'keeps empty bin files harmless' do
    expect(audit_bin('')).to be_empty
  end

  it 'does not select an extensionless bin symlink' do
    with_project('target' => "#!/usr/bin/env ruby\n# rubocop:todo all\n", 'bin/empty' => '') do |root|
      File.symlink(root.join('target'), root.join('bin/launcher'))
      expect(described_class.new(root:).offenses).to be_empty
    end
  end

  %w[exe/console nested/bin/console bin/vendor/console sample.ru].each do |path|
    it "does not expand selection to #{path}" do
      with_project(path => "#!/usr/bin/env ruby\n# rubocop:todo all\n") do |root|
        expect(described_class.new(root:).offenses).to be_empty
      end
    end
  end

  it 'retains Ruby extension selection in bin without a shebang' do
    with_project('bin/example.rb' => '# rubocop:todo all') do |root|
      expect(described_class.new(root:).offenses.map(&:message)).to eq ['rubocop:todo directives are not permitted']
    end
  end

  def audit_bin(source)
    with_project('bin/tools/console' => source) do |root|
      described_class.new(root:).offenses.map { |item| [item.line, item.message] }
    end
  end
end
