# tests/

Unit tests for shellLibs, written with [bats-core](https://github.com/bats-core/bats-core).

This is a **starter suite** — it covers the foundation layer (`logshell`, `checksystem`)
and demonstrates the techniques you can reuse to test the rest of the library.

## Run

```bash
make test          # from the repo root
# or directly:
bats tests/
```

Install bats first if you don't have it:

```bash
make test-install  # brew / apt / npm, auto-detected
```

## What's here

| File | Covers |
|---|---|
| `test_helper.bash` | Shared setup — resolves `SHELLLIBS_ROOT` so tests can source `scripts/*` from any CWD. Loaded via `load test_helper`. |
| `logshell.bats` | Message tagging + `LOG_LEVEL` gating for the logger. |
| `checksystem.bats` | `checkIfCommandExist`, `checkIfFileHaveText`, `checkIfRootSession`, `checkIfUserExist`, `checkOsID`. |
| `safetylib.bats` | `_run`, `_append_line`, `_write_file`, `_backup_file` (dry-run + backup + idempotency). |
| `admin.bats`, `disk-utils.bats`, `kvm-utils.bats` | Dry-run pilot tests — verify converted functions preview safely. |

## The three techniques (and when to use them)

These map onto the testing ladder in the main [README](../README.md#testing).

**1. Pure assertions** — for functions that only compute. Source the file, `run` the
function, check `$status` and `$output`:

```bash
run checkIfCommandExist bash
[ "$status" -eq 0 ]
[ "$output" = "yes" ]
```

**2. Env override** — when a function reads an environment variable, set it on the `run`
line (each `@test` is isolated, so this can't leak):

```bash
USER=root run checkIfRootSession
[ "$output" = "yes" ]
```

**3. Command mocking** — for functions that shell out (`docker`, `apt`, `mysql`, `id`,
…). Define a shell function with the command's name to shadow the real one, so the unit
under test becomes deterministic and host-independent. A function shadow **already takes
effect inside bats `run`** — you do *not* need `export -f` (only add it if the mock must
reach into a child shell, e.g. `bash -c "..."`). Make the mock mimic the real command's
output, not just its exit code, so the test exercises real behavior:

```bash
id() { echo "uid=1000(someuser) gid=1000"; return 0; }   # mimic id's real banner
run checkIfUserExist someuser
```

> Mocking `cat`/`grep` and friends works, but it's a **last resort** — reach for it only
> when the function hardcodes a path with no seam (as `checkOsID` does). When a function
> takes a path *argument*, prefer writing a fixture and passing its path (technique 1,
> `checkIfFileHaveText`): clearer, and it doesn't shadow a core tool.

### Extending to the system-touching modules

Many functions in this repo **echo the full command before `eval`-ing it**
(`database-utils`, docker macvlan, …). That makes them easy to test *without executing
anything* — mock the tool to a no-op and assert on the printed command string:

```bash
@test "mysql-createUser builds the right SQL" {
  source "${SHELLLIBS_ROOT}/scripts/database-utils"
  mysql() { :; }            # no-op so the eval'd command does nothing
  run mysql-createUser bob
  [[ "$output" == *"CREATE USER 'bob'@'%'"* ]]
}
```

For genuinely destructive / distro-specific behavior (real `docker`, `apt` across
Debian/RHEL/Alpine), run the suite inside a throwaway container so a bad command can't
touch your host:

```bash
docker run --rm -v "$PWD":/src -w /src bats/bats:latest tests/
```

## Notes

- **`.bats` files are not shellcheck-linted.** `@test "..." { }` isn't valid standalone
  Bash, so `tests/` is intentionally left out of `make lint`'s sources.
- **Portability.** Tests are written to pass on both Linux (bash 5) and macOS (bash 3.2):
  no negative array indexing, no `${var^^}`, no `mapfile`. Assertions avoid the timestamp
  (Linux `date` supports `%3N` millis, macOS doesn't) and match on level tags instead.
- **Optional niceties.** [`bats-assert`](https://github.com/bats-core/bats-assert) +
  [`bats-support`](https://github.com/bats-core/bats-support) give richer assertions
  (`assert_output --partial`, `assert_success`). They're kept out of this starter to stay
  zero-extra-dependency; add them as git submodules under `tests/` if you want them.
