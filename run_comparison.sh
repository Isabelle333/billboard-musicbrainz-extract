#!/bin/bash
# run_comparison.sh - builds the comparison group (Job B) in the database created by run_all.sh
# Usage (from the project folder):  bash run_comparison.sh 2>&1 | tee run_log_comparison.txt
set -euo pipefail                      # stop at the first error
DB=musicbrainz_2026_10_17              # the same database as Job A
cd "$(dirname "$0")"                   # run from the project folder, whatever the current folder

run () { echo "=== $1"; psql -d "$DB" -v ON_ERROR_STOP=1 -f "sql/$1"; }

run mb_07_comparison.sql
run mb_08_export_comparison.sql
gzip -n -9 -f comparison_songs_musicbrainz.csv   # -n: no name/time stamp, so the file is reproducible
shasum -a 256 comparison_songs_musicbrainz.csv.gz billboard_song_lead_artist.csv | tee comparison_files.sha256
echo "Done."