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
