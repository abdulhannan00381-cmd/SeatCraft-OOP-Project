"""Generate the narration lines with Kokoro (offline TTS, Apache-2.0).

usage: python voice.py <models dir> <out dir> [voice] [speed]
Writes vo_XX.wav per line plus lines.json with durations.
"""
import json
import os
import sys

import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

from script import LINES

models, out = sys.argv[1], sys.argv[2]
voice = sys.argv[3] if len(sys.argv) > 3 else "af_heart"
speed = float(sys.argv[4]) if len(sys.argv) > 4 else 0.95
os.makedirs(out, exist_ok=True)
k = Kokoro(os.path.join(models, "kokoro-v1.0.onnx"), os.path.join(models, "voices-v1.0.bin"))
meta = []
for i, line in enumerate(LINES):
    samples, sr = k.create(line["say"], voice=voice, speed=line.get("speed", speed), lang="en-us")
    # trim leading/trailing silence, keep a 40 ms tail so endings never clip
    a = np.abs(samples)
    idx = np.where(a > 0.01)[0]
    s0, s1 = max(0, idx[0] - int(0.02 * sr)), min(len(samples), idx[-1] + int(0.12 * sr))
    samples = samples[s0:s1]
    path = os.path.join(out, f"vo_{i:02d}.wav")
    sf.write(path, samples, sr)
    meta.append({"i": i, "at": line["at"], "dur": round(len(samples) / sr, 3), "text": line["text"]})
    print(f"{i:02d} at {line['at']:5.1f}s  dur {len(samples) / sr:5.2f}s  ends {line['at'] + len(samples) / sr:5.2f}  {line['text']}")
json.dump(meta, open(os.path.join(out, "lines.json"), "w"), indent=1)
