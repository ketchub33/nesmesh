"""Одноразовый патч game.gd: UI-ассеты из assets/ui, шрифты, новый экран выбора."""
p = 'scripts/game.gd'
s = open(p, encoding='utf-8').read()


def R(a, b):
    global s
    assert s.count(a) == 1, a[:90]
    s = s.replace(a, b)


def between(start, end, new):
    global s
    a = s.index(start)
    b = s.index(end)
    s = s[:a] + new + s[b:]


R('var font: Font\n', '''var font: Font
var font_head: Font
var ui := {}
var panel_sb: StyleBoxTexture
const UI_NAMES := ["btn_normal", "btn_selected", "btn_pressed", "panel", "toggle_off", "toggle_on", "slider_empty",
	"knob", "arrow_left", "arrow_right", "tag_p1", "tag_p2", "banner_left", "banner_right", "bar_empty_p1", "bar_fill_p1",
	"bar_empty_p2", "bar_fill_p2", "vs", "hex_normal", "hex_p1", "hex_p2"]
''')

# шрифты и ui-текстуры
R('''	font = sf
''', '''	font = sf
	if ResourceLoader.exists("res://assets/fonts/Oswald-SemiBold.ttf"):
		font = load("res://assets/fonts/Oswald-SemiBold.ttf")
	font_head = load("res://assets/fonts/RussoOne-Regular.ttf") if ResourceLoader.exists("res://assets/fonts/RussoOne-Regular.ttf") else font
	for n in UI_NAMES:
		ui[n] = load("res://assets/ui/%s.png" % n)
	panel_sb = StyleBoxTexture.new()
	panel_sb.texture = ui.panel
	panel_sb.set_texture_margin_all(110)
''')

R('''	ip_edit.add_theme_font_size_override("font_size", 22)''', '''	ip_edit.add_theme_font_size_override("font_size", 22)
	ip_edit.add_theme_font_override("font", font)
	var le_sb := StyleBoxFlat.new()
	le_sb.bg_color = Color(0.06, 0.03, 0.06, 0.92)
	le_sb.border_color = Color(0.75, 0.72, 0.8)
	le_sb.set_border_width_all(2)
	le_sb.content_margin_left = 14
	ip_edit.add_theme_stylebox_override("normal", le_sb)
	var le_focus: StyleBoxFlat = le_sb.duplicate()
	le_focus.border_color = Color("e0245e")
	ip_edit.add_theme_stylebox_override("focus", le_focus)''')

# крупный текст — Russo One, мелкий — Oswald
between('func txt(s: String, p: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 0) -> void:',
        '# ---------------- меню ----------------', '''func txt(s: String, p: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 0) -> void:
	var f: Font = font_head if size >= 28 else font
	var w := 2000.0
	var x := p.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w / 2
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	if outline > 0:
		draw_string_outline(f, Vector2(x, p.y), s, align, w, size, outline, Color(0, 0, 0, 0.85 * col.a))
	draw_string(f, Vector2(x, p.y), s, align, w, size, col)


## Растягивает картинку по ширине, не искажая края (cap — ширина края в пикселях картинки).
func draw_3slice(tex: Texture2D, r: Rect2, cap: float, mod := Color.WHITE) -> void:
	var ts := tex.get_size()
	var k := r.size.y / ts.y
	var cw := minf(cap * k, r.size.x / 2.0)
	var cs := cw / k
	draw_texture_rect_region(tex, Rect2(r.position, Vector2(cw, r.size.y)), Rect2(0, 0, cs, ts.y), mod)
	draw_texture_rect_region(tex, Rect2(r.position.x + cw, r.position.y, r.size.x - 2 * cw, r.size.y), Rect2(cs, 0, ts.x - 2 * cs, ts.y), mod)
	draw_texture_rect_region(tex, Rect2(r.end.x - cw, r.position.y, cw, r.size.y), Rect2(ts.x - cs, 0, cs, ts.y), mod)


## Полоска: пустая рамка + заливка, обрезанная по доле f.
func draw_bar(r: Rect2, f: float, slot: int) -> void:
	var e: Texture2D = ui["bar_empty_p%d" % (slot + 1)]
	var fl: Texture2D = ui["bar_fill_p%d" % (slot + 1)]
	draw_texture_rect(e, r, false)
	f = clampf(f, 0.0, 1.0)
	var ts := fl.get_size()
	draw_texture_rect_region(fl, Rect2(r.position, Vector2(r.size.x * f, r.size.y)), Rect2(0, 0, ts.x * f, ts.y))


func draw_panel(r: Rect2) -> void:
	draw_style_box(panel_sb, r)


''')

# кнопки
between('func button(r: Rect2, label: String, id: String, value := "") -> void:', 'func draw_title(vs: Vector2) -> void:',
        '''func button(r: Rect2, label: String, id: String, value := "") -> void:
	var on := ui_btns.size() == ui_sel
	ui_btns.append({"r": r, "id": id})
	# у картинки кнопки по краям свечение и шипы — рисуем её чуть больше области нажатия
	var tex: Texture2D = ui.btn_selected if on else ui.btn_normal
	var h := r.size.y * 1.55
	draw_3slice(tex, Rect2(r.position.x - h * 0.42, r.get_center().y - h / 2, r.size.x + h * 0.84, h), 175.0)
	var y := r.get_center().y + 9
	var tc := Color.WHITE if on else Color(0.86, 0.84, 0.9)
	if value == "":
		txt(label, Vector2(r.get_center().x, y), 26, tc, HORIZONTAL_ALIGNMENT_CENTER, 4 if on else 0)
	else:
		txt(label, Vector2(r.position.x + 30, y), 24, tc, HORIZONTAL_ALIGNMENT_LEFT, 4 if on else 0)
		txt(value, Vector2(r.end.x - 30, y), 24, tc, HORIZONTAL_ALIGNMENT_RIGHT, 4 if on else 0)


''')

# настройки: переключатели и ползунок
between('func draw_settings(vs: Vector2) -> void:', 'func draw_controls(vs: Vector2) -> void:', '''func draw_settings(vs: Vector2) -> void:
	var cx := vs.x / 2
	txt("НАСТРОЙКИ", Vector2(cx, 100), 56, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10)
	if show_controls:
		draw_controls(vs)
		return
	draw_panel(Rect2(cx - 380, 125, 760, 500))
	var items := [
		["Громкость", "set_volume"],
		["Полный экран", "set_fullscreen"],
		["Тряска экрана", "set_shake"],
		["Вибрация геймпада", "set_rumble"],
		["Управление", "controls"],
		["Назад", "back"],
	]
	for i in items.size():
		var r := Rect2(cx - 270, 165 + i * 72, 540, 52)
		button(r, items[i][0], items[i][1], " " if i < 4 else "")
		if i < 4:
			var y := r.get_center().y
			if items[i][1] == "set_volume":
				var br := Rect2(r.end.x - 230, y - 9, 190, 18)
				draw_bar(br, settings.volume / 100.0, 0)
				var kn: Texture2D = ui.knob
				var ks := Vector2(26, 32)
				draw_texture_rect(kn, Rect2(Vector2(br.position.x + br.size.x * settings.volume / 100.0, y) - ks / 2, ks), false)
			else:
				var on: bool = settings[{"set_fullscreen": "fullscreen", "set_shake": "shake", "set_rumble": "rumble"}[items[i][1]]]
				var tex: Texture2D = ui.toggle_on if on else ui.toggle_off
				var ts := tex.get_size()
				var th := 36.0
				draw_texture_rect(tex, Rect2(r.end.x - 34 - ts.x * th / ts.y, y - th / 2, ts.x * th / ts.y, th), false)


''')
R('''	var box := Rect2(cx - 540, 130, 1080, 500)
	rbox(box, Color(0.03, 0.06, 0.16, 0.88), Color(1, 1, 1, 0.3), 18)''', '''	var box := Rect2(cx - 560, 125, 1120, 510)
	draw_panel(box)''')
R('''	rbox(Rect2(cx - 430, 135, 860, 470), Color(0.03, 0.06, 0.16, 0.85), Color(1, 1, 1, 0.3), 18)''',
  '''	draw_panel(Rect2(cx - 450, 128, 900, 490))''')

# экран выбора
between('func draw_hex_portrait(ch: Dictionary, c: Vector2, r: float, pf) -> void:', 'func draw_over(vs: Vector2) -> void:', '''func draw_hex_portrait(ch: Dictionary, c: Vector2, r: float, pf) -> void:
	var pts := hex_points(c, r)
	draw_colored_polygon(pts, Color(0.06, 0.03, 0.06))
	if ch.has("portrait"):
		var tex: Texture2D = textures[ch.portrait[0]]
		var src: Rect2 = ch.portrait[1]
		var ts := tex.get_size()
		var uvs := PackedVector2Array()
		for pt in pts:
			var rel := (pt - c) / (2.0 * r) + Vector2(0.5, 0.5)
			uvs.append((src.position + rel * src.size) / ts)
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)
	elif pf:
		draw_portrait(pf, c, r * 0.8)


## Рамка-шестиугольник из ассетов: центр рамки совпадает с центром ячейки радиуса r.
func draw_hex_frame(tex: Texture2D, c: Vector2, r: float) -> void:
	var ts := tex.get_size()
	var k := (r * 2.0 + 10.0) / (ts.y * 0.68)
	var sz := ts * k
	draw_texture_rect(tex, Rect2(c - sz / 2, sz), false)


## Большой арт выбранного бойца сбоку экрана (P2 — зеркально).
func draw_side_art(slot: int, vs: Vector2) -> void:
	var n: int = Fighter.CHARS.size()
	var right := slot == 1
	if sel[slot] >= n:
		txt("?", Vector2(vs.x - 220 if right else 220.0, vs.y * 0.6), 260, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER, 14)
		return
	var ch: Dictionary = Fighter.CHARS[sel[slot]]
	if ch.has("portrait"):
		var tex: Texture2D = textures[ch.portrait[0]]
		var ts := tex.get_size()
		var h := vs.y - 80
		var w := ts.x * h / ts.y
		var y := vs.y - h
		var x := vs.x - w + 20 if right else -20.0
		var dst := Rect2(x, y, -w, h) if right else Rect2(x, y, w, h)
		draw_texture_rect(tex, dst, false)
	else:
		var p = previews[slot]
		if p:
			draw_set_transform(Vector2(vs.x - 220 if right else 220.0, vs.y - 170) - p.pos * 3.4, 0, Vector2(3.4, 3.4))
			draw_fighter(p, false)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


## Плашка с именем и характеристиками внизу экрана.
func draw_name_banner(slot: int, vs: Vector2) -> void:
	var n: int = Fighter.CHARS.size()
	var right := slot == 1
	var pc: Color = PCOL[slot]
	var y := vs.y - 150
	var w := 520.0
	var r := Rect2(vs.x - w + 8, y, w, 78) if right else Rect2(-8, y, w, 78)
	draw_3slice(ui.banner_right if right else ui.banner_left, r, 150.0)
	var c: Dictionary = Fighter.CHARS[sel[slot]] if sel[slot] < n else {}
	var nm: String = c.get("name", "Случайный").to_upper()
	var tx := vs.x - 70 if right else 70.0
	var al := HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	txt(nm, Vector2(tx, y + 54), 38, Color.WHITE, al, 6)
	txt(slot_label(slot), Vector2(tx, y - 8), 20, pc, al, 5)
	# подложка под характеристики
	var sy := y + 92
	draw_rect(Rect2(vs.x - 460 if right else 0.0, sy - 6, 460, 50), Color(0.02, 0.01, 0.03, 0.75))
	if c.is_empty():
		return
	var stats := [["СКОРОСТЬ", c.speed / 7.5], ["ВЕС", c.weight / 1.4], ["СИЛА", c.power / 1.25], ["ПРЫЖКИ", (c.jumps + 1) / 4.0]]
	for k in 4:
		var col := k % 2
		var row := k / 2
		var sx: float = (vs.x - 440 + col * 215) if right else (24 + col * 215)
		var yy := sy + row * 22
		txt(stats[k][0], Vector2(sx, yy + 13), 14, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_LEFT)
		draw_bar(Rect2(sx + 78, yy + 2, 118, 14), stats[k][1], slot)


func draw_select(vs: Vector2) -> void:
	var cx := vs.x / 2
	var n: int = Fighter.CHARS.size()
	var online := net_mode != ""
	var can_edit := net_mode != "client"
	draw_rect(Rect2(0, 0, vs.x, vs.y), Color(0.03, 0.0, 0.02, 0.72))
	draw_side_art(0, vs)
	draw_side_art(1, vs)
	# затемнённая полоса по центру, чтобы соты читались поверх артов
	draw_rect(Rect2(cx - 230, 60, 460, vs.y - 60), Color(0.02, 0.0, 0.02, 0.55))

	# соты с портретами: ряды по 3 и 2
	var r := 70.0
	var hw := sqrt(3.0) * r
	var total := n + 1
	var rows := []
	var left := total
	var wide := true
	while left > 0:
		var k := mini(left, 3 if wide else 2)
		rows.append(k)
		left -= k
		wide = not wide
	var cells := []
	var gy0 := 250.0
	for ri in rows.size():
		var k: int = rows[ri]
		for j in k:
			cells.append(Vector2(cx + (j - (k - 1) / 2.0) * (hw + 22), gy0 + ri * (r * 1.5 + 20)))
	for i in total:
		var c: Vector2 = cells[i]
		if i < n:
			draw_hex_portrait(Fighter.CHARS[i], c, r, portraits[i])
		else:
			draw_colored_polygon(hex_points(c, r), Color(0.06, 0.03, 0.06))
			txt("?", c + Vector2(0, 26), 64, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 6)
		draw_hex_frame(ui.hex_normal, c, r)
	for sl in 2:
		var c: Vector2 = cells[sel[sl]]
		draw_hex_frame(ui.hex_p1 if sl == 0 else ui.hex_p2, c, r)
		var tex: Texture2D = ui.tag_p1 if sl == 0 else ui.tag_p2
		var ts := tex.get_size()
		var tw := 86.0
		var th := ts.y * tw / ts.x
		var ty := c.y + r + 10 if sl == 0 else c.y - r - 10 - th
		draw_texture_rect(tex, Rect2(c.x - tw / 2, ty, tw, th), false)
		var lab: String = slot_label(sl)
		txt(lab if lab.length() <= 3 else "P%d" % (sl + 1), Vector2(c.x + 6, ty + th / 2 + 6), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 3)

	draw_name_banner(0, vs)
	draw_name_banner(1, vs)
	var vt: Texture2D = ui.vs
	var vsz := vt.get_size() * (250.0 / vt.get_size().x)
	draw_texture_rect(vt, Rect2(Vector2(cx, vs.y - 120) - vsz / 2, vsz), false)

	# верхняя полоса с настройками матча
	draw_rect(Rect2(0, 0, vs.x, 60), Color(0.03, 0.01, 0.03, 0.92))
	draw_rect(Rect2(0, 59, vs.x, 1), Color("e0245e"))
	txt("Esc / B — назад", Vector2(20, 37), 17, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	var chips := [["Арена: " + ARENAS[arena].name, "Q E", can_edit], ["Жизни: %d" % stocks, "W S", can_edit]]
	if not online:
		chips.append(["Соперник: " + ("CPU" if vs_cpu else "Игрок 2"), "C", true])
		if vs_cpu:
			chips.append(["Сложность: " + LVL_NAMES[lvl], "V", true])
	var total_w := 0.0
	for c in chips:
		total_w += font.get_string_size(c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + font.get_string_size(c[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 56
	var x := cx - total_w / 2
	for c in chips:
		x += chip(x, 12, c[0], c[1], c[2]) + 12
	txt("ОНЛАЙН" if online else "ВЫБОР БОЙЦА", Vector2(cx, 112), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8)

	var blink := 0.6 + 0.4 * sin(frame * 0.1)
	var py: float = cells[total - 1].y + r + 70
	if net_mode == "client":
		txt("Ждём хоста...", Vector2(cx, py), 22, Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER, 5)
	else:
		txt("ENTER / A — В БОЙ", Vector2(cx, py), 22, Color(1, 0.85, 0.35, blink), HORIZONTAL_ALIGNMENT_CENTER, 5)


''')

R('''	rbox(Rect2(x, y, w, 36), Color(0.04, 0.08, 0.22, 0.85), Color(1, 1, 1, 0.45 if active else 0.15), 10)''',
  '''	rbox(Rect2(x, y, w, 36), Color(0.08, 0.03, 0.06, 0.9), Color(0.88, 0.14, 0.37, 0.8) if active else Color(1, 1, 1, 0.15), 6)''')

open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
