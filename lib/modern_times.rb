require 'rubygems'
require 'modern_times/exception'
require 'modern_times/base'
require 'modern_times/hornetq'
require 'modern_times/hornetq_requestor'
require 'modern_times/manager_mbean'
require 'modern_times/manager'
require 'modern_times/loggable'
require 'modern_times/railsable'

module ModernTimes
  extend ModernTimes::Loggable
  extend ModernTimes::Railsable
end