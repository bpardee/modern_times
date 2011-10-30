module ModernTimes::Batch::ActiveRecord
  class FailedRecord < ActiveRecord::Base
    set_table_name 'mt_failed_records'
  end
end
