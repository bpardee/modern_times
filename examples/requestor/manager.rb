# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'rubygems'
require 'modern_times'
require 'yaml'
require 'reverse_echo_worker'

config = YAML.load_file('jms.yml')
ModernTimes::JMS::Connection.init(config['client'])

manager = ModernTimes::Manager.new
manager.stop_on_signal
manager.add(ReverseEchoWorker, 1, {})
manager.join
