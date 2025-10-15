_checkCommandExists() {
  cmd="$1"
  if ! command -v "${cmd}" >/dev/null; then
    echo 1
    return
  fi
  echo 0
  return
}
