#require_relative 'bencode.rb'
require 'bencode'

class Peer 
    #create a peer

    BUFFER = 4096

    attr_reader :address, :state, :port, :sock, :bitfield
    def initialize address, port
        @address = address
        @port = port
        @state = 0b1010 
        @sock = TCPSocket.new @address, @port  #need error handling for refused connections, or more likely, missing hosts
        #moved socket to initialize - seems more natural to put this ivar in the init method - dnh
        #connection

        @data_to_send = Queue.new #while sending requests, keeps a queue of data

        #belonging to me
        @blocks_to_get = []
        @interested = false
        @choked = true

        #belonging to peer I'm dowloading from
        @p_pieces = []
        @p_blocks_to_get = []
        @p_interested = false
        @p_choked = true
        
        @started = false #tracks whether request has been started
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
                    puts "Saved piece #{index}"
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

    #gets the block, deletes block from list of desired blocks, notifies that block has
    #been received

    def handle_blocks

    end

    def request_piece n, ln

        @started = true

        #so when a peer sends over its bitfield, we'll let them know that we're interested
        #we'll make request for bloks

        #if the peer doesn't have the desired pieces, we'll just chill

        #thread that handles getting blocks/msgs in terms of bits
        Thread.new 
            begin
                while @started
                    get_blocks_and_msgs
                end
            rescue IOError
                @running = false
                #more error handling? when getting the blocks fails
            end
        end

        #thread that handles receiving blocks//msgs in terms of bits

        Thread.new
            begin
                while @started
                    get_blocks_and_msgs
                end
            rescue IOError  
                @running = false
                #again, more error handling?
            end
        end

        #
        # sleep 4
        # puts "Sending request"
        # # this doesn't seem to work
        #@sock.send 13.to_be + 6.chr + n.to_be + 0.to_be + ln.to_be,0
        # this code is entirely redundant with the message class function "to_peer"
        #@sock.send "\0"+"BitTorrent protocol"+"\0\0\0\0\0\0\0\0",0
        #end
    end

    #(threaded/blocking) gets bits that will either be blocks or messages from the queue
    def get_blocks_and_msgs
        data = @data_to_send.deq
        case data
        when Block
            send_data data.to_peer
        when Message
            #    ID_LIST = [:choke, :unchoke, :interested, :not_interested, :have, :bitfield, :request, :piece, :cancel]

           msg = Message.new(:piece, {:block => data, :index => data., :begin => data.begin}).to_peer
            send_data
        else
            puts "Invalid data: #{data}."
        end

    end

    #(threaded/blocking) sends bits that will either be blocks or messages
    def send_blocks_and_msgs

        data = convert_to_block_or_msg

        case data
        when Message
            handle_messages data
        when Block
            handle_blocks data
        else
            puts "Invalid data: #{data}."
        end
    end

    #converts bits that will either be blocks or messages
    def convert_to_block_or_msg

        #first, see if there's a keep alive message
        length = Integer.new
        #convert data received from 32-bit be format
        while(0 == (length = receive_data(4).from_be))
            puts "Got keep alive message." #rm
        end

        #get message id
        id = receive_data(1)

        #if the id tells you to get a piece, you want to get the  next block that's specified
        if :piece == Message::ID_LIST[id] 
            length -= 9 #must subtract the message length prefix for a piece
            msg = Message.from_peer(id, receive_data(8))
            block = Block.new(msg.index, msg.begin, length)

            until length <= 0
                block.data += receive_data([len, BUFFER].min)
                length -= [len, BUFFER].min
            end
        else
        #otherwise you just want to add whatever message you get to the queue
            msg = Message.from_peer(id, receive_data(length)
        end

    end
        
    
    def send_data data
        if data
            @sock.send(data, 0)
        end
    end

    def receive_data length
        all_data = ""

        while all_data.length < length
            data_to_store = @sock.recv(length-all_data.length)
            all_data += data_to_store
        end
        #rm error handling if data_to_store is empty
        all_data
    end
end

