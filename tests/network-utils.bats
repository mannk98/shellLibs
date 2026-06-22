#!/usr/bin/env bats
#
# Dry-run tests for scripts/network-utils. SHELLLIBS_DRYRUN=1 makes every mutating
# call a no-op preview, so these never edit /etc, touch iptables, or restart
# services. Helpers that gate a write (checkIfFileHaveText / checkIfCommandExist)
# are mocked to force the write branch deterministically.

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/network-utils"
}

@test "nwEnableDhcp_v4Service (dry-run) previews dhcpd.conf + isc-dhcp-server writes, asks first" {
  checkIfCommandExist() { echo no; }
  SHELLLIBS_DRYRUN=1 run nwEnableDhcp_v4Service eth0
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]] || return 1
  [[ "$output" == *"/etc/dhcp/dhcpd.conf"* ]] || return 1
  [[ "$output" == *"/etc/default/isc-dhcp-server"* ]] || return 1
  [[ "$output" == *"systemctl restart isc-dhcp-server"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
}

@test "nwSetupCentos7 (dry-run) previews the three /etc writes incl resolv.conf, asks first" {
  SHELLLIBS_DRYRUN=1 run nwSetupCentos7 eth0 10.0.0.5 255.255.255.0 10.0.0.1 uuid-123
  [ "$status" -eq 0 ]
  [[ "$output" == *"/etc/sysconfig/network-scripts/ifcfg-eth0"* ]] || return 1
  [[ "$output" == *"/etc/sysconfig/network"* ]] || return 1
  [[ "$output" == *"/etc/resolv.conf"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
}

@test "nw-IptableAddLimitInboudPort (dry-run) previews the ACCEPT + DROP rules, asks first" {
  SHELLLIBS_DRYRUN=1 run nw-IptableAddLimitInboudPort 8080 10.0.0.0/24 tcp
  [ "$status" -eq 0 ]
  [[ "$output" == *"iptables -A INPUT"* ]] || return 1
  [[ "$output" == *"ACCEPT"* ]] || return 1
  [[ "$output" == *"DROP"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
}

@test "nwIfaceFlush (dry-run) previews ip addr flush, asks first" {
  SHELLLIBS_DRYRUN=1 run nwIfaceFlush eth0
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would run: ip addr flush dev eth0"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
}

@test "nwWifiConnect2AP_networkingService (dry-run) previews the interfaces write, asks first" {
  checkIfFileHaveText() { echo no; }
  SHELLLIBS_DRYRUN=1 run nwWifiConnect2AP_networkingService myssid mypass wlan0
  [ "$status" -eq 0 ]
  [[ "$output" == *"/etc/network/interfaces"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
}

@test "nmcliSetStaticIP (dry-run) previews the nmcli con mod commands, asks first" {
  SHELLLIBS_DRYRUN=1 run nmcliSetStaticIP eth0 10.0.0.1 10.0.0.5/24
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would run: nmcli con mod eth0"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
}
