# Billboard Hot 100 and MusicBrainz: what determines whether a song reaches the chart? (Group C)

**Authors (Group C):** Thien Anh NGUYEN, Norelle CHY--GLASSCOCK, Lio SUCHET--WANG, Georg RIEKHAKAINEN, Isabelle LIEW YU CHEN

**Repository:** https://github.com/Isabelle333/billboard-musicbrainz-extract

This repository holds the final notebook of our data project (Group C) and the MusicBrainz part of its workflow:
the PostgreSQL scripts we ran on the full MusicBrainz export, their results, and their run logs.

This project is not affiliated with, endorsed by or sponsored by Billboard or the MetaBrainz Foundation.

## Notebook

[`Data_Project_Billboard_Charts_Group_C.ipynb`](Data_Project_Billboard_Charts_Group_C.ipynb) contains the whole workflow, from collection to analysis,
with every decision and its justification (decision log at the top of the notebook).
The copy in this repository is published **without outputs**, because some outputs show sample rows of Billboard chart data, which we do not redistribute.

## How to run (all results and figures in the report)

**Python version:** 3.13 (tested in a fresh local virtual environment); the notebook also runs in Google Colab.

**Option 1 – Google Colab (nothing to install):** open the notebook in Colab and use **Runtime → Run all**
(to start from scratch, first **Runtime → Disconnect and delete runtime**). Allow multiple downloads if the browser asks.

**Option 2 – on your own computer, one command:**

    python3 -m venv .venv
    source .venv/bin/activate          # Windows (PowerShell): .venv\Scripts\Activate.ps1
    pip install -r requirements.txt
    jupyter nbconvert --to notebook --execute --ExecutePreprocessor.timeout=1200 --output executed.ipynb Data_Project_Billboard_Charts_Group_C.ipynb

Or open the notebook with `jupyter notebook Data_Project_Billboard_Charts_Group_C.ipynb` and use **Run → Run All Cells**.

**How long it takes:** about 1–3 minutes depending on the connection (78 seconds in our local test). An internet connection is needed.

**Where the results are:** all files are written to an `outputs/` folder next to the notebook (figures in `outputs/figures/`).
In Colab, this folder is shown in the **Files** panel (folder icon in the left sidebar) and is deleted when the runtime ends;
the notebook also downloads its records and figures to your computer automatically.
The run ends with final checks (Section 12.3) that stop it if any result is wrong.

## What has to be done by hand

**To reproduce the results of the report: nothing.** No account, API key, password or registration is needed.
The notebook downloads the Billboard archive and the MusicBrainz extracts at fixed commits and checks each file against its SHA-256 fingerprint.

**Billboard raw data is not included:** the Billboard.com Terms of Use do not allow redistributing chart data, so the notebook downloads it
from the public UT Data archive (`utdata/rwd-billboard-data`, fixed commit) and checks its SHA-256 (Sections 1 and 3).

**Only to rebuild the MusicBrainz extracts (Jobs A and B, optional):**
1. Install PostgreSQL 18; about 25 GB of free disk space is needed.
2. Download `mbdump.tar.bz2` and `mbdump-derived.tar.bz2` from a MusicBrainz full export (https://data.metabrainz.org/pub/musicbrainz/data/fullexport/) and extract them into a `mbdump/` folder in this folder.
   The export we used, `20261017-002244`, is no longer on the server (MusicBrainz keeps each export for about two weeks); a newer export reproduces the method, with slightly different numbers and fingerprints.
3. Move `billboard_song_names.csv`, written by the notebook in Section 8.1, into this folder.
4. Run the jobs in the order given under "Reproducing".

**Checks done by hand:** 30 random MusicBrainz matches (Section 8.4d) and 30 random comparison songs (Section 10.5). The notebook draws the same samples every time (fixed seed) and records our verdicts.

## MusicBrainz scripts and extracts

- **Job A:** for each song that reached the Billboard Hot 100 between 2000 and 2025 (identified by our own `song_id`), its MusicBrainz recording, first release date, first release type and genres.
- **Job B:** a comparison group of songs by the same lead artists that never reached the Hot 100, released 2000–2024, with the same information derived by the same rules; and the lead artist of each charting song.

The notebook downloads these files at fixed commits and checks their SHA-256 fingerprints (notebook Sections 8.3 and 10.2).

## Coverage periods

The two groups of songs do not cover exactly the same years:

| Group | Period | What the period refers to |
|---|---|---|
| Charting songs (Job A) | 2000–2025 | Chart dates: songs that appeared on at least one of the 1,357 weekly Hot 100 charts of 2000–2025 |
| Comparison songs (Job B) | 2000–2024 | Release dates: songs by the same lead artists that never reached the Hot 100 |

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

**Other**
- `requirements.txt` – Python packages used by the notebook

The three data files (`.csv`, `.csv.gz`) are included in this repository and in our submitted archive; the notebook downloads the same files from this repository at fixed commits and checks their fingerprints.

## Not included
- The MusicBrainz dump files (about 25 GB; published by MetaBrainz, identified in `provenance_musicbrainz.txt`).
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
| `billboard_song_names.csv` (song_id, name_id, title, performer) | Notebook, Section 8.1 (written to `outputs/`; in Colab also downloaded automatically) | `sql/mb_04_billboard.sql` |
| `outputs/billboard_hot100.sqlite`, cleaned tables in `outputs/clean/` | Notebook, Sections 5–6 | Rest of the notebook |
| `mbdump/` folder (MusicBrainz tables, ~25 GB) | Download and extract `mbdump.tar.bz2` and `mbdump-derived.tar.bz2` from a MusicBrainz full export (see "What has to be done by hand") | `sql/mb_02_load.sql` |

### Order of execution

1. **Notebook, Sections 1–8.1.** Downloads the pinned Billboard archive, checks its SHA-256, cleans it and stores it in SQLite.
   Section 8.1 writes `billboard_song_names.csv`.
2. **Job A (local computer, PostgreSQL 18; about 15 minutes, plus downloading and extracting the dump).** Put `billboard_song_names.csv` and the extracted `mbdump/` folder in this repository's folder,
   then run `bash run_all.sh 2>&1 | tee run_log.txt`. Output: `musicbrainz_for_billboard_songs.csv`.
   On the export we used, its SHA-256 matches `musicbrainz_for_billboard_songs.sha256`.
3. **Job B (same database; about 2 minutes).** Run `bash run_comparison.sh 2>&1 | tee run_log_comparison.txt`.
   Outputs: `comparison_songs_musicbrainz.csv.gz` and `billboard_song_lead_artist.csv`. On the export we used, their SHA-256 match `comparison_files.sha256`.
4. **Notebook, Sections 8.3–13.** Downloads the Job A and Job B extracts from this repository at fixed commits, checks their SHA-256 and runs the analysis.

Run times of Jobs A and B are taken from `run_log.txt` and `run_log_comparison.txt`.

## Where each result in the report comes from

Figure files are in `outputs/figures/`.

| In the report | Produced by |
|---|---|
| Figure 1: median weeks by entry position and era | Notebook 7.7, `fig6_entry_position_longevity_by_era.png` |
| Figure 2: Figure 2: chance that a song will still chart | Notebook 11.5, `11_5_chance_to_still_chart.png` |
| Figure 3a: release type | Notebook 11.3, `11_3_release_type_within_artist.png` |
| Figure 3b: genre | Notebook 11.4, `11_4_genre_within_artist.png` |
| 1,357 charts, 135,700 rows | Notebook 3.7, 4.5 |
| 11,728 songs after cleaning (34 renamed entries linked) | Notebook 5.16 |
| Storage table (CSV vs Parquet vs SQLite) | Notebook 6.6–6.8 |
| MusicBrainz match: 95.7% matched, 30/30 correct, 504 unmatched | Notebook 8.4a, 8.4d, 8.4e; Job A (`sql/mb_05_match.sql`) |
| Release-date flags (M1–M3), genre families and ties | Notebook 8.4, 8.7 |
| Comparison group: 186,819 → 176,210 songs; 30 songs checked by hand | Notebook 10.1–10.5; Job B (`sql/mb_07_comparison.sql`) |
| 5.5% of 178,338 songs charted | Notebook 11.1 |
| Time to chart: 38% on first possible chart, 54% within four, 92% within a year | Notebook 9.2, `9_2_cumulative_entry.png` |
| Entry on first possible chart: 14% → 70% | Notebook 9.3, `9_3_speed_by_release_year.png` |
| Artist popularity: 74.5% of entries by credits that had charted before | Notebook 7.5, 9.7 |
| Release month (exploratory) | Notebook 11.7, `11_7_singles_by_release_month.png` |
| Robustness checks (worst case 4.2%, singles-only time to chart) | Notebook 11.6 |
| 15 final checks | Notebook 12.3 |

## Requirements and tested systems

- **Python:** 3.13, with the packages in `requirements.txt`.
- **Notebook run (analysis only):** an internet connection; the full run took 78 seconds in our local test.
- **MusicBrainz jobs (optional):** PostgreSQL 18 and about 25 GB of free disk space.

## Decisions

Every decision, the alternatives considered and the reasons are in the decision log at the top of the notebook.

## AI use

We used AI assistants to help write and debug code and to check and edit our text. Every choice was made and checked by the group, and every number comes from running the notebook.

## How to cite

If you use this repository, please cite it as:

> Nguyen, T. A., Chy--Glasscock, N., Suchet--Wang, L., Riekhakainen, G., & Liew Yu Chen, I. (2026). *Billboard Hot 100 and MusicBrainz: what determines whether a song reaches the chart? (Group C)* [Data project]. https://github.com/Isabelle333/billboard-musicbrainz-extract

Please also credit the data sources: **MusicBrainz** (https://musicbrainz.org, MetaBrainz Foundation; see "Source and licence" for the licence terms) and the **UT Data archive** `utdata/rwd-billboard-data` for the Billboard chart data.
