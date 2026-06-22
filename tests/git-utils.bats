#!/usr/bin/env bats
#
# Regression test for scripts/git-utils. git is mocked so nothing touches a real repo.

setup() {
  load test_helper
  source "${SHELLLIBS_ROOT}/scripts/git-utils"
}

@test "git-push-create-merge defaults the branch name without executing it" {
  # Bug: `${nameOfMergeBranch:=mannk_temp_branch}` on its own line default-assigns AND
  # THEN runs the result as a command -> 'mannk_temp_branch: command not found'.
  git() { return 0; }
  run git-push-create-merge "my message"
  [ "$status" -eq 0 ]
  [[ "$output" != *"command not found"* ]] || return 1
}

# --- no global leak: positionals must be `local` ----------------------------
# Called DIRECTLY (not via `run`, whose subshell would mask a leak) with git mocked.

@test "git-config-name-mail does not leak Name/Mail into the shell" {
  git() { :; }
  unset Name Mail
  git-config-name-mail Alice a@b.c
  [ -z "${Name:-}" ] || return 1
  [ -z "${Mail:-}" ] || return 1
}

@test "git-delete-branch-on-remote does not leak branch_name into the shell" {
  git() { :; }
  unset branch_name
  git-delete-branch-on-remote feature-x
  [ -z "${branch_name:-}" ] || return 1
}
