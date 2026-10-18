-- mb_06_export.sql
-- Writes the result to a CSV file (MusicBrainz data + our song_id only; no Billboard chart data).
\set ON_ERROR_STOP 1
\copy (SELECT * FROM song_musicbrainz ORDER BY song_id) TO 'musicbrainz_for_billboard_songs.csv' WITH (FORMAT csv, HEADER true)
SELECT COUNT(*) AS rows_exported FROM song_musicbrainz;