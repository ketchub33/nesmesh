"""Режет AI-лист персонажа на ровные полосы кадров, выровненные по ногам, плюс отдельные VFX."""
import json
import os
import sys
from PIL import Image

SRC = sys.argv[1]
OUT = sys.argv[2]      # папка персонажа
VFX = sys.argv[3]      # папка эффектов
os.makedirs(OUT, exist_ok=True)
os.makedirs(VFX, exist_ok=True)

BOX = {
    "i0": (396, 20, 528, 152), "i1": (572, 20, 704, 152), "i2": (748, 20, 880, 148), "i3": (928, 20, 1068, 148),
    "i4": (1104, 20, 1240, 148), "i5": (1292, 20, 1424, 152),
    "r0": (388, 192, 504, 324), "r1": (560, 188, 680, 324), "r2": (720, 188, 864, 312), "r3": (900, 188, 1048, 320),
    "r4": (1080, 200, 1224, 316), "r5": (1268, 200, 1428, 312),
    "d0": (388, 352, 512, 472), "d1": (552, 360, 716, 472), "d2": (764, 364, 928, 468), "d3": (944, 364, 1108, 476),
    "d4": (1128, 372, 1296, 476), "d5": (1312, 368, 1480, 480),
    "a0": (8, 516, 180, 660), "a1": (240, 508, 380, 660), "a2": (432, 516, 568, 656), "a3": (604, 500, 824, 652),
    "a4": (828, 496, 1000, 668), "a5": (1140, 496, 1336, 668), "a6": (1340, 484, 1536, 684),
    "h0": (8, 696, 136, 812), "h1": (200, 692, 348, 808), "h2": (388, 704, 548, 808),
}
ANIMS = {
    "idle": ["i0", "i1", "i2", "i3", "i4", "i5"],
    "run": ["r0", "r1", "r2", "r3", "r4", "r5"],
    "jump": ["d0", "d1"],
    "fall": ["d4", "d5"],
    "dodge": ["d1", "d2", "d3"],
    "attack": ["a0", "a1", "a2", "a3"],
    "attack2": ["a2", "a3", "a4", "a5", "a6"],
    "hit": ["h0", "h1", "h2"],
}
FX = {
    "slash": [(32, 840, 276, 992)],
    "spike": [(268, 852, 492, 984)],
    "line": [(496, 880, 568, 984)],
    "spark": [(592, 856, 692, 972)],
    "dust": [(744, 852, 1000, 988)],
    "swirl": [(744, 852, 1000, 988)],
    "burst": [(1056, 820, 1320, 988)],
    "ring": [(1348, 876, 1512, 988)],
    "circle": [(1348, 876, 1512, 988)],
}
PORTRAIT = (0, 4, 388, 456)
sheet = Image.open(SRC).convert('RGBA')
# убираем полупрозрачный мусор вокруг кадров
r, g, b, a = sheet.split()
sheet = Image.merge('RGBA', (r, g, b, a.point(lambda v: 0 if v < 40 else v)))


def is_body(px):
    r, g, b, a = px
    if a < 40:
        return False
    return not (b > 150 and b > r + 30)  # светло-синие пиксели — это эффекты, не тело


def feet(img):
    """Точка между ног: самый низ тела и средний x нижних 12 строк."""
    w, h = img.size
    p = img.load()
    bottom = -1
    for y in range(h - 1, -1, -1):
        if any(is_body(p[x, y]) for x in range(w)):
            bottom = y
            break
    top = next(y for y in range(h) if any(is_body(p[x, y]) for x in range(w)))
    # x — центр корпуса (полоса 35–65% роста), чтобы ноги в беге не сдвигали персонажа
    y0 = top + int((bottom - top) * 0.35)
    y1 = top + int((bottom - top) * 0.65)
    xs = [x for y in range(y0, y1 + 1) for x in range(w) if is_body(p[x, y])]
    return (sorted(xs)[len(xs) // 2], bottom + 1)


frames = {}
for i, bx in BOX.items():
    img = sheet.crop(bx)
    frames[i] = (img, feet(img))

# одна ячейка на всех: максимальные отступы от точки ног
used = sorted({i for v in ANIMS.values() for i in v})
L = max(frames[i][1][0] for i in used)
Rr = max(frames[i][0].size[0] - frames[i][1][0] for i in used)
U = max(frames[i][1][1] for i in used)
D = max(frames[i][0].size[1] - frames[i][1][1] for i in used)
fw, fh = int(L + Rr) + 4, int(U + D) + 4
ax, ay = int(L) + 2, int(U) + 2

for name, ids in ANIMS.items():
    strip = Image.new('RGBA', (fw * len(ids), fh), (0, 0, 0, 0))
    for k, i in enumerate(ids):
        img, (fx, fy) = frames[i]
        strip.alpha_composite(img, (k * fw + int(round(ax - fx)), int(round(ay - fy))))
    strip.save(os.path.join(OUT, name + '.png'))

portrait = sheet.crop(PORTRAIT)
portrait.save(os.path.join(OUT, 'portrait.png'))

for name, boxes in FX.items():
    x0 = min(b[0] for b in boxes); y0 = min(b[1] for b in boxes)
    x1 = max(b[2] for b in boxes); y1 = max(b[3] for b in boxes)
    sheet.crop((x0, y0, x1, y1)).save(os.path.join(VFX, name + '.png'))

print(json.dumps({"fw": fw, "fh": fh, "anchor": [ax, ay], "counts": {k: len(v) for k, v in ANIMS.items()},
                  "body_h": max(frames[i][1][1] - frames[i][0].getbbox()[1] for i in ANIMS["idle"])}))
