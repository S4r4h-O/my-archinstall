#!/bin/bash

source ./storage.sh
source ./connectivity.sh
source ./keymap.sh
source ./chroot.sh
source ./logging.sh

install_essentials() {
  log "CORE" "Installing essentials..."
  if pacstrap -K /mnt base linux linux-firmware base-devel \
    grub efibootmgr networkmanager git --noconfirm; then
    log "CORE" "Essentials installed successfuly!"
  else
    logError "Error installing essentials."
    exit 1
  fi
}

run_fstab() {
  log "SYSTEM" "Running fstab..."

  if genfstab -U /mnt >>/mnt/etc/fstab; then
    log "SYSTEM" "fstab successfuly!"
  else
    logError "SYSTEM" "Failed to run fstab"
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
}

main
cp ./post-install.sh ./_lib.sh ./logging.sh ./pkgs.sh /mnt/home/${username}
