# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'modern_times'
require 'rubygems'
require 'erb'
require 'yaml'
require 'base_request_worker'
require 'char_count_worker'
require 'exception_raiser_worker'
require 'length_worker'
require 'print_worker'
require 'reverse_worker'
require 'triple_worker'

config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), '..', 'jms.yml'))).result(binding))
ModernTimes::JMS::Connection.init(config)

manager = ModernTimes::Manager.new
manager.stop_on_signal(join=true)
manager.persist_file = 'modern_times.yml'
run Rumx::Server
