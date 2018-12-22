#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'
require 'rubygems/package'
require 'stringio'
require 'sinatra'
require 'net/https'

require 'rouge'

class Package < Gem::Package
  def self.from_string(string)
    io = StringIO.new(string)
    io.rewind
    new io
  end

  def at_path(path)
    by_dir = {}
    @gem.with_read_io do |io|
      gem_tar = Gem::Package::TarReader.new io
      gem_tar.each do |entry|
        next unless entry.full_name == 'data.tar.gz'

        open_tar_gz entry do |pkg_tar|
          pkg_tar.each do |contents_entry|
            full_name = contents_entry.full_name
            dirname = File.dirname(full_name)
            (by_dir[dirname] ||= Set['.', '..']) << File.basename(full_name)
            (by_dir[File.dirname(dirname)] ||= Set['.', '..']) << File.basename(dirname)
            next unless full_name == path

            return contents_entry.read
          end
        end
      end
    end

    by_dir['.']&.delete('..')

    by_dir[path] ||

      raise("#{path.inspect} not found in #{self}")
  end
end

def fetch_gem_content(full_name)
  url = URI "https://rubygems.org/downloads/#{full_name}.gem"
  Net::HTTP.get(url).freeze
end

get '/gems/:full_name' do |full_name|
  redirect "/gems/#{full_name}/"
end

get '/gems/:full_name/*?' do |full_name, path|
  s = fetch_gem_content(full_name)
  package = Package.from_string(s)
  path.chomp!('/')
  path = '.' if path.empty?
  content = package.at_path(path)
  content_type 'text/plain'
  case content
  when Set
    return content.sort.join("\n") if params['raw']

    content_type 'text/html'
    '<ul>' +
      content.sort.map { |l| "<li><a href='/gems/#{full_name}/#{path}/#{l}'>#{l}</a></li>" }.join +
      '</ul>'
  when String
    return content if params['raw']

    content_type 'text/html'
    <<~HTML
      <head>
        <link rel='stylesheet' type='text/css' href='/highlight.css'>
      </head>
      <body>
        <h3>
          <a href='/gems/#{full_name}/#{File.dirname path}'>#{File.dirname path}</a>
          /
          <a href='/gems/#{full_name}/#{path}'>#{File.basename path}</a>
        </h3>
        #{html_highlight(source: content, filename: path)}
      </body>
    HTML
  end
end

get '/gemspecs/:full_name' do |full_name|
  url = URI "https://rubygems.org/quick/Marshal.#{Gem.marshal_version}/#{full_name}.gemspec.rz"
  rz = Net::HTTP.get(url)
  marshal = Gem::Util.inflate rz
  spec = Marshal.load marshal
  content_type 'text/plain'
  ruby = spec.to_ruby

  return ruby if params['raw']

  content_type 'text/html'
  <<~HTML
    <head>
      <link rel='stylesheet' type='text/css' href='/highlight.css'>
    </head>
    <body>
      <h3><a href='/gems/#{full_name}/'>#{spec.full_name}</a></h3>
      #{html_highlight(source: ruby, filename: spec.spec_name)}
    </body>
  HTML
end

get '/highlight.css' do
  content_type 'text/css'
  Rouge::Theme.find('github').render(scope: '.highlight')
end

get '/' do
  content_type 'text/html'
  <<~HTML
    <body>
      <h1>Gem Browser</h1>

      <p>Browse gems hosted on <a href="https://rubygems.org">rubygems.org</a>!</p>

      <p>For example, to browse <a href="https://rubygems.org/gems/bundler/versions/1.17.2">Bundler 1.17.2</a>:</p>

      <p><a href="/gems/bundler-1.17.2">You can browse the contents of the gem</a><br/>

      <a href="/gemspecs/bundler-1.17.2">as well as the gemspec!</a></p>
    </body>
  HTML
end

def html_highlight(source:, filename: nil)
  "<div class='highlight'>" +
    Rouge.highlight(
      source,
      Rouge::Lexer.guess(source: source, filename: filename),
      Rouge::Formatters::HTMLTable.new(Rouge::Formatters::HTML.new)
    ) +
    '</div>'
end
