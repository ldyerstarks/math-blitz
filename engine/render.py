#!/usr/bin/env python3
"""Math Blitz video maker.

Usage: python3 render.py lessons/day001.json out/day001.mp4

Turns a lesson file into a ~45-75 second vertical (1080x1920) video:
narrated by a fun announcer voice (Kokoro TTS, runs offline), with math that
builds on screen line by line, burnt-in captions, and a challenge question at
the end (answer is NOT shown in the video; the watch page asks for it).
"""
import json, math, os, random, subprocess, sys, tempfile, shutil
import numpy as np
import soundfile as sf
from PIL import Image, ImageDraw, ImageFont

W, H, FPS = 1080, 1920, 30
HERE = os.path.dirname(os.path.abspath(__file__))
FONT_DIR = "/usr/share/fonts/opentype/inter"

def font(size, weight="Bold"):
    for name in (f"InterDisplay-{weight}.otf", f"Inter-{weight}.otf", "InterDisplay-Bold.otf"):
        p = os.path.join(FONT_DIR, name)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)

# ---------- palette ----------
BG_TOP = (14, 18, 48)
BG_BOT = (40, 14, 70)
WHITE = (255, 255, 255)
SOFT = (190, 198, 235)
COLORS = {
    "yellow": (255, 214, 64), "pink": (255, 92, 168), "cyan": (64, 220, 255),
    "green": (92, 235, 140), "orange": (255, 150, 60), "white": WHITE,
}
ACCENT = COLORS["yellow"]

def make_bg(boss=False):
    y = np.linspace(0, 1, H)[:, None]
    top, bot = (np.array((48, 8, 18)), np.array((92, 14, 34))) if boss else (np.array(BG_TOP), np.array(BG_BOT))
    grad = (top * (1 - y) + bot * y)[:, None, :].repeat(W, axis=1).reshape(H, W, 3)
    return Image.fromarray(grad.astype(np.uint8), "RGB").convert("RGBA")

BG = None
SYMBOLS = list("+−×÷=√π∑%") + ["x", "y", "²", "∞", "θ"]

class Floaters:
    def __init__(self, seed):
        rnd = random.Random(seed)
        self.items = []
        for _ in range(18):
            self.items.append(dict(
                ch=rnd.choice(SYMBOLS), x=rnd.uniform(0, W), y=rnd.uniform(0, H),
                vy=rnd.uniform(-22, -8), size=rnd.randint(60, 150),
                phase=rnd.uniform(0, 6.28)))
        self.cache = {}
    def draw(self, img, t):
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        for it in self.items:
            y = (it["y"] + it["vy"] * t) % (H + 200) - 100
            x = it["x"] + 25 * math.sin(t * 0.6 + it["phase"])
            d.text((x, y), it["ch"], font=font(it["size"]), fill=(255, 255, 255, 22))
        img.alpha_composite(layer)

def text_img(txt, size, color, weight="Bold", max_w=W - 140):
    """Render text (auto-shrinks to fit width) to a tight RGBA image."""
    f = font(size, weight)
    while f.getlength(txt) > max_w and size > 30:
        size -= 4
        f = font(size, weight)
    bbox = f.getbbox(txt)
    w, h = bbox[2] - bbox[0] + 20, bbox[3] - bbox[1] + 30
    im = Image.new("RGBA", (int(w), int(h)), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((10 - bbox[0], 10 - bbox[1]), txt, font=f, fill=color + (255,))
    return im

def wrap(txt, f, max_w):
    words, lines, cur = txt.split(), [], ""
    for w_ in words:
        test = (cur + " " + w_).strip()
        if f.getlength(test) <= max_w:
            cur = test
        else:
            if cur: lines.append(cur)
            cur = w_
    if cur: lines.append(cur)
    return lines

def paste_alpha(base, im, x, y, a):
    if a <= 0: return
    if a < 1:
        im = im.copy()
        im.putalpha(im.getchannel("A").point(lambda v: int(v * a)))
    base.alpha_composite(im, (int(x), int(y)))

def ease(p):
    p = max(0.0, min(1.0, p))
    return 1 - (1 - p) ** 3

def rounded(d, box, r, fill, outline=None, width=0):
    d.rounded_rectangle(box, r, fill=fill, outline=outline, width=width)

# ---------- caption chunks ----------
def caption_chunks(say, dur):
    words = say.split()
    chunks, cur = [], []
    for w_ in words:
        cur.append(w_)
        if len(" ".join(cur)) > 26 or w_[-1] in ".!?,":
            chunks.append(" ".join(cur)); cur = []
    if cur: chunks.append(" ".join(cur))
    total = sum(len(c) + 4 for c in chunks)
    out, t = [], 0.15
    span = dur - 0.5
    for c in chunks:
        d = span * (len(c) + 4) / total
        out.append((t, t + d, c)); t += d
    return out

# ---------- scene drawing ----------
def draw_frame(scene, t, dur, ctx):
    img = BG.copy()
    ctx["floaters"].draw(img, ctx["t0"] + t)
    d = ImageDraw.Draw(img)

    # header bar
    d.text((70, 90), "BOSS BATTLE" if ctx.get("boss") else "MATH BLITZ", font=font(54, "Black"), fill=(255, 90, 90) if ctx.get("boss") else ACCENT)
    day_txt = f"DAY {ctx['day']}"
    fd = font(44, "Bold")
    d.text((W - 70 - fd.getlength(day_txt), 96), day_txt, font=fd, fill=SOFT)
    # progress bar
    prog = (ctx["t0"] + t) / ctx["total"]
    rounded(d, (70, 175, W - 70, 189), 7, (255, 255, 255, 40))
    rounded(d, (70, 175, 70 + max(14, (W - 140) * prog), 189), 7, ACCENT)

    kind = scene["kind"]
    if kind == "title":
        p = ease(t / 0.6)
        big = ctx["cache"].setdefault(("big", scene["big"]), text_img(scene["big"], 150, ACCENT, "Black"))
        s = 0.6 + 0.4 * p
        bw, bh = int(big.width * s), int(big.height * s)
        bi = big.resize((max(1, bw), max(1, bh)))
        paste_alpha(img, bi, (W - bw) / 2, 760 - bh / 2, p)
        sub = ctx["cache"].setdefault(("sub", scene.get("sub", "")), text_img(scene.get("sub", ""), 58, WHITE, "SemiBold"))
        q = ease((t - 0.5) / 0.5)
        paste_alpha(img, sub, (W - sub.width) / 2, 900 + 40 * (1 - q), q)
        if scene.get("tag"):
            tg = ctx["cache"].setdefault(("tag", scene["tag"]), text_img(scene["tag"], 46, COLORS["cyan"], "Bold"))
            q2 = ease((t - 1.0) / 0.5)
            paste_alpha(img, tg, (W - tg.width) / 2, 1010 + 40 * (1 - q2), q2)

    elif kind == "board":
        y = 300
        if scene.get("heading"):
            hd = ctx["cache"].setdefault(("hd", scene["heading"]), text_img(scene["heading"], 64, COLORS["cyan"], "Black"))
            paste_alpha(img, hd, 80, y, ease(t / 0.4))
            y += hd.height + 40
        lines = scene.get("lines", [])
        n = len(lines)
        # reveal times: spread across ~80% of narration
        for i, ln in enumerate(lines):
            txt, col, size = (ln, "white", 96) if isinstance(ln, str) else (ln["t"], ln.get("c", "white"), ln.get("s", 96))
            at = ln.get("at") if isinstance(ln, dict) and "at" in ln else (0.3 + i * (dur * 0.78) / max(1, n))
            im = ctx["cache"].setdefault(("ln", txt, col, size), text_img(txt, size, COLORS.get(col, WHITE), "Bold"))
            p = ease((t - at) / 0.35)
            if p > 0:
                paste_alpha(img, im, (W - im.width) / 2, y + 50 * (1 - p), p)
            y += im.height + 36
        if scene.get("note"):
            at = scene.get("note_at", dur * 0.55)
            p = ease((t - at) / 0.4)
            if p > 0:
                fn = font(50, "SemiBold")
                wl = wrap(scene["note"], fn, W - 260)
                bh = 40 + 66 * len(wl)
                top = max(y + 30, 1150)
                layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                ld = ImageDraw.Draw(layer)
                rounded(ld, (90, top, W - 90, top + bh), 30, (255, 214, 64, int(235 * p)))
                for j, l in enumerate(wl):
                    ld.text((130, top + 22 + 66 * j), l, font=fn, fill=(20, 20, 40, int(255 * p)))
                img.alpha_composite(layer)

    elif kind == "question":
        hd = ctx["cache"].setdefault(("qhd",), text_img("BEAT THE BOSS!" if ctx.get("boss") else "YOUR TURN!", 120, COLORS["pink"], "Black"))
        pulse = 1 + 0.04 * math.sin(t * 6)
        hw, hh = int(hd.width * pulse), int(hd.height * pulse)
        paste_alpha(img, hd.resize((hw, hh)), (W - hw) / 2, 290, ease(t / 0.4))
        xp_txt = f"+{ctx['xp']} XP" + ("  ·  2X BOSS BONUS" if ctx.get("boss") else "")
        xc = ctx["cache"].setdefault(("xp", xp_txt), text_img(xp_txt, 44, ACCENT, "Black"))
        paste_alpha(img, xc, (W - xc.width) / 2, 420, ease((t - 0.2) / 0.4))
        pr = ctx["cache"].setdefault(("qpr", scene["prompt"]), text_img(scene["prompt"], 92, WHITE, "Bold"))
        paste_alpha(img, pr, (W - pr.width) / 2, 490, ease((t - 0.3) / 0.4))
        fa = font(56, "SemiBold")
        ask_lines = wrap(scene["ask"], fa, W - 180)
        p = ease((t - 0.6) / 0.4)
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        for j, l in enumerate(ask_lines):
            ld.text(((W - fa.getlength(l)) / 2, 640 + 72 * j), l, font=fa, fill=SOFT + (int(255 * p),))
        top = 660 + 72 * len(ask_lines) + 40
        letters = "ABCD"
        fc = font(76, "Bold")
        for i, ch in enumerate(scene["choices"]):
            pc = ease((t - 1.0 - 0.25 * i) / 0.35)
            if pc <= 0: continue
            col = [COLORS["cyan"], COLORS["green"], COLORS["orange"], COLORS["pink"]][i]
            yy = top + i * 165 + 30 * (1 - pc)
            rounded(ld, (120, yy, W - 120, yy + 135), 34, col + (int(60 * pc),), outline=col + (int(255 * pc),), width=5)
            ld.text((165, yy + 26), letters[i], font=fc, fill=col + (int(255 * pc),))
            ld.text((280, yy + 26), ch, font=fc, fill=WHITE + (int(255 * pc),))
        img.alpha_composite(layer)
        # countdown ring in the final hold
        hold = ctx.get("hold", 0)
        if t > dur - hold:
            left = dur - t
            n = int(math.ceil(left))
            cx, cy, r = W / 2, top + 4 * 165 + 140, 80
            d2 = ImageDraw.Draw(img)
            d2.ellipse((cx - r, cy - r, cx + r, cy + r), outline=ACCENT, width=10)
            fn = font(90, "Black")
            s = str(max(n, 1))
            d2.text((cx - fn.getlength(s) / 2, cy - 58), s, font=fn, fill=ACCENT)

    # captions
    for (a, b, c) in ctx["caps"]:
        if a <= t < b:
            fc = font(52, "SemiBold")
            wl = wrap(c, fc, W - 220)
            bh = 30 + 64 * len(wl)
            top = H - 200 - bh
            layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            ld = ImageDraw.Draw(layer)
            rounded(ld, (80, top, W - 80, top + bh), 26, (0, 0, 0, 150))
            for j, l in enumerate(wl):
                ld.text(((W - fc.getlength(l)) / 2, top + 14 + 64 * j), l, font=fc, fill=WHITE + (255,))
            img.alpha_composite(layer)
            break
    return img.convert("RGB")

# ---------- main ----------
def main(lesson_path, out_path):
    global BG
    lesson = json.load(open(lesson_path))
    boss = bool(lesson.get("boss"))
    BG = make_bg(boss)
    from kokoro_onnx import Kokoro
    k = Kokoro(os.path.join(HERE, "kokoro.onnx"), os.path.join(HERE, "voices.bin"))
    voice, speed = lesson.get("voice", "am_puck"), lesson.get("speed", 1.08)

    tmp = tempfile.mkdtemp(prefix="blitz_")
    audio, sr, durs = [], 24000, []
    for i, sc in enumerate(lesson["scenes"]):
        samples, sr = k.create(sc["say"], voice=voice, speed=speed, lang="en-us")
        pad_after = 0.45
        hold = sc.get("hold", 0.0)
        dur = len(samples) / sr + pad_after + hold
        nfr = int(round(dur * FPS)); dur = nfr / FPS
        seg = np.zeros(nfr * sr // FPS, dtype=np.float32)
        seg[:len(samples)] = samples[: len(seg)]
        audio.append(seg); durs.append(dur)
    total = sum(durs)
    full = np.concatenate(audio)
    # gentle loudness normalization
    peak = float(np.max(np.abs(full))) or 1.0
    full = full * (0.89 / peak)
    sf.write(os.path.join(tmp, "voice.wav"), full, sr)

    floaters = Floaters(lesson.get("day", 1))
    cache, t0, parts = {}, 0.0, []
    for i, sc in enumerate(lesson["scenes"]):
        dur = durs[i]
        speech = dur - 0.45 - sc.get("hold", 0.0)
        ctx = dict(day=lesson.get("day", 1), boss=boss, xp=50 if boss else 25, t0=t0, total=total, floaters=floaters,
                   cache=cache, caps=caption_chunks(sc["say"], speech + 0.45), hold=sc.get("hold", 0.0))
        part = os.path.join(tmp, f"s{i:02d}.tmp.mp4")
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
               "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "veryfast",
               "-crf", "21", "-pix_fmt", "yuv420p", part]
        pr = subprocess.Popen(cmd, stdin=subprocess.PIPE)
        nfr = int(round(dur * FPS))
        for f in range(nfr):
            pr.stdin.write(draw_frame(sc, f / FPS, dur, ctx).tobytes())
        pr.stdin.close()
        if pr.wait() != 0:
            raise SystemExit(f"encode failed on scene {i}")
        final = part.replace(".tmp.mp4", ".mp4"); os.rename(part, final)
        parts.append(final); t0 += dur

    lst = os.path.join(tmp, "list.txt")
    with open(lst, "w") as fh:
        for p in parts: fh.write(f"file '{p}'\n")
    silent = os.path.join(tmp, "silent.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", silent], check=True)
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    tmp_out = out_path + ".part.mp4"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", silent, "-i", os.path.join(tmp, "voice.wav"),
                    "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "128k",
                    "-movflags", "+faststart", "-shortest", tmp_out], check=True)
    os.replace(tmp_out, out_path)
    shutil.rmtree(tmp, ignore_errors=True)
    print(f"done: {out_path} ({total:.1f}s)")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
