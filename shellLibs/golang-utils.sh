#!/bin/bash

# Initialize a Go test project
go-init-testProj() {
  # Check if Go is installed
  command -v go >/dev/null 2>&1 || {
    echo "Error: Go is not installed. Please install Go first."
    return 1
  }

  # Validate and create temporary directory
  local tmpdir
  tmpdir=$(mktemp -d 2>/dev/null) || {
    echo "Error: Failed to create temporary directory."
    return 1
  }

  # Clone and build gotools
  if ! git clone --depth=1 git@github.com:mannk98/gotools.git "$tmpdir/gotools"; then
    echo "Error: Failed to clone gotools repository."
    rm -rf "$tmpdir"
    return 1
  fi

  cd "$tmpdir/gotools" || {
    echo "Error: Failed to change to gotools directory."
    rm -rf "$tmpdir"
    return 1
  }

  if ! go build; then
    echo "Error: Failed to build gotools."
    rm -rf "$tmpdir"
    return 1
  fi

  # Initialize project
  if ! ./gotools mod_init test || ! ./gotools init --viper || ! ./gotools mod_tidy; then
    echo "Error: Failed to initialize test project."
    rm -rf "$tmpdir"
    return 1
  fi

  echo "Info: Test project created at: $tmpdir/gotools"
  return 0
}

# Configure private Go repository
go-setup-privateRepo() {
  if [[ -z $1 || -z $2 || $1 == "-h" || $2 == "-h" ]]; then
    echo "Usage: $FUNCNAME <http-url> <ssh-url>"
    echo "Example: $FUNCNAME https://github.com/mannk98 git@github.com:mannk98"
    return 1
  fi

  local http_url=$1
  local ssh_url=$2

  # Validate URLs
  if [[ ! $http_url =~ ^https?:// || ! $ssh_url =~ ^git@ ]]; then
    echo "Error: Invalid URL format. Ensure HTTP and SSH URLs are correct."
    return 1
  fi

  export GOPRIVATE="${ssh_url}/*"
  git config --global url."${ssh_url}".insteadOf "${http_url}"
  echo "Info: Configured GOPRIVATE for ${ssh_url}/*"
  return 0
}

# Display Go module dependencies
go-track-package() {
  go mod graph 2>/dev/null || {
    echo "Error: Failed to generate module graph. Ensure you're in a Go module directory."
    return 1
  }
}
