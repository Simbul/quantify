require 'json'
require 'net/http'
require 'ruby-progressbar'
require 'cgi'
require 'plist'

require_relative 'utils'

module Itunes

  include Utils

  COUNTRY = 'GB'
  LIBRARY_FILE = 'Library.xml'

  ITUNES_ALBUM_API_URL = "https://itunes.apple.com/lookup?id=%s&entity=album&country=#{COUNTRY}"
  ITUNES_TRACK_API_URL = "https://itunes.apple.com/lookup?id=%s&entity=song&country=#{COUNTRY}"

  TRACKS_AFTER_EXCLUSION_CACHE_FILE = 'tracks_after_exclusion_cache.json'
  ITUNES_ENRICHED_ALBUMS_CACHE_FILE = 'itunes_enriched_albums_cache.json'
  ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE = 'itunes_enriched_individual_tracks_cache.json'

  def self.fetch_albums albums
    if File.exist?(ITUNES_ENRICHED_ALBUMS_CACHE_FILE)
      albums = JSON.parse( IO.read(ITUNES_ENRICHED_ALBUMS_CACHE_FILE) )
      log "Loaded #{albums.count} albums from #{ITUNES_ENRICHED_ALBUMS_CACHE_FILE}"
    else
      log "Fetching album prices from iTunes..."
      progressbar = progress_bar_for(albums)
      albums.each do |album|
        if without_price?(album) && album['itunes_link']
          itunes_ids = get_itunes_ids(album['itunes_link'])
          album.merge!(get_itunes_album_price(itunes_ids['album_id']))
          sleep 0.1 # let's not hammer iTunes
        end
        progressbar.increment
      end
      log "#{without_price(albums).count} prices still missing"
      log

      cache(albums, ITUNES_ENRICHED_ALBUMS_CACHE_FILE)
    end

    albums
  end

  def self.fetch_tracks individual_tracks
    if File.exist?(ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE)
      individual_tracks = JSON.parse( IO.read(ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE) )
      log "Loaded #{individual_tracks.count} individual tracks from #{ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE}"
    else
      log "Fetching track prices from iTunes..."
      progressbar = progress_bar_for(individual_tracks)
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
      log "#{without_price(individual_tracks).count} prices still missing"
      log

      cache(individual_tracks, ITUNES_ENRICHED_INDIVIDUAL_TRACKS_CACHE_FILE)
    end

    individual_tracks
  end

  def self.exclude_library_tracks tracks
    if File.exist?(TRACKS_AFTER_EXCLUSION_CACHE_FILE) && tracks_after_exclusion = JSON.parse( IO.read(TRACKS_AFTER_EXCLUSION_CACHE_FILE) )
      log "Loaded #{tracks_after_exclusion.count} tracks from #{TRACKS_AFTER_EXCLUSION_CACHE_FILE}"
    else
      if File.exist?(LIBRARY_FILE)
        log "Excluding tracks already in iTunes library '#{LIBRARY_FILE}'..."
        library_tracks = Itunes.library_tracks(LIBRARY_FILE)
      else
        log "No library file in '#{LIBRARY_FILE}': no tracks will be excluded"
        library_tracks = []
      end

      tracks_after_exclusion = tracks.reject{ |track|
        library_tracks.find{ |library_track|
          library_track['artist'].casecmp(track['artist']) == 0 && library_track['title'].casecmp(track['title']) == 0
        }
      }

      log "#{tracks_after_exclusion.count} tracks remaining after exclusion"
      log

      cache(tracks_after_exclusion, TRACKS_AFTER_EXCLUSION_CACHE_FILE)
    end

    tracks_after_exclusion
  end

  def self.library_tracks library_file
    plist = Plist::parse_xml(library_file)

    plist['Tracks'].values
      .select{ |track| !track['Podcast'] }
      .map{ |track|
        {
          'artist' => track['Artist'] || '',
          'title' => track['Name'] || '',
          'album' => track['Album'] || '',
        }
      }
  end

  def self.get_itunes_ids itunes_link
    uri = URI.parse(itunes_link)
    response = Net::HTTP.get_response(uri)

    redirect = response['location']
    itunes_url = URI.parse(CGI.parse(URI.parse(redirect).query)['url'].first)
    {
      'album_id' => itunes_url.path[/id(\d+)/, 1],
      'track_id' => itunes_url.query[/i=(\d+)/, 1],
    }
  end

  def self.get_itunes_album_price album_id
    response = get(ITUNES_ALBUM_API_URL % album_id)

    if response['results'].empty?
      {}
    else
      {
        'price' => response['results'].first['collectionPrice'],
        'currency' => response['results'].first['currency'],
      }
    end
  end

  def self.get_itunes_track_price track_id
    response = get(ITUNES_TRACK_API_URL % track_id)

    if response['results'].empty?
      {}
    else
      {
        'price' => response['results'].first['trackPrice'],
        'currency' => response['results'].first['currency'],
      }
    end
  end

end
