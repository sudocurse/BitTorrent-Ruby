module Bencode
	class BencodingError < StandardError
		def initialize
			super
		end
	end

	def decode(to_decode)
		require 'strscan'

		scanner = StringScanner.new(to_decode)
		to_decode = scan(scanner)
		raise BencodingError unless scanner.eos?
		return to_decode
	end

	private 

	def scan(scanner)
		case token = scanner.scan(/[dil]|\d+:/) 
		#look for dic, int, list or a number followed by a colon
		when "d"
			dict = {}

			until scanner.peek(1) == "e"
				dict.store(scan(scanner), scan(scanner))
			end
			scanner.pos += 1 #skip the 'e' signifiying the end of the dict
			return dict

		when "i"
			int = scanner.scan(/(-?\d+)/)

			raise BencodingError unless int #error if it indicates an int will follow, but it doesn't
			raise BencodingError unless scanner.scan(/e/) #error if it doesn't have end marker
			return int

		when "l"
			list = []

			until scanner.peek(1) == "e"
				list << scan(scanner)
			end
			scanner.pos += 1 #skip the 'e' signifying the end of the list
			return list

		when /\d+:/
			len = token.chop.to_i #converts the length to an integer
			str = scanner.peek(len) #looks at the next few letters in the string

			scanner.pos += len #advances scanner's position by the length
			return str

		else
			raise BencodingError
		end 
	end
end

class Array

	def bencode
		bencoded = "l"

		self.each { |element|
			bencoded += element.bencode
		}
		bencoded += "e"
	end
end

class Hash

	def bencode
		bencoded = "d"

		self.each { |key, value|
			bencoded += key.bencode + value.bencode
		}

		bencoded += "e"
	end
end

class Integer

	def bencode
		"i#{self}e"
	end
end

class String

	def bencode
		"#{self.length}:#{self}"
	end
end

include Bencode

puts "Testing bencoding...\n"

test = "spam"

puts "String encode test: " + test.bencode + "\n"

test = test.bencode 

puts "String decode test: " + Bencode.decode(test) + "\n"

test = ["spam", "eggs"]

puts "List encode test: " + test.bencode + "\n"

test = test.bencode

puts "List decode test: " + Bencode.decode(test).to_s + "\n"

test = 3

puts "Integer encode test: " + test.bencode + "\n"

test = test.bencode

puts "Integer decode test: " + Bencode.decode(test) + "\n"

test = { "spam" => [ "a", "b" ] } 

puts "Dictionary encode test: " + test.bencode + "\n"

test = test.bencode

puts "Dictionary decode test: " + Bencode.decode(test).to_s + "\n"

