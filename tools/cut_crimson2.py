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
    "i0": (460, 28, 596, 164), "i1": (636, 32, 768, 164), "i2": (808, 32, 936, 164), "i3": (984, 28, 1108, 164),
    "i4": (1144, 24, 1276, 164), "i5": (1328, 24, 1464, 164),
    "r0": (456, 208, 584, 336), "r1": (612, 200, 756, 332), "r2": (800, 204, 936, 332), "r3": (980, 208, 1112, 336),
    "r4": (1176, 212, 1312, 340), "r5": (1368, 216, 1496, 340),
    "d0": (448, 372, 580, 488), "d1": (592, 376, 740, 488), "d2": (792, 376, 940, 480), "d3": (972, 380, 1112, 484),
    "d4": (1156, 376, 1296, 484), "d5": (1340, 376, 1464, 484),
    "a0": (24, 512, 180, 668), "a1": (208, 512, 352, 668), "a2": (376, 532, 516, 668), "a3": (552, 536, 680, 672),
    "a4": (720, 504, 936, 680), "a5": (938, 504, 1166, 680), "a6": (1162, 500, 1352, 716), "a7": (1354, 500, 1528, 716),
    "h0": (20, 708, 164, 824), "h1": (216, 712, 360, 812), "h2": (384, 712, 536, 824),
}
ANIMS = {
    "idle": ["i0", "i1", "i2", "i3", "i4", "i5"],
    "run": ["r0", "r1", "r2", "r3", "r4", "r5"],
    "jump": ["d0", "d1"],
    "fall": ["d4", "d5"],
    "dodge": ["d1", "d2", "d3"],
    "attack": ["a2", "a3", "a4", "a5"],
    "attack2": ["a3", "a4", "a5", "a6", "a7"],
    "hit": ["h0", "h1", "h2"],
}
FX = {
    "slash": [(8, 852, 272, 1004)],
    "spike": [(264, 848, 536, 1008)],
    "line": [(532, 856, 720, 1004)],
    "spark": [(532, 856, 720, 1004)],
    "dust": [(748, 868, 984, 1008)],
    "swirl": [(748, 868, 984, 1008)],
    "burst": [(976, 848, 1360, 1008)],
    "ring": [(1360, 860, 1520, 1008)],
    "circle": [(1360, 860, 1520, 1008)],
}
PORTRAIT = (0, 8, 448, 464)
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
