#!/bin/bash

source ./logging.sh

_checkCommandExists() {
  cmd="$1"
  if ! command -v "${cmd}" >/dev/null; then
    echo 1
    return
  fi
  echo 0
  return
}

_checkDirExists() {
  dir="$1"
  if [[ -d "$dir" ]]; then
    log "INFO" "Path ${dir} exists."
    return 0
  else
    return 1
  fi
}
