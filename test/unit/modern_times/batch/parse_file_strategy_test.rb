require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'modern_times'
require 'fileutils'
require 'tempfile'

class ParseFileStrategyTest < Test::Unit::TestCase
  context '' do
    setup do
      Tempfile.open('foo') do |tmp|
        @tmp_path = tmp.path
        (0..9).each {|i| tmp.puts(i.to_s)}
      end
      Tempfile.open('bar') do |tmp|
        @tmp_path2 = tmp.path
        (0..4).each {|i| tmp.puts((i+3).to_s)}
      end
    end

    teardown do
      FileUtils.rm [@tmp_path, @tmp_path2]
    end

    should 'parse a file correctly' do
      parse_file_strategy = ModernTimes::Batch::ParseFileStrategy.new({})
      parse_file_strategy.open(@tmp_path)
      assert_equal 10, parse_file_strategy.record_total
      (0..9).each do |i|
        assert_equal i, parse_file_strategy.file_position
        assert_equal i, parse_file_strategy.next_record.to_i
      end
      [3, 6, 2, 7, 4, 1, 8].each do |i|
        parse_file_strategy.file_position = i
        assert_equal i, parse_file_strategy.file_position
        assert_equal i, parse_file_strategy.next_record.to_i
      end
      parse_file_strategy.close

      parse_file_strategy.open(@tmp_path2)
      assert_equal 5, parse_file_strategy.record_total
      (0..4).each do |i|
        assert_equal i, parse_file_strategy.file_position
        assert_equal i+3, parse_file_strategy.next_record.to_i
      end
      parse_file_strategy.close
    end
  end
end
