-- mb_05_match.sql
-- Finds the MusicBrainz recordings of each Billboard song and derives, per song:
-- first release date, type of the first release (single/album/...), and genres.
\set ON_ERROR_STOP 1
\timing on
SET client_min_messages = warning;   -- hide harmless 'table does not exist, skipping' notices

------------------------------------------------------------------------------
-- 1. Name normalisation: the same rules on both sides (Billboard and MusicBrainz)
------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS unaccent;

-- lower case, accents removed, apostrophe styles unified, Feat./Ft. -> featuring,
-- & -> and, punctuation removed, spaces collapsed (same rules as Section 5, plus accents)
CREATE OR REPLACE FUNCTION match_key(t text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT btrim(
         regexp_replace(
         regexp_replace(
         regexp_replace(
         regexp_replace(
         regexp_replace(lower(public.unaccent('public.unaccent'::regdictionary, t)),
                        '[’‘`´]', '''', 'g'),
                        '\m(feat|ft)\.', 'featuring', 'g'),
                        '&', ' and ', 'g'),
                        '[^a-z0-9 ]', '', 'g'),
                        '\s+', ' ', 'g'))
$$;

-- title without anything in brackets, e.g. "Soak City (Do It)" -> "soak city"
CREATE OR REPLACE FUNCTION base_title(t text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT match_key(regexp_replace(t, '\s*[\(\[][^\)\]]*[\)\]]', '', 'g'))
$$;

-- main credited artist: everything before "featuring"
CREATE OR REPLACE FUNCTION lead_key(t text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT btrim(split_part(match_key(t), ' featuring ', 1))
$$;

------------------------------------------------------------------------------
-- 2. Billboard side
------------------------------------------------------------------------------
DROP TABLE IF EXISTS bb_keys;
CREATE TABLE bb_keys AS
SELECT song_id, name_id,
       match_key(title)      AS title_key,
       base_title(title)     AS title_base,
       match_key(performer)  AS performer_key,
       lead_key(performer)   AS lead_key
FROM bb_song_names;

------------------------------------------------------------------------------
-- 3. MusicBrainz recordings whose title matches a Billboard title (slowest step:
--    reads every recording once)
------------------------------------------------------------------------------
DROP TABLE IF EXISTS rec_title;
CREATE TABLE rec_title AS
WITH keyed AS (
    SELECT r.id AS recording, r.artist_credit, r.comment,
           match_key(r.name) AS title_key,
           base_title(r.name) AS title_base
    FROM recording r
    WHERE NOT r.video                                   -- music videos are separate recordings
)
SELECT *
FROM keyed
WHERE title_key  IN (SELECT title_key  FROM bb_keys)
   OR title_base IN (SELECT title_base FROM bb_keys);
CREATE INDEX ON rec_title (title_key);
CREATE INDEX ON rec_title (title_base);
CREATE INDEX ON rec_title (recording);

-- every way the artist of each candidate recording can be written
DROP TABLE IF EXISTS rec_artist_keys;
CREATE TABLE rec_artist_keys AS
SELECT DISTINCT rt.recording, k.akey
FROM rec_title rt
JOIN artist_credit ac ON ac.id = rt.artist_credit
LEFT JOIN artist_credit_name acn ON acn.artist_credit = ac.id
LEFT JOIN artist a ON a.id = acn.artist
CROSS JOIN LATERAL (VALUES (match_key(ac.name)), (lead_key(ac.name)),
                           (match_key(acn.name)), (match_key(a.name))) AS k(akey)
WHERE k.akey IS NOT NULL AND k.akey <> '';
CREATE INDEX ON rec_artist_keys (recording, akey);

------------------------------------------------------------------------------
-- 4. Matching: same title AND same artist; live/karaoke/instrumental/demo versions excluded
------------------------------------------------------------------------------
DROP TABLE IF EXISTS matches;
CREATE TABLE matches AS
SELECT DISTINCT b.song_id, rt.recording, 'exact title'::text AS match_method
FROM bb_keys b
JOIN rec_title rt ON rt.title_key = b.title_key
WHERE EXISTS (SELECT 1 FROM rec_artist_keys k
              WHERE k.recording = rt.recording AND k.akey IN (b.lead_key, b.performer_key))
  AND rt.comment !~* '\m(live|karaoke|instrumental|demo|a ?cappella)\M';

-- fallback, only for songs not matched above: titles compared without bracketed parts
INSERT INTO matches
SELECT DISTINCT b.song_id, rt.recording, 'title without brackets'
FROM bb_keys b
JOIN rec_title rt ON rt.title_base = b.title_base
WHERE b.song_id NOT IN (SELECT song_id FROM matches)
  AND b.title_base <> ''
  AND EXISTS (SELECT 1 FROM rec_artist_keys k
              WHERE k.recording = rt.recording AND k.akey IN (b.lead_key, b.performer_key))
  AND rt.comment !~* '\m(live|karaoke|instrumental|demo|a ?cappella)\M';
CREATE INDEX ON matches (recording);

------------------------------------------------------------------------------
-- 5. Release dates of every release containing a matched recording
------------------------------------------------------------------------------
SELECT id, name FROM release_status ORDER BY id;          -- check the status names used below

DROP TABLE IF EXISTS match_releases;
CREATE TABLE match_releases AS
SELECT DISTINCT m.song_id, m.recording, rel.id AS release, rg.id AS release_group,
       rg.artist_credit AS rg_artist_credit, rgt.name AS release_group_type,
       d.date_year AS y, d.date_month AS mo, d.date_day AS dd
FROM matches m
JOIN track t                 ON t.recording = m.recording
JOIN medium md               ON md.id = t.medium
JOIN release rel             ON rel.id = md.release
JOIN release_group rg        ON rg.id = rel.release_group
LEFT JOIN release_group_primary_type rgt ON rgt.id = rg.type
LEFT JOIN release_status rs  ON rs.id = rel.status
LEFT JOIN (SELECT release, date_year, date_month, date_day FROM release_country
           UNION ALL
           SELECT release, date_year, date_month, date_day FROM release_unknown_country) d
       ON d.release = rel.id
WHERE COALESCE(rs.name, '') NOT IN ('Bootleg', 'Pseudo-Release');

-- earliest dated release per song (earliest year, then month, then day; unknown parts last)
DROP TABLE IF EXISTS song_first_release;
CREATE TABLE song_first_release AS
SELECT DISTINCT ON (song_id)
       song_id, recording, release_group, release_group_type, y, mo, dd,
       CASE WHEN mo IS NOT NULL AND dd IS NOT NULL THEN 'day'
            WHEN mo IS NOT NULL THEN 'month'
            ELSE 'year' END AS date_precision
FROM match_releases
WHERE y IS NOT NULL
ORDER BY song_id, y, mo NULLS LAST, dd NULLS LAST, release;

------------------------------------------------------------------------------
-- 6. Genres: user tags that are official MusicBrainz genres, with positive votes.
--    Most specific level available: recording > release group (artist's own) > artist
------------------------------------------------------------------------------
DROP TABLE IF EXISTS song_genre_votes;
CREATE TABLE song_genre_votes AS
WITH genre_tags AS (
    SELECT t.id AS tag, t.name AS genre
    FROM tag t JOIN genre g ON lower(g.name) = lower(t.name)
),
rec_level AS (
    SELECT m.song_id, 1 AS level, gt.genre, SUM(rt.count) AS votes
    FROM matches m
    JOIN recording_tag rt ON rt.recording = m.recording AND rt.count > 0
    JOIN genre_tags gt    ON gt.tag = rt.tag
    GROUP BY m.song_id, gt.genre
),
own_release_groups AS (                       -- the artist's own releases, not compilations
    SELECT DISTINCT mr.song_id, mr.release_group
    FROM match_releases mr
    JOIN recording r ON r.id = mr.recording
    WHERE mr.rg_artist_credit = r.artist_credit
),
rg_level AS (
    SELECT o.song_id, 2 AS level, gt.genre, SUM(rgt.count) AS votes
    FROM own_release_groups o
    JOIN release_group_tag rgt ON rgt.release_group = o.release_group AND rgt.count > 0
    JOIN genre_tags gt         ON gt.tag = rgt.tag
    GROUP BY o.song_id, gt.genre
),
lead_artists AS (                             -- first credited artist of each matched recording
    SELECT DISTINCT m.song_id, acn.artist
    FROM matches m
    JOIN recording r ON r.id = m.recording
    JOIN artist_credit_name acn ON acn.artist_credit = r.artist_credit AND acn.position = 0
),
artist_level AS (
    SELECT la.song_id, 3 AS level, gt.genre, SUM(at.count) AS votes
    FROM lead_artists la
    JOIN artist_tag at  ON at.artist = la.artist AND at.count > 0
    JOIN genre_tags gt  ON gt.tag = at.tag
    GROUP BY la.song_id, gt.genre
)
SELECT * FROM rec_level
UNION ALL SELECT * FROM rg_level
UNION ALL SELECT * FROM artist_level;

DROP TABLE IF EXISTS song_genres;
CREATE TABLE song_genres AS
WITH best_level AS (
    SELECT song_id, MIN(level) AS level FROM song_genre_votes GROUP BY song_id
),
ranked AS (
    SELECT v.song_id, v.level, v.genre, v.votes,
           ROW_NUMBER() OVER (PARTITION BY v.song_id ORDER BY v.votes DESC, v.genre) AS rnk
    FROM song_genre_votes v
    JOIN best_level b ON b.song_id = v.song_id AND b.level = v.level
)
SELECT song_id,
       CASE MIN(level) WHEN 1 THEN 'recording' WHEN 2 THEN 'release group' ELSE 'artist' END AS genre_level,
       MAX(genre) FILTER (WHERE rnk = 1)                                   AS top_genre,
       string_agg(genre || ':' || votes, '|' ORDER BY rnk) FILTER (WHERE rnk <= 5) AS top_genres_votes
FROM ranked
GROUP BY song_id;

------------------------------------------------------------------------------
-- 7. One row per Billboard song (unmatched songs included, with empty fields)
------------------------------------------------------------------------------
DROP TABLE IF EXISTS song_musicbrainz;
CREATE TABLE song_musicbrainz AS
WITH songs AS (SELECT DISTINCT song_id FROM bb_song_names),
method AS (SELECT song_id, MIN(match_method) AS match_method, COUNT(DISTINCT recording) AS n_recordings
           FROM matches GROUP BY song_id)
SELECT s.song_id,
       COALESCE(me.match_method, 'no match')        AS match_method,
       COALESCE(me.n_recordings, 0)                 AS n_matched_recordings,
       r.gid                                        AS first_recording_mbid,
       r.name                                       AS mb_title,
       ac.name                                      AS mb_artist_credit,
       rg.gid                                       AS first_release_group_mbid,
       f.release_group_type                         AS first_release_type,
       f.y                                          AS first_release_year,
       NULLIF(CONCAT_WS('-', f.y::text, lpad(f.mo::text, 2, '0'),
                 CASE WHEN f.mo IS NOT NULL THEN lpad(f.dd::text, 2, '0') END), '') AS first_release_date,
       f.date_precision,
       g.genre_level,
       g.top_genre,
       g.top_genres_votes
FROM songs s
LEFT JOIN method me            ON me.song_id = s.song_id
LEFT JOIN song_first_release f ON f.song_id = s.song_id
LEFT JOIN recording r          ON r.id = f.recording
LEFT JOIN artist_credit ac     ON ac.id = r.artist_credit
LEFT JOIN release_group rg     ON rg.id = f.release_group
LEFT JOIN song_genres g        ON g.song_id = s.song_id;

-- summary
SELECT match_method, COUNT(*) AS songs,
       COUNT(first_release_year) AS with_release_date,
       COUNT(top_genre)          AS with_genre
FROM song_musicbrainz GROUP BY match_method ORDER BY match_method;