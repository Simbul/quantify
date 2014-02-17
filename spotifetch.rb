#!/usr/bin/env ruby

require_relative 'lib/spotifetch'

tracks = Spotifetch.fetch
albums, individual_tracks = Spotifetch.group(tracks)
