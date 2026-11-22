# Billboard Hot 100 and MusicBrainz: what determines whether a song reaches the chart? (Group C)

**Authors (Group C):** Thien Anh NGUYEN, Norelle CHY--GLASSCOCK, Lio SUCHET--WANG, Georg RIEKHAKAINEN, Isabelle LIEW YU CHEN

This repository holds the final notebook of our data project (Group C) and the MusicBrainz part of its workflow:
the PostgreSQL scripts we ran on the full MusicBrainz export, their results, and their run logs.

## Notebook

[`Data_Project_Billboard_Charts_Group_C.ipynb`](Data_Project_Billboard_Charts_Group_C.ipynb) contains the whole workflow, from collection to analysis,
with every decision and its justification (decision log at the top of the notebook).
The copy in this repository is published **without outputs**, because some outputs show sample rows of Billboard chart data, which we do not redistribute.

## How to run

**Python version:** 3.13 (tested in Google Colab and in a fresh local virtual environment).

**Option 1 – Google Colab (recommended, nothing to install):** open the notebook in Colab and use **Runtime → Run all**
(to start from scratch, first **Runtime → Disconnect and delete runtime**). Allow multiple downloads if the browser asks.

**Option 2 – on your own computer:**

    python3 -m venv .venv
    source .venv/bin/activate          # Windows (PowerShell): .venv\Scripts\Activate.ps1
    pip install -r requirements.txt
    jupyter notebook Data_Project_Billboard_Charts_Group_C.ipynb

Then use **Run → Run All Cells**. An internet connection is needed; a full run takes a few minutes. All files are written to an `outputs/` folder next to the notebook.

**Data:** nothing needs to be downloaded by hand. The notebook downloads the Billboard archive (UT Data, `utdata/rwd-billboard-data`)
and the MusicBrainz extracts of this repository at fixed commits, and checks each file against its SHA-256 fingerprint.
No password, API key or other setting is needed.

## MusicBrainz scripts and extracts

- **Job A:** for each song that reached the Billboard Hot 100 between 2000 and 2025 (identified by our own `song_id`), its MusicBrainz recording, first release date, first release type and genres.
- **Job B:** a comparison group of songs by the same lead artists that never reached the Hot 100, released 2000–2024, with the same information derived by the same rules; and the lead artist of each charting song.

The notebook downloads these files at fixed commits and checks their SHA-256 fingerprints (notebook Sections 8.3 and 10.2).

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

The three data files (`.csv`, `.csv.gz`) are in this repository but not in our submitted archive, because the notebook downloads them from here.

## Not included
- The MusicBrainz dump files (several GB; published by MetaBrainz, identified in `provenance_musicbrainz.txt`).
- Billboard chart data, including the list of Billboard songs used for matching (`billboard_song_names.csv`): the notebook downloads the chart data from its original public source and rebuilds this list (see Reproducing).

## Source and licence
Data from **MusicBrainz** (https://musicbrainz.org), full export `20261017-002244`, published by the MetaBrainz Foundation.
- Core data (recordings, artists, releases): **CC0** (public domain).
- Genres are derived from MusicBrainz user tags: **CC BY-NC-SA 3.0** – attribution to MusicBrainz, non-commercial use, share-alike.

The extracts in this repository are therefore published under the same terms for the genre information (CC BY-NC-SA 3.0), for non-commercial educational use.

## Reproducing

**Analysis only:** run the notebook as described in "How to run". It downloads the published Job A and Job B extracts, so stages 2–3 below are skipped.

The whole workflow runs in four stages, in this order. Some intermediate files are not in this repository because they contain
Billboard chart data, which we do not redistribute, or are too large; each one is rebuilt by the step that produces it.

### Intermediate files not included

| File | Produced by | Used by |
|---|---|---|
| `billboard_song_names.csv` (song_id, name_id, title, performer) | Notebook, Section 8.1 (downloaded automatically) | `sql/mb_04_billboard.sql` |
| `outputs/billboard_hot100.sqlite`, cleaned tables in `outputs/clean/` | Notebook, Sections 5–6 | Rest of the notebook |
| `mbdump/` folder (MusicBrainz tables, ~25 GB) | Download and extract `mbdump.tar.bz2` and `mbdump-derived.tar.bz2` from export `20261017-002244` (see `provenance_musicbrainz.txt`) | `sql/mb_02_load.sql` |

### Order of execution

1. **Notebook, Sections 1–8.1.** Downloads the pinned Billboard archive, checks its SHA-256, cleans it and stores it in SQLite.
   Section 8.1 exports `billboard_song_names.csv` and downloads it to your computer.
2. **Job A (local computer, PostgreSQL 18).** Put `billboard_song_names.csv` and the extracted `mbdump/` folder in this repository's folder,
   then run `bash run_all.sh 2>&1 | tee run_log.txt`. Output: `musicbrainz_for_billboard_songs.csv`.
   Its SHA-256 must match `musicbrainz_for_billboard_songs.sha256`.
3. **Job B (same database).** Run `bash run_comparison.sh 2>&1 | tee run_log_comparison.txt`.
   Outputs: `comparison_songs_musicbrainz.csv.gz` and `billboard_song_lead_artist.csv`. Their SHA-256 must match `comparison_files.sha256`.
4. **Notebook, Sections 8.3–13.** Downloads the Job A and Job B extracts from this repository at fixed commits, checks their SHA-256 and runs the analysis.

MusicBrainz keeps each full export online for about two weeks only. Running stages 2–3 on a later export reproduces the method,
but the results and fingerprints may differ slightly.

## Decisions
Every decision, the alternatives considered and the reasons are in the decision log at the top of the notebook.

## Running the workflow and how long it takes

- **Analysis (all results and figures in the report):** run the notebook top to bottom.
  - Colab: **Runtime → Run all**.
  - Locally: `pip install -r requirements.txt`, then
    `jupyter nbconvert --to notebook --execute Data_Project_Billboard_Charts_Group_C.ipynb --output executed.ipynb`
  - About 1–3 minutes, depending on the connection. Nothing needs to be done by hand: no account, API key or registration.
- **Building the MusicBrainz data (Jobs A and B, optional):** several hours on a laptop with PostgreSQL 18 and about 25 GB free.
  The MusicBrainz export we used (20261017-002244) is no longer on the MusicBrainz server; a newer export reproduces the method, with slightly different numbers.
  Our extracts are included in this archive and also downloaded by the notebook at fixed commits.
- **Billboard raw data is not included:** the Billboard.com Terms of Use do not allow redistributing chart data, so the notebook downloads it
  from the public UT Data archive (`utdata/rwd-billboard-data`, fixed commit) and checks its SHA-256.


  ## Where each result in the report comes from (to edit)

| In the report | Produced by (notebook section, figure file in `outputs/figures/`) |
|---|---|
| Data: 1,357 charts, 11,728 songs | Notebook 5.10–5.12 |
| MusicBrainz match rate (95.7%) | Notebook 8.3–8.6 |
| Comparison group (186,819 → 176,210 songs) | Notebook 10.1–10.5 |
| Storage choice (SQLite vs CSV vs Parquet) | Notebook 6.6–6.8 |
| 38% enter on first possible chart | Notebook 9.2, `9_2_cumulative_entry.png` |
| 5.5% of songs charted | Notebook 11.1 |
| Singles +11.3 points | Notebook 11.3, `11_3_release_type_within_artist.png` |
| Pop +12.1 points | Notebook 11.4, `11_4_genre_within_artist.png` |
| Chance to chart: 5.2% → 2.7% → 0.45% | Notebook 11.5, `11_5_chance_to_still_chart.png` |
| Robustness checks | Notebook 11.6 |
| Release month (exploratory) | Notebook 11.7, `11_7_singles_by_release_month.png` |
