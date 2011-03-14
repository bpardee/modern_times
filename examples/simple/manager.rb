# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'rubygems'
require 'modern_times'
require 'yaml'
require 'bar_worker'
require 'baz_worker'

config = YAML.load_file('hornetq.yml')
ModernTimes::HornetQ::Client.init(config['client'])

manager = ModernTimes::Manager.new(:persist_file => 'modern_times.state')
manager.stop_on_signal
manager.allowed_workers = [BarWorker,BazWorker]
#manager.add(BarWorker, 2, {})
manager.join
