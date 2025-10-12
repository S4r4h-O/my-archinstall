# TODO: sudo ip link set wlan0 up
wireless_connection() {
  local interface=""

  printf "${GREEN}[WIRELESS]${RESET}: Available wireless interfaces: \n"
  ip link show | grep -E '^[0-9]+: wl'

  printf "${GREEN}[WIRELESS]${RESET}: Attempting to unblock wlan0...\n"

  if rfkill unblock wlan0 2>/dev/null; then
    printf "${GREEN}[WIRELESS]${RESET}: wlan0 unblocked successfuly!\n"
    return 0
  fi

  printf "${RED}[WIRELESS]${RESET}: Failed to unblock wlan0.\n"

  while true; do
    printf "${GREEN}[WIRELESS]${RESET}: Enter interface name!\n"
    read -r interface

    if [[ -z "$interface" ]]; then
      printf "${RED}[WIRELESS]${RESET}: interface cannot be empty.\n"
      continue
    fi

    if ! ip link show "$interface" &>/dev/null; then
      printf "${RED}[WIRELESS]${RESET}: Interface $interface does not exist.\n"
      continue
    fi

    if rfkill unblock "$interface"; then
      printf "${GREEN}[WIRELESS]${RESET}: $interface unblocked successfuly!\n"
      break
    else
      printf "${RED}[WIRELESS]${RESET}: Failed to unblock $interface.\n"
    fi

  done

}

wifi_connect() {
  local station=""
  local wifi=""

  printf "${GREEN}[WIRELESS]${RESET}: Available wireless stations: \n"
  iwctl station list

  while true; do
    printf "${GREEN}[WIRELESS]${RESET}: Select a station to scan for wireless connections: \n"
    read -r station

    if [[ -z "$station" ]]; then
      printf "${GREEN}[WIRELESS]${RESET}: Enter a station!\n"
      continue
    fi

    printf "${BLUE}[WIRELESS]{RESET}: Scanning networks on ${station}"
    if ! iwctl station "$station" get-networks; then
      printf "${RED}[WIRELESS]${RESET}: Failed to scan. Invalid station or scan error.\n"
    fi

    printf "${GREEN}[WIRELESS]${RESET}: Select a wifi network: "
    read -r wifi

    if [[ -z "$wifi" ]]; then
      printf "${RED}[WIRELESS]${RESET}: Wifi cannot be empty.\n"
      continue
    fi

    if ! iwctl station "$station" connect "$wifi"; then
      printf "${RED}[WIRELESS]${RESET}: Could not connect, please try again.\n"
      continue
    fi

    printf "${GREEN}[WIRELESS]${RESET}: Connected to $wifi successfuly.\n"
    return 0

  done
}

# TODO: Add input to select countries
# TODO: rate-mirrors is from AUR, we need to install it first
# TODO: consider rankmirrors
select_mirrors() {
  printf "${BLUE}[MIRRORS]${RESET}: Installing rate-mirrors...\n"

  # Bootstrap with a stable mirror
  echo 'Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch' >/etc/pacman.d/mirrorlist

  if ! pacman -Sy --noconfirm rate-mirrors; then
    printf "${RED}[MIRRORS]${RESET}: Failed to install rate-mirrors.\n"
    return 1
  fi

  printf "${GREEN}[MIRRORS]${RESET}: rate-mirrors installed.\n"
  printf "${GREEN}[MIRRORS]${RESET}: Selecting mirrors...\n"

  if ! rate-mirrors --save /etc/pacman.d/mirrorlist --protocol https --concurrency 4 arch; then
    printf "${RED}[MIRRORS]${RESET}: rate-mirrors failed. Using fallback...\n"
    if ! curl --fail -o /etc/pacman.d/mirrorlist https://archlinux.org/mirrorlist/all/; then
      printf "${RED}[MIRRORS]${RESET}: Failed to download fallback mirrorlist.\n"
      return 1
    fi
    sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
    printf "${GREEN}[MIRRORS]${RESET}: Fallback mirrorlist configured.\n"
  else
    printf "${GREEN}[MIRRORS]${RESET}: Mirrors configured successfully.\n"
  fi
}
