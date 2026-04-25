#!/bin/bash

#need sudo permission to execute
source ./scripts/logshell
source ./scripts/checksystem

# Resolve which user's ~/.bashrc we should append to. When invoked via `sudo`,
# $HOME and ~ point at /root — but the block needs to land in the *invoking*
# user's .bashrc so their next shell actually picks up scripts.
if [[ -n ${SUDO_USER:-} && ${SUDO_USER} != "root" ]]; then
	target_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
else
	target_home=${HOME}
fi
target_bashrc="${target_home}/.bashrc"

[[ $(checkIfRootSession) == "no" ]] && {
	log-step "Run as $USER"
	log-warning "Run as $USER non root only add script to ~/.bashrc, need to run as root to install src first."
}

[[ $(checkIfRootSession) == "yes" ]] && {
# clean old installed
log-info "Delete old source at /bin"
rm -rf /bin/scripts

[[ -e "/bin/apt-port" ]] && {
    for file in ./scripts/*; do
    	rm -f "$(which "${file##*/}")"
    done
}

# new installed
chmod +x ./scripts/*
if ! cp -r scripts /bin/scripts; then
	exit 1
fi
log-info "Done cp scripts to /bin/scripts folder."
}

# Managed block is delimited by unique markers so re-installs can remove the
# old copy and append a fresh one without touching the rest of .bashrc.
block_begin="# >>> shellLibs managed block >>>"
block_end="# <<< shellLibs managed block <<<"

# shellcheck disable=SC2016  # single-quoted template: $PATH and $(...) must be literal
sourceShellFiles="${block_begin}
# Managed by shellLibs install.sh — do not edit by hand; re-run install.sh to refresh.
"'export PATH="$PATH:/bin/scripts"

listSourceFiles=($(ls /bin/scripts))
for file in "${listSourceFiles[@]}"; do
	source $(which ${file})
done
'"${block_end}"

if [[ -f ${target_bashrc} ]] && grep -qF "${block_begin}" "${target_bashrc}"; then
	sed -i "/${block_begin}/,/${block_end}/d" "${target_bashrc}"
	log-info "Removed previous shellLibs block from ${target_bashrc}"
fi
echo "${sourceShellFiles}" >>"${target_bashrc}"
log-info "Appended shellLibs block to ${target_bashrc}"
