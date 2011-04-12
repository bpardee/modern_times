require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'modern_times'

class Klass
  def initialize(str)
    @str = str
  end
  def hello
    @str
  end
end

class MarshalStrategyTest < Test::Unit::TestCase
  context '' do
    setup do
      @bson   = Object.new
      @json   = Object.new
      @ruby   = Object.new
      @string = Object.new
      @bson.extend   ModernTimes::MarshalStrategy::BSON
      @json.extend   ModernTimes::MarshalStrategy::JSON
      @ruby.extend   ModernTimes::MarshalStrategy::Ruby
      @string.extend ModernTimes::MarshalStrategy::String
    end

    should 'marshal and unmarshal correctly' do
      hash = {'foo' => 42, 'bar' => 'zulu'}
      str  = 'abcdef1234'
      obj  = Klass.new('hello')
      assert_equal hash, @bson.unmarshal(@bson.marshal(hash))
      assert_equal hash, @json.unmarshal(@json.marshal(hash))
      assert_equal hash, @ruby.unmarshal(@ruby.marshal(hash))
      assert_equal str,  @string.unmarshal(@string.marshal(str))
      assert_equal obj.hello,  @ruby.unmarshal(@ruby.marshal(obj)).hello
    end
  end
end
