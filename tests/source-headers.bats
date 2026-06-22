#!/usr/bin/env bats
#
# Every domain file must load its deps with the guarded sibling-fallback header so it
# works when sourced STANDALONE (before install / under bats), not only after install
# when all files already sit on PATH. Bare `source "$(which X)"` returns "" off-PATH and
# errors, leaving the dep undefined.

setup() { load test_helper; }

@test "apt-utils.sh loads its checksystem dep when sourced standalone" {
  run bash -c "source '${SHELLLIBS_ROOT}/scripts/apt-utils.sh' && type checkOsID >/dev/null && type apt-update >/dev/null && echo OK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]] || return 1
}

@test "lpic1a loads its logshell + checksystem deps when sourced standalone" {
  run bash -c "source '${SHELLLIBS_ROOT}/scripts/lpic1a' && type log-run >/dev/null && type checkIfFileHaveText >/dev/null && type kmod_blacklist >/dev/null && echo OK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]] || return 1
}

@test "cloudstack-utils loads its logshell dep when sourced standalone" {
  run bash -c "source '${SHELLLIBS_ROOT}/scripts/cloudstack-utils' && type log-error >/dev/null && type cloudstack-sshjump >/dev/null && echo OK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]] || return 1
}
