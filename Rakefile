# encoding: UTF-8
require 'rubygems'
begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rake'
require 'rake/rdoctask'

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end

task :default => :test

Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'ModernTimes'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.summary = 'Asynchronous task library'
    gemspec.description = 'Generic asynchronous task library'
    gemspec.authors = ['Brad Pardee']
    gemspec.email = ['bradpardee@gmail.com']
    gemspec.homepage = 'http://github.com/ClarityServices/modern_times'
    gemspec.add_dependency 'jruby-jms', ['>= 0.11.2']
    gemspec.add_dependency 'rumx'
  end
rescue LoadError
  puts 'Jeweler not available. Install it with: gem install jeweler'
end
