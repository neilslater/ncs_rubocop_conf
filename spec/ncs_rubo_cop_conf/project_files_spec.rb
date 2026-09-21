# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NcsRuboCopConf::ProjectFiles do
  it 'prunes conventional generated directories at every depth' do
    files = described_class::IGNORED_DIRECTORIES.to_h { |name| ["nested/#{name}/hidden.rb", ''] }
    with_project(files.merge('nested/visible.rb' => '')) do |root|
      expect(described_class.new(root).map { |path| path.relative_path_from(root).to_s }).to eq ['nested/visible.rb']
    end
  end

  it 'returns an enumerator and does not prune the root by basename' do
    with_project('tmp/visible.rb' => '') do |root|
      expect(described_class.new(root.join('tmp')).each.to_a).to eq [root.join('tmp/visible.rb')]
    end
  end
end
