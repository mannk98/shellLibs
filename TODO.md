# shellLibs — TODO / Roadmap

Short "what's next" view. The deep, historical menu (with done-status and rationale)
lives in [agent_docs/improvement-proposals.md](agent_docs/improvement-proposals.md);
this file is the quick backlog.

## Now

- [ ] **CI (GitHub Actions)** — run `make lint-ci` + `make test` on every push/PR. *(in progress)*

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
