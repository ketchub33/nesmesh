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
    0: (384, 20, 488, 164), 1: (516, 20, 620, 164), 2: (644, 20, 744, 164), 3: (772, 20, 872, 164),
    4: (900, 20, 1000, 164), 5: (1028, 20, 1128, 164), 6: (1156, 20, 1256, 164), 7: (4, 4, 372, 488),
    8: (388, 200, 484, 328), 9: (516, 196, 604, 328), 10: (652, 196, 740, 320), 11: (780, 196, 868, 320),
    12: (912, 200, 1008, 328), 13: (1052, 200, 1148, 324), 14: (1172, 208, 1264, 332), 15: (1284, 200, 1384, 340),
    16: (384, 344, 488, 480), 17: (512, 356, 632, 480), 18: (664, 344, 768, 464), 19: (808, 352, 920, 456),
    20: (964, 360, 1084, 488), 21: (1140, 352, 1260, 472), 22: (1320, 364, 1464, 468),
    23: (12, 516, 164, 656), 24: (188, 524, 344, 660), 25: (372, 520, 512, 660), 26: (520, 528, 680, 660),
    27: (688, 524, 840, 660), 28: (856, 496, 1120, 652), 29: (1140, 512, 1352, 656), 30: (1356, 504, 1528, 660),
    33: (32, 720, 144, 816), 34: (200, 716, 332, 816), 35: (356, 732, 480, 812),
}
ANIMS = {
    "idle": [0, 1, 2, 3, 4, 5, 6],
    "run": [8, 9, 10, 11, 12, 13, 14, 15],
    "jump": [17, 18],
    "fall": [20, 21],
    "dodge": [16, 19, 22],
    "attack": [23, 24, 25, 26, 27],
    "attack2": [26, 27, 28, 29, 30],
    "hit": [33, 34, 35],
}
FX = {
    "spark": [(1224, 692, 1304, 804)],
    "ring": [(1112, 696, 1216, 812)],
    "spike": [(1384, 676, 1488, 812)],
    "line": [(1340, 688, 1372, 812)],
    "circle": [(20, 856, 176, 1000)],
    "slash": [(208, 824, 484, 1000)],
    "swirl": [(532, 864, 700, 1000)],
    "dust": [(756, 776, 968, 1000)],
    "burst": [(1008, 848, 1264, 1004)],
}

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

portrait = sheet.crop((4, 4, 372, 488))
portrait.save(os.path.join(OUT, 'portrait.png'))

for name, boxes in FX.items():
    x0 = min(b[0] for b in boxes); y0 = min(b[1] for b in boxes)
    x1 = max(b[2] for b in boxes); y1 = max(b[3] for b in boxes)
    sheet.crop((x0, y0, x1, y1)).save(os.path.join(VFX, name + '.png'))

print(json.dumps({"fw": fw, "fh": fh, "anchor": [ax, ay], "counts": {k: len(v) for k, v in ANIMS.items()},
                  "body_h": max(frames[i][1][1] - frames[i][0].getbbox()[1] for i in ANIMS["idle"])}))
