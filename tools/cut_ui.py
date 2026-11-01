"""Режет листы UI (assets/ui/source) на отдельные PNG в assets/ui. Запуск из корня проекта."""
from PIL import Image

OUT = 'assets/ui/'
PAD = 10

MENU = {
    'btn_normal': (36, 24, 828, 160),
    'btn_selected': (36, 180, 828, 312),
    'btn_pressed': (40, 324, 820, 452),
    'panel': (28, 472, 904, 972),
    'toggle_off': (916, 72, 1164, 192),
    'toggle_on': (1224, 76, 1476, 192),
    'slider_empty': (860, 268, 1512, 360),
    'slider_full': (856, 396, 1520, 488),
    'knob': (1150, 270, 1222, 360),
    'arrow_left': (980, 616, 1228, 876),
    'arrow_right': (1240, 616, 1488, 876),
}
SELECT = {
    'tag_p1': (1148, 168, 1444, 248),
    'tag_p2': (1152, 264, 1444, 348),
    'banner_left': (64, 452, 756, 564),
    'banner_right': (848, 452, 1468, 564),
    'bar_empty_p1': (48, 584, 616, 642),
    'bar_fill_p1': (48, 646, 616, 708),
    'bar_empty_p2': (924, 584, 1492, 642),
    'bar_fill_p2': (924, 646, 1492, 708),
    'vs': (344, 712, 1192, 1012),
}
HEX = {'hex_normal': (132, 8, 444, 456), 'hex_p1': (464, 8, 784, 456), 'hex_p2': (800, 8, 1124, 456)}


def crop(sheet, b, pad=PAD):
    w, h = sheet.size
    return sheet.crop((max(0, b[0] - pad), max(0, b[1] - pad), min(w, b[2] + pad), min(h, b[3] + pad)))


menu = Image.open('assets/ui/source/menu_sheet.png').convert('RGBA')
sel = Image.open('assets/ui/source/select_sheet.png').convert('RGBA')
for name, b in MENU.items():
    crop(menu, b, 0 if name == 'knob' else PAD).save(OUT + name + '.png')
for name, b in SELECT.items():
    pad = 2 if name.startswith('bar_') else (0 if name.startswith('banner') else PAD)
    crop(sel, b, pad).save(OUT + name + '.png')

# шестиугольники: обрезаем симметрично вокруг центра металлической рамки, чтобы в игре центр рамки = центр ячейки
for name, b in HEX.items():
    part = sel.crop(b)
    solid = part.split()[3].point(lambda v: 255 if v > 200 else 0).getbbox()
    cx = b[0] + (solid[0] + solid[2]) / 2
    cy = b[1] + (solid[1] + solid[3]) / 2
    hw = max(cx - b[0], b[2] - cx) + 4
    hh = max(cy - b[1], b[3] - cy) + 4
    out = sel.crop((int(cx - hw), int(cy - hh), int(cx + hw), int(cy + hh)))
    # нижние углы вне шестиугольника — там могут оказаться куски соседних элементов
    px = out.load()
    ow, oh = out.size
    for y in range(oh - 60, oh):
        for x in range(ow):
            if abs(x - ow / 2) > 50 + (oh - y) * 2:
                px[x, y] = (0, 0, 0, 0)
    out.save(OUT + name + '.png')
    print(name, out.size, 'solid', solid[2] - solid[0], solid[3] - solid[1])
print('ok')
