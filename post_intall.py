from pathlib import Path
from urllib import request
from arch_install import run_command


def install_apps():
    with Path("./to_install.txt").open("r", encoding="utf-8") as f:
        apps = f.read().replace("\n", " ")

    run_command(command=f"sudo pacman -Sy {apps}", interactive=True)


def download_files(url, filename: Path):
    def reporthook(count, block_size, total_size):
        total_size = total_size / (1024 * 1024)
        block_size = block_size / (1024 * 1024)
        downloaded = count * block_size
        print(
            f"Downloaded: {downloaded:.2f} / {total_size:.2f} MB",
            end="\r",
            flush=True,
        )

    result = request.urlretrieve(url, filename=filename, reporthook=reporthook)
    print(f"\n{filename.name} downloaded!")
    return result


if __name__ == "__main__":
    download_files(
        url="https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-linux-x64",
        filename=Path("./tailwind"),
    )
