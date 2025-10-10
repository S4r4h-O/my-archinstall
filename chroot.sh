#!/bin/bash

echo "Changing to chroot."

arch-chroot /mnt /bin/bash -c "
echo 'Generating locale and configuring the system.'
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
echo 'LANG=en_US.UTF-8' >> /etc/locale.conf
locale-gen
exec /bin/bash
"
