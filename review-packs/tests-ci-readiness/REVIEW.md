# Review instructions: tests and CI readiness

## What Important means here

Mark a finding Important when a change ships behavior without a test that would catch it
breaking, weakens CI, or disables a test. Test naming and structure are Nit at most.

## Always check

- New API routes and public functions have at least one test that exercises them.
- Bug fixes include a regression test that fails without the fix.
- No test is skipped, deleted or marked expected-to-fail without a reason and a tracking link in the PR.
- Tests do not call real external services, paid APIs or production databases; they use fakes or recorded responses.
- Tests do not depend on wall clock, random seeds or ordering without pinning them.
- CI config changes do not remove required jobs, drop coverage thresholds or add `continue-on-error`/`|| true` to test steps.
- New environment variables used by the app are documented and set in CI.
- Database changes have a test that runs the migration.
- No `.only`, `fit`, `fdescribe` or focused tests are committed.

## Do not report

- Coverage percentage changes under one point.
- Snapshot files and generated test data.

## Evidence required

Each finding cites the changed code at `file:line` and, for a missing test, names the behavior
that has no test.
