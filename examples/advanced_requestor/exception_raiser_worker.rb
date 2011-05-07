class ExceptionRaiserWorker < BaseRequestWorker

  virtual_topic 'test_string'
  response_marshal :string

  def request(obj)
    raise "Raising dummy exception on #{obj}" if options[:raise]
    "We decided not to raise on #{obj}"
  end
end