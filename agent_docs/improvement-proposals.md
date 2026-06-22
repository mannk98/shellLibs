# shellLibs — improvement proposals

A menu of things worth doing, ranked by my guess at value-per-effort. Each item is self-contained so you can pick any subset to start with. Effort = S (<1h), M (a few hours), L (a day+).

---

## 1. Add shellcheck + shfmt as a lint gate  ✅ shellcheck done

**Effort:** S — **Risk:** none — **Value:** high — **Status:** shellcheck + Bucket A merged; shfmt still open

Done:
- `.shellcheckrc` added. Silences SC1090 / SC1091 (dynamic source paths), SC2128 (`$FUNCNAME` false positive), SC2002 (`cat file | …` idiom), SC2009 (`ps | grep` used for awk parsing). Each has a rationale comment.
- `Makefile` with `lint`, `lint-report`, `lint-install`, `help` targets.
- Baseline + latest run saved to [`shellcheck-report.txt`](./shellcheck-report.txt); summary in [`shellcheck-summary.md`](./shellcheck-summary.md).
- Bucket A bug fixes applied (see §4 below for the per-fix list).
- Bucket B sweep applied: SC2086/SC2046/SC2181 all 0; `$(docker ps -q)` call sites annotated with `# shellcheck disable=SC2046` where multi-ID word splitting is the intent.
- Bucket C cleanup applied: silenced cosmetic codes, fixed a real array-append bug in `_other.sh` (`files+="…"` was string-concatting into element 0), an inverted `if` in `network-utils:nwBridgeListPortsOfBridge`, an unquoted printf format string in `logshell`, a missing `|| return` after `cd` in two spots, and a few unused locals / useless echos. Two deliberate patterns in `install.sh` got per-line `# shellcheck disable=...` annotations.

Progress: **239 → 190 (Bucket A) → 38 (Bucket B) → 14 (Bucket C)**. The 14 left are all tracked elsewhere:
- 12 × SC2015 (`A && B || C`) → §9 below
- 2 × SC2155 (`export X=$(…)` at top-level) → §2 "Eliminate source-time side effects" — those two lines are *exactly* the side effects §2 is about, so they'll go away when §2 is done.

Remaining:
- shfmt not yet wired in.
- Pre-commit / CI integration not yet wired in.

---

## 2. Eliminate source-time side effects  ✅ done

**Effort:** S — **Risk:** low — **Value:** high (every new shell) — **Status:** applied

Applied fix:

- `scripts/nginxgen-utils` — removed `export publicIp=$(curl ifconfig.me …)` at top level. `publicIp` was never read by any script, so replaced with `nginxgen-publicip` (a function the user calls explicitly when they want their public IP). Removed `export nginxgenConName=$(docker ps …)` and replaced with a lazy ensurer `_nginxgen_ensure_con_name`, called at the top of each of the three functions that read `${nginxgenConName}`.
- `scripts/apt-utils.sh` — removed top-level `export oscheck; oscheck="$(checkOsID)"`. Added a lazy ensurer `_apt_oscheck` that populates `$oscheck` on first call, and inserted a `_apt_oscheck` line at the top of all 13 functions that read `${oscheck}`.

Smoke test: after `source apt-utils.sh`, `$oscheck` is unset; after the first `apt-*` call, it holds the cached OS ID. Same for `$nginxgenConName` after `source nginxgen-utils` vs after first `nginxgen-*` call.

Side effect: both `SC2155` findings in the shellcheck report (the two `export X=$(cmd)` lines) are now gone. Remaining shellcheck findings: **14 → 12** (all SC2015, tracked in §9).

Minor behavior change worth noting: users who typed `$publicIp` at a shell prompt to see their IP now need to type `nginxgen-publicip`. `$nginxgenConName` still works as a variable, but only after at least one `nginxgen-*` command has been run in the current shell.

---

## 3. Lazy-load domains instead of sourcing all 18 files per shell

**Effort:** M — **Risk:** medium (muscle-memory shift) — **Value:** medium-high

Today `~/.bashrc` sources every file unconditionally. Startup cost scales with library growth, and every function lands in one flat namespace.

**Two options, pick one:**

**A — autoload stubs.** For each public function, install a one-line stub like:
```bash
docker-commit() { unset -f docker-commit; source "$(which docker-utils)"; docker-commit "$@"; }
```
First call self-replaces with the real function. Zero-cost import, no workflow change for the user.

**B — explicit loader.** Replace the `.bashrc` block with a single `shellLibs-load <domain>` command; users source domains on demand. Simpler to maintain, but changes how people use the library.

A is nicer for users, B is simpler to build. I'd default to A.

---

## 4. Fix the confirmed bug list  ✅ done

**Effort:** S — **Risk:** low — **Value:** high — **Status:** applied

All originally-listed bugs fixed + extras found via shellcheck (SC2317 dead code, SC2027/SC2140 broken heredoc quoting, `admin-kernelInstallSpecificVersion` `exit` → `return`, `read -p` → `read -rp`). Full list with before/after:

| File:line | Bug | Fix |
|---|---|---|
| `admin:37-48` | `admin-user-add-to-group` — both vars assigned `$1`, hardcoded `-aG docker` | Read `$2` as groupname, use it in `usermod` |
| `admin:184` | Tilde in single quotes never expands, idempotency check always fails | `'~/.bashrc'` → `"$HOME/.bashrc"` |
| `admin:226` | `admin-disableSElinuxCentos` calls undefined `replaceStringInFile` | Inline `sed -i` |
| `admin:267` | `read -p` without `-r` mangles backslashes | `read -rp` |
| `admin:271, 274` | Typo `linux-iamge` | `linux-image` |
| `admin:278` | `exit` in sourced file on user "no" kills shell | `return 0` |
| `admin:289` | Calls nonexistent `admin-updateRamdisk` | `admin-updateInitRamdisk` |
| `apt-utils.sh:244-250, 257-263` | Dead `echo` after `return` in both duplicates of `apt-disable-autoupdate` | Moved echo into success branch |
| `apt-utils.sh:316-318` | `mkdir -p "${localrepodir}"` runs before variable assignment | Swapped order |
| `cloudstack-utils:67-68` | Undefined `replaceStringInFile` | Inline `sed -i` |
| `disk-utils:90` | `dd count=2GB` — `dd` doesn't accept `GB` suffix | `bs=1M count=2048` (writes 2 GiB) |
| `docker-utils:275` | `: "{${2}:=myimage_latest.tar.gz}"` — broken default; you can't `:=` a positional | `local outfile="${2:-myimage_latest.tar.gz}"` |
| `docker-utils:414` | `docker service rm "${scale_number}"` — wrong var | `${service_name}` |
| `git-utils:117` | `commit --amend --reset-author` — missing `git` prefix | Added |
| `git-utils:168,175,182` | `echo "…success…"` after `return 1` — dead code | Moved success `echo` out of the error branch |
| `git-utils:184` | "Go is not installed" in the wrong branch — prints on success | Flipped the if/else |
| `lpic1a:9` | `lscpi` | `lspci` |
| `network-utils:17-32` | Broken nested quoting in heredoc-like string (SC2140/SC2027) | Replaced with real heredoc |
| `network-utils:54-63` | Same broken pattern | Same fix |
| `network-utils:181` | `nmcliSetStaticIP` uses `ipv4.method auto` (DHCP) with manual gateway/address | Changed to `manual` |
| `network-utils:258-290` | `nwSetupCentos7` — same nested-quote pattern across three config blocks | Three heredocs |
| `nvidia-utils:107` | `exit 0` in sourced file kills user shell | `return 0` |

Shellcheck run after these changes: **239 → 190 findings** (49 fewer). The remaining 190 are overwhelmingly style/quoting (Bucket B) — no known bugs left in the "clearly broken" category.

**Follow-up exit sweep (2026-06-22).** §4 fixed the two `exit`-in-sourced-file bugs found at the time (`admin:278`, `nvidia-utils:107`); a later `grep -n '\bexit\b'` over `scripts/` found the rest. All `exit` in a sourced file kills the *user's* interactive shell, so each became `return`:

| File:fn | Was | Now |
|---|---|---|
| `admin:admin-crontab-add` | `-h` guard `exit 0` | `return 0` |
| `checksystem:unknown_os` | `exit 1` | `return 1` (+ `checkOsDistro` now `return 1`s after calling it, so an unknown OS still aborts the function) |
| `network-utils:nwSetupAccessPoint` | 4× `cd … \|\| exit 1` | `\|\| return 1` |
| `apt-utils.sh` (local-repo build) | `cd "${localrepodir}" \|\| exit` | `\|\| return 1` |

Non-bugs left alone: `ssh-utils:33,202` are the *remote* `ssh … exit` command, not a shell exit; `install.sh:37` is an executed script (not sourced), where `exit` is correct. Regression tests: `tests/admin.bats` + `tests/checksystem.bats` use a `bash -c "source …; <fn>; echo SURVIVED"` sentinel — an `exit` aborts the child before the sentinel prints.

Still-open items that came out of the shellcheck run but are not bugs:
- **SC2015 (14 remaining):** `A && B || C` as pseudo-if. Most are idiomatic fallbacks; some may be latent issues. Needs hand review, separate PR.
- **SC2088 (1 remaining):** `install.sh:42` — `~/.bashrc` inside a user-facing message string; literal display is the intent. Can leave or silence with a directive.
- **SC2317 (1 remaining):** `apt-utils.sh:263` — already addressed in the second edit pass; if this still shows, re-run `make lint-report`.

---

## 5. Harden the installer  ✅ two footguns fixed

**Effort:** S — **Risk:** low — **Value:** medium — **Status:** the two named footguns applied; remaining items still open

Applied:

- **`~/.bashrc` as root** — `install.sh` now resolves the target bashrc via `$SUDO_USER`. When invoked as `sudo ./install.sh`, the source block lands in `/home/$SUDO_USER/.bashrc` (looked up with `getent passwd`), not `/root/.bashrc`. Plain `./install.sh` as non-root or as real root still targets the caller's `$HOME/.bashrc`. This means `sudo ./install.sh` is now a one-shot install — no more "run again as yourself" step.
- **Fragile sentinel** — replaced the `grep "listSourceFiles"` word-search with a bracketed managed-block pattern:
  ```
  # >>> shellLibs managed block >>>
  ...
  # <<< shellLibs managed block <<<
  ```
  Re-installs are now idempotent: if the begin marker exists, `sed -i '/begin/,/end/d'` drops the old block, then the fresh one is appended. Running `install.sh` 100 times still leaves exactly one block. Tested end-to-end against a scratch bashrc — existing user content is preserved, duplicates do not accumulate.

Side effect: `install.sh` dropped its last shellcheck finding (SC2015 on line 39). Repo total: 12 → 11.

Still open (not named in the "two footguns" request; leaving for later):

- **Install path** — now `/bin/scripts` (renamed from `/bin/shellLibs` in the scripts/ rename; all stale doc/code references have been synced — see §11). Still under `/bin`, which is reserved for OS packages; `/usr/local/bin/shellLibs` or `/opt/shellLibs` would be more conventional. Changing this touches existing installs, so defer until there's a reason.
- **No uninstall script** — uninstall *instructions* now live in the README (marker-based `sed` range-delete + `rm -rf /bin/scripts`); a dedicated `make uninstall` / `uninstall.sh` is still unwritten.
- **`rm -rf /bin/scripts` unguarded** — a typo here is catastrophic as root. Cheap guard: `[[ -d /bin/scripts ]] && rm -rf /bin/scripts`, or hoist the path into a variable that's validated first.

---

## 6. Naming & structure consistency

**Effort:** S — **Risk:** low (but churny — breaks anyone sourcing by old name) — **Value:** low-medium

- File extensions are mixed: `apt-utils.sh`, `golang-utils.sh`, `_other.sh` have `.sh`; the other 15 don't. Pick one.
- Function prefixes mostly match filename, but `lpic1a` uses no prefix (`kmod_unload`, `grubReInstall`, `findPartitionUUID`) and `network-utils` mixes `nw*` / `nmcli*` / `nwIface*` / `nw-*`.
- `_other.sh` is a grab-bag — `listFilesInDir` / `listDirInDir` could move to a `fs-utils` file, `install-qt5` to an `apps-utils` file.

If we do this, do it alongside the lazy-load work (§3) since both touch user-facing names.

---

## 7. Security-sensitive patterns to revisit

**Effort:** S–M — **Risk:** low (improving) — **Value:** depends on threat model

- ✅ `admin-user-add-to-sudo` — **done.** Now prompts (`_confirm`) and writes a per-user `/etc/sudoers.d/<user>` drop-in, validated with `visudo -cf` in a scratch file before it can land, then `chmod 0440` — instead of appending `NOPASSWD:ALL` to the monolithic `/etc/sudoers` (a bad edit there locks you out of sudo). Routed through `_write_file`/`_run`, so dry-run previews it.
- `database-utils` passes passwords as CLI args (`mysql -p"${PASS}"`) — visible to anyone running `ps`. Use `MYSQL_PWD` env var or a `~/.my.cnf` with 0600 perms.
- `ssh-utils:ssh-copy-key:134` falls back to `cat ~/.ssh/id_rsa.pub` — won't exist on ed25519-only systems. Use `ssh-add -L` or glob `~/.ssh/id_*.pub`.
- Several functions write to `/etc/fstab` / `/etc/sudoers` / `/etc/network/interfaces` with no backup and no idempotency check — re-running them accumulates duplicate entries.

---

## 8. Minimal test harness (bats)  ✅ starter shipped

**Effort:** M — **Risk:** none — **Value:** medium — **Status:** starter suite done; broader coverage + CI open

Done:
- `tests/` bats suite + `tests/test_helper.bash`, run via `make test` (and `make test-install` to get bats — brew/apt/npm auto-detected). `.bats` files are kept out of `make lint` (not valid standalone bash).
- `tests/logshell.bats` — message tagging, `LOG_LEVEL` gating, `log-error`→stderr, and a deterministic portable-timestamp regression (mocks GNU vs BSD/macOS `date`).
- `tests/checksystem.bats` — `checkIfCommandExist`, `checkIfFileHaveText`, `checkIfRootSession`, `checkIfUserExist`, `checkOsID`/`checkOsVersionID`. Demonstrates three reusable techniques: pure assertions, env override, command mocking.
- 24 tests, green on bash 3.2 (macOS) and bash 5 (Linux). See `tests/README.md`.

Open:
- System-touching modules (docker/network/apt) still need container-based integration tests.
- No CI wiring yet (e.g. GitHub Actions running `make lint` + `make test`).

---

## 9. SC2015 hand review — `A && B || C` sites

**Effort:** S — **Risk:** low (per-site reasoning) — **Value:** low-medium

11 sites still flag SC2015. The pattern is load-bearing throughout this repo (used as `if [[ cond ]]; then X; else Y; fi`), and most of the remaining occurrences are safe *in practice*: the `B` branch is either a single command that can't fail, or the author accepted the "C also runs if B fails" behavior.

The 11 sites (from `make lint`, shellcheck 0.11.0):
- `docker-utils:148, 158, 314, 320` — config-dir / runtime-detection branches
- `lpic1a:25, 28` — blacklist-file creation
- `network-utils:16, 53, 347` — config-file write branches
- `nvidia-utils:95` — nvidia-installer detection
- `nginxgen-utils:111` — whitelist-IP default

**What to do:** walk each one. If `B` is a single `echo`/`log-*`/assignment that effectively can't fail, leave it (optionally add `# shellcheck disable=SC2015`). If `B` is a multi-line `{ ... }` block where a failure inside would wrongly trigger `C`, rewrite to `if/then/else`. Expect most to be safe and 1–2 genuine footguns.

Low urgency — none of these are known-broken today.

---

## 10. Logger correctness (logshell)  ✅ done

**Effort:** S — **Risk:** low — **Value:** medium — **Status:** applied

- **`log-error` → stderr.** `log-error` now redirects the console line to stderr (`_log ... >&2`) so errors don't pollute a function's stdout when its output is captured or piped. The `LOG_FILE` append inside `_log` keeps its own redirect, so file logging is unchanged. Regression: `tests/logshell.bats` "log-error writes to stderr, not stdout" (uses `run --separate-stderr`).
- **Portable millisecond timestamp.** `_get_timestamp` used `date +"%F %T,%3N"`. `%3N` is GNU-only; macOS/BSD `date` supports plain `%N` but NOT the `%3N` width form, so it leaked a literal `,3N` into every line (and the LOG_FILE). Fix: probe the exact `%3N` form once (cached in `_LOGSHELL_HAS_NANOS`) — three digits → GNU, keep millis; otherwise fall back to `%F %T` (second precision). Regression: two deterministic tests mock GNU vs BSD/macOS `date`.

---

## 11. Doc / install-path drift sync  ✅ done

**Effort:** S — **Risk:** none — **Value:** low (correctness) — **Status:** applied

The `scripts/` rename moved the install target to `/bin/scripts`, but several references still said the old `/bin/shellLibs`. Synced all of them:
- `scripts/cloudstack-utils:17` — `source /bin/shellLibs/cloudstack-utils` → `/bin/scripts/...` (this one was a real runtime bug on the remote `cloudstackServer`).
- `CLAUDE.md` (4 refs) and the `.shellcheckrc` header comment.
- `README.md` — rewritten to document `/bin/scripts` as the real path.

---

## 12. Dry-run safety layer (safetylib)  ✅ v1 done

**Effort:** M — **Risk:** low — **Value:** high — **Status:** v1 shipped

New `scripts/safetylib` foundation file: `_run` (argv, no eval), `_append_line` /
`_write_file` (idempotent, auto-backup), `_backup_file`, all gated by `SHELLLIBS_DRYRUN`.
Pilots converted: `admin-swap-enable`, `admin-user-add-to-sudo`, `disk-mount-partition`,
`kvm-nat-port`, `install.sh` (rm -rf now guarded + previewable). Tests in
`tests/safetylib.bats` + per-pilot dry-run suites. Design: `2026-06-20-safetylib-dryrun-design.md`.

**v2 (2026-06-21):** `_confirm` + `SHELLLIBS_ASSUME_YES` and `_need_root` / `_need_cmd`
(advisory in dry-run) added and wired into the 5 pilots; install.sh apt-port `rm` wrapped in
`_run`; all bats `[[ ]]` assertions hardened with `|| return 1`. Design: `2026-06-21-safetylib-v2-design.md`.

**v2.1 (2026-06-22):** `admin-user-add-to-sudo` migrated to a `visudo -cf`-validated
`/etc/sudoers.d/<user>` drop-in (see §7). Plus an **exit-audit sweep** — every `exit` in a
*sourced* file turned into `return` (see §4 follow-up).

Open (next): convert the remaining destructive functions (network-utils, nvidia-utils,
docker-utils, nginxgen-utils, …) — the last big item in the safety arc.

---

## My suggested order

1. **§1 shellcheck + §4 bug fixes + Buckets B/C** ✅ done.
2. **§2 source-time side effects** ✅ done.
3. **§5 installer hardening — two footguns** ✅ done (install path now `/bin/scripts`; uninstall script and `rm -rf` guard still open as smaller follow-ups).
4. **§8 bats starter + §10 logger fixes + §11 path sync** ✅ done.
5. Then choose between §3 (lazy-load) and §7 (security) depending on whether the pain point is shell startup time or the sudoers/mysql patterns.

§6 and §9 are polish — do when the rest is stable.
