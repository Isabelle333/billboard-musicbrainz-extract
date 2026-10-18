-- mb_04_billboard.sql
-- Loads the list of Billboard songs to look up (exported from our notebook, Section 8.1).
-- One row per printed spelling of each song: song_id, name_id, title, performer.
-- Run from the folder that contains billboard_song_names.csv.
\set ON_ERROR_STOP 1
SET client_min_messages = warning;

DROP TABLE IF EXISTS bb_song_names;
CREATE TABLE bb_song_names (
    song_id    TEXT    NOT NULL,
    name_id    INTEGER PRIMARY KEY,
    title      TEXT    NOT NULL,
    performer  TEXT    NOT NULL
);
\copy bb_song_names FROM 'billboard_song_names.csv' WITH (FORMAT csv, HEADER true)

SELECT COUNT(*) AS spellings, COUNT(DISTINCT song_id) AS songs FROM bb_song_names;