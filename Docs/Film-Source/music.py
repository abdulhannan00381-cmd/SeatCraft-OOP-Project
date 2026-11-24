"""Original understated electronic score for the SeatCraft film (synthesised here, so it is
royalty-free and owned by the project). 96 BPM, A minor, 66 s, 48 kHz stereo.

Arc: 0-5 pad swell + pulse (hook) · 5-44 light groove · 44-57 lift (organizer) · 57-65 resolve.
usage: python music.py <out.wav>
"""
import sys

import numpy as np
import soundfile as sf

SR = 48000
DUR = 66.0
BPM = 96
BEAT = 60 / BPM
N = int(SR * DUR)
t = np.arange(N) / SR
rng = np.random.default_rng(7)


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env_adsr(n, a, d, s, r, sr=SR):
    x = np.arange(n) / sr
    e = np.where(x < a, x / a, np.where(x < a + d, 1 - (1 - s) * (x - a) / d, s))
    rel = np.clip((n / sr - x) / r, 0, 1) if r > 0 else 1
    return e * rel


def lowpass(x, cutoff):
    # one-pole low-pass, cutoff may be an array
    a = np.exp(-2 * np.pi * np.asarray(cutoff) / SR) * np.ones(len(x))
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def lp_fast(x, cutoff):
    # vectorised one-pole via scipy
    from scipy.signal import lfilter
    a = np.exp(-2 * np.pi * cutoff / SR)
    return lfilter([1 - a], [1, -a], x)


def smooth_step(x, a, b):
    p = np.clip((x - a) / (b - a), 0, 1)
    return p * p * (3 - 2 * p)


L = np.zeros(N)
R = np.zeros(N)

# chord progression: Am9 · Fmaj7 · Cmaj7/E · G6 — one chord per 2 bars (5 s)
CHORDS = [[57, 60, 64, 67, 71], [53, 57, 60, 64, 69], [52, 55, 60, 64, 67], [55, 59, 62, 64, 67]]
BAR = 4 * BEAT
CH = 2 * BAR  # 5.0 s

# ---- pad: detuned soft saws (additive, few partials), slow swell, gently filtered
for k in range(int(DUR / CH) + 1):
    t0 = k * CH
    chord = CHORDS[k % 4] if t0 < 57 else [57, 60, 64, 69, 72]
    length = CH + 1.2 if t0 < 57 else DUR - t0
    n = int(length * SR)
    s0 = int(t0 * SR)
    if s0 >= N or t0 >= 62:
        break
    n = min(n, N - s0)
    tt = np.arange(n) / SR
    e = env_adsr(n, 1.4, 1.0, 0.8, 1.2)
    for j, m in enumerate(chord):
        for det, pan in ((-0.09, 0.25), (0.09, 0.75)):
            f = midi(m) * 2 ** (det / 12)
            w = sum(np.sin(2 * np.pi * f * h * tt + rng.uniform(0, 6)) / h ** 1.6 for h in (1, 2, 3, 4))
            L[s0:s0 + n] += w * e * 0.022 * (1 - pan)
            R[s0:s0 + n] += w * e * 0.022 * pan

# ---- sub bass on chord roots, 8th-note pulse from 5 s, sustained at the end
roots = [45, 41, 40, 43]
for k in range(int(DUR / (BEAT / 2))):
    t0 = k * BEAT / 2
    if t0 < 4.5 or t0 >= 64.0:
        continue
    chord_i = int(t0 // CH) % 4
    m = roots[chord_i] if t0 < 57 else 45
    dur = BEAT / 2 * 0.9 if t0 < 57 else min(DUR - t0, 7.5)
    if t0 >= 57 and k % 16:
        continue
    n = int(dur * SR)
    s0 = int(t0 * SR)
    n = min(n, N - s0)
    tt = np.arange(n) / SR
    e = env_adsr(n, 0.005, 0.12, 0.55, 0.05)
    acc = 1.0 if k % 2 == 0 else 0.7
    w = np.sin(2 * np.pi * midi(m) * tt) + 0.25 * np.sin(2 * np.pi * midi(m + 12) * tt)
    L[s0:s0 + n] += w * e * 0.10 * acc
    R[s0:s0 + n] += w * e * 0.10 * acc

# ---- soft kick on beats (5-57 s), softer during narration-heavy bars
def kick(at, gain):
    n = int(0.35 * SR)
    s0 = int(at * SR)
    if s0 + n > N:
        return
    tt = np.arange(n) / SR
    f = 48 + 90 * np.exp(-tt * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    w = np.sin(ph) * np.exp(-tt * 9)
    L[s0:s0 + n] += w * gain
    R[s0:s0 + n] += w * gain


def hat(at, gain, pan=0.5):
    n = int(0.06 * SR)
    s0 = int(at * SR)
    if s0 + n > N:
        return
    nz = rng.standard_normal(n)
    nz = nz - lp_fast(nz, 6000)
    w = nz * np.exp(-np.arange(n) / SR * 70)
    L[s0:s0 + n] += w * gain * (1 - pan)
    R[s0:s0 + n] += w * gain * pan


b = 0
while True:
    at = 5.0 + b * BEAT
    if at >= 57:
        break
    lift = 1.25 if at >= 44 else 1.0
    kick(at, 0.16 * lift)
    if at >= 14:
        hat(at + BEAT / 2, 0.035 * lift, 0.35 + 0.3 * (b % 2))
    if at >= 44:
        hat(at + BEAT / 4, 0.018, 0.7)
        hat(at + 3 * BEAT / 4, 0.018, 0.3)
    b += 1

# ---- pluck arpeggio (sparkle), 16ths, from 14 s, pauses 37-44, returns brighter 44-57
ARP = [0, 2, 4, 3, 1, 3, 4, 2]
k = 0
while True:
    at = 14.0 + k * BEAT / 2
    if at >= 57:
        break
    if 37 <= at < 44:
        k += 1
        continue
    chord = CHORDS[int(at // CH) % 4]
    m = chord[ARP[k % 8]] + 12
    n = int(0.5 * SR)
    s0 = int(at * SR)
    tt = np.arange(n) / SR
    w = (np.sin(2 * np.pi * midi(m) * tt) + 0.3 * np.sin(2 * np.pi * midi(m) * 2 * tt)) * np.exp(-tt * 7)
    g = 0.030 if at < 44 else 0.040
    pan = 0.3 if k % 2 else 0.7
    L[s0:s0 + n] += w * g * (1 - pan)
    R[s0:s0 + n] += w * g * pan
    k += 1

# ---- riser into the organizer section and a soft swell into the close
for a, b_, g in ((42.0, 44.0, 0.05), (55.2, 57.0, 0.05)):
    s0, s1 = int(a * SR), int(b_ * SR)
    nz = rng.standard_normal(s1 - s0)
    nz = lp_fast(nz, 3500) - lp_fast(nz, 400)
    e = np.linspace(0, 1, s1 - s0) ** 2
    L[s0:s1] += nz * e * g
    R[s0:s1] += nz * e * g

# ---- simple stereo "room": short multi-tap echo
for d, g in ((0.031, 0.25), (0.047, 0.2), (0.089, 0.12)):
    n = int(d * SR)
    L[n:] += R[:-n] * g
    R[n:] += L[:-n] * g

mix = np.stack([L, R], axis=1)
mix *= smooth_step(t, 0, 1.0)[:, None] * (1 - smooth_step(t, 63.0, 65.8))[:, None]
mix /= np.max(np.abs(mix)) + 1e-9
mix *= 0.7
sf.write(sys.argv[1], mix.astype(np.float32), SR, subtype="FLOAT")
print("music", sys.argv[1], f"{DUR}s")
