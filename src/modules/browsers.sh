#!/usr/bin/env bash
set -eo pipefail
# DESC: Inactive browser web caches (explicit only)

sweep_browsers() {
  run_targeted_cleanup browsers
}
