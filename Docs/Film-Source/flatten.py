"""Composite the transparent film-mode captures onto the app background (#0B0A09).
usage: python flatten.py <film dir>    (reads <film>/cap/*.png, writes <film>/flat/*.png)"""
import glob
import os
import sys

from PIL import Image

film = sys.argv[1]
os.makedirs(os.path.join(film, "flat"), exist_ok=True)
for f in glob.glob(os.path.join(film, "cap", "*.png")):
    im = Image.open(f).convert("RGBA")
    bg = Image.new("RGBA", im.size, (11, 10, 9, 255))
    bg.alpha_composite(im)
    bg.convert("RGB").save(os.path.join(film, "flat", os.path.basename(f)))
print("flattened")
