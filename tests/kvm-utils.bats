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
  [[ "$output" == *"Use:"* ]] || return 1
}

@test "kvm-nat-port (dry-run) previews both iptables rules, runs nothing" {
  # Use a VM IP distinct from the help text's example (192.168.122.10) so the DNAT
  # target is verified to use ${ip_of_vm}, not a hard-coded address.
  SHELLLIBS_DRYRUN=1 run kvm-nat-port virbr0 10.20.30.40 3389 5555
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]] || return 1
  [[ "$output" == *"iptables"* ]] || return 1
  [[ "$output" == *"PREROUTING"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
  [[ "$output" == *"--to 10.20.30.40:3389"* ]] || return 1   # DNAT target must use ${ip_of_vm}, not a hard-coded IP ("--to " is unique to the rule, not the confirm prompt)
}
