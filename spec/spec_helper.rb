# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'tmpdir'
require 'yaml'
require 'ncs_rubocop_conf'

module FixtureHelpers
  ROOT = Pathname(__dir__).join('..').expand_path
  CONFIG_ROOT = ROOT.join('config')

  def with_project(files)
    Dir.mktmpdir('ncs-rubocop-conf') do |directory|
      write_files(directory, files)
      yield Pathname(directory)
    end
  end

  def with_rubocop_project(profiles, files, &)
    inherited = profiles.map { |profile| CONFIG_ROOT.join("#{profile}.yml").to_s }
    with_project({ '.rubocop.yml' => { 'inherit_from' => inherited }.to_yaml }.merge(files), &)
  end

  def rubocop_offenses(root, files, only:)
    stdout, stderr, status = run_rubocop(root, files, only)
    validate_rubocop_result(stdout, stderr, status)

    JSON.parse(stdout).fetch('files').flat_map { |file| file.fetch('offenses') }
  end

  def rubocop_cop_names(root, files, only:)
    rubocop_offenses(root, files, only:).map { |offense| offense.fetch('cop_name') }
  end

  private

  def run_rubocop(root, files, only)
    command = [Gem.ruby, Gem.bin_path('rubocop', 'rubocop'), '--no-server', '--format', 'json',
               '--cache', 'false', '--force-exclusion', '--only', only.join(','), *files]
    environment = { 'RUBOCOP_CACHE_ROOT' => root.join('.rubocop-cache').to_s }
    Open3.capture3(environment, *command, chdir: root.to_s)
  end

  def validate_rubocop_result(stdout, stderr, status)
    raise "RuboCop failed: #{stderr}" unless [0, 1].include?(status.exitstatus)
    raise "RuboCop returned no JSON: #{stderr}" if stdout.empty?
  end

  def write_files(directory, files)
    files.each do |relative_path, contents|
      path = Pathname(directory).join(relative_path)
      FileUtils.mkdir_p(path.dirname)
      path.write(contents)
    end
  end
end

RSpec.configure do |config|
  config.include FixtureHelpers
end
