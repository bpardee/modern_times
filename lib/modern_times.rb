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
end