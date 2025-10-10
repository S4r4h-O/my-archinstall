#!/usr/bin/python

import subprocess
import pty
import os


class ArchInstall:
    def __init__(
        self,
        hostname,
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

    def run_command(
        self, command, cwd=".", background=False, interactive=False, virt_terminal=False
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

    def set_keymap(self):
        print(f"Setting keymap to {self.keymap}.")
        self.run_command(command=f"localectl set-keymap --no-convert {self.keymap}")

    def unblock_wireless_interface(self):
        print("Unblocking wireless interface.")
        # TODO add verification to choose other interfaces
        self.run_command(command="rfkill unblock phy0")

    def wifi_connect(self):
        print("Wireless stations: ")
        self.run_command(command="iwctl station list")
        station_to_scan = input(
            "Select a station to scan for wireless connections: "
        ).strip()
        print("Available wifi connections: ")
        self.run_command(f"iwctl station {station_to_scan} get-networks")
        wifi_to_connect = input("Select a wifi connection: ").strip()
        self.run_command(f"iwctl station {station_to_scan} connect {wifi_to_connect}")

        self.run_command(command="iwctl device list")

    def partitioning(self):
        print("Available disks: ")
        self.run_command("lsblk")
        disk_to_partition = input("Select a disk: ").strip()
        self.disk = disk_to_partition
        # This allocates the remaining space to root
        # TODO: user should choose the root size
        print("Partitioning the disk...")
        self.run_command(
            command=f"""
            parted --script /dev/{self.disk} \
            mklabel gpt \
            mkpart ESP fat32 1MiB 1025MiB \
            set 1 esp on \
            mkpart primary ext4 1025MiB 100%
        """
        )
        print("Formatting the partitions...")
        self.run_command(command=f"mkfs.fat -F32 /dev/{self.disk}1")
        self.run_command(command=f"mkfs.ext4 /dev/{self.disk}2")

    def mount_filesystems(self):
        print("Mounting the partitions...")
        self.run_command(command=f"mount /dev/{self.disk}2 /mnt")
        self.run_command(command="mkdir -p /mnt/boot/efi")
        self.run_command(command=f"mount /dev/{self.disk}1 /mnt/boot/efi")

    def select_mirrors(self):
        print("Installing reflector...")
        self.run_command(command="pacman -Sy --noconfirm reflector", interactive=True)
        country = input("Your country: ").strip()
        self.run_command(
            command=f"""
                reflector --country {country},Worldwide \
                --age 12 --protocol https --sort rate \
                --save /etc/pacman.d/mirrorlist
            """
        )
        print("Updating mirrors...")
        self.run_command(command="pacman -Syy --noconfirm")

    def install_essential(self):
        print("Installing essentials...")
        self.run_command(
            command="pacstrap -K /mnt base linux linux-firmware sof-firmware \
            base-devel grub efibootmgr networkmanager --noconfirm",
            interactive=True,
        )

    def fstab(self):
        print("Generating fstab")
        self.run_command(command="genfstab /mnt", interactive=True)
        self.run_command(command="genfstab -U /mnt >> /mnt/etc/fstab", interactive=True)

    def system_settings(self):
        """Here, chroot creates an isolated enviroment, so we need to run everything at once (I guess)"""
        # TODO: Find out how to run chroot properly via subprocess
        print("Chroot...")
        self.run_command(
            command="chmod +x ./chroot.sh && ./chroot.sh", interactive=True
        )

    def network_config(self):
        self.run_command(command=f"hostnamectl hostname {self.hostname}")

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
        self.network_config()


if __name__ == "__main__":
    archinstall = ArchInstall(
        keymap="br-abnt2",
        region="America",
        city="Sao_Paulo",
        hostname="sarah",
        wireless=False,
    )
    archinstall.install()
