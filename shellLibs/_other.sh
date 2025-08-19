#!/bin/bash


function listFilesInDir() {
  [[ $1 == "-h" || -z $1 ]] && {
    echo "Usage: sudo $FUNCNAME <path/to/dir>"
    return 0
  }
  dirPath=${1}
  files=()
  for element in ${dirPath}/*; do
    [[ -f ${element} ]] && {
      files+="${element} "
    }
  done
  echo "${files[@]}"
  return 0
}

function listDirInDir() {
  [[ $1 == "-h" || -z $1 ]] && {
    echo "Usage: sudo $FUNCNAME <path/to/dir>"
    return 0
  }
  dirPath=${1}
  dirs=()
  for element in ${dirPath}/*; do
    [[ -d ${element} ]] && {
      dirs+="${element} "
    }
  done
  echo "${dirs[@]}"
  return 0
}
# list to arraay
#read -ra arraay  <<< "$list"

function install-qt5() {
  sudo apt update
  sudo apt install -y build-essential libfontconfig1 mesa-common-dev libglu1-mesa-dev
  sudo apt install -y qtcreator qtbase5-dev qt5-doc qt5-doc-html qtbase5-doc-html qtbase5-examples
}
