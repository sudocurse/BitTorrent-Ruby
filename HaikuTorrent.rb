require_relative 'bencode.rb'
require_relative 'torrent.rb'

if __FILE__ == $PROGRAM_NAME    
    if ARGV.length < 1
        puts "usage: ruby %s torrent-file" % [$PROGRAM_NAME]
    elsif
        torrent = Torrent.open(ARGV[0])
        puts "======\nhello and welcome"
        puts "to the only bittorrent"
        puts "client we\'ve written\n======\n"
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
end
