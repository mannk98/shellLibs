#!/usr/bin/env bats
#
# Unit tests for scripts/checksystem — OS detection + predicate helpers.
#
# This file shows three testing techniques you can reuse for the rest of the
# library:
#   1. Pure assertions  — call the function, check $status / $output (most tests).
#   2. Env override      — set a variable the function reads (checkIfRootSession).
#   3. Command mocking   — shadow an external command (`id`, `cat`) with a shell
#                          function so a system-touching helper becomes testable
#                          without a matching OS. This is the same trick you use
#                          for docker/apt/mysql functions elsewhere.

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/checksystem"
}

# --- 1. Pure assertions -----------------------------------------------------

@test "checkIfCommandExist: existing command -> 'yes' and exit 0" {
  run checkIfCommandExist bash
  [ "$status" -eq 0 ]
  [ "$output" = "yes" ]
}

@test "checkIfCommandExist: missing command -> 'no' and exit 1" {
  run checkIfCommandExist definitely_not_a_real_command_xyz
  [ "$status" -eq 1 ]
  [ "$output" = "no" ]
}

@test "checkIfFileHaveText: text present -> 'yes' and exit 0" {
  local f="${BATS_TEST_TMPDIR}/sample.txt"
  printf 'alpha\nbeta\ngamma\n' > "$f"
  run checkIfFileHaveText "beta" "$f"
  [ "$status" -eq 0 ]
  [ "$output" = "yes" ]
}

@test "checkIfFileHaveText: text absent -> 'no' and exit 1" {
  local f="${BATS_TEST_TMPDIR}/sample.txt"
  printf 'alpha\nbeta\n' > "$f"
  run checkIfFileHaveText "zzz_not_present" "$f"
  [ "$status" -eq 1 ]
  [ "$output" = "no" ]
}

@test "checkIfFileHaveText: -h prints usage and exits 0 (scans nothing)" {
  run checkIfFileHaveText -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

# --- 2. Env override --------------------------------------------------------

@test "checkIfRootSession: USER=root -> 'yes' and exit 0" {
  USER=root run checkIfRootSession
  [ "$status" -eq 0 ]
  [ "$output" = "yes" ]
}

@test "checkIfRootSession: non-root user -> 'no' and exit 1" {
  USER=alice run checkIfRootSession
  [ "$status" -eq 1 ]
  [ "$output" = "no" ]
}

# --- 3. Command mocking -----------------------------------------------------
#
# A shell-function shadow already takes effect inside bats `run` — you do NOT need
# `export -f` here (only add it if the mock must cross into a child shell, e.g.
# `bash -c "..."`).

@test "checkIfUserExist (mocked id): user exists -> last line 'yes', exit 0" {
  # The real `id` prints a "uid=...(name)..." banner to stdout, and checkIfUserExist
  # does NOT redirect it — so the function's output is that banner line FOLLOWED by
  # "yes". That's exactly why we check the LAST line, not the whole output. The mock
  # reproduces the banner so the test exercises the real behavior (and the last-line
  # indexing is genuinely load-bearing, not decorative).
  id() { echo "uid=1000(someuser) gid=1000(someuser) groups=1000(someuser)"; return 0; }
  run checkIfUserExist someuser
  [ "$status" -eq 0 ]
  [ "${lines[$(( ${#lines[@]} - 1 ))]}" = "yes" ]
}

@test "checkIfUserExist (mocked id): user missing -> last line 'no', exit 1" {
  # Missing user: real `id` writes "no such user" to stderr (bats merges stderr into
  # $output) and returns non-zero, so the function appends "no" as the last line.
  # Checking the last line — not `*no*` — avoids a false match on "no such user".
  id() { echo "id: someuser: no such user" >&2; return 1; }
  run checkIfUserExist someuser
  [ "$status" -eq 1 ]
  [ "${lines[$(( ${#lines[@]} - 1 ))]}" = "no" ]
}

@test "checkOsID (mocked cat): extracts an unquoted ID field" {
  # checkOsID does: cat /etc/os-release | grep ^ID= | cut -d= -f2
  # We shadow `cat` because checkOsID HARDCODES /etc/os-release (no injectable seam).
  # This is a last resort — when a function takes a path argument, prefer a fixture +
  # path instead (see the checkIfFileHaveText tests above); it's clearer and doesn't
  # shadow a core tool.
  cat() { printf 'NAME="Ubuntu"\nID=ubuntu\nVERSION_ID="22.04"\n'; }
  run checkOsID
  [ "$output" = "ubuntu" ]
}

@test "checkOsID (mocked cat): does NOT strip quotes around ID (documents real behavior)" {
  # Alpine, RHEL, Fedora, openSUSE ship a *quoted* ID, e.g. ID="alpine". checkOsID
  # uses a plain `cut`, so the quotes survive into the value. Downstream dispatch
  # tolerates it (consumers match with substring globs: [[ $oscheck == *"alpine"* ]]),
  # but the raw return value keeps its quotes — pin that so the quirk is visible.
  cat() { printf 'NAME="Alpine Linux"\nID="alpine"\n'; }
  run checkOsID
  [ "$output" = '"alpine"' ]
}

@test "checkOsVersionID (mocked cat): extracts VERSION_ID (keeps quotes, same as ID)" {
  cat() { printf 'ID=ubuntu\nVERSION_ID="22.04"\n'; }
  run checkOsVersionID
  [ "$output" = '"22.04"' ]
}
