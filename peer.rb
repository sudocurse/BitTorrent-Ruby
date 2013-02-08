#require_relative 'bencode.rb'
require 'bencode'

class Peer 
    #create a peer
    def initialize address, port
        @address = address
        @port = port
        @state = 0b1010 
        # @state[0] = am choking
        # @state[1] = am interested
        # @state[2] = peer choking
        # @state[3] = peer interested
    end

    def to_s
        @address.to_s + ":" + @port.to_s
    end

    attr_reader :address, :state, :port
end

#test with an actual .torrent file to see if the code works
# torrent = Torrent.open(ARGV[0])
# puts torrent.decoded_data
# puts torrent.bencoded_data
