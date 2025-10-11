#!/usr/bin/python

import subprocess
import pty
import os


def run_command(
    command, cwd=".", background=False, interactive=False, virt_terminal=False
):
    try:
        if background:
            process = subprocess.Popen(
                command,
                shell=True,
                cwd=cwd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

            return process

        if interactive:
            process = subprocess.Popen(command, shell=True, cwd=cwd)
            return process.wait() == 0

        if virt_terminal:
            master_fd, slave_fd = pty.openpty()
            process = subprocess.Popen(
                command,
                shell=True,
                cwd=cwd,
                stdin=slave_fd,
                stdout=slave_fd,
                stderr=slave_fd,
                universal_newlines=True,
            )

            os.close(slave_fd)

            try:
                while True:
                    output = os.read(master_fd, 1024)
                    if not output:
                        break
                    print(output.decode(), end="")
            except OSError:
                pass

            process.wait()
            os.close(master_fd)
            return process.returncode

        else:
            with subprocess.Popen(
                command,
                shell=True,
                cwd=cwd,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                bufsize=1,
            ) as result:
                stdout_lines, stderr_lines = result.communicate()

                if stdout_lines:
                    for line in stdout_lines.splitlines():
                        print(line.strip())

                if stderr_lines:
                    for line in stderr_lines.splitlines():
                        print(line.strip())

                if result.returncode != 0:
                    print(f"Error executing {command}")
                    print(f"stderr: {result.stderr}")
                    return False

                return True

    except Exception as e:
        print(f"Exception executing {command}: {e}")


class ArchInstall:
    def __init__(
        self,
        hostname,
        username,
        keymap,
        wireless=True,
        region=None,
        city=None,
        locale="en_US.UTF-8",
    ):
        self.keymap = keymap
        self.is_wireless = wireless
        self.disk = None
        self.region = region
        self.city = city
        self.locale = locale
        self.hostname = hostname
        self.username = username

    def set_keymap(self):
        print(f"Setting keymap to {self.keymap}.")
        run_command(command=f"localectl set-keymap --no-convert {self.keymap}")

    def unblock_wireless_interface(self):
        print("Unblocking wireless interface.")
        # TODO add verification to choose other interfaces
        run_command(command="rfkill unblock phy0")

    def wifi_connect(self):
        print("Wireless stations: ")
        run_command(command="iwctl station list")
        station_to_scan = input(
            "Select a station to scan for wireless connections: "
        ).strip()
        print("Available wifi connections: ")
        run_command(f"iwctl station {station_to_scan} get-networks")
        wifi_to_connect = input("Select a wifi connection: ").strip()
        run_command(f"iwctl station {station_to_scan} connect {wifi_to_connect}")

        run_command(command="iwctl device list")

    def check_uefi(self):
        pass

    def partitioning(self):
        # TODO: add valitdation
        print("Available disks: ")
        # print(os.listdir("/sys/block/"))
        # avail_disks = os.listdir("/sys/block/")
        run_command("lsblk")
        disk_to_partition = input("Select a disk: ").strip()
        # if not disk_to_partition in avail_disks:
        #   print("Disk not Available")
        self.disk = disk_to_partition
        # This allocates the remaining space to root
        # TODO: user should choose the root size
        print("Partitioning the disk...")
        run_command(
            command=f"""
            parted --script /dev/{self.disk} \
            mklabel gpt \
            mkpart ESP fat32 1MiB 1025MiB \
            set 1 esp on \
            mkpart primary ext4 1025MiB -2GiB \
            mkpart swap linux-swap -2GiB 100%
        """
        )
        print("Formatting the partitions...")
        run_command(command=f"mkfs.fat -F32 /dev/{self.disk}1")
        run_command(command=f"mkfs.ext4 /dev/{self.disk}2")
        run_command(command=f"mkswap /dev/{self.disk}3")
        run_command(command=f"swapon /dev/{self.disk}3")

    def mount_filesystems(self):
        print("Mounting the partitions...")
        run_command(command=f"mount /dev/{self.disk}2 /mnt")
        run_command(command="mkdir -p /mnt/boot/efi")
        run_command(command=f"mount /dev/{self.disk}1 /mnt/boot/efi")

    def select_mirrors(self):
        print("Installing reflector...")
        run_command(command="pacman -Sy --noconfirm reflector", interactive=True)
        print("Selecting mirrors through reflector...")
        run_command(
            command="reflector --latest 10 --fastest 5 --protocol http --download-timeout 10 --save /etc/pacman.d/mirrorlist",
            interactive=True,
        )
        print("Updating mirrors...")
        run_command(command="pacman -Syy --noconfirm")

    def install_essential(self):
        # TODO: verify cpu to install amd or intel libs
        print("Installing essentials...")
        run_command(
            command="pacstrap -K /mnt base linux linux-firmware sof-firmware \
            base-devel grub efibootmgr networkmanager amd-ucode git --noconfirm",
            interactive=True,
        )

    def fstab(self):
        print("Generating fstab")
        run_command(command="genfstab -U /mnt >> /mnt/etc/fstab", interactive=True)

    def system_settings(self):
        """Setup network configs, core services and e grub"""
        # TODO: Find out how to run chroot properly via subprocess
        print("Chroot...")
        root_passwd = input("Root password: ").strip()
        user_passwd = input("User password: ").strip()

        chroot_commands = f"""
            ln -sf /usr/share/zoneinfo/{self.region}/{self.city} /etc/localtime
            hwclock --systohc
            echo 'LANG={self.locale}' > /etc/locale.conf
            sed -i 's/#{self.locale}/{self.locale}/' /etc/locale.gen
            locale-gen
            echo 'KEYMAP={self.keymap}' > /etc/vconsole.conf
            hostnamectl hostname {self.hostname}
            echo 'root:{root_passwd}' | chpasswd
            useradd -m -G wheel -s /bin/bash {self.username}
            echo '{self.username}:{user_passwd}' | chpasswd
            echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
            chmod 440 /etc/sudoers.d/wheel
            systemctl enable NetworkManager
            grub-install --target=x86_64-efi --efi-directory=/boot/efi/ --bootloader-id=GRUB --recheck
            grub-mkconfig -o /boot/grub/grub.cfg
            """

        run_command(command=f'arch-chroot /mnt /bin/bash -c "{chroot_commands}"')

    def install(self):
        self.set_keymap()
        if self.is_wireless:
            self.unblock_wireless_interface()
            self.wifi_connect()
        self.partitioning()
        self.mount_filesystems()
        self.select_mirrors()
        self.install_essential()
        self.fstab()
        self.system_settings()


if __name__ == "__main__":
    archinstall = ArchInstall(
        keymap="br-abnt2",
        region="America",
        city="Sao_Paulo",
        hostname="arch",
        username="sarah",
        wireless=False,
    )
    archinstall.install()
