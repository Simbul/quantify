require 'json'
require 'net/http'
require 'ruby-progressbar'

module Spotifetch

  TRACK_API_URL = 'http://ws.spotify.com/lookup/1/.json?uri=spotify:track:%s'
  ALBUM_API_URL = 'http://ws.spotify.com/lookup/1/.json?uri=spotify:album:%s&extras=track'

  URIS_FILE = 'tracks.json'
  CACHE_FILE = 'tracks_cache.json'
  ALBUMS_CACHE_FILE = 'albums_cache.json'
  INDIVIDUAL_TRACKS_CACHE_FILE = 'individual_tracks_cache.json'

  ALBUM_THRESHOLD = 10

  def self.fetch uris_file=URIS_FILE
    if File.exists?(CACHE_FILE) && tracks = JSON.parse( IO.read(CACHE_FILE) )
      puts "Loaded #{tracks.count} tracks from #{CACHE_FILE}"
    else
      puts "Loading Spotify URIs from #{uris_file}..."
      track_ids = JSON.parse( IO.read(uris_file) ).sample(5)
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

    tracks
  end

  def self.group tracks
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

    [albums, individual_tracks]
  end

  def self.get_track id
    uri = URI.parse(TRACK_API_URL % id)
    response = JSON.parse(Net::HTTP.get(uri))
    {
      'track_id' => response['track']['href'],
      'artist' => response['track']['artists'].first['name'],
      'title' => response['track']['name'],
      'album' => response['track']['album']['name'],
      'album_href' => response['track']['album']['href'],
    }
  end

  def self.get_album id
    uri = URI.parse(ALBUM_API_URL % id)
    response = JSON.parse(Net::HTTP.get(uri))
    {
      'artist' => response['album']['artist'],
      'title' => response['album']['name'],
      'track_ids' => response['album']['tracks'].map{ |track| track['href'] }
    }
  end

  def self.spotify_id_from href
    href.split(':').last
  end

  def self.cache content, file, desc: 'objects'
    puts "Caching #{desc}..."
    File.open(file, 'w'){ |f| f.write(content.to_json) }
    puts "Cached #{desc} in #{file}"
    puts
  end

end
