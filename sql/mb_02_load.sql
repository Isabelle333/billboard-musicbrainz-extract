-- mb_02_load.sql
-- Loads the dump files into the tables created by mb_01_schema.sql.
-- Run from the folder that CONTAINS the extracted "mbdump" folder (paths below are relative).
-- The dump files are in PostgreSQL's COPY text format (tab-separated, \N = missing),
-- which is the default format of \copy, so no format options are needed.
\set ON_ERROR_STOP 1
\timing on

-- core dump (mbdump.tar.bz2), CC0
\copy artist                     FROM 'mbdump/artist'
\copy artist_credit              FROM 'mbdump/artist_credit'
\copy artist_credit_name         FROM 'mbdump/artist_credit_name'
\copy recording                  FROM 'mbdump/recording'
\copy release_group              FROM 'mbdump/release_group'
\copy release_group_primary_type FROM 'mbdump/release_group_primary_type'
\copy release                    FROM 'mbdump/release'
\copy release_status             FROM 'mbdump/release_status'
\copy release_country            FROM 'mbdump/release_country'
\copy release_unknown_country    FROM 'mbdump/release_unknown_country'
\copy medium                     FROM 'mbdump/medium'
\copy track                      FROM 'mbdump/track'
\copy genre                      FROM 'mbdump/genre'

-- derived dump (mbdump-derived.tar.bz2), CC BY-NC-SA 3.0
\copy tag                        FROM 'mbdump/tag'
\copy recording_tag              FROM 'mbdump/recording_tag'
\copy release_group_tag          FROM 'mbdump/release_group_tag'
\copy artist_tag                 FROM 'mbdump/artist_tag'

-- row counts, to record in the provenance notes
SELECT 'artist' AS table_name, COUNT(*) AS rows FROM artist
UNION ALL SELECT 'artist_credit', COUNT(*) FROM artist_credit
UNION ALL SELECT 'artist_credit_name', COUNT(*) FROM artist_credit_name
UNION ALL SELECT 'recording', COUNT(*) FROM recording
UNION ALL SELECT 'release_group', COUNT(*) FROM release_group
UNION ALL SELECT 'release', COUNT(*) FROM release
UNION ALL SELECT 'release_country', COUNT(*) FROM release_country
UNION ALL SELECT 'release_unknown_country', COUNT(*) FROM release_unknown_country
UNION ALL SELECT 'medium', COUNT(*) FROM medium
UNION ALL SELECT 'track', COUNT(*) FROM track
UNION ALL SELECT 'genre', COUNT(*) FROM genre
UNION ALL SELECT 'tag', COUNT(*) FROM tag
UNION ALL SELECT 'recording_tag', COUNT(*) FROM recording_tag
UNION ALL SELECT 'release_group_tag', COUNT(*) FROM release_group_tag
UNION ALL SELECT 'artist_tag', COUNT(*) FROM artist_tag;