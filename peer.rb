#require_relative 'bencode.rb'
require 'bencode'
require 'thread'

class Peer
    #create a peer

    BUFFER = 4096

    attr_reader :address, :state, :port, :sock, :bitfield
    def initialize address, port
        @address = address
        @port = port

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
    end


    def to_s
        @address.to_s + ":" + @port.to_s
    end

    #establish a connection
    def handshake info_hash

        @sock = TCPSocket.new @address, @port  #need error handling for refused connections, or more likely, missing hosts
        # was having some trouble with this in init, not sure why.
        # Also, putting this in initialize means that as soon as a peer object is created so is its socket
        # (so, when a tracker returns a list of 2000 peers, 2000 sockets are immediately created when the client is only likely to ever interact with less than 5% of that).

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
        their_id = @sock.recv(20)
        puts their_id
        @sock
    end

    def save_piece name, piece, index
            File.open(name + index+".piece", "wb") do |f|
                f.write(piece)
            end
    end

    def handle_messages msg

        case Message::ID_LIST[msg.id]
        when :choke

            puts "choke"

            @p_choked = 1

        when :unchoke

            puts "unchoke"

            @p_choked = 0

        when :interested

            puts "interested"

            @p_interested = 1

        when :not_interested

            puts "uninterested"

            @p_interested = 0

        when :have

            puts "have piece at index: #{msg.params[:index]}"

            #update piece rarity bitfield
        when :bitfield

            bitfield = msg.params[:bitfield]
            puts "bitfield (#{bitfield.length}):\n#{bitfield.to_x}"
            #puts "Our bitfield (#{torrent.bitfield.length}):\t\n#{torrent.bitfield.to_x)}"
            #puts "with #{ torrent.decoded_data["info"]["piece length"]} bytes / piece"
        when :request
           puts "requesting piece at #{msg.params[:index]}"

        when :piece
            puts "data block at #{msg.params[:index]}"
        when :cancel
            puts "cancelling piece at #{msg.params[:index]}"
        else
            puts "Error: unexpected message."
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
        Thread.new do
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

        Thread.new do
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

            msg = Message.new(:piece, {:block => data, :index => data.begin, :begin => data.begin}).to_peer
            send_data data.to_peer
        else
            puts "Invalid data: #{data}."
        end

    end

    #(threaded/blocking) sends bits that will either be blocks or messages
    def send_blocks_and_msgs

        data = convert_to_block_or_msg

        case data
        when Message
            puts "data!"
            handle_messages data
        when Block
            puts "block!"
            handle_blocks data
        else
            puts "Invalid data: #{data}."
        end
    end

    #converts bits that will either be blocks or messages
    def convert_to_block_or_msg

        #first, see if there's a keep alive message
        length = -1
        #convert data received from 32-bit be format
        while(0 == (length = receive_data(4).from_be))
            puts "Got keep alive message." #rm
        end

        #get message id
        id = receive_data(1).from_byte

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
            msg = Message.from_peer(id, receive_data(length))
        end

    end


    def send_data data
        if data
            @sock.send(data, 0)
        end
    end

    def receive_data length
        all_data = ""
        puts "rcv length: #{length}"
        while all_data.length < length
            data_to_store = @sock.recv(length-all_data.length)
            all_data += data_to_store
        end
        #rm error handling if data_to_store is empty
        all_data
    end
end

