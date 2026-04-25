SHELL := /bin/bash

SOURCES := $(wildcard scripts/*) install.sh
SHELLCHECK_FLAGS := --shell=bash --severity=style
REPORT := agent_docs/shellcheck-report.txt

.PHONY: help lint lint-report lint-install

help:
	@echo "Targets:"
	@echo "  lint          Run shellcheck on scripts/* and install.sh"
	@echo "  lint-report   Run shellcheck and save full output to $(REPORT)"
	@echo "  lint-install  Install shellcheck via apt (needs sudo)"

lint:
	@command -v shellcheck >/dev/null || { echo "shellcheck not found — run 'make lint-install'"; exit 1; }
	shellcheck $(SHELLCHECK_FLAGS) $(SOURCES)

lint-report:
	@command -v shellcheck >/dev/null || { echo "shellcheck not found — run 'make lint-install'"; exit 1; }
	@mkdir -p $(dir $(REPORT))
	-shellcheck $(SHELLCHECK_FLAGS) $(SOURCES) > $(REPORT) 2>&1
	@echo "Report written to $(REPORT) ($$(wc -l < $(REPORT)) lines)"

lint-install:
	sudo apt install -y shellcheck
