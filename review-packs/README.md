# DevPurge review packs for Claude Code Review

Four `REVIEW.md` rule packs that make Claude Code Review check production readiness on
every pull request:

| Pack | Checks |
| --- | --- |
| `auth-mfa` | MFA on login, recovery and admin paths, authorization scoping, password hashing, token expiry and invalidation, rate limits, secrets in code |
| `db-indexes-migrations` | indexes for new queries and foreign keys, non-blocking index builds, backward-compatible migrations, rollbacks, batched backfills, N+1 queries |
| `compliance-pii-logging` | PII in logs and errors, analytics consent, new third parties, card data, deletion/export coverage, retention |
| `tests-ci-readiness` | tests for new routes and fixes, skipped or focused tests, real network calls in tests, weakened CI steps |

## How Code Review uses REVIEW.md

From Anthropic's docs ([Customize Code Review](https://code.claude.com/docs/en/code-review-customize),
[Code Review](https://code.claude.com/docs/en/code-review)):

- `REVIEW.md` at the repository root is given to the agents that find and verify findings, and is
  consulted when severity is set and the summary is written. A `REVIEW.md` in a subdirectory adds
  checks for changes under that path.
- It is read from the pull request's base branch or the default branch, never from the pull request
  itself, so merge it before you expect it to apply. Protect the default branch; without protection
  only the root file is read, and if protection can't be confirmed none is read
  ([Troubleshoot](https://code.claude.com/docs/en/code-review-troubleshooting)).
- The text is read as-is: `@` imports are not expanded. That is why each pack is one self-contained file.
- The local `/code-review` command reads `CLAUDE.md`, not `REVIEW.md`.
- Code Review is available to Team and Enterprise organizations once an Owner turns it on
  ([Set up Code Review](https://code.claude.com/docs/en/code-review-setup)).

## Install

Use one pack as the root file:

    cp review-packs/auth-mfa/REVIEW.md /path/to/your-repo/REVIEW.md

To combine packs, paste the `## Always check` rules of each into one root `REVIEW.md`, keep one
`What Important means here` section, or put a pack in the subdirectory it applies to
(for example `db/REVIEW.md`). Merge to your default branch, then open a pull request to test it.

## Check the format

    python3 review-packs/validate.py

Each pack must start with `# Review instructions`, have the four sections, list at least five
rules under `Always check`, and contain no `@` imports.

## Pricing idea (not live)

- One pack: $29. All four: $49. Buyers get updates to the rules.
- Upsell: a paid audit where we run the packs against a repo's recent pull requests, tune severity
  and exclusions for that codebase, and hand back a custom `REVIEW.md`.

Nothing here is listed or sold yet.
