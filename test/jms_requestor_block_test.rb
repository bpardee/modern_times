require 'modern_times'
require 'shoulda'
require 'test/unit'
require 'fileutils'
require 'erb'

# NOTE: This test requires a running ActiveMQ server

class BaseRequestWorker
  include ModernTimes::JMS::RequestWorker

  def self.sleep_time=(val)
    @sleep_time = val
  end

  def self.sleep_time
    @sleep_time
  end

  def self.do_exception=(val)
    @create_exception = val
  end

  def self.do_exception
    @create_exception
  end

  def request(obj)
    raise Exception,'my exception' if self.class.do_exception
    sleep self.class.sleep_time if self.class.sleep_time
  end

  def log_backtrace(e)
  end
end

class CharCountWorker < BaseRequestWorker
  virtual_topic 'test_string'
  response :marshal => :bson

  def request(obj)
    super
    hash = Hash.new(0)
    obj.each_char {|c| hash[c] += 1}
    hash
  end
end

class LengthWorker < BaseRequestWorker
  virtual_topic 'test_string'
  response :marshal => :ruby

  def request(obj)
    super
    obj.length
  end
end

class ReverseWorker < BaseRequestWorker
  virtual_topic 'test_string'
  response :marshal => :string

  def request(obj)
    super
    obj.reverse
  end
end

class TripleWorker < BaseRequestWorker
  virtual_topic 'test_string'
  response :marshal => :string

  def request(obj)
    super
    obj*3
  end
end

class HolderWorker
  include ModernTimes::JMS::Worker
  virtual_topic 'test_string'

  def self.my_obj
    @@my_obj
  end

  def perform(obj)
    @@my_obj = obj
  end
end

class JMSRequestorBlockTest < Test::Unit::TestCase

  def assert_response(hash, expected_key, expected_val)
    assert_equal 1, hash.keys.size
    actual_val = hash[expected_key]
    assert_equal expected_val, actual_val
  end

  def assert_exception(hash, expected_key)
    assert_equal 1, hash.keys.size
    e = hash[expected_key]

    assert e.kind_of?(ModernTimes::RemoteException)
  end

  def make_call(publisher, string, timeout)
    handle = publisher.publish(string)
    hash_results = {}

    handle.read_response(timeout) do |response|
      response.on_message 'CharCount' do |val|
        hash = hash_results[response.name] ||= {}
        hash[:message] = val
      end
      response.on_message 'CharCount2' do |val|
        hash = hash_results[response.name] ||= {}
        hash[:message] = val
      end
      response.on_message 'Length', 'Length2', 'Reverse', 'Triple' do |val|
        hash = hash_results[response.name] ||= {}
        hash[:message] = val
      end
      response.on_timeout 'Reverse' do
        hash = hash_results[response.name] ||= {}
        hash[:explicit_timeout] = true
      end
      response.on_timeout do
        hash = hash_results[response.name] ||= {}
        hash[:default_timeout] = true
      end
      response.on_remote_exception 'CharCount' do |e|
        hash = hash_results[response.name] ||= {}
        hash[:explicit_exception] = e
      end
      response.on_remote_exception do |e|
        hash = hash_results[response.name] ||= {}
        hash[:default_exception] = e
      end
    end
    puts "results=#{hash_results.inspect}"
    # 6 request workers
    assert_equal 6, hash_results.keys.size
    assert_equal string, HolderWorker.my_obj
    return hash_results
  end

  context 'jms request with block' do
    setup do
      config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), 'jms.yml'))).result(binding))
      ModernTimes::JMS::Connection.init(config)
    end

    teardown do
    end

    context "real publishing" do
      setup do
        @manager = ModernTimes::Manager.new

        @manager.add(CharCountWorker, 1)
        @manager.add(CharCountWorker, 1, :name => 'CharCount2')
        @manager.add(LengthWorker,    1)
        @manager.add(LengthWorker,    1, :name => 'Length2')
        @manager.add(ReverseWorker,   1)
        @manager.add(TripleWorker,    1)
        @manager.add(HolderWorker,    1)

        sleep 1
      end

      teardown do
        if @manager
          @manager.stop
          @manager.join
        end
      end

      should "handle replies" do

        publisher = ModernTimes::JMS::Publisher.new(:virtual_topic_name => 'test_string', :response_time_to_live => 10000, :marshal => :string)
        cc_val = {'f' => 1, 'o' => 4, 'b' => 1}

        hash = make_call(publisher, 'fooboo', 2)
        assert_response(hash['CharCount'],  :message, cc_val)
        assert_response(hash['CharCount2'], :message, cc_val)
        assert_response(hash['Length'],     :message, 6)
        assert_response(hash['Length2'],    :message,  6)
        assert_response(hash['Reverse'],    :message, 'ooboof')
        assert_response(hash['Triple'],     :message,  'fooboofooboofooboo')

        CharCountWorker.sleep_time = 3
        ReverseWorker.sleep_time   = 3
        hash = make_call(publisher, 'fooboo', 2)
        assert_response(hash['CharCount'],  :default_timeout,  true)
        assert_response(hash['CharCount2'], :default_timeout,  true)
        assert_response(hash['Length'],     :message, 6)
        assert_response(hash['Length2'],    :message,  6)
        assert_response(hash['Reverse'],    :explicit_timeout, true)
        assert_response(hash['Triple'],     :message,  'fooboofooboofooboo')
        CharCountWorker.sleep_time = nil
        ReverseWorker.sleep_time   = nil

        CharCountWorker.do_exception = true
        TripleWorker.do_exception    = true
        hash = make_call(publisher, 'fooboo', 2)
        assert_exception(hash['CharCount'],  :explicit_exception)
        assert_exception(hash['CharCount2'], :default_exception)
        assert_response(hash['Length'],      :message, 6)
        assert_response(hash['Length2'],     :message,  6)
        assert_response(hash['Reverse'],     :message, 'ooboof')
        assert_exception(hash['Triple'],     :default_exception)
        CharCountWorker.do_exception = false
        TripleWorker.do_exception    = false

        sleep 2
      end
    end

    context "dummy publishing" do
      setup do
        workers = [
            CharCountWorker.new,
            CharCountWorker.new(:name => 'CharCount2'),
            LengthWorker.new,
            LengthWorker.new(:name => 'Length2'),
            ReverseWorker.new,
            TripleWorker.new,
            HolderWorker.new,
        ]
        ModernTimes::JMS::Publisher.setup_dummy_publishing(workers)
      end

      teardown do
        ModernTimes::JMS::Publisher.clear_dummy_publishing
      end

      should "handle replies" do

        publisher = ModernTimes::JMS::Publisher.new(:virtual_topic_name => 'test_string', :response => true, :marshal => :string)
        cc_val = {'f' => 1, 'o' => 4, 'b' => 1}

        hash = make_call(publisher, 'fooboo', 2)
        assert_response(hash['CharCount'],  :message, cc_val)
        assert_response(hash['CharCount2'], :message, cc_val)
        assert_response(hash['Length'],     :message, 6)
        assert_response(hash['Length2'],    :message,  6)
        assert_response(hash['Reverse'],    :message, 'ooboof')
        assert_response(hash['Triple'],     :message,  'fooboofooboofooboo')

        # Timeouts don't occur when dummy publishing
        CharCountWorker.sleep_time = 3
        ReverseWorker.sleep_time   = 3
        hash = make_call(publisher, 'fooboo', 2)
        assert_response(hash['CharCount'],  :message, cc_val)
        assert_response(hash['CharCount2'], :message, cc_val)
        assert_response(hash['Length'],     :message, 6)
        assert_response(hash['Length2'],    :message,  6)
        assert_response(hash['Reverse'],    :message, 'ooboof')
        assert_response(hash['Triple'],     :message,  'fooboofooboofooboo')
        CharCountWorker.sleep_time = nil
        ReverseWorker.sleep_time   = nil

        CharCountWorker.do_exception = true
        TripleWorker.do_exception    = true
        hash = make_call(publisher, 'fooboo', 2)
        assert_exception(hash['CharCount'],  :explicit_exception)
        assert_exception(hash['CharCount2'], :default_exception)
        assert_response(hash['Length'],      :message, 6)
        assert_response(hash['Length2'],     :message,  6)
        assert_response(hash['Reverse'],     :message, 'ooboof')
        assert_exception(hash['Triple'],     :default_exception)
        CharCountWorker.do_exception = false
        TripleWorker.do_exception    = false
      end
    end
  end
end
