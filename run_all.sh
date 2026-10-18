#!/bin/bash
# run_all.sh - builds the MusicBrainz database and produces musicbrainz_for_billboard_songs.csv
# Usage (from the project folder):  bash run_all.sh
set -euo pipefail                      # stop at the first error
DB=musicbrainz_2026_10_17              # database name records the dump date
cd "$(dirname "$0")"                   # run from the project folder, whatever the current folder

createdb "$DB" 2>/dev/null || echo "Database $DB already exists - reusing it"

run () { echo "=== $1"; psql -d "$DB" -v ON_ERROR_STOP=1 -f "sql/$1"; }

if [ "${SKIP_LOAD:-0}" != "1" ]; then  # SKIP_LOAD=1 bash run_all.sh  -> only redo the matching
  run mb_01_schema.sql
  run mb_02_load.sql
  run mb_03_indexes.sql
fi
run mb_04_billboard.sql
run mb_05_match.sql
run mb_06_export.sql
shasum -a 256 musicbrainz_for_billboard_songs.csv | tee musicbrainz_for_billboard_songs.sha256
echo "Done."