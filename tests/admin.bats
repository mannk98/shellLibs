#!/usr/bin/env bats
#
# Dry-run pilot tests for scripts/admin. These never touch the real system because
# SHELLLIBS_DRYRUN=1 makes every mutating call a no-op preview.

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/admin"
}

@test "admin-swap-enable (dry-run) previews fallocate + fstab append, touches nothing" {
  SHELLLIBS_DRYRUN=1 run admin-swap-enable "${BATS_TEST_TMPDIR}/swap" 1G
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
  [[ "$output" == *"fallocate"* ]]
  [[ "$output" == *"/etc/fstab"* ]]
  [ ! -e "${BATS_TEST_TMPDIR}/swap" ]
}

@test "admin-user-add-to-sudo (dry-run) previews the sudoers append, touches nothing" {
  SHELLLIBS_DRYRUN=1 run admin-user-add-to-sudo someuser
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
  [[ "$output" == *"/etc/sudoers"* ]]
}

@test "admin-swap-enable -h prints usage" {
  run admin-swap-enable -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}
