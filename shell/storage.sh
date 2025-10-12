select_disk() {
  local -n disk_ref="$1"

  printf "${GREEN}[DISK]${RESET}: Available disks: \n"
  lsblk -dn -o NAME,SIZE,TYPE | grep -E 'disk|nvme'

  printf "${GREEN}[DISK]${RESET}: Select a disk: \n"
  read -r disk_ref

  if [[ -z "$disk_ref" ]]; then
    printf "${GREEN}[DISK]${RESET}: Disk cannot be empty.\n"
    return 1
  fi

  if ! lsblk -dn -o NAME | grep -Fxq "$disk_ref"; then
    printf "${GREEN}[DISK]${RESET}: Disk not found.\n"
    return 1
  fi

  return 0
}

get_partition_suffix() {
  local disk="$1"

  if [[ "$disk" =~ ^(nvme|loop|mmcblk) ]]; then
    echo "p"
  else
    echo ""
  fi
}

partition_disk() {
  local disk="$1"

  printf "${BLUE}[DISK]${RESET}: Partitioning ${disk}.\n"

  local disk_size
  disk_size=$(parted "/dev/${disk}" unit MiB print | grep "^Disk" | awk '{print $3}' | sed 's/MiB//')
  local swap_start=$((disk_size - 2048))

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

format_partition() {
  local disk="$1"
  local suffix
  suffix=$(get_partition_suffix "$disk")

  printf "${GREEN}[DISK]${RESET}: Formatting partition...\n"

  mkfs.fat -F32 "/dev/${disk}${suffix}1" || {
    printf "${RED}[DISK]${RESET}: Failed to format EFI partition.\n"
    return 1
  }

  mkfs.ext4 "/dev/${disk}${suffix}2" || {
    printf "${RED}[DISK]${RESET}: Failed to format root partition.\n"
    return 1
  }

  mkswap "/dev/$disk${suffix}3" || {
    printf "${RED}[DISK]${RESET}: Failed to format swap partition.\n"
    return 1
  }

  swapon "/dev/${disk}${suffix}3" || {
    printf "${RED}[DISK]${RESET}: Failed to activate swap partition.\n"
    return 1
  }

  printf "${GREEN}[DISK]${RESET}: Formatted successfully!\n"
  return 0
}

mount_partitions() {
  local disk="$1"
  local mount_point="$2"
  local suffix
  suffix=$(get_partition_suffix "$disk")

  printf "${BLUE}[DISK]${RESET}: Mounting partitions...\n"

  mount "/dev/${disk}${suffix}2" "$mount_point" || {
    printf "${RED}[DISK]${RESET}: Failed to mount root partition.\n"
    return 1
  }

  mkdir -p "${mount_point}/boot/efi/" || {
    printf "${RED}[DISK]${RESET}: Failed to create EFI directory.\n"
    return 1
  }

  mount "/dev/${disk}${suffix}1" "${mount_point}/boot/efi/" || {
    printf "${RED}[DISK]${RESET}: Failed to mount EFI partition.\n"
    umount "$mount_point"
    return 1
  }

  printf "${GREEN}[DISK]${RESET}: Mounted successfully!\n"
  return 0

}

partitioning_and_mounting() {
  local disk=""
  local mount_point="/mnt/"

  while true; do
    # This works like a pointer to the local variable
    # local -n creates a nameref ^
    # It's like echo "$disk_ref" -> disk=$(select_disk)
    if ! select_disk disk; then
      continue
    fi

    if ! partition_disk "$disk"; then
      continue
    fi

    if ! format_partition "$disk"; then
      continue
    fi

    if mount_partitions "$disk" "$mount_point"; then
      break
    fi

  done
}
