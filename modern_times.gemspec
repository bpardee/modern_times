Gem::Specification.new do |s|
  s.name = "modern_times"
  s.summary = 'Asynchronous task library'
  s.description = 'Generic asynchronous task library'
  s.platform    = Gem::Platform::JRUBY
  s.authors = ['Brad Pardee']
  s.email = ['bradpardee@gmail.com']
  s.homepage = 'http://github.com/ClarityServices/modern_times'
  s.files = Dir["{app,examples,lib,config}/**/*"] + %w(LICENSE.txt Rakefile Gemfile History.md README.rdoc)
  s.version = ModernTimes::VERSION
  s.add_dependency 'jruby-jms', ['>= 0.11.2']
  s.add_dependency 'jmx',  ['>= 0.6']
end
