# SeatCraft product film v2 — editable source

A deterministic pipeline: the same inputs always render the same film.
Every interface pixel comes from the real app (`SeatCraft-Demo.exe`), captured in its film mode.

## 1. Capture real app states (about 90 s)

```bat
set QT_ENABLE_HIGHDPI_SCALING=0
set SEATCRAFT_DOWNLOAD_DIR=C:\Users\Public\Downloads
SeatCraft-Demo.exe --demo --film --data <scratch>\film-data.txt --screenshots <film>\cap
```

`--film` (see `qml/Main.qml`, `filmShots`) drives the real app through the story with a throwaway
data file, so production data is never touched. It sizes the window to 1600×900, takes each step and
grabs the whole window at 2× (3200×1800). Steps: Discover → filter by Thu 12 + Talks → TechTalk seat
page → C5 → best seats together → details → name typed → confirmed → ticket → download → search
→ cancel → seats free → organizer clash → fix applied → published → venues.
Then flatten the PNGs onto the app background (#0B0A09) into `<film>\flat`.

## 2. Voice, music, effects

| Step | Command | Notes |
|---|---|---|
| Narration | `python voice.py <models> <film>\audio af_heart 0.95` | Kokoro v1.0 (Apache-2.0, offline). Voice `af_heart`. Script and timings live in `script.py`. |
| Score | `python music.py <film>\audio\music.wav` | Original 96 BPM A-minor bed, synthesised in code, so it is royalty-free. |
| Effect cues | `python film.py <film> sfx <film>\sfx.json` | Click, selection, confirm, download, cancel, fix and publish cues, timed to the picture. |
| Mix and captions | `python mix.py <film>` | Ducks the score under the voice, adds the effects and writes the `.srt` from the real line timings. |

## 3. Picture

```
python film.py <film> preview sheet.png         # contact sheet
python film.py <film> frames 12.5,30.1 stills   # full-size stills
python film.py <film> render video.mp4 4        # 4 parallel workers, then concatenated
```

`film.py` is the edit: one function per scene (`SCENES` table), with eased camera keys, the cursor
path, click pulses, highlights, captions and match cuts. Coordinates are logical window pixels (1600×900).

## 4. Final mux

```
ffmpeg -i video.mp4 -i audio\mix.wav -c:v copy -af loudnorm=I=-14:TP=-1.5:LRA=9 -c:a aac -b:a 192k -ar 48000 -shortest -movflags +faststart SeatCraft-Product-Showcase-v2.mp4
```

Requirements: Python 3.12 with Pillow, numpy, scipy, soundfile and kokoro-onnx; ffmpeg with libx264.
