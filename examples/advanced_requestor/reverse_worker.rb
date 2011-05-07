class ReverseWorker < BaseRequestWorker

  virtual_topic 'test_string'
  response_marshal :string

  def request(obj)
    obj.reverse
  end
end