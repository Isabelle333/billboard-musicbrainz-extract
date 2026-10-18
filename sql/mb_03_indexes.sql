-- mb_03_indexes.sql
-- Primary keys and indexes needed to make the joins fast (the dump files come without them).
\set ON_ERROR_STOP 1
\timing on
SET maintenance_work_mem = '1GB';   -- more memory for building indexes (this session only)

ALTER TABLE artist                  ADD PRIMARY KEY (id);
ALTER TABLE artist_credit           ADD PRIMARY KEY (id);
ALTER TABLE artist_credit_name      ADD PRIMARY KEY (artist_credit, position);
ALTER TABLE recording               ADD PRIMARY KEY (id);
ALTER TABLE release_group           ADD PRIMARY KEY (id);
ALTER TABLE release                 ADD PRIMARY KEY (id);
ALTER TABLE medium                  ADD PRIMARY KEY (id);
ALTER TABLE track                   ADD PRIMARY KEY (id);
ALTER TABLE tag                     ADD PRIMARY KEY (id);

CREATE INDEX track_recording_idx        ON track (recording);
CREATE INDEX medium_release_idx         ON medium (release);
CREATE INDEX release_country_rel_idx    ON release_country (release);
CREATE INDEX release_unknown_rel_idx    ON release_unknown_country (release);
CREATE INDEX recording_tag_rec_idx      ON recording_tag (recording);
CREATE INDEX release_group_tag_rg_idx   ON release_group_tag (release_group);
CREATE INDEX artist_tag_artist_idx      ON artist_tag (artist);

ANALYZE;