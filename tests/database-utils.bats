#!/usr/bin/env bats
#
# Tests for scripts/database-utils after the eval->argv refactor. Two styles:
#  - dry-run: assert the previewed command + the _confirm gate, touching nothing.
#  - real mode with `mysql`/`psql` shadowed by a recorder: prove the SQL reaches the
#    client as a SINGLE --execute argv element (i.e. no `eval` re-parsing the string).

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/database-utils"
  export MANNK_MYSQL_USER=root MANNK_MYSQL_HOST=localhost MANNK_MYSQL_PASS=
}

@test "mysql-createDB works with one arg and runs mysql with the SQL as one --execute arg" {
  # arity fix (was -z \$2, blocking the documented single-arg call) + eval->argv.
  mysql() { printf 'ARG:%s\n' "$@"; }
  run mysql-createDB mydb
  [ "$status" -eq 0 ]
  [[ "$output" == *"ARG:--execute=CREATE DATABASE mydb;"* ]] || return 1
}

@test "mysql-createDB passes a SQL string with shell metachars as ONE arg (no eval re-split)" {
  mysql() { printf 'ARG:%s\n' "$@"; }
  run mysql-createTable 'T (id int); SELECT 1'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ARG:--execute=CREATE TABLE T (id int); SELECT 1;"* ]] || return 1
}

@test "mysql-createUser yes uses mysql_native_password, not the invalid use_native_pass" {
  mysql() { printf 'ARG:%s\n' "$@"; }
  run mysql-createUser bob secret '%' yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"mysql_native_password"* ]] || return 1
  [[ "$output" != *"use_native_pass"* ]] || return 1
}

@test "mysql-dropDB (dry-run) asks first and previews the DROP, touches nothing" {
  SHELLLIBS_DRYRUN=1 run mysql-dropDB mydb
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]] || return 1
  [[ "$output" == *"would ask"* ]] || return 1
  [[ "$output" == *"--execute=DROP"* ]] || return 1
}

@test "mysql-truncateTable (dry-run) asks first and previews the TRUNCATE" {
  SHELLLIBS_DRYRUN=1 run mysql-truncateTable mytable
  [ "$status" -eq 0 ]
  [[ "$output" == *"would ask"* ]] || return 1
  [[ "$output" == *"--execute=TRUNCATE"* ]] || return 1
}

@test "mysql-dropDB refuses with no TTY and no ASSUME_YES (the _confirm gate holds)" {
  mysql() { printf 'ARG:%s\n' "$@"; }
  run mysql-dropDB mydb
  [ "$status" -ne 0 ]
  [[ "$output" != *"ARG:--execute=DROP"* ]] || return 1
}

@test "mysql-connect (dry-run) previews an interactive mysql session (no --execute)" {
  SHELLLIBS_DRYRUN=1 run mysql-connect
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would run: mysql -u root"* ]] || return 1
  [[ "$output" != *"--execute"* ]] || return 1
}

@test "psql-connect (dry-run) previews psql without -W and without leaking the password" {
  SHELLLIBS_DRYRUN=1 run psql-connect bob db.example 5432 s3cret
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would run: psql -U bob"* ]] || return 1
  [[ "$output" != *"-W"* ]] || return 1
  [[ "$output" != *"s3cret"* ]] || return 1
}
