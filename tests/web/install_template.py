"""Installs Godot's Web export template.

The template archive is 1.2 GB and only two 9 MB files in it are needed (the
debug build shows script errors in the browser console, the release build is
what players get), so this
first tries to read just those files with HTTP range requests (needs the
"remotezip" package). If the server refuses those, it downloads the archive.

    python3 install_template.py 4.4.1.stable ~/.local/share/godot/export_templates/4.4.1.stable
"""
import pathlib
import shutil
import sys
import tempfile
import urllib.request
import zipfile

version, dest = sys.argv[1], pathlib.Path(sys.argv[2])
tag = version.replace(".stable", "-stable")
url = f"https://github.com/godotengine/godot/releases/download/{tag}/Godot_v{tag}_export_templates.tpz"
wanted = ("web_nothreads_release.zip", "web_nothreads_debug.zip", "version.txt")  # the preset has thread support off


def extract(archive: zipfile.ZipFile) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    for name in archive.namelist():
        if name.endswith(wanted):
            (dest / pathlib.Path(name).name).write_bytes(archive.read(name))
            print("installed", name)


try:
    from remotezip import RemoteZip

    with RemoteZip(url) as remote:
        extract(remote)
except Exception as error:  # no remotezip, or the server doesn't do range requests
    print(f"Reading the archive remotely failed ({type(error).__name__}); downloading all of it.")
    with tempfile.NamedTemporaryFile(suffix=".tpz") as tmp:
        with urllib.request.urlopen(url) as response:
            shutil.copyfileobj(response, tmp, 1 << 20)
        tmp.flush()
        with zipfile.ZipFile(tmp.name) as archive:
            extract(archive)

for name in wanted:
    if not (dest / name).exists():
        sys.exit(f"{name} is not in the template archive")
