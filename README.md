# MusicBrainz information for Billboard Hot 100 songs (2000–2025)

Output of the MusicBrainz step of our ESSEC data project (Group C): for each song that reached the Billboard Hot 100 between 2000 and 2025 (identified by our own `song_id`), its MusicBrainz recording, first release date, first release type and genres.

## Files
- `musicbrainz_for_billboard_songs.csv` – the result (one row per song; MusicBrainz data and our `song_id` only, no Billboard chart data)
- `musicbrainz_for_billboard_songs.sha256` – its SHA-256 fingerprint
- `run_all.sh`, `sql/` – the scripts that produced it (PostgreSQL)
- `provenance_musicbrainz.txt` – dump used, checksums, software version, run time
- `run_log.txt` – full output of the run

## Source and licence
Data from **MusicBrainz** (https://musicbrainz.org), full export `20261017-002244`, published by the MetaBrainz Foundation.
- Core data (recordings, artists, releases): **CC0** (public domain).
- Genres are derived from MusicBrainz user tags: **CC BY-NC-SA 3.0** – attribution to MusicBrainz, non-commercial use, share-alike.

This repository is therefore published under the same terms for the genre information (CC BY-NC-SA 3.0), for non-commercial educational use.

## Reproducing
See `provenance_musicbrainz.txt` and the comments in `run_all.sh`. MusicBrainz publishes each full export for about two weeks only; re-running the scripts on a later export reproduces the method but may give slightly different results.
