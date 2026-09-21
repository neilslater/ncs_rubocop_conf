# frozen_string_literal: true

require 'simplecov'
require 'simplecov_json_formatter'

SimpleCov.start do
  enable_coverage :branch
  track_files '{lib/**/*.rb,exe/*}'
  formatter SimpleCov::Formatter::MultiFormatter.new([SimpleCov::Formatter::HTMLFormatter,
                                                      SimpleCov::Formatter::JSONFormatter])
  add_filter '/spec/'
  add_filter '/tasks/'
  minimum_coverage line: 95, branch: 95
  use_merging false
end
