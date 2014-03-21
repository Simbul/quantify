require 'json'
require 'net/http'
require 'open-uri'
require 'cgi'
require 'ruby-progressbar'

require_relative 'lib/spotifetch'

# Latest track 12 feb 2014
# Oldest track 23 sep 2013


def cache content, file, desc: 'objects'
  puts "Caching #{desc}..."
  File.open(file, 'w'){ |f| f.write(content.to_json) }
  puts "Cached #{desc} in #{file}"
  puts
end

def with_price items
  items.select{ |item| with_price?(item) }
end

def without_price items
  items.select{ |item| without_price?(item) }
end

def with_price? item
  item.has_key?('price')
end

def without_price? item
  !item.has_key?('price')
end

tracks = Spotifetch.fetch
albums, individual_tracks = Spotifetch.group(tracks)

# This doesn't return prices in the last.fm response
# http://ws.audioscrobbler.com/2.0/?method=track.getbuylinks&autocorrect=1&artist=Choeurs%20Ren%C3%A9%20Duclos/Choeurs%20d%27Enfants%20Jean%20Pesneaud/Orchestre%20de%20l%27Op%C3%A9ra%20National%20de%20Paris/Georges%20Pr%C3%AAtre&country=united%20kingdom&api_key=eb5d09df54b0ebf14541ae6da045476b&format=json&track=Carmen%20(1997%20-%20Remaster),%20Act%20I:%20La%20cloche%20a%20sonn%C3%A9....Dans%20l%27air
# But the iTunes link takes you here
# https://itunes.apple.com/gb/album/bizet-carmen/id696628355?affId=1773178&ign-mpt=uo%3D4
# And the id can be used in an album lookup
# https://itunes.apple.com/lookup?id=696628355&entity=album&country=GB
# Which contains the tracks, though not the specific one we were looking for
# But then again, sometimes the link will be
# https://itunes.apple.com/gb/album/id259584141?i=259584887&affId=1773178&ign-mpt=uo%3D5
# Which contains both the album id and the track id, so we can do
# https://itunes.apple.com/lookup?id=259584887&entity=song&country=GB



# Albums with a price of -1 cannot be bought on iTunes (only individual tracks available)
# puts "Splitting albums that cannot be bought..."


