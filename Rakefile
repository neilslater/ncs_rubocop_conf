# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require_relative 'lib/ncs_rubocop_conf'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = ['--cache', 'false']
end

desc 'Audit RuboCop exception documentation and placement'
task :audit do
  config_paths = Dir['config/*.yml'] + ['.rubocop.yml']
  audit = NcsRuboCopConf::ExceptionAudit.new(config_paths:)
  audit.report
  abort 'RuboCop exception audit failed' unless audit.success?
end

task default: %i[spec rubocop audit]
