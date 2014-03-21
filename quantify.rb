#!/usr/bin/env ruby

require_relative 'lib/spotifetch'
require_relative 'lib/lastfetch'

tracks = Spotifetch.fetch
albums, individual_tracks = Spotifetch.group(tracks)

enriched_albums = Lastfetch.fetch_albums(albums)
