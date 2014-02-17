require 'json'
require 'net/http'
require 'open-uri'
require 'cgi'
require 'ruby-progressbar'

# Latest track 12 feb 2014
# Oldest track 23 sep 2013

raise "Your Last.fm API key must be provided in a file called lastfm_api_key" unless File.exist?('lastfm_api_key')
LASTFM_API_KEY = IO.read('lastfm_api_key').chomp

COUNTRY = 'GB'

SPOTIFY_TRACK_API_URL = 'http://ws.spotify.com/lookup/1/.json?uri=spotify:track:%s'
SPOTIFY_ALBUM_API_URL = 'http://ws.spotify.com/lookup/1/.json?uri=spotify:album:%s&extras=track'
LASTFM_ALBUM_API_URL = "http://ws.audioscrobbler.com/2.0/?method=album.getbuylinks&artist=%s&album=%s&country=#{COUNTRY}&api_key=#{LASTFM_API_KEY}&format=json&autocorrect=1"
LASTFM_TRACK_API_URL = "http://ws.audioscrobbler.com/2.0/?method=track.getbuylinks&artist=%s&track=%s&country=#{COUNTRY}&api_key=#{LASTFM_API_KEY}&format=json&autocorrect=1"
ITUNES_ALBUM_API_URL = "https://itunes.apple.com/lookup?id=%s&entity=album&country=#{COUNTRY}"
ITUNES_TRACK_API_URL = "https://itunes.apple.com/lookup?id=%s&entity=song&country=#{COUNTRY}"

URIS_FILE = 'tracks.json'
CACHE_FILE = 'tracks_cache.json'
ALBUMS_CACHE_FILE = 'albums_cache.json'
ENRICHED_ALBUMS_CACHE_FILE = 'enriched_albums_cache.json'
ITUNES_ENRICHED_ALBUMS_CACHE_FILE = 'itunes_enriched_albums_cache.json'
INDIVIDUAL_TRACKS_CACHE_FILE = 'individual_tracks_cache.json'
ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE = 'enriched_individual_tracks_cache.json'
ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE = 'itunes_enriched_individual_tracks_cache.json'

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

def enrich_album_price_from_lastfm! album
  enrich_price_from_lastfm!(album, LASTFM_ALBUM_API_URL)
end

def enrich_track_price_from_lastfm! track
  enrich_price_from_lastfm!(track, LASTFM_TRACK_API_URL)
end

def enrich_price_from_lastfm! item, api_url
  uri_params = [item['artist'], item['title']].map{ |param| URI.encode(param) }
  uri = URI.parse(api_url % uri_params)

  response = JSON.parse(Net::HTTP.get(uri))

  if response.has_key?('affiliations')
    itunes = response['affiliations']['downloads']['affiliation'].find{ |affiliation| affiliation['supplierName'] == 'iTunes' }
    item['itunes_link'] = itunes['buyLink']
    if itunes.has_key?('price')
      item['price'] = itunes['price']['amount']
      item['currency'] = itunes['price']['currency']
    end
  end
end

def get_itunes_ids itunes_link
  uri = URI.parse(itunes_link)
  response = Net::HTTP.get_response(uri)

  redirect = response['location']
  itunes_url = URI.parse(CGI.parse(URI.parse(redirect).query)['url'].first)
  {
    'album_id' => itunes_url.path[/id(\d+)/, 1],
    'track_id' => itunes_url.query[/i=(\d+)/, 1],
  }
end

def get_itunes_album_price album_id
  uri = URI.parse(ITUNES_ALBUM_API_URL % album_id)
  response = JSON.parse(Net::HTTP.get(uri))

  if response['results'].empty?
    {}
  else
    {
      'price' => response['results'].first['collectionPrice'],
      'currency' => response['results'].first['currency'],
    }
  end
end

def get_itunes_track_price track_id
  uri = URI.parse(ITUNES_TRACK_API_URL % track_id)
  response = JSON.parse(Net::HTTP.get(uri))

  if response['results'].empty?
    {}
  else
    {
      'price' => response['results'].first['trackPrice'],
      'currency' => response['results'].first['currency'],
    }
  end
end

def spotify_id_from href
  href.split(':').last
end

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

if File.exists?(CACHE_FILE) && tracks = JSON.parse( IO.read(CACHE_FILE) )
  puts "Loaded #{tracks.count} tracks from #{CACHE_FILE}"
else
  puts "Loading Spotify URIs from #{URIS_FILE}..."
  track_ids = JSON.parse( IO.read(URIS_FILE) )
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

  cache(tracks, CACHE_FILE)
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
    sleep 0.2 if (albums.count + individual_tracks.count) % 10 == 0 # Let's not hammer the API
    progressbar.increment
  end
  puts "Found #{albums.count} albums and #{individual_tracks.count} tracks"
  puts

  cache(albums, ALBUMS_CACHE_FILE)
  cache(individual_tracks, INDIVIDUAL_TRACKS_CACHE_FILE)
end

consistency_check = albums.inject(0){ |sum, album| sum + album['track_ids'].count } + individual_tracks.count
raise "Expected at least #{tracks.count} tracks but #{consistency_check} were found" unless consistency_check >= tracks.count

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

if File.exist?(ENRICHED_ALBUMS_CACHE_FILE)
  albums = JSON.parse( IO.read(ENRICHED_ALBUMS_CACHE_FILE) )
  puts "Loaded #{albums.count} albums from #{ENRICHED_ALBUMS_CACHE_FILE}"
else
  puts "Fetching album prices from Last.fm..."
  progressbar = ProgressBar.create(total: albums.count)
  albums.each do |album|
    enrich_album_price_from_lastfm!(album)
    sleep 0.2 # Last.fm TOS (clause 4.4) require not to make "more than 5 requests per originating IP address per second, averaged over a 5 minute period"
    progressbar.increment
  end
  puts "#{with_price(albums).count} prices fetched, #{without_price(albums).count} prices not found"
  puts

  cache(albums, ENRICHED_ALBUMS_CACHE_FILE)
end

if File.exist?(ITUNES_ENRICHED_ALBUMS_CACHE_FILE)
  albums = JSON.parse( IO.read(ITUNES_ENRICHED_ALBUMS_CACHE_FILE) )
  puts "Loaded #{albums.count} albums from #{ITUNES_ENRICHED_ALBUMS_CACHE_FILE}"
else
  puts "Fetching album prices from iTunes..."
  progressbar = ProgressBar.create(total: albums.count)
  albums.each do |album|
    if without_price?(album) && album['itunes_link']
      itunes_ids = get_itunes_ids(album['itunes_link'])
      album.merge!(get_itunes_album_price(itunes_ids['album_id']))
      sleep 0.1 # let's not hammer iTunes
    end
    progressbar.increment
  end
  puts "#{without_price(albums).count} prices still missing"
  puts

  cache(albums, ITUNES_ENRICHED_ALBUMS_CACHE_FILE)
end

# Albums with a price of -1 cannot be bought on iTunes (only individual tracks available)
# puts "Splitting albums that cannot be bought..."

if File.exist?(ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE)
  individual_tracks = JSON.parse( IO.read(ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE) )
  puts "Loaded #{individual_tracks.count} individual tracks from #{ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE}"
else
  puts "Fetching track prices from Last.fm..."
  progressbar = ProgressBar.create(total: individual_tracks.count)
  individual_tracks.each do |track|
    enrich_track_price_from_lastfm!(track)
    sleep 0.2 # Last.fm TOS (clause 4.4) require not to make "more than 5 requests per originating IP address per second, averaged over a 5 minute period"
    progressbar.increment
  end
  puts "#{with_price(individual_tracks).count} prices fetched, #{without_price(individual_tracks).count} prices not found"
  puts

  cache(individual_tracks, ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE)
end

if File.exist?(ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE)
  individual_tracks = JSON.parse( IO.read(ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE) )
  puts "Loaded #{individual_tracks.count} individual tracks from #{ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE}"
else
  puts "Fetching track prices from iTunes..."
  progressbar = ProgressBar.create(total: individual_tracks.count)
  individual_tracks.each do |track|
    if without_price?(track) && track['itunes_link']
      itunes_ids = get_itunes_ids(track['itunes_link'])
      if itunes_ids['track_id']
        track.merge!(get_itunes_track_price(itunes_ids['track_id']))
      end
      sleep 0.1 # let's not hammer iTunes
    end
    progressbar.increment
  end
  puts "#{without_price(individual_tracks).count} prices still missing"
  puts

  cache(individual_tracks, ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE)
end

unless without_price(albums).empty?
  puts "A price could not be found for the following albums:"
  without_price(albums).each do |album|
    puts " * #{album['artist']} - #{album['title']}"
  end
  puts
end

unless without_price(individual_tracks).empty?
  puts "A price could not be found for the following tracks:"
  without_price(individual_tracks).each do |track|
    puts " * #{track['artist']} - #{track['title']} (from #{track['album']})"
  end
  puts
end
