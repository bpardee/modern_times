# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require 'rubygems'
require 'modern_times'
require 'rumx'
require 'erb'
require 'yaml'
require 'logger'

#ModernTimes.logger = Logger.new($stdout)

jms_file = File.expand_path('../jms.yml', __FILE__)
if File.exist?(jms_file)
  config = YAML.load(ERB.new(File.read(jms_file)).result(binding))
  ModernTimes::JMS::Connection.init(config)
  ModernTimes::QueueAdapter.set(:jms)
else
  ModernTimes::QueueAdapter.set(:in_mem)
end
