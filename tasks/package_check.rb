# frozen_string_literal: true

require 'bundler'
require 'fileutils'
require 'json'
require 'open3'
require 'rubygems/package'
require 'tmpdir'

# Builds and exercises the artifact without exposing checkout code to consumers.
module PackageCheck
  ROOT = File.expand_path('..', __dir__)
  EXPECTED_FILES = %w[
    CHANGELOG.md LICENSE README.md
    config/base.yml config/native_extension.yml config/rake.yml config/rspec.yml
    exe/ncs-rubocop-conf-audit lib/ncs_rubocop_conf.rb
    lib/ncs_rubocop_conf/config_audit.rb lib/ncs_rubocop_conf/directive_audit.rb
    lib/ncs_rubocop_conf/directive_comment.rb lib/ncs_rubocop_conf/exception_audit.rb
    lib/ncs_rubocop_conf/policy_offense.rb lib/ncs_rubocop_conf/project_files.rb
    lib/ncs_rubocop_conf/version.rb
  ].freeze

  module_function

  def run
    Dir.mktmpdir('ncs-package') do |directory|
      spec = Gem::Specification.load(File.join(ROOT, 'ncs_rubocop_conf.gemspec'))
      artifact = Gem::Package.build(spec, false, true, File.join(directory, 'policy.gem'))
      raise 'Package file inventory changed' unless Gem::Package.new(artifact).spec.files.sort == EXPECTED_FILES.sort

      check_installation(directory, spec, artifact)
    end
    puts 'Package inventory, installed profiles, library, and executable passed'
  end

  def runtime_specs(spec)
    spec.runtime_dependencies.flat_map do |dependency|
      installed = Gem::Specification.find_by_name(dependency.name, dependency.requirement)
      [installed, *runtime_specs(installed)]
    end.uniq(&:full_name)
  end

  def check_installation(directory, spec, artifact)
    home = File.join(directory, 'gems')
    consumer = File.join(directory, 'consumer')
    FileUtils.mkdir_p(consumer)
    Bundler.with_unbundled_env do
      environment = { 'GEM_HOME' => home, 'GEM_PATH' => home, 'RUBYLIB' => nil, 'RUBYOPT' => nil }
      install(environment, consumer, home, [*runtime_archives(spec), artifact])
      check_library(environment, consumer, home)
      check_profiles(environment, consumer, home)
      check_executable(environment, consumer, home)
    end
  end

  def runtime_archives(spec)
    runtime_specs(spec).reject(&:default_gem?).map(&:cache_file)
  end

  def install(environment, consumer, home, archives)
    arguments = [File.join(RbConfig::CONFIG.fetch('bindir'), 'gem'), 'install', '--install-dir', home,
                 '--local', '--no-document', '--ignore-dependencies', *archives]
    command(environment, consumer, arguments)
  end

  def command(environment, directory, arguments, expected: 0)
    stdout, stderr, status = Open3.capture3(environment, Gem.ruby, *arguments, chdir: directory)
    raise "#{arguments.first} exited #{status.exitstatus}: #{stdout}\n#{stderr}" unless status.exitstatus == expected

    stdout
  end

  def check_library(environment, consumer, home)
    source = <<~RUBY
      require 'ncs_rubocop_conf'
      path = Gem.loaded_specs.fetch('ncs_rubocop_conf').full_gem_path
      installed = File.realpath(path).start_with?(File.realpath(#{home.dump}))
      abort "Loaded package outside isolated installation: \#{path}" unless installed
      abort 'Loaded checkout code' if $LOADED_FEATURES.any? { |file| file.start_with?(#{ROOT.dump}) }
    RUBY
    command(environment, consumer, ['-e', source])
  end

  def check_profiles(environment, consumer, home)
    profiles = %w[base rake rspec native_extension].map { |name| "    - config/#{name}.yml" }
    File.write(File.join(consumer, '.rubocop.yml'), "inherit_gem:\n  ncs_rubocop_conf:\n#{profiles.join("\n")}\n")
    File.write(File.join(consumer, 'sample.rb'), "$example = 1\n")
    arguments = [File.join(home, 'bin/rubocop'), '--no-server', '--cache', 'false', '--format', 'json', 'sample.rb']
    output = command(environment, consumer, arguments, expected: 1)
    raise 'Installed consumer did not check globals' unless cop_names(output).include?('Style/GlobalVars')
  end

  def cop_names(output)
    JSON.parse(output).fetch('files').flat_map do |file|
      file.fetch('offenses').map { |item| item.fetch('cop_name') }
    end
  end

  def check_executable(environment, consumer, home)
    arguments = [File.join(home, 'bin/ncs-rubocop-conf-audit'), '--root', consumer]
    output = command(environment, consumer, arguments)
    raise 'Missing success summary' unless output == "RuboCop exception audit passed\n"

    File.write(File.join(consumer, '.rubocop_todo.yml'), "--- {}\n")
    output = command(environment, consumer, arguments, expected: 1)
    expected = ".rubocop_todo.yml:1: .rubocop_todo.yml is not permitted\n1 exception audit offense(s)\n"
    raise 'Unexpected installed audit diagnostic' unless output == expected
  end
end

PackageCheck.run if $PROGRAM_NAME == __FILE__
