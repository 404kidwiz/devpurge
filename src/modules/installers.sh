#!/usr/bin/env bash
set -eo pipefail
# DESC: Verified stale app installers (explicit only)

sweep_installers() {
  run_targeted_cleanup installers
}
