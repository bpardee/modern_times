ActiveRecord::Schema.define(:version => 0) do

  create_table :mt_batch_jobs, :force => true do |t|
    t.string    :file,              :null => false
    t.string    :worker_name,       :null => false
    t.integer   :total_count
    t.integer   :finished_count,    :null => false, :default => 0
    t.column    :status, 'char(8)', :null => false, :default => ModernTimes::Batch::JobStatus::INITED
    t.datetime  :created_at,        :null => false
    t.datetime  :updated_at,        :null => false
  end
  add_index :mt_batch_jobs, [:file, :worker_name]

  create_table :mt_outstanding_records, :force => true do |t|
    t.integer   :batch_job_id,      :null => false
    t.integer   :file_position,     :null => false
  end
  add_index :mt_outstanding_records, [:batch_job_id]

  create_table :mt_failed_records, :force => true do |t|
    t.integer   :batch_job_id,      :null => false
    t.integer   :file_position,     :null => false
    t.string    :message,           :null => false
  end
  add_index :mt_failed_records, [:batch_job_id]


end