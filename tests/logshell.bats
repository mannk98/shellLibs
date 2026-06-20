#!/usr/bin/env bats
#
# Unit tests for scripts/logshell — the color/level-gated logger.
# These are "pure" functions (no system calls), so we just source the file
# and assert on what each function prints. Assertions deliberately avoid the
# timestamp (its format differs between Linux `date` and macOS `date`) and
# match on the level tag + the message instead.

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/logshell"
}

@test "log-info prints the message tagged [info]" {
  run log-info "hello world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[info]"* ]]
  [[ "$output" == *"hello world"* ]]
}

@test "log-warning prints the message tagged [warn]" {
  run log-warning "careful now"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[warn]"* ]]
  [[ "$output" == *"careful now"* ]]
}

@test "log-error prints the message tagged [err]" {
  run log-error "boom"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[err]"* ]]
  [[ "$output" == *"boom"* ]]
}

@test "LOG_LEVEL gating: at WARNING level, log-debug is silent" {
  # NOTE: a gated-out log call returns non-zero (the `(( LOG_LEVEL <= ... ))`
  # test evaluates false), so we assert only on the contract that matters —
  # that nothing is printed — not on $status.
  LOG_LEVEL=$LOG_LEVEL_WARNING
  run log-debug "this must not appear"
  [ -z "$output" ]
}

@test "LOG_LEVEL gating: at WARNING level, log-info is silent" {
  LOG_LEVEL=$LOG_LEVEL_WARNING
  run log-info "this must not appear"
  [ -z "$output" ]
}

@test "LOG_LEVEL gating: at WARNING level, log-warning still shows" {
  LOG_LEVEL=$LOG_LEVEL_WARNING
  run log-warning "this should appear"
  [[ "$output" == *"[warn]"* ]]
  [[ "$output" == *"this should appear"* ]]
}

@test "LOG_LEVEL gating: at DEBUG level, log-debug shows" {
  # the debug tag is [dbg], not [debug]
  LOG_LEVEL=$LOG_LEVEL_DEBUG
  run log-debug "debug visible"
  [[ "$output" == *"[dbg]"* ]]
  [[ "$output" == *"debug visible"* ]]
}

@test "log-info joins multiple arguments into one line" {
  run log-info one two three
  [[ "$output" == *"one two three"* ]]
}

@test "timestamp is well-formed on this host (no literal %N / 3N leak)" {
  # Contract check against whatever `date` this host actually has: a real
  # YYYY-MM-DD HH:MM:SS stamp with no stray '%' or '3N'.
  run log-info "ts check"
  [ "$status" -eq 0 ]
  [[ "$output" != *"3N"* ]]
  [[ "$output" != *"%"* ]]
  local re='[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'
  [[ "$output" =~ $re ]]
}

@test "timestamp regression: BSD/macOS date (no %3N) falls back, never leaks 3N" {
  # Deterministic regression independent of the runner's real `date`. Simulate
  # macOS/BSD: `date +%3N` returns the literal "3N" (the bug trigger). _get_timestamp
  # must detect that and fall back to second precision — so nothing leaks "3N".
  # This FAILS against the old logshell, which always used `%3N`.
  unset _LOGSHELL_HAS_NANOS
  date() {
    case "$1" in
    "+%3N") echo "3N" ;;
    "+%F %T,%3N") echo "2026-06-20 13:14:15,3N" ;;
    "+%F %T") echo "2026-06-20 13:14:15" ;;
    *) command date "$@" ;;
    esac
  }
  run log-info "bsd"
  [ "$status" -eq 0 ]
  [[ "$output" != *"3N"* ]]
  [[ "$output" == *"2026-06-20 13:14:15"* ]]
}

@test "timestamp regression: GNU date (%3N works) keeps millisecond precision" {
  # Simulate GNU coreutils: `date +%3N` returns three digits, so _get_timestamp uses
  # the millisecond form and emits ",NNN".
  unset _LOGSHELL_HAS_NANOS
  date() {
    case "$1" in
    "+%3N") echo "016" ;;
    "+%F %T,%3N") echo "2026-06-20 13:14:15,016" ;;
    "+%F %T") echo "2026-06-20 13:14:15" ;;
    *) command date "$@" ;;
    esac
  }
  run log-info "gnu"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-06-20 13:14:15,016"* ]]
  [[ "$output" != *"3N"* ]]
}
