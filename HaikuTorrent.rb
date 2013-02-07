#require_relative 'bencode.rb'
require 'bencode'
require 'ipaddr'
require 'socket'
require_relative 'torrent.rb'
require_relative 'connect.rb'
require_relative 'peer.rb'
require_relative 'tracker.rb'
require_relative 'message.rb'

$version = "HT0001"
$my_id = "" 
$pstr = "BitTorrent protocol"

#we chose to use the current time for the string
def generate_my_id 
    return "-"+$version+"-"+"%12d" % (Time.now.hash % 1000000000000).to_s
end

def parse_config(config_file)

    if File.exist?(config_file)
        
        encoded =  File.open(config_file, "rb").read.strip
        config = BEncode.load(encoded)
        $my_id = config['my_id']

    elsif config_file == ".config"

        puts "Default config file not found. Creating .config."

        $my_id = generate_my_id
        
        File.open(config_file, "wb") do |f|
            f.write({'my_id' => $my_id}.bencode + "\n")
        end
    elsif
        abort("Error: Config file not found. Exiting.")
    end
end

def print_metadata(torrent)
    torrent.decoded_data.each{ |key, val|
        if key == "info" # info dictionary
            puts "info =>"
            val.each{   |info_key, info_val|
                if info_key == "pieces"
                    puts "\tSkipping pieces."
                elsif info_key == "files"
                    puts "\tFiles:"
                    info_val.each{  |file|
                        fn = file['path']
                        flen = file['length']
                        puts "\t\t#{fn}, #{flen} bytes"
                    }
                elsif info_key == "length"
                    puts "\tLength of single file torrent: #{info_val}"
                elsif
                    puts "\t#{info_key} => #{info_val}"
                end
            }
        elsif   #Announce URL and any other metadata
            puts "#{key} => #{val}"
        end
    }
end

def parse_tracker_response response
    resp_d = response[:body].bdecode
    # puts "Response Keys:" + resp_d.keys.to_s #response keys. useful for unhandled response cases
    
    # interval in seconds we should wait before sending requests
    num_seeders = resp_d['complete']
    num_leechers = resp_d['incomplete']
    interval = resp_d['interval']
    puts "\nSeeders: #{num_seeders}\tLeechers: #{num_leechers}\tInterval: #{interval}"
    
    # peerlist. i assume if this comes in dictionary form, bencode will already have handled it.

    peers = resp_d['peers'] 
    peerlist = Array.new
    # puts peers.unpack("H*")   #debug peerlist
    until peers == ""                
        ip = peers.unpack("C4").join(".")   # grabs the 4 leftmost 8bit unsigneds from peers
        peers = peers[4, peers.length]      # chops the contents of addr off of peers
        port = peers.unpack("n").join       # grabs the leftmost 16-bit big-endian from peers
        peers = peers[2, peers.length]      # chops the contents of addr off of peers
        p = Peer.new( ip, port.to_s )   
        peerlist += [p]
    end
    peerlist
end

#establish a connection
def handshake(peer, info_hash)
    sock = TCPSocket.new peer.address, peer.port 
    sock.send "\023"+"BitTorrent protocol"+"\0\0\0\0\0\0\0\0",0
    sock.send (info_hash + $my_id),0

    # recving handshake. might want to make these peer attributes.
    ln = sock.recv(1).to_i
    puts "Response: this better be 19: #{ln}"
    prot = sock.recv(19)
    options = sock.recv(8)
    their_hash = sock.recv(20)
    puts their_hash.unpack("H*")
    their_id = sock.recv(20)
    puts their_id
    sock
end

if __FILE__ == $PROGRAM_NAME    

    config_file = ".config"
    case ARGV.length
    when 0
        puts "usage: ruby %s [config] torrent-file" % [$PROGRAM_NAME]
        puts "\tby default, config is assumed to be in ./.config"
        exit
    when 1
        torrent_file = ARGV[0]
    when 2
        config_file = ARGV[0]
        torrent_file = ARGV[1]
    end

    puts "\n\t======"
    puts "\thello and welcome"
    puts "\tto the only bittorrent"
    puts "\tclient we\'ve written"
    puts "\t======"

    puts "\nUsing config file #{config_file}"
    parse_config config_file
    torrent = Torrent.open(torrent_file)

    if torrent

        puts "Parsed torrent metadata for #{torrent_file}."
        #print_metadata torrent     #debug prints torrent metadata

        # initialize a Tracker object
        options = {:timeout => 5, :peer_id => $my_id}
        connection = Tracker.new(torrent, options)

        #array of available trackers
        trackers = connection.trackers
#        puts "Getting tracker updates from #{trackers}."  #debug tracker info

        #connect to first tracker in the list
        success = connection.connect_to_tracker 0
        connected_tracker = connection.successful_trackers.last


        # make a request to a successfully connected tracker
        if success

            response = connection.make_tracker_request( :uploaded => 1, :downloaded => 10,
                      :left => 100, :compact => 0,
                      :no_peer_id => 0, :event => 'started', 
                      :index => 0)

            #puts "RESPONSE: " + response.to_s      # debug - prints tracker response
            peerlist = parse_tracker_response response

            puts "Peers (#{peerlist.length}):"
            puts peerlist   #debug - prints peerlist

            

            # select a peer somehow
            other_client = "127.0.0.1"
            lhost = Peer.new "127.0.0.1", 52042
            peerlist += [lhost]
            
            # other_client = "209.234.249.226"
            i = peerlist.find_index {|x| x.address ==  other_client}
            puts "Sending handshake to client at #{other_client} (def. in line 160)"
    
            # probably should make this a thread or otherwise non-blocking
            peer_socket = handshake( peerlist[i] , torrent.info_hash)  

            ln = peer_socket.recv(4).unpack("C*").join.to_i #bitfield length
            puts "Message length: #{ln}"
            #perhaps the message class should deal with such things
            id = peer_socket.recv(1).unpack("C*")[0]
            if id == 5
                puts "receiving #{other_client}'s bitfield:"
                their_bitfield = peer_socket.recv(ln.to_i - 2)
                puts "Peer's bitfield: #{their_bitfield.unpack('H*')}"
            elsif
                puts "Error: expected bitfield. Didn't get a bitfield. :("
            end 

            # if own bitfield != \0\0\0...
            # bitfield[:bitfield] = "" #(should this of a length equal to the number of pieces? probably should be stored in .config on a per-torrent setting?)
            # peer_socket.send Message.new(:bitfield, bitfield)

            # find a piece that you don't have at random, and then download it.
            # strategically, you could open up threads with a large number of peers, figure out with pieces are more rare and request those (rarest first)
                # is this also the step that figures out how to unchoke/sends an interest message?
            # to request a piece, figure out the index from the bitfield, and send a request message. 
            #begin receiving piece messages. once verified(?), send a 'have' message- (out to all peers, or just that one?)

        elsif
            puts "Could not connect to tracker."
            # Perhaps we should try again soon. 
        end
    elsif 
        puts "Torrent could not be opened."
    end
end

