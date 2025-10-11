# exec "$0" volta para o início

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
BOLD="\033[1m"
RED_BOLD="\033[31m\033[1m"
GREEN_BOLD="\033[32m\033[1m"
YELLOW_BOLD="\033[33m\033[1m"
BLUE_BOLD="\033[34m\033[1m"
RESET="\033[0m"

# printf "${BOLD}${GREEN}Enter your hostname:${RESET} "
# read hostname
#
# printf "${BOLD}${GREEN}Enter your username:${RESET} "
# read username
#
#
# printf "${BOLD}${GREEN}Enter your region:${RESET} "
# read region
#
# printf "${BOLD}${GREEN}Enter your city:${RESET} "
# read city
#
# printf "${BOLD}${GREEN}Enter your locale:${RESET} \n"
# read locale

set_keymap() {
  local keymap=""
  printf "${GREEN}[KEYBOARD]${RESET}: Setting up keymap...\n"

  while true; do
    printf "${GREEN}[KEYBOARD]${RESET}: Enter your keymap:${RESET} "
    read -r keymap

    if [[ -n "$keymap" ]]; then
      if sudo localectl set-keymap --no-convert $keymap; then
        printf "${GREEN}[KEYBOARD]${RESET}: Keymap set to ${keymap}"
        break
      else
        printf "${RED}[KEYBOARD]${RESET}: Error setting keymap to ${keymap}"
        continue
      fi
    else
      printf "${RED}[KEYBOARD]${RESET}: Keymap cannot be empty. Try again.\n"
    fi

  done
}

# TODO: sudo ip link set wlan0 up
wireless_connection() {
  local interface=""

  printf "${GREEN}[WIRELESS]${RESET}: Available wireless interfaces: \n"
  ip link
  printf "${GREEN}[WIRELESS]${RESET}: Trying to unlock most common interface: \n"

  if rfkill unblock wlan0; then
    printf "${GREEN}[WIRELESS]${RESET}: wlan0 unblocked successfuly... \n"
    break
  else
    while true; do
      printf "${RED}[WIRELESS]${RESET}: Could not unblock wlan0... Enter you desired interface: "
      read -r interface

      if [[ -n "$interface" ]]; then
        if rfkill unblock $interface; then
          printf "${GREEN}[WIRELESS]${RESET}: ${interface} unblocked successfuly."
          break
        else
          printf "${RED}[WIRELESS]${RESET}: Could not unblock ${interface}, try again"
          continue
        fi
      else
        continue
      fi

    done
  fi
}

wifi_connect() {
  local station=""
  local wifi=""

  printf "${GREEN}[WIRELESS]${RESET}: Available wireless stations: \n"
  iwctl station list

  while true; do
    printf "${GREEN}[WIRELESS]${RESET}: Select a station to scan for wireless connections: "
    read -r station

    if [[ -n "$station" ]]; then
      printf "${GREEN}[WIRELESS]${RESET}: Scanning for networks on station $station...\n"
      if iwctl station "$station" get-networks; then
        printf "${GREEN}[WIRELESS]${RESET}: Select a Wi-Fi connection: "
        read -r wifi

        if [[ -n "$wifi" ]]; then
          if iwctl station "$station" connect "$wifi"; then
            printf "${GREEN}[WIRELESS]${RESET}: Connected successfully.\n"
            break
          else
            printf "${RED}[WIRELESS]${RESET}: Could not connect. Please try again.\n"
          fi
        else
          printf "${RED}[WIRELESS]${RESET}: No Wi-Fi network selected. Please try again.\n"
        fi
      else
        printf "${RED}[WIRELESS]${RESET}: Failed to scan for networks. Please try again.\n"
      fi
    else
      printf "${RED}[WIRELESS]${RESET}: No station selected. Please try again.\n"
    fi
  done
}

# TODO: dynamic partitioning sizes
partitioning() {
  local disk=""

  printf "${GREEN}[DISK]${RESET}: Available disks: \n"
  lsblk -dn -o NAME,SIZE,TYPE | grep disk

  while true; do
    printf "${GREEN}[DISK]${RESET}: Select a disk: "
    read -r disk

    if [[ -n "$disk" ]] && lsblk -dn -o NAME | grep -Fxq "$disk"; then
      printf "${GREEN}[DISK]${RESET}: Partitioning ${disk}...\n"

      if parted --script "/dev/${disk}" \
        mklabel gpt \
        mkpart ESP fat32 1MiB 1025MiB \
        set 1 esp on \
        mkpart primary ext4 1025MiB -2GiB \
        mkpart swap linux-swap -2GiB 100%; then
        printf "${GREEN}[DISK]${RESET}: ${disk} partitioned successfully!\n"
        break
      else
        printf "${RED}[DISK]${RESET}: Failed to partition ${disk}.\n"
      fi
    else
      printf "${RED}[DISK]${RESET}: Disk not found, try again.\n"
    fi
  done
}

main() {
  while true; do
    printf "${BOLD}${GREEN}Want to setup wireless connections?: (y/n)${RESET} "
    read -r is_wireless

    if [[ "$is_wireless" == "y" ]]; then
      wireless_connection
      wifi_connect
      break
    elif [[ "$is_wireless" == "n" ]]; then
      printf "${YELLOW}[WIRELESS]${RESET}: Skipping wireless setup.\n"
      break
    else
      printf "${RED}[ERROR]${RESET}: Invalid option. Please try again.\n"
      continue
    fi
  done

  set_keymap
  partitioning
}

main
