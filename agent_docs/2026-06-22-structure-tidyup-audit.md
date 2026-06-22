# shellLibs — function-structure tidy-up audit (2026-06-22)

Audit of `scripts/` for "làm gọn cấu trúc các hàm". Produced by a fan-out audit (one
reader per file + duplication / naming / boilerplate lenses) and an adversarial critique
pass (the critique's corrections are folded into the themes below). Effort: S (<1h) ·
M (a few hours) · L (a day+). "Breaks callers?" = breaks `source "$(which X)"` siblings or
interactive muscle memory.

## Status

- [x] **Quick wins (shipped this run)** — commits 3015329 / 4bfbc0a / 849178c / f01bb8d:
  - Theme D headers: apt-utils.sh, lpic1a, cloudstack-utils → guarded sibling-fallback.
  - Theme B footguns: checksystem (`checkZombieParents`, `checkStressTestCpu/Ram`),
    disk-utils (`disk-check-performance`), admin (`changeUserSession`,
    `kernelInstallSpecificVersion`) — missing `return` + inverted `command -v`.
  - `ssh-enable-root`: explicit action (no silent enable) + sshd_config edit via
    safetylib (`_need_root`/`_confirm`/`_backup_file`/`_run`).
  - Small bugs: logshell `<ts> [level]` spacing, git-utils `git-push-create-merge`
    branch-default-then-exec bug; deduped `admin-apt-disable-autoupdate` → alias.
- [x] **Theme C** — database-utils eval→argv via `_mysql_exec` (commit f01615c): 13 evals
  + the shell-injection class gone; `_confirm` on drop/truncate; arity/`mysql_native_password`/
  `psql -W` bugs fixed; REPLs kept; `tests/database-utils.bats` added.
- [x] **Theme A** — `local` sweep DONE: git/checksystem/lpic1a/nginxgen/cloudstack/apt
  (7d5bac0) + docker/network/admin (9ea48b0); ~90 positionals localized, command-subs
  split for SC2155, intentional globals/exports/lazy-caches skipped; no-leak regression
  tests added (call the fn directly, then assert the var is unset).
- [x] **Theme E** — timezone GMT0/GMT7 + nvidia-toolkit dedup (8f6cdc4); apt-install/-quite
  collapse + apt-setup-localrepo off-by-one fix (520c3d9). (cloudstack TOML→nginxgen and
  the check-systemd dup deferred — lowest value.)
- [ ] **Theme F** — naming / `.sh` extensions / grab-bag split (only caller-breaking one).
- [ ] **Theme G** — def-style: recommend documenting "both allowed" in CLAUDE.md, no sweep.

Gates after quick wins: `make test` 94/94, `make lint-ci` exit 0.

---

## Remaining themes (prioritized)

### Theme C — database-utils eval→argv  — ✅ DONE (commit f01615c)
All 13 `mysql-*` build `command=$(cat <<EOF…); eval "$command"`. Extract one private
`_mysql_exec '<SQL>'` that materializes the `MANNK_MYSQL_*` defaults once and runs
`mysql … --execute="<SQL>"` as **argv via `_run`** (no eval → kills the SQL-injection
class + ~13 duplicated preambles + collapses the grant trio). **Critique corrections that
MUST be applied:**
- `mysql-connect` and `psql-connect` are interactive REPLs (no `--execute=`) — route them
  to plain `_run mysql …` / `_run psql …`, NOT through `_mysql_exec`.
- Add `_confirm` on `mysql-dropUser/dropDB/dropTable/truncateTable` — the arity-guard fix
  flips them from silent no-op to actually executing, so the first post-fix run drops/
  truncates for real.
- Build the `-p…` password token conditionally (empty pass → bare `-p` prompt, not `-p ""`).
- Do the database-utils `local` sweep (Theme A) AS PART of this rewrite (same lines).
- Fix the SQL bugs surfaced: arity guards (`-z $2` vs one-arg Usage) on
  createDB/dropDB/createTable/dropTable/truncateTable; `mysql-createUser` `use_native_pass`
  → `mysql_native_password` + inverted yes/no→plugin map; `psql-connect` `-W ${password}`
  (wrong, -W takes no arg); drop the stray mid-file `#!/bin/bash` at line ~322.
- database-utils has no bats yet → add a dry-run suite as part of this.

### Theme A — `local` sweep  (M · low risk · no caller break)
Prefix bare positional/`command=$(…)` assignments with `local`. ~90 sites; worst:
database-utils, git-utils, docker-utils, admin, nginxgen-utils, network-utils (nmcli),
cloudstack-utils, lpic1a, checksystem. **MUST skip:** `mysql-setEnv` `MANNK_MYSQL_*`
exports, `GOPRIVATE`, `: "${x:=default}"` lines, and the lazy-ensurer cached globals
(`$oscheck`, `$nginxgenConName`, `_LOGSHELL_HAS_NANOS`). Grep each var name across the file
before localizing (guard against cross-function state). shellcheck SC2034 + bats catch slips.

### Theme E (remaining merges) — S–M · low risk
`admin-timezone-set-GMT0/GMT7` → one `admin-timezone-set <tz> [path]` + wrappers (route
the localtime `cp`/`ln -sf` through `_run`/`_backup_file`); nvidia toolkit pair (extract
`_nvidia_add_toolkit_repo`, the `toolkitl` typo'd one becomes an alias); `apt-install` vs
`apt-install-quite` → one with optional `-q`; the two `apt-setup-localrepo-*` (fold into a
`$oscheck` switch — also fix the shared count-loop off-by-one: `((count++))` runs before the
skip-`$1` test, so the repo path is installed as a package); `cloudstack-genNginxConfig`
should call `nginxgen-createTemplate`. Leave a back-compat alias for any name you actually type.

### Theme F — naming / extensions / grab-bag  (M · medium-HIGH risk — only file-breaking one)
network-utils' 4 naming schemes (`nw*`/`nw-*`/`nmcli*`/typo `nwIaceGetIPmask`); drop `.sh`
from apt-utils.sh/golang-utils.sh/_other.sh; dissolve `_other.sh` + `lpic1a` into real
domains. **Verified safe-ish:** no sibling sources any of these by name and the installer
globs extension-agnostically — BUT `install.sh:4-6` sources `./scripts/logshell|checksystem|
safetylib` by literal relative path, so never rename those three. Do as ONE clearly-messaged
rename commit that also updates the CLAUDE.md module table; leave aliases for function renames.
This is improvement-proposals §6 (deferred as churny) — lowest value-per-effort.

### Theme G — def-style (`function f()` vs `f()`)  (cosmetic)
Mixed repo-wide. Recommend **documenting in CLAUDE.md that both are allowed** rather than a
noisy normalize sweep.

---

## Standalone follow-ups noted by the audit (not yet scheduled)
- `database-utils` passes the password on the CLI (`-p"$PASS"`, visible in `ps`) — §7.
- `disk-fix-cloudstack-qcow2-image`, the apt-disable-autoupdate write, and several other
  destructive functions in the deferred files still bypass safetylib — the conversion
  follow-up pass (see `2026-06-22-safetylib-conversion-design.md`).
