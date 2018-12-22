#!/usr/bin/env ruby

require 'rubygems'
require 'rubygems/package'
require 'stringio'
require 'sinatra'
require 'net/https'

require 'rouge'

class Package < Gem::Package
  def self.from_string(s)
    io = StringIO.new(s)
    io.rewind
    new io
  end

  def at_path(path)
    verify unless @spec

    by_dir = {}
    @gem.with_read_io do |io|
      gem_tar = Gem::Package::TarReader.new io
      gem_tar.each do |entry|
        next unless entry.full_name == 'data.tar.gz'

        open_tar_gz entry do |pkg_tar|
          pkg_tar.each do |contents_entry|
            (by_dir[File.dirname(contents_entry.full_name) || ''] ||= Set[?., '..']) << File.basename(contents_entry.full_name)
            (by_dir[File.dirname File.dirname(contents_entry.full_name) || ''] ||= Set[?., '..']) << File.basename(File.dirname contents_entry.full_name)
            next unless contents_entry.full_name == path
            return contents_entry.read
          end
        end
      end
    end
    
    by_dir['.']&.delete('..')
    
    by_dir[path] or
    
    raise "#{path.inspect} not found in #{self}"
  end
end

def fetch_gem_content(full_name)
  url = URI "https://rubygems.org/downloads/#{full_name}.gem"
  Net::HTTP.get(url).freeze
end

get "/gems/:full_name" do |full_name|
  redirect "/gems/#{full_name}/"
end

get "/gems/:full_name/*?" do |full_name, path|
  s = fetch_gem_content(full_name)
  package = Package.from_string(s)
  path.chomp!('/')
  path = '.' if path.empty?
  content = package.at_path(path)
  content_type 'text/plain'
  case content
  when Set
    return content.sort.join(?\n) if params['raw']
    content_type 'text/html'
    "<ul>" + content.sort.map { |l| "<li><a href='/gems/#{full_name}/#{path}/#{l}'>#{l}</a></li>" }.join + "</ul>"
  when String
    return content if params['raw']
    content_type 'text/html'
    "<head><link rel='stylesheet' type='text/css' href='/highlight.css'></head>" \
    "<body>" \
    "<h3><a href='/gems/#{full_name}/#{File.dirname path}'>#{File.dirname path}</a>/<a href='/gems/#{full_name}/#{path}'>#{File.basename path}</a></h3>" \
    "<div class='highlight'>#{Rouge.highlight content, Rouge::Lexer.guess(source: content, filename: path), Rouge::Formatters::HTMLTable.new(Rouge::Formatters::HTML.new)}</div>" \
    "</body>"
  end
end

get "/gemspecs/:full_name" do |full_name|
  url = URI "https://rubygems.org/quick/Marshal.#{Gem.marshal_version}/#{full_name}.gemspec.rz"
  rz = Net::HTTP.get(url)
  marshal = Gem::Util.inflate rz
  spec = Marshal.load marshal
  content_type 'text/plain'
  ruby = spec.to_ruby
  
  return ruby if params['raw']
  content_type 'text/html'
  "<head><link rel='stylesheet' type='text/css' href='/highlight.css'></head>" \
  "<body>" \
  "<h3><a href='/gems/#{full_name}/'>#{spec.full_name}</a></h3>" \
  "<div class='highlight'>#{Rouge.highlight ruby, Rouge::Lexer.guess(source: ruby, filename: spec.spec_name), Rouge::Formatters::HTMLTable.new(Rouge::Formatters::HTML.new)}</div>" \
  "</body>"
end

get '/highlight.css' do
  content_type 'text/css'
  Rouge::Theme.find('github').render(scope: '.highlight')
end