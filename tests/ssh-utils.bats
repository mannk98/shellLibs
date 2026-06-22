#!/usr/bin/env bats
#
# Guard + dry-run tests for scripts/ssh-utils:ssh-enable-root. SHELLLIBS_DRYRUN=1
# makes the sshd_config edit a no-op preview; SHELLLIBS_SSHD_CONFIG points the
# function at a fixture so the test never touches the real /etc/ssh/sshd_config.

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/ssh-utils"
}

@test "ssh-enable-root with no action prints usage (no silent enable)" {
  run ssh-enable-root
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]] || return 1
}

@test "ssh-enable-root enable (dry-run) previews the sshd_config edit + restart, asks first, touches nothing" {
  printf 'PermitRootLogin no\n' > "${BATS_TEST_TMPDIR}/sshd_config"
  SHELLLIBS_DRYRUN=1 SHELLLIBS_SSHD_CONFIG="${BATS_TEST_TMPDIR}/sshd_config" run ssh-enable-root enable
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]] || return 1
  [[ "$output" == *"PermitRootLogin yes"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
  [ "$(cat "${BATS_TEST_TMPDIR}/sshd_config")" = "PermitRootLogin no" ]
}

@test "ssh-enable-root rejects an invalid action" {
  SHELLLIBS_DRYRUN=1 run ssh-enable-root bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid action"* ]] || return 1
}
