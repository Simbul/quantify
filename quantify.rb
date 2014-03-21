#!/usr/bin/env ruby

require_relative 'lib/spotifetch'
require_relative 'lib/lastfetch'
require_relative 'lib/itunesfetch'

tracks = Spotifetch.fetch
albums, individual_tracks = Spotifetch.group(tracks)

consistency_check = albums.inject(0){ |sum, album| sum + album['track_ids'].count } + individual_tracks.count
raise "Expected at least #{tracks.count} tracks but #{consistency_check} were found" unless consistency_check >= tracks.count

enriched_albums = Lastfetch.fetch_albums(albums)

itunes_albums = Itunesfetch.fetch_albums(enriched_albums)
