# shellLibs — TODO / Roadmap

Short "what's next" view. The deep, historical menu (with done-status and rationale)
lives in [agent_docs/improvement-proposals.md](agent_docs/improvement-proposals.md);
this file is the quick backlog.

## Status (resume point — 2026-06-22)

On **`dev`** (`origin/dev` @ `144e1de`; local `dev` is ahead with the run below, not yet
pushed). Gates: `make test` → **78/78 green**, `make lint-ci` → **exit 0**. Dev machine is
macOS (bash 3.2); the library runs on Linux. To re-orient:
`agent_docs/improvement-proposals.md` (deep menu) + the dated
`agent_docs/2026-06-*-safetylib-*` design/plan docs.

**Shipped this run (local `dev`, closes the safety arc):**
- **Exit audit** — swept every `exit` in a *sourced* file (they kill the user's interactive shell) and turned them into `return`: `admin-crontab-add` `-h` guard, `checksystem`'s `unknown_os` (+ its `checkOsDistro` callers now propagate the failure), and four `cd … || exit` sites in `network-utils:nwSetupAccessPoint` + one in `apt-utils.sh`. `ssh-utils` hits are remote `ssh … exit` (not shell exits); `install.sh` is an executed script (correct). RED tests via the `bash -c … ; echo SURVIVED` sentinel.
- **sudoers hardening** — `admin-user-add-to-sudo` now writes a per-user `/etc/sudoers.d/<user>` drop-in (validated with `visudo -cf` in a scratch file first, then `chmod 0440`) instead of appending `NOPASSWD:ALL` to the monolithic `/etc/sudoers` (a bad edit there can lock you out of sudo). All via `_write_file`/`_run`, so dry-run previews it.
- **Conversion sweep** — routed the remaining destructive functions through safetylib across `nvidia-utils` (08ff0f1), `docker-utils` (8096c42), `network-utils` (94ea0bb): `_run`/`_write_file`/`_append_line` + `_need_root`/`_need_cmd`/`_confirm`, each with a `tests/<file>.bats` dry-run suite. Folded-in fixes: dropped nvidia's dead `admin-updateRamdisk` call + a leaking `set -e`; removed docker macvlan's `eval`; fixed `docker-swarm-inspectService` (`service`→`docker service`) and `nmcliRestartIface`'s arg guard. Plan/status: `agent_docs/2026-06-22-safetylib-conversion-design.md`.

**Shipped earlier:**
- **safetylib v1** — `scripts/safetylib`: `_run` / `_append_line` / `_write_file` / `_backup_file`, gated by `SHELLLIBS_DRYRUN`; converted 5 destructive pilots (admin-swap-enable, admin-user-add-to-sudo, disk-mount-partition, kvm-nat-port, install.sh). Plus a `%3N` timestamp portability fix in `logshell`.
- **CI** — `.github/workflows/ci.yml`: `make lint-ci` + `make test` on push/PR.
- **safetylib v2** — `_confirm` (+`SHELLLIBS_ASSUME_YES`), `_need_root`, `_need_cmd` (advisory in dry-run); wired into the same 5 pilots; hardened every bats `[[ ]]` assertion with `|| return 1` (bats `set -e` skips bare `[[ ]]`).
- **Bug fix** — `kvm-nat-port` DNAT now uses `${ip_of_vm}` (was hard-coded to the example IP).

## Now

- [x] **CI (GitHub Actions)** — `make lint-ci` + `make test` on every push/PR. *(shipped; confirm the first Actions run on GitHub is green — tweak if a runner version differs)*

## Next — safety arc (continue `safetylib`)

- [x] **safetylib v2:** `_confirm` + `SHELLLIBS_ASSUME_YES` — prompt before destructive ops (skipped in dry-run / when ASSUME_YES set).
- [x] **`_need_root` / `_need_cmd`** preflight helpers — standardize the ad-hoc root/command checks scattered across functions.
- [x] **Convert the remaining destructive functions** to `_run` / `_append_line` / `_write_file` — done for `nvidia-utils`, `docker-utils`, `network-utils` (each with a dry-run bats suite). `nginxgen-utils` is an inspection module (out of scope). Follow-up pass for `cloudstack-utils` / `lpic1a` / `database-utils` / `ssh-utils` / `git-utils` / `disk-create-partition` — see the design doc's "Follow-up" list.
- [x] **`install.sh:30`** — wrap the legacy `rm -f "$(which …)"` apt-port cleanup in `_run` *(final-review follow-up)*.
- [x] **`_append_line /etc/sudoers`** — migrated `admin-user-add-to-sudo` to a `visudo -cf`-validated `/etc/sudoers.d/<user>` drop-in (see improvement-proposals §7).
- [x] **Audit `exit` in sourced functions** — swept and fixed all 7 real sites (`admin`, `checksystem`, `network-utils` ×4, `apt-utils.sh`); `ssh-utils`/`install.sh` hits are non-bugs. *(final-review follow-up)*

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
