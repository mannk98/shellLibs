#!/usr/bin/env bash
# Shared setup for the bats suite.
#
# Resolves the repo root from the running .bats file so tests can
# `source "${SHELLLIBS_ROOT}/scripts/<name>"` no matter what the current
# working directory is. `load test_helper` (no extension) picks this file up
# from the same tests/ directory as the test that loads it.

SHELLLIBS_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
export SHELLLIBS_ROOT
