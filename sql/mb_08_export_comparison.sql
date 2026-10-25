-- mb_08_export_comparison.sql
-- Writes the comparison group and the lead artist of each charting song to CSV files
-- (MusicBrainz data + our song_id only; no Billboard chart data).
\set ON_ERROR_STOP 1
\copy (SELECT * FROM comparison_musicbrainz ORDER BY comparison_id) TO 'comparison_songs_musicbrainz.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT l.song_id, a.gid AS artist_mbid, a.name AS artist_name FROM song_lead_artist l JOIN artist a ON a.id = l.artist ORDER BY l.song_id) TO 'billboard_song_lead_artist.csv' WITH (FORMAT csv, HEADER true)
SELECT (SELECT COUNT(*) FROM comparison_musicbrainz) AS comparison_rows_exported,
       (SELECT COUNT(*) FROM song_lead_artist)       AS lead_artist_rows_exported;