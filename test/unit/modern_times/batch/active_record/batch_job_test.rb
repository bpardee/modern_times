require 'test_helper_active_record'

class AcquireFileStrategyTest < Test::Unit::TestCase
  include ModernTimes::Batch::JobStatus

  context 'BatchJob' do
    setup do
      @file_name = 'file'
      @worker_name = 'worker'
      @batch_job = ModernTimes::Batch::ActiveRecord::BatchJob.acquire(@file_name, @worker_name)
    end

    teardown do
      @batch_job.destroy
    end

    should 'handle state changes correctly' do
      assert_equal INITED, @batch_job.status
      assert_nil ModernTimes::Batch::ActiveRecord::BatchJob.acquire(@file_name, @worker_name)
      assert_nil ModernTimes::Batch::ActiveRecord::BatchJob.resume_paused_job(@worker_name)
      @batch_job.run(1000)
      assert_equal RUNNING, @batch_job.status
      assert_equal 1000, @batch_job.total_count
      (0..4).each {|file_position| @batch_job.start_record(file_position) }
      @batch_job.finish_record(1)
      @batch_job.failed_record(2, 'Failed 2')
      (5..9).each {|file_position| @batch_job.start_record(file_position) }
      @batch_job.finish_record(4)
      @batch_job.finish_record(5)
      @batch_job.failed_record(7, 'Failed 7')
      assert_equal [0, 3, 6, 8, 9], @batch_job.outstanding_array
      assert_equal { 2 => 'Failed 2', 7 => 'Failed 7'}, @batch_job.failed_hash
    end
  end
end
