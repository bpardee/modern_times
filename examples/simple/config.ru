# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'rubygems'
require 'modern_times'
require 'rumx'
require '../setup_adapter'
require './bar_worker'
require './baz_worker'
require './publisher'

# If we're not starting up a standalone publisher, then start up a manager
if ENV['RACK_ENV'] != 'publisher'
  manager = ModernTimes::Manager.new(:name => 'Worker', :persist_file => 'modern_times.yml')
  at_exit do
    manager.stop
    manager.join
  end
end
if ENV['RACK_ENV'] != 'worker'
  Rumx::Bean.root.bean_add_child(:Publisher, Publisher.new)
end
run Rumx::Server
