require 'erb'
require 'yaml'

jms_file = File.expand_path('../jms.yml', __FILE__)
if File.exist?(jms_file)
  config = YAML.load(ERB.new(File.read(jms_file)).result(binding))
  ModernTimes::JMS::Connection.init(config)
  ModernTimes::QueueAdapter.set(:jms)
else
  ModernTimes::QueueAdapter.set(:in_mem)
end
