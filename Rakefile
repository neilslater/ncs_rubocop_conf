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

desc 'Check locked dependencies against the updated advisory database'
task :dependency_audit do
  ruby Gem.bin_path('bundler-audit', 'bundler-audit'), 'check', '--update'
end

desc 'Check documentation for every public Ruby API object'
task :documentation do
  ruby 'tasks/documentation.rb'
end

desc 'Build and validate the installed package in a disposable consumer'
task :package_check do
  ruby 'tasks/package_check.rb'
end

task default: %i[spec rubocop audit dependency_audit documentation]
