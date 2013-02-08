#require_relative 'bencode.rb'
require 'bencode'
require 'ipaddr'
require 'socket'
require_relative 'torrent.rb'
require_relative 'peer.rb'
require_relative 'tracker.rb'
require_relative 'message.rb'

$version = "HT0002"
$my_id = "" 
$pstr = "BitTorrent protocol"
$config_file = ""

#we chose to use the current time for the string
def generate_my_id 
    return "-"+$version+"-"+"%12d" % (Time.now.hash % 1000000000000).to_s
end

def parse_config_file 

    config = Hash.new

    if File.exist?($config_file) #if either .config or the user defined config file exists:
        
        encoded =  File.open($config_file, "rb").read.strip
        config = BEncode.load(encoded)
        $my_id = config['my_id']

    elsif $config_file == ".config" # if not, and there's no user supplied string
        puts "Default config file not found. Creating .config."
        
        $my_id = generate_my_id
        config['my_id'] =  $my_id
        save config

    else
        abort("Error: Config file not found. Exiting.")
    end

    config
end

def update config, torrent
    config[torrent.info_hash] = torrent.bitfield
end

def save config 
        File.open($config_file, "wb") do |f|
            f.write(config.bencode + "\n")
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
        else   #Announce URL and any other metadata
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
    ln = sock.recv(1).unpack("C*")[0].to_i #to_i
    
    if ln != 19
        puts "Response length : #{ln}"
        return
    end 

    prot = sock.recv(19)
    options = sock.recv(8)
    their_hash = sock.recv(20)
    puts their_hash.unpack("H*")
    their_id = sock.recv(20)
    puts their_id
    
    sock
end

def handle_messages peer_socket, torrent
    if peer_socket == nil
        puts "Client can't be reached or isn't talking about that torrent."
        return 
    end
    ln = peer_socket.recv(4).unpack("C*").join.to_i #bitfield length
    puts "Message length: #{ln}"
    if ln > 0
        id = peer_socket.recv(1).unpack("C*")[0]
        rcvd_message = Message.from_peer id
        puts rcvd_message
        #perhaps the message class should deal with such things
        if id == 5
            their_bitfield = peer_socket.recv((ln.to_i - 1))
            puts "Peer's bitfield (#{their_bitfield.length }):\n#{their_bitfield.unpack("H*")}"
            puts "Our bitfield (#{torrent.bitfield.length}):\t\n#{torrent.bitfield.unpack('H*')}"
            puts "with #{ torrent.decoded_data["info"]["piece length"]} bytes / piece"
        else
            puts "Error: expected bitfield. Didn't get a bitfield. :("
        end 
    else
        puts "Keep alive"
    end
end

if __FILE__ == $PROGRAM_NAME    

    $config_file = ".config"
    case ARGV.length
    when 0
        puts "usage: ruby %s [config] torrent-file" % [$PROGRAM_NAME]
        puts "\tby default, config is assumed to be in ./.config"
        exit
    when 1
        torrent_file = ARGV[0]
    when 2
        $config_file = ARGV[0]
        torrent_file = ARGV[1]
    end

    puts "\n\t======"
    puts "\thello and welcome"
    puts "\tto the only bittorrent"
    puts "\tclient we\'ve written"
    puts "\t======"

    puts "\nUsing config file #{$config_file}"
    config = parse_config_file
    torrent = Torrent.open(torrent_file)

    if torrent
        
        puts "Parsed torrent metadata for #{torrent_file}. Checking config file for torrent."
        #print_metadata torrent     #debug prints torrent metadata

        if config.has_key? torrent.info_hash
            puts "Torrent found."
            torrent.bitfield = config[torrent.info_hash] # could do error checking here on the bitfield length...
        else
            puts "Adding torrent to config file"
            bitfield_length = torrent.decoded_data["info"]["pieces"].length / 20
            if bitfield_length % 8 != 0
                bitfield_length = bitfield_length / 8
                bitfield_length += 1 
            else
                bitfield_length = bitfield_length / 8
            end
            torrent.bitfield = "\x0" * bitfield_length
            puts torrent.bitfield.length
            puts "Bitfield: #{torrent.bitfield}"
            update config, torrent #how often should the config be written to file? 
            save config
        end


        # initialize a Tracker object
        options = {:timeout => 5, :peer_id => $my_id}
        connection = Tracker.new(torrent, options)

        #array of available trackers
        trackers = connection.trackers
        # puts "Getting tracker updates from #{trackers}."  #debug tracker info

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
            # puts peerlist   #debug - prints peerlist

            # select a peer somehow
            other_client = "127.0.0.1"
            lhost = Peer.new other_client, 52042
            #other_client = "207.231.92.41"
            #lhost = Peer.new other_client, 51413 
            peerlist += [lhost]
            
            # other_client = "209.234.249.226"
            i = peerlist.find_index {|x| x.address ==  other_client}
            puts "Sending handshake to client at #{lhost} (def. in code at ~line 232)"
    
            # probably should make this a thread or otherwise non-blocking
            peer_socket = handshake( peerlist[i] , torrent.info_hash)  

            handle_messages peer_socket, torrent
            
            puts torrent.bitfield.unpack('H*')

        else
            puts "Could not connect to tracker."
            # Perhaps we should try again soon. 
        end
    else
        puts "Torrent could not be opened."
    end
    
    save config 
end

