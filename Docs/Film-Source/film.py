"""SeatCraft product film v2 — 65 s, 1920x1080, 30 fps.

Every UI pixel comes from real SeatCraft-Demo.exe captures (film mode, 3200x1800 = 2x of a
1600x900 window). Coordinates below are in LOGICAL window pixels (1600x900); capture pixels = 2x.
The camera, cursor, highlights, captions and match cuts are drawn on top of those frames.

usage:
  python film.py <film dir> preview <out.png>          contact sheet of sample frames
  python film.py <film dir> frames <t1,t2,...> <dir>    full-size stills
  python film.py <film dir> render <out.mp4> [workers]  video (no audio)
  python film.py <film dir> sfx <out.json>              sound-effect cue list
"""
import json
import math
import os
import subprocess
import sys
from functools import lru_cache

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FILM = sys.argv[1]
FLAT = os.path.join(FILM, "flat")
FFMPEG = r"C:\Tools\ffmpeg\bin\ffmpeg.exe"
W, H, FPS = 1920, 1080, 30
DUR = 65.0
LW, LH = 1600, 900          # logical window
TOP = 88                     # logical height of the app's top bar

BG = (11, 10, 9)
INK = (243, 238, 230)
SOFT = (216, 209, 197)
MUTED = (150, 143, 132)
AMBER = (245, 181, 68)
OK = (127, 214, 164)
RED = (255, 107, 94)


# ============================================================ helpers
def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def ease(p):
    p = clamp(p)
    return 4 * p ** 3 if p < 0.5 else 1 - (-2 * p + 2) ** 3 / 2


def ease_out(p):
    p = clamp(p)
    return 1 - (1 - p) ** 3


def ramp(t, a, d):
    return ease((t - a) / d) if d > 0 else float(t >= a)


def lerp(a, b, p):
    return a + (b - a) * p


def window(t, a, b, fade=0.35):
    """1 inside [a,b], eased in/out over `fade` seconds."""
    return ramp(t, a, fade) * (1 - ramp(t, b - fade, fade))


def keyed(t, keys):
    """keys: [(time, value_tuple)], eased interpolation between consecutive keys."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            p = ease((t - t0) / (t1 - t0)) if t1 > t0 else 1
            return tuple(lerp(a, b, p) for a, b in zip(v0, v1))
    return keys[-1][1]


_fonts = {}


def font(kind, size):
    k = (kind, size)
    if k not in _fonts:
        if kind in ("display", "semi"):
            f = ImageFont.truetype(r"C:\Windows\Fonts\bahnschrift.ttf", size)
            f.set_variation_by_name("Bold Condensed" if kind == "display" else "SemiBold SemiCondensed")
        elif kind == "body":
            f = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", size)
        elif kind == "bodyb":
            f = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", size)
        else:
            f = ImageFont.truetype(r"C:\Windows\Fonts\consola.ttf", size)
        _fonts[k] = f
    return _fonts[k]


def text_w(s, kind, size, spacing=0):
    f = font(kind, size)
    return f.getlength(s) + spacing * len(s)


def draw_text(d, xy, s, kind, size, fill, spacing=0):
    f = font(kind, size)
    if not spacing:
        d.text(xy, s, font=f, fill=fill)
        return
    x, y = xy
    for c in s:
        d.text((x, y), c, font=f, fill=fill)
        x += f.getlength(c) + spacing


# ============================================================ captures
@lru_cache(maxsize=40)
def cap(name):
    return Image.open(os.path.join(FLAT, name + ".png")).convert("RGB")


@lru_cache(maxsize=8)
def topbar(name):
    return cap(name).crop((0, 0, 2 * LW, 2 * TOP))


def scrolled(full, bar, s):
    """Window frame = real top bar + page content scrolled by s logical px (as the ScrollView does)."""
    img = Image.new("RGB", (2 * LW, 2 * LH), BG)
    img.paste(topbar(bar), (0, 0))
    content = cap(full)
    s2 = int(round(2 * s))
    img.paste(content.crop((0, s2, 2 * LW, s2 + 2 * (LH - TOP))), (0, 2 * TOP))
    return img


def scroll_between(a_img, a_s, b_img, b_s, p, settle=0.18):
    """Window scrolls from a (scroll a_s) to b (scroll b_s). Rows come from whichever capture
    holds that content; the last `settle` fraction dissolves the remaining state change."""
    p = clamp(p)
    if p <= 0:
        return a_img
    if p >= 1:
        return b_img
    q = ease(clamp(p / (1 - settle)))
    sc_ = lerp(a_s, b_s, q)
    out = Image.new("RGB", (2 * LW, 2 * LH), BG)
    out.paste(a_img.crop((0, 0, 2 * LW, 2 * TOP)), (0, 0))
    body = 2 * (LH - TOP)
    for img, s0 in ((b_img, b_s), (a_img, a_s)):      # a drawn last: wins where both exist
        off = int(round(2 * (s0 - sc_)))             # window row of this capture's first content row
        top_, bot_ = max(0, off), min(body, off + body)
        if bot_ > top_:
            out.paste(img.crop((0, 2 * TOP + top_ - off, 2 * LW, 2 * TOP + bot_ - off)), (0, 2 * TOP + top_))
    if p > 1 - settle:
        out = Image.blend(out, b_img, ease((p - (1 - settle)) / settle))
    return out


def slide(a_img, b_img, p, dy):
    """Scroll-like transition between two window frames: content moves up by dy, b fades in."""
    if p <= 0:
        return a_img
    if p >= 1:
        return b_img
    off = int(2 * dy * p)
    out = Image.new("RGB", (2 * LW, 2 * LH), BG)
    body_a = a_img.crop((0, 2 * TOP + off, 2 * LW, 2 * LH))
    out.paste(body_a, (0, 2 * TOP))
    body_b = b_img.crop((0, 2 * TOP, 2 * LW, 2 * LH - (2 * dy - off)))
    mask = Image.new("L", body_b.size, int(255 * ease(p)))
    out.paste(body_b, (0, 2 * TOP + (2 * dy - off)), mask)
    out = Image.blend(out, b_img, ease(clamp((p - 0.55) / 0.45)))
    out.paste(b_img.crop((0, 0, 2 * LW, 2 * TOP)), (0, 0))
    return out


# ============================================================ camera
class Cam:
    """Logical point (cx, cy) appears at the frame centre; k = output px per logical px."""

    def __init__(self, cx, cy, k):
        self.k = k
        if k >= W / LW:  # filling the frame: keep the view inside the window
            hw, hh = W / 2 / k, H / 2 / k
            cx = clamp(cx, hw, LW - hw)
            cy = clamp(cy, hh, LH - hh)
        self.cx, self.cy = cx, cy

    def pt(self, x, y):
        return (x - self.cx) * self.k + W / 2, (y - self.cy) * self.k + H / 2

    def rect(self, r):
        x0, y0 = self.pt(r[0], r[1])
        x1, y1 = self.pt(r[2], r[3])
        return x0, y0, x1, y1


def make_bg():
    bg = Image.new("RGBA", (W, H), BG + (255,))
    glow = Image.new("RGBA", (W // 4, H // 4), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((W // 4 - 260, -180, W // 4 + 160, 200), fill=(47, 53, 144, 70))
    gd.ellipse((-140, H // 4 - 120, 200, H // 4 + 160), fill=(245, 181, 68, 26))
    glow = glow.filter(ImageFilter.GaussianBlur(60)).resize((W, H), Image.BICUBIC)
    bg.alpha_composite(glow)
    return bg.convert("RGB")


BGIMG = make_bg()


@lru_cache(maxsize=1)
def shadow_sprite():
    s = Image.new("L", (400, 240), 0)
    ImageDraw.Draw(s).rounded_rectangle((60, 60, 340, 180), radius=10, fill=170)
    return s.filter(ImageFilter.GaussianBlur(22))


def shoot(src, cam, base=None):
    """Render window image `src` (3200x1800) through camera onto the background."""
    frame = (base or BGIMG).copy()
    x0, y0, x1, y1 = cam.rect((0, 0, LW, LH))
    if x0 <= 0 and y0 <= 0 and x1 >= W and y1 >= H:
        bx0 = (0 - x0) / cam.k
        by0 = (0 - y0) / cam.k
        box = (2 * bx0, 2 * by0, 2 * (bx0 + W / cam.k), 2 * (by0 + H / cam.k))
        return src.resize((W, H), Image.BILINEAR, box=box)
    # window smaller than the frame: float it as a card with a soft shadow
    rw, rh = int(round(x1 - x0)), int(round(y1 - y0))
    sh = shadow_sprite().resize((int(rw * 400 / 280), int(rh * 240 / 120)), Image.BILINEAR)
    frame.paste((0, 0, 0), (int(x0 - rw * 60 / 280), int(y0 - rh * 60 / 120) + 18), sh)
    win = src.resize((rw, rh), Image.BILINEAR)
    m = Image.new("L", (rw, rh), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, rw - 1, rh - 1), radius=int(10 * cam.k), fill=255)
    frame.paste(win, (int(round(x0)), int(round(y0))), m)
    ImageDraw.Draw(frame).rounded_rectangle((x0, y0, x1, y1), radius=int(10 * cam.k), outline=(58, 54, 47), width=1)
    return frame


# ============================================================ overlays
class Layer:
    def __init__(self):
        self.im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
        self.used = False


def a_(c, o):
    return c + (int(255 * clamp(o)),)


def box(L, cam, r, color, o, label=None, pad=8, width=4, label_below=False):
    if o <= 0.01:
        return
    L.used = True
    x0, y0, x1, y1 = cam.rect(r)
    x0, y0, x1, y1 = x0 - pad, y0 - pad, x1 + pad, y1 + pad
    for g in (10, 6):  # soft glow
        L.d.rounded_rectangle((x0 - g, y0 - g, x1 + g, y1 + g), radius=14 + g, outline=a_(color, o * 0.10), width=6)
    L.d.rounded_rectangle((x0, y0, x1, y1), radius=12, outline=a_(color, o), width=width)
    if label:
        fs = 28
        tw = text_w(label, "bodyb", fs)
        lx = clamp(x0, 24, W - tw - 60)
        ly = y1 + 14 if label_below or y0 - 62 < 20 else y0 - 60
        L.d.rounded_rectangle((lx, ly, lx + tw + 34, ly + 46), radius=23, fill=a_(color, o))
        L.d.text((lx + 17, ly + 5), label, font=font("bodyb", fs), fill=a_((18, 15, 11), o))


def chip(L, x, y, text, color, o, dark=True, size=28):
    if o <= 0.01:
        return
    L.used = True
    tw = text_w(text, "bodyb", size)
    L.d.rounded_rectangle((x, y, x + tw + 36, y + size + 22), radius=(size + 22) // 2,
                          fill=a_((20, 18, 15), o * 0.92) if dark else a_(color, o), outline=a_(color, o), width=2)
    L.d.text((x + 18, y + 7), text, font=font("bodyb", size), fill=a_(color if dark else (18, 15, 11), o))


def ring(L, cam, x, y, t, t_click, color=AMBER, size=1.0):
    """Click / selection pulse: expanding ring."""
    p = (t - t_click) / 0.55
    if not 0 <= p <= 1:
        return
    L.used = True
    px, py = cam.pt(x, y)
    r = (14 + 46 * ease_out(p)) * size
    L.d.ellipse((px - r, py - r, px + r, py + r), outline=a_(color, 1 - p), width=4)
    if p < 0.4:
        r2 = 10 * size
        L.d.ellipse((px - r2, py - r2, px + r2, py + r2), fill=a_(color, 0.5 * (1 - p / 0.4)))


def glow_dot(L, px, py, r, color, o):
    if o <= 0.01:
        return
    L.used = True
    for i in range(6, 0, -1):
        rr = r * i / 2.2
        L.d.ellipse((px - rr, py - rr, px + rr, py + rr), fill=a_(color, o * 0.09 * (7 - i) / 6))


@lru_cache(maxsize=1)
def cursor_sprite():
    s = 3
    im = Image.new("RGBA", (36 * s, 50 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = [(3, 3), (3, 38), (12, 30), (18, 44), (24, 41), (18, 28), (30, 28)]
    d.polygon([(x * s, y * s) for x, y in pts], fill=(250, 248, 244, 255), outline=(10, 10, 10, 255), width=2 * s)
    im = im.resize((36, 50), Image.LANCZOS)
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sh.putalpha(im.getchannel("A").point(lambda v: v * 0.45))
    out = Image.new("RGBA", (44, 58), (0, 0, 0, 0))
    out.alpha_composite(sh.filter(ImageFilter.GaussianBlur(2)), (4, 5))
    out.alpha_composite(im, (0, 0))
    return out


def draw_cursor(frame_rgba, cam, x, y, o=1.0, press=0.0):
    if o <= 0.01:
        return
    px, py = cam.pt(x, y)
    spr = cursor_sprite()
    if press > 0:
        sc = 1 - 0.14 * press
        spr = spr.resize((int(44 * sc), int(58 * sc)), Image.BILINEAR)
    if o < 1:
        spr = spr.copy()
        spr.putalpha(spr.getchannel("A").point(lambda v: int(v * o)))
    frame_rgba.alpha_composite(spr, (int(px - 3), int(py - 3)))


def cursor_path(t, keys):
    """keys: [(time, x, y)] logical; eased glide between waypoints."""
    v = keyed(t, [(k[0], (k[1], k[2])) for k in keys])
    return v


def press_amount(t, clicks):
    best = 0.0
    for c in clicks:
        p = (t - c) / 0.22
        if 0 <= p <= 1:
            best = max(best, math.sin(p * math.pi))
    return best


SCRIM = None


def caption(L, t, a, b, kicker, phrase, kick_color=AMBER):
    o = window(t, a, b, 0.45)
    if o <= 0.01:
        return
    global SCRIM
    if SCRIM is None:
        SCRIM = Image.new("RGBA", (W, 300), (0, 0, 0, 0))
        col = Image.new("L", (1, 300))
        for y in range(300):
            col.putpixel((0, y), int(225 * (y / 299) ** 1.3))
        SCRIM.putalpha(col.resize((W, 300)))
        SCRIM = Image.composite(Image.new("RGBA", (W, 300), BG + (255,)), SCRIM, SCRIM)
    L.used = True
    sc = SCRIM.copy()
    sc.putalpha(sc.getchannel("A").point(lambda v: int(v * o)))
    L.im.alpha_composite(sc, (0, H - 300))
    rise = (1 - ease_out(ramp(t, a, 0.6))) * 18
    draw_text(L.d, (100, H - 196 + rise), kicker, "mono", 26, a_(kick_color, o), spacing=4)
    L.d.text((96, H - 160 + rise), phrase, font=font("display", 84), fill=a_(INK, o))


def tag(L, t, a, b, text, color=RED):
    """Small persistent top-right label (e.g. demonstration marker)."""
    o = window(t, a, b, 0.35)
    if o <= 0.01:
        return
    L.used = True
    tw = text_w(text, "mono", 24, 3)
    x = W - tw - 120
    L.d.rounded_rectangle((x, 44, x + tw + 50, 92), radius=24, fill=a_((24, 14, 12), o * 0.92), outline=a_(color, o), width=2)
    L.d.ellipse((x + 18, 62, x + 30, 74), fill=a_(color, o))
    draw_text(L.d, (x + 40, 55), text, "mono", 24, a_(color, o), spacing=3)


def compose(base_rgb, L, cursor=None):
    if not L.used and cursor is None:
        return base_rgb
    fr = base_rgb.convert("RGBA")
    if L.used:
        fr.alpha_composite(L.im)
    if cursor:
        draw_cursor(fr, *cursor)
    return fr.convert("RGB")


def dissolve(a, b, p):
    if p <= 0:
        return a
    if p >= 1:
        return b
    return Image.blend(a, b, p)


# ============================================================ geometry (logical)
ROW_C = [(331, 678), (372, 697), (415, 712), (459, 725), (504, 734), (549, 739),
         (630, 739), (676, 734), (720, 725), (764, 712), (807, 697), (849, 678)]
C5, C6 = (504, 734), (549, 739)
POSTER = (56, 919, 333, 1333)            # TechTalk poster in Discover content (content coords)
THUMB = (122, 205, 176, 283)             # event thumbnail in the seat page header
TT_CHIP = (56, 106, 292, 180)            # TechTalk chip in the seat page event strip
TT_BLOCK = (510, 612, 680, 670)          # TechTalk block on the organizer timeline


# ============================================================ scenes
def sc_hook(t):
    """0-5.2  Logo + real seat map; an amber light runs along row C, then opens into Discover."""
    frame = BGIMG.copy()
    seat = cap("f16-seats-free")
    crop = seat.crop((2 * 200, 2 * 440, 2 * 1000, 2 * 900))         # logical 800x460 of the plan
    tw_, th_ = 1000, int(1000 * 460 / 800)
    plan = crop.resize((tw_, th_), Image.BILINEAR)
    # restrained depth: plan starts slightly tilted back and settles flat
    tilt = 1 - ease_out(ramp(t, 0.0, 2.6))
    ox, oy = 840, 250 + 30 * tilt
    if tilt > 0.01:
        k = 70 * tilt
        plan = plan.transform(plan.size, Image.QUAD, (k, 0, 0, th_, tw_, th_, tw_ - k, 0), Image.BILINEAR)
    m = Image.new("L", plan.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, tw_ - 1, th_ - 1), radius=18, fill=255)
    m = m.point(lambda v: int(v * ease(ramp(t, 0.1, 0.9))))
    frame.paste(plan, (ox, int(oy)), m)
    L = Layer()
    # wordmark + hook line
    o1 = ramp(t, 0.15, 0.7)
    L.used = True
    y = 300 + (1 - o1) * 20
    L.d.text((110, y), "SEAT", font=font("display", 150), fill=a_(INK, o1))
    L.d.text((110 + font("display", 150).getlength("SEAT") + 4, y), "CRAFT", font=font("display", 150), fill=a_(AMBER, o1))
    for i, (w_, at) in enumerate((("Every event.", 0.6), ("Every seat.", 1.35), ("In sync.", 2.05))):
        o = ramp(t, at, 0.5)
        L.d.text((114, 500 + i * 74 + (1 - o) * 14), w_, font=font("display", 66), fill=a_(AMBER if i == 2 else INK, o))
    draw_text(L.d, (118, 760), "THE OFFLINE BOX OFFICE FOR CAMPUS EVENTS", "mono", 24, a_(MUTED, ramp(t, 2.6, 0.6)), spacing=3)

    def seat_xy(x, y):  # logical seat -> output, inside the plan card
        return ox + (x - 200) * tw_ / 800, oy + (y - 440) * th_ / 460

    # amber light travels along row C (1.0 -> 3.6 s), leaves a short glow on each seat it passes
    p = ramp(t, 1.0, 2.6)
    pos = p * (len(ROW_C) - 1)
    for i, (sx, sy) in enumerate(ROW_C):
        lit = clamp(1 - abs(pos - i) / 1.6) if t < 4.4 else 0
        trail = clamp(1 - (pos - i) / 4) if pos >= i and t > 1.0 else 0
        px, py = seat_xy(sx, sy)
        glow_dot(L, px, py, 26, AMBER, max(lit, trail * 0.45) * (1 - ramp(t, 3.9, 0.4)))
    i0 = int(pos)
    fx = lerp(*(seat_xy(*ROW_C[min(i0, 11)])[:1] + seat_xy(*ROW_C[min(i0 + 1, 11)])[:1]), pos - i0)
    fy = lerp(seat_xy(*ROW_C[min(i0, 11)])[1], seat_xy(*ROW_C[min(i0 + 1, 11)])[1], pos - i0)
    if 1.0 <= t < 4.2:
        glow_dot(L, fx, fy, 40, (255, 214, 140), 1.0)
    # the light settles on C5 + C6, then becomes the iris that opens Discover
    for s_ in (C5, C6):
        px, py = seat_xy(*s_)
        glow_dot(L, px, py, 30, AMBER, ramp(t, 3.5, 0.4))
    out = compose(frame, L)
    if t >= 4.1:
        cx, cy = seat_xy((C5[0] + C6[0]) / 2, C5[1])
        p = ease(ramp(t, 4.1, 1.1))
        r = 20 + p * 2300
        disc = sc_discover(5.2, base_only=True)
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
        m = m.filter(ImageFilter.GaussianBlur(6))
        out = Image.composite(disc, out, m)
        ring_l = Layer()
        ring_l.d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=a_(AMBER, 1 - p), width=6)
        ring_l.used = True
        out = compose(out, ring_l)
    return out


DISC_SCROLL = [(5.2, (0,)), (5.5, (0,)), (7.2, (520,))]


def disc_state(t):
    if t < 7.75:
        return "f01b-discover-full"
    if t < 8.65:
        return "f02a-discover-day-full"
    return "f02b-discover-filter-full"


def sc_discover(t, base_only=False):
    """5.2-11.4  Discover: glide to artwork, filter by Thu 12 + Talks, open TechTalk (match cut)."""
    s = keyed(t, DISC_SCROLL)[0]
    k = keyed(t, [(5.2, (1.2,)), (7.2, (1.2,)), (9.6, (1.26,))])[0]
    cam = Cam(LW / 2, keyed(t, [(5.2, (450,)), (7.2, (450,)), (9.6, (520,))])[0], k)
    st = disc_state(t)
    img = scrolled(st, "f01-discover", s)
    # short dissolve on each filter click so the change reads as a response
    for tc, prev in ((7.75, "f01b-discover-full"), (8.65, "f02a-discover-day-full")):
        if tc <= t < tc + 0.2:
            img = dissolve(scrolled(prev, "f01-discover", s), img, (t - tc) / 0.2)
    base = shoot(img, cam)
    if base_only:
        return base
    L = Layer()
    day12 = (396, 775 + TOP - 520)
    talks = (1440, 691 + TOP - 520)
    poster_c = ((POSTER[0] + POSTER[2]) / 2, (POSTER[1] + POSTER[3]) / 2 + TOP - 520)
    keys = [(7.0, 1700, 620), (7.6, *day12), (8.25, *day12), (8.55, *talks), (9.3, *talks), (10.1, *poster_c)]
    cx, cy = cursor_path(t, keys)
    clicks = [7.75, 8.65, 10.25]
    for c, (x, y) in zip(clicks, (day12, talks, poster_c)):
        ring(L, cam, x, y, t, c)
    box(L, cam, (360, 742 + TOP - 520, 432, 812 + TOP - 520), AMBER, window(t, 7.8, 9.9, 0.25), pad=4, width=3)
    box(L, cam, (1410, 676 + TOP - 520, 1470, 712 + TOP - 520), AMBER, window(t, 8.7, 9.9, 0.25), pad=6, width=3)
    caption(L, t, 5.7, 13.8, "DISCOVER", "Find the event. Make it yours.")
    cur = (cam, cx, cy, window(t, 6.9, 10.6, 0.3), press_amount(t, clicks)) if t < 10.6 else None
    return compose(base, L, cur)


def sc_open_event(t):
    """10.3-14  Match cut: the TechTalk poster flies into the event page's header artwork."""
    k = keyed(t, [(11.3, (1.2,)), (12.2, (1.2,)), (14.0, (1.34,))])[0]
    cy = keyed(t, [(11.3, (450,)), (12.2, (450,)), (14.0, (560,))])[0]
    cam = Cam(keyed(t, [(11.3, (800,)), (12.2, (800,)), (14.0, (620,))])[0], cy, k)
    page = shoot(cap("f03-seats-open"), cam)
    disc = sc_discover(min(t, 10.6), base_only=True)
    p = ease(ramp(t, 10.35, 1.0))
    out = dissolve(disc, page, ease(ramp(t, 10.45, 0.6)))
    if p < 1:
        dcam = Cam(LW / 2, 520, 1.26)
        a0 = dcam.rect((POSTER[0], POSTER[1] + TOP - 520, POSTER[2], POSTER[3] + TOP - 520))
        a1 = cam.rect(THUMB)
        mid = (W / 2 - 170, H / 2 - 250, W / 2 + 170, H / 2 + 260)
        if p < 0.45:
            r = tuple(lerp(a, b, ease(p / 0.45)) for a, b in zip(a0, mid))
        else:
            r = tuple(lerp(a, b, ease((p - 0.45) / 0.55)) for a, b in zip(mid, a1))
        src = cap("f02b-discover-filter-full").crop(tuple(2 * v for v in POSTER))
        rw, rh = max(2, int(r[2] - r[0])), max(2, int(r[3] - r[1]))
        spr = src.resize((rw, rh), Image.BILINEAR)
        m = Image.new("L", (rw, rh), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, rw - 1, rh - 1), radius=max(2, int(rw * 0.03)), fill=255)
        o = 1 - ramp(t, 11.25, 0.15)
        out = out.copy()
        out.paste(spr, (int(r[0]), int(r[1])), m.point(lambda v: int(v * o)))
    L = Layer()
    box(L, cam, (190, 200, 610, 290), AMBER, window(t, 11.6, 13.7, 0.3), pad=8, width=3)
    caption(L, t, 5.7, 13.8, "DISCOVER", "Find the event. Make it yours.")
    return compose(out, L)


SEAT_CAM = [(14.0, (620, 560, 1.34)), (15.0, (600, 640, 1.5)), (17.8, (600, 600, 1.5)),
            (18.3, (600, 600, 1.5)), (20.2, (527, 700, 2.4)), (21.0, (527, 700, 2.4)),
            (22.0, (1200, 640, 2.0)), (24.0, (1240, 700, 2.0)), (25.2, (1250, 700, 2.0)),
            (26.2, (1220, 560, 1.7))]


def seat_state(t):
    if t < 16.45:
        return cap("f03-seats-open")
    if t < 18.05:
        return cap("f04-seats-c5")
    return cap("f05-seats-best")


def sc_seats(t):
    """14-26.6  Venue plan, select C5, best seats together (C5+C6), view from seat, live total."""
    cx, cy, k = keyed(t, SEAT_CAM)
    cam = Cam(cx, cy, k)
    img = seat_state(t)
    for tc, prev in ((16.45, "f03-seats-open"), (18.05, "f04-seats-c5")):
        if tc <= t < tc + 0.18:
            img = dissolve(cap(prev), img, (t - tc) / 0.18)
    base = shoot(img, cam)
    L = Layer()
    # VIP / Regular labels on the plan
    box(L, cam, (232, 520, 950, 630), AMBER, window(t, 14.9, 16.3, 0.3) * 0.9, label="VIP · rows A–B · Rs 1,200", pad=6, width=3)
    box(L, cam, (220, 660, 965, 860), SOFT, window(t, 15.3, 16.3, 0.3) * 0.9, label="Regular · rows C–E · Rs 800", pad=6, width=3, label_below=False)
    clicks = [16.4, 18.0]
    keys = [(15.6, 900, 820), (16.2, *C5), (16.9, *C5), (17.7, 576, 375)]
    cxx, cyy = cursor_path(t, keys)
    ring(L, cam, *C5, t, 16.4)
    ring(L, cam, 576, 375, t, 18.0)
    for i, s_ in enumerate((C5, C6)):
        ring(L, cam, *s_, t, 18.3 + 0.12 * i, AMBER, 1.3)
        ring(L, cam, *s_, t, 19.6 + 0.12 * i, AMBER, 1.6)
    box(L, cam, (478, 706, 578, 768), AMBER, window(t, 19.0, 21.2, 0.3), label="Best seats together · C5 + C6", pad=10)
    box(L, cam, (1212, 533, 1568, 716), AMBER, window(t, 21.9, 23.6, 0.3), label="View from C5", pad=8)
    box(L, cam, (1400, 795, 1572, 865), AMBER, window(t, 23.4, 25.6, 0.3), label="Live total · Rs 1,600", pad=8)
    caption(L, t, 14.2, 26.3, "SEAT SELECTION", "The right seats. Together.")
    cur = (cam, cxx, cyy, window(t, 15.5, 18.5, 0.3), press_amount(t, clicks)) if 15.5 <= t < 18.5 else None
    return compose(base, L, cur)


def sc_checkout(t):
    """26.6-30.9  Details: slide to the name form, type a demo name, confirm."""
    a = cap("f05-seats-best")
    if t < 27.9:
        b = cap("f06-details-empty")
    elif t < 28.4:
        b = cap("f07-details-a")
    elif t < 28.9:
        b = cap("f08-details-b")
    elif t < 29.85:
        b = cap("f09-details-full")
    else:
        b = cap("f10-confirmed")
    if t < 27.3:
        img = scroll_between(a, 0, cap("f06-details-empty"), 293, (t - 26.55) / 0.7)
    elif t >= 29.85:
        img = scroll_between(cap("f09-details-full"), 293, b, 0, (t - 29.85) / 0.55)
    else:
        img = b
    cx, cy, k = keyed(t, [(26.2, (1220, 560, 1.7)), (27.3, (1200, 640, 1.75)), (29.6, (1200, 640, 1.75)),
                          (30.4, (1150, 450, 1.75)), (30.9, (1200, 420, 2.2))])
    cam = Cam(cx, cy, k)
    base = shoot(img, cam)
    L = Layer()
    clicks = [27.45, 29.8]
    keys = [(26.9, 1100, 760), (27.4, 1360, 667), (28.9, 1450, 690), (29.6, 1390, 733)]
    cxx, cyy = cursor_path(t, keys)
    ring(L, cam, 1360, 667, t, 27.45)
    ring(L, cam, 1390, 733, t, 29.8)
    # confirmation: the seats carry over (match cut) — highlight C5 · C6 in the confirmation card
    box(L, cam, (1212, 330, 1300, 362), AMBER, window(t, 30.0, 31.2, 0.2), pad=8)
    ring(L, cam, 1255, 346, t, 30.0, OK, 1.6)
    caption(L, t, 27.0, 33.5, "CHECKOUT", "Booked. Confirmed. Ready to go.")
    tag(L, t, 27.0, 36.8, "DEMO CUSTOMER", AMBER)
    cur = (cam, cxx, cyy, window(t, 26.9, 30.0, 0.25), press_amount(t, clicks)) if t < 30.0 else None
    return compose(base, L, cur)


@lru_cache(maxsize=1)
def ticket_bg():
    im = cap("f11-ticket").resize((LW, LH), Image.BILINEAR).filter(ImageFilter.GaussianBlur(6))
    return Image.blend(im, Image.new("RGB", im.size, BG), 0.45).resize((2 * LW, 2 * LH), Image.BILINEAR)


TICKET = (56, 241, 1112, 571)


def sc_ticket(t):
    """30.9-37  Ticket into focus (seats match cut), highlight details, download PDF + image."""
    view_click = 30.95
    if t < 33.25:
        # match cut: confirmation seats -> ticket seats; ticket rises into focus over a soft page
        p = ease(ramp(t, 30.95, 1.2))
        cx, cy, k = keyed(t, [(30.95, (384, 484, 2.6)), (32.15, (590, 420, 1.55)), (33.25, (590, 420, 1.55))])
        cam = Cam(cx, cy, k)
        img = cap("f11-ticket")
        bgimg = dissolve(img, ticket_bg(), window(t, 31.3, 33.0, 0.4))
        base = shoot(bgimg, cam)
        if window(t, 31.3, 33.0, 0.4) > 0.01:
            r = cam.rect(TICKET)
            spr = img.crop(tuple(2 * v for v in TICKET)).resize((int(r[2] - r[0]), int(r[3] - r[1])), Image.BILINEAR)
            base.paste(spr, (int(r[0]), int(r[1])))
        if t < 31.35:
            prev = shoot(cap("f10-confirmed"), Cam(1200, 420, 2.2 + 0.4 * ease(ramp(t, 30.9, 0.45))))
            base = dissolve(prev, base, ease(ramp(t, 30.95, 0.4)))
    else:
        img = cap("f11-ticket")
        if t >= 33.25:
            img = scroll_between(img, 0, cap("f12-ticket-saved"), 120, (t - 33.25) / 0.6)
        cx, cy, k = keyed(t, [(33.25, (590, 420, 1.55)), (34.0, (800, 470, 1.25)), (36.9, (800, 470, 1.25))])
        cam = Cam(cx, cy, k)
        base = shoot(img, cam)
    L = Layer()
    box(L, cam, (316, 312, 740, 358), AMBER, window(t, 31.6, 33.0, 0.25), label="Event", pad=8)
    box(L, cam, (316, 452, 452, 514), AMBER, window(t, 31.95, 33.0, 0.25), label="Seats", pad=8, label_below=True)
    box(L, cam, (946, 264, 1040, 302), AMBER, window(t, 32.3, 33.0, 0.25), label="Booking ref", pad=8)
    # download: cursor clicks the real button, then the saved-file notice appears
    clicks = [33.15]
    if 32.2 <= t < 33.6:
        cam_c = cam
        cxx, cyy = cursor_path(t, [(32.3, 860, 330), (33.0, 692, 169)])
        ring(L, cam_c, 692, 169, t, 33.15)
    if t >= 33.8:
        box(L, cam, (56, 740, 1112, 784), OK, window(t, 33.9, 36.8, 0.3), pad=4, width=3)
        o = window(t, 34.1, 36.8, 0.3)
        if o > 0.01:
            L.used = True
            L.d.rounded_rectangle((1372, 610, 1880, 860), radius=16, fill=a_((14, 22, 17), o * 0.95), outline=a_(OK, o), width=2)
            draw_text(L.d, (1400, 636), "TICKET SAVED · PDF + IMAGE", "mono", 22, a_(OK, o), spacing=3)
        chip(L, 1400, 690, "EVT01-BKG-0013.pdf", OK, window(t, 34.2, 36.8, 0.3))
        chip(L, 1400, 770, "EVT01-BKG-0013.png", OK, window(t, 34.45, 36.8, 0.3))

    caption(L, t, 27.0, 33.5, "CHECKOUT", "Booked. Confirmed. Ready to go.")
    tag(L, t, 27.0, 36.8, "DEMO CUSTOMER", AMBER)
    cur = (cam, cxx, cyy, window(t, 32.25, 33.6, 0.2), press_amount(t, clicks)) if 32.2 <= t < 33.6 else None
    return compose(base, L, cur)


def sc_bookings(t):
    """37-41.7  Search BKG-0013, cancel the whole booking (clearly labelled demonstration)."""
    if t < 37.75:
        img = scroll_between(cap("f12-ticket-saved"), 120, cap("f11-ticket"), 0, (t - 36.9) / 0.55)
    elif t < 38.3:
        img = cap("f13a-search")
    elif t < 39.85:
        img = cap("f13-search")
    elif t < 40.95:
        img = scroll_between(cap("f13-search"), 0, cap("f14-cancel-ask"), 213, (t - 39.85) / 0.6)
    else:
        img = scroll_between(cap("f14-cancel-ask"), 213, cap("f15-cancelled"), 0, (t - 40.95) / 0.55)
    cx, cy, k = keyed(t, [(36.9, (800, 470, 1.25)), (37.6, (1050, 380, 1.4)), (39.3, (1050, 380, 1.4)),
                          (39.9, (800, 450, 1.25)), (41.7, (760, 420, 1.3))])
    cam = Cam(cx, cy, k)
    base = shoot(img, cam)
    L = Layer()
    clicks = [37.55, 39.8, 40.9]
    keys = [(37.0, 1100, 500), (37.5, 1380, 234), (38.6, 1420, 300), (39.6, 864, 169), (40.1, 864, 300),
            (40.75, 992, 704)]
    cxx, cyy = cursor_path(t, keys)
    ring(L, cam, 1380, 234, t, 37.55)
    ring(L, cam, 864, 169, t, 39.8, RED)
    ring(L, cam, 992, 704, t, 40.9, RED)
    box(L, cam, (1162, 330, 1598, 416), AMBER, window(t, 38.4, 39.7, 0.25), label="BKG-0013 · Ayesha Khan", pad=4, label_below=True)
    box(L, cam, (56, 660, 1112, 780), RED, window(t, 40.3, 40.9, 0.15) if t < 40.95 else 0, pad=4, width=3)
    caption(L, t, 37.2, 39.75, "BOOKINGS", "Find bookings. Handle changes.")
    caption(L, t, 41.2, 43.8, "BOOKINGS", "Find bookings. Handle changes.")
    tag(L, t, 37.0, 43.9, "CANCELLATION DEMO")
    cur = (cam, cxx, cyy, window(t, 37.0, 41.2, 0.25), press_amount(t, clicks)) if t < 41.2 else None
    return compose(base, L, cur)


def sc_freed(t):
    """41.7-44.6  Seats C5 + C6 are available again; match cut to the organizer timeline."""
    cx, cy, k = keyed(t, [(41.7, (760, 420, 1.3)), (42.3, (527, 690, 2.2)), (43.5, (527, 690, 2.2))])
    cam = Cam(cx, cy, k)
    base = shoot(cap("f16-seats-free"), cam)
    if t < 42.2:
        prev = shoot(cap("f15-cancelled"), Cam(760, 420, 1.3))
        base = dissolve(prev, base, ease(ramp(t, 41.7, 0.45)))
    L = Layer()
    for i, s_ in enumerate((C5, C6)):
        ring(L, cam, *s_, t, 42.4 + 0.1 * i, OK, 1.5)
        ring(L, cam, *s_, t, 43.0 + 0.1 * i, OK, 1.5)
    box(L, cam, (478, 706, 578, 768), OK, window(t, 42.4, 43.9, 0.25), label="C5 + C6 available again", pad=10)
    caption(L, t, 41.2, 43.8, "BOOKINGS", "Find bookings. Handle changes.")
    tag(L, t, 37.0, 43.9, "CANCELLATION DEMO")
    return compose(base, L)


ORG_CAM = [(44.4, (800, 450, 1.2)), (45.3, (800, 450, 1.2)), (46.4, (700, 640, 1.75)), (48.0, (720, 640, 1.75)),
           (49.2, (1100, 520, 1.35)), (52.0, (1100, 520, 1.35)), (53.2, (800, 450, 1.2)), (57.0, (800, 450, 1.25))]
ORG_SCROLL = [(44.4, (0,)), (48.3, (0,)), (49.3, (380,)), (50.3, (380,)), (50.95, (150,)), (52.1, (150,)), (53.2, (0,))]


def sc_organizer(t):
    """44-57  Timeline clash TechTalk/Hamlet, preview the suggested fix, apply, publish, clear."""
    s = keyed(t, ORG_SCROLL)[0]
    if t < 50.05:
        full = "f17b-organizer-full"
    elif t < 51.65:
        full = "f18b-organizer-fixed-full"
    else:
        full = "f19b-organizer-published-full"
    img = scrolled(full, "f17-organizer-clash", s)
    for tc, prev in ((50.05, "f17b-organizer-full"), (51.65, "f18b-organizer-fixed-full")):
        if tc <= t < tc + 0.25:
            img = dissolve(scrolled(prev, "f17-organizer-clash", s), img, (t - tc) / 0.25)
    cam = Cam(*keyed(t, ORG_CAM))
    base = shoot(img, cam)
    # match cut in: the TechTalk event chip from the seat page lands on its timeline block
    if t < 45.2:
        p = ease(ramp(t, 44.0, 1.0))
        prev = shoot(cap("f16-seats-free"), Cam(527, 690, 2.2 - 0.9 * p))
        base = dissolve(prev, base, ease(ramp(t, 44.05, 0.55)))
        fcam = Cam(527, 690, 2.2)
        r0 = Cam(400, 300, 1.2).rect(TT_CHIP)
        r1 = cam.rect(TT_BLOCK)
        if 44.0 <= t < 45.15:
            q = ease(ramp(t, 44.0, 1.1))
            r = tuple(lerp(a, b, q) for a, b in zip(r0, r1))
            spr = cap("f16-seats-free").crop(tuple(2 * v for v in TT_CHIP)).resize(
                (max(2, int(r[2] - r[0])), max(2, int(r[3] - r[1]))), Image.BILINEAR)
            base = base.copy()
            m = Image.new("L", spr.size, int(255 * (1 - ramp(t, 44.9, 0.25))))
            base.paste(spr, (int(r[0]), int(r[1])), m)
    L = Layer()
    sy = -s  # content scroll -> window y offset for overlays drawn in content coords
    pulse = 0.5 + 0.5 * math.sin(t * 6)
    box(L, cam, (638, 604 + sy, 684, 770 + sy), RED, window(t, 45.6, 47.4, 0.3) * (0.7 + 0.3 * pulse),
        label="Clash · 30 min overlap", pad=6)
    box(L, cam, (1190, 420 + sy, 1570, 620 + sy), RED, window(t, 46.2, 47.4, 0.3) * 0.0, pad=4)
    box(L, cam, (684, 610 + sy, 858, 672 + sy), AMBER, window(t, 47.4, 49.4, 0.3), label="Suggested fix · 17:00–19:00", pad=6)
    box(L, cam, (1190, 632 + sy, 1570, 735 + sy), AMBER, window(t, 48.4, 50.0, 0.3), pad=4, width=3)
    clicks = [50.0, 51.6]
    keys = [(48.9, 1250, 560), (49.75, 1380, 993 + TOP - 380), (50.3, 1380, 993 + TOP - 380), (51.0, 1300, 560 + TOP - 150),
            (51.45, 1380, 566 + TOP - 150)]
    cxx, cyy = cursor_path(t, keys)
    ring(L, cam, 1380, 993 + TOP - 380, t, 50.0)
    ring(L, cam, 1380, 566 + TOP - 150, t, 51.6, OK)
    box(L, cam, (1190, 336 + TOP + sy, 1570, 394 + TOP + sy), OK, window(t, 50.9, 51.55, 0.2),
        label="Fix applied · Hamlet now 17:00–19:00", pad=6, label_below=True)
    box(L, cam, (1190, 230, 1560, 380), OK, window(t, 53.3, 56.8, 0.35), label="0 conflicts", pad=6, label_below=True)
    box(L, cam, (508, 604, 1000, 676), OK, window(t, 53.9, 56.8, 0.35), label="Hamlet, Reimagined · now on sale", pad=6, label_below=True)
    caption(L, t, 44.7, 56.7, "ORGANIZER", "Spot the clash. Fix the schedule.")
    cur = (cam, cxx, cyy, window(t, 48.8, 52.1, 0.25), press_amount(t, clicks)) if 48.8 <= t < 52.1 else None
    return compose(base, L, cur)


VENUES = [("f16-seats-free", "MAIN AUDITORIUM", "Fan · 60 seats"),
          ("f21-seats-eh", "ENGINEERING HALL", "Flat floor · 40 seats"),
          ("f22-seats-oa", "OPEN-AIR AMPHITHEATRE", "Tiered · 84 seats")]


@lru_cache(maxsize=3)
def venue_card(i):
    src = cap(VENUES[i][0]).crop((2 * 120, 2 * 440, 2 * 1140, 2 * 900))
    c = src.resize((540, int(540 * 460 / 1020)), Image.LANCZOS)
    m = Image.new("L", c.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, c.width - 1, c.height - 1), radius=14, fill=255)
    return c, m


def sc_close(t):
    """56.8-65  Three real venue layouts, then the logo and the closing line (held 2 s)."""
    frame = BGIMG.copy()
    if t < 57.4:
        org = sc_organizer(min(t, 56.95))
        frame = dissolve(org, frame, ease(ramp(t, 56.8, 0.6)))
    out_p = ease(ramp(t, 59.8, 0.8))
    L = Layer()
    for i in range(3):
        c, m = venue_card(i)
        p = ease_out(ramp(t, 57.0 + 0.22 * i, 0.8)) * (1 - out_p)
        if p <= 0.01:
            continue
        x = 90 + i * 590
        y = 330 + (1 - p) * 60 - out_p * 40
        frame.paste(c, (x, int(y)), m.point(lambda v, p=p: int(v * p)))
        L.used = True
        L.d.text((x, y + c.height + 18), VENUES[i][1], font=font("display", 44), fill=a_(INK, p))
        L.d.text((x + 2, y + c.height + 72), VENUES[i][2], font=font("body", 28), fill=a_(MUTED, p))
    hdr = ramp(t, 57.1, 0.5) * (1 - out_p)
    draw_text(L.d, (92, 230), "THREE VENUES · ONE BOX OFFICE · FULLY OFFLINE", "mono", 28, a_(AMBER, hdr), spacing=4)
    # logo resolve
    lo = ease(ramp(t, 60.2, 0.9))
    if lo > 0.01:
        L.used = True
        f = font("display", 190)
        wsz = f.getlength("SEAT") + f.getlength("CRAFT") + 6
        x = (W - wsz) / 2
        y = 330 + (1 - lo) * 24
        L.d.text((x, y), "SEAT", font=f, fill=a_(INK, lo))
        L.d.text((x + f.getlength("SEAT") + 6, y), "CRAFT", font=f, fill=a_(AMBER, lo))
        lw_ = 520 * ease(ramp(t, 60.6, 0.8))
        L.d.rectangle(((W - lw_) / 2, 580, (W + lw_) / 2, 584), fill=a_(AMBER, lo))
        o2 = ramp(t, 61.0, 0.7)
        line = "Great events start with a seat."
        f2 = font("display", 72)
        L.d.text(((W - f2.getlength(line)) / 2, 612 + (1 - o2) * 14), line, font=f2, fill=a_(INK, o2))
        o3 = ramp(t, 61.8, 0.6)
        sub = "C++  ·  QT QUICK  ·  WORKS OFFLINE"
        draw_text(L.d, ((W - text_w(sub, "mono", 28, 5)) / 2, 730), sub, "mono", 28, a_(MUTED, o3), spacing=5)
    return compose(frame, L)


SCENES = [(0.0, 5.2, sc_hook), (5.2, 10.35, sc_discover), (10.35, 14.0, sc_open_event), (14.0, 26.55, sc_seats),
          (26.55, 30.95, sc_checkout), (30.95, 36.9, sc_ticket), (36.9, 41.7, sc_bookings), (41.7, 44.0, sc_freed),
          (44.0, 56.8, sc_organizer), (56.8, 65.01, sc_close)]


def frame_at(t):
    for a, b, fn in SCENES:
        if a <= t < b:
            img = fn(t)
            break
    if t < 0.4:
        img = Image.blend(Image.new("RGB", (W, H), (0, 0, 0)), img, ease(t / 0.4))
    return img


# ============================================================ sound-effect cues
SFX = (
    [("whoosh", 4.2), ("tick", 7.75), ("tick", 8.65), ("click", 10.25), ("whoosh", 10.4),
     ("select", 16.4), ("click", 18.0), ("select2", 18.3), ("whoosh", 26.6), ("click", 27.45)]
    + [("key", 27.7 + 0.11 * i) for i in range(11)]
    + [("click", 29.8), ("confirm", 29.95), ("whoosh", 30.95), ("click", 33.15), ("saved", 33.6), ("click", 37.55)]
    + [("key", 37.75 + 0.07 * i) for i in range(8)]
    + [("click", 39.8), ("click", 40.9), ("cancel", 41.0), ("free", 42.4), ("whoosh", 44.0), ("alert", 45.6),
       ("click", 50.0), ("fixed", 50.1), ("click", 51.6), ("publish", 51.7), ("whoosh", 56.9), ("shimmer", 60.2)]
)


if __name__ == "__main__":
    mode = sys.argv[2]
    if mode == "sfx":
        json.dump(SFX, open(sys.argv[3], "w"))
    elif mode == "frames":
        os.makedirs(sys.argv[4], exist_ok=True)
        for tt in [float(x) for x in sys.argv[3].split(",")]:
            frame_at(tt).save(os.path.join(sys.argv[4], f"t{tt:05.2f}.png"))
    elif mode == "preview":
        times = [float(x) for x in sys.argv[4].split(",")] if len(sys.argv) > 4 else [1.5, 3.2, 4.6, 6.5, 8.0, 9.2, 10.7, 12.5, 15.5,
                                                                                       17.0, 19.5, 22.5, 24.5, 26.9, 28.6, 30.2, 31.2, 32.6,
                                                                                       34.8, 38.0, 39.0, 40.5, 41.3, 43.0, 44.5, 46.5, 48.2,
                                                                                       50.4, 51.9, 55.0, 58.5, 64.0]
        th = [frame_at(tt).resize((480, 270)) for tt in times]
        sh = Image.new("RGB", (480 * 4, 284 * math.ceil(len(th) / 4)), (40, 40, 40))
        d = ImageDraw.Draw(sh)
        for i, im in enumerate(th):
            sh.paste(im, ((i % 4) * 480, (i // 4) * 284))
            d.text(((i % 4) * 480 + 4, (i // 4) * 284 + 271), f"{times[i]:.1f}s", fill=(255, 255, 0))
        sh.save(sys.argv[3])
    elif mode == "render":
        out = sys.argv[3]
        workers = int(sys.argv[4]) if len(sys.argv) > 4 else 1
        part = int(sys.argv[5]) if len(sys.argv) > 5 else -1
        n = int(round(DUR * FPS))
        if part < 0 and workers > 1:
            procs = [subprocess.Popen([sys.executable, __file__, FILM, "render", out, str(workers), str(i)]) for i in range(workers)]
            codes = [p.wait() for p in procs]
            lst = out + ".txt"
            with open(lst, "w") as f:
                for i in range(workers):
                    f.write(f"file '{out}.part{i}.mp4'\n")
            subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", out], check=True)
            print("render done", codes)
            sys.exit(0)
        if part < 0:
            a, b, target = 0, n, out
        else:
            per = math.ceil(n / workers)
            a, b, target = part * per, min(n, (part + 1) * per), f"{out}.part{part}.mp4"
        cmd = [FFMPEG, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
               "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p", "-profile:v", "high",
               "-g", "60", target]
        p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
        for i in range(a, b):
            p.stdin.write(frame_at(i / FPS).tobytes())
            if (i - a) % 150 == 0:
                print(f"part {part} frame {i - a}/{b - a}", flush=True)
        p.stdin.close()
        p.wait()
