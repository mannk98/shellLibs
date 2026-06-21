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

# --- _append_line ---

@test "_append_line appends a line when absent" {
  local f="${BATS_TEST_TMPDIR}/fstab"
  printf 'existing\n' > "$f"
  run _append_line "$f" "newline"
  [ "$status" -eq 0 ]
  grep -qxF "newline" "$f"
}

@test "_append_line is idempotent (no duplicate on second call)" {
  local f="${BATS_TEST_TMPDIR}/fstab"
  printf 'existing\n' > "$f"
  _append_line "$f" "dup"
  _append_line "$f" "dup"
  run grep -cxF "dup" "$f"
  [ "$output" -eq 1 ]
}

@test "_append_line in dry-run does not modify the file" {
  local f="${BATS_TEST_TMPDIR}/fstab"
  printf 'existing\n' > "$f"
  SHELLLIBS_DRYRUN=1 run _append_line "$f" "nope"
  [ "$status" -eq 0 ]
  run grep -qxF "nope" "$f"
  [ "$status" -ne 0 ]
}

@test "_append_line backs up the file before appending" {
  local f="${BATS_TEST_TMPDIR}/fstab"
  printf 'existing\n' > "$f"
  _append_line "$f" "added"
  local baks=( "${f}".bak.* )
  [ "${#baks[@]}" -eq 1 ]
}

@test "_append_line with missing args returns 2" {
  run _append_line "${BATS_TEST_TMPDIR}/x"
  [ "$status" -eq 2 ]
}

# --- _write_file ---

@test "_write_file writes stdin content to the file" {
  local f="${BATS_TEST_TMPDIR}/out"
  run _write_file "$f" <<< "hello content"
  [ "$status" -eq 0 ]
  [ "$(cat "$f")" = "hello content" ]
}

@test "_write_file in dry-run does not create the file" {
  local f="${BATS_TEST_TMPDIR}/out"
  SHELLLIBS_DRYRUN=1 run _write_file "$f" <<< "nope"
  [ "$status" -eq 0 ]
  [ ! -e "$f" ]
  [[ "$output" == *"nope"* ]]
}

@test "_write_file backs up an existing file before overwriting" {
  local f="${BATS_TEST_TMPDIR}/out"
  printf 'old\n' > "$f"
  _write_file "$f" <<< "new"
  local baks=( "${f}".bak.* )
  [ "${#baks[@]}" -eq 1 ]
  [ "$(cat "${baks[0]}")" = "old" ]
  [ "$(cat "$f")" = "new" ]
}

@test "_write_file with no argument returns 2" {
  run _write_file <<< "x"
  [ "$status" -eq 2 ]
}

# --- _confirm ---

@test "_confirm in dry-run passes without prompting" {
  SHELLLIBS_DRYRUN=1 run _confirm "do thing?"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would ask"* ]]
}

@test "_confirm with SHELLLIBS_ASSUME_YES passes without prompting" {
  SHELLLIBS_ASSUME_YES=1 run _confirm "do thing?"
  [ "$status" -eq 0 ]
}

@test "_confirm with no TTY and no ASSUME_YES refuses (returns 1)" {
  run _confirm "do thing?"
  [ "$status" -eq 1 ]
  [[ "$output" == *"refused"* ]]
}

# --- _need_root ---

@test "_need_root succeeds for root (mocked id)" {
  id() { echo 0; }
  run _need_root
  [ "$status" -eq 0 ]
}

@test "_need_root fails for non-root (mocked id)" {
  id() { echo 1000; }
  run _need_root
  [ "$status" -eq 1 ]
  [[ "$output" == *"needs root"* ]]
}

@test "_need_root in dry-run passes for non-root (mocked id)" {
  id() { echo 1000; }
  SHELLLIBS_DRYRUN=1 run _need_root
  [ "$status" -eq 0 ]
}

# --- _need_cmd ---

@test "_need_cmd succeeds for an existing command" {
  run _need_cmd bash
  [ "$status" -eq 0 ]
}

@test "_need_cmd fails for a missing command" {
  run _need_cmd definitely_not_a_real_command_xyz
  [ "$status" -eq 1 ]
  [[ "$output" == *"not installed"* ]]
}

@test "_need_cmd with no argument returns 2" {
  run _need_cmd
  [ "$status" -eq 2 ]
}

@test "_need_cmd in dry-run passes for a missing command" {
  SHELLLIBS_DRYRUN=1 run _need_cmd definitely_not_a_real_command_xyz
  [ "$status" -eq 0 ]
}
