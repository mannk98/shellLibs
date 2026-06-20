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

# --- _backup_file ---

@test "_backup_file copies an existing file to a timestamped backup" {
  local f="${BATS_TEST_TMPDIR}/conf"
  printf 'original\n' > "$f"
  run _backup_file "$f"
  [ "$status" -eq 0 ]
  local baks=( "${f}".bak.* )
  [ "${#baks[@]}" -eq 1 ]
  [ "$(cat "${baks[0]}")" = "original" ]
}

@test "_backup_file is a no-op when the file does not exist" {
  run _backup_file "${BATS_TEST_TMPDIR}/absent"
  [ "$status" -eq 0 ]
  local baks=( "${BATS_TEST_TMPDIR}/absent".bak.* )
  [ ! -e "${baks[0]}" ]
}

@test "_backup_file in dry-run does not create a backup" {
  local f="${BATS_TEST_TMPDIR}/conf"
  printf 'x\n' > "$f"
  SHELLLIBS_DRYRUN=1 run _backup_file "$f"
  [ "$status" -eq 0 ]
  local baks=( "${f}".bak.* )
  [ ! -e "${baks[0]}" ]
}

@test "_backup_file with no argument returns 2" {
  run _backup_file
  [ "$status" -eq 2 ]
}

@test "_backup_file returns 0 and still backs up when LOG_LEVEL silences info" {
  local f="${BATS_TEST_TMPDIR}/conf"
  printf 'original\n' > "$f"
  LOG_LEVEL=2 run _backup_file "$f"
  [ "$status" -eq 0 ]
  local baks=( "${f}".bak.* )
  [ "${#baks[@]}" -eq 1 ]
}
