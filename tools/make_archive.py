"""Архивы в dist/:

  dist/scpsite_full.zip      — всё вместе: garrysmod/gamemodes/scpsite (код) + garrysmod/addons/scpsite_content
                               (контент) — распаковать в папку garrysmod/ сервера.
  dist/scpsite_gamemode.zip  — только код режима: распаковать в garrysmod/.
  dist/scpsite_content.zip   — только контент отдельным аддоном: в garrysmod/addons/ или залить в Workshop.

python3 tools/make_archive.py
"""
import json
import os
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GM = os.path.join(ROOT, "gamemodes", "scpsite")
CONTENT = os.path.join(ROOT, "content")
DIST = os.path.join(ROOT, "dist")

ADDON = {
    "title": "SCP — Объект 19 · Контент",
    "type": "servercontent",
    "tags": ["roleplay", "scenic"],
    "ignore": ["*.psd", "*.log", "*.txt"],
}


def add_dir(z, src, prefix):
    for base, dirs, files in os.walk(src):
        dirs.sort()
        for f in sorted(files):
            if f.endswith((".pyc", ".log")):
                continue
            full = os.path.join(base, f)
            z.write(full, os.path.join(prefix, os.path.relpath(full, src)))


def write(name, fill):
    path = os.path.join(DIST, name)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        fill(z)
    print("wrote", os.path.relpath(path, ROOT), os.path.getsize(path) // 1024, "KB")


def main():
    os.makedirs(DIST, exist_ok=True)
    addon = json.dumps(ADDON, ensure_ascii=False, indent=2)
    credits = os.path.join(ROOT, "CREDITS.md")

    def gamemode(z, prefix):
        add_dir(z, GM, prefix)
        z.write(os.path.join(ROOT, "README.md"), prefix + "/README.md")

    def content(z, prefix):
        add_dir(z, CONTENT, prefix)
        z.writestr(prefix + "/addon.json", addon)
        z.write(credits, prefix + "/CREDITS.md")

    write("scpsite_gamemode.zip", lambda z: gamemode(z, "gamemodes/scpsite"))
    write("scpsite_content.zip", lambda z: content(z, "scpsite_content"))

    def full(z):
        gamemode(z, "garrysmod/gamemodes/scpsite")
        content(z, "garrysmod/addons/scpsite_content")
    write("scpsite_full.zip", full)


if __name__ == "__main__":
    main()
