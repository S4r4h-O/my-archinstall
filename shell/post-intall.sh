source ./logging.sh
source ./_lib.sh
source ./pkgs.sh

_isInstalled() {
  packages="$1"
  check="$(sudo pacman -Qs --color always "${packages}" | grep "local" | grep "${packages} ")"
  if [[ -n "${check}" ]]; then
    echo 0
    return
  fi
  echo 1
  return
}

_installParu() {
  if ! timeout 30 git clone "https://aur.archlinux.org/paru.git"; then
    printf "${RED}[POST INSTALL]${RESET}: Failed to clone paru. Retrying...\n"
    sleep 2
    if ! timeout 30 git clone "https://aur.archlinux.org/paru.git"; then
      printf "${RED}[POST INSTALL]${RESET}: Failed to install paru. Skipping AUR helper.\n"
    fi
  fi

  if [[ -d paru ]]; then
    cd paru
    if makepkg --noconfirm && sudo pacman -U --noconfirm paru-*.pkg.tar.zst; then
      printf "${GREEN}[POST INSTALL]${RESET}: paru installed successfully.\n"
      cd /tmp
      rm -rf paru
      paru -Syu --noconfirm
    else
      printf "${RED}[POST INSTALL]${RESET}: Failed to build/install paru.\n"
      cd /tmp
      rm -rf paru
    fi
  else
    printf "${YELLOW}[POST INSTALL]${RESET}: Skipping paru installation.\n"
  fi
}

_installPackages() {
  local to_install=()

  for pkg; do
    if [[ $(_isInstalled "${pkg}") == 0 ]]; then
      logWarning "${pkg} is already installed."
    else
      to_install+=("${pkg}")
    fi
  done

  if [[ ${#to_install[@]} -gt 0 ]]; then
    log "INFO" "Installing ${#to_install[@]} packages"
    sudo acman -S --noconfirm "${to_install[@]}" || {
      logError "Some packages failed to install."
      exit 1
    }
  fi
}

log "POST INSTALL" "Installing post install packages..."
# --------------------------------------------------------------
# Install figlet and loolcat
# --------------------------------------------------------------
if [[ $(_checkCommandExists "figlet" == 0) ]]; then
  log "POST INSTALL" "gum is already installed."
else
  logWarning "The installer requires figlet. figlet will be installed now."
  sudo pacman --noconfirm -S figlet
fi

if [[ $(_checkCommandExists "lolcat" == 0) ]]; then
  log "POST INSTALL" "lolcat is already installed."
else
  logWarning "The installer requires lolcat. lolcat will be installed now."
  sudo pacman --noconfirm -S lolcat
fi

# --------------------------------------------------------------
# Install Paru if needed
# --------------------------------------------------------------
_installParu

# --------------------------------------------------------------
# General
# --------------------------------------------------------------
_installPackages "${general[@]}"

# --------------------------------------------------------------
# Desktop Environment
# --------------------------------------------------------------
_installPackages "${desktop_environ[@]}"

# --------------------------------------------------------------
# Programming languages
# --------------------------------------------------------------
_installPackages "${languages[@]}"

# --------------------------------------------------------------
# Tools
# --------------------------------------------------------------
_installPackages "${tools[@]}"

# --------------------------------------------------------------
# Drivers
# --------------------------------------------------------------
_installPackages "${drivers[@]}"

# --------------------------------------------------------------
# Fonts
# --------------------------------------------------------------
_installPackages "${fonts[@]}"

log "POST INSTALL" "Installing oh-my-tmux..."
# --------------------------------------------------------------
# oh-my-tmux
# --------------------------------------------------------------
curl -fsSL "https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh#$(date +%s)" | bash

log "POST INSTALL" "Installing oh-my-zsh"
# --------------------------------------------------------------
# oh-my-zsh
# --------------------------------------------------------------
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sudo chsh -s /bin/zsh sarah

log "POST INSTALL" "Enabling ly..."
# --------------------------------------------------------------
# ly
# --------------------------------------------------------------
systemctl enable ly.service
cat >>/etc/ly/config.ini <<EOF
default_user=sarah
default_session=Hyprland
EOF

figlet "Finished!" | lolcat

figlet "Sarah O. configs" | lolcat
# --------------------------------------------------------------
# My personal configs
# --------------------------------------------------------------
cd /tmp
git clone "https://github.com/S4r4h-O/my-linux.git"
cp my-linux/zsh/.zshrc /home/sarah/.zshrc && cp my-linux/zsh/aliases.zsh /home/sarah/.oh-my-zsh/custom/aliases.zsh

cp -r my-linux/hypr ~/.config
cp -r my-linux/mako ~/.config
cp -r my-linux/waybar ~/.config
cp -r my-linux/rofi ~/.config
