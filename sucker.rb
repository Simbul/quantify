require 'json'
require 'net/http'
require 'ruby-progressbar'

# https://itunes.apple.com/search?term=middle%20cyclone&entity=album

# Latest track 12 feb 2014
# Oldest track 23 sep 2013

API_URL = 'http://ws.spotify.com/lookup/1/.json?uri=spotify:track:%s'
URIS_FILE = 'tracks.json'
CACHE_FILE = 'tracks_cache.json'

def get_track id
  uri = URI.parse(API_URL % id)
  response = JSON.parse(Net::HTTP.get(uri))
  {
    artist: response['track']['artists'].first['name'],
    title: response['track']['name'],
    album: response['track']['album']['name'],
  }
end

if tracks = JSON.parse( IO.read(CACHE_FILE) )
  puts "Loaded #{tracks.count} tracks from #{CACHE_FILE}"
else
  puts "Loading Spotify URIs from #{URIS_FILE}..."
  track_ids = JSON.parse( IO.read(URIS_FILE) ).sample(2)
  puts "#{track_ids.count} URIs loaded"
  puts

  puts "Removing duplicate URIs..."
  track_ids.uniq!
  puts "#{track_ids.count} unique URIs remaining"
  puts

  puts "Fetching data for URIs..."
  progressbar = ProgressBar.create(total: track_ids.count)
  tracks = []

  track_ids.each do |id|
    tracks << get_track(id)
    sleep 0.2 if tracks.count % 10 == 0 # Let's not hammer the API
    progressbar.increment
  end
  puts "#{tracks.count} tracks fetched"
  puts

  puts "Caching tracks..."
  File.open(CACHE_FILE, 'w'){ |file| file.write(tracks.to_json) }
  puts "Cached tracks in #{CACHE_FILE}"
  puts
end

puts "Fetching track prices from iTunes..."
progressbar = ProgressBar.create(total: tracks.count)


