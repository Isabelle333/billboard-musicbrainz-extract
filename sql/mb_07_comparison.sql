-- mb_07_comparison.sql
-- Builds the comparison group (Job B): songs by the lead artists of our charting songs that never
-- reached the Hot 100, with the same information as for the charting songs (first release date,
-- type of the first release, genre), derived with the same rules as mb_05_match.sql.
-- Needs the tables created by mb_04_billboard.sql and mb_05_match.sql (bb_keys, matches).
\set ON_ERROR_STOP 1
\timing on
SET client_min_messages = warning;   -- hide harmless 'table does not exist, skipping' notices

------------------------------------------------------------------------------
-- 0. Check that the results of Job A are still in the database
------------------------------------------------------------------------------
SELECT COUNT(DISTINCT song_id) AS matched_billboard_songs FROM matches;      -- expected: 11224

------------------------------------------------------------------------------
-- 1. Lead artist of each matched Billboard song: the first credited artist (position 0) of its
--    matched recordings; if these differ (e.g. a remix credited to a DJ), the most frequent one.
--    Placeholder "artists" such as Various Artists are not real artists and are skipped.
------------------------------------------------------------------------------
DROP TABLE IF EXISTS song_lead_artist;
CREATE TABLE song_lead_artist AS
SELECT DISTINCT ON (x.song_id) x.song_id, x.artist
FROM (
    SELECT m.song_id, acn.artist, COUNT(*) AS n_recordings
    FROM matches m
    JOIN recording r            ON r.id = m.recording
    JOIN artist_credit_name acn ON acn.artist_credit = r.artist_credit AND acn.position = 0
    JOIN artist a               ON a.id = acn.artist
    WHERE a.name NOT IN ('Various Artists', '[unknown]', '[anonymous]', '[traditional]',
                         '[no artist]', '[data]', '[dialogue]')
    GROUP BY m.song_id, acn.artist
) x
ORDER BY x.song_id, x.n_recordings DESC, x.artist;

DROP TABLE IF EXISTS chart_artists;
CREATE TABLE chart_artists AS SELECT DISTINCT artist FROM song_lead_artist;

SELECT (SELECT COUNT(*) FROM song_lead_artist) AS songs_with_lead_artist,
       (SELECT COUNT(*) FROM chart_artists)    AS distinct_lead_artists;

------------------------------------------------------------------------------
-- 2. Indexes for finding all recordings of an artist (not needed by Job A)
------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS acn_artist_idx              ON artist_credit_name (artist);
CREATE INDEX IF NOT EXISTS recording_artist_credit_idx ON recording (artist_credit);

------------------------------------------------------------------------------
-- 3. Every recording on which one of these artists is the first credited artist,
--    with the same exclusions as Job A (music videos; live, karaoke, instrumental, demo,
--    a cappella versions), plus a flag for each reason to leave a recording out
------------------------------------------------------------------------------
DROP TABLE IF EXISTS cmp_recordings;
CREATE TABLE cmp_recordings AS
WITH candidates AS (
    SELECT r.id AS recording, r.artist_credit, ca.artist, r.name, base_title(r.name) AS title_base
    FROM chart_artists ca
    JOIN artist_credit_name acn ON acn.artist = ca.artist AND acn.position = 0
    JOIN recording r            ON r.artist_credit = acn.artist_credit
    WHERE NOT r.video
      AND r.comment !~* '\m(live|karaoke|instrumental|demo|a ?cappella)\M'
)
SELECT c.*,
       c.title_base = ''                                          AS no_title,
       c.title_base ~ '\m(intro|outro|interlude|skit)\M'           AS not_a_song,
       c.title_base IN (SELECT title_base FROM bb_keys)            AS billboard_title,
       c.recording  IN (SELECT recording  FROM matches)            AS charted_recording
FROM candidates c;

ALTER TABLE cmp_recordings ADD COLUMN keep boolean;
UPDATE cmp_recordings SET keep = NOT (no_title OR not_a_song OR billboard_title OR charted_recording);
CREATE INDEX ON cmp_recordings (recording);
CREATE INDEX ON cmp_recordings (artist, title_base);

-- how many recordings each rule removes (a recording can be removed for several reasons)
SELECT COUNT(*)                             AS candidate_recordings,
       COUNT(*) FILTER (WHERE no_title)          AS empty_title,
       COUNT(*) FILTER (WHERE not_a_song)        AS intro_outro_interlude_skit,
       COUNT(*) FILTER (WHERE billboard_title)   AS same_title_as_a_billboard_song,
       COUNT(*) FILTER (WHERE charted_recording) AS matched_to_a_billboard_song,
       COUNT(*) FILTER (WHERE keep)              AS kept
FROM cmp_recordings;

------------------------------------------------------------------------------
-- 4. Releases of the kept recordings (same rules as Job A: bootlegs and pseudo-releases excluded)
------------------------------------------------------------------------------
DROP TABLE IF EXISTS cmp_releases;
CREATE TABLE cmp_releases AS
SELECT DISTINCT c.artist, c.title_base, c.recording, c.artist_credit AS rec_artist_credit,
       rel.id AS release, rg.id AS release_group, rg.artist_credit AS rg_artist_credit,
       rgt.name AS release_group_type,
       d.date_year AS y, d.date_month AS mo, d.date_day AS dd
FROM cmp_recordings c
JOIN track t                 ON t.recording = c.recording
JOIN medium md               ON md.id = t.medium
JOIN release rel             ON rel.id = md.release
JOIN release_group rg        ON rg.id = rel.release_group
LEFT JOIN release_group_primary_type rgt ON rgt.id = rg.type
LEFT JOIN release_status rs  ON rs.id = rel.status
LEFT JOIN (SELECT release, date_year, date_month, date_day FROM release_country
           UNION ALL
           SELECT release, date_year, date_month, date_day FROM release_unknown_country) d
       ON d.release = rel.id
WHERE c.keep
  AND COALESCE(rs.name, '') NOT IN ('Bootleg', 'Pseudo-Release');

------------------------------------------------------------------------------
-- 5. One "song" = one artist + one title (without bracketed parts), so that remixes, edits and
--    re-releases of the same song count once, as on the Billboard chart.
--    Its first release = the earliest dated release of any of its recordings (as in Job A).
------------------------------------------------------------------------------
DROP TABLE IF EXISTS cmp_first_release;
CREATE TABLE cmp_first_release AS
SELECT DISTINCT ON (artist, title_base)
       artist, title_base, recording, release_group, release_group_type, y, mo, dd,
       CASE WHEN mo IS NOT NULL AND dd IS NOT NULL THEN 'day'
            WHEN mo IS NOT NULL THEN 'month'
            ELSE 'year' END AS date_precision
FROM cmp_releases
WHERE y IS NOT NULL
ORDER BY artist, title_base, y, mo NULLS LAST, dd NULLS LAST, release, recording;

-- keep songs first released 2000–2024 (the exact cut-off is applied in the notebook, Section 9)
DROP TABLE IF EXISTS cmp_songs;
CREATE TABLE cmp_songs AS
SELECT md5(a.gid::text || '|' || f.title_base) AS comparison_id,
       a.gid AS artist_mbid, f.*
FROM cmp_first_release f
JOIN artist a ON a.id = f.artist
WHERE f.y BETWEEN 2000 AND 2024;
CREATE UNIQUE INDEX ON cmp_songs (comparison_id);

DROP TABLE IF EXISTS cmp_song_recordings;
CREATE TABLE cmp_song_recordings AS
SELECT s.comparison_id, c.recording, c.artist_credit
FROM cmp_songs s
JOIN cmp_recordings c ON c.artist = s.artist AND c.title_base = s.title_base AND c.keep;

SELECT (SELECT COUNT(DISTINCT (artist, title_base)) FROM cmp_recordings WHERE keep) AS songs_kept,
       (SELECT COUNT(*) FROM cmp_first_release)                                     AS songs_with_a_date,
       (SELECT COUNT(*) FROM cmp_songs)                                             AS songs_released_2000_2024;

------------------------------------------------------------------------------
-- 6. Genres, with exactly the same rules as Job A:
--    recording > release group (artist's own) > artist; official genres with positive votes
------------------------------------------------------------------------------
DROP TABLE IF EXISTS cmp_genre_votes;
CREATE TABLE cmp_genre_votes AS
WITH genre_tags AS (
    SELECT t.id AS tag, t.name AS genre
    FROM tag t JOIN genre g ON lower(g.name) = lower(t.name)
),
rec_level AS (
    SELECT sr.comparison_id, 1 AS level, gt.genre, SUM(rt.count) AS votes
    FROM cmp_song_recordings sr
    JOIN recording_tag rt ON rt.recording = sr.recording AND rt.count > 0
    JOIN genre_tags gt    ON gt.tag = rt.tag
    GROUP BY sr.comparison_id, gt.genre
),
own_release_groups AS (                       -- the artist's own releases, not compilations
    SELECT DISTINCT s.comparison_id, cr.release_group
    FROM cmp_songs s
    JOIN cmp_releases cr ON cr.artist = s.artist AND cr.title_base = s.title_base
    WHERE cr.rg_artist_credit = cr.rec_artist_credit
),
rg_level AS (
    SELECT o.comparison_id, 2 AS level, gt.genre, SUM(rgt.count) AS votes
    FROM own_release_groups o
    JOIN release_group_tag rgt ON rgt.release_group = o.release_group AND rgt.count > 0
    JOIN genre_tags gt         ON gt.tag = rgt.tag
    GROUP BY o.comparison_id, gt.genre
),
artist_level AS (
    SELECT s.comparison_id, 3 AS level, gt.genre, SUM(at.count) AS votes
    FROM cmp_songs s
    JOIN artist_tag at ON at.artist = s.artist AND at.count > 0
    JOIN genre_tags gt ON gt.tag = at.tag
    GROUP BY s.comparison_id, gt.genre
)
SELECT * FROM rec_level
UNION ALL SELECT * FROM rg_level
UNION ALL SELECT * FROM artist_level;

DROP TABLE IF EXISTS cmp_genres;
CREATE TABLE cmp_genres AS
WITH best_level AS (
    SELECT comparison_id, MIN(level) AS level FROM cmp_genre_votes GROUP BY comparison_id
),
ranked AS (
    SELECT v.comparison_id, v.level, v.genre, v.votes,
           ROW_NUMBER() OVER (PARTITION BY v.comparison_id ORDER BY v.votes DESC, v.genre) AS rnk
    FROM cmp_genre_votes v
    JOIN best_level b ON b.comparison_id = v.comparison_id AND b.level = v.level
)
SELECT comparison_id,
       CASE MIN(level) WHEN 1 THEN 'recording' WHEN 2 THEN 'release group' ELSE 'artist' END AS genre_level,
       MAX(genre) FILTER (WHERE rnk = 1)                                          AS top_genre,
       string_agg(genre || ':' || votes, '|' ORDER BY rnk) FILTER (WHERE rnk <= 5) AS top_genres_votes
FROM ranked
GROUP BY comparison_id;

------------------------------------------------------------------------------
-- 7. One row per comparison song (same columns as the Job A file where they apply)
------------------------------------------------------------------------------
DROP TABLE IF EXISTS comparison_musicbrainz;
CREATE TABLE comparison_musicbrainz AS
WITH recordings_per_song AS (                 -- counted once for all songs (fast)
    SELECT comparison_id, COUNT(*) AS n_recordings
    FROM cmp_song_recordings
    GROUP BY comparison_id
)
SELECT s.comparison_id,
       s.artist_mbid,
       r.name                                        AS mb_title,
       COALESCE(n.n_recordings, 0)                   AS n_recordings,
       s.release_group_type                          AS first_release_type,
       s.y                                           AS first_release_year,
       CONCAT_WS('-', s.y::text, lpad(s.mo::text, 2, '0'),
                 CASE WHEN s.mo IS NOT NULL THEN lpad(s.dd::text, 2, '0') END) AS first_release_date,
       s.date_precision,
       g.genre_level,
       g.top_genre,
       g.top_genres_votes
FROM cmp_songs s
JOIN recording r                    ON r.id = s.recording
LEFT JOIN recordings_per_song n     ON n.comparison_id = s.comparison_id
LEFT JOIN cmp_genres g              ON g.comparison_id = s.comparison_id;

-- summary per release year
SELECT first_release_year, COUNT(*) AS songs,
       COUNT(*) FILTER (WHERE date_precision = 'day') AS exact_date,
       COUNT(top_genre) AS with_genre
FROM comparison_musicbrainz GROUP BY first_release_year ORDER BY first_release_year;

SELECT genre_level, COUNT(*) AS songs FROM comparison_musicbrainz GROUP BY genre_level ORDER BY genre_level;