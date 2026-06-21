# Design — safetylib v2: confirm + preflight helpers

**Date:** 2026-06-21
**Status:** approved design, pre-implementation
**Builds on:** [2026-06-20-safetylib-dryrun-design.md](2026-06-20-safetylib-dryrun-design.md) (v1: `_run`/`_append_line`/`_write_file`/`_backup_file` + 5 pilots).

## Goal

Round out the safety layer with the two pieces v1 deferred:

- **`_confirm`** — a y/N gate before destructive operations, with a `SHELLLIBS_ASSUME_YES`
  escape hatch for automation.
- **`_need_root` / `_need_cmd`** — standardized preflight checks (the ad-hoc
  `checkIfRootSession` / `$EUID` / `command -v` checks are scattered and inconsistent).

Wire all three into the same 5 pilots from v1, plus convert the one remaining unguarded
`rm` in `install.sh` (the final-review follow-up).

## Non-goals (still deferred)

- Converting the remaining destructive functions across the other ~6 domain files
  (network-utils, nvidia-utils, docker-utils, nginxgen-utils, …) — a separate mechanical sweep.
- `admin-user-add-to-sudo` → `/etc/sudoers.d` migration + `visudo -c` validation
  (improvement-proposals §7).

## Key design decision: preflight/confirm are advisory in dry-run

`_need_root`, `_need_cmd`, and `_confirm` must **NOT block when `SHELLLIBS_DRYRUN` is set**.
Otherwise a dry-run preview run as a non-root user, or on a host lacking a tool (e.g.
`iptables` on macOS), would abort before printing anything — and would break the v1 dry-run
pilot tests (which run non-root on any host). So in dry-run mode all three pass (with a
warning where relevant); they enforce only in real mode.

This keeps "preview the whole flow on any machine" working, while real runs get genuine
root/command/consent gates.

## Components — 3 new helpers in `scripts/safetylib`

```bash
# Ask for y/N confirmation before a destructive op.
# Precedence: dry-run -> pass; ASSUME_YES -> pass; TTY -> prompt; no TTY -> refuse.
# Returns 0 = proceed, 1 = abort.
_confirm() {
  local prompt="${1:-Proceed?}" reply
  [[ -n ${SHELLLIBS_DRYRUN:-}     ]] && { log-run  "DRY-RUN would ask: ${prompt}"; return 0; }
  [[ -n ${SHELLLIBS_ASSUME_YES:-} ]] && { log-info "assume-yes: ${prompt}";        return 0; }
  [[ ! -t 0 ]] && { log-warning "${prompt} — refused (no TTY; set SHELLLIBS_ASSUME_YES=1)"; return 1; }
  read -rp "${prompt} [y/N] " reply
  [[ ${reply} =~ ^[Yy]([Ee][Ss])?$ ]] && return 0
  log-info "aborted: ${prompt}"; return 1
}

# Require root (uses `id -u` — correct under sudo). Advisory (pass) in dry-run.
_need_root() {
  [[ "$(id -u)" -eq 0 ]] && return 0
  [[ -n ${SHELLLIBS_DRYRUN:-} ]] && { log-warning "(dry-run) ${FUNCNAME[1]:-cmd} would require root"; return 0; }
  log-error "${FUNCNAME[1]:-command} needs root (run with sudo)"; return 1
}

# Require a command to exist. Advisory (pass) in dry-run.
_need_cmd() {
  [[ -z $1 ]] && { log-error "_need_cmd: no command given"; return 2; }
  command -v "$1" >/dev/null 2>&1 && return 0
  [[ -n ${SHELLLIBS_DRYRUN:-} ]] && { log-warning "(dry-run) ${FUNCNAME[1]:-cmd} would require '$1'"; return 0; }
  log-error "${FUNCNAME[1]:-command} needs '$1' which is not installed"; return 1
}
```

Add all three to the `export -f` line.

### Contracts

| Helper | Args | Dry-run | Real mode | Returns |
|---|---|---|---|---|
| `_confirm` | `[prompt]` | log + pass | ASSUME_YES→pass; TTY→prompt; no-TTY→refuse | 0 proceed / 1 abort |
| `_need_root` | — | warn + pass | root→0, else error+1 | 0 / 1 |
| `_need_cmd` | `<command>` | warn + pass | present→0, else error+1 | 0 / 1 / 2 (no arg) |

### Notes / overlaps

- `_confirm` accepts `y`/`Y`/`yes`/`YES` (ERE regex; bash 3.2-safe). `read -rp` prompt goes
  to stderr; only used in the TTY branch.
- `_need_root` uses `id -u` (reliable under `sudo`), unlike the older `checkIfRootSession`
  which keys on `$USER`. `_need_cmd` parallels `checkIfCommandExist`. Both new helpers are
  the **preflight idiom** (return status + log + dry-run-aware) and intentionally coexist
  with the checksystem predicates (which return "yes"/"no" strings). Documented, not a bug.
- `${FUNCNAME[1]}` names the calling function in the error so the user knows what needs root/the command.
- Helpers never `exit` (sourced file) — only `return`.

## Wiring into the 5 pilots

Placed after each function's usage (`-h`) guard, before the destructive work, in the order
`_need_root` → `_need_cmd` → `_confirm`, each as `<check> || return 1`:

| Function | Added checks |
|---|---|
| `admin-swap-enable` | `_need_root` · `_need_cmd mkswap` · `_confirm "Create ${sizeSwap} swapfile at ${pathSwap} and add it to /etc/fstab?"` |
| `admin-user-add-to-sudo` | `_need_root` · `_confirm "Grant '${username}' passwordless sudo (NOPASSWD:ALL in /etc/sudoers)?"` |
| `disk-mount-partition` | (after the `[[ -b ]]` check) `_need_root` · `_confirm "Mount ${partition} at ${mount_point} and add a UUID entry to /etc/fstab?"` |
| `kvm-nat-port` | `_need_root` · `_need_cmd iptables` · `_confirm "Add iptables NAT: host port ${port_host} → ${ip_of_vm}:${port_vm}?"` |
| `install.sh` (line ~30) | wrap the apt-port-cleanup `rm -f "$(which …)"` loop body with `_run` |

Because dry-run makes all three checks pass, the existing v1 dry-run pilot tests keep
producing the same asserted strings (`DRY-RUN`, `fallocate`, `iptables`, …) and exit 0 —
no v1 test needs changing.

## Behavior change (intended, documented)

In **real** mode the pilots now:
- abort early with a clear error if not root (instead of failing messily mid-way);
- prompt y/N before acting (unless a TTY is absent → refuse, or `SHELLLIBS_ASSUME_YES=1`).

Automation that calls these non-interactively must set `SHELLLIBS_ASSUME_YES=1`. This is the
safety trade-off, by design.

## Testing — `tests/safetylib.bats` (extend)

Unit-test the 3 helpers (no root needed; bats `run` has no TTY, which is itself the no-TTY case):

- `_confirm`: dry-run → 0 (no read); `SHELLLIBS_ASSUME_YES=1` → 0; no-TTY (default under bats)
  → 1. (The interactive TTY read/parse branch is verified manually — a real TTY can't be
  allocated in bats; the safety-critical decision logic above is fully covered.)
- `_need_root`: mock `id() { echo 0; }` → 0; mock `id() { echo 1000; }` → 1; non-root +
  `SHELLLIBS_DRYRUN=1` → 0.
- `_need_cmd`: existing command → 0; missing → 1; no arg → 2; missing + `SHELLLIBS_DRYRUN=1` → 0.

Pilot suites (`admin.bats`/`disk-utils.bats`/`kvm-utils.bats`): confirm the existing dry-run
tests still pass unchanged; add one assertion (e.g. in `kvm-utils.bats`) that the dry-run
output contains the `would ask:` confirm line, proving `_confirm` is wired in.

`make test` runs the whole suite; `make lint-ci` must stay clean (no new shellcheck codes).

## Docs to update

- `README.md` — extend the "Safety / dry-run" section with `_confirm` / `_need_root` /
  `_need_cmd` and the `SHELLLIBS_ASSUME_YES` escape hatch.
- `CLAUDE.md` — extend the `safetylib` foundation bullet with the 3 helpers + `SHELLLIBS_ASSUME_YES`.
- `agent_docs/improvement-proposals.md` — update §12 (these helpers now done; note the
  remaining deferred items).
- `TODO.md` — check off the v2 items that ship here.

## Risks / trade-offs

- **Interactive read path untested** by bats (no TTY). Mitigated: the decision logic
  (dry-run/assume-yes/no-TTY) is unit-tested; the read+regex is thin and verified by hand.
- **Behavior change** for non-interactive callers (now need `SHELLLIBS_ASSUME_YES=1`) — intended, documented.
- **Partial coverage** — only the 5 v1 pilots get the new gates; the rest are the deferred sweep.
