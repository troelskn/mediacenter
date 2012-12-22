$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'boilerplate'
require 'models'
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'transmission-client', 'lib'))
require 'transmission-client'

EM.run do
  transfers = Transfers.new
  streams = Streams.new(File.join(File.dirname(__FILE__), "streams"))
  encoder = Encoder.new(transfers, streams)
  EM.add_periodic_timer(10) do
    encoder.queue_transfers
    encoder.encode_streams
  end
end
