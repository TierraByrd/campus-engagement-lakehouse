# Schema Evolution: Version 1 to Version 2

## What changed

Starting in November 2024, the engagement table added one new column called `delivery_mode`. It tells you whether an event happened in person or virtually. The allowed values are `in_person` and `virtual`. The change is recorded in `lakehouse/metadata/engagement_table_v2.yaml`, and the version number went from 1 to 2.

The column is optional. That was on purpose. The v1 rules only allow adding optional columns, because removing, renaming, or changing the type of a column would break queries that already depend on it.

## How old and new files live together

The September and October files were written under version 1, so they only have the original six columns. The November file was written under version 2 and has seven. Nothing in the old files was rewritten. They stay exactly as they were loaded.

When a query reads all three months at once, DuckDB lines the columns up by name. Rows from September and October show `delivery_mode` as NULL, and rows from November show the real value. So one query can cover the whole table without anyone fixing the old data first. This is the same idea Delta Lake and Iceberg use. The table log tracks which schema version each file was written under, and the engine fills in missing columns at read time.

## Why this matters

If the team had just started dropping seven-column files into the folder with no metadata update, it would be hard to tell later whether a missing value meant the column didn't exist yet or someone forgot to fill it in. That kind of guessing is how a lake turns into a swamp. The version number and change log make it clear. Any NULL in `delivery_mode` before November means the column didn't exist yet, and the v2 rules say what's valid going forward.

## How to see it in the queries

Query 5 in `duckdb_queries/queries.sql` reads all three partitions together and counts how many rows have a `delivery_mode` value versus NULL in each month. September and October come back fully NULL and November comes back filled in.
