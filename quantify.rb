#!/usr/bin/env ruby

require_relative 'lib/spotify'
require_relative 'lib/lastfm'
require_relative 'lib/itunes'
require_relative 'lib/utils'

tracks = Spotify.fetch
albums, individual_tracks = Spotify.group(tracks)

Utils.consistency_check(albums, tracks, individual_tracks)

enriched_albums = Lastfm.fetch_albums(albums)

itunes_albums = Itunes.fetch_albums(enriched_albums)

# Albums with a price of -1 cannot be bought on iTunes (only individual tracks available)
# TODO: split albums into individual tracks

enriched_tracks = Lastfm.fetch_tracks(individual_tracks)

itunes_tracks = Itunes.fetch_tracks(enriched_tracks)

unless Utils.without_price(itunes_albums).empty?
  puts "A price could not be found for the following albums:"
  Utils.without_price(itunes_albums).each do |album|
    puts " * #{album['artist']} - #{album['title']}"
  end
  puts
end

unless Utils.without_price(itunes_tracks).empty?
  puts "A price could not be found for the following tracks:"
  Utils.without_price(itunes_tracks).each do |track|
    puts " * #{track['artist']} - #{track['title']} (from #{track['album']})"
  end
  puts
end
