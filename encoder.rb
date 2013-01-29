$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'boilerplate'
require 'models'
require 'transmission_client'

transfers = Transfers.new
streams = Streams.new(File.join(File.dirname(__FILE__), "streams"))
encoder = Encoder.new(transfers, streams)
while true
  encoder.queue_transfers
  encoder.encode_streams
  sleep 10
end
