# frozen_string_literal: true

require_relative 'lib/ncs_rubocop_conf/version'

Gem::Specification.new do |spec|
  spec.name = 'ncs_rubocop_conf'
  spec.version = NcsRuboCopConf::VERSION
  spec.authors = ['Neil Slater']
  spec.email = ['slobo777@gmail.com']
  spec.summary = 'Versioned RuboCop policy for Neil Slater Ruby repositories'
  spec.description = 'Shared base and framework RuboCop profiles with exception-policy auditing.'
  spec.homepage = 'https://github.com/neilslater/ncs_rubocop_conf'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3'

  spec.files = Dir['CHANGELOG.md', 'LICENSE', 'README.md', 'config/**/*.yml', 'exe/*', 'lib/**/*.rb']
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |path| File.basename(path) }
  spec.require_paths = ['lib']

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['source_code_uri'] = spec.homepage

  spec.add_dependency 'rubocop', '~> 1.89.0', '>= 1.89.0'
  spec.add_dependency 'rubocop-rake', '~> 0.7.0', '>= 0.7.1'
  spec.add_dependency 'rubocop-rspec', '~> 3.10.0', '>= 3.10.2'
end
