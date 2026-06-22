# shellLibs — TODO / Roadmap

Short "what's next" view. The deep, historical menu (with done-status and rationale)
lives in [agent_docs/improvement-proposals.md](agent_docs/improvement-proposals.md);
this file is the quick backlog.

## Status (resume point — 2026-06-22)

Everything is on **`dev`**, merged and pushed (`origin/dev` @ `144e1de`).
Gates: `make test` → **59/59 green**, `make lint-ci` → **exit 0**. Dev machine is macOS
(bash 3.2); the library runs on Linux. To re-orient: `agent_docs/improvement-proposals.md`
(deep menu) + the dated `agent_docs/2026-06-*-safetylib-*` design/plan docs.

**Shipped this run:**
- **safetylib v1** — `scripts/safetylib`: `_run` / `_append_line` / `_write_file` / `_backup_file`, gated by `SHELLLIBS_DRYRUN`; converted 5 destructive pilots (admin-swap-enable, admin-user-add-to-sudo, disk-mount-partition, kvm-nat-port, install.sh). Plus a `%3N` timestamp portability fix in `logshell`.
- **CI** — `.github/workflows/ci.yml`: `make lint-ci` + `make test` on push/PR.
- **safetylib v2** — `_confirm` (+`SHELLLIBS_ASSUME_YES`), `_need_root`, `_need_cmd` (advisory in dry-run); wired into the same 5 pilots; hardened every bats `[[ ]]` assertion with `|| return 1` (bats `set -e` skips bare `[[ ]]`).
- **Bug fix** — `kvm-nat-port` DNAT now uses `${ip_of_vm}` (was hard-coded to the example IP).

## Now

- [x] **CI (GitHub Actions)** — `make lint-ci` + `make test` on every push/PR. *(shipped; confirm the first Actions run on GitHub is green — tweak if a runner version differs)*

## Next — safety arc (continue `safetylib`)

- [x] **safetylib v2:** `_confirm` + `SHELLLIBS_ASSUME_YES` — prompt before destructive ops (skipped in dry-run / when ASSUME_YES set).
- [x] **`_need_root` / `_need_cmd`** preflight helpers — standardize the ad-hoc root/command checks scattered across functions.
- [ ] **Convert the remaining destructive functions** to `_run` / `_append_line` / `_write_file` (network-utils, nvidia-utils, docker-utils, nginxgen-utils, …).
- [x] **`install.sh:30`** — wrap the legacy `rm -f "$(which …)"` apt-port cleanup in `_run` *(final-review follow-up)*.
- [ ] **`_append_line /etc/sudoers`** — validate with `visudo -c`, or migrate to `/etc/sudoers.d/<user>` (see improvement-proposals §7).
- [ ] **Audit `exit` in sourced functions** — e.g. `admin-crontab-add`'s `-h` guard uses `exit 0`, which kills the user's interactive shell (sourced files must `return`). Sweep for others. *(final-review follow-up)*

## Ideas — new capability / UX (when the safety arc feels done)

- [ ] **`slh` discoverability** — a meta-command that lists/searches every function from its `-h` block, by domain; + bash completion; + optional `fzf` picker. Biggest day-to-day win for a flat namespace of ~200 functions.
- [ ] **`sys-report`** — first-5-minutes server health snapshot (load, mem, disk, top procs, failed systemd units, listening ports, last logins, pending updates).
- [ ] **`_compat` shim** — wrap GNU↔BSD differences (`date`/`sed`/`stat`/`readlink`) so the lib runs on macOS too (timely after the `%3N` timestamp bug).
- [ ] **`cert-utils`** — TLS: generate self-signed, inspect a cert, check a remote host's expiry (`openssl s_client`).
- [ ] **`security-audit`** — list SUID / world-writable files, sudoers, unexpected open ports, failed-login summary from journald.
- [ ] **CI matrix** — run the bats suite inside `alpine` (busybox) + `almalinux` containers to catch GNU-vs-busybox differences in the helpers (`grep -qxF`, `date`, `cp -p`, `printf %q`).

## Deeper backlog (details in improvement-proposals.md)

- [ ] §3 — lazy-load domains (autoload stubs) for faster shell startup.
- [ ] §6 — naming / extension consistency (mixed `.sh`).
- [ ] §7 — security hardening (sudoers.d via `visudo`, MySQL creds off the CLI, fstab/sudoers backups + idempotency).
- [ ] §9 — SC2015 hand-review (the 11 `A && B || C` sites).
