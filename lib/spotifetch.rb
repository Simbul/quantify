require 'json'
require 'net/http'
require 'ruby-progressbar'

module Spotifetch

  class HTTPResponseError < RuntimeError; end

  TRACK_API_URL = 'http://ws.spotify.com/lookup/1/.json?uri=spotify:track:%s'
  ALBUM_API_URL = 'http://ws.spotify.com/lookup/1/.json?uri=spotify:album:%s&extras=track'

  URIS_FILE = 'spotify_track_uris'
  CACHE_FILE = 'tracks_cache.json'
  ALBUMS_CACHE_FILE = 'albums_cache.json'
  INDIVIDUAL_TRACKS_CACHE_FILE = 'individual_tracks_cache.json'

  ALBUM_THRESHOLD = 10

  def self.fetch uris_file=URIS_FILE
    if File.exists?(CACHE_FILE) && tracks = JSON.parse( IO.read(CACHE_FILE) )
      log "Loaded #{tracks.count} tracks from #{CACHE_FILE}"
    else
      log "Loading Spotify URIs from #{uris_file}..."
      track_ids = track_ids_from(uris_file)
      log "#{track_ids.count} URIs loaded"
      log

      log "Removing duplicate URIs..."
      track_ids.uniq!
      log "#{track_ids.count} unique URIs remaining"
      log

      log "Fetching data for URIs..."
      progressbar = ProgressBar.create(total: track_ids.count)
      tracks = []

      track_ids.each do |id|
        tracks << get_track(id)
        sleep 0.2 if tracks.count % 10 == 0 # Let's not hammer the API
        progressbar.increment
      end
      log "#{tracks.count} tracks fetched"
      log

      cache(tracks, CACHE_FILE)
    end

    tracks
  end

  def self.group tracks
    if File.exists?(ALBUMS_CACHE_FILE) && File.exists?(INDIVIDUAL_TRACKS_CACHE_FILE)
      albums = JSON.parse( IO.read(ALBUMS_CACHE_FILE) )
      individual_tracks = JSON.parse( IO.read(INDIVIDUAL_TRACKS_CACHE_FILE) )
      log "Loaded #{albums.count} albums from #{ALBUMS_CACHE_FILE}"
      log "Loaded #{individual_tracks.count} individual tracks from #{INDIVIDUAL_TRACKS_CACHE_FILE}"
    else
      log "Grouping tracks by album..."
      grouped_tracks = tracks.group_by{ |track| track['album_href'] }
      log "#{grouped_tracks.count} albums detected"
      log

      log "Sorting tracks between albums and individual tracks..."
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
      log "Found #{albums.count} albums and #{individual_tracks.count} tracks"
      log

      cache(albums, ALBUMS_CACHE_FILE)
      cache(individual_tracks, INDIVIDUAL_TRACKS_CACHE_FILE)
    end

    [albums, individual_tracks]
  end

  def self.track_ids_from uris_file
    regex = %r{
      track          # prefix: we are looking for a track
      (?:/|:)        # the separator is '/' for HTTP links and ':' for Spotify URIs
      ([0-9A-Za-z]+) # the id itself, e.g. '6WbPC4l07YdaaBtfVCs0vj'
    }x
    IO.read(uris_file)
      .lines
      .map{ |line| line[regex, 1] }.compact
  end

  def self.get uri_string
    uri = URI.parse(uri_string)

    begin
      response = Net::HTTP.get_response(uri)
      raise HTTPResponseError, "HTTP call response is #{response.code}: #{response.msg}" unless response.code == '200'
      json = JSON.parse(response.body)
    rescue Exception => e
      log "Error requesting #{uri}"
      raise
    end

    json
  end

  def self.get_track id
    response = get(TRACK_API_URL % id)
    {
      'track_id' => response['track']['href'],
      'artist' => response['track']['artists'].first['name'],
      'title' => response['track']['name'],
      'album' => response['track']['album']['name'],
      'album_href' => response['track']['album']['href'],
    }
  end

  def self.get_album id
    response = get(ALBUM_API_URL % id)
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
    log "Caching #{desc}..."
    File.open(file, 'w'){ |f| f.write(content.to_json) }
    log "Cached #{desc} in #{file}"
    log
  end

  def self.log msg
    puts "[#{self.name}] #{msg}"
  end

end
