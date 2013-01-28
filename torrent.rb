require 'digest/sha1'
require_relative 'bencode.rb'

class Torrent
    #create/bencode a new Torrent file
    def initialize decoded_data = {}
        @decoded_data = decoded_data
        @bencoded_data = @decoded_data.bencode unless @decoded_data.nil?
    end

    #open an existing, bencoded torrent file and save it as a Torrent object
    def self.open to_open
        file = File.open(to_open, "rb")
        @bencoded_data = file.read.strip
        @decoded_data = Bencode.decode(@bencoded_data)
        @decoded_data["info_hash"] = Digest::SHA1.hexdigest(@decoded_data["info"].bencode)
        Torrent.new @decoded_data
    end

    #save a .torrent to a new file
    def save new_file
        File.open(new_file, "wb") do |f|
            f.write @bencoded_data
        end
        @decoded_data
    end

    def update decoded_data = {}
        @decoded_data = decoded_data
        @bencoded_data = @decoded_data.bencode unless @decoded_data.nil?
    end

    attr_reader :decoded_data, :bencoded_data
end

#test with an actual .torrent file to see if the code works
# torrent = Torrent.open(ARGV[0])
# puts torrent.decoded_data
# puts torrent.bencoded_data
