# frozen_string_literal: true

require 'yard'

# Checks documented public Ruby objects; the README owns CLI/profile prose.
module DocumentationCheck
  module_function

  def internal?(object)
    return false if object.root?
    return true if object.has_tag?(:api) && object.tag(:api).text == 'private'

    internal?(object.namespace)
  end

  def undocumented_objects
    YARD::Registry.all.reject { |object| internal?(object) }.select do |object|
      object.visibility == :public && object.docstring.empty?
    end
  end

  def run
    YARD::Registry.clear
    YARD.parse('lib/**/*.rb')
    missing = undocumented_objects
    abort "Undocumented public Ruby objects: #{missing.map(&:path).join(', ')}" unless missing.empty?
    abort 'YARD reported documentation warnings' if YARD::Logger.instance.warned

    puts 'Public Ruby API documentation passed (CLI and profiles: README.md)'
  end
end

DocumentationCheck.run if $PROGRAM_NAME == __FILE__
