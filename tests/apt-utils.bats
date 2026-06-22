#!/usr/bin/env bats
#
# Structural test for scripts/apt-utils.sh.

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/apt-utils.sh"
}

@test "admin-apt-disable-autoupdate is a thin alias (no duplicated /etc/apt write)" {
  # Dedupe: its body used to be byte-identical to apt-disable-autoupdate. It is now a
  # one-line back-compat alias, so its definition must not re-contain the direct write.
  run declare -f admin-apt-disable-autoupdate
  [ "$status" -eq 0 ]
  [[ "$output" != *"20auto-upgrades"* ]] || return 1
  [[ "$output" == *"apt-disable-autoupdate"* ]] || return 1
}
