class Integer
    def to_be
        [self].pack('N')
    end
end

class Message

    ID_LIST = [:choke, :unchoke, :interested, :not_interested, :have, :bitfield, :request, :piece, :cancel]

    attr_accessor :id

    def initialize(id, params=nil)
        @id = id
        @params = params
    end

    def to_peer
        case @id
        when :keepalive
            0.to_be
        when :choke, :unchoke, :interested, :not_interested
            1.to_be + ID_LIST.index(@id).chr
        when :have
            5.to_be + ID_LIST.index(@id).chr + @params[:index].to_be
        when :bitfield
            (1+@params[:bitfield].length).to_be + ID_LIST.index[@id].chr + @params[:bitfield]
        when :request, :cancel
            13.to_be + ID_LIST.index[@id].chr + @params[:index].to_be + @params[:begin].to_be + @params[:length].to_be
        when :piece
            (9 + @params[:block].length).to_be + ID_LIST.index[@id].chr + @params[:index].to_be + @params[:begin].to_be + @params[:block]
        end
    end

    def self.from_peer id
        if ID_LIST.length < id
            return :error
        else 
            return ID_LIST.index(id)
        end
    end
end

# m = Message.new(:request)
# print m.to_peer[2].ord

