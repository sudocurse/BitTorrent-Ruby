require 'digest/sha1'
#require_relative 'bencode.rb'
require 'bencode'

class Torrent
    #create/bencode a new Torrent file
    def initialize decoded_data = {}, info_hash
        @decoded_data = decoded_data
        @bencoded_data = @decoded_data.bencode unless @decoded_data.nil?
        @info_hash = info_hash
    end

    #open an existing, bencoded torrent file and save it as a Torrent object
    def self.open to_open
        file = File.open(to_open, "rb")
        @bencoded_data = file.read.strip
        @decoded_data = BEncode.load(@bencoded_data)
        # puts "\nhex form of hash:" + Digest::SHA1.hexdigest(@decoded_data["info"].bencode)        #debug prints info_hash
        @info_hash = Digest::SHA1.digest(@decoded_data["info"].bencode).force_encoding('binary')
        Torrent.new @decoded_data, @info_hash
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

    attr_reader :decoded_data, :bencoded_data, :info_hash
end

#test with an actual .torrent file to see if the code works
# torrent = Torrent.open(ARGV[0])
# puts torrent.decoded_data
# puts torrent.bencoded_data
