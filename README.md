# Campus Engagement Lakehouse

A small lakehouse simulation built with partitioned CSV files, YAML table metadata, and DuckDB. It stores student engagement events (workshops, tutoring visits, and LMS activity) for September through November 2024 and shows partition pruning, schema enforcement rules, and schema evolution.

## Project structure

```
lakehouse/
  engagement/
    year=2024/month=09/engagement_2024_09.csv
    year=2024/month=10/engagement_2024_10.csv
    year=2024/month=11/engagement_2024_11.csv
  metadata/
    engagement_table.yaml       # v1 table spec
    engagement_table_v2.yaml    # v2 table spec (adds delivery_mode)
duckdb_queries/
  queries.sql                   # 7 lakehouse queries
  query_results.txt             # saved output from running queries.sql
schema_evolution.md
lakehouse_reflection.md
README.md
```

Each month is its own partition folder using Hive-style naming (year=YYYY/month=MM). The year and month values come from the folder path and are not stored inside the files. Each file has 12 events.

## Metadata and schema evolution

`engagement_table.yaml` is the version 1 table spec. It lists every column with its type and whether it's required, the allowed values for event_type and campus, the partition keys, the enforcement rules a file has to pass, and what kinds of schema changes are allowed. It works like a simplified version of the metadata a Delta Lake or Iceberg table keeps in its log.

`engagement_table_v2.yaml` is version 2. Starting with the November partition, it adds an optional column called delivery_mode (in_person or virtual). The September and October files were not rewritten. When DuckDB reads all three months together, older rows show delivery_mode as NULL. `schema_evolution.md` explains this in more detail.

## How to run the queries

You need the DuckDB CLI installed. From the project root, run:

```
duckdb < duckdb_queries/queries.sql
```

To save the output the same way it was saved for this repo:

```
duckdb < duckdb_queries/queries.sql | tee duckdb_queries/query_results.txt
```

The script creates a view called engagement that reads every partition at once with `hive_partitioning = true` (turns folder names into columns) and `union_by_name = true` (lines up v1 and v2 files by column name).

## What to look for in the results

All results are saved in `duckdb_queries/query_results.txt`.

- **Query 1** reads only the month=09 folder directly. Each event type shows 4 events.
- **Query 2** filters on year and month. The EXPLAIN plan under it shows `File Filters: (month = 10)` and `Scanning Files: 1/3`, which proves DuckDB skipped the September and November files. This is partition pruning.
- **Query 3** summarizes every partition: 12 events per month, unique students, and average minutes.
- **Query 4** filters to tutoring visits at the St. Paul campus by month.
- **Query 5** shows schema evolution. Months 9 and 10 have 0 rows with delivery_mode and 12 NULL. Month 11 has all 12 filled in.
- **Query 6** labels pre-v2 rows as not_tracked using COALESCE, so a report doesn't show blanks.
- **Query 7** combines partitions to find students active in more than one month.

## AI assistance

AI Assistance: I used Claude to help break down the weekly readings and better understand the core lakehouse concepts. It was helpful for brainstorming realistic columns for the student dataset and checking the DuckDB syntax for querying folder paths. git add lakehouse_reflection.md README.md