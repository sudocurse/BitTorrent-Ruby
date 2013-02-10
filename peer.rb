#require_relative 'bencode.rb'
require 'bencode'

class Peer 
    #create a peer
    attr_reader :address, :state, :port, :sock
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

    #establish a connection
    def handshake(info_hash)
        @sock = TCPSocket.new @address, @port 
        @sock.send "\023"+"BitTorrent protocol"+"\0\0\0\0\0\0\0\0",0
        @sock.send (info_hash + $my_id),0

        # recving handshake. might want to make these peer attributes.
        ln = @sock.recv(1).unpack("C*")[0].to_i #to_i
        
        if ln != 19
            puts "Response length : #{ln}"
            return
        end 

        prot = @sock.recv(19)
        options = @sock.recv(8)
        their_hash = @sock.recv(20)
        puts their_hash.unpack("H*")
        their_id = @sock.recv(20)
        puts their_id
        @sock
    end

    def handle_messages torrent
        if @sock == nil
            puts "Client can't be reached or isn't talking about that torrent."
            return 
        end
        until @sock == nil
            ln = @sock.recv(4).unpack("C*").join.to_i #bitfield length
            print "Message from #{self} of length: #{ln} of type: "
            if ln > 0
                id = @sock.recv(1).unpack("C*")[0]
                payload = @sock.recv((ln.to_i - 1))
                
                case id
                # these first 4 should update the state variable
                when 0 
                    puts "choke"
                when 1 
                    puts "unchoke"
                when 2 
                    puts "interested"
                when 3 
                    puts "uninterested"
                when 4
                    puts "have piece" # payload includes a piece index
                when 5
                    their_bitfield = payload
                    puts "Peer's bitfield (#{their_bitfield.length }):\n#{their_bitfield.unpack("H*")}"
                    puts "Our bitfield (#{torrent.bitfield.length}):\t\n#{torrent.bitfield.unpack('H*')}"
                    puts "with #{ torrent.decoded_data["info"]["piece length"]} bytes / piece"
                when 6 
                    puts "request"
                when 7 
                    puts "data block!"
                when 8 
                    puts "cancel"
                else 
                    puts "Error: unexpected messages. Lower your expectations?"
                end 
            else
                puts "Keep alive" #should keep a timer?
            end
        end
    end
end

