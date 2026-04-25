# shellcheck findings — summary

**Tool:** shellcheck 0.9.0
**Run:** `make lint` (= `shellcheck --shell=bash --severity=style scripts/* install.sh`, with `.shellcheckrc` disables for non-actionable codes)
**Saved report:** [`shellcheck-report.txt`](./shellcheck-report.txt) — regenerate with `make lint-report`

## Progress

| Milestone | Findings | Δ |
|---|---:|---:|
| Baseline | 239 | — |
| After Bucket A (real bugs + SC1090 silence) | 190 | −49 |
| After Bucket B (SC2086 / SC2046 / SC2181 + SC2128 silence) | 38 | −152 |
| After Bucket C (cosmetic silence + remaining fixes) | 14 | −24 |
| After §2 (source-time side effects) | 12 | −2 |
| After §5 (installer hardening — two footguns) | **11** | −1 |

All 11 remaining findings are `A && B || C` pseudo-if patterns tracked under §9 of `improvement-proposals.md`. Zero errors.

## Remaining (11)

| Code | # | What it is | Tracked under |
|---|---:|---|---|
| SC2015 | 11 | `A && B \|\| C` used as pseudo if/else | §9 of `improvement-proposals.md` — hand review required |

Everything else — SC2002, SC2009, SC1090, SC1091, SC2128 — is silenced in [`.shellcheckrc`](../.shellcheckrc) with a per-rule rationale comment.

## What each bucket did

### Bucket A — real bugs (−49)

Fixed 22 concrete bugs across 9 files. Highlights: dead-code `echo`s after `return`, broken nested-quote heredocs, an inverted Go-install warning branch, missing `git` prefix on `commit --amend`, `exit` inside sourced files, `lscpi` typo, `nmcliSetStaticIP` method set to `auto` instead of `manual`, calls to undefined `replaceStringInFile`, `dd count=2GB` (invalid suffix). Full table in `§4` of [`improvement-proposals.md`](./improvement-proposals.md). Silenced SC1090 in `.shellcheckrc`.

### Bucket B — robustness sweep (−152)

Mechanical rewrites, all three target codes fully cleared:

| Code | Before | After | How |
|---|---:|---:|---|
| SC2181 | 44 | 0 | `cmd; [[ $? != 0 ]] && return 1` → `cmd \|\| return 1` (30 in `apt-utils.sh` alone) |
| SC2086 | 18 | 0 | Quoted `$var` in command positions |
| SC2046 | 17 | 0 | Quoted `"$(which X)"`, `"$(uname -r)"`; annotated 4 `$(docker ps -q)` sites where multi-ID splitting is intentional |
| SC2128 | 66 | 0 | Silenced in `.shellcheckrc` — all were `$FUNCNAME` false positives |

Drive-by bug: `docker-utils:113` had `exit 0` inside a sourced file (would kill the user's shell on a PID match) → `return 0`.

### Bucket C — cleanup (−24)

Silenced or fixed everything that wasn't a real bug still in scope:

**Silenced in `.shellcheckrc`** (each with a rationale comment): SC2002 (useless cat), SC2009 (ps\|grep vs pgrep), SC1091 (same family as SC1090).

**Fixed:**
- `_other.sh` — `listFilesInDir` / `listDirInDir` were appending to arrays via `files+="…"` (string concat into `array[0]`), then reading with `${files[@]}`. Only the first element ever got filled. Fixed to `files+=("${element}")`. Also quoted the `for` glob.
- `checksystem:30` — `username="$(echo "$USER")"` → `username="$USER"`.
- `logshell:32` — `printf "${STAMP}"` (format-string from variable) → `printf '%s' "${stamp}"`. Also removed the unused `local level` in `_log`.
- `lpic1a:50` — `cd /lib/systemd/system` → `cd ... || return 1`.
- `network-utils:327` — removed dead `[[ $? ]] || return 1` (always true). The enclosing `if command -v bridge` was inverted (said "install first" when bridge *was* present); flipped to `if ! command -v bridge`.
- `network-utils:503` — added `|| return 1` after `cd`.
- `ssh-utils:11` — removed unused `local script_name`.
- `ssh-utils:151` — `local backup_file="$(date …)"` split into declare + assign.

**Annotated with per-line disables:** SC2088 and SC2016 in `install.sh` — the tilde-in-message and the single-quoted `$PATH` template are deliberate.
