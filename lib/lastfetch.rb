require 'json'
require 'net/http'
require 'ruby-progressbar'

module Lastfetch

  class HTTPResponseError < RuntimeError; end

  raise "Your Last.fm API key must be provided in a file called lastfm_api_key" unless File.exist?('lastfm_api_key')
  LASTFM_API_KEY = IO.read('lastfm_api_key').chomp

  COUNTRY = 'GB'

  LASTFM_ALBUM_API_URL = "http://ws.audioscrobbler.com/2.0/?method=album.getbuylinks&artist=%s&album=%s&country=#{COUNTRY}&api_key=#{LASTFM_API_KEY}&format=json&autocorrect=1"
  LASTFM_TRACK_API_URL = "http://ws.audioscrobbler.com/2.0/?method=track.getbuylinks&artist=%s&track=%s&country=#{COUNTRY}&api_key=#{LASTFM_API_KEY}&format=json&autocorrect=1"

  ENRICHED_ALBUMS_CACHE_FILE = 'enriched_albums_cache.json'

  def self.fetch_albums albums
    if File.exist?(ENRICHED_ALBUMS_CACHE_FILE) && albums = JSON.parse( IO.read(ENRICHED_ALBUMS_CACHE_FILE) )
      log "Loaded #{albums.count} albums from #{ENRICHED_ALBUMS_CACHE_FILE}"
    else
      log "Fetching album prices from Last.fm..."
      progressbar = ProgressBar.create(total: albums.count)
      albums.each do |album|
        enrich_album_price_from_lastfm!(album)
        sleep 0.2 # Last.fm TOS (clause 4.4) require not to make "more than 5 requests per originating IP address per second, averaged over a 5 minute period"
        progressbar.increment
      end
      log "#{with_price(albums).count} prices fetched, #{without_price(albums).count} prices not found"
      log

      cache(albums, ENRICHED_ALBUMS_CACHE_FILE)
    end

    albums
  end

  def self.enrich_album_price_from_lastfm! album
    enrich_price_from_lastfm!(album, LASTFM_ALBUM_API_URL)
  end

  def self.enrich_price_from_lastfm! item, api_url
    uri_params = [item['artist'], item['title']].map{ |param| URI.encode(param) }

    response = get(api_url % uri_params)

    if response.has_key?('affiliations')
      itunes = response['affiliations']['downloads']['affiliation'].find{ |affiliation| affiliation['supplierName'] == 'iTunes' }
      item['itunes_link'] = itunes['buyLink']
      if itunes.has_key?('price')
        item['price'] = itunes['price']['amount']
        item['currency'] = itunes['price']['currency']
      end
    end
  end

  def self.with_price items
    items.select{ |item| with_price?(item) }
  end

  def self.without_price items
    items.select{ |item| without_price?(item) }
  end

  def self.with_price? item
    item.has_key?('price')
  end

  def self.without_price? item
    !item.has_key?('price')
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
