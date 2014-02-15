require 'json'
require 'net/http'
require 'ruby-progressbar'

# https://itunes.apple.com/search?term=middle%20cyclone&entity=album

# Latest track 12 feb 2014
# Oldest track 23 sep 2013

SPOTIFY_TRACK_API_URL = 'http://ws.spotify.com/lookup/1/.json?uri=spotify:track:%s'
SPOTIFY_ALBUM_API_URL = 'http://ws.spotify.com/lookup/1/.json?uri=spotify:album:%s&extras=track'
URIS_FILE = 'tracks.json'
CACHE_FILE = 'tracks_cache.json'
ALBUMS_CACHE_FILE = 'albums_cache.json'
INDIVIDUAL_TRACKS_CACHE_FILE = 'individual_tracks_cache.json'

ALBUM_THRESHOLD = 10

def get_track id
  uri = URI.parse(SPOTIFY_TRACK_API_URL % id)
  response = JSON.parse(Net::HTTP.get(uri))
  {
    'track_id' => response['track']['href'],
    'artist' => response['track']['artists'].first['name'],
    'title' => response['track']['name'],
    'album' => response['track']['album']['name'],
    'album_href' => response['track']['album']['href'],
  }
end

def get_album id
  uri = URI.parse(SPOTIFY_ALBUM_API_URL % id)
  response = JSON.parse(Net::HTTP.get(uri))
  {
    'artist' => response['album']['artist'],
    'title' => response['album']['name'],
    'track_ids' => response['album']['tracks'].map{ |track| track['href'] }
  }
end

def spotify_id_from href
  href.split(':').last
end

if File.exists?(CACHE_FILE) && tracks = JSON.parse( IO.read(CACHE_FILE) )
  puts "Loaded #{tracks.count} tracks from #{CACHE_FILE}"
else
  puts "Loading Spotify URIs from #{URIS_FILE}..."
  track_ids = JSON.parse( IO.read(URIS_FILE) )[0...100]
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

if File.exists?(ALBUMS_CACHE_FILE) && File.exists?(INDIVIDUAL_TRACKS_CACHE_FILE)
  albums = JSON.parse( IO.read(ALBUMS_CACHE_FILE) )
  individual_tracks = JSON.parse( IO.read(INDIVIDUAL_TRACKS_CACHE_FILE) )
  puts "Loaded #{albums.count} albums from #{ALBUMS_CACHE_FILE}"
  puts "Loaded #{individual_tracks.count} individual tracks from #{INDIVIDUAL_TRACKS_CACHE_FILE}"
else
  puts "Grouping tracks by album..."
  grouped_tracks = tracks.group_by{ |track| track['album_href'] }
  puts "#{grouped_tracks.count} albums detected"
  puts

  puts "Sorting tracks between albums and individual tracks..."
  albums = []
  individual_tracks = []
  progressbar = ProgressBar.create(total: grouped_tracks.count)
  grouped_tracks.each do |album_href, tracks|
    album_id = spotify_id_from(album_href)
    album = get_album(album_id)
    unmatched_tracks = album['track_ids'] - tracks.map{ |track| track['track_id'] }
    if unmatched_tracks.empty? || album['track_ids'].count - unmatched_tracks.count >= ALBUM_THRESHOLD
      albums << album
    else
      individual_tracks.concat(tracks)
    end
    sleep 0.2 if tracks.count % 10 == 0 # Let's not hammer the API
    progressbar.increment
  end
  puts "Found #{albums.count} albums and #{individual_tracks.count} tracks"
  puts

  puts "Caching albums..."
  File.open(ALBUMS_CACHE_FILE, 'w'){ |file| file.write(albums.to_json) }
  puts "Cached albums in #{ALBUMS_CACHE_FILE}"
  puts

  puts "Caching individual tracks..."
  File.open(INDIVIDUAL_TRACKS_CACHE_FILE, 'w'){ |file| file.write(individual_tracks.to_json) }
  puts "Cached individual tracks in #{INDIVIDUAL_TRACKS_CACHE_FILE}"
  puts
end

consistency_check = albums.inject(0){ |sum, album| sum + album['track_ids'].count } + individual_tracks.count
raise "Expected at least #{tracks.count} tracks but #{consistency_check} were found" unless consistency_check >= tracks.count



# puts "Fetching track prices from iTunes..."
# progressbar = ProgressBar.create(total: tracks.count)

