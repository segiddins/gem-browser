# frozen_string_literal: true

require_relative '../app'
require 'rack/test'

RSpec.describe 'gem-browser' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  it 'has a homepage' do
    get '/'
    expect(last_response).to be_ok
    expect(last_response.body).to include('Gem Browser')
  end

  it '404s' do
    get '/gems/bundler/000000'
    expect(last_response).to be_not_found
  end

  it 'shows contents of a gem' do
    get '/gems/molinillo/versions/0.6.0'
    follow_redirect!
    expect(last_response.body).to eq <<~HTML
      <ul>
        <li><a href='/gems/molinillo/versions/0.6.0/./.'>.</a></li>
        <li><a href='/gems/molinillo/versions/0.6.0/./ARCHITECTURE.md'>ARCHITECTURE.md</a></li>
        <li><a href='/gems/molinillo/versions/0.6.0/./CHANGELOG.md'>CHANGELOG.md</a></li>
        <li><a href='/gems/molinillo/versions/0.6.0/./LICENSE'>LICENSE</a></li>
        <li><a href='/gems/molinillo/versions/0.6.0/./README.md'>README.md</a></li>
        <li><a href='/gems/molinillo/versions/0.6.0/./lib'>lib</a></li>
      </ul>
    HTML
  end

  it 'shows a file in a gem' do
    get '/gems/molinillo/versions/0.6.0/lib/molinillo/gem_metadata.rb'
    expect(last_response).to be_ok
    expect(last_response.body).to include('VERSION').and include('0.6.0')
  end
end
