require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = 'modern_times'
    gemspec.summary = 'Asynchronous task library'
    gemspec.description = 'Generic asynchronous task library'
    gemspec.authors = ['Brad Pardee', 'Reid Morrison']
    gemspec.email = ['bradpardee@gmail.com', 'rubywmq@gmail.com']
    gemspec.homepage = 'http://github.com/ClarityServices/modern_times'
    gemspec.add_dependency 'jruby-hornetq', ['>= 0.3.2']
    gemspec.add_dependency 'ClarityServices-jmxjr'
  end
rescue LoadError
  puts 'Jeweler not available. Install it with: gem install jeweler'
end

desc "Run Test Suite"
task :test do
  Rake::TestTask.new(:functional) do |t|
    t.test_files = FileList['test/*_test.rb']
    t.verbose    = true
  end

  Rake::Task['functional'].invoke
end
