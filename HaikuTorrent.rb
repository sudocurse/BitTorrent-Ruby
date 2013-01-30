#require_relative 'bencode.rb'
require 'bencode'
require_relative 'torrent.rb'
require_relative 'connect.rb'
require_relative 'peer.rb'
require_relative 'tracker.rb'
require_relative 'message.rb'
require 'socket'

$version = "HT0001"
$my_id = "" 
$pstr = "BitTorrent protocol"

#we chose to use the current time for the string
def generate_my_id 
    return "-"+$version+"-"+"%12d" % (Time.now.hash/1000000).to_s
end

def parse_config(config_file)

    if File.exist?(config_file)

        encoded =  File.open(config_file, "rb").read.strip
        config = BEncode.load(encoded)
        $my_id = config['my_id']

    elsif config_file == ".config"

        puts "Default config file not found."

        $my_id = generate_my_id
        
        File.open(config_file, "wb") do |f|
            f.write($my_id.bencode + "\n")
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

#establish a connection
def handshake(peer, info_hash)
    sock = TCPSocket.new peer.address, peer.port 
    sock.send "\023"+"BitTorrent protocol"+"\0\0\0\0\0\0\0\0",0
    sock.send info_hashi + $my_id
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


    puts "======\nhello and welcome"
    puts "to the only bittorrent"
    puts "client we\'ve written\n======"

    puts "\nUsing config file #{config_file}"
    parse_config config_file

    puts "Opening #{torrent_file}:"
    torrent = Torrent.open(torrent_file)
    print_metadata torrent

    if torrent
        #initialize a Tracker object
        options = {:timeout => 5, :peer_id => $my_id}
        connection = Tracker.new(torrent, options)

        #array of available trackers
        trackers = connection.trackers
        #connect to first tracker in the list
        success = connection.connect_to_tracker 0
        connected_tracker = connection.successful_trackers.last


        #make a request to a successfully connected tracker
        if success
            puts "SUCCESS"

            response = connection.make_tracker_request( :uploaded => 1, :downloaded => 10,
                      :left => 100, :compact => 0,
                      :no_peer_id => 0, :event => 'started', 
                      :index => 0)

            puts "RESPONSE: " + response.to_s
        end

    
    
    # peerlist = Hash.new(1010)
    # for each peer in response, add peerlist[""]
    # peer_socket = handshake( peerlist["some address"] , torrent.info_hash)   #receive handshake?

    # bitfield[:bitfield] = "\0\0\0\0\0\0" #(should this of a length equal to the number of pieces?) 
    # peer_socket.send Message.new(:bitfield, bitfield)

    # find a piece that you don't have at random, and then download it.

    end
end

