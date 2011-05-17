class LengthWorker < BaseRequestWorker

  virtual_topic 'test_string'
  response :marshal => :ruby, :time_to_live => 5000

  def request(obj)
    obj.length
  end
end