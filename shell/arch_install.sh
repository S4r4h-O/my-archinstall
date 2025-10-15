#!/bin/bash

source ./storage.sh
source ./connectivity.sh
source ./keymap.sh
source ./chroot.sh
source ./logging.sh

install_essentials() {
  printf "${GREEN}[CORE]${RESET}: Installing essentials...\n"
  if pacstrap -K /mnt base linux linux-firmware base-devel \
    grub efibootmgr networkmanager git --noconfirm; then
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

main() {
  connectivity              # ./connectivity.sh
  set_keymap                #./keymap.sh
  partitioning_and_mounting # ./storage.sh
  select_mirrors            # ./connectivity.sh
  install_essentials
  run_fstab
  system_setting # ./chroot.sh
  printf "${GREEN}[SUCCESS]${RESET}: Arch Linux installed successfuly!\n"
  cp ./post-install.sh ./_lib.sh ./logging.sh ./pkgs.sh /mnt/home/${username}
}

main
