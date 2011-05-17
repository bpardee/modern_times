class TripleWorker < BaseRequestWorker

  virtual_topic 'test_string'
  response :marshal => :string, :time_to_live => 5000

  def request(obj)
    obj * 3
  end
end