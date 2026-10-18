-- mb_01_schema.sql
-- Creates ONLY the MusicBrainz tables we need, with column definitions copied
-- unchanged from the official schema (metabrainz/musicbrainz-server, admin/sql/CreateTables.sql).
-- Column order must match the dump files exactly, so do not edit these definitions.
\set ON_ERROR_STOP 1

CREATE TABLE artist ( -- replicate (verbose)
    id                  SERIAL,
    gid                 UUID NOT NULL,
    name                VARCHAR NOT NULL,
    sort_name           VARCHAR NOT NULL,
    begin_date_year     SMALLINT,
    begin_date_month    SMALLINT,
    begin_date_day      SMALLINT,
    end_date_year       SMALLINT,
    end_date_month      SMALLINT,
    end_date_day        SMALLINT,
    type                INTEGER, -- references artist_type.id
    area                INTEGER, -- references area.id
    gender              INTEGER, -- references gender.id
    comment             VARCHAR(255) NOT NULL DEFAULT '',
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ended               BOOLEAN NOT NULL DEFAULT FALSE
      CONSTRAINT artist_ended_check CHECK (
        (
          -- If any end date fields are not null, then ended must be true
          (end_date_year IS NOT NULL OR
           end_date_month IS NOT NULL OR
           end_date_day IS NOT NULL) AND
          ended = TRUE
        ) OR (
          -- Otherwise, all end date fields must be null
          (end_date_year IS NULL AND
           end_date_month IS NULL AND
           end_date_day IS NULL)
        )
      ),
    begin_area          INTEGER, -- references area.id
    end_area            INTEGER -- references area.id
);

CREATE TABLE artist_credit ( -- replicate
    id                  SERIAL,
    name                VARCHAR NOT NULL,
    artist_count        SMALLINT NOT NULL,
    ref_count           INTEGER DEFAULT 0,
    created             TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    gid                 UUID NOT NULL
);

CREATE TABLE artist_credit_name ( -- replicate (verbose)
    artist_credit       INTEGER NOT NULL, -- PK, references artist_credit.id CASCADE
    position            SMALLINT NOT NULL, -- PK
    artist              INTEGER NOT NULL, -- references artist.id CASCADE
    name                VARCHAR NOT NULL,
    join_phrase         TEXT NOT NULL DEFAULT ''
);

CREATE TABLE recording ( -- replicate (verbose)
    id                  SERIAL,
    gid                 UUID NOT NULL,
    name                VARCHAR NOT NULL,
    artist_credit       INTEGER NOT NULL, -- references artist_credit.id
    length              INTEGER CHECK (length IS NULL OR length > 0),
    comment             VARCHAR(255) NOT NULL DEFAULT '',
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    video               BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE track ( -- replicate (verbose)
    id                  SERIAL,
    gid                 UUID NOT NULL,
    recording           INTEGER NOT NULL, -- references recording.id
    medium              INTEGER NOT NULL, -- references medium.id
    position            INTEGER NOT NULL,
    number              TEXT NOT NULL,
    name                VARCHAR NOT NULL,
    artist_credit       INTEGER NOT NULL, -- references artist_credit.id
    length              INTEGER CHECK (length IS NULL OR length > 0),
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_data_track       BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE medium ( -- replicate (verbose)
    id                  SERIAL,
    release             INTEGER NOT NULL, -- references release.id
    position            INTEGER NOT NULL,
    format              INTEGER, -- references medium_format.id
    name                VARCHAR NOT NULL DEFAULT '',
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    track_count         INTEGER NOT NULL DEFAULT 0,
    gid                 UUID NOT NULL
);

CREATE TABLE release ( -- replicate (verbose)
    id                  SERIAL,
    gid                 UUID NOT NULL,
    name                VARCHAR NOT NULL,
    artist_credit       INTEGER NOT NULL, -- references artist_credit.id
    release_group       INTEGER NOT NULL, -- references release_group.id
    status              INTEGER, -- references release_status.id
    packaging           INTEGER, -- references release_packaging.id
    language            INTEGER, -- references language.id
    script              INTEGER, -- references script.id
    barcode             VARCHAR(255),
    comment             VARCHAR(255) NOT NULL DEFAULT '',
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    quality             SMALLINT NOT NULL DEFAULT -1,
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE release_group ( -- replicate (verbose)
    id                  SERIAL,
    gid                 UUID NOT NULL,
    name                VARCHAR NOT NULL,
    artist_credit       INTEGER NOT NULL, -- references artist_credit.id
    type                INTEGER, -- references release_group_primary_type.id
    comment             VARCHAR(255) NOT NULL DEFAULT '',
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >= 0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE release_group_primary_type ( -- replicate
    id                  SERIAL,
    name                VARCHAR(255) NOT NULL,
    parent              INTEGER, -- references release_group_primary_type.id
    child_order         INTEGER NOT NULL DEFAULT 0,
    description         TEXT,
    gid                 uuid NOT NULL
);

CREATE TABLE release_status ( -- replicate
    id                  SERIAL,
    name                VARCHAR(255) NOT NULL,
    parent              INTEGER, -- references release_status.id
    child_order         INTEGER NOT NULL DEFAULT 0,
    description         TEXT,
    gid                 uuid NOT NULL
);

CREATE TABLE release_country ( -- replicate (verbose)
  release INTEGER NOT NULL,  -- PK, references release.id
  country INTEGER NOT NULL,  -- PK, references country_area.area
  date_year SMALLINT,
  date_month SMALLINT,
  date_day SMALLINT
);

CREATE TABLE release_unknown_country ( -- replicate (verbose)
  release INTEGER NOT NULL,  -- PK, references release.id
  date_year SMALLINT,
  date_month SMALLINT,
  date_day SMALLINT
);

CREATE TABLE genre ( -- replicate (verbose)
    id                  SERIAL, -- PK
    gid                 UUID NOT NULL,
    name                VARCHAR NOT NULL,
    comment             VARCHAR(255) NOT NULL DEFAULT '',
    edits_pending       INTEGER NOT NULL DEFAULT 0 CHECK (edits_pending >=0),
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE tag ( -- replicate (verbose)
    id                  SERIAL,
    name                VARCHAR(255) NOT NULL,
    ref_count           INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE recording_tag ( -- replicate (verbose)
    recording           INTEGER NOT NULL, -- PK, references recording.id
    tag                 INTEGER NOT NULL, -- PK, references tag.id
    count               INTEGER NOT NULL,
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE release_group_tag ( -- replicate (verbose)
    release_group       INTEGER NOT NULL, -- PK, references release_group.id
    tag                 INTEGER NOT NULL, -- PK, references tag.id
    count               INTEGER NOT NULL,
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE artist_tag ( -- replicate (verbose)
    artist              INTEGER NOT NULL, -- PK, references artist.id
    tag                 INTEGER NOT NULL, -- PK, references tag.id
    count               INTEGER NOT NULL,
    last_updated        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);