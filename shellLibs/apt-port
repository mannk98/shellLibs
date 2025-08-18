#!/bin/bash

source "$(which checksystem)"

export oscheck
oscheck="$(checkOsID)"

#Updating package database
apt-update() {
  [[ ${oscheck} == *"alpine"* ]] && {
    apk update
    [[ $? != 0 ]] && return 1
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    yum update
    [[ $? != 0 ]] && return 1
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt update
    [[ $? != 0 ]] && return 1
  }
  return 0
}

#Showing available updates
# apt list --upgradeable
apt-list-upgradable() {
  [[ ${oscheck} == *"alpine"* ]] && {
    apk version -v
    [[ $? != 0 ]] && return 1
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    yum list updates
    [[ $? != 0 ]] && return 1
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt list --upgradable
    [[ $? != 0 ]] && return 1
  }
  return 0
}

#Showing installed
# apt list --installed
apt-list-installed() {
  [[ ${oscheck} == *"alpine"* ]] && {
    apk version -v
    [[ $? != 0 ]] && return 1
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    yum list installed
    [[ $? != 0 ]] && return 1
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt list --installed
    [[ $? != 0 ]] && return 1
  }

  return 0
}

#Showing package info
# apt show
apt-show() {
  local packageName="$1"
  [[ ${oscheck} == *"alpine"* ]] && {
    apk search "${packageName}"
    [[ $? != 0 ]] && return 1
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    yum info "${packageName}"
    [[ $? != 0 ]] && return 1
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt show "${packageName}"
    [[ $? != 0 ]] && return 1
  }
  return 0
}

#Install package -q
apt-install-quite() {
  #echo "$@"
  [[ ${oscheck} == *"alpine"* ]] && {
    for value in "$@"; do
      apk add -y -q "${value}" && apk upgrade
      [[ $? != 0 ]] && return 1
    done
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    for value in "$@"; do
      yum install -y -q "${value}" #&& apk upgrade
      [[ $? != 0 ]] && return 1
    done
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    for value in "$@"; do
      echo "${value}"
      apt install -y -q "${value}" #&& apk upgrade
      [[ $? != 0 ]] && return 1
    done
  }

  return 0
}

apt-install() {
  #echo "$@"
  [[ ${oscheck} == *"alpine"* ]] && {
    for value in "$@"; do
      apk add -y "${value}" && apk upgrade
      [[ $? != 0 ]] && return 1
    done
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    for value in "$@"; do
      yum install -y "${value}" #&& apk upgrade
      [[ $? != 0 ]] && return 1
    done
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    for value in "$@"; do
      echo "${value}"
      apt install -y "${value}" #&& apk upgrade
      [[ $? != 0 ]] && return 1
    done
  }
  return 0
}

#Remove package
apt-remove() {
  [[ ${oscheck} == *"alpine"* ]] && {
    for value in "$@"; do
      apk del -y -q "${value}"
      [[ $? != 0 ]] && return 1
    done
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    for value in "$@"; do
      yum remove -y -q "${value}" #&& apk upgrade
      [[ $? != 0 ]] && return 1
    done
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    for value in "$@"; do
      apt remove -y -q "${value}" #&& apk upgrade
      [[ $? != 0 ]] && return 1
    done
  }
  return 0
}

#Searching the package database
apt-search() {
  local package="$1"
  [[ ${oscheck} == *"alpine"* ]] && {
    apk search "${package}"
    [[ $? != 0 ]] && return 1
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    yum search "${package}"
    [[ $? != 0 ]] && return 1
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt search "${package}"
    [[ $? != 0 ]] && return 1
  }
  return 0
}

#Remove package and config file
apt-purge() {
  local package="$1"
  [[ ${oscheck} == *"alpine"* ]] && {
    apk del --purge "${package}"
    [[ $? != 0 ]] && return 1
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    sudo package-cleanup --orphans "${package}"
    [[ $? != 0 ]] && return 1
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt purge "${package}"
    [[ $? != 0 ]] && return 1
  }
  return 0
}

#Only downloading packages
apt-install-download-only() {
  [[ ${oscheck} == *"alpine"* ]] && {
    for value in "$@"; do
      apk fetch "${value}"
      [[ $? != 0 ]] && return 1
    done
  }
  [[ ${oscheck} == *"centos"* || ${oscheck} == *"almalinux"* || ${oscheck} == *"rocky"* ]] && {
    yum install yum-downloadonly &>/dev/null
    for value in "$@"; do
      yum install --download-only "${value}"
      [[ $? != 0 ]] && return 1
    done
  }
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    for value in "$@"; do
      apt install --download-only "${value}"
      [[ $? != 0 ]] && return 1
    done
  }
  return 0
}

apt-fix-broken-depend() {
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt install -f
  }
  return 0
}

# clean /var/cache/apt/archives && /var/cache/apt/archives/partial/
apt-clean-cache() {
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt clean
  }
  return 0
}

# search what package provide file / header file (.h)
apt-file-search() {
  filename=${1}
  [[ ${oscheck} == *"debian"* || ${oscheck} == *"ubuntu"* ]] && {
    apt-file search "${filename}"
  }
  return 0
}

admin-apt-disable-autoupdate() {
  local content="
APT::Periodic::Update-Package-Lists \"0\";
APT::Periodic::Unattended-Upgrade \"0\";"

  if echo "${content}" >/etc/apt/apt.conf.d/20auto-upgrades; then
    systemctl restart apt-daily.timer
    return 0
  else
    return 1
  fi

  echo "apt auto update is disabled"
}

apt-disable-autoupdate() {
  local content="
APT::Periodic::Update-Package-Lists \"0\";
APT::Periodic::Unattended-Upgrade \"0\";"

  if echo "${content}" >/etc/apt/apt.conf.d/20auto-upgrades; then
    systemctl restart apt-daily.timer
    return 0
  else
    return 1
  fi
  echo "apt auto update is disabled"
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

  cd "${localrepodir}" || exit
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

  mkdir -p "${localrepodir}"
  localrepodir="${1}"
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

apt-setup-OCRInstall() {
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg &&
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |
      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

  sudo apt-get update
  apt-setup-localrepo-debubuntu gcc linux-headers-"$(uname -r)" nvidia-container-toolkit
}

apt-remove-NvidiaDriver() {
  sudo apt-get remove --purge '^nvidia-.*'
}
