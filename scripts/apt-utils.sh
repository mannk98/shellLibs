#!/bin/bash

command -v checkOsID >/dev/null 2>&1 || source "$(command -v checksystem 2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/checksystem")"

# Lazily populate $oscheck on first use — avoids reading /etc/os-release at every
# shell startup. Functions below call this at entry; subsequent calls are free.
_apt_oscheck() {
  [[ -n ${oscheck:-} ]] || oscheck=$(checkOsID)
}

#Updating package database
apt-update() {
  _apt_oscheck
  [[ ${oscheck} == *"alpine"* ]] && {
    apk update || return 1
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    yum update || return 1
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt update || return 1
  }
  return 0
}

#Showing available updates
# apt list --upgradeable
apt-list-upgradable() {
  _apt_oscheck
  [[ ${oscheck} == *"alpine"* ]] && {
    apk version -v || return 1
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    yum list updates || return 1
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt list --upgradable || return 1
  }
  return 0
}

#Showing installed
# apt list --installed
apt-list-installed() {
  _apt_oscheck
  [[ ${oscheck} == *"alpine"* ]] && {
    apk version -v || return 1
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    yum list installed || return 1
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt list --installed || return 1
  }

  return 0
}

#Showing package info
# apt show
apt-show() {
  _apt_oscheck
  local packageName="$1"
  [[ ${oscheck} == *"alpine"* ]] && {
    apk search "${packageName}" || return 1
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    yum info "${packageName}" || return 1
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt show "${packageName}" || return 1
  }
  return 0
}

#Install package -q
apt-install-quite() {
  _apt_oscheck
  #echo "$@"
  [[ ${oscheck} == *"alpine"* ]] && {
    for value in "$@"; do
      apk add -y -q "${value}" || return 1
      apk upgrade || return 1
    done
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    for value in "$@"; do
      yum install -y -q "${value}" || return 1
    done
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    for value in "$@"; do
      echo "${value}"
      apt install -y -q "${value}" || return 1
    done
  }

  return 0
}

apt-install() {
  _apt_oscheck
  #echo "$@"
  [[ ${oscheck} == *"alpine"* ]] && {
    for value in "$@"; do
      apk add -y "${value}" || return 1
      apk upgrade || return 1
    done
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    for value in "$@"; do
      yum install -y "${value}" || return 1
    done
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    for value in "$@"; do
      echo "${value}"
      apt install -y "${value}" || return 1
    done
  }
  return 0
}

#Remove package
apt-remove() {
  _apt_oscheck
  [[ ${oscheck} == *"alpine"* ]] && {
    for value in "$@"; do
      apk del -y -q "${value}" || return 1
    done
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    for value in "$@"; do
      yum remove -y -q "${value}" || return 1
    done
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    for value in "$@"; do
      apt remove -y -q "${value}" || return 1
    done
  }
  return 0
}

#Searching the package database
apt-search() {
  _apt_oscheck
  local package="$1"
  [[ ${oscheck} == *"alpine"* ]] && {
    apk search "${package}" || return 1
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    yum search "${package}" || return 1
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt search "${package}" || return 1
  }
  return 0
}

#Remove package and config file
apt-purge() {
  _apt_oscheck
  local package="$1"
  [[ ${oscheck} == *"alpine"* ]] && {
    apk del --purge "${package}" || return 1
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    sudo package-cleanup --orphans "${package}" || return 1
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt purge "${package}" || return 1
  }
  return 0
}

#Only downloading packages
apt-install-download-only() {
  _apt_oscheck
  [[ ${oscheck} == *"alpine"* ]] && {
    for value in "$@"; do
      apk fetch "${value}" || return 1
    done
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    yum install yum-downloadonly &>/dev/null
    for value in "$@"; do
      yum install --download-only "${value}" || return 1
    done
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    for value in "$@"; do
      apt install --download-only "${value}" || return 1
    done
  }
  return 0
}

apt-fix-broken-depend() {
  _apt_oscheck
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt install -f
  }
  return 0
}

# clean /var/cache/apt/archives && /var/cache/apt/archives/partial/
apt-clean-cache() {
  _apt_oscheck
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt clean
  }
  return 0
}

# search what package provide file / header file (.h)
apt-file-search() {
  _apt_oscheck
  filename=${1}
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt-file search "${filename}"
  }
  return 0
}

# Back-compat alias — this used to be a byte-for-byte copy of apt-disable-autoupdate
# (and carries the wrong prefix for this file). Kept as a thin wrapper so anyone who
# typed the old name still works; the canonical impl is apt-disable-autoupdate below.
admin-apt-disable-autoupdate() { apt-disable-autoupdate "$@"; }

apt-disable-autoupdate() {
  local content="
APT::Periodic::Update-Package-Lists \"0\";
APT::Periodic::Unattended-Upgrade \"0\";"

  if echo "${content}" >/etc/apt/apt.conf.d/20auto-upgrades; then
    systemctl restart apt-daily.timer
    echo "apt auto update is disabled"
    return 0
  else
    return 1
  fi
}

apt-setup-localrepo-debubuntu() {
  [[ -z ${1} || ${1} == "-h" ]] && {
    echo "Use: /path/to/localrepo <package1> <package2> ... <package n>"
    return 0
  }

  apt update

  localrepodir=$(realpath -s "${1}")
  count=0

  echo "Info: Clean apt cache..."
  sudo apt clean cache

  echo "Info: Download apps..."
  for value in "$@"; do
    ((count++))
    [[ $count == '0' ]] && {
      continue
    }
    apt install --download-only -y "${value}"
    #[[ $? != 0 ]] && return 1
  done

  mkdir -p "${localrepodir}"
  cp -r /var/cache/apt/archives/* "${localrepodir}"

  cd "${localrepodir}" || return 1
  mkdir amd64

  if ! command -v dpkg-scanpackages; then
    apt install -y dpkg-dev
  fi

  dpkg-scanpackages ./ /dev/null | gzip -9c >amd64/Packages.gz
  chmod u+x "${localrepodir}"

  repofilename=$(basename "${localrepodir}")
  echo "deb [trusted=yes] file:${localrepodir} amd64/" >/etc/apt/sources.list.d/"${repofilename}".list

  echo "INFO: Run "apt update" to load new source list"
}
# gcc linux-headers-6.5.0-18-generic docker-ce docker-ce-cli containerd.io docker-buildx-plugin nvidia-container-toolkit

apt-setup-localrepo-cenred() {
  [[ -z ${1} || ${1} == "-h" ]] && {
    echo "Use: local/path/repo <package1> <package2> ... <package n>"
    return 0
  }

  localrepodir="${1}"
  mkdir -p "${localrepodir}"
  count=0
  for value in "$@"; do
    ((count++))
    [[ $count == '0' ]] && {
      continue
    }
    yum install --downloadonly --downloaddir="${localrepodir}" "${value}"
    #[[ $? != 0 ]] && return 1
  done

  cp -r /tmp/yum/yumcache/* "${localrepodir}"

}
