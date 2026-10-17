"""Статическая проверка частых ошибок режима (то, что не видно стенду загрузки).

  1. net.Start("имя") без регистрации в core/sh_net.lua — в игре «unpooled message».
  2. Вызов SCP.X.Y(...) или через локальный алиас (local L = SCP.Lobby), где Y нигде не определена.
  3. Иконки, звуки и материалы scpsite/..., которых нет в content/.
  4. Два net.Receive на одно имя в одном реалме (второй молча заменяет первый).

python3 tools/test/lint.py
"""
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GM = os.path.join(ROOT, "gamemodes", "scpsite")
CONTENT = os.path.join(ROOT, "content")

files = sorted(glob.glob(os.path.join(GM, "**", "*.lua"), recursive=True))


def strip_comments(s):
    s = re.sub(r"--\[(=*)\[.*?\]\1\]", "", s, flags=re.S)
    return re.sub(r"--[^\n]*", "", s)


code = {f: strip_comments(open(f, encoding="utf-8").read()) for f in files}
problems = []


def rel(f):
    return os.path.relpath(f, GM)


def line(s, pos):
    return s[:pos].count("\n") + 1


# 1. net
netfile = code[os.path.join(GM, "gamemode", "core", "sh_net.lua")]
registered = set(re.findall(r'"(scp\.[^"]+)"', netfile))
for f, s in code.items():
    for m in re.finditer(r'net\.(?:Start|Receive)\(\s*"([^"]+)"', s):
        if m.group(1) not in registered:
            problems.append(f"{rel(f)}:{line(s, m.start())}: net \"{m.group(1)}\" не зарегистрировано")

# 2. функции SCP.X.Y
alias = {}
for f, s in code.items():
    for m in re.finditer(r'local\s+(\w+)\s*=\s*SCP\.(\w+)\b(?!\.)', s):
        alias[(f, m.group(1))] = m.group(2)
    # local M = {} … SCP.X = M
    for m in re.finditer(r'^SCP\.(\w+)\s*=\s*(\w+)\s*$', s, flags=re.M):
        alias[(f, m.group(2))] = m.group(1)
defined = set()
for f, s in code.items():
    for m in re.finditer(r'function\s+SCP\.(\w+)[.:](\w+)\s*\(', s):
        defined.add((m.group(1), m.group(2)))
    for m in re.finditer(r'SCP\.(\w+)\.(\w+)\s*=(?!=)', s):
        defined.add((m.group(1), m.group(2)))
    for m in re.finditer(r'function\s+(\w+)[.:](\w+)\s*\(', s):
        ns = alias.get((f, m.group(1)))
        if ns:
            defined.add((ns, m.group(2)))
    for m in re.finditer(r'(?<![\w.])(\w+)\.(\w+)\s*=(?!=)', s):
        ns = alias.get((f, m.group(1)))
        if ns:
            defined.add((ns, m.group(2)))
for f, s in code.items():
    for m in re.finditer(r'SCP\.(\w+)\.(\w+)\s*\(', s):
        ns, fn = m.groups()
        if (ns, fn) not in defined and f"SCP.{ns}.{fn} then" not in s and f"SCP.{ns}.{fn} and" not in s:
            problems.append(f"{rel(f)}:{line(s, m.start())}: SCP.{ns}.{fn}() нигде не определена")
    for m in re.finditer(r'(?<![\w.:])(\w+)\.(\w+)\s*\(', s):
        ns = alias.get((f, m.group(1)))
        if not ns:
            continue
        fn = m.group(2)
        if (ns, fn) not in defined and f"{m.group(1)}.{fn} and" not in s and f"{m.group(1)}.{fn} then" not in s:
            problems.append(f"{rel(f)}:{line(s, m.start())}: {m.group(1)}.{fn}() (SCP.{ns}) нигде не определена")

# 3. контент
icons = {os.path.splitext(x)[0] for x in os.listdir(os.path.join(CONTENT, "materials", "scpsite", "icons"))}
for f, s in code.items():
    for m in re.finditer(r'(?:DrawIcon|SetIcon)\(\s*"(\w+)"', s):
        if m.group(1) not in icons:
            problems.append(f"{rel(f)}:{line(s, m.start())}: иконка \"{m.group(1)}\" — нет файла")
    for m in re.finditer(r'icon\s*=\s*"(\w+)"', s):
        if m.group(1) not in icons:
            problems.append(f"{rel(f)}:{line(s, m.start())}: иконка \"{m.group(1)}\" — нет файла")
    for m in re.finditer(r'\{\s*"([a-z_]+)",\s*[^,]*"[^"]+",\s*function\(\) send', s):
        if m.group(1) not in icons:
            problems.append(f"{rel(f)}:{line(s, m.start())}: иконка \"{m.group(1)}\" — нет файла")
    for m in re.finditer(r'"(?:sound/)?(scpsite/[\w/]+\.(?:wav|mp3))"', s):
        if not os.path.isfile(os.path.join(CONTENT, "sound", m.group(1))):
            problems.append(f"{rel(f)}:{line(s, m.start())}: звук {m.group(1)} — нет файла")
    for m in re.finditer(r'"(scpsite/[\w/]+)"\s*\.\.\s*math\.random\((\d+),\s*(\d+)\)\s*\.\.\s*"(\.\w+)"', s):
        for i in range(int(m.group(2)), int(m.group(3)) + 1):
            p = os.path.join(CONTENT, "sound", m.group(1) + str(i) + m.group(4))
            if not os.path.isfile(p):
                problems.append(f"{rel(f)}:{line(s, m.start())}: звук {os.path.relpath(p, CONTENT)} — нет файла")
    for m in re.finditer(r'Mat\(\s*"(scpsite/[\w/]+\.png)"', s):
        if not os.path.isfile(os.path.join(CONTENT, "materials", m.group(1))):
            problems.append(f"{rel(f)}:{line(s, m.start())}: материал {m.group(1)} — нет файла")

# картинки обновлений и звуки UI по именам
upd = open(os.path.join(GM, "gamemode", "modules", "menu", "sh_updates.lua"), encoding="utf-8").read()
for img in re.findall(r'image\s*=\s*"(\w+)"', upd):
    if not os.path.isfile(os.path.join(CONTENT, "materials", "scpsite", "updates", img + ".png")):
        problems.append(f"sh_updates.lua: картинка updates/{img}.png — нет файла")
for f, s in code.items():
    for m in re.finditer(r'UI\.Sound\(\s*"(\w+)"', s):
        if not os.path.isfile(os.path.join(CONTENT, "sound", "scpsite", "ui", m.group(1) + ".wav")):
            problems.append(f"{rel(f)}:{line(s, m.start())}: UI-звук {m.group(1)}.wav — нет файла")
vo = open(os.path.join(GM, "gamemode", "modules", "story", "sh_story.lua"), encoding="utf-8").read()
vo = vo[vo.index("S.VO = {"):]
for vid in re.findall(r'^\t(\w+)\s*=', vo, flags=re.M):
    if not os.path.isfile(os.path.join(CONTENT, "sound", "scpsite", "vo", vid + ".mp3")):
        problems.append(f"озвучка vo/{vid}.mp3 — нет файла (пересоберите контент)")

# 4. дубли net.Receive в одном реалме
def realm(f):
    n = os.path.basename(f)
    if n.startswith("sv_") or n == "init.lua":
        return "sv"
    if n.startswith("cl_"):
        return "cl"
    return "sh"
seen = {}
for f, s in code.items():
    for m in re.finditer(r'net\.Receive\(\s*"([^"]+)"', s):
        for r in (["sv", "cl"] if realm(f) == "sh" else [realm(f)]):
            key = (r, m.group(1))
            if key in seen and seen[key] != f:
                problems.append(f"{rel(f)}:{line(s, m.start())}: второй net.Receive(\"{m.group(1)}\") — первый в {rel(seen[key])}")
            seen[key] = f

for p in problems:
    print(p)
print("итого замечаний:", len(problems))
sys.exit(1 if problems else 0)
