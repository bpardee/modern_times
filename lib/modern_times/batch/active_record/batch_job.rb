module ModernTimes::Batch::ActiveRecord
  class BatchJob < ActiveRecord::Base
    include ModernTimes::Batch::JobStatus

    set_table_name 'mt_batch_jobs'

    has_many :failed_records,      :dependent => :destroy
    has_many :outstanding_records, :dependent => :destroy

    validates :file, :worker_name, :finished_count, :status, :presence => true
      #t.string    :file,              :null => false
      #t.string    :worker_name,       :null => false
      #t.integer   :total_count
      #t.integer   :finished_count,    :null => false, :default => 0
      #t.column    :status, 'char(8)', :null => false, :default => ModernTimes::Batch::JobStatus::INITED
      #t.datetime  :created_at,        :null => false
      #t.datetime  :updated_at,        :null => false

    # Acquire this file if it hasn't already been acquired.
    def self.acquire(file, worker_name)
      return nil if find_by_file_and_worker_name(file, worker_name)
      create!(:file => file, :worker_name  => worker_name)
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.warn("Assuming race condition (duplicate index) for BatchJob file=#{file} worker=#{worker_name}: #{e.message}")
      return nil
    end

    # Acquire and resume a paused job if available
    def self.resume_paused_job(worker_name)
      transaction do
        job = where(:worker_name => worker_name, status => PAUSED).lock(true).first
        return nil unless job
        job.outstanding_records.each do |record|
          job.start_record(record.file_position)
          record.destroy
        end
        job.update_attribute(:status => RUNNING)
      end
    end

    def initialize(opts={})
      super
      @outstanding_array = []
    end

    def run(total_count)
      update_attributes(:status => RUNNING, :total_count => total_count)
    end

    def pause
      save_outstanding_array
      update_attribute(:status => STOPPED)
    end

    def abort
      save_outstanding_array
      update_attribute(:status => ABORTED)
    end

    def cancel
      save_outstanding_array
      update_attribute(:status => CANCELED)
    end

    def finish
      update_attribute(:status => FINISHED)
    end

    def start_record(file_position)
      @outstanding_array << file_position
    end

    def finish_record(file_position)
      @outstanding_array.delete(file_position)
      update_attribute(:finished_count => finished_count + 1)
    end

    def fail_record(file_position, message)
      @outstanding_array.delete(file_position)
      failed_records.create!(:file_position => file_position, :message => message)
    end

    def retry_failed_record
      failed_record = failed_records.first
      return nil unless failed_record
      failed_record.destroy
      return failed_record.file_position
    end

    def outstanding_array
      @outstanding_array
    end

    def failed_hash
      hash = {}
      failed_records.each do |failed_record|
        hash[failed_record.file_position] = failed_record.message
      end
      return hash
    end

    private

    def save_outstanding_array
      outstanding_records.each {|record| record.destroy}
      @outstanding_array.each do |file_position|
        outstanding_records.create!(:file_position => file_position)
      end
    end
  end
end
