"""Сборка аддона контента scpsite_content (папка content/).

Источники (скачиваются заранее, пути — аргументами):
  --scpcb  клон https://github.com/Regalis11/scpcb (нужны SFX/ и Loadingscreens/) — CC BY-SA 3.0
  --npm    распакованные npm-пакеты: @expo-google-fonts/{oswald,manrope,jetbrains-mono} (OFL), @tabler/icons (MIT)
  --voice  модель Piper ru-irinia-medium.onnx (github.com/rhasspy/piper, релиз v0.0.2)
Остальное (эмблема Фонда, градиенты, виньетка, зерно, кровь по краям, звуки терминала/гонга) рисуется и
синтезируется здесь.

python3 tools/build_content.py --scpcb <dir> --npm <dir> --voice <file.onnx> [--nyrp-ui <dir с ui-звуками>]
"""
import argparse
import glob
import io
import math
import os
import shutil
import struct
import subprocess
import sys
import wave

import cairosvg
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CONTENT = os.path.join(ROOT, "content")
sys.path.insert(0, os.path.join(ROOT, "gamemodes"))


def out(*parts):
    p = os.path.join(CONTENT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


# ------------------------------------------------------------------ шрифты --
FONTS = {
    "oswald": ["300Light/Oswald_300Light", "500Medium/Oswald_500Medium", "600SemiBold/Oswald_600SemiBold"],
    "manrope": ["400Regular/Manrope_400Regular", "500Medium/Manrope_500Medium", "600SemiBold/Manrope_600SemiBold",
                "800ExtraBold/Manrope_800ExtraBold"],
    "jetbrains-mono": ["400Regular/JetBrainsMono_400Regular", "700Bold/JetBrainsMono_700Bold"],
}


def build_fonts(npm):
    for fam, files in FONTS.items():
        pkg = glob.glob(os.path.join(npm, f"expo-google-fonts-{fam}-*", "package"))[0]
        for f in files:
            src = os.path.join(pkg, f + ".ttf")
            shutil.copy(src, out("resource", "fonts", os.path.basename(src)))
    print("шрифты: ok")


# ------------------------------------------------------------------ иконки --
ICONS = {
    "pencil": "pencil", "radio": "radio", "clipboard": "clipboard-text", "medkit": "first-aid-kit", "box": "box",
    "key": "key", "heart": "heart", "shield": "shield", "map_pin": "map-pin", "hand": "hand-stop",
    "volume": "volume-3", "warning": "alert-triangle", "user": "user", "users": "users", "user_plus": "user-plus",
    "mic": "microphone", "play": "player-play", "logout": "logout", "trash": "trash", "plus": "plus",
    "minus": "minus", "crosshair": "crosshair", "skull": "skull", "eye": "eye", "info": "info-circle",
    "check": "check", "close": "x", "arrow_right": "arrow-right", "arrow_left": "arrow-left",
    "chevron_right": "chevron-right", "chevron_left": "chevron-left", "item": "package",
    "run": "run", "lock": "lock", "bolt": "bolt", "flask": "flask", "settings": "settings",
}


def build_icons(npm):
    base = glob.glob(os.path.join(npm, "tabler-icons-*", "package", "icons", "outline"))[0]
    for name, src in ICONS.items():
        path = os.path.join(base, src + ".svg")
        if not os.path.exists(path):
            path = os.path.join(base, src.replace("-3", "") + ".svg")
        svg = open(path, encoding="utf-8").read().replace("currentColor", "#ffffff").replace('stroke-width="2"', 'stroke-width="1.8"')
        png = cairosvg.svg2png(bytestring=svg.encode(), output_width=128, output_height=128)
        open(out("materials", "scpsite", "icons", name + ".png"), "wb").write(png)
    print("иконки:", len(ICONS))


# ---------------------------------------------------------- эмблема Фонда --
def build_logo(size=1024, ss=3):
    n = size * ss
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    cx = cy = n / 2
    dx, dy = (x - cx) / n, (y - cy) / n
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dx, -dy)  # 0 — вверх, по часовой

    def tabs(width, reach):
        m = np.zeros_like(r, dtype=bool)
        for a0 in (0, 2 * math.pi / 3, -2 * math.pi / 3):
            ca, sa = math.cos(a0), math.sin(a0)
            # координаты в системе вкладки: u — вдоль луча, v — поперёк
            u = dx * sa + (-dy) * ca
            v = dx * ca - (-dy) * sa
            m |= (np.abs(v) <= width / 2) & (u >= 0) & (u <= reach)
        return m

    outer = (r <= 0.40) | tabs(0.22, 0.475)
    hole = (r <= 0.355) | tabs(0.15, 0.43)
    shape = outer & ~hole
    # внутреннее кольцо с разрывами под стрелки
    ring = (r >= 0.20) & (r <= 0.265)
    gaps = np.zeros_like(ring)
    arrows = np.zeros_like(ring)
    for a0 in (0, 2 * math.pi / 3, -2 * math.pi / 3):
        ca, sa = math.cos(a0), math.sin(a0)
        u = dx * sa + (-dy) * ca
        v = dx * ca - (-dy) * sa
        gaps |= (np.abs(v) <= 0.045) & (u > 0)
        # древко от внешнего края кольца к центру
        arrows |= (np.abs(v) <= 0.017) & (u >= 0.115) & (u <= 0.30)
        # наконечник (треугольник остриём к центру)
        tip, base_u, half = 0.045, 0.125, 0.05
        t = (u - tip) / (base_u - tip)
        arrows |= (u >= tip) & (u <= base_u) & (np.abs(v) <= half * t)
    shape |= (ring & ~gaps) | arrows
    img = Image.fromarray((shape * 255).astype(np.uint8), "L").resize((size, size), Image.LANCZOS)
    rgba = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    rgba.putalpha(img)
    rgba.resize((512, 512), Image.LANCZOS).save(out("materials", "scpsite", "logo.png"))
    rgba.save(os.path.join(ROOT, "branding", "logo_1024.png")) if os.path.isdir(os.path.join(ROOT, "branding")) else None
    print("эмблема: ok")
    return rgba


# --------------------------------------------------------- UI-текстуры --
def build_ui():
    s = 256
    y, x = np.mgrid[0:s, 0:s].astype(np.float32) / (s - 1)
    d = np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2) * 2

    def save(arr, name, size=None):
        a = np.clip(arr, 0, 1)
        im = Image.new("RGBA", (arr.shape[1], arr.shape[0]), (255, 255, 255, 0))
        im.putalpha(Image.fromarray((a * 255).astype(np.uint8), "L"))
        if size:
            im = im.resize(size, Image.LANCZOS)
        im.save(out("materials", "scpsite", "ui", name + ".png"))

    save((d <= 0.98).astype(np.float32) * 1.0, "circle")
    big = 512
    yy, xx = np.mgrid[0:big, 0:big].astype(np.float32) / (big - 1)
    dd = np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2) * 2
    save(np.clip(1 - np.abs(dd - 0.9) / 0.06, 0, 1), "ring")
    save(np.clip(1 - dd, 0, 1) ** 2.2, "glow")
    # горизонтальный и вертикальный градиенты (непрозрачно слева / снизу)
    gx = np.tile(np.linspace(1, 0, 512, dtype=np.float32) ** 1.4, (8, 1))
    save(gx, "fade_h")
    gy = np.tile(np.linspace(0, 1, 512, dtype=np.float32)[:, None] ** 1.3, (1, 8))
    save(gy, "fade_v")
    # виньетка: чёрная по краям
    vw, vh = 1024, 576
    vy, vx = np.mgrid[0:vh, 0:vw].astype(np.float32)
    nx, ny = (vx / (vw - 1) - 0.5) * 2, (vy / (vh - 1) - 0.5) * 2
    vd = np.sqrt((nx * 0.86) ** 2 + (ny * 1.0) ** 2)
    va = np.clip((vd - 0.55) / 0.75, 0, 1) ** 1.6 * 0.92
    im = Image.new("RGBA", (vw, vh), (0, 0, 0, 0))
    im.putalpha(Image.fromarray((va * 255).astype(np.uint8), "L"))
    im.save(out("materials", "scpsite", "ui", "vignette.png"))
    # кровь по краям: тёмно-красная рваная кромка
    rng = np.random.default_rng(7)
    noise = Image.fromarray((rng.random((vh // 8, vw // 8)) * 255).astype(np.uint8)).resize((vw, vh), Image.BICUBIC)
    noise = np.asarray(noise.filter(ImageFilter.GaussianBlur(6)), dtype=np.float32) / 255
    ba = np.clip((vd - 0.62 + (noise - 0.5) * 0.35) / 0.45, 0, 1) ** 1.3 * 0.95
    rgb = np.zeros((vh, vw, 4), np.uint8)
    rgb[..., 0] = (90 + noise * 50).astype(np.uint8)
    rgb[..., 1] = 4
    rgb[..., 2] = 6
    rgb[..., 3] = (ba * 255).astype(np.uint8)
    Image.fromarray(rgb, "RGBA").save(out("materials", "scpsite", "ui", "blood_edges.png"))
    # зерно
    g = (rng.random((256, 256)) * 255).astype(np.uint8)
    gi = Image.new("RGBA", (256, 256), (255, 255, 255, 0))
    gi.putalpha(Image.fromarray(g, "L"))
    gi.save(out("materials", "scpsite", "ui", "grain.png"))
    print("UI-текстуры: ok")


# ------------------------------------------------------ картинки обновлений --
def build_update_images(scpcb, logo):
    def cover(src, name, tint=True):
        im = Image.open(src).convert("RGB")
        w, h = 1024, 512
        k = max(w / im.width, h / im.height)
        im = im.resize((int(im.width * k) + 1, int(im.height * k) + 1), Image.LANCZOS)
        l, t = (im.width - w) // 2, (im.height - h) // 2
        im = im.crop((l, t, l + w, t + h))
        if tint:
            g = np.asarray(im.convert("L"), dtype=np.float32) / 255
            arr = np.stack([g * 235, g * 230, g * 222], -1).clip(0, 255).astype(np.uint8)
            im = Image.fromarray(arr, "RGB")
        im.save(out("materials", "scpsite", "updates", name + ".png"))

    cover(os.path.join(scpcb, "Loadingscreens", "096.png"), "096")
    cover(os.path.join(scpcb, "Loadingscreens", "mtf.jpg"), "mtf")
    cover(os.path.join(scpcb, "Loadingscreens", "173.jpg"), "173")
    cover(os.path.join(scpcb, "Loadingscreens", "049.jpg"), "049")
    cover(os.path.join(scpcb, "Loadingscreens", "079.jpg"), "keter")
    # эмблема на тёмном фоне со сканлайнами
    bg = Image.new("RGB", (1024, 512), (14, 15, 18))
    lg = logo.resize((380, 380), Image.LANCZOS)
    bg.paste(Image.new("RGB", lg.size, (220, 218, 212)), (322, 66), lg)
    arr = np.asarray(bg).copy()
    arr[::4] = (arr[::4] * 0.6).astype(np.uint8)
    Image.fromarray(arr).save(out("materials", "scpsite", "updates", "foundation.png"))
    print("картинки обновлений: ok")


# ------------------------------------------------------------------- звуки --
def ff(src, dst, *filters, mono=True, rate=44100, br="128k"):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    cmd = ["ffmpeg", "-v", "error", "-y", "-i", src]
    if filters:
        cmd += ["-af", ",".join(filters)]
    cmd += ["-ar", str(rate), "-ac", "1" if mono else "2"]
    if dst.endswith(".mp3"):
        cmd += ["-b:a", br]
    else:
        cmd += ["-c:a", "pcm_s16le"]
    cmd.append(dst)
    subprocess.run(cmd, check=True)


def add_loop_points(path):
    """Дописывает в wav чанк cue — Source зацикливает такой звук (CreateSound / ambient)."""
    with wave.open(path, "rb") as w:
        frames = w.getnframes()
    data = open(path, "rb").read()
    cue = b"cue " + struct.pack("<I", 28) + struct.pack("<I", 1) + struct.pack("<II4sIII", 1, 0, b"data", 0, 0, 0)
    riff_size = len(data) - 8 + len(cue)
    data = data[:4] + struct.pack("<I", riff_size) + data[8:] + cue
    open(path, "wb").write(data)


SOUNDS = {
    # путь в content/sound/scpsite : (файл SCP:CB, фильтры, моно)
    "music/menu.mp3": ("Music/Menu.ogg", ["loudnorm=I=-18"], False),
    "music/ambient.mp3": ("Music/HeavyContainment.ogg", ["loudnorm=I=-20"], False),
    "music/ending.mp3": ("Music/Ending.ogg", ["loudnorm=I=-16"], False),
    "fx/radio_squelch.mp3": ("Radio/squelch.ogg", ["volume=0.8"], True),
    "fx/radio_beep.mp3": ("Character/MTF/Beep.ogg", [], True),
    "fx/heartbeat.mp3": ("Character/D9341/Heartbeat.ogg", ["volume=2.0"], True),
    "fx/death_hit.mp3": ("General/BodyFall.ogg", [], True),
    "fx/pickup.mp3": ("Interact/PickItem2.ogg", [], True),
    "fx/paper.mp3": ("Interact/PickItem0.ogg", [], True),
    "fx/objective.mp3": ("Interact/Button2.ogg", [], True),
    "fx/terminal_done.mp3": ("Interact/KeycardUse1.ogg", [], True),
    "fx/generator_on.mp3": ("General/GeneratorOn.ogg", [], True),
    "fx/power_down.mp3": ("Room/Blackout.ogg", [], True),
    "fx/lockdown.mp3": ("Door/BigDoorClose.ogg", [], True),
    "fx/warhead_arm.mp3": ("Ending/GateB/Siren.ogg", ["volume=0.8"], True),
    "fx/detonation.mp3": ("Ending/GateB/Nuke1.ogg", ["loudnorm=I=-12"], False),
    "fx/cutscene_hit.mp3": ("Horror/Horror0.ogg", ["volume=0.9"], True),
    "fx/bandage.mp3": ("Interact/PickItem3.ogg", [], True),
    "amb/drone.mp3": ("Ambient/Room ambience/lowdrone.ogg", ["loudnorm=I=-24"], True),
    "amb/vent.mp3": ("Ambient/Room ambience/ventilation.ogg", ["loudnorm=I=-24"], True),
    "amb/servers.mp3": ("Ambient/Room ambience/servers1.ogg", ["loudnorm=I=-24"], True),
    "amb/fan.mp3": ("Ambient/Room ambience/Fan.ogg", ["loudnorm=I=-24"], True),
    "amb/drip.mp3": ("Ambient/Room ambience/drip.ogg", ["loudnorm=I=-24"], True),
}

# Реплики МОГ Эпсилон-11 (SCP:CB) для круговое меню G: имя в игре -> файлы
MTF = {
    "stop": [f"Stop{i}.ogg" for i in range(1, 7)],
    "thereheis": [f"ThereHeIs{i}.ogg" for i in range(1, 7)],
    "blinking": ["173/BLINKING.ogg"],
    "173_spotted": [f"173/Spotted{i}.ogg" for i in range(1, 4)],
    "096_spotted": [f"096/Spotted{i}.ogg" for i in range(1, 3)],
    "049_spotted": [f"049/Spotted{i}.ogg" for i in range(1, 6)],
    "searching": [f"Searching{i}.ogg" for i in range(1, 7)],
    "targetlost": [f"TargetLost{i}.ogg" for i in range(1, 4)],
    "terminated": ["Targetterminated1.ogg"] + [f"TargetTerminated{i}.ogg" for i in range(2, 5)],
    "contained": [f"173/Cont{i}.ogg" for i in range(1, 5)],
}


def build_sounds(scpcb, nyrp_ui):
    sfx = os.path.join(scpcb, "SFX")
    for dst, (src, flt, mono) in SOUNDS.items():
        ff(os.path.join(sfx, src), out("sound", "scpsite", dst), *flt, mono=mono)
    for i in range(1, 9):
        ff(os.path.join(sfx, "Horror", f"Horror{i}.ogg"), out("sound", "scpsite", "fx", f"horror{i}.mp3"), "volume=0.8")
    for i in range(5):
        ff(os.path.join(sfx, "Character", "D9341", f"breath{i}.ogg"), out("sound", "scpsite", "breath", f"breath{i}.mp3"), "loudnorm=I=-22")
    for name, files in MTF.items():
        for i, f in enumerate(files, 1):
            dst = out("sound", "scpsite", "mtf", name + (str(i) if len(files) > 1 else "") + ".mp3")
            ff(os.path.join(sfx, "Character", "MTF", f), dst, "loudnorm=I=-14")
    for z, n in ((1, 11), (2, 11), (3, 12)):
        for i in range(1, n + 1):
            ff(os.path.join(sfx, "Ambient", f"Zone{z}", f"Ambient{i}.ogg"), out("sound", "scpsite", "amb", f"zone{z}_{i}.mp3"), "loudnorm=I=-22")
    # тревога: склеиваем сирену в петлю ~11 с, wav с точкой зацикливания
    alarm = out("sound", "scpsite", "fx", "alarm_loop.wav")
    src = os.path.join(sfx, "Alarm", "Alarm2_1.ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-stream_loop", "1", "-i", src, "-ac", "1", "-ar", "44100",
                    "-af", "volume=0.9", "-c:a", "pcm_s16le", alarm], check=True)
    add_loop_points(alarm)
    if nyrp_ui and os.path.isdir(nyrp_ui):
        for f in glob.glob(os.path.join(nyrp_ui, "*.wav")):
            shutil.copy(f, out("sound", "scpsite", "ui", os.path.basename(f)))
    synth_sounds()
    print("звуки: ok")


def write_wav(path, samples, rate=44100, loop=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    s = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(s.tobytes())
    if loop:
        add_loop_points(path)


def synth_sounds():
    rate = 44100
    # гонг громкой связи: два мягких тона
    t = np.arange(int(rate * 1.6)) / rate
    def tone(f, start, dur):
        env = np.where(t >= start, np.exp(-(t - start) * 3.2), 0) * np.clip((t - start) * 60, 0, 1)
        return np.sin(2 * np.pi * f * (t - start)) * env + 0.25 * np.sin(2 * np.pi * f * 2 * (t - start)) * env
    chime = (tone(659.25, 0.0, 0.8) + tone(523.25, 0.42, 1.0)) * 0.32
    tmp = out("sound", "scpsite", "fx", "_chime.wav")
    write_wav(tmp, chime)
    ff(tmp, out("sound", "scpsite", "fx", "pa_chime.mp3"), "aecho=0.8:0.6:60:0.3")
    os.remove(tmp)
    # гул терминала при удержании E — петля 2 с
    t = np.arange(rate * 2) / rate
    hum = 0.18 * np.sin(2 * np.pi * 120 * t) + 0.08 * np.sin(2 * np.pi * 240 * t) + 0.05 * np.sin(2 * np.pi * 1760 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 4 * t))
    rng = np.random.default_rng(3)
    hum += 0.03 * rng.standard_normal(len(t))
    write_wav(out("sound", "scpsite", "fx", "terminal_loop.wav"), hum * 0.8, loop=True)
    # тиканье таймера
    t = np.arange(int(rate * 0.12)) / rate
    tick = np.sin(2 * np.pi * 2200 * t) * np.exp(-t * 60) * 0.5 + np.sin(2 * np.pi * 880 * t) * np.exp(-t * 40) * 0.3
    tmp = out("sound", "scpsite", "fx", "_tick.wav")
    write_wav(tmp, tick)
    ff(tmp, out("sound", "scpsite", "fx", "tick.mp3"))
    os.remove(tmp)
    # жужжание лампы
    t = np.arange(int(rate * 0.9)) / rate
    buzz = np.sign(np.sin(2 * np.pi * 120 * t)) * 0.12 + 0.05 * rng.standard_normal(len(t))
    buzz *= np.clip(t * 20, 0, 1) * np.clip((0.9 - t) * 8, 0, 1) * (0.6 + 0.4 * (rng.random(len(t)) > 0.02))
    tmp = out("sound", "scpsite", "amb", "_buzz.wav")
    write_wav(tmp, buzz)
    ff(tmp, out("sound", "scpsite", "amb", "buzz.mp3"), "lowpass=f=3000")
    os.remove(tmp)


# ---------------------------------------------------------- озвучка (Piper) --
# Громкая связь: женский голос, полоса 250–5000 Гц, компрессия, «зал» из двух отражений.
PA_FILTER = ["highpass=f=240", "lowpass=f=5200", "acompressor=threshold=0.08:ratio=3:attack=5:release=120:makeup=2",
             "aecho=0.85:0.5:55|140|260:0.28|0.16|0.08", "afade=t=in:d=0.04", "loudnorm=I=-16:TP=-1.5"]
# Командование по рации: тот же синтез, ниже на ~4 тона (голос «мужской»), узкая полоса, лёгкий перегруз
CMD_FILTER = ["rubberband=pitch=0.76:tempo=1.0", "highpass=f=380", "lowpass=f=3100",
              "acompressor=threshold=0.05:ratio=6:makeup=3", "acrusher=bits=10:mix=0.12", "loudnorm=I=-15:TP=-1.5"]


def synth(voice, text, raw, length=1.06):
    spoken = text.replace("…", ".").replace("—", ",").replace("«", "").replace("»", "")
    subprocess.run([sys.executable, "-m", "piper", "-m", voice, "-f", raw, "--length-scale", str(length),
                    "--noise-scale", "0.55", "--noise-w-scale", "0.75", "--sentence-silence", "0.4"],
                   input=spoken.encode(), check=True, capture_output=True)


def build_vo(voice):
    import re
    import zlib
    src = open(os.path.join(ROOT, "gamemodes", "scpsite", "gamemode", "modules", "story", "sh_story.lua"), encoding="utf-8").read()
    block = src[src.index("S.VO = {"):]
    block = block[:block.index("\n}\n")]
    lines = dict(re.findall(r'(\w+)\s*=\s*"([^"]+)"', block))
    tmpdir = out("sound", "scpsite", "vo", "_tmp")
    os.makedirs(tmpdir, exist_ok=True)
    for vid, text in lines.items():
        raw = os.path.join(tmpdir, vid + ".wav")
        synth(voice, text, raw)
        ff(raw, out("sound", "scpsite", "vo", vid + ".mp3"), *PA_FILTER, mono=True, br="96k")
    # реплики Командования (диалоги этапов и катсцен): имя файла — CRC32 текста (как util.CRC в GMod)
    cmd = set(re.findall(r'\{\s*"command",\s*"([^"]+)"\s*\}', src))
    cmd |= set(re.findall(r'\{\s*[\d.]+,\s*"Командование",\s*"([^"]+)"\s*\}', src))
    for text in sorted(cmd):
        crc = zlib.crc32(text.encode("utf-8")) & 0xFFFFFFFF
        raw = os.path.join(tmpdir, f"cmd_{crc}.wav")
        synth(voice, text, raw, length=1.0)
        ff(raw, out("sound", "scpsite", "vo", f"cmd_{crc}.mp3"), *CMD_FILTER, mono=True, br="80k")
    shutil.rmtree(tmpdir)
    print("озвучка: оповещений", len(lines), "· реплик Командования", len(cmd))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--scpcb", required=True)
    ap.add_argument("--npm", required=True)
    ap.add_argument("--voice", required=True)
    ap.add_argument("--nyrp-ui", default=None)
    a = ap.parse_args()
    if os.path.isdir(CONTENT):
        shutil.rmtree(CONTENT)
    build_fonts(a.npm)
    build_icons(a.npm)
    logo = build_logo()
    build_ui()
    build_update_images(a.scpcb, logo)
    build_sounds(a.scpcb, a.nyrp_ui)
    build_vo(a.voice)
