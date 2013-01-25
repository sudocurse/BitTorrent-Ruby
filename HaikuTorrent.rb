require_relative 'bencode.rb'
require_relative 'torrent.rb'
require_relative 'tracker.rb'

if __FILE__ == $PROGRAM_NAME    
    if ARGV.length < 1
        puts "usage: ruby %s torrent-file" % [$PROGRAM_NAME]
    elsif
        torrent = Torrent.open(ARGV[0])
        puts "======\nhello and welcome"
        puts "to the only bittorrent"
        puts "client we\'ve written\n======"
        puts "\nOpening #{ARGV[0]}:"
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
        # ['announce']
        #puts torrent.bencoded_data
    end

    if torrent
        # initialize a TrackerHandler object
        options = {:tracker_timeout => 5, :port => 42309}
        handler = Tracker.new(Torrent.open(ARGV[0]), options)
                                   

        # get list of available trackers (as an array)
        trackers = handler.trackers

        # establish connection to tracker from index of a tracker
        # from the above 'trackers' array
        success = handler.establish_connection 0
        connected_tracker = handler.connected_trackers.last

        # send request to a connected tracker
        if success
            puts "SUCCESS"
            response = handler.request( :uploaded => 1, :downloaded => 10,
                      :left => 100, :compact => 0,
                      :no_peer_id => 0, :event => 'started',
                      :index => 0)
        end
    end
end


