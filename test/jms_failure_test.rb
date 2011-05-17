require 'modern_times'
require 'shoulda'
require 'test/unit'
require 'fileutils'
require 'erb'

# NOTE: This test requires a running ActiveMQ server

class ExceptionWorker
  include ModernTimes::JMS::Worker

  def perform(obj)
    puts "ExceptinoWorker received #{obj} but raising exception"
    raise 'foobar'
  end
end

# This will read from the queue that ExceptionWorker fails to
class ExceptionFailureWorker
  include ModernTimes::JMS::Worker

  def self.my_obj
    @@my_obj
  end

  def perform(obj)
    puts "ExceptinoFailureWorker received #{obj}"
    @@my_obj = obj
  end
end

class JMSFailureTest < Test::Unit::TestCase

  context 'jms' do
    setup do
      config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), 'jms.yml'))).result(binding))
      ModernTimes::JMS::Connection.init(config)
    end

    teardown do
    end

    context "worker with exception" do
      setup do
        @manager = ModernTimes::Manager.new

        @manager.add(ExceptionWorker, 1)
        @manager.add(ExceptionFailureWorker, 1)

        sleep 1
      end

      teardown do
        if @manager
          @manager.stop
          @manager.join
        end
      end

      should "write failure messages to a queue of <name>Failure" do

        # Publish to Exception that will throw exception which will put on ExceptionFailure queue
        publisher = ModernTimes::JMS::Publisher.new(:queue_name => 'Exception', :marshal => :string)
        publisher.publish('zulu')
        sleep 1
        assert_equal 'zulu', ExceptionFailureWorker.my_obj
      end
    end

#    context "dummy publishing" do
#      setup do
#        workers = [
#            CharCountWorker.new,
#            CharCountWorker.new(:name => 'CharCount2'),
#            LengthWorker.new,
#            LengthWorker.new(:name => 'Length2'),
#            ReverseWorker.new,
#            TripleWorker.new,
#            HolderWorker.new,
#        ]
#        ModernTimes::JMS::Publisher.setup_dummy_publishing(workers)
#      end
#
#      teardown do
#        ModernTimes::JMS::Publisher.clear_dummy_publishing
#      end
#
#      should "handle replies" do
#
#        publisher = ModernTimes::JMS::Publisher.new(:virtual_topic_name => 'test_string', :response => true, :marshal => :string)
#        cc_val = {'f' => 1, 'o' => 4, 'b' => 1}
#
#        hash = make_call(publisher, 'fooboo', 2)
#        assert_response(hash['CharCount'],  :message, cc_val)
#        assert_response(hash['CharCount2'], :message, cc_val)
#        assert_response(hash['Length'],     :message, 6)
#        assert_response(hash['Length2'],    :message,  6)
#        assert_response(hash['Reverse'],    :message, 'ooboof')
#        assert_response(hash['Triple'],     :message,  'fooboofooboofooboo')
#
#        # Timeouts don't occur when dummy publishing
#        CharCountWorker.sleep_time = 3
#        ReverseWorker.sleep_time   = 3
#        hash = make_call(publisher, 'fooboo', 2)
#        assert_response(hash['CharCount'],  :message, cc_val)
#        assert_response(hash['CharCount2'], :message, cc_val)
#        assert_response(hash['Length'],     :message, 6)
#        assert_response(hash['Length2'],    :message,  6)
#        assert_response(hash['Reverse'],    :message, 'ooboof')
#        assert_response(hash['Triple'],     :message,  'fooboofooboofooboo')
#        CharCountWorker.sleep_time = nil
#        ReverseWorker.sleep_time   = nil
#
#        CharCountWorker.do_exception = true
#        TripleWorker.do_exception    = true
#        hash = make_call(publisher, 'fooboo', 2)
#        assert_exception(hash['CharCount'],  :explicit_exception)
#        assert_exception(hash['CharCount2'], :default_exception)
#        assert_response(hash['Length'],      :message, 6)
#        assert_response(hash['Length2'],     :message,  6)
#        assert_response(hash['Reverse'],     :message, 'ooboof')
#        assert_exception(hash['Triple'],     :default_exception)
#        CharCountWorker.do_exception = false
#        TripleWorker.do_exception    = false
#      end
#    end
  end
end
