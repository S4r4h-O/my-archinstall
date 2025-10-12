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
# TODO: split function for readabilty
partitioning_and_mounting() {
  local disk=""

  printf "${GREEN}[DISK]${RESET}: Available disks: \n"
  lsblk -dn -o NAME,SIZE,TYPE | grep disk

  while true; do
    printf "${GREEN}[DISK]${RESET}: Select a disk: "
    read -r disk

    if [[ -n "$disk" ]] && lsblk -dn -o NAME | grep -Fxq "$disk"; then
      printf "${BLUE}[DISK]${RESET}: Partitioning ${disk}...\n"

      if parted --script "/dev/${disk}" \
        mklabel gpt \
        mkpart ESP fat32 1MiB 1025MiB \
        set 1 esp on \
        mkpart primary ext4 1025MiB -2GiB \
        mkpart swap linux-swap -2GiB 100%; then
        printf "${GREEN}[DISK]${RESET}: ${disk} partitioned successfully!\n"

        printf "${BLUE}[DISK]${RESET}: Now formatting...\n"
        mkfs.fat -F32 "/dev/${disk}1"
        status_fat=$?

        mkfs.ext4 "/dev/${disk}2"
        status_ext4=$?

        mkswap "/dev/${disk}3"
        status_swap=$?

        swapon "/dev/${disk}3"
        status_swapon=$?

        if [[ $status_fat -eq 0 ]] && [[ $status_ext4 -eq 0 ]] && [[ $status_swap -eq 0 ]] && [[ $status_swapon -eq 0 ]]; then
          printf "${GREEN}[DISK]${RESET}: Formatted successfully!\n"

          printf "${GREEN}[DISK]${RESET}: Now mounting...\n"
          mount "/dev/${disk}2" /mnt
          status_root_mount=$?

          mkdir -p /mnt/boot/efi
          status_efi_dir=$?

          mount "/dev/${disk}1" /mnt/boot/efi
          status_efi_mount=$?

          if [[ $status_root_mount -eq 0 ]] && [[ $status_efi_dir -eq 0 ]] && [[ $status_efi_mount -eq 0 ]]; then
            printf "${GREEN}[DISK]${RESET}: Mounted successfully!\n"
          else
            printf "${RED}[DISK]${RESET}: Failed to mount partitions.\n"
          fi

        else
          printf "${RED}[DISK]${RESET}: Failed to format.\n"
          echo "Status codes: FAT=${status_fat} | EXT4=${status_ext4} | SWAP=${status_swap} | SWAPON=${status_swapon}"
        fi

        break
      else
        printf "${RED}[DISK]${RESET}: Failed to partition ${disk}.\n"
      fi
    else
      printf "${RED}[DISK]${RESET}: Disk not found, try again.\n"
    fi
  done
}

# TODO: Add input to select countries
select_mirrors() {
  printf "${BLUE}[MIRRORS]${RESET}: Installing reflector...\n"

  if pacman -Sy --noconfiirm reflector; then
    printf "${GREEN}[MIRRORS]${RESET}: Reflector installed.\n"
  else
    printf "${RED}[MIRRORS]${RESET}: Failed to install reflector.\n"
  fi
  printf "${GREEN}[MIRRORS]${RESET}: Selecting mirrors...\n"

  reflector --latest 10 --fastest 5 --protocol http --download-timeout 10 --save /etc/pacman.d/mirrorlist
}

# TODO: installation should not continue if this function is not successful
install_essentials() {
  printf "${GREEN}[CORE]${RESET}: Installing essentials...\n"
  if pacstrap -K /mnt base linux linux-firmware sof-firmware base-devel \
    grub efibootmgr networkmanager amd-ucode git --noconfirm; then
    printf "${GREEN}[CORE]${RESET}: Essentials installed successfuly!\n"
  else
    printf "${RED}[CORE]${RESET}: Error installing essentials.\n"
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
# TODO: split function
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
}

main
