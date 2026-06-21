# safetylib v2 (confirm + preflight) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `_confirm` (+ `SHELLLIBS_ASSUME_YES`) and `_need_root` / `_need_cmd` preflight helpers to `scripts/safetylib`, and wire all three into the 5 v1 pilots + the install.sh apt-port `rm`.

**Architecture:** Three new helpers in the existing `scripts/safetylib`. All are **advisory in dry-run** (they pass with a warning) and enforce only in real mode — so dry-run previews still work on any host and the v1 dry-run tests keep passing. Each pilot gains `_need_root` / `_need_cmd` / `_confirm` after its usage guard.

**Tech Stack:** Bash (3.2-compatible), bats-core 1.5+, shellcheck. Tests in `tests/`, run via `make test`; CI gate `make lint-ci`.

---

## Conventions (every task)

- Repo `/Users/man.nk/git/shellLibs`. Work on the feature branch (the controller creates it); do NOT switch branches.
- Run bats with an absolute path: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`. `cd /Users/man.nk/git/shellLibs` for git/make/shellcheck.
- The pilots already source `safetylib` (v1), so the new helpers are available there with no loader change.
- Helpers never `exit` — only `return`. Success paths that end in a log call need care, but these helpers all end in explicit `return` already.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## File Structure

- **Modify** `scripts/safetylib` — add `_confirm`, `_need_root`, `_need_cmd` (+ export line).
- **Modify** `tests/safetylib.bats` — unit tests for the three helpers.
- **Modify** `scripts/admin`, `scripts/disk-utils`, `scripts/kvm-utils` — wire the gates into the 4 pilot functions.
- **Modify** `tests/admin.bats`, `tests/disk-utils.bats`, `tests/kvm-utils.bats` — assert the confirm line appears in dry-run.
- **Modify** `install.sh` — wrap the apt-port `rm -f` in `_run`.
- **Modify** docs: `README.md`, `CLAUDE.md`, `agent_docs/improvement-proposals.md`, `TODO.md`.

---

## Task 1: `_confirm`

**Files:** Modify `scripts/safetylib`; Modify `tests/safetylib.bats`

- [ ] **Step 1: Add the failing tests**

Append to `tests/safetylib.bats`:
```bash
# --- _confirm ---

@test "_confirm in dry-run passes without prompting" {
  SHELLLIBS_DRYRUN=1 run _confirm "do thing?"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would ask"* ]]
}

@test "_confirm with SHELLLIBS_ASSUME_YES passes without prompting" {
  SHELLLIBS_ASSUME_YES=1 run _confirm "do thing?"
  [ "$status" -eq 0 ]
}

@test "_confirm with no TTY and no ASSUME_YES refuses (returns 1)" {
  run _confirm "do thing?"
  [ "$status" -eq 1 ]
  [[ "$output" == *"refused"* ]]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`
Expected: the 3 `_confirm` tests FAIL with `_confirm: command not found`.

- [ ] **Step 3: Implement `_confirm`**

In `scripts/safetylib`, insert before the `export -f` line:
```bash
# Ask for y/N confirmation before a destructive op.
# dry-run -> pass; ASSUME_YES -> pass; TTY -> prompt; no TTY -> refuse. 0 = proceed, 1 = abort.
_confirm() {
  local prompt="${1:-Proceed?}" reply
  [[ -n ${SHELLLIBS_DRYRUN:-} ]] && { log-run "DRY-RUN would ask: ${prompt}"; return 0; }
  [[ -n ${SHELLLIBS_ASSUME_YES:-} ]] && { log-info "assume-yes: ${prompt}"; return 0; }
  [[ ! -t 0 ]] && { log-warning "${prompt} — refused (no TTY; set SHELLLIBS_ASSUME_YES=1)"; return 1; }
  read -rp "${prompt} [y/N] " reply
  [[ ${reply} =~ ^[Yy]([Ee][Ss])?$ ]] && return 0
  log-info "aborted: ${prompt}"; return 1
}
```
and change the `export -f` line to include `_confirm`:
```bash
export -f _run _backup_file _append_line _write_file _confirm
```

- [ ] **Step 4: Run to verify all pass**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`
Expected: all pass (18 previous + 3 new = 21).

- [ ] **Step 5: Commit**

```bash
cd /Users/man.nk/git/shellLibs
git add scripts/safetylib tests/safetylib.bats
git commit -m "feat(safetylib): add _confirm with SHELLLIBS_ASSUME_YES" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `_need_root`

**Files:** Modify `scripts/safetylib`; Modify `tests/safetylib.bats`

- [ ] **Step 1: Add the failing tests**

Append to `tests/safetylib.bats`:
```bash
# --- _need_root ---

@test "_need_root succeeds for root (mocked id)" {
  id() { echo 0; }
  run _need_root
  [ "$status" -eq 0 ]
}

@test "_need_root fails for non-root (mocked id)" {
  id() { echo 1000; }
  run _need_root
  [ "$status" -eq 1 ]
  [[ "$output" == *"needs root"* ]]
}

@test "_need_root in dry-run passes for non-root (mocked id)" {
  id() { echo 1000; }
  SHELLLIBS_DRYRUN=1 run _need_root
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`
Expected: the 3 `_need_root` tests FAIL with `_need_root: command not found`.

- [ ] **Step 3: Implement `_need_root`**

In `scripts/safetylib`, insert before the `export -f` line:
```bash
# Require root (uses `id -u`, correct under sudo). Advisory (pass) in dry-run.
_need_root() {
  [[ "$(id -u)" -eq 0 ]] && return 0
  [[ -n ${SHELLLIBS_DRYRUN:-} ]] && { log-warning "(dry-run) ${FUNCNAME[1]:-cmd} would require root"; return 0; }
  log-error "${FUNCNAME[1]:-command} needs root (run with sudo)"; return 1
}
```
and update the `export -f` line to add `_need_root`:
```bash
export -f _run _backup_file _append_line _write_file _confirm _need_root
```

- [ ] **Step 4: Run to verify all pass**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`
Expected: 24 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/man.nk/git/shellLibs
git add scripts/safetylib tests/safetylib.bats
git commit -m "feat(safetylib): add _need_root preflight" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `_need_cmd`

**Files:** Modify `scripts/safetylib`; Modify `tests/safetylib.bats`

- [ ] **Step 1: Add the failing tests**

Append to `tests/safetylib.bats`:
```bash
# --- _need_cmd ---

@test "_need_cmd succeeds for an existing command" {
  run _need_cmd bash
  [ "$status" -eq 0 ]
}

@test "_need_cmd fails for a missing command" {
  run _need_cmd definitely_not_a_real_command_xyz
  [ "$status" -eq 1 ]
  [[ "$output" == *"not installed"* ]]
}

@test "_need_cmd with no argument returns 2" {
  run _need_cmd
  [ "$status" -eq 2 ]
}

@test "_need_cmd in dry-run passes for a missing command" {
  SHELLLIBS_DRYRUN=1 run _need_cmd definitely_not_a_real_command_xyz
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats`
Expected: the 4 `_need_cmd` tests FAIL with `_need_cmd: command not found`.

- [ ] **Step 3: Implement `_need_cmd`**

In `scripts/safetylib`, insert before the `export -f` line:
```bash
# Require a command to exist. Advisory (pass) in dry-run.
_need_cmd() {
  [[ -z $1 ]] && { log-error "_need_cmd: no command given"; return 2; }
  command -v "$1" >/dev/null 2>&1 && return 0
  [[ -n ${SHELLLIBS_DRYRUN:-} ]] && { log-warning "(dry-run) ${FUNCNAME[1]:-cmd} would require '$1'"; return 0; }
  log-error "${FUNCNAME[1]:-command} needs '$1' which is not installed"; return 1
}
```
and update the `export -f` line to add `_need_cmd`:
```bash
export -f _run _backup_file _append_line _write_file _confirm _need_root _need_cmd
```

- [ ] **Step 4: Run + shellcheck, verify all pass**

Run: `bats /Users/man.nk/git/shellLibs/tests/safetylib.bats` → expect 28 tests pass.
Run: `shellcheck --shell=bash scripts/safetylib` → expect clean.

- [ ] **Step 5: Commit**

```bash
cd /Users/man.nk/git/shellLibs
git add scripts/safetylib tests/safetylib.bats
git commit -m "feat(safetylib): add _need_cmd preflight" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Wire gates into `scripts/admin` (swap-enable + user-add-to-sudo)

**Files:** Modify `scripts/admin`; Modify `tests/admin.bats`

- [ ] **Step 1: Strengthen the admin dry-run tests (TDD — assert the confirm line)**

In `tests/admin.bats`, add one assertion to EACH of the two dry-run tests.

In `admin-swap-enable (dry-run) previews ...`, after the existing `[[ "$output" == *"/etc/fstab"* ]]` line, add:
```bash
  [[ "$output" == *"would ask"* ]]
```
In `admin-user-add-to-sudo (dry-run) previews ...`, after the existing `[[ "$output" == *"/etc/sudoers"* ]]` line, add:
```bash
  [[ "$output" == *"would ask"* ]]
```

- [ ] **Step 2: Run to verify the new assertions fail**

Run: `bats /Users/man.nk/git/shellLibs/tests/admin.bats`
Expected: the two dry-run tests FAIL (`would ask` not in output — confirm not wired yet). The `-h` test passes.

- [ ] **Step 3: Wire `admin-swap-enable`**

In `scripts/admin`, find this line inside `admin-swap-enable`:
```bash
  echo "List swapfile on this system:"
```
and insert the three gates immediately BEFORE it:
```bash
  _need_root || return 1
  _need_cmd mkswap || return 1
  _confirm "Create ${sizeSwap} swapfile at ${pathSwap} and add it to /etc/fstab?" || return 1

  echo "List swapfile on this system:"
```

- [ ] **Step 4: Wire `admin-user-add-to-sudo`**

In `scripts/admin`, find this line inside `admin-user-add-to-sudo`:
```bash
  _run apt install sudo &>/dev/null
```
and insert the gates immediately BEFORE it:
```bash
  _need_root || return 1
  _confirm "Grant '${username}' passwordless sudo (NOPASSWD:ALL in /etc/sudoers)?" || return 1

  _run apt install sudo &>/dev/null
```

- [ ] **Step 5: Run tests + shellcheck**

Run: `bats /Users/man.nk/git/shellLibs/tests/admin.bats` → expect 3/3 pass.
Run: `shellcheck --shell=bash scripts/admin` → expect no new findings.

- [ ] **Step 6: Commit**

```bash
cd /Users/man.nk/git/shellLibs
git add scripts/admin tests/admin.bats
git commit -m "feat(admin): gate swap-enable and user-add-to-sudo with preflight + confirm" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Wire gates into `scripts/disk-utils` (disk-mount-partition)

**Files:** Modify `scripts/disk-utils`; Modify `tests/disk-utils.bats`

- [ ] **Step 1: Strengthen the disk dry-run test**

In `tests/disk-utils.bats`, in the `disk-mount-partition (dry-run) ...` test, after the existing `[[ "$output" == *"mount"* ]]` line, add:
```bash
  [[ "$output" == *"would ask"* ]]
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats /Users/man.nk/git/shellLibs/tests/disk-utils.bats`
Expected: the dry-run test FAILS (`would ask` not present); `-h` passes. (May `skip` if no block device.)

- [ ] **Step 3: Wire `disk-mount-partition`**

In `scripts/disk-utils`, find this line inside `disk-mount-partition`:
```bash
  if [[ ! -d $mount_point ]]; then
```
and insert the gates immediately BEFORE it (this places them after the existing `[[ ! -b $partition ]]` device check):
```bash
  _need_root || return 1
  _confirm "Mount ${partition} at ${mount_point} and add a UUID entry to /etc/fstab?" || return 1

  if [[ ! -d $mount_point ]]; then
```

- [ ] **Step 4: Run tests + shellcheck**

Run: `bats /Users/man.nk/git/shellLibs/tests/disk-utils.bats` → expect pass (or skip).
Run: `shellcheck --shell=bash scripts/disk-utils` → expect no new findings.

- [ ] **Step 5: Commit**

```bash
cd /Users/man.nk/git/shellLibs
git add scripts/disk-utils tests/disk-utils.bats
git commit -m "feat(disk-utils): gate disk-mount-partition with preflight + confirm" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Wire gates into `scripts/kvm-utils` (kvm-nat-port)

**Files:** Modify `scripts/kvm-utils`; Modify `tests/kvm-utils.bats`

- [ ] **Step 1: Strengthen the kvm dry-run test**

In `tests/kvm-utils.bats`, in the `kvm-nat-port (dry-run) ...` test, after the existing `[[ "$output" == *"PREROUTING"* ]]` line, add:
```bash
  [[ "$output" == *"would ask"* ]]
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats /Users/man.nk/git/shellLibs/tests/kvm-utils.bats`
Expected: the dry-run test FAILS (`would ask` not present); `-h` passes.

- [ ] **Step 3: Wire `kvm-nat-port`**

In `scripts/kvm-utils`, find this line inside `kvm-nat-port`:
```bash
  _run sudo iptables -I FORWARD -o "${virbr_of_vm}" -d "${ip_of_vm}" -p tcp --dport "${port_vm}" -j ACCEPT
```
and insert the gates immediately BEFORE it (after the `virbr_of_vm`/`ip_of_vm`/`port_vm`/`port_host` assignments):
```bash
  _need_root || return 1
  _need_cmd iptables || return 1
  _confirm "Add iptables NAT: host port ${port_host} -> ${ip_of_vm}:${port_vm}?" || return 1

  _run sudo iptables -I FORWARD -o "${virbr_of_vm}" -d "${ip_of_vm}" -p tcp --dport "${port_vm}" -j ACCEPT
```

- [ ] **Step 4: Run tests + shellcheck**

Run: `bats /Users/man.nk/git/shellLibs/tests/kvm-utils.bats` → expect 2/2 pass.
Run: `shellcheck --shell=bash scripts/kvm-utils` → expect clean.

- [ ] **Step 5: Commit**

```bash
cd /Users/man.nk/git/shellLibs
git add scripts/kvm-utils tests/kvm-utils.bats
git commit -m "feat(kvm-utils): gate kvm-nat-port with preflight + confirm" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: `install.sh` — wrap the apt-port `rm -f` in `_run`

**Files:** Modify `install.sh`

No bats test (install.sh has top-level side effects, needs root). Verify by reading + shellcheck.

- [ ] **Step 1: Wrap the rm**

In `install.sh`, find:
```bash
    for file in ./scripts/*; do
    	rm -f "$(which "${file##*/}")"
    done
```
and change the inner line to:
```bash
    for file in ./scripts/*; do
    	_run rm -f "$(which "${file##*/}")"
    done
```
(install.sh already sources `./scripts/safetylib` from v1, so `_run` is available.)

- [ ] **Step 2: shellcheck**

Run: `cd /Users/man.nk/git/shellLibs && shellcheck --shell=bash install.sh`
Expected: no NEW findings (the pre-existing SC2088/SC2016 per-line disables remain).

- [ ] **Step 3: Commit**

```bash
cd /Users/man.nk/git/shellLibs
git add install.sh
git commit -m "fix(install): dry-run the apt-port cleanup rm via _run" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Documentation

**Files:** Modify `README.md`, `CLAUDE.md`, `agent_docs/improvement-proposals.md`, `TODO.md`

- [ ] **Step 1: Green gate first**

Run: `bats /Users/man.nk/git/shellLibs/tests/` → expect all pass.
Run: `cd /Users/man.nk/git/shellLibs && make lint-ci` → expect exit 0 (no warnings/errors).
If anything is red, STOP and report (don't document over a red gate).

- [ ] **Step 2: README.md — extend the Safety section**

In `README.md`, in the `## Safety / dry-run` section, immediately after the existing paragraph that begins "Under the hood, functions route destructive work through `_run` ...", insert this paragraph (no code fence — keep it prose to avoid nesting):
```markdown
**Confirm + preflight.** Mutating functions also gate on `_confirm` (a y/N prompt) and the
preflight helpers `_need_root` / `_need_cmd`. `_confirm` auto-proceeds under
`SHELLLIBS_DRYRUN`, auto-yes when `SHELLLIBS_ASSUME_YES=1` is set (use that for automation,
e.g. `SHELLLIBS_ASSUME_YES=1 admin-user-add-to-sudo alice`), prompts on a terminal, and
**refuses** when there's no TTY — so an unattended script won't hang or run a destructive op
by accident. `_need_root` / `_need_cmd` abort with a clear error in real mode but are
advisory under dry-run so previews work on any host.
```

- [ ] **Step 3: CLAUDE.md — extend the safetylib foundation bullet**

In `CLAUDE.md`, find the `safetylib` bullet in the "Foundation layer" list and append these two lines to it (keep the existing text):
```markdown
  Also `_confirm <prompt>` (y/N gate — `SHELLLIBS_ASSUME_YES=1` to skip, refuses with no TTY)
  and `_need_root` / `_need_cmd` preflight (advisory under dry-run). Gate destructive ops with these.
```

- [ ] **Step 4: improvement-proposals.md — update §12**

In `agent_docs/improvement-proposals.md`, in section `## 12`, replace the line that starts with `Open (next):` with:
```markdown
**v2 (2026-06-21):** `_confirm` + `SHELLLIBS_ASSUME_YES` and `_need_root` / `_need_cmd`
(advisory in dry-run) added and wired into the 5 pilots; install.sh apt-port `rm` wrapped in
`_run`. Design: `2026-06-21-safetylib-v2-design.md`.

Open (next): convert the remaining destructive functions (network-utils, nvidia-utils,
docker-utils, nginxgen-utils, …); `admin-user-add-to-sudo` → `/etc/sudoers.d` + `visudo -c`
validation (see §7).
```

- [ ] **Step 5: TODO.md — check off the shipped v2 items**

In `TODO.md`, under "## Next — safety arc", change these three lines from `- [ ]` to `- [x]`:
- `safetylib v2: _confirm + SHELLLIBS_ASSUME_YES ...`
- `_need_root / _need_cmd preflight helpers ...`
- `install.sh:30 — wrap the legacy rm -f ... in _run ...`
Leave "Convert the remaining destructive functions" and the sudoers `visudo -c` line unchecked.

- [ ] **Step 6: Commit**

```bash
cd /Users/man.nk/git/shellLibs
git add README.md CLAUDE.md agent_docs/improvement-proposals.md TODO.md
git commit -m "docs: document safetylib v2 (confirm + preflight)" \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Final verification

- [ ] `bats /Users/man.nk/git/shellLibs/tests/` → all pass.
- [ ] `cd /Users/man.nk/git/shellLibs && make lint-ci` → exit 0.
- [ ] Manual real-mode smoke (non-root, expect refusal): `bash -c 'source scripts/logshell; source scripts/safetylib; source scripts/admin; admin-user-add-to-sudo alice; echo "exit=$?"'` → prints a "needs root" error and `exit=1` (does NOT prompt or touch /etc/sudoers).
- [ ] Manual dry-run smoke: `SHELLLIBS_DRYRUN=1 bash -c 'source scripts/logshell; source scripts/safetylib; source scripts/admin; admin-user-add-to-sudo alice'` → prints `(dry-run) ... would require root`, `DRY-RUN would ask: ...`, and the `DRY-RUN would ...` action lines; touches nothing.

## Self-review notes (spec coverage)

- `_confirm` / `_need_root` / `_need_cmd` with dry-run-advisory + no-TTY-refuse → Tasks 1-3. ✓
- Wired into all 5 pilots (admin×2, disk, kvm, install.sh) → Tasks 4-7. ✓
- Tests: 3 helpers unit-tested; each pilot dry-run test asserts the confirm line (TDD) → Tasks 1-6. ✓
- Docs (README, CLAUDE.md, §12, TODO.md) → Task 8. ✓
- Deferred (remaining conversions, sudoers.d/visudo) recorded in §12, not implemented. ✓
- Interactive TTY read/parse path: not bats-testable (no TTY); covered by the manual smoke + the decision-logic unit tests. Documented in the spec.
