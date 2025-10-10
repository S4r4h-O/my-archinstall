from pathlib import Path
from urllib import request

with Path("./to_install.txt").open("r", encoding="utf-8") as f:
    apps = f.read().replace("\n", " ")


def download_files(url, filename, binary=False):
    local_filename, headers = request.urlretrieve(url)

    if binary:
        pass

    else:
        with open(local_filename, "r") as f:
            content = f.read()

        with Path(filename).open(mode="w", encoding="utf-8") as file:
            file.write(content)
