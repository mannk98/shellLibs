# shellLibs

A personal collection of Bash utility functions for day-to-day Linux sysadmin work,
organized by domain (docker, network, admin, database, nvidia, disk, git, …). Each
file under [`scripts/`](scripts/) exposes a family of functions that get **sourced into
your interactive shell** so they're always one command away.

There's no build step and no runtime: you install once, and every new shell picks up
all the functions automatically.

---

## Install

Run as **root** (the install copies files into `/bin` and needs write access there):

```bash
sudo ./install.sh
```

What [`install.sh`](install.sh) does:

1. **As root** — wipes `/bin/scripts`, copies the whole `scripts/` directory there,
   and makes every file executable.
2. **Always** — appends a *managed block* to the invoking user's `~/.bashrc`. The block
   adds `/bin/scripts` to `PATH` and `source`s every file in that directory.

Because it's invoked with `sudo`, the installer resolves the **real** user via
`$SUDO_USER` (`getent passwd`), so the block lands in *your* `~/.bashrc` — not
`/root/.bashrc`. One `sudo ./install.sh` is all you need.

Open a new shell (or `source ~/.bashrc`) and the functions are live:

```bash
log-info "hello"
checkOsID
docker-getIPAll
```

### The managed block

The lines added to `~/.bashrc` are wrapped in unique markers:

```bash
# >>> shellLibs managed block >>>
...
# <<< shellLibs managed block <<<
```

Re-installs are **idempotent** — the installer deletes the old block (`sed` range-delete
between the markers) before appending a fresh one, so running `install.sh` repeatedly
never duplicates the block or corrupts the rest of your `~/.bashrc`.

### Updating

After editing a script, just re-run `sudo ./install.sh` (or copy the one file into
`/bin/scripts/`). Files source each other by **PATH lookup** — `source "$(which logshell)"`,
not a relative path — so a script only works *after* it has been installed.

### Uninstall

There's no uninstall script yet. To remove manually:

```bash
sudo rm -rf /bin/scripts
# then delete the managed block from ~/.bashrc:
sed -i '/# >>> shellLibs managed block >>>/,/# <<< shellLibs managed block <<</d' ~/.bashrc
```

---

## Requirements

- **Bash** (the libraries use bashisms — arrays, `[[ ]]`, `FUNCNAME`; not POSIX `sh`).
- **root / sudo** for most functions. Anything touching docker, `iptables`, `systemctl`,
  `/etc/fstab`, `/etc/sudoers`, partitions, or network config will silently fail for an
  unprivileged user.
- **Linux.** OS-detection (`checkOsID`) reads `/etc/os-release`; the cross-distro wrappers
  target Debian/Ubuntu, RHEL family (CentOS/AlmaLinux/Rocky), and Alpine.
- Per-domain external tools (`docker`, `nvidia-smi`, `mysql`, `tcpdump`, `jq`, …) must be
  installed for the corresponding functions to work.

---

## How it's organized

### Foundation layer — sourced first by almost everything

| File | Provides |
|---|---|
| [`logshell`](scripts/logshell) | Color, level-gated logger: `log-debug`, `log-info`, `log-warning`, `log-error`, `log-run`, `log-step`. Verbosity is controlled by `LOG_LEVEL` (default = debug, shows everything). Functions are `export -f`'d so subshells see them. |
| [`checksystem`](scripts/checksystem) | OS detection + predicates: `checkOsID`, `checkOsVersionID`, `checkIfCommandExist`, `checkIfRootSession`, `checkIfFileHaveText`, `checkIfUserExist`, plus hardware/zombie/stress/systemd checks. |

Set verbosity before sourcing (or any time) with one of the level constants, e.g.:

```bash
LOG_LEVEL=$LOG_LEVEL_WARNING   # only warnings, errors, run, step
```

### Domain modules

One file = one domain. Function names are **prefixed** with the domain so they don't
collide in the single flat namespace (every function lands in the same shell session).
Every public function responds to `-h` (and to a missing first arg) by printing usage —
so `<function> -h` is always safe to explore.

| File | Prefix(es) | What's inside |
|---|---|---|
| [`admin`](scripts/admin) | `admin-*` | Users/sudo, swap files, crontab, kernel install/initramfs, timezone, hostname, SSH-agent/host setup, core-dump enable, desktop entries, cgroup v2 |
| [`apt-utils.sh`](scripts/apt-utils.sh) | `apt-*` | **Cross-distro package wrapper** — install/remove/search/update/purge/download-only; dispatches to `apt`/`yum`/`apk` by OS. Also local-repo setup helpers |
| [`checksystem`](scripts/checksystem) | `check*` | See foundation layer |
| [`cloudstack-utils`](scripts/cloudstack-utils) | `cloudstack-*`, `disk-fix-cloudstack-*` | SSH jump host + nginxgen TOML template + qcow2 fsck repair (internal CloudStack setup) |
| [`database-utils`](scripts/database-utils) | `mysql-*`, `psql-*` | MySQL user/grant/db/table ops (+ a Postgres connect helper). Reads creds from `MANNK_MYSQL_USER`/`_HOST`/`_PASS` — call `mysql-setEnv` first. Each function **echoes the command before running it** |
| [`disk-utils`](scripts/disk-utils) | `disk-*` | Create/format a partition (GPT), mount + append a UUID entry to `/etc/fstab`, quick disk-perf check |
| [`docker-utils`](scripts/docker-utils) | `docker-*` | Container/image/network/volume/swarm ops; macvlan & overlay networks, root-dir migration, resource limits, backup/restore volumes, commit & save |
| [`git-utils`](scripts/git-utils) | `git-*` | Commit/branch/rebase/author helpers; `git-setup-mannk98-repo` wires SSH config + URL rewrite + `GOPRIVATE` |
| [`golang-utils.sh`](scripts/golang-utils.sh) | `go-*` | Go module + private-repo scaffolding, dependency graph |
| [`kvm-utils`](scripts/kvm-utils) | `kvm-*` | libvirt NAT port-forwarding via iptables |
| [`logshell`](scripts/logshell) | `log-*` | See foundation layer |
| [`lpic1a`](scripts/lpic1a) | mixed (`kmod_*`, `systemd_*`, `grub*`, …) | LPIC-1 style sysadmin snippets: module blacklist/unload, grub repair, ldconfig, pci/usb inspect |
| [`network-utils`](scripts/network-utils) | `nw*`, `nmcli*` | Interfaces, DHCP server/client, wifi (wpa_supplicant + NetworkManager), static IP, bridges, tcpdump, iptables port limits, bandwidth shaping |
| [`nginxgen-utils`](scripts/nginxgen-utils) | `nginxgen-*` | Helpers around a local docker container named `nginxgen` (config view, logs, TOML template generation) |
| [`nvidia-utils`](scripts/nvidia-utils) | `nvidia-*` | Driver + container-toolkit install, nouveau blacklist, kernel-module reload |
| [`ssh-utils`](scripts/ssh-utils) | `ssh-*` | Local/remote port forwarding, SOCKS tunnel, root-login enable/disable (with sshd_config backup), key copy, connection test |
| [`tar-utils`](scripts/tar-utils) | `tar-extract`, `tar-view` | Format-dispatched extract/list for tar/gz/bz2/xz/zip/7z |
| [`_other.sh`](scripts/_other.sh) | misc | Grab-bag: `listFilesInDir`, `listDirInDir`, `install-qt5` |

---

## Conventions (read before adding code)

These patterns are load-bearing — keep them when you edit or add a file.

- **`-h` / no-arg usage guard.** Every public function starts with:
  ```bash
  [[ $1 == "-h" || -z $1 ]] && {
    echo "Usage: $FUNCNAME <args>..."
    return 0
  }
  ```
  Use `$FUNCNAME` (or `${FUNCNAME[0]}`) instead of hard-coding the name.

- **Cross-distro via `checkOsID`.** Don't hard-code `apt`. Branch on the OS like
  `apt-utils.sh` does (match `${oscheck}` against `*ubuntu*` / `*centos*` / `*alpine*` …).

- **No side effects at source time.** Every new shell sources *all* files, so a top-level
  `cmd` / `$(cmd)` / `export X=$(cmd)` would run on every login. Use a **lazy ensurer**:
  a private `_x_ensure_…` helper that fills a cached global on first use, called at the top
  of each function that needs it (see `_apt_oscheck` in `apt-utils.sh`,
  `_nginxgen_ensure_con_name` in `nginxgen-utils`).

- **Echo-then-eval.** Many functions (`database-utils`, docker macvlan) print the full
  command string before running it, so you can see exactly what executed.

- **Source by PATH, not relative path** (`source "$(which logshell)"`) — which is why a new
  helper must be installed before a sibling can source it.

---

## Linting

A `shellcheck` gate is wired up via the [`Makefile`](Makefile):

```bash
make lint           # run shellcheck over scripts/* and install.sh
make lint-report    # same, but write full output to agent_docs/shellcheck-report.txt
make lint-install   # apt-install shellcheck
```

Project-wide suppressions (with rationale) live in [`.shellcheckrc`](.shellcheckrc).
Run `make lint` before committing.

---

## Testing

A starter [`bats`](https://github.com/bats-core/bats-core) suite covers the foundation
layer (`logshell` + `checksystem`):

```bash
make test           # run tests/ (run `make test-install` first if bats is missing)
```

See [`tests/`](tests/) for the suite and [`tests/README.md`](tests/README.md) for how to
extend it. The recommended ladder, cheapest first:

1. **`make lint`** — `shellcheck` already catches the big quoting/arity/typo classes.
   This is your first gate, not really "testing" but high value for zero effort.
2. **`bats` unit tests for pure functions** — functions that only compute (no system
   calls) can be sourced and asserted directly. Good first targets: `checksystem`
   predicates, `logshell` level-gating, `tar-utils` format dispatch, `network-utils`
   `nwIaceGetIPmask` netmask math, and every `-h` usage guard.
3. **Command mocking for system-touching functions** — override `docker`/`apt`/`mysql`/…
   with a shell function that just records its arguments, then assert the *command that
   would have run*. This fits this repo especially well because many functions already
   **echo the command before `eval`-ing it** (`database-utils`, docker macvlan) — so you
   can assert on that printed string without executing anything.
4. **Container integration tests** — for the genuinely destructive/distro-specific bits
   (docker, apt across Debian/RHEL/Alpine), run inside throwaway containers
   (`ubuntu:`, `almalinux:`, `alpine:`) so a bad command can't hurt your host.

A zero-dependency taste of approach 2 — source a file and assert in plain bash:

```bash
source scripts/network-utils
result=$(nwIaceGetIPmask -h)   # usage guard returns the help text, runs nothing
echo "$result" | grep -q "Usage:" && echo PASS || echo FAIL
```

For a real harness, [`bats-core`](https://github.com/bats-core/bats-core) is the standard.
See [`agent_docs/improvement-proposals.md`](agent_docs/improvement-proposals.md) §8 for the
concrete first cut.

---

## Caveats / known rough edges

- **Install path.** The install path is **`/bin/scripts`** (all docs and the
  `cloudstack-utils` remote `source` line are synced to it). `/bin` itself is unconventional
  — `/usr/local/bin` or `/opt` would be cleaner, but moving it touches existing installs, so
  that's a deliberate "later" item.
- **Destructive ops are unguarded.** Functions that write to `/etc/fstab`, `/etc/sudoers`,
  `/etc/network/interfaces`, or run `rm -rf` assume you know what you're doing and mostly
  don't back up or check for idempotency. Read a function (`<fn> -h`, or open the file)
  before running it as root.
- **Secrets on the command line.** `database-utils` passes the MySQL password as
  `-p"$PASS"`, which is visible in `ps`. Fine for a personal box; not for shared hosts.

A ranked menu of improvements (with what's already done) lives in
[`agent_docs/improvement-proposals.md`](agent_docs/improvement-proposals.md).

---

## License

See [`LICENSE`](LICENSE).
