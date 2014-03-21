require 'json'
require 'net/http'
require 'ruby-progressbar'
require 'cgi'

require_relative 'utils'

module Itunesfetch

  extend Utils

  COUNTRY = 'GB'

  ITUNES_ALBUM_API_URL = "https://itunes.apple.com/lookup?id=%s&entity=album&country=#{COUNTRY}"
  ITUNES_TRACK_API_URL = "https://itunes.apple.com/lookup?id=%s&entity=song&country=#{COUNTRY}"

  ITUNES_ENRICHED_ALBUMS_CACHE_FILE = 'itunes_enriched_albums_cache.json'

  def self.fetch_albums albums
    if File.exist?(ITUNES_ENRICHED_ALBUMS_CACHE_FILE)
      albums = JSON.parse( IO.read(ITUNES_ENRICHED_ALBUMS_CACHE_FILE) )
      log "Loaded #{albums.count} albums from #{ITUNES_ENRICHED_ALBUMS_CACHE_FILE}"
    else
      log "Fetching album prices from iTunes..."
      progressbar = ProgressBar.create(total: albums.count)
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

end