require 'retryable'

module Utils

  class HTTPResponseError < RuntimeError; end

  module ClassMethods
    def log msg=''
      puts "[#{self.name}] #{msg}"
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

    def get uri_string
      uri = URI.parse(uri_string)

      begin
        response = nil
        retryable(:tries => 3) do
          response = Net::HTTP.get_response(uri)
          raise HTTPResponseError, "HTTP call response is #{response.code}: #{response.msg}" unless response.code == '200'
        end
        json = JSON.parse(response.body)
      rescue Exception => e
        log "Error requesting #{uri}"
        raise
      end

      json
    end

    def cache content, file, desc: 'objects'
      log "Caching #{desc}..."
      File.open(file, 'w'){ |f| f.write(content.to_json) }
      log "Cached #{desc} in #{file}"
      log
    end

    def consistency_check albums, tracks, individual_tracks
      consistency_check = albums.inject(0){ |sum, album| sum + album['track_ids'].count } + individual_tracks.count
      raise "Expected at least #{tracks.count} tracks but #{consistency_check} were found" unless consistency_check >= tracks.count
    end

    def progress_bar_for items
      ProgressBar.create(total: items.count, format: '%t: |%B| %c/%C')
    end
  end

  extend ClassMethods
  def self.included(other)
    other.extend(ClassMethods)
  end
end
