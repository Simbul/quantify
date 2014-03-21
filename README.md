# Quantify

An answer to the question "How much would I have spent if I had bought all the stuff I listened to on Spotify?".

In other words, a collection of scripts to associate a monetary value to the tracks you listen to on Spotify.

Quantify gets data from public APIs for Spotify, iTunes and Last.fm (the latter requires an API key).

## Installation

Install support gems:

```
$ bundle install
```

Store your [Last.fm API key](http://www.last.fm/api) in a file named `lastfm_api_key`.

```
$ echo 'your key here' > lastfm_api_key
```

Optionally, store an iTunes library export in a file named `Library.xml`. To get it in iTunes: File -> Library -> Export Library...

Quantify will assume you already own all the tracks in your library and ignore them when it comes to calculating value.

## Usage

Get the list of tracks you want to quantify. In most cases, this will be your Spotify history, which you can access from Play Queue -> History. Select all items in the history and copy them (HTTP links and Spotify URIs are both fine).
Paste the results in a file called `spotify_track_uris` (see `spotify_track_uris.example` for an example).

Run the `quantify.rb` script. You'll notice that the script goes through many steps and it creates a cache file for each one (to minimise API calls in the future).

```
$ ./quantify.rb
[Spotify] Loading Spotify URIs from spotify_track_uris...
[Spotify] 2000 URIs loaded
[Spotify]
[Spotify] Removing duplicate URIs...
[Spotify] 1680 unique URIs remaining
...
```

At the end of the script run, the most interesting files will be `itunes_enriched_albums_cache.json` and `itunes_enriched_individual_tracks_cache.json`.

Run the `counter.rb` script. This will give you stats on the value of all your tracks and albums.

```
$ ./counter.rb
Loaded 112 albums from itunes_enriched_albums_cache.json
Loaded 387 individual tracks from itunes_enriched_individual_tracks_cache.json
The total value of your albums is 665.81 GBP
The average price of one of your albums is 5.94 GBP
...
```

## How does it all work?

The scripts are based on a number of assumptions, so YMMV. This section will explain those assumptions so you can have an idea whether they apply to you.

The basic idea is to use the Spotify API to get info about tracks and albums and then the Last.fm API to get prices (or links to iTunes). The iTunes API is only used as a fallback to process the "buy" links provided by Last.fm.

The reason for relying on Last.fm instead of going to iTunes directly is that finding the price for a very specific item using the iTunes API is very unreliable (not to mention, a royal pain the neck).

The `quantify.rb` script goes through the following steps:

1. Load HTTP links or Spotify URIs from `spotify_track_uris`
2. Query the Spotify API to retrieve track info (e.g. artist and title) for the URIs
3. Load a local iTunes library from `Library.xml` and exclude all the tracks it contains from further processing (as you probably already own them)
4. Query the Spotify API to group tracks into albums. This is based on the fact that buying an album is usually cheaper than buying all its tracks individually. If you have 10 or more tracks from the same album, they will be grouped. This is based on the assumption that, even if you don't care about all tracks, buying the album will be cheaper if you want 10 tracks or more.
5. Query the Last.fm API to retrieve pricing info for your albums (price if possible, iTunes buy link if not).
6. Query the iTunes API to retrieve pricing info for the albums Last.fm could not price.
7. Query the Last.fm API to retrieve pricing info for your tracks outside of albums (price if possible, iTunes buy link if not).
8. Query the iTunes API to retrieve pricing info for the tracks Last.fm could not price.

At the end of a run, the script will print out albums and tracks that could not be priced. This is usually due to inconsistencies in the names used by the different APIs or to Last.fm not having any buying info for it. For albums, a reason could be iTunes not selling them as a whole (only as a collection of individual tracks).

For all API calls retrieving prices, the selected marketplace depends on the value of the `COUNTRY` constant.

## TODO

* iTunes returns a price of `-1` for an album which cannot be bought as a whole. Those should be split back into their tracks.

## Legal mumbo-jumbo

This product uses a SPOTIFY API but is not endorsed, certified or otherwise approved in any way by Spotify. Spotify is the registered trade mark of the Spotify Group.
