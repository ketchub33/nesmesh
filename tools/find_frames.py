import sys
from PIL import Image, ImageDraw

SRC = sys.argv[1]
OUT = sys.argv[2]
im = Image.open(SRC).convert('RGBA')
W, H = im.size
F = 4  # клетка сетки для поиска связных областей
alpha = im.split()[3].point(lambda v: 255 if v > 40 else 0)
small = alpha.resize((W // F, H // F), Image.Resampling.BOX).point(lambda v: 255 if v > 0 else 0)
sw, sh = small.size
px = small.load()
seen = [[False] * sw for _ in range(sh)]
boxes = []
R = 2  # «слипание» соседних кусков (в клетках)
for y in range(sh):
    for x in range(sw):
        if px[x, y] == 0 or seen[y][x]:
            continue
        stack = [(x, y)]
        seen[y][x] = True
        x0 = x1 = x
        y0 = y1 = y
        while stack:
            cx, cy = stack.pop()
            x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
            for dy in range(-R, R + 1):
                for dx in range(-R, R + 1):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < sw and 0 <= ny < sh and not seen[ny][nx] and px[nx, ny]:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
        b = (x0 * F, y0 * F, (x1 + 1) * F, (y1 + 1) * F)
        if (b[2] - b[0]) * (b[3] - b[1]) >= 600:
            boxes.append(b)
boxes.sort(key=lambda b: ((b[1] + b[3]) // 2 // 150, b[0]))
d = ImageDraw.Draw(im)
for i, b in enumerate(boxes):
    print(i, b, b[2] - b[0], b[3] - b[1])
    d.rectangle(b, outline=(255, 0, 0, 255), width=2)
    d.text((b[0] + 2, b[1] + 2), str(i), fill=(255, 0, 0, 255))
bg = Image.new('RGBA', im.size, (40, 40, 40, 255))
bg.alpha_composite(im)
bg.save(OUT)
