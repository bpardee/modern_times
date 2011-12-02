class ReverseWorker < BaseRequestWorker

  topic 'test_string'
  response :marshal => :string, :time_to_live => 5000

  def request(obj)
    obj.reverse
  end
end
