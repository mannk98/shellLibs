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
  [[ "$output" == *"DRY-RUN"* ]] || return 1
  [[ "$output" == *"fallocate"* ]] || return 1
  [[ "$output" == *"/etc/fstab"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
  [ ! -e "${BATS_TEST_TMPDIR}/swap" ]
}

@test "admin-user-add-to-sudo (dry-run) writes a validated /etc/sudoers.d drop-in, touches nothing" {
  SHELLLIBS_DRYRUN=1 run admin-user-add-to-sudo someuser
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]] || return 1
  # writes a per-user drop-in, not the monolithic /etc/sudoers (a bad edit there
  # can lock you out of sudo); the drop-in path is the new contract.
  [[ "$output" == *"/etc/sudoers.d/someuser"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
  # safety: it must NOT append to the monolithic /etc/sudoers anymore.
  [[ "$output" != *"would append to /etc/sudoers:"* ]] || return 1
}

@test "admin-swap-enable -h prints usage" {
  run admin-swap-enable -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]] || return 1
}

# --- exit-audit regression --------------------------------------------------
#
# admin is sourced into the interactive shell, so a bare `exit` in any function
# kills the *user's* shell, not just the function. The -h guard must `return`.
# Run it in a child shell and prove the sentinel after the call still prints —
# an `exit 0` would abort the child first, so SURVIVED would be missing.

@test "admin-crontab-add -h returns instead of exiting the shell" {
  run bash -c "source '${SHELLLIBS_ROOT}/scripts/admin'; admin-crontab-add -h; echo SURVIVED"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SURVIVED"* ]] || return 1
}

@test "admin-changeUserSession -h returns 0 without running sudo (no fall-through)" {
  sudo() { echo "SUDO-RAN $*"; }
  run admin-changeUserSession -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]] || return 1
  [[ "$output" != *"SUDO-RAN"* ]] || return 1
}

@test "admin-user-createnew does not leak username into the shell (local sweep)" {
  # Direct call (not `run`, whose subshell would mask a leak) with adduser mocked.
  adduser() { :; }
  unset username
  admin-user-createnew alice
  [ -z "${username:-}" ] || return 1
}
