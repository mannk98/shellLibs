#!/usr/bin/env bats
#
# Dry-run tests for scripts/nvidia-utils. SHELLLIBS_DRYRUN=1 makes every mutating
# call a no-op preview, so these never touch the real system and run fine on a
# host with no GPU. checkOsID is mocked to force a deterministic distro branch.

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/nvidia-utils"
}

@test "nvidia-disable-nouveau -h prints usage, runs nothing" {
  run nvidia-disable-nouveau -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]] || return 1
}

@test "nvidia-disable-nouveau (dry-run, ubuntu) previews the blacklist write + rmmod, asks first" {
  checkOsID() { echo ubuntu; }
  SHELLLIBS_DRYRUN=1 run nvidia-disable-nouveau
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]] || return 1
  [[ "$output" == *"/etc/modprobe.d/blacklist-nouveau.conf"* ]] || return 1
  [[ "$output" == *"rmmod nouveau"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
}

@test "nvidia-unload-kmodule (dry-run) previews rmmod of the nvidia modules, asks first" {
  SHELLLIBS_DRYRUN=1 run nvidia-unload-kmodule
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would run: rmmod nvidia"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
}

@test "nvidia-container-uninstall (dry-run) previews the purge, asks first" {
  SHELLLIBS_DRYRUN=1 run nvidia-container-uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would run: apt-get remove --purge"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
}

@test "nvidia-install-driver -h prints usage, runs nothing" {
  run nvidia-install-driver -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]] || return 1
}
