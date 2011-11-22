class ExceptionRaiserWorker < BaseRequestWorker

  virtual_topic 'test_string'
  response :marshal => :string, :time_to_live => 5000

  config_accessor :raise, :boolean, 'Raise an exception instead of handling the request', false

  def request(obj)
    raise "Raising dummy exception on #{obj}" if config.raise
    "We decided not to raise on #{obj}"
  end
end
