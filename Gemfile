# frozen_string_literal: true

ruby File.read(File.expand_path('.ruby-version', __dir__)).strip

source 'https://rubygems.org' do
  gem 'rouge', '~> 3.11'
  gem 'sinatra', '2.0.8'

  group :development do
    gem 'rack-test'
    gem 'rake', '~> 12.3'
    gem 'rspec'
    gem 'rubocop', '~> 0.71.0'
  end
end
