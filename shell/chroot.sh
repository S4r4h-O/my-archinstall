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

    arch-chroot "$mount_point" /bin/bash <<EOF
set -e
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

    if [[ $? -eq 0 ]]; then
      printf "${GREEN}[SYSTEM]${RESET}: System configuration completed successfully\n"
      break
    else
      printf "${RED}[SYSTEM]${RESET}: Configuration failed, please try again\n"
    fi
  done
}
