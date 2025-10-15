# --------------------------------------------------------------
# Colors
# --------------------------------------------------------------

RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[34m"
YELLOW="\033[33m"
RESET="\033[0m"

log() {
  local level="$1"
  shift
  printf "${BLUE}[${level}]${RESET}: $@\n"
}

logError() {
  printf "${ERROR}[ERROR]${RESET}: $@\n"
}

logSuccess() {
  printf "${GREEN}[ERROR]${RESET}: $@\n"
}

logWarning() {
  printf "${YELLOW}[WARNING]${RESET}: $@\n"
}
