"""Убирает нарисованную шахматку «прозрачности»: заливка от краёв по светлым серым пикселям."""
import sys
from collections import deque
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGBA')
w, h = im.size
p = im.load()


def bgish(c):
    r, g, b, _ = c
    return min(r, g, b) > 196 and max(r, g, b) - min(r, g, b) < 14


seen = bytearray(w * h)
q = deque()
for x in range(w):
    for y in (0, h - 1):
        q.append((x, y))
for y in range(h):
    for x in (0, w - 1):
        q.append((x, y))
while q:
    x, y = q.popleft()
    i = y * w + x
    if seen[i] or not bgish(p[x, y]):
        continue
    seen[i] = 1
    if x > 0: q.append((x - 1, y))
    if x < w - 1: q.append((x + 1, y))
    if y > 0: q.append((x, y - 1))
    if y < h - 1: q.append((x, y + 1))

out = Image.new('RGBA', (w, h))
o = out.load()
for y in range(h):
    for x in range(w):
        c = p[x, y]
        if seen[y * w + x]:
            o[x, y] = (0, 0, 0, 0)
        else:
            # светлая кайма у края фигуры — делаем полупрозрачной, чтобы не было белого ореола
            near = (x > 0 and seen[y * w + x - 1]) or (x < w - 1 and seen[y * w + x + 1]) or \
                   (y > 0 and seen[(y - 1) * w + x]) or (y < h - 1 and seen[(y + 1) * w + x])
            o[x, y] = (c[0], c[1], c[2], 120 if near and min(c[:3]) > 180 else 255)
out.save(dst)
print('removed', sum(seen), 'of', w * h)
