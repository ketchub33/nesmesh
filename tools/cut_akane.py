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
    "i0": (484, 12, 620, 152), "i1": (648, 16, 784, 152), "i2": (824, 16, 964, 152), "i3": (1012, 16, 1152, 152),
    "i4": (1188, 16, 1328, 152), "i5": (1364, 12, 1504, 152),
    "r0": (464, 184, 604, 316), "r1": (640, 184, 772, 320), "r2": (808, 184, 948, 320), "r3": (996, 184, 1140, 320),
    "r4": (1180, 184, 1312, 320), "r5": (1364, 188, 1500, 320),
    "d0": (452, 348, 612, 480), "d1": (620, 352, 788, 480), "d2": (808, 352, 980, 480), "d3": (992, 352, 1148, 480),
    "d4": (1176, 356, 1328, 480), "d5": (1332, 352, 1508, 480),
    "a0": (36, 500, 196, 664), "a1": (216, 500, 356, 660), "a2": (388, 504, 528, 660), "a3": (552, 508, 692, 660),
    "a4": (704, 496, 936, 684), "a5": (954, 496, 1172, 684), "a6": (1178, 492, 1354, 704), "a7": (1364, 492, 1528, 704),
    "h0": (12, 688, 156, 816), "h1": (192, 692, 340, 812), "h2": (372, 692, 528, 812),
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
    "slash": [(32, 836, 288, 992)],
    "spike": [(288, 832, 540, 992)],
    "line": [(540, 844, 732, 992)],
    "spark": [(540, 844, 732, 992)],
    "dust": [(752, 852, 992, 996)],
    "swirl": [(752, 852, 992, 996)],
    "burst": [(984, 836, 1352, 996)],
    "ring": [(1356, 848, 1528, 1004)],
    "circle": [(1356, 848, 1528, 1004)],
}
PORTRAIT = (0, 0, 460, 472)
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
