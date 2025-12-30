# Why Your PostgreSQL Pagination Gets Slower on the Last Page

*Or: How we discovered that disk layout matters more than indexes*

---

Think of a database table as a warehouse. Packages arrive throughout the day and workers place them on the nearest available shelf. By evening, you have thousands of packages scattered across the building with no relationship between their labels and their physical locations.

Now imagine someone asks: "Give me all packages shipped on December 10th, sorted by tracking number."

You could build an index—a sorted list of tracking numbers pointing to shelf locations. Finding the *order* is instant. But retrieving the actual packages? Workers still zigzag across the warehouse, grabbing one package from aisle 3, another from aisle 47, another from aisle 12.

This is exactly how PostgreSQL stores data. And it's why our pagination queries were timing out.

---

## The Problem

We built an SEC filings tracker. Users browse companies sorted by their most recent filing date—the `latest_date` column. The table holds ~25,000 companies.

A simple query:

```sql
SELECT cik, name, latest_date, form_types, filing_count
FROM companies
ORDER BY latest_date DESC
LIMIT 50 OFFSET 25500;
```

Here's what we observed:

| Page | OFFSET | Response Time |
|------|--------|---------------|
| 1 | 0 | 12ms |
| 100 | 5000 | 45ms |
| 500 | 25000 | 3,200ms |

Page 1: instant. Page 500: over three seconds.

Users wanting to see the oldest companies—the last pages—faced timeouts. The degradation wasn't linear. It was exponential.

We had an index on `latest_date`. The query plan showed an index scan. What was going wrong?

---

## The Heap

PostgreSQL stores table data in what it calls a **heap**. This isn't the heap data structure from computer science (a priority queue). In PostgreSQL, "heap" simply means *unordered storage*.

When you INSERT a row, PostgreSQL places it in the first available slot. That slot might be at the end of the table, or it might be a gap left by a previously deleted row. The database doesn't care about logical ordering—it cares about efficient space utilization.

Consider what happens over months of operation:

1. Company A gets inserted → goes to page 10
2. Company B gets inserted → goes to page 11
3. Company A gets updated → stays on page 10, but now has a newer `latest_date`
4. Company C gets inserted → goes to page 847 (there was free space)
5. Company D gets inserted → goes to page 12

After thousands of these operations, rows with `latest_date = 2024-12-10` might live on pages 10, 847, 2341, and 156. Rows with `latest_date = 2019-03-15` might live on pages 11, 158, and 3002.

The physical arrangement on disk has nothing to do with the dates.

---

## How Indexes Actually Work

Let's clear up a common misconception. When people say "add an index to make queries faster," they often imagine the index *contains* the data. It doesn't.

A B-tree index is a separate structure that stores:
- The indexed column values (sorted)
- Pointers to where each row lives in the heap

Visualized:

```
INDEX (sorted by latest_date)          HEAP (unordered rows)
┌────────────────────────────┐         ┌─────────────────────────┐
│ 2024-12-10 → page 847      │         │ Page 10: [2019-03-15...] │
│ 2024-12-10 → page 2341     │         │ Page 11: [2023-07-22...] │
│ 2024-12-09 → page 156      │         │ Page 12: [2024-12-10...] │
│ 2024-12-09 → page 3892     │         │ ...                      │
│ 2024-12-08 → page 1203     │         │ Page 847: [2024-12-10...]│
└────────────────────────────┘         │ ...                      │
                                       └─────────────────────────┘
```

To execute `ORDER BY latest_date DESC LIMIT 50`:

1. PostgreSQL walks the index from the top (newest dates first)
2. For each entry, it follows the pointer to fetch the actual row from the heap
3. It repeats until it has 50 rows

Step 1 is fast—the index is sorted, so PostgreSQL reads sequential pages. Step 2 is where performance degrades.

---

## The Random I/O Problem

Let's think through what happens for different pages.

**Page 1 (OFFSET 0, LIMIT 50)**

PostgreSQL needs 50 rows. The index says: "fetch from pages 847, 2341, 156, 3892, 1203..."

That's 50 disk reads from scattered locations. On an SSD, each random read takes roughly 0.1-0.2ms. Total: 5-10ms. Acceptable.

**Page 500 (OFFSET 25500, LIMIT 50)**

PostgreSQL must skip 25,500 rows to reach the 50 it will return. But here's the crucial detail: it can't just skip index entries. It must *verify* each row still exists and passes any filters.

So PostgreSQL:
1. Walks the index to find 25,550 row pointers
2. Fetches all 25,550 rows from the heap
3. Discards the first 25,500
4. Returns the final 50

That's 25,550 random disk reads. Even at 0.1ms each, that's 2.5 seconds of I/O alone. Add CPU overhead, and we exceed 3 seconds.

**The killer insight:** Index scans are fast. Heap fetches with high OFFSET are slow. The index tells PostgreSQL *where* data lives, but if that data is scattered across thousands of pages, retrieval becomes a random I/O nightmare.

---

## Measuring the Chaos

PostgreSQL tracks how well physical row order matches index order. This metric is called **correlation**:

```sql
SELECT tablename, attname, correlation
FROM pg_stats
WHERE tablename = 'companies' AND attname = 'latest_date';
```

Our result: `-0.25`

What does correlation mean?

| Value | Meaning |
|-------|---------|
| 1.0 | Perfectly ordered (first row on disk = smallest value) |
| -1.0 | Perfectly reverse-ordered (first row on disk = largest value) |
| 0.0 | Completely random |

Our `-0.25` indicated near-random distribution with a slight reverse tendency. PostgreSQL couldn't predict where the next row would be, so it couldn't batch disk reads or use sequential I/O patterns.

---

## The Solution: CLUSTER

PostgreSQL provides a command that physically reorders table rows to match an index:

```sql
CLUSTER companies USING idx_companies_latest_date_covering;
```

What CLUSTER does:
1. Creates a new copy of the table
2. Inserts rows in index order
3. Drops the old table
4. Renames the new table
5. Rebuilds all indexes

It's essentially defragmentation. After CLUSTER, rows with `latest_date = 2024-12-10` sit adjacent to each other on disk. Rows with `latest_date = 2024-12-09` come right after.

**After clustering:**

```sql
SELECT correlation FROM pg_stats
WHERE tablename = 'companies' AND attname = 'latest_date';
```

New result: `-1.0`

Perfect reverse correlation. The newest dates are at the start of the table (physically), oldest at the end. This matches our `ORDER BY latest_date DESC` query pattern.

---

## The Performance Transformation

Post-clustering results:

| Page | OFFSET | Before | After |
|------|--------|--------|-------|
| 1 | 0 | 12ms | 8ms |
| 100 | 5000 | 45ms | 15ms |
| 500 | 25000 | 3,200ms | 52ms |

**Page 500: from 3.2 seconds to 52 milliseconds.** A 60x improvement.

Why such dramatic gains? When fetching rows for the last page, PostgreSQL now reads from contiguous disk locations. Instead of "fetch page 847, then 2341, then 156," it's "fetch pages 500, 501, 502, 503..."

Sequential I/O is fundamentally faster than random I/O:

| Operation | Typical SSD Speed |
|-----------|-------------------|
| Sequential read | 3-5 GB/s |
| Random read (4KB blocks) | 50-100 MB/s |

That's a 30-100x difference. Physical data layout matters enormously.

---

## The Maintenance Challenge

CLUSTER has a catch. From the PostgreSQL documentation:

> When a table is subsequently updated, the changes are not clustered.

Every INSERT places new rows wherever space exists—not in sorted order. Updates can move rows if they grow too large for their original slot. Within days or weeks, the table fragments again.

**Scenario 1: High-write OLTP system**

Imagine an e-commerce orders table receiving 1,000 inserts per minute. Clustering it nightly means:
- 23 hours of fragmented data
- Nightly maintenance window required
- Table locked during CLUSTER (could be minutes for large tables)

CLUSTER isn't practical here. You'd use partitioning, covering indexes, or accept the random I/O cost.

**Scenario 2: Daily batch updates**

Our SEC filings tracker receives data once daily. New filings arrive each morning, we update ~100-500 companies, then the table sits idle until the next day.

For this use case, CLUSTER is ideal. We run it after each daily update:

```sql
CREATE OR REPLACE FUNCTION refresh_company_aggregates(cik_list TEXT[] DEFAULT NULL)
RETURNS void AS $$
BEGIN
    -- Update aggregate columns (filing counts, form types, etc.)
    UPDATE companies c SET
        form_types = sub.form_types,
        filing_count = sub.filing_count
    FROM (
        SELECT cik, ARRAY_AGG(DISTINCT form_type) as form_types, COUNT(*) as filing_count
        FROM filings
        WHERE cik = ANY(cik_list) OR cik_list IS NULL
        GROUP BY cik
    ) sub
    WHERE c.cik = sub.cik;

    -- Re-cluster to maintain physical ordering
    CLUSTER companies USING idx_companies_latest_date_covering;
END;
$$ LANGUAGE plpgsql;
```

Since CLUSTER runs after each refresh, the table stays optimally ordered. Users always get consistent pagination performance.

---

## Bonus: Covering Indexes

We combined CLUSTER with a covering index:

```sql
CREATE INDEX idx_companies_latest_date_covering
ON companies (latest_date DESC)
INCLUDE (cik, name, form_types, filing_count, form_year_counts);
```

The `INCLUDE` clause adds columns to the index leaf pages without affecting the sort order. Now the index contains everything our pagination query needs.

When PostgreSQL can satisfy a query entirely from an index—without touching the heap—it performs an "index-only scan." This provides two optimization layers:

1. **Index-only scans** for queries selecting only indexed columns
2. **Sequential heap access** when heap fetches are needed (thanks to CLUSTER)

---

## Summary

PostgreSQL tables are heaps—unordered collections of rows stored wherever space permits. Indexes provide sorted access but only contain pointers, not data. Fetching actual rows requires heap access, and if rows are scattered, that means random I/O.

High OFFSET pagination forces PostgreSQL to fetch thousands of scattered rows just to skip them. This is why the last page is always slowest.

CLUSTER physically reorders table rows to match an index, transforming random I/O into sequential I/O. For tables with predictable access patterns and moderate write rates, it's a powerful optimization.

The commands:

```sql
-- Check current correlation
SELECT correlation FROM pg_stats
WHERE tablename = 'companies' AND attname = 'latest_date';

-- Cluster the table
CLUSTER companies USING idx_companies_latest_date_covering;

-- Verify improvement
ANALYZE companies;
SELECT correlation FROM pg_stats
WHERE tablename = 'companies' AND attname = 'latest_date';
```

---

*Sometimes the biggest performance wins don't come from smarter algorithms or better hardware. They come from understanding how bytes are arranged on disk.*
