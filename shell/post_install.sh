#!/bin/bash

cp ./to_install.txt /mnt/to_install.txt
arch-chroot /mnt /bin/bash <<'EOF'
set -e

RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[34m"
YELLOW="\033[33m"
RESET="\033[0m"

printf "${BLUE}[POST INSTALL]${RESET}: Running post install script...\n"
pacman -Syy --noconfirm

printf "${BLUE}[POST INSTALL]${RESET}: Installing apps...\n"
APPS=$(grep -Ev '^#|^$' /to_install.txt)
if ! pacman -S --noconfirm $APPS; then
  printf "${RED}[POST INSTALL]${RESET}: Failed to install some packages.\n"
fi
rm /to_install.txt

printf "${BLUE}[POST INSTALL]${RESET}: LazyVim installation...\n"
mkdir -p /home/sarah/.config
git clone https://github.com/S4r4h-O/my-lazyvim.git /home/sarah/.config/nvim
chown -R sarah:sarah /home/sarah/.config

su - sarah <<'SARAH_EOF'
RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[34m"
YELLOW="\033[33m"
RESET="\033[0m"

# TODO: replace with paru
printf "${BLUE}[POST INSTALL]${RESET}: Installing paru AUR helper...\n"
cd /tmp

if ! timeout 30 git clone https://aur.archlinux.org/paru.git; then
  printf "${RED}[POST INSTALL]${RESET}: Failed to clone paru (timeout or error). Retrying...\n"
  sleep 2
  if ! timeout 30 git clone https://aur.archlinux.org/paru.git; then
    printf "${RED}[POST INSTALL]${RESET}: Failed to install paru (timeout or error). Skipping AUR helper.\n"
    exit 0
  fi
fi

cd paru
makepkg --noconfirm
sudo pacman -U --noconfirm paru-*.pkg.tar.zst
cd /tmp
rm -rf paru

paru -Syu --noconfirm

printf "${BLUE}[POST INSTALL]${RESET}: Installing zsh and Oh My Zsh...\n"
sudo pacman -S zsh --noconfirm
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

cd /tmp
git clone https://github.com/S4r4h-O/my-linux.git
cp my-linux/zsh/.zshrc /home/sarah/.zshrc
cp my-linux/zsh/aliases.zsh /home/sarah/.oh-my-zsh/custom/aliases.zsh
rm -rf my-linux
SARAH_EOF

printf "${BLUE}[POST INSTALL]${RESET}: Setting default shell to zsh...\n"
chsh -s /bin/zsh sarah

printf "${BLUE}[POST INSTALL]${RESET}: Setting up greeter...\n"
systemctl enable ly.service
cat >> /etc/ly/config.ini <<'LY_EOF'
default_user=sarah
default_session=Hyprland
LY_EOF

printf "${GREEN}[POST INSTALL]${RESET}: Post install completed successfully.\n"
EOF
