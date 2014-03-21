module Utils

  class HTTPResponseError < RuntimeError; end

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
      response = Net::HTTP.get_response(uri)
      raise HTTPResponseError, "HTTP call response is #{response.code}: #{response.msg}" unless response.code == '200'
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

end
