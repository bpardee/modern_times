class CharCountWorker < BaseRequestWorker

  virtual_topic 'test_string'
  response_marshal :bson
  
  def request(obj)
    hash = Hash.new(0)
    obj.each_char {|c| hash[c] += 1}
    hash
  end
end