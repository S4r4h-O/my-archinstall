#!/bin/bash

# TODO: split this code into multiple files

source ./storage.sh
source ./connectivity.sh

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
      continue
    fi

    if localectl set-keymap --no-convert "$keymap"; then
      printf "${GREEN}[KEYBOARD]${RESET}: Keymap set to ${keymap}\n"
      break
    else
      printf "${RED}[KEYBOARD]${RESET}: Error setting keymap to ${keymap}\n"
    fi

  done
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
    exit 1
  fi
}

# TODO: better valitdation
# TODO: should exit if fail
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
      # from ./connectivity.sh
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
  # from ./storage.sh
  partitioning_and_mounting
  # from ./connectivity.sh
  select_mirrors
  install_essentials
  run_fstab
  system_setting
  printf "${GREEN}[SUCCESS]${RESET}: Arch Linux installed successfuly!\n"
}

main
