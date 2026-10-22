-- Week 7 mini lakehouse queries
-- Run from the project root: duckdb < duckdb_queries/queries.sql

-- The engagement view reads every partition as one table.
-- hive_partitioning turns the folder names (year=2024/month=09) into year and month columns.
-- union_by_name lines up columns by name, so v1 files (6 columns) and v2 files (7 columns) read together.
CREATE OR REPLACE VIEW engagement AS
SELECT *
FROM read_csv(
    'lakehouse/engagement/*/*/*.csv',
    hive_partitioning = true,
    hive_types = {'year': INTEGER, 'month': INTEGER},
    union_by_name = true
);

-- Query 1: Partition pruning by path
-- Reads only the September folder. October and November files are never opened.
SELECT 'Query 1: September events by type (only month=09 folder read)' AS query;
SELECT event_type, COUNT(*) AS events
FROM read_csv('lakehouse/engagement/year=2024/month=09/*.csv')
GROUP BY event_type
ORDER BY events DESC;

-- Query 2: Partition pruning by filter
-- Uses the full table, but the WHERE clause on the partition columns lets DuckDB skip the other folders.
-- The EXPLAIN shows the partition filter being applied when the files are scanned.
SELECT 'Query 2: October only, filtered on partition columns' AS query;
SELECT year, month, COUNT(*) AS events, SUM(duration_minutes) AS total_minutes
FROM engagement
WHERE year = 2024 AND month = 10
GROUP BY year, month;

EXPLAIN
SELECT COUNT(*)
FROM engagement
WHERE year = 2024 AND month = 10;

-- Query 3: Aggregation across all partitions
-- OLAP-style summary: events and average time per month.
SELECT 'Query 3: Monthly totals and averages across all partitions' AS query;
SELECT
    year,
    month,
    COUNT(*) AS events,
    COUNT(DISTINCT student_id) AS unique_students,
    ROUND(AVG(duration_minutes), 1) AS avg_minutes
FROM engagement
GROUP BY year, month
ORDER BY year, month;

-- Query 4: Filtering by event_type and campus
-- Tutoring visits on the St. Paul campus, by month.
SELECT 'Query 4: St. Paul tutoring visits by month' AS query;
SELECT
    month,
    COUNT(*) AS tutoring_visits,
    ROUND(AVG(duration_minutes), 1) AS avg_minutes
FROM engagement
WHERE event_type = 'tutoring' AND campus = 'St. Paul'
GROUP BY month
ORDER BY month;

-- Query 5: Handling the evolved column
-- delivery_mode only exists in v2 files (November).
-- Sep and Oct rows should come back as NULL, showing old and new files coexisting.
SELECT 'Query 5: delivery_mode filled vs NULL per month (schema evolution)' AS query;
SELECT
    month,
    COUNT(*) AS total_rows,
    COUNT(delivery_mode) AS rows_with_delivery_mode,
    COUNT(*) - COUNT(delivery_mode) AS rows_null_delivery_mode
FROM engagement
GROUP BY month
ORDER BY month;

-- Query 6: Evolved column with a safe default
-- COALESCE labels older rows instead of showing blanks, so a report still makes sense.
SELECT 'Query 6: Events by delivery mode, older rows labeled not_tracked' AS query;
SELECT
    COALESCE(delivery_mode, 'not_tracked') AS delivery_mode,
    COUNT(*) AS events
FROM engagement
GROUP BY 1
ORDER BY events DESC;

-- Query 7: Combining partitions to follow students over time
-- Students who showed up in more than one month.
SELECT 'Query 7: Students with activity in more than one month' AS query;
SELECT
    student_id,
    COUNT(DISTINCT month) AS months_active,
    COUNT(*) AS total_events
FROM engagement
GROUP BY student_id
HAVING COUNT(DISTINCT month) > 1
ORDER BY months_active DESC, total_events DESC, student_id;
