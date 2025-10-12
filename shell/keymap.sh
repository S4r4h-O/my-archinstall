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
      printf "${RED}[KEYBOARD]${RESET}: Invalid keymap: ${keymap}.\n"
      continue
    fi

    if localectl set-keymap --no-convert "$keymap"; then
      printf "${GREEN}[KEYBOARD]${RESET}: Keymap set to ${keymap}.\n"
      break
    else
      printf "${RED}[KEYBOARD]${RESET}: Error setting keymap to ${keymap}\n"
    fi

  done
}
