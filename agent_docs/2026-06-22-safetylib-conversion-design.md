# safetylib conversion sweep — design / plan (2026-06-22)

The last big item of the safety arc: route the **remaining destructive functions**
through `safetylib` (`_run` / `_write_file` / `_append_line`) + the preflight/confirm
helpers, so every dangerous op is previewable (`SHELLLIBS_DRYRUN=1`), idempotent where it
edits a file, root/command-checked, and (for the truly destructive ones) confirmed.

Builds on safetylib v1 (`2026-06-20-safetylib-dryrun-design.md`) and v2
(`2026-06-21-safetylib-v2-design.md`). Pilots already converted: `admin-swap-enable`,
`admin-user-add-to-sudo`, `disk-mount-partition`, `kvm-nat-port`, `install.sh`.

## What counts as "destructive" (→ convert)

Convert a function when it does any of:
- writes/edits a system file (`/etc/**`, fstab, sudoers, modprobe.d, resolv.conf, …) —
  via `>`, `>>`, `tee`, `sed -i`, or a heredoc;
- runs `rm -rf`, `dd`, `mkfs`/`mkswap`, `wipefs`, partition tools;
- `iptables`/`tc` changes, `ip link/addr`, `nmcli con/dev` mutations;
- loads/unloads kernel modules (`modprobe`/`rmmod`);
- installs/removes packages (`apt`/`yum`/`apk install|remove|purge`);
- starts/stops/restarts/enables/disables services (`systemctl`, `service`);
- removes Docker objects (`docker rm`/`rmi`/`prune`/`network rm`/`volume rm`/`system prune`).

**Leave read-only functions alone** — `cat`, `nvidia-smi -L`, `docker ps`, `tail`, `grep`,
`swapon --show`, `cd`, `curl <info>`, `docker cp … /tmp`, `docker exec … bash`. No safety
value in wrapping a query; it only adds noise.

## Conversion recipe (per function)

1. **Header:** ensure the file loads safetylib with the guarded sibling-fallback pattern
   (so it works from the repo before install, which the bats tests need):
   ```bash
   command -v _run >/dev/null 2>&1 || source "$(command -v safetylib 2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/safetylib")"
   ```
2. **Preflight:** `_need_root || return 1` for root-only ops; `_need_cmd <tool> || return 1`
   for each external tool the function hard-depends on (advisory under dry-run).
3. **Confirm:** `_confirm "<what will happen>?" || return 1` before genuinely dangerous,
   hard-to-undo ops (purge packages, rmmod the GPU driver, overwrite /etc/resolv.conf,
   wipe a docker root-dir). Skip the prompt for low-risk single-package installs.
4. **Mutations:** wrap each command in `_run …` (argv, no eval). File writes become
   `_write_file <path>` (content on stdin — convert a `cat >file <<EOF` heredoc into
   `_write_file file <<EOF`) or `_append_line <file> <line>` for single-line appends.
5. **Keep** the `-h`/no-arg usage guard, `$FUNCNAME`, and `checkOsID` cross-distro branching.

## Test approach

One `tests/<file>.bats` per module, mirroring `tests/admin.bats`: drive each converted
function with `SHELLLIBS_DRYRUN=1`, assert the preview mentions the key command / file and
that nothing was created/changed. Where a function branches on `checkOsID`, mock it
(`checkOsID() { echo ubuntu; }`) to force a deterministic branch. System-touching real runs
still need a live matching host — out of scope for CI.

## Catalog & order

### 1. nvidia-utils  (start here — clear high-risk ops, self-contained)
- `nvidia-disable-nouveau` — writes modprobe.d blacklist (debian) / denylist (centos),
  `update-initramfs`/`dracut`, `grub2-mkconfig`, `rmmod nouveau`. **Confirm.**
- `nvidia-unload-kmodule` — `rmmod nvidia*` ×4. **Confirm.**
- `nvidia-install-nvidiadockertoolkit` — writes apt/yum repo file, `sed -i`, install,
  `systemctl restart docker`.
- `nvidia-install-driver` — `apt install`/`purge`, `nvidia-installer --uninstall`, runs a
  local `./package`. **Confirm** before purge/uninstall.
- `nvidia-container-toolkitl-install` — writes apt repo file, install.
- `nvidia-container-uninstall` — `apt-get remove --purge '^nvidia-.*'`. **Confirm.**
- **Bugs to fix in passing:** `nvidia-disable-nouveau` calls `admin-updateRamdisk`
  (doesn't exist → `admin-updateInitRamdisk`); `nvidia-install-driver` has a top-level
  `set -e` inside the function that leaks into the user's shell — remove it.
- Read-only (leave): `nvidia-list-devices`, `nvidia-check-version`.

### 2. docker-utils
- root-dir migration (`systemctl stop docker …`, write `/etc/docker/daemon.json`,
  `systemctl restart docker`), backup/restore (`docker run --rm …`), and any
  `docker rm/rmi/prune/network rm/volume rm`. Full read at conversion time (grep flagged
  lines 142, 176–177, 256, 270, 296; confirm the rest).

### 3. network-utils
- Writes `/etc/network/interfaces`, `/etc/wpa_supplicant/*.conf`, `/etc/dhcp/dhcpd.conf`,
  `/etc/default/isc-dhcp-server`, `/etc/sysconfig/network-scripts/ifcfg-*`,
  `/etc/sysconfig/network`, `/etc/resolv.conf`; `systemctl restart networking/isc-dhcp-server`;
  `apt install`; `iptables -A/-D` (lines 438–439, 461–462); `nmcli` mutations.

## Out of scope (note, don't convert now)
- `nginxgen-utils` — inspection module; only `nginxgen-createTemplate` writes a file (to cwd,
  already idempotent). Low value.
- `cloudstack-utils`, `lpic1a`, `database-utils`, `ssh-utils`, `git-utils`, `_other.sh`,
  `disk-utils:disk-create-partition` — a later pass after the three big ones land.

## Status
- [x] nvidia-utils — 6 fns converted; dropped a dead `admin-updateRamdisk` call + a
  leaking `set -e`. `tests/nvidia-utils.bats`. (commit 08ff0f1)
- [x] docker-utils — mutating fns converted; removed the macvlan `eval`; fixed
  `docker-swarm-inspectService` (`service` -> `docker service`). `tests/docker-utils.bats`. (8096c42)
- [x] network-utils — ~20 fns converted (/etc writers, iptables, nmcli/ip/sysctl);
  fixed `nmcliRestartIface` arg guard. `tests/network-utils.bats`. (94ea0bb)

Gates after the sweep: `make test` 78/78, `make lint-ci` exit 0.

### Follow-up (deliberately deferred — a later pass)
- `nginxgen-utils` stays as-is (inspection module; only `nginxgen-createTemplate` writes,
  to cwd, already idempotent — low value).
- `cloudstack-utils`, `lpic1a`, `database-utils` (also has the CLI-password issue, §7),
  `ssh-utils`, `git-utils`, `_other.sh`, `disk-utils:disk-create-partition` (mkfs/dd).
