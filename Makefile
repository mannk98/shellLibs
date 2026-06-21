SHELL := /bin/bash

SOURCES := $(wildcard scripts/*) install.sh
SHELLCHECK_FLAGS := --shell=bash --severity=style
REPORT := agent_docs/shellcheck-report.txt

.PHONY: help lint lint-ci lint-report lint-install test test-install

help:
	@echo "Targets:"
	@echo "  lint          Run shellcheck (severity=style) — shows everything incl. the tracked SC2015"
	@echo "  lint-ci       CI gate: shellcheck severity=warning — fails only on real warnings/errors"
	@echo "  lint-report   Run shellcheck and save full output to $(REPORT)"
	@echo "  lint-install  Install shellcheck via apt (needs sudo)"
	@echo "  test          Run the bats unit-test suite in tests/"
	@echo "  test-install  Install bats-core (brew / apt / npm, auto-detected)"

lint:
	@command -v shellcheck >/dev/null || { echo "shellcheck not found — run 'make lint-install'"; exit 1; }
	shellcheck $(SHELLCHECK_FLAGS) $(SOURCES)

# CI gate. severity=warning excludes the tracked SC2015 (info, see improvement-proposals.md §9),
# so this exits 0 unless a real warning/error is introduced.
lint-ci:
	@command -v shellcheck >/dev/null || { echo "shellcheck not found — run 'make lint-install'"; exit 1; }
	shellcheck --shell=bash --severity=warning $(SOURCES)

lint-report:
	@command -v shellcheck >/dev/null || { echo "shellcheck not found — run 'make lint-install'"; exit 1; }
	@mkdir -p $(dir $(REPORT))
	-shellcheck $(SHELLCHECK_FLAGS) $(SOURCES) > $(REPORT) 2>&1
	@echo "Report written to $(REPORT) ($$(wc -l < $(REPORT)) lines)"

lint-install:
	sudo apt install -y shellcheck

test:
	@command -v bats >/dev/null || { echo "bats not found — run 'make test-install'"; exit 1; }
	bats tests/

test-install:
	@if command -v brew >/dev/null; then brew install bats-core; \
	elif command -v apt >/dev/null; then sudo apt install -y bats; \
	elif command -v npm >/dev/null; then sudo npm install -g bats; \
	else echo "Install bats-core manually: https://github.com/bats-core/bats-core"; exit 1; fi
