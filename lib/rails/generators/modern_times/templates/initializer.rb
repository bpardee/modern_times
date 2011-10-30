module Cheese
  class Engine < Rails::Engine
    config.mount_at = '/modern_times'
    config.widget_factory_name = 'Modern Times'
  end
end
