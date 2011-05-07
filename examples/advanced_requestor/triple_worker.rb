class TripleWorker < BaseRequestWorker

  virtual_topic 'test_string'
  response_marshal :string

  def request(obj)
    obj * 3
  end
end