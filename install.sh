#!/bin/bash

#need sudo permission to execute
source ./shellLibs/logshell
source ./shellLibs/checksystem

[[ $(checkIfRootSession) == "no" ]] && {
	log-step "Run as $USER"
	log-warning "Run as $USER non root only add script to ~/.bashrc, need to run as root to install src first."
}

[[ $(checkIfRootSession) == "yes" ]] && {
# clean old installed
log-info "Delete old source at /bin"
rm -rf /bin/shellLibs

[[ -e "/bin/apt-port" ]] && {
    oldSourceFiles=($(ls ./shellLibs))
    for file in "${oldSourceFiles[@]}"; do
    	rm -f $(which ${file})
    done
}

# new installed
chmod +x ./shellLibs/*
cp -r shellLibs /bin

[[ $? != 0 ]] && {
	exit 1
} || log-info "Done cp shellLibs to /bin/bash folder."
}

sourceShellFiles='
export PATH="$PATH:/bin/shellLibs"

listSourceFiles=($(ls /bin/shellLibs))
for file in "${listSourceFiles[@]}"; do
	source $(which ${file})
done'

[[ $(checkIfFileHaveText "listSourceFiles" ~/.bashrc) == "yes" ]] && {
	log-info "~/.bashrc already have source source files"
} || {
	echo "${sourceShellFiles}" >>~/.bashrc
	log-info "Done add source source files to ~/.bashrc"
}