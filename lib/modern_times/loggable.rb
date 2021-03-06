module ModernTimes
  module Loggable
    def logger
      @logger ||= (rails_logger || default_logger)
    end

    def rails_logger
      (defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger) ||
      (defined?(RAILS_DEFAULT_LOGGER) && RAILS_DEFAULT_LOGGER.respond_to?(:debug) && RAILS_DEFAULT_LOGGER)
    end

    def default_logger
      require 'logger'
      l = Logger.new($stdout)
      l.level = Logger::INFO
      l
    end

    def logger=(logger)
      @logger = logger
    end
  end
end