class CharCountWorker < BaseRequestWorker

  topic 'test_string'
  response :marshal => :bson, :time_to_live => 5000
  
  def request(obj)
    hash = Hash.new(0)
    obj.each_char {|c| hash[c] += 1}
    hash
  end
end
