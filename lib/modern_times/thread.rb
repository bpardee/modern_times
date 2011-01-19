module ModernTimes
  class Thread < ::Thread
    def initialize(&block)
      begin
        super
      rescue => e
        ModernTimes.logger.fatal("Thread #{self} died due to exception #{e.message}\n#{e.backtrace.join("\n")}")
      ensure
        ActiveRecord::Base.clear_active_connections!() if Module.const_get('ActiveRecord') rescue nil
        ModernTimes.logger.flush if ModernTimes.logger.respond_to?(:flush)
      end
    end
  end
end
