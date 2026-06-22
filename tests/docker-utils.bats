#!/usr/bin/env bats
#
# Dry-run tests for scripts/docker-utils. SHELLLIBS_DRYRUN=1 makes every mutating
# call a no-op preview, so these never touch real Docker / the system and run fine
# on a host with no docker daemon.

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/docker-utils"
}

@test "docker-daemon-restart (dry-run) previews daemon-reload + restart, touches nothing" {
  SHELLLIBS_DRYRUN=1 run docker-daemon-restart
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would run: systemctl daemon-reload"* ]] || return 1
  [[ "$output" == *"DRY-RUN would run: systemctl restart docker"* ]] || return 1
}

@test "docker-change-rootdir (dry-run) previews the daemon.json write + systemctl, asks first" {
  SHELLLIBS_DRYRUN=1 run docker-change-rootdir /data/docker
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]] || return 1
  [[ "$output" == *"/etc/docker/daemon.json"* ]] || return 1
  [[ "$output" == *"systemctl stop docker"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
}

@test "docker-swarm-removeService (dry-run) previews service rm, asks first" {
  SHELLLIBS_DRYRUN=1 run docker-swarm-removeService web
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would run: docker service rm web"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
}

@test "docker-network-create-macvlan (dry-run) previews a single docker network create (no eval), with optional flags" {
  SHELLLIBS_DRYRUN=1 run docker-network-create-macvlan enp1s0 mvlan 10.6.200.0/22 10.6.200.1 10.6.203.236/30 passthru
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would run: docker network create -d macvlan"* ]] || return 1
  [[ "$output" == *"--ip-range 10.6.203.236/30"* ]] || return 1
  [[ "$output" == *"macvlan_mode=passthru"* ]] || return 1
}

@test "docker-network-create (dry-run) previews the create command, touches nothing" {
  SHELLLIBS_DRYRUN=1 run docker-network-create mynet 172.20.0.0/16
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would run: docker network create"* ]] || return 1
}

@test "docker-swarm-inspectService calls 'docker service inspect' (regression: was bare 'service')" {
  # The function used to call `service inspect` (missing the docker prefix). Mock
  # docker as a recorder and assert it receives the service-inspect subcommand.
  docker() { echo "docker $*"; }
  run docker-swarm-inspectService web
  [[ "$output" == *"docker service inspect --pretty web"* ]] || return 1
}

@test "docker-getIPInfo does not leak conname into the shell (local sweep)" {
  # Direct call (not `run`, whose subshell would mask a leak) with docker mocked.
  docker() { :; }
  unset conname
  docker-getIPInfo web >/dev/null
  [ -z "${conname:-}" ] || return 1
}
