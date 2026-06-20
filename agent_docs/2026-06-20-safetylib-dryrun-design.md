# Design — safetylib: a dry-run safety layer for shellLibs

**Date:** 2026-06-20
**Status:** approved design, pre-implementation
**Scope:** v1 — the `_run` mechanism + file-edit verbs, plus 5 pilot conversions.

## Problem

shellLibs is ~200 sourced bash functions for a Linux admin. Many mutate the system
irreversibly — append to `/etc/fstab` / `/etc/sudoers` / `/etc/network/interfaces`,
`rm -rf` as root, add `iptables` rules — with no preview, no backup, and (for the
file appends) no idempotency, so re-running a function silently duplicates entries.

There is no way to see *what a function would do* before it does it. For an admin
running these on a real server — and for the maintainer, who is learning shell — that
is the biggest risk and the biggest missing affordance.

## Goal (v1)

A **dry-run preview** layer: set one environment variable and any converted function
prints the commands and file edits it *would* perform, changing nothing.

The mechanism also folds in two adjacent safety wins for free, because the dangerous
operations are dominated by "append a line to /etc/X": **automatic backup** before
editing a system file, and **idempotent** appends (never duplicate a line).

### Non-goals (deferred to a later iteration)

- `_confirm` interactive y/N prompts + `SHELLLIBS_ASSUME_YES`.
- `_need_root` / `_need_cmd` preflight standardization.
- Converting all ~200 functions (v1 converts 5 pilots).
- Migrating `admin-user-add-to-sudo` to `/etc/sudoers.d` (that's a security item, §7 of
  improvement-proposals.md).

## Approach (chosen: C)

Considered three designs for the core helper:

- **A — argv passthrough** (`_run cmd args...`): safe (no `eval`), but can't express
  redirections/pipes like `echo x >> /etc/fstab`.
- **B — string + eval** (`_run "cmd string"`): handles redirects, but `eval` is fragile
  with spaces/special chars — the exact bug class this repo keeps hitting.
- **C — argv `_run` + dedicated file-edit verbs** (chosen): `_run` (argv) for commands,
  plus `_append_line` / `_write_file` for the file edits. Avoids `eval`, and turns the
  dangerous file-write paths into a small, clear API that carries backup + idempotency.

## Architecture

New foundation file **`scripts/safetylib`** — a third foundation peer to `logshell` and
`checksystem` (no `.sh` extension, matching the foundation files). It:

- sources `logshell` at the top (`source "$(which logshell)"`) to use `log-run` /
  `log-info` / `log-error`;
- defines functions only — **no side effects at source time** (repo invariant);
- `export -f`s its helpers, for parity with `logshell`.

**Control surface:** a single environment variable, `SHELLLIBS_DRYRUN`. Non-empty →
preview mode. The user sets it to preview a whole workflow, unsets it to execute.

**Invariant:** helpers never `exit` (a sourced file's `exit` kills the user's shell);
they always `return`.

## Components (the 4 helpers)

```bash
# 1) Run a command (argv — no eval). Returns the command's own exit status.
_run() {
  [[ $# -eq 0 ]] && { log-error "_run: no command given"; return 2; }
  if [[ -n ${SHELLLIBS_DRYRUN:-} ]]; then
    log-run "DRY-RUN would run: $(printf '%q ' "$@")"; return 0
  fi
  log-run "$(printf '%q ' "$@")"      # transparency: show the real command (gated by LOG_LEVEL)
  "$@"
}

# 2) Append one line — idempotent (whole-line match) + auto-backup before editing.
_append_line() {
  local file="$1" line="$2"
  [[ -z $file || -z $2 ]] && { log-error "Usage: _append_line <file> <line>"; return 2; }
  [[ -e $file ]] && grep -qxF -- "$line" "$file" && { log-info "already in ${file}, skip"; return 0; }
  [[ -n ${SHELLLIBS_DRYRUN:-} ]] && { log-run "DRY-RUN would append to ${file}: ${line}"; return 0; }
  _backup_file "$file"
  printf '%s\n' "$line" >>"$file" && log-info "appended to ${file}"
}

# 3) Overwrite a file, content from stdin — auto-backup.
_write_file() {
  local file="$1"; [[ -z $file ]] && { log-error "Usage: _write_file <file>  (content on stdin)"; return 2; }
  local content; content="$(cat)"
  [[ -n ${SHELLLIBS_DRYRUN:-} ]] && { log-run "DRY-RUN would write ${file} with:"; printf '%s\n' "$content"; return 0; }
  _backup_file "$file"
  printf '%s\n' "$content" >"$file" && log-info "wrote ${file}"
}

# 4) Back up <file> -> <file>.bak.<timestamp> (portable timestamp — no %N, per the logshell lesson).
_backup_file() {
  local f="$1"; [[ -z $f ]] && { log-error "_backup_file: no file given"; return 2; }
  [[ -e $f ]] || return 0          # nothing to back up (new file)
  local bak="${f}.bak.$(date +%Y%m%d%H%M%S)"
  [[ -n ${SHELLLIBS_DRYRUN:-} ]] && { log-run "DRY-RUN would back up ${f} -> ${bak}"; return 0; }
  cp -p "$f" "$bak" && log-info "backed up ${f} -> ${bak}"
}
```

### Contracts

| Helper | Args | Dry-run behavior | Normal behavior | Returns |
|---|---|---|---|---|
| `_run` | command + args | log "would run …", no exec | log + exec command | command's exit status (2 if no args) |
| `_append_line` | `<file> <line>` | log "would append …" | backup, then append if line absent | 0 (incl. skip), 2 on bad args |
| `_write_file` | `<file>` (+ stdin) | log "would write …" + show content | backup, then overwrite | 0, 2 on bad args |
| `_backup_file` | `<file>` | log "would back up …" | `cp -p` to timestamped copy | 0 (incl. no-op), 2 on bad args |

Notes:
- `_append_line` matches **whole lines** (`grep -qxF`) so idempotency is exact, not a
  substring accident.
- File-writing helpers require the caller to be root to write `/etc/*` (consistent with
  "most functions assume root"). Explicit preflight (`_need_root`) is deferred.
- `_write_file`'s `content="$(cat)"` strips trailing newlines; `printf` re-adds one.

## Pilot conversions (5)

Only the *mutating* calls are wrapped; read-only calls (`swapon --show`, `blkid`) stay
direct.

| Function | Change | Concrete win |
|---|---|---|
| `admin-swap-enable` | `fallocate`/`mkswap`/`swapon` → `_run`; fstab line → `_append_line` | preview; no duplicate fstab line on re-run |
| `disk-mount-partition` | `mount` → `_run`; fstab entry → `_append_line` | fixes a real bug: re-run no longer duplicates the fstab entry |
| `admin-user-add-to-sudo` | `usermod`/`apt` → `_run`; NOPASSWD line → `_append_line /etc/sudoers` | backup + idempotent before touching sudoers |
| `kvm-nat-port` | two `iptables` rules → `_run` | preview firewall changes before applying |
| `install.sh` | `rm -rf /bin/scripts` → `[[ -d /bin/scripts ]] && _run rm -rf /bin/scripts` | guard against catastrophic typo + dry-run. install.sh gains `source ./scripts/safetylib` (**relative path**, like its existing `source ./scripts/logshell` — `$(which …)` won't resolve on a first install) |

## Testing — `tests/safetylib.bats`

Unit-test the four helpers on temp-dir fixtures (no root needed):

- `_run`: dry-run does NOT execute (sentinel — `SHELLLIBS_DRYRUN=1 _run touch "$f"` leaves
  `$f` absent); normal mode executes (file created); returns child status (`_run false` → 1);
  no-args → 2.
- `_append_line`: appends when absent; **idempotent** (second call keeps the line count at
  1); dry-run leaves the file unchanged; creates a backup when the file already existed.
- `_write_file`: writes stdin content; dry-run leaves the file unchanged; backup created.
- `_backup_file`: creates a timestamped copy; portable timestamp (reuses the date lesson —
  no `%N`); no-op when the file is absent.

**Synergy worth highlighting:** dry-run makes the destructive pilots *testable*. E.g.
`SHELLLIBS_DRYRUN=1 run admin-swap-enable /tmp/sw 1G` → assert the output mentions
`fallocate` / `mkswap` / the fstab append, while the system stays untouched. Pilot tests
run safely on any host.

All tests follow the existing bats conventions (`load test_helper`, `BATS_TEST_TMPDIR`,
no bash-3.2-unsafe constructs). `make test` runs the whole suite.

## Docs to update

- `README.md` — a "Safety / dry-run" subsection: `SHELLLIBS_DRYRUN=1 <function>` previews.
- `CLAUDE.md` — document the convention: new destructive code must use
  `_run` / `_append_line` / `_write_file`; add `safetylib` to the foundation layer.
- `tests/README.md` — note the `safetylib` suite.
- `agent_docs/improvement-proposals.md` — new §12 marking this done.

## Risks / trade-offs

- **Behavior shift on pilots:** functions that previously used `sudo tee` (e.g.
  `admin-swap-enable`) will, via `_append_line`'s `>>`, require ambient root rather than
  self-`sudo`. Acceptable for a lib whose functions already assume root; called out so it
  isn't a surprise. (Explicit `_need_root` preflight is the deferred follow-up.)
- **Partial coverage:** only 5 of ~200 functions are converted in v1. The rest still
  behave as before. This is intentional — prove the pattern, then expand.
- **`grep -qxF` whole-line idempotency** won't catch a "same intent, different formatting"
  duplicate (e.g. extra spaces). Good enough for v1; documented.
