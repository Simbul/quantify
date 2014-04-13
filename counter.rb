#!/usr/bin/env ruby

require 'json'

require_relative 'lib/utils'

ITUNES_ENRICHED_ALBUMS_CACHE_FILE = 'itunes_enriched_albums_cache.json'
ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE = 'itunes_enriched_individual_tracks_cache.json'

raise "Your albums must be cached in #{ITUNES_ENRICHED_ALBUMS_CACHE_FILE}" unless File.exist?(ITUNES_ENRICHED_ALBUMS_CACHE_FILE)
raise "Your tracks must be cached in #{ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE}" unless File.exist?(ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE)

all_albums = JSON.parse( IO.read(ITUNES_ENRICHED_ALBUMS_CACHE_FILE) )
puts "Loaded #{all_albums.count} albums from #{ITUNES_ENRICHED_ALBUMS_CACHE_FILE}"

all_tracks = JSON.parse( IO.read(ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE) )
puts "Loaded #{all_tracks.count} individual tracks from #{ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE}"

triaged_albums = all_albums.group_by{ |item| Utils.with_price?(item) }
albums = triaged_albums[true]
skipped_albums = triaged_albums[false]

triaged_tracks = all_tracks.group_by{ |item| Utils.with_price?(item) }
tracks = triaged_tracks[true]
skipped_tracks = triaged_tracks[false]

album_currencies = albums.map{ |album| album['currency'] }.compact.uniq
track_currencies = tracks.map{ |track| track['currency'] }.compact.uniq
raise "Your album prices have multiple currencies" unless album_currencies.count == 1
raise "Your track prices have multiple currencies" unless track_currencies.count == 1
ALBUM_CURRENCY = album_currencies.first
TRACK_CURRENCY = track_currencies.first

album_prices = albums.map{ |album| album['price'].to_f }.compact
track_prices = tracks.map{ |track| track['price'].to_f }.compact

album_total_value = album_prices.inject{ |sum, price| sum + price }.to_f
album_avg_price = album_total_value / albums.count

track_total_value = track_prices.inject{ |sum, price| sum + price }.to_f
track_avg_price = track_total_value / tracks.count

puts "The total value of your albums is #{album_total_value.round(2)} #{ALBUM_CURRENCY}"
puts "The average price of one of your albums is #{album_avg_price.round(2)} #{ALBUM_CURRENCY}"
puts "The cheapest album is #{album_prices.min} #{ALBUM_CURRENCY} and the most expensive #{album_prices.max} #{ALBUM_CURRENCY}"

puts "The total value of your tracks is #{track_total_value.round(2)} #{TRACK_CURRENCY}"
puts "The average price of one of your tracks is #{track_avg_price.round(2)} #{TRACK_CURRENCY}"
puts "The cheapest track is #{track_prices.min} #{TRACK_CURRENCY} and the most expensive #{track_prices.max} #{TRACK_CURRENCY}"

unless skipped_albums.empty?
  puts
  puts "A price could not be found for the following #{skipped_albums.count} albums:"
  skipped_albums.each{ |item| puts " * #{item['artist']} - #{item['title']}" }
end

unless skipped_tracks.empty?
  puts
  puts "A price could not be found for the following #{skipped_tracks.count} tracks:"
  skipped_tracks.each{ |item| puts " * #{item['artist']} - #{item['title']}" }
end
