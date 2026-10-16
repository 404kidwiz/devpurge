# Review instructions: database indexes and migrations

## What Important means here

Mark a finding Important when a change can lock or slow a production table, lose data, or
block a rollback: a migration that is not backward compatible, a destructive change without
a backfill, or a new hot query with no supporting index. Schema naming is Nit at most.

## Always check

- New queries that filter, join or sort on a column have an index that covers it, or the PR explains why not (small table, existing composite index).
- New foreign key columns are indexed.
- Index creation on existing tables is non-blocking (`CREATE INDEX CONCURRENTLY` in Postgres, `ALGORITHM=INPLACE, LOCK=NONE` in MySQL) or the PR states the table size.
- Migrations are backward compatible with the previous app version: add column, deploy, backfill, then drop or rename in a later release. Flag a rename or drop in the same release as the code that stops using it.
- Adding a NOT NULL column to an existing table supplies a default or a backfill step.
- Every migration has a working down/rollback, or the PR says it is irreversible and why.
- Data backfills run in batches, not one unbounded UPDATE or DELETE.
- No N+1 queries in loops over request data; flag a query inside a loop over results.
- Queries built from user input use parameters, never string concatenation.
- Multi-tenant queries are scoped by tenant or account id.

## Do not report

- Generated migration snapshots and ORM schema dumps.
- Seed data and test-only fixtures.

## Evidence required

Each finding cites the migration or query at `file:line`. For a missing index, name the table,
the column and the query that needs it.
