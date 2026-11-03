# MusicBrainz information for Billboard Hot 100 songs (2000–2025)

This repository contains our project submission for intermediary check in and peer review. 
Here, you can find Notebook and Database Extraction Scripts.
Also, please find decision log at the end.

## Notebook

Access it [here](https://github.com/Isabelle333/billboard-musicbrainz-extract/blob/main/data_project_billboard_group_c_v2.ipynb). It contains all the work, and also all the decision were documented there.

## Scripts
Output of the MusicBrainz steps of our ESSEC data project (Group C).

- **Job A:** for each song that reached the Billboard Hot 100 between 2000 and 2025 (identified by our own `song_id`), its MusicBrainz recording, first release date, first release type and genres.
- **Job B:** a comparison group of songs by the same lead artists that never reached the Hot 100, released 2000–2024, with the same information derived by the same rules; and the lead artist of each charting song.

## Files

**Job A**
- `musicbrainz_for_billboard_songs.csv` – one row per charting song (MusicBrainz data and our `song_id` only, no Billboard chart data)
- `musicbrainz_for_billboard_songs.sha256` – its SHA-256 fingerprint
- `run_all.sh`, `sql/mb_01` to `sql/mb_06` – the scripts that produced it (PostgreSQL)
- `provenance_musicbrainz.txt` – dump used, checksums, software version, run time
- `run_log.txt` – full output of the run

**Job B**
- `comparison_songs_musicbrainz.csv.gz` – one row per comparison song (compressed with `gzip -n`, so that the same data always gives the same file)
- `billboard_song_lead_artist.csv` – the MusicBrainz lead artist of each matched charting song
- `comparison_files.sha256` – SHA-256 fingerprints of both files
- `run_comparison.sh`, `sql/mb_07_comparison.sql`, `sql/mb_08_export_comparison.sql` – the scripts that produced them; they run in the database built by Job A
- `run_log_comparison.txt` – full output of the run, including how many recordings each rule removed

## Not included
- The MusicBrainz dump files (several GB; published by MetaBrainz, identified in `provenance_musicbrainz.txt`).
- The list of Billboard songs used for matching, because it is derived from Billboard chart data, which we do not redistribute.

## Source and licence
Data from **MusicBrainz** (https://musicbrainz.org), full export `20261017-002244`, published by the MetaBrainz Foundation.
- Core data (recordings, artists, releases): **CC0** (public domain).
- Genres are derived from MusicBrainz user tags: **CC BY-NC-SA 3.0** – attribution to MusicBrainz, non-commercial use, share-alike.

This repository is therefore published under the same terms for the genre information (CC BY-NC-SA 3.0), for non-commercial educational use.

## Reproducing
Run `run_all.sh` (Job A), then `run_comparison.sh` (Job B), on the same MusicBrainz export; the SHA-256 fingerprints of the outputs must match those recorded here. MusicBrainz publishes each full export for about two weeks only; re-running the scripts on a later export reproduces the method but may give slightly different results.

# Decision Log For Analysis
Every major decision in this project, the alternatives considered, and where it is justified.

| # | Decision | Alternatives considered | Main reason | Section |
|---|---|---|---|---|
| 1 | Billboard data from the UT Data archive, pinned to one commit and verified by SHA-256 | Collecting charts ourselves with billboard.py; other public datasets | Billboard.com's Terms of Use (§9) prohibit scraping; pinning makes the data reproducible | 1, 3 |
| 2 | Problems in the chart data flagged, not deleted (e.g. the 2018-01-06 chart) | Deleting or correcting affected rows | The correct values cannot be known; flags let each analysis decide | 4.7, 5 |
| 3 | Renamed chart entries linked into one song using Billboard's own last-week ranks | Exact names only; manual matching | Uses the source's own evidence; checked so that no song appears twice in a week | 5.10 |
| 4 | Storage in SQLite | CSV files, Parquet | Enforces keys and rules on our data; tested in 6.6–6.7 | 6 |
| 5 | MusicBrainz processed from the full official dump in a local PostgreSQL database | Processing in Colab | About 25 GB of tables, too large for Colab; only one row per song is imported | 8.2 |
| 6 | Dump of 17 October 2026 | Dump of 30 September 2026 | The earlier dump had already been removed from the server | 8.2 |
| 7 | Release dates on 1 January treated as known to the year only (M1) | Keeping them as exact dates | 236 such dates against about 29 expected: mostly placeholders | 8.7 |
| 8 | 218 genres grouped into 10 families by ordered keyword rules; unknown genres kept as "Other" | Keeping all genres; a hand-made list | Too many genres to compare; rules are transparent and the full mapping is saved | 8.7 |
| 9 | Every join declares its expected relationship and checks the row count | Unchecked joins | A duplicated key can silently multiply rows (Lecture 6) | 4.7, 5.10, 6.3, 8.7, 9, 10 |
| 10 | Time to chart counted in charts waited after the first possible chart | Days from release to first chart | Billboard's chart-dating rules changed in 2015 and 2018 | 9.1 |
| 11 | Every song followed for the same number of charts (52, or 260 for long-term results); releases up to December 2024 | Including all 2025 releases | Recent songs cannot yet show slow entries; including them would make recent years look faster | 9.2 |
| 12 | Comparison group: songs by charting lead artists, released 2000–2024, that never charted | Random songs released in the US market | Release countries exist in MusicBrainz, but many digital releases are only labelled "worldwide" and a random draw would be dominated by obscure releases; same-artist songs are realistic candidates and need only tables already loaded | 10, Job B |
| 13 | A comparison song = lead artist + title without brackets; songs sharing a title with any Billboard song, and intros/interludes/skits, excluded | Counting every recording; excluding only exact matches | Remixes and re-releases count once, as on the chart; no hidden hits or album fillers in the comparison group | 10.1, Job B (`mb_07`) |
| 14 | Same rules as Job A for release dates, release types and genres of comparison songs | Simpler rules for Job B | Both groups must be measured the same way to be comparable | 10.1, Job B (`mb_07`) |
| 15 | Genre, release-type and artist-history comparisons made within release periods, shares shown only for groups of 30+ songs | Overall comparisons only | The genre mix and release practices changed over time; small groups are too noisy | 9.5–9.7 |
| 16 | Problems in the comparison group cleaned in the notebook (K1–K5); the published extract is unchanged | Re-running `mb_07` with more exclusions | The raw extract stays exactly as produced and verified; every exclusion is visible, counted and justified | 10.5 |
| 17 | Artists that reached the chart only with songs released 5+ years earlier excluded from the comparison (K2) | Keeping all lead artists | Their 2000–2024 releases are mostly reissues of old catalogues, not new songs competing for the chart (same idea as M3) | 10.5 |
| 18 | Comparisons between charting and non-charting songs give each artist equal weight (artists with at least 10 songs) | Pooling all songs | The 20 largest catalogues hold 10.5% of comparison songs; a few prolific artists would otherwise dominate | 11 |
| 19 | Comparison group placed in its own section after the analysis of charting songs | Inside Section 8 (same source) | It is a separate population with its own collection, quality, cleaning and storage, and it answers the limitation found in 9.4 | 10 |
| 20 | MusicBrainz scripts and extracts published in a separate public repository | Keeping them only on a laptop; storing them in the group's project repository | The notebook must download the extracts from a public, fixed and verifiable location; the extract carries MusicBrainz's licence, unlike our own code | 8.3, 10.2 |
| 21 | Charting vs non-charting comparison limited to songs first released 2000–2023 | 2000–2024 as in Section 9 | 14% of comparison songs only have a release year, so the cut-off must be a whole year; 2023 gives every song at least two years to chart | 11.1 |
| 22 | Each category's chart rate compared with the same artist's own average | Comparing pooled shares; statistical models | Removes differences between artists (e.g. prolific vs occasional) in a simple, transparent way; no modelling, which the brief requires discussing with the instructor first | 11.3–11.4 |
