require '../setup'
require './bar_worker'
require './baz_worker'
require './publisher'

# If we're not starting up a standalone publisher, then start up a manager
if ENV['RACK_ENV'] != 'publisher'
  manager = ModernTimes::Manager.new(:name => 'Worker', :persist_file => 'modern_times.yml')
  at_exit { manager.stop }
end
if ENV['RACK_ENV'] != 'worker'
  Rumx::Bean.root.bean_add_child(:Publisher, Publisher.new)
end
run Rumx::Server
