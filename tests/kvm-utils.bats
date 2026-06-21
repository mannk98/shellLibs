#!/usr/bin/env bats
#
# Dry-run pilot test for scripts/kvm-utils.

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/kvm-utils"
}

@test "kvm-nat-port -h prints usage and returns 0" {
  run kvm-nat-port -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Use:"* ]]
}

@test "kvm-nat-port (dry-run) previews both iptables rules, runs nothing" {
  SHELLLIBS_DRYRUN=1 run kvm-nat-port virbr0 192.168.122.10 3389 3389
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
  [[ "$output" == *"iptables"* ]]
  [[ "$output" == *"PREROUTING"* ]]
}
