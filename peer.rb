#require_relative 'bencode.rb'
require 'bencode'

class Peer 
    #create a peer
    attr_reader :address, :state, :port, :sock, :bitfield
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
    def handshake info_hash
        @sock = TCPSocket.new @address, @port  #need error handling for refused connections, or more likely, missing hosts
        @sock.send "\023"+"BitTorrent protocol"+"\0\0\0\0\0\0\0\0",0
        @sock.send (info_hash + $my_id),0

        ln = @sock.recv(1).unpack("C*")[0].to_i #to_i
        
        if ln != 19
            puts "Response length : #{ln}"
            return
        end 

        prot = @sock.recv(19)
        options = @sock.recv(8)
        their_hash = @sock.recv(20)
        puts their_hash.unpack("H*")
        their_id = @sock.recv(20)       #could use their id to ID threads
        puts their_id
        @sock
    end

def save_piece name, piece, index
        File.open(name + index+".piece", "wb") do |f|
            f.write(piece)
        end
end
    def handle_messages torrent

        if @sock == nil
            puts "Client can't be reached or isn't talking about that torrent."
            return 
        end

        #puts @state
        until @sock == nil
            ln = @sock.recv(4).unpack("C*").join.to_i #bitfield length
            if ln > 0
                print "Message from #{self}\tlength: #{ln}\ttype: "
                id = @sock.recv(1).unpack("C*")[0]
                payload = @sock.recv((ln.to_i - 1))
                case id
                # these first 4 should update the state variable
                when 0 
                    puts "choke"
                    @state[2] = @state[2] | 1
                when 1 
                    puts "unchoke"
                    @state[2] = @state[2] & 0
                when 2 
                    puts "interested"
                    @state[3] = @state[3] | 1
                when 3 
                    puts "uninterested"
                    @state[3] = @state[3] & 0
                when 4
                    puts "have piece at index: #{payload.unpack("H*")[0]}" 
                    # update the bitfield
                when 5
                    bitfield = payload
                    puts "Peer's bitfield (#{bitfield.length }):\n#{bitfield.unpack("H*")}"
                    puts "Our bitfield (#{torrent.bitfield.length}):\t\n#{bitfield.unpack('H*')}"
                    puts "with #{ torrent.decoded_data["info"]["piece length"]} bytes / piece"

                    #could store bitfield aggregates in torrent object... would have to have a count for each piece and a semaphore
                when 6 
                    puts "requesting piece" # 4-byte piece index, 4-byte offset, 4-byte length
                when 7 
                    puts "data block!" # 4 byte index, 4-byte offset, (ln - 9)-byte data block
                    index = payload.unpack("N").to_i
                    piece = payload[8, ln - 9]
                    puts "index at #{index}"
                    save_piece torrent.decoded_data["info"]["name"], piece, index
                when 8 
                    puts "cancel" # payload identical to request (id = 6)
                else 
                    puts "Error: unexpected messages. Lower your expectations?"
                end 
            #else
            #    puts "Keep alive" #should keep a timer?
            end
        end
    end

    def request_piece n, ln
        #puts "Sending request"
        # this doesn't seem to work
        #@sock.send [0, 0, 0, 13, 6].pack("C4"), 0
        #@sock.send n.to_be,0
        #@sock.send 0.to_be,0
        #@sock.send ln.to_be,0
        # this code is entirely redundant with the message class function "to_peer"
        #@sock.send "\0"+"BitTorrent protocol"+"\0\0\0\0\0\0\0\0",0
        #end
    end
end

