class LengthWorker < BaseRequestWorker

  virtual_topic 'test_string'
  response_marshal :ruby

  def request(obj)
    obj.length
  end
end