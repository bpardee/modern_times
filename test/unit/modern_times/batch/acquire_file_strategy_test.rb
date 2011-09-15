require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'modern_times'
require 'fileutils'
require 'tempfile'

class AcquireFileStrategyTest < Test::Unit::TestCase
  def perform_after(duration)
    Thread.new do
      sleep duration.to_f
      yield
    end
  end

  def assert_duration(expected_duration, actual_duration, threshold = 0.3)
    msg = "duration #{actual_duration} does not fall between #{expected_duration.to_f - threshold} and #{expected_duration.to_f + threshold}"
    assert (expected_duration.to_f - threshold) <= actual_duration.to_f && actual_duration.to_f <= (expected_duration.to_f + threshold), msg
  end

  context '' do
    setup do
      @dir = Dir.mktmpdir
    end

    teardown do
      #FileUtils.remove_entry_secure @dir
    end

    should 'allow stop to abort sleep' do
      acquire_file_strategy = ModernTimes::Batch::AcquireFileStrategy.new(:glob => "#{@dir}/*", :poll_time => 10)
      perform_after(3) { acquire_file_strategy.stop }
      secs = Benchmark.realtime do
        file = acquire_file_strategy.acquire_file
        assert_nil file
      end
      assert_duration(3, secs)
    end

    should 'acquire files when they become available' do
      acquire_file_strategy = ModernTimes::Batch::AcquireFileStrategy.new(:glob => "#{@dir}/*", :poll_time => 0.2, :age => 3)
      file1 = "#{@dir}/file1"
      file2 = "#{@dir}/file2"
      perform_after(2) { FileUtils.touch [file1, file2] }
      file = nil  # scope it
      secs = Benchmark.realtime do
        file = acquire_file_strategy.acquire_file
        assert_equal "#{file1}.processing", file
        assert !File.exists?(file1)
        assert File.exists?(file)
      end

      assert_duration(2+3, secs, 1)
      file = acquire_file_strategy.complete_file(file)
      assert_equal "#{file1}.completed", file
      assert !File.exists?("#{file1}.processing")
      assert File.exists?(file)

      secs = Benchmark.realtime do
        file = acquire_file_strategy.acquire_file
        assert_equal "#{file2}.processing", file
        assert !File.exists?(file2)
        assert File.exists?(file)
      end
      assert_duration(0, secs)
      file = acquire_file_strategy.complete_file(file)
      assert_equal "#{file2}.completed", file
      assert !File.exists?("#{file2}.processing")
      assert File.exists?(file)
    end

    should 'handle contention with only one thread acquiring each file' do
      acquire_file_strategy = ModernTimes::Batch::AcquireFileStrategy.new(:glob => "#{@dir}/*", :poll_time => 0.0, :age => 0)
      mutex = Mutex.new
      # 10 of the 100 threads should acquire a file
      files = (0..9).map {|i| "#{@dir}/foo#{i}"}
      acquire_counts = Array.new(10, 0)
      nil_count = 0
      threads = (0..99).map do |i|
        Thread.new do
          file = acquire_file_strategy.acquire_file
          mutex.synchronize do
            if file
              files.each_index do |i|
                acquire_counts[i] += 1 if file == "#{files[i]}.processing"
              end
            else
              nil_count += 1
            end
          end
        end
      end
      FileUtils.touch(files)
      sleep 2
      acquire_file_strategy.stop
      threads.each {|t| t.join}
      (0..9).each {|i| assert_equal 1, acquire_counts[i], "Index #{i} has count of #{acquire_counts[i]}"}
      assert_equal 90, nil_count
    end
  end
end
