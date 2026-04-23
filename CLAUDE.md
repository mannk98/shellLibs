# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal collection of Bash utility libraries organized by domain (docker, network, admin, database, nvidia, etc.). Each file under `shellLibs/` exposes a family of functions that are sourced into an interactive bash shell — there is no build system, no tests, and no lint. Work is done by editing the scripts and re-running `install.sh`.

## Install / update workflow

```bash
sudo ./install.sh
```

The installer (`install.sh`) does two things:
1. **As root**: wipes `/bin/shellLibs`, copies the whole `shellLibs/` directory there, and makes each file executable.
2. **As any user**: appends a managed block to the calling user's `~/.bashrc` that adds `/bin/shellLibs` to `PATH` and `source`s every file in the directory. Under `sudo`, the target is resolved from `$SUDO_USER` via `getent passwd`, so the block lands in the invoking user's bashrc (not `/root/.bashrc`). Non-root runs skip step 1 and target `$HOME/.bashrc` directly — the files must already exist in `/bin/shellLibs`.

The managed block is wrapped in unique markers:
```
# >>> shellLibs managed block >>>
...
# <<< shellLibs managed block <<<
```
Re-installs are idempotent: `sed -i '/begin/,/end/d'` removes the old block before appending the fresh one, so running `install.sh` repeatedly never accumulates duplicates.

After editing a script, re-run `install.sh` (or re-copy the file to `/bin/shellLibs/`) for a new shell to pick it up. Scripts source each other by PATH lookup (`source "$(which logshell)"`), not by relative path — so a file only works after it's been installed.

## Architecture

### Foundation layer — always source these first

- `logshell` — structured logger. Provides `log-debug`, `log-info`, `log-warning`, `log-error`, `log-run`, `log-step`, each color-coded and gated by `LOG_LEVEL`. Functions are `export -f`'d so they're visible to subshells.
- `checksystem` — OS detection + predicates. The key helpers other scripts rely on are `checkOsID` (returns `ubuntu`/`debian`/`centos`/`alpine`/`almalinux`/`rocky`/...), `checkIfCommandExist`, `checkIfRootSession`, `checkIfFileHaveText`, `checkIfUserExist`.

Most other files begin with `source "$(which logshell)"` and/or `source "$(which checksystem)"`. Keep that pattern when adding new files.

### Domain modules

One file = one domain. Function names are prefixed with the domain so they don't collide in the flat namespace (everything lands in the same bash session):

| File | Prefix(es) | Notes |
|---|---|---|
| `admin` | `admin-*` | User/sudo/swap/crontab/kernel/timezone/hostname/desktop-entry ops |
| `apt-utils.sh` | `apt-*` | **Cross-distro wrapper** — dispatches to `apt`/`yum`/`apk` by matching `$oscheck` (set from `checkOsID`) |
| `cloudstack-utils` | `cloudstack-*`, `disk-fix-cloudstack-*` | SSH jump host + nginxgen toml template for internal CloudStack setup |
| `database-utils` | `mysql-*`, `psql-*` | MySQL helpers read creds from `MANNK_MYSQL_USER`/`MANNK_MYSQL_HOST`/`MANNK_MYSQL_PASS`; call `mysql-setEnv` first |
| `disk-utils` | `disk-*` | Partition create/mount, appends UUID entries to `/etc/fstab` |
| `docker-utils` | `docker-*` | Container/network/swarm/volume ops; includes macvlan, overlay, root-dir migration |
| `git-utils` | `git-*` | Commit/branch/rebase helpers; `git-setup-mannk98-repo` wires SSH config + `GOPRIVATE` |
| `golang-utils.sh` | `go-*` | Go module + private-repo scaffolding |
| `kvm-utils` | `kvm-*` | libvirt NAT port forwarding via iptables |
| `lpic1a` | misc (`kmod_*`, `systemd_*`, `grub*`) | LPIC-1 style sysadmin snippets; no consistent prefix |
| `network-utils` | `nw*`, `nmcli*` | Interface/DHCP/wifi/tcpdump/iptables/bridge ops |
| `nginxgen-utils` | `nginxgen-*` | Helpers around a local docker container literally named `nginxgen`. `${nginxgenConName}` is populated lazily on first `nginxgen-*` call via `_nginxgen_ensure_con_name`, not at source time |
| `nvidia-utils` | `nvidia-*` | Driver/toolkit install, nouveau blacklist |
| `ssh-utils` | `ssh-*` | Port forwarding, SOCKS tunnel, root-login toggle, key copy |
| `tar-utils` | `tar-extract`, `tar-view` | Format-dispatched archive handling |
| `_other.sh` | misc | Grab-bag: `listFilesInDir`, `listDirInDir`, `install-qt5` |
| `checksystem` | `check*` | See foundation layer |
| `logshell` | `log-*` | See foundation layer |

### Cross-distro pattern (important)

`apt-utils.sh` is the canonical example: a single public function (e.g. `apt-install`) calls `_apt_oscheck` (which lazily populates `$oscheck` via `checkOsID` on first use), then inspects `${oscheck}` and branches to `apt`/`yum`/`apk`. Several other files (`admin`, `nvidia-utils`) use the same `checkOsID` switch inline. When adding package-manager-touching code, mirror this — don't hard-code `apt`, and if you need `$oscheck` in a new `apt-*` function, call `_apt_oscheck` first.

### Function conventions

Every public function starts with the same guard:

```bash
[[ $1 == "-h" || -z $1 ]] && {
  echo "Usage: $FUNCNAME <args>..."
  return 0
}
```

`$FUNCNAME` (or `${FUNCNAME[0]}`) is used instead of hard-coding the name — preserve that when refactoring. Many functions also `echo` the full command string before `eval`-ing it (see `database-utils`) so the user can see what ran.

### Runtime requirements

Most functions assume root or sudo; some (docker, nmcli, iptables, systemctl, fstab edits) will silently fail for non-root users. The README explicitly warns about this. New functions that need root should check `checkIfRootSession` or document it in their `-h` output.

## Gotchas when editing

- **No test harness.** The only way to validate changes is to re-install and exercise the function in a live shell on a matching distro. Don't assume a change works without doing that. A shellcheck lint gate (`make lint`) exists and catches the big quoting/arity classes.
- **`source "$(which X)"` fails before install.** If you split a new helper out of an existing file, you must run `install.sh` before sourcing it from a sibling.
- **No top-level side effects at source time.** Don't add `cmd` / `$(cmd)` / `export X=$(cmd)` at the top of a file. Every new shell sources all files in `/bin/shellLibs` — any top-level command runs on every login. Use a lazy ensurer pattern like `_apt_oscheck` in `apt-utils.sh` or `_nginxgen_ensure_con_name` in `nginxgen-utils`: a private helper that populates a cached global on first use, called at the top of each function that needs it.
- **`_other.sh` and `apt-utils.sh` / `golang-utils.sh` end in `.sh`**, the rest don't. The installer `source`s every file regardless, but if you rename an existing file you'll break any caller that does `source "$(which old-name)"`.
