require 'rubygems'
require 'modern_times/exception'
require 'modern_times/marshal_strategy'
require 'modern_times/base'
require 'modern_times/jms'
require 'modern_times/jms_requestor'
require 'modern_times/manager_mbean'
require 'modern_times/manager'
require 'modern_times/loggable'
require 'modern_times/railsable'

module ModernTimes
  extend ModernTimes::Loggable
  extend ModernTimes::Railsable

  DEFAULT_DOMAIN = 'ModernTimes'

  def self.manager_mbean_name(domain)
    domain = DEFAULT_DOMAIN unless domain
    "#{domain}.Manager"
  end

  def self.manager_mbean_object_name(domain)
    domain = DEFAULT_DOMAIN unless domain
    "#{domain}:type=Manager"
  end
end