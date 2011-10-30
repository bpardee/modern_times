module ModernTimes::Batch::ActiveRecord
  class OutstandingRecord < ActiveRecord::Base
    set_table_name 'mt_outstanding_records'
  end
end

