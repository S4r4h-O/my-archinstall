from pathlib import Path
from urllib import request
from arch_install import run_command

RED = "\033[31m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
RESET = "\033[0m"


def install_apps():
    with Path("./to_install.txt").open("r", encoding="utf-8") as f:
        apps = " ".join(
            line.strip()
            for line in f
            if line.strip() and not line.strip().startswith("#")
        )

    print(f"{GREEN}[INSTALL]{RESET} Installing: \n {apps}")
    run_command(command=f"sudo pacman -S {apps}", interactive=True)


def download_files(url: str, filename: Path):
    print(f"{GREEN}[DOWNLOAD]{RESET}: {url}")

    def reporthook(count, block_size, total_size):
        total_mb = total_size / (1024 * 1024)
        block_mb = block_size / (1024 * 1024)
        downloaded_mb = count * block_mb
        percent = (downloaded_mb / total_mb * 100) if total_mb > 0 else 0
        print(
            f"{GREEN}[DOWNLOAD]{RESET}: {downloaded_mb:>8.2f} / {total_mb:.2f} MB ({percent:>5.1f}%)",
            end="\r",
            flush=True,
        )

    result = request.urlretrieve(url, filename=filename, reporthook=reporthook)
    print(f"\n{filename.name} downloaded!\n")
    return result


class PostInstall:
    def greeter(self):
        # TODO: user should be dynamic
        print(f"{GREEN}[GRETTER]{RESET} Setting up the greeter manager (ly)...")
        run_command(command="sudo systemctl enable ly", interactive=True)
        print(f"{YELLOW}[INFO]{RESET} Writing default user and session...")
        run_command(
            command="""
            sudo tee /etc/ly/config.ini >> /dev/null <<EOF
            # User and sessions
            default_user=sarah
            default_session=Hyprland
            EOF
        """
        )
        print(f"{YELLOW}[INFO]{RESET} Restarting greeter (ly)...")
        run_command(command="sudo systemctl restart ly.service", interactive=True)

    def desktop_environ(self):
        print(f"{GREEN}[DE]{RESET}Setting up desktop environment...")
        run_command(
            command="echo 'exec = /usr/lib/polkit-kde-authentication-agent-1' >> ~/.config/hypr/hyprland.conf "
        )


if __name__ == "__main__":
    download_files(
        url="https://github.com/curl/curl/releases/download/curl-8_16_0/curl-8.16.0.zip",
        filename=Path("curl.zip"),
    )
