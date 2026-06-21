#!/usr/bin/env bats
#
# Dry-run pilot tests for scripts/disk-utils.

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/disk-utils"
}

@test "disk-mount-partition -h prints usage" {
  run disk-mount-partition -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "disk-mount-partition (dry-run) previews the mount, runs nothing" {
  # Pick any existing block device so the [[ -b ]] guard passes; dry-run does no I/O.
  # After the dry-run mount no-ops, the real blkid UUID lookup returns empty and the
  # function returns 1 before the fstab step — so assert only the mount preview (the
  # fstab idempotency is covered by the _append_line unit tests).
  local dev
  dev="$(ls /dev/disk0 /dev/sda /dev/vda 2>/dev/null | head -n1)"
  [ -n "$dev" ] || skip "no block device available to exercise the guard"
  SHELLLIBS_DRYRUN=1 run disk-mount-partition "$dev" "${BATS_TEST_TMPDIR}/mnt" ext4
  [[ "$output" == *"DRY-RUN"* ]]
  [[ "$output" == *"mount"* ]]
}
