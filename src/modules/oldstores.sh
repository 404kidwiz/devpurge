#!/usr/bin/env bash
set -eo pipefail
# DESC: Older pnpm stores via matching installed pnpm (explicit only)

sweep_oldstores() {
  run_targeted_cleanup oldstores
}
