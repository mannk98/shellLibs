#!/bin/bash

function go-init-testProj() {
  if ! command -v go; then
    echo "Error: Install go first."
    return 1
  fi
  git clone git@github.com:mannk98/gotools.git
  cd gotools
  go build
  tmpdir=$(mktemp -d)
  cp gotools "$tmpdir"
  cd "$tmpdir"
  gotools mod_init test
  gotools init --viper
  gotools mod_tidy

  echo "Info: Test project path: $tmpdir"
}

function go-setup-privateRepo() {
  [[ -z $1 || $1 == "-h" ]] && {
    echo "Use: $FUNCNAME <httpurl> <sshurl>
    Example: https://github.com/mannk98 git@github.com:/mannk98"
  }

  export GOPRIVATE=${2}/*
  git config --global url."${2}".insteadOf "${1}"
}

function go-track-package() {
  go mod graph
}
