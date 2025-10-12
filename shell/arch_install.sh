# exec "$0" volta para o início
# TODO: split this code into multiple files

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

set_keymap() {
  printf "${GREEN}[KEYBOARD]${RESET}: Setting up keymap...\n"

  while true; do
    printf "${GREEN}[KEYBOARD]${RESET}: Enter your keymap: \n"
    read -r keymap

    if [[ -z "$keymap" ]]; then
      printf "${RED}[KEYBOARD]${RESET}: Keymap cannot be empty. Try again.\n"
      continue
    fi

    if ! localectl list-keymaps | grep -Fxq "$keymap"; then
      printf "${RED}[KEYBOARD]${RESET}: Invalid keymap: ${keymap}"
    fi

    if localectl set-keymap --no-convert "$keymap"; then
      printf "${GREEN}[KEYBOARD]${RESET}: Keymap set to ${keymap}\n"
      break
    else
      printf "${RED}[KEYBOARD]${RESET}: Error setting keymap to ${keymap}\n"
    fi

  done
}

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

# TODO: dynamic partitioning sizes
partition_disk() {
  local disk="$1"
  local disk_size

  printf "${BLUE}[DISK]${RESET}: Partitioning ${disk}...\n"

  # Get disk size in MiB
  disk_size=$(parted "/dev/${disk}" unit MiB print | grep "^Disk" | awk '{print $3}' | sed 's/MiB//')
  swap_start=$((disk_size - 2048))

  if ! parted --script "/dev/${disk}" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 1025MiB \
    set 1 esp on \
    mkpart primary ext4 1025MiB ${swap_start}MiB \
    mkpart primary linux-swap ${swap_start}MiB 100%; then
    printf "${RED}[DISK]${RESET}: Failed to partition ${disk}.\n"
    return 1
  fi

  printf "${GREEN}[DISK]${RESET}: ${disk} partitioned successfully!\n"
  return 0
}

format_partitions() {
  local disk="$1"

  printf "${BLUE}[DISK]${RESET}: Formatting partitions...\n"

  mkfs.fat -F32 "/dev/${disk}1" || {
    printf "${RED}[DISK]${RESET}: Failed to format EFI partition.\n"
    return 1
  }

  mkfs.ext4 "/dev/${disk}2" || {
    printf "${RED}[DISK]${RESET}: Failed to format root partition.\n"
    return 1
  }

  mkswap "/dev/${disk}3" || {
    printf "${RED}[DISK]${RESET}: Failed to format swap partition.\n"
    return 1
  }

  swapon "/dev/${disk}3" || {
    printf "${RED}[DISK]${RESET}: Failed to activate swap.\n"
    return 1
  }

  printf "${GREEN}[DISK]${RESET}: Formatted successfully!\n"
  return 0
}

mount_partitions() {
  local disk="$1"
  local mount_point="$2"

  printf "${BLUE}[DISK]${RESET}: Mounting partitions...\n"

  mount "/dev/${disk}2" "$mount_point" || {
    printf "${RED}[DISK]${RESET}: Failed to mount root partition.\n"
    return 1
  }

  mkdir -p "${mount_point}/boot/efi" || {
    printf "${RED}[DISK]${RESET}: Failed to create EFI directory.\n"
    umount "$mount_point"
    return 1
  }

  mount "/dev/${disk}1" "${mount_point}/boot/efi" || {
    printf "${RED}[DISK]${RESET}: Failed to mount EFI partition.\n"
    umount "$mount_point"
    return 1
  }

  printf "${GREEN}[DISK]${RESET}: Mounted successfully!\n"
  return 0
}

partitioning_and_mounting() {
  local disk=""
  local mount_point="/mnt"

  printf "${GREEN}[DISK]${RESET}: Available disks: \n"
  lsblk -dn -o NAME,SIZE,TYPE | grep disk

  while true; do
    printf "${GREEN}[DISK]${RESET}: Select a disk: "
    read -r disk

    if [[ -z "$disk" ]] || ! lsblk -dn -o NAME | grep -Fxq "$disk"; then
      printf "${RED}[DISK]${RESET}: Disk not found, try again.\n"
      continue
    fi

    if ! partition_disk "$disk"; then
      continue
    fi

    if ! format_partitions "$disk"; then
      continue
    fi

    if mount_partitions "$disk" "$mount_point"; then
      break
    fi
  done
}

# TODO: Add input to select countries
# TODO: rate-mirrors is from AUR, we need to install it first
select_mirrors() {
  printf "${BLUE}[MIRRORS]${RESET}: Installing rate-mirrors...\n"

  if ! pacman -Sy rate-mirrors --noconfirm; then
    printf "${RED}[MIRRORS]${RESET}: Failed to install rate-mirrors.\n"
    return 1
  fi

  printf "${GREEN}[MIRRORS]${RESET}: rate-mirrors installed.\n"
  printf "${GREEN}[MIRRORS]${RESET}: Selecting mirrors...\n"

  if ! rate-mirrors \
    --save /etc/pacman.d/mirrorlist \
    --protocol https \
    --concurrency 4 \
    arch; then
    printf "${RED}[MIRRORS]${RESET}: rate-mirrors failed. Using fallback...\n"

    if ! curl -o /etc/pacman.d/mirrorlist https://archlinux.org/mirrorlist/all/; then
      printf "${RED}[MIRRORS]${RESET}: Failed to download fallback mirrorlist.\n"
      return 1
    fi

    sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
    printf "${GREEN}[MIRRORS]${RESET}: Fallback mirrorlist configured.\n"
    return 0
  fi

  printf "${GREEN}[MIRRORS]${RESET}: Mirrors configured successfuly.\n"
  return 0

}

install_essentials() {
  printf "${GREEN}[CORE]${RESET}: Installing essentials...\n"
  if pacstrap -K /mnt base linux linux-firmware sof-firmware base-devel \
    grub efibootmgr networkmanager amd-ucode git --noconfirm; then
    printf "${GREEN}[CORE]${RESET}: Essentials installed successfuly!\n"
  else
    printf "${RED}[CORE]${RESET}: Error installing essentials.\n"
    exit 1
  fi
}

run_fstab() {
  printf "${GREEN}[SYSTEM]${RESET}: Running fstab...\n"

  if genfstab -U /mnt >>/mnt/etc/fstab; then
    printf "${GREEN}[SYSTEM]${RESET}: fstab successfuly!\n"
  else
    printf "${RED}[SYSTEM]${RESET}: Failed to run fstab.\n"
  fi
}

# TODO: better valitdation
system_setting() {
  printf "${GREEN}[SYSTEM]${RESET}: Setting up network configs, core services and grub...\n"
  local root_passwd=""
  local user_passwd=""
  local username=""
  local hostname=""
  local region=""
  local city=""
  local locale=""
  local mount_point="/mnt"

  while true; do
    printf "${GREEN}[SYSTEM]${RESET}: Your region: \n"
    read -r region
    printf "${GREEN}[SYSTEM]${RESET}: Your city: \n"
    read -r city

    if [[ -z "$region" || -z "$city" ]]; then
      printf "${RED}[SYSTEM]${RESET}: Enter city and region!\n"
      continue
    fi

    printf "${GREEN}[SYSTEM]${RESET}: Enter system locale: \n"
    read -r locale

    if [[ -z "$locale" ]]; then
      printf "${RED}[SYSTEM]${RESET}: Enter a locale!\n"
      continue
    fi

    printf "${GREEN}[SYSTEM]${RESET}: Your hostname: \n"
    read -r hostname

    if [[ -z "$hostname" ]]; then
      printf "${RED}[SYSTEM]${RESET}: Enter a hostname!\n"
      continue
    fi

    printf "${GREEN}[SYSTEM]${RESET}: Root password: \n"
    read -rs root_passwd
    echo

    if [[ -z "$root_passwd" ]]; then
      printf "${RED}[SYSTEM]${RESET}: Enter a password!\n"
      continue
    fi

    printf "${GREEN}[SYSTEM]${RESET}: Your username: \n"
    read -r username
    printf "${GREEN}[SYSTEM]${RESET}: Your user password: \n"
    read -rs user_passwd
    echo

    if [[ -z "$username" || -z "$user_passwd" ]]; then
      printf "${RED}[SYSTEM]${RESET}: Enter an username and password!\n"
      continue
    fi

    # Execute commands inside arch-chroot
    arch-chroot "$mount_point" /bin/bash <<EOF
ln -sf "/usr/share/zoneinfo/${region}/${city}" /etc/localtime
hwclock --systohc
echo "LANG=${locale}" > /etc/locale.conf
sed -i "s/#${locale}/${locale}/" /etc/locale.gen
locale-gen
echo "KEYMAP=${keymap}" > /etc/vconsole.conf
hostnamectl hostname ${hostname}
echo "root:${root_passwd}" | chpasswd
useradd -m -G wheel -s /bin/bash ${username}
echo "${username}:${user_passwd}" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
systemctl enable NetworkManager
grub-install --target=x86_64-efi --efi-directory=/boot/efi/ --bootloader-id=GRUB --recheck
grub-mkconfig -o /boot/grub/grub.cfg
EOF

    break
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
      printf "${YELLOW}[WIRELESS]${RESET}: Skipping wireless setup. ""\
This process requires network connection, reexecute the script if you need wifi.\n"
      break
    else
      printf "${RED}[ERROR]${RESET}: Invalid option. Please try again.\n"
      continue
    fi
  done

  set_keymap
  partitioning_and_mounting
  select_mirrors
  install_essentials
  run_fstab
  system_setting
}

main
