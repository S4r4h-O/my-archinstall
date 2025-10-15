#!/bin/bash

source ./logging.sh
source ./_lib.sh

if [[ $EUID -ne 0 ]]; then
  logError "Script needs root privileges."
  exit 1
fi

if [[ $(_checkCommandExists "ufw") == 0 ]]; then
  logWarning "UFW is already installed."
else
  pacman -Sy --noconfirm ufw
fi

ufw reset

ufw default deny incoming
ufw default allow outgoing

ufw allow ssh

# ufw allow http
# ufw allow https

ufw enable

ufw status verbose

log "FIREWALL" "Firewall (ufw) setup successfully."
