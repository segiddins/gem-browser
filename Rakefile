# frozen_string_literal: true

require 'bundler/setup'

require 'rubocop/rake_task'
RuboCop::RakeTask.new

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

task default: %i[rubocop spec]
