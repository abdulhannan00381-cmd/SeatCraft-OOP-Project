"""Mix narration + score + interface sounds into one 48 kHz stereo track and write the SRT.

usage: python mix.py <film dir>
reads  audio/vo_XX.wav, audio/lines.json, audio/music.wav, sfx.json
writes audio/mix.wav, SeatCraft-Product-Showcase-v2.srt (in film dir)
"""
import json
import os
import sys

import numpy as np
import soundfile as sf
from scipy.signal import lfilter, resample_poly

from script import LINES

FILM = sys.argv[1]
A = os.path.join(FILM, "audio")
SR = 48000
DUR = 65.0
N = int(SR * DUR)
rng = np.random.default_rng(3)

# ---------------------------------------------------------------- narration
vo = np.zeros(N)
meta = json.load(open(os.path.join(A, "lines.json")))
for m in meta:
    x, sr = sf.read(os.path.join(A, f"vo_{m['i']:02d}.wav"))
    if x.ndim > 1:
        x = x.mean(axis=1)
    if sr != SR:
        x = resample_poly(x, SR, sr)
    # 8 ms fades so no line starts or ends with a click
    f = int(0.008 * SR)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    s0 = int(m["at"] * SR)
    vo[s0:s0 + len(x)] += x[: N - s0]
vo /= np.max(np.abs(vo)) + 1e-9
vo *= 0.89
# gentle presence: tiny high-shelf-ish lift by mixing a high-passed copy
hp = vo - lfilter([1 - np.exp(-2 * np.pi * 3000 / SR)], [1, -np.exp(-2 * np.pi * 3000 / SR)], vo)
vo = vo + 0.18 * hp

# ---------------------------------------------------------------- score, ducked under the voice
mus, msr = sf.read(os.path.join(A, "music.wav"))
mus = mus[:N]
if len(mus) < N:
    mus = np.pad(mus, ((0, N - len(mus)), (0, 0)))
env = np.abs(vo)
a = np.exp(-1 / (0.25 * SR))
env = lfilter([1 - a], [1, -a], env)                       # ~250 ms follower
env = np.clip(env / (np.percentile(env[env > 1e-4], 60) + 1e-9), 0, 1)
duck = 1 - 0.62 * env
mus = mus * 0.42 * duck[:, None]


# ---------------------------------------------------------------- interface sounds
def tone(freqs, dur, decay, gain, attack=0.003):
    t = np.arange(int(dur * SR)) / SR
    w = sum(np.sin(2 * np.pi * f * t) * (0.6 ** i) for i, f in enumerate(freqs))
    e = np.minimum(t / attack, 1) * np.exp(-t * decay)
    return w * e * gain


def noise_swell(dur, lo, hi, gain):
    n = int(dur * SR)
    x = rng.standard_normal(n)
    al = np.exp(-2 * np.pi * hi / SR)
    x = lfilter([1 - al], [1, -al], x)
    al = np.exp(-2 * np.pi * lo / SR)
    x = x - lfilter([1 - al], [1, -al], x)
    t = np.linspace(0, 1, n)
    e = np.sin(np.pi * t) ** 2
    return x * e * gain / (np.max(np.abs(x)) + 1e-9)


def chord(notes, gap, dur, decay, gain):
    out = np.zeros(int((gap * len(notes) + dur) * SR))
    for i, f in enumerate(notes):
        tt = tone([f, 2 * f], dur, decay, gain)
        s0 = int(i * gap * SR)
        out[s0:s0 + len(tt)] += tt
    return out


SOUNDS = {
    "click": tone([2600, 5200], 0.05, 90, 0.16),
    "tick": tone([1900, 3800], 0.05, 110, 0.12),
    "key": tone([3400], 0.025, 180, 0.05),
    "select": tone([880, 1320], 0.25, 18, 0.13),
    "select2": chord([880, 1175], 0.07, 0.3, 14, 0.12),
    "confirm": chord([659, 830, 988, 1319], 0.075, 0.6, 6, 0.11),
    "saved": chord([1047, 1568], 0.08, 0.4, 9, 0.10),
    "cancel": chord([587, 440], 0.09, 0.35, 10, 0.10),
    "free": chord([784, 988], 0.08, 0.35, 10, 0.08),
    "alert": chord([466, 466], 0.16, 0.25, 14, 0.09),
    "fixed": chord([698, 880, 1047], 0.07, 0.5, 7, 0.10),
    "publish": chord([784, 988, 1175, 1568], 0.07, 0.7, 5, 0.10),
    "whoosh": noise_swell(0.55, 300, 4200, 0.10),
    "shimmer": chord([1319, 1568, 1976, 2637], 0.09, 1.2, 3, 0.06),
}
fx = np.zeros(N)
for name, at in json.load(open(os.path.join(FILM, "sfx.json"))):
    x = SOUNDS[name]
    s0 = int(at * SR)
    fx[s0:s0 + len(x)] += x[: max(0, N - s0)]

# ---------------------------------------------------------------- sum
L = mus[:, 0] + vo * 0.98 + fx * 0.95
R = mus[:, 1] + vo * 0.98 + fx * 0.85
mix = np.stack([L, R], axis=1)
fade_in = np.minimum(np.arange(N) / (0.3 * SR), 1)
tail = np.clip((DUR - np.arange(N) / SR) / 1.6, 0, 1)
mix *= (fade_in * tail)[:, None]
peak = np.max(np.abs(mix))
mix *= 0.89 / peak
sf.write(os.path.join(A, "mix.wav"), mix.astype(np.float32), SR, subtype="FLOAT")


# ---------------------------------------------------------------- captions (SRT) from the real line timings
def ts(x):
    ms = int(round(x * 1000))
    return f"{ms // 3600000:02d}:{ms // 60000 % 60:02d}:{ms // 1000 % 60:02d},{ms % 1000:03d}"


with open(os.path.join(FILM, "SeatCraft-Product-Showcase-v2.srt"), "w", encoding="utf-8") as f:
    for i, m in enumerate(meta):
        start = max(0.0, m["at"] - 0.05)
        end = m["at"] + m["dur"] + 0.35
        if i + 1 < len(meta):
            end = min(end, meta[i + 1]["at"] - 0.06)
        f.write(f"{i + 1}\n{ts(start)} --> {ts(end)}\n{LINES[i]['text']}\n\n")
print("mix + srt written; voice lines:", len(meta))
