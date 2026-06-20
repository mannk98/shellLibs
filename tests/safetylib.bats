#!/usr/bin/env bats
#
# Unit tests for scripts/safetylib — dry-run-aware execution + safe file edits.
# All tests operate on temp-dir fixtures, so no root is needed.

bats_require_minimum_version 1.5.0

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/safetylib"
}

# --- _run ---

@test "_run executes the command in normal mode" {
  run _run touch "${BATS_TEST_TMPDIR}/created"
  [ "$status" -eq 0 ]
  [ -e "${BATS_TEST_TMPDIR}/created" ]
}

@test "_run in dry-run mode does NOT execute the command" {
  SHELLLIBS_DRYRUN=1 run _run touch "${BATS_TEST_TMPDIR}/nope"
  [ "$status" -eq 0 ]
  [ ! -e "${BATS_TEST_TMPDIR}/nope" ]
  [[ "$output" == *"DRY-RUN"* ]]
}

@test "_run returns the command's own exit status" {
  run _run false
  [ "$status" -eq 1 ]
}

@test "_run with no command returns 2" {
  run _run
  [ "$status" -eq 2 ]
}
