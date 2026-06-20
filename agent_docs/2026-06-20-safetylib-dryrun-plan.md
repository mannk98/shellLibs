# safetylib dry-run safety layer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dry-run safety layer (`scripts/safetylib`) so any converted shellLibs function can preview what it would do, and convert 5 high-risk functions to use it.

**Architecture:** A new foundation file `scripts/safetylib` provides `_run` (argv, no eval), `_append_line`/`_write_file` (idempotent + auto-backup file edits), and `_backup_file`. One env var, `SHELLLIBS_DRYRUN`, switches everything to preview mode. Five pilot functions are converted; their bats dry-run tests run safely on any host because dry-run touches nothing.

**Tech Stack:** Bash (3.2-compatible), bats-core 1.5+, shellcheck. Tests live in `tests/`, run via `make test`.

---

## Conventions used in every task

- **Guarded sibling-fallback loader** — the line a file uses to pull a dependency, working both installed (on PATH) and from the repo/tests:
  ```bash
  command -v <sentinel> >/dev/null 2>&1 || source "$(which <dep> 2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/<dep>")"
  ```
  Sentinels: `log-run` for `logshell`, `checkOsID` for `checksystem`, `_run` for `safetylib`.
- **Helpers never `exit`** (a sourced file's `exit` kills the user's shell) — always `return`.
- **Run tests** from the repo root with an absolute path: `bats /Users/man.nk/git/shellLibs/tests/<file>.bats` (the Bash tool's CWD is `/Users/man.nk/git`, not the repo).
- **Commit trailer** on every commit: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure

- **Create** `scripts/safetylib` — the 4 helpers + the logshell loader. One responsibility: safe/previewable execution.
- **Create** `tests/safetylib.bats` — unit tests for the 4 helpers.
- **Create** `tests/admin.bats`, `tests/disk-utils.bats`, `tests/kvm-utils.bats` — dry-run tests for the pilots.
- **Modify** `scripts/admin` (2 pilots), `scripts/disk-utils` (1), `scripts/kvm-utils` (1), `install.sh` (rm -rf guard).
- **Modify** docs: `README.md`, `CLAUDE.md`, `tests/README.md`, `agent_docs/improvement-proposals.md`.

---

## Task 1: `scripts/safetylib` skeleton + `_run`

**Files:**
- Create: `scripts/safetylib`
- Create: `tests/safetylib.bats`

- [ ] **Step 1: Write the failing tests for `_run`**

Create `tests/safetylib.bats`:
```bash
#!/usr/bin/env bats
#
# Unit tests for scripts/safetylib — dry-run-aware execution + safe file edits.
# All tests operate on temp-dir fixtures, so no root is needed.

bats_require_minimum_version 1.5.0

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/safetylib"
}

# --- _run ---

@test "_run executes the command in normal mode" {
  run _run touch "${BATS_TEST_TMPDIR}/created"
  [ "$status" -eq 0 ]
  [ -e "${BATS_TEST_TMPDIR}/created" ]
}

@test "_run in dry-run mode does NOT execute the command" {
  SHELLLIBS_DRYRUN=1 run _run touch "${BATS_TEST_TMPDIR}/nope"
  [ "$status" -eq 0 ]
  [ ! -e "${BATS_TEST_TMPDIR}/nope" ]
  [[ "$output" == *"DRY-RUN"* ]]
}

@test "_run returns the command's own exit status" {
  run _run false
  [ "$status" -eq 1 ]
}

@test "_run with no command returns 2" {
  run _run
  [ "$status" -eq 2 ]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`
Expected: FAIL — `setup` can't source `scripts/safetylib` (file doesn't exist yet).

- [ ] **Step 3: Create `scripts/safetylib` with the loader + `_run`**

Create `scripts/safetylib`:
```bash
#!/bin/bash
# safetylib — dry-run-aware command execution + safe file edits.
# Foundation peer to logshell/checksystem. Set SHELLLIBS_DRYRUN=1 to preview.
#
# No side effects at source time. Helpers never `exit` (sourced file) — only `return`.

# Load logshell once, whether installed (on PATH) or run from the repo/tests (sibling).
command -v log-run >/dev/null 2>&1 || source "$(which logshell 2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/logshell")"

# Run a command (argv — no eval). Returns the command's own exit status.
_run() {
  [[ $# -eq 0 ]] && { log-error "_run: no command given"; return 2; }
  if [[ -n ${SHELLLIBS_DRYRUN:-} ]]; then
    log-run "DRY-RUN would run: $(printf '%q ' "$@")"
    return 0
  fi
  log-run "$(printf '%q ' "$@")"
  "$@"
}

export -f _run
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`
Expected: 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/man.nk/git/shellLibs
git add scripts/safetylib tests/safetylib.bats
git commit -m "feat(safetylib): add _run with SHELLLIBS_DRYRUN" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `_backup_file`

**Files:**
- Modify: `scripts/safetylib`
- Modify: `tests/safetylib.bats`

- [ ] **Step 1: Add the failing tests for `_backup_file`**

Append to `tests/safetylib.bats`:
```bash
# --- _backup_file ---

@test "_backup_file copies an existing file to a timestamped backup" {
  local f="${BATS_TEST_TMPDIR}/conf"
  printf 'original\n' > "$f"
  run _backup_file "$f"
  [ "$status" -eq 0 ]
  local baks=( "${f}".bak.* )
  [ "${#baks[@]}" -eq 1 ]
  [ "$(cat "${baks[0]}")" = "original" ]
}

@test "_backup_file is a no-op when the file does not exist" {
  run _backup_file "${BATS_TEST_TMPDIR}/absent"
  [ "$status" -eq 0 ]
  local baks=( "${BATS_TEST_TMPDIR}/absent".bak.* )
  [ ! -e "${baks[0]}" ]
}

@test "_backup_file in dry-run does not create a backup" {
  local f="${BATS_TEST_TMPDIR}/conf"
  printf 'x\n' > "$f"
  SHELLLIBS_DRYRUN=1 run _backup_file "$f"
  [ "$status" -eq 0 ]
  local baks=( "${f}".bak.* )
  [ ! -e "${baks[0]}" ]
}

@test "_backup_file with no argument returns 2" {
  run _backup_file
  [ "$status" -eq 2 ]
}
```

- [ ] **Step 2: Run to verify the new tests fail**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`
Expected: the 4 `_backup_file` tests FAIL with `_backup_file: command not found` (the `_run` tests still pass).

- [ ] **Step 3: Implement `_backup_file`**

In `scripts/safetylib`, insert before `export -f _run`:
```bash
# Back up <file> -> <file>.bak.<timestamp> (portable timestamp, no %N). No-op if absent.
_backup_file() {
  local f="$1"
  [[ -z $f ]] && { log-error "_backup_file: no file given"; return 2; }
  [[ -e $f ]] || return 0
  local bak="${f}.bak.$(date +%Y%m%d%H%M%S)"
  if [[ -n ${SHELLLIBS_DRYRUN:-} ]]; then
    log-run "DRY-RUN would back up ${f} -> ${bak}"
    return 0
  fi
  cp -p "$f" "$bak" && log-info "backed up ${f} -> ${bak}"
}
```
and change the export line to:
```bash
export -f _run _backup_file
```

- [ ] **Step 4: Run to verify all pass**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`
Expected: 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/man.nk/git/shellLibs
git add scripts/safetylib tests/safetylib.bats
git commit -m "feat(safetylib): add _backup_file" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `_append_line`

**Files:**
- Modify: `scripts/safetylib`
- Modify: `tests/safetylib.bats`

- [ ] **Step 1: Add the failing tests for `_append_line`**

Append to `tests/safetylib.bats`:
```bash
# --- _append_line ---

@test "_append_line appends a line when absent" {
  local f="${BATS_TEST_TMPDIR}/fstab"
  printf 'existing\n' > "$f"
  run _append_line "$f" "newline"
  [ "$status" -eq 0 ]
  grep -qxF "newline" "$f"
}

@test "_append_line is idempotent (no duplicate on second call)" {
  local f="${BATS_TEST_TMPDIR}/fstab"
  printf 'existing\n' > "$f"
  _append_line "$f" "dup"
  _append_line "$f" "dup"
  run grep -cxF "dup" "$f"
  [ "$output" -eq 1 ]
}

@test "_append_line in dry-run does not modify the file" {
  local f="${BATS_TEST_TMPDIR}/fstab"
  printf 'existing\n' > "$f"
  SHELLLIBS_DRYRUN=1 run _append_line "$f" "nope"
  [ "$status" -eq 0 ]
  run grep -qxF "nope" "$f"
  [ "$status" -ne 0 ]
}

@test "_append_line backs up the file before appending" {
  local f="${BATS_TEST_TMPDIR}/fstab"
  printf 'existing\n' > "$f"
  _append_line "$f" "added"
  local baks=( "${f}".bak.* )
  [ "${#baks[@]}" -eq 1 ]
}

@test "_append_line with missing args returns 2" {
  run _append_line "${BATS_TEST_TMPDIR}/x"
  [ "$status" -eq 2 ]
}
```

- [ ] **Step 2: Run to verify the new tests fail**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`
Expected: the 5 `_append_line` tests FAIL with `_append_line: command not found`.

- [ ] **Step 3: Implement `_append_line`**

In `scripts/safetylib`, insert before the `export -f` line:
```bash
# Append one line to a file, idempotently (whole-line match), backing up first.
_append_line() {
  local file="$1" line="$2"
  [[ -z $file || -z $2 ]] && { log-error "Usage: _append_line <file> <line>"; return 2; }
  if [[ -e $file ]] && grep -qxF -- "$line" "$file"; then
    log-info "_append_line: already in ${file}, skipping"
    return 0
  fi
  if [[ -n ${SHELLLIBS_DRYRUN:-} ]]; then
    log-run "DRY-RUN would append to ${file}: ${line}"
    return 0
  fi
  _backup_file "$file"
  printf '%s\n' "$line" >>"$file" && log-info "appended to ${file}: ${line}"
}
```
and update the export line to:
```bash
export -f _run _backup_file _append_line
```

- [ ] **Step 4: Run to verify all pass**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`
Expected: 13 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/man.nk/git/shellLibs
git add scripts/safetylib tests/safetylib.bats
git commit -m "feat(safetylib): add idempotent _append_line" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: `_write_file`

**Files:**
- Modify: `scripts/safetylib`
- Modify: `tests/safetylib.bats`

- [ ] **Step 1: Add the failing tests for `_write_file`**

Append to `tests/safetylib.bats`:
```bash
# --- _write_file ---

@test "_write_file writes stdin content to the file" {
  local f="${BATS_TEST_TMPDIR}/out"
  run _write_file "$f" <<< "hello content"
  [ "$status" -eq 0 ]
  [ "$(cat "$f")" = "hello content" ]
}

@test "_write_file in dry-run does not create the file" {
  local f="${BATS_TEST_TMPDIR}/out"
  SHELLLIBS_DRYRUN=1 run _write_file "$f" <<< "nope"
  [ "$status" -eq 0 ]
  [ ! -e "$f" ]
  [[ "$output" == *"nope"* ]]
}

@test "_write_file backs up an existing file before overwriting" {
  local f="${BATS_TEST_TMPDIR}/out"
  printf 'old\n' > "$f"
  _write_file "$f" <<< "new"
  local baks=( "${f}".bak.* )
  [ "${#baks[@]}" -eq 1 ]
  [ "$(cat "${baks[0]}")" = "old" ]
  [ "$(cat "$f")" = "new" ]
}

@test "_write_file with no argument returns 2" {
  run _write_file <<< "x"
  [ "$status" -eq 2 ]
}
```

- [ ] **Step 2: Run to verify the new tests fail**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`
Expected: the 4 `_write_file` tests FAIL with `_write_file: command not found`.

- [ ] **Step 3: Implement `_write_file`**

In `scripts/safetylib`, insert before the `export -f` line:
```bash
# Overwrite a file with content from stdin, backing up first.
_write_file() {
  local file="$1"
  [[ -z $file ]] && { log-error "Usage: _write_file <file>  (content on stdin)"; return 2; }
  local content; content="$(cat)"
  if [[ -n ${SHELLLIBS_DRYRUN:-} ]]; then
    log-run "DRY-RUN would write ${file} with:"
    printf '%s\n' "$content"
    return 0
  fi
  _backup_file "$file"
  printf '%s\n' "$content" >"$file" && log-info "wrote ${file}"
}
```
and update the export line to:
```bash
export -f _run _backup_file _append_line _write_file
```

- [ ] **Step 4: Run to verify all pass**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`
Expected: 17 tests PASS.

- [ ] **Step 5: shellcheck the new file, then commit**

```bash
cd /Users/man.nk/git/shellLibs
shellcheck --shell=bash scripts/safetylib   # expect: clean (no output)
git add scripts/safetylib tests/safetylib.bats
git commit -m "feat(safetylib): add _write_file" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Pilot — `scripts/admin` (`admin-swap-enable` + `admin-user-add-to-sudo`)

**Files:**
- Modify: `scripts/admin` (header source lines; `admin-swap-enable`; `admin-user-add-to-sudo`)
- Create: `tests/admin.bats`

- [ ] **Step 1: Write the failing dry-run tests**

Create `tests/admin.bats`:
```bash
#!/usr/bin/env bats
#
# Dry-run pilot tests for scripts/admin. These never touch the real system because
# SHELLLIBS_DRYRUN=1 makes every mutating call a no-op preview.

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/admin"
}

@test "admin-swap-enable (dry-run) previews fallocate + fstab append, touches nothing" {
  SHELLLIBS_DRYRUN=1 run admin-swap-enable "${BATS_TEST_TMPDIR}/swap" 1G
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
  [[ "$output" == *"fallocate"* ]]
  [[ "$output" == *"/etc/fstab"* ]]
  [ ! -e "${BATS_TEST_TMPDIR}/swap" ]
}

@test "admin-user-add-to-sudo (dry-run) previews the sudoers append, touches nothing" {
  SHELLLIBS_DRYRUN=1 run admin-user-add-to-sudo someuser
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
  [[ "$output" == *"/etc/sudoers"* ]]
}

@test "admin-swap-enable -h prints usage" {
  run admin-swap-enable -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `bats /Users/man.nk/git/shellLibs/tests/admin.bats`
Expected: FAIL — the dry-run tests see real command output / no "DRY-RUN" because `admin` doesn't use `_run`/`_append_line` yet (and may try real `swapon`). The `-h` test passes.

- [ ] **Step 3: Update `scripts/admin` header to the guarded loaders**

Replace lines 3-4 of `scripts/admin`:
```bash
source "$(which logshell)"
source "$(which checksystem)"
```
with:
```bash
command -v log-run  >/dev/null 2>&1 || source "$(which logshell    2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/logshell")"
command -v checkOsID >/dev/null 2>&1 || source "$(which checksystem 2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/checksystem")"
command -v _run     >/dev/null 2>&1 || source "$(which safetylib   2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/safetylib")"
```

- [ ] **Step 4: Convert `admin-swap-enable`'s mutating calls**

In `scripts/admin`, inside `admin-swap-enable`, replace this block:
```bash
  fallocate -l "${sizeSwap}" "${pathSwap}"
  chmod 600 "${pathSwap}"
  mkswap "${pathSwap}"
  swapon "${pathSwap}"
  echo "${pathSwap} none swap sw 0 0" | sudo tee -a /etc/fstab
```
with:
```bash
  _run fallocate -l "${sizeSwap}" "${pathSwap}"
  _run chmod 600 "${pathSwap}"
  _run mkswap "${pathSwap}"
  _run swapon "${pathSwap}"
  _append_line /etc/fstab "${pathSwap} none swap sw 0 0"
```

- [ ] **Step 5: Convert `admin-user-add-to-sudo`'s mutating calls**

In `scripts/admin`, inside `admin-user-add-to-sudo`, replace:
```bash
  apt install sudo &>/dev/null
  if ! usermod -aG sudo "${username}"; then
    echo "This script need sudo permission to execute."
  fi
  if echo "${username} ALL=(ALL:ALL) NOPASSWD:ALL" >>/etc/sudoers; then
    echo "Done add user to sudo group and enable sudo without password."
  fi
```
with:
```bash
  _run apt install sudo &>/dev/null
  if ! _run usermod -aG sudo "${username}"; then
    echo "This script need sudo permission to execute."
  fi
  _append_line /etc/sudoers "${username} ALL=(ALL:ALL) NOPASSWD:ALL" \
    && echo "Done add user to sudo group and enable sudo without password."
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bats /Users/man.nk/git/shellLibs/tests/admin.bats`
Expected: 3 tests PASS.

- [ ] **Step 7: shellcheck + commit**

```bash
cd /Users/man.nk/git/shellLibs
shellcheck --shell=bash scripts/admin   # expect: no NEW findings vs baseline
git add scripts/admin tests/admin.bats
git commit -m "feat(admin): dry-run-safe swap-enable and user-add-to-sudo" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Pilot — `scripts/disk-utils` (`disk-mount-partition`)

**Files:**
- Modify: `scripts/disk-utils` (header; `disk-mount-partition`)
- Create: `tests/disk-utils.bats`

- [ ] **Step 1: Write the failing dry-run test**

Create `tests/disk-utils.bats`:
```bash
#!/usr/bin/env bats
#
# Dry-run pilot tests for scripts/disk-utils.

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/disk-utils"
}

@test "disk-mount-partition -h prints usage" {
  run disk-mount-partition -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "disk-mount-partition (dry-run) previews the mount, runs nothing" {
  # Pick any existing block device so the [[ -b ]] guard passes; dry-run does no I/O.
  # After the dry-run mount no-ops, the real blkid UUID lookup returns empty and the
  # function returns 1 before the fstab step — so assert only the mount preview (the
  # fstab idempotency is covered by the _append_line unit tests in Task 3).
  local dev
  dev="$(ls /dev/disk0 /dev/sda /dev/vda 2>/dev/null | head -n1)"
  [ -n "$dev" ] || skip "no block device available to exercise the guard"
  SHELLLIBS_DRYRUN=1 run disk-mount-partition "$dev" "${BATS_TEST_TMPDIR}/mnt" ext4
  [[ "$output" == *"DRY-RUN"* ]]
  [[ "$output" == *"mount"* ]]
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats /Users/man.nk/git/shellLibs/tests/disk-utils.bats`
Expected: the dry-run test FAILS (no "DRY-RUN" in output — not yet converted). The `-h` test passes. (The dry-run test may `skip` if no block device; on macOS `/dev/disk0` exists.)

- [ ] **Step 3: Update `scripts/disk-utils` header to guarded loaders**

Replace line 3 of `scripts/disk-utils`:
```bash
source "$(which logshell)"
```
with:
```bash
command -v log-run >/dev/null 2>&1 || source "$(which logshell  2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/logshell")"
command -v _run    >/dev/null 2>&1 || source "$(which safetylib 2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/safetylib")"
```

- [ ] **Step 4: Convert `disk-mount-partition`'s mutating calls**

In `scripts/disk-utils`, inside `disk-mount-partition`, replace:
```bash
  if ! mount "$partition" "$mount_point"; then
    echo "Error: Failed to mount $partition to $mount_point."
    return 1
  fi
```
with:
```bash
  if ! _run mount "$partition" "$mount_point"; then
    echo "Error: Failed to mount $partition to $mount_point."
    return 1
  fi
```
and replace:
```bash
  echo "Adding $partition to /etc/fstab..."
  fstab_entry="UUID=$disk_uuid $mount_point $format defaults 0 2"
  echo "$fstab_entry" | tee -a /etc/fstab
```
with:
```bash
  echo "Adding $partition to /etc/fstab..."
  fstab_entry="UUID=$disk_uuid $mount_point $format defaults 0 2"
  _append_line /etc/fstab "$fstab_entry"
```

> Note: this is why the Task-6 dry-run test asserts only the `mount` preview — after the
> dry-run `mount` no-ops, the real `blkid` lookup returns empty and the function returns
> 1 before the fstab step. The fstab idempotency is covered by the `_append_line` unit
> tests in Task 3.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bats /Users/man.nk/git/shellLibs/tests/disk-utils.bats`
Expected: tests PASS (or `skip` if no block device).

- [ ] **Step 6: shellcheck + commit**

```bash
cd /Users/man.nk/git/shellLibs
shellcheck --shell=bash scripts/disk-utils   # expect: no NEW findings
git add scripts/disk-utils tests/disk-utils.bats
git commit -m "feat(disk-utils): dry-run-safe, idempotent disk-mount-partition" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Pilot — `scripts/kvm-utils` (`kvm-nat-port`)

**Files:**
- Modify: `scripts/kvm-utils` (header; `kvm-nat-port`)
- Create: `tests/kvm-utils.bats`

- [ ] **Step 1: Write the failing dry-run test**

Create `tests/kvm-utils.bats`:
```bash
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
  [[ "$output" == *"Use:"* ]]
}

@test "kvm-nat-port (dry-run) previews both iptables rules, runs nothing" {
  SHELLLIBS_DRYRUN=1 run kvm-nat-port virbr0 192.168.122.10 3389 3389
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
  [[ "$output" == *"iptables"* ]]
  [[ "$output" == *"PREROUTING"* ]]
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats /Users/man.nk/git/shellLibs/tests/kvm-utils.bats`
Expected: the dry-run test FAILS (no "DRY-RUN"; would try real `iptables`). The `-h` test passes.

- [ ] **Step 3: Add the guarded safetylib loader to `scripts/kvm-utils`**

In `scripts/kvm-utils`, immediately after the `#!/bin/bash` line, add:
```bash

command -v _run >/dev/null 2>&1 || source "$(which safetylib 2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/safetylib")"
```

- [ ] **Step 4: Fix the `-h` guard (missing `return 0`) and convert the iptables calls**

`kvm-nat-port`'s `-h` guard lacks a `return`, so `kvm-nat-port -h` falls through into the
iptables calls (real `sudo iptables` on Linux). Fix that first. In `scripts/kvm-utils`,
inside `kvm-nat-port`, replace the usage guard:
```bash
  [[ $1 == "-h" || -z $1 ]] && {
    echo "Use: ${FUNCNAME[0]} <virbr_of_vm> <ip_of_vm> <port_vm> <port_host>
    Example: ${FUNCNAME[0]} virbr0 192.168.122.10 3389 3389"
  }
```
with:
```bash
  [[ $1 == "-h" || -z $1 ]] && {
    echo "Use: ${FUNCNAME[0]} <virbr_of_vm> <ip_of_vm> <port_vm> <port_host>
    Example: ${FUNCNAME[0]} virbr0 192.168.122.10 3389 3389"
    return 0
  }
```
Then replace the two iptables calls:
```bash
  sudo iptables -I FORWARD -o "${virbr_of_vm}" -d "${ip_of_vm}" -p tcp --dport "${port_vm}" -j ACCEPT
  sudo iptables -t nat -I PREROUTING -p tcp --dport "${port_host}" -j DNAT --to "192.168.122.10:${port_vm}"
```
with:
```bash
  _run sudo iptables -I FORWARD -o "${virbr_of_vm}" -d "${ip_of_vm}" -p tcp --dport "${port_vm}" -j ACCEPT
  _run sudo iptables -t nat -I PREROUTING -p tcp --dport "${port_host}" -j DNAT --to "192.168.122.10:${port_vm}"
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bats /Users/man.nk/git/shellLibs/tests/kvm-utils.bats`
Expected: 2 tests PASS.

- [ ] **Step 6: shellcheck + commit**

```bash
cd /Users/man.nk/git/shellLibs
shellcheck --shell=bash scripts/kvm-utils   # expect: clean
git add scripts/kvm-utils tests/kvm-utils.bats
git commit -m "feat(kvm-utils): dry-run-safe kvm-nat-port iptables rules" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Pilot — `install.sh` (guard + dry-run the `rm -rf`)

**Files:**
- Modify: `install.sh`

No bats test: `install.sh` runs top-level side effects (copies into `/bin`, needs root) and cannot be sourced safely. Verified by reading + shellcheck + a manual dry-run.

- [ ] **Step 1: Source safetylib (relative path) in `install.sh`**

In `install.sh`, after the existing:
```bash
source ./scripts/logshell
source ./scripts/checksystem
```
add:
```bash
source ./scripts/safetylib
```
(Relative path — `$(which …)` won't resolve on a first install, before files reach `/bin/scripts`.)

- [ ] **Step 2: Guard + dry-run the `rm -rf`**

In `install.sh`, replace:
```bash
log-info "Delete old source at /bin"
rm -rf /bin/scripts
```
with:
```bash
log-info "Delete old source at /bin"
[[ -d /bin/scripts ]] && _run rm -rf /bin/scripts
```

- [ ] **Step 3: shellcheck install.sh**

Run: `cd /Users/man.nk/git/shellLibs && shellcheck --shell=bash install.sh`
Expected: no NEW findings vs the baseline (the existing SC2088/SC2016 per-line disables remain).

- [ ] **Step 4: Manual dry-run smoke (no system change)**

Run: `cd /Users/man.nk/git/shellLibs && SHELLLIBS_DRYRUN=1 bash -c 'source ./scripts/logshell; source ./scripts/safetylib; [[ -d /bin/scripts ]] && _run rm -rf /bin/scripts; echo "exit=$?"'`
Expected: prints `DRY-RUN would run: rm -rf /bin/scripts` (if `/bin/scripts` exists) or nothing (if not), and `exit=0`. `/bin/scripts` is NOT removed.

- [ ] **Step 5: Commit**

```bash
cd /Users/man.nk/git/shellLibs
git add install.sh
git commit -m "fix(install): guard and dry-run the rm -rf of /bin/scripts" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: Documentation

**Files:**
- Modify: `README.md`, `CLAUDE.md`, `tests/README.md`, `agent_docs/improvement-proposals.md`

- [ ] **Step 1: Full green gate before documenting**

Run: `bats /Users/man.nk/git/shellLibs/tests/`
Expected: all suites PASS (foundation + safetylib + the 3 pilot suites).
Run: `cd /Users/man.nk/git/shellLibs && make lint`
Expected: only the known 11 SC2015 findings; no new codes.

- [ ] **Step 2: Add a "Safety / dry-run" subsection to `README.md`**

In `README.md`, immediately under the `## Caveats / known rough edges` heading's preceding section (i.e., right after the `## Conventions` section, before `## Linting`), insert:
```markdown
## Safety / dry-run

Converted functions honour a global preview switch. Set `SHELLLIBS_DRYRUN` to any
non-empty value and they print the commands and file edits they *would* perform —
changing nothing:

```bash
SHELLLIBS_DRYRUN=1 admin-swap-enable /swapfile 2G   # preview, runs nothing
admin-swap-enable /swapfile 2G                       # actually do it
```

Under the hood, functions route destructive work through `_run` (run a command),
`_append_line` / `_write_file` (edit a file — idempotent, with an automatic
`*.bak.<timestamp>` backup), all defined in `scripts/safetylib`. New destructive code
should use these helpers. Converted so far: `admin-swap-enable`,
`admin-user-add-to-sudo`, `disk-mount-partition`, `kvm-nat-port`, and `install.sh`.
```

- [ ] **Step 3: Document the convention in `CLAUDE.md`**

In `CLAUDE.md`, in the "Foundation layer" list, add a third bullet:
```markdown
- `safetylib` — dry-run + safe file edits. `_run <cmd...>` (argv, no eval),
  `_append_line <file> <line>` and `_write_file <file>` (idempotent, auto-backup),
  `_backup_file`. All honour `SHELLLIBS_DRYRUN`. New destructive code (rm, fstab/sudoers
  edits, iptables, …) MUST route through these instead of running the command directly.
```

- [ ] **Step 4: Note the new suites in `tests/README.md`**

In `tests/README.md`, in the "What's here" table, add rows:
```markdown
| `safetylib.bats` | `_run`, `_append_line`, `_write_file`, `_backup_file` (dry-run + backup + idempotency). |
| `admin.bats`, `disk-utils.bats`, `kvm-utils.bats` | Dry-run pilot tests — verify converted functions preview safely. |
```

- [ ] **Step 5: Add `## 12` to `agent_docs/improvement-proposals.md`**

In `agent_docs/improvement-proposals.md`, before `## My suggested order`, insert:
```markdown
## 12. Dry-run safety layer (safetylib)  ✅ v1 done

**Effort:** M — **Risk:** low — **Value:** high — **Status:** v1 shipped

New `scripts/safetylib` foundation file: `_run` (argv, no eval), `_append_line` /
`_write_file` (idempotent, auto-backup), `_backup_file`, all gated by `SHELLLIBS_DRYRUN`.
Pilots converted: `admin-swap-enable`, `admin-user-add-to-sudo`, `disk-mount-partition`,
`kvm-nat-port`, `install.sh` (rm -rf now guarded + previewable). Tests in
`tests/safetylib.bats` + per-pilot dry-run suites. Design: `2026-06-20-safetylib-dryrun-design.md`.

Open (next): `_confirm` + `SHELLLIBS_ASSUME_YES`; `_need_root` / `_need_cmd`; convert the
remaining destructive functions; `admin-user-add-to-sudo` → `/etc/sudoers.d` (see §7).

---
```

- [ ] **Step 6: Commit the docs**

```bash
cd /Users/man.nk/git/shellLibs
git add README.md CLAUDE.md tests/README.md agent_docs/improvement-proposals.md
git commit -m "docs: document the safetylib dry-run layer" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Final verification

- [ ] Run the whole suite: `bats /Users/man.nk/git/shellLibs/tests/` → all PASS.
- [ ] Lint: `cd /Users/man.nk/git/shellLibs && make lint` → only the known 11 SC2015, no new codes.
- [ ] `git log --oneline -9` shows the 8 feature/fix/docs commits from this plan.
- [ ] Manual dry-run demo: `SHELLLIBS_DRYRUN=1 bash -c 'source scripts/logshell; source scripts/safetylib; source scripts/admin; admin-swap-enable /tmp/sw 1G'` prints DRY-RUN lines and creates no `/tmp/sw`.

## Self-review notes (spec coverage)

- `_run`, `_append_line`, `_write_file`, `_backup_file`, `SHELLLIBS_DRYRUN`, no source-time side effects, never-`exit` → Tasks 1-4. ✓
- 5 pilots (admin×2, disk-utils, kvm-utils, install.sh) → Tasks 5-8. ✓
- Tests incl. the "dry-run makes pilots testable" synergy → Tasks 5-7. ✓
- Docs (README, CLAUDE.md, tests/README, §12) → Task 9. ✓
- Deferred items (`_confirm`, `_need_root`, full conversion, sudoers.d) recorded in §12, not implemented. ✓
- Refinement beyond spec: guarded sibling-fallback loaders on safetylib + pilot files (required for testability without install; a clean robustness upgrade). Documented here and in each task.
