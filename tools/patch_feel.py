"""Одноразовый патч: буфер ввода, отдельный прыжок, короткий прыжок, отмены, быстрые лёгкие атаки,
управление в воздухе, интерполяция отрисовки. Запуск из корня проекта."""


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert s.count(a) == 1, (path, a[:80])
        s = s.replace(a, b)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)


patch('scripts/fighter.gd', [
    ('const DODGE_GROUND_CD := 40\n', '''const DODGE_GROUND_CD := 40
const BUF := 6  # сколько кадров помнится нажатие (буфер ввода)
const BUFFERED := ["j", "atk", "spc", "sh"]
'''),
    ('"speed": 7.0, "air": 5.4,', '"speed": 7.0, "air": 6.2,'),
    ('"speed": 6.4, "air": 5.0,', '"speed": 6.4, "air": 5.8,'),
    ('"nlight": {"s": 5, "a": 4, "e": 12,', '"nlight": {"s": 4, "a": 4, "e": 8,'),
    ('"slight": {"s": 6, "a": 4, "e": 14,', '"slight": {"s": 5, "a": 4, "e": 9,'),
    ('"dlight": {"s": 5, "a": 7, "e": 14,', '"dlight": {"s": 5, "a": 6, "e": 9,'),
    ('"nair": {"s": 5, "a": 7, "e": 12,', '"nair": {"s": 4, "a": 6, "e": 8,'),
    ('"sair": {"s": 6, "a": 5, "e": 13,', '"sair": {"s": 5, "a": 5, "e": 9,'),
    ('"dair": {"s": 7, "a": 6, "e": 14,', '"dair": {"s": 6, "a": 6, "e": 10,'),
    ('var clinging := false\n', '''var clinging := false
var buf := {}
var hop_cut := false
var prev_pos := Vector2.ZERO  # позиция на прошлом тике — для плавной отрисовки
'''),
    ('''	var pr := {}
	for k in KEYS:
		pr[k] = inp.get(k, false) and not prev.get(k, false)
	prev = inp''', '''	var pr := {}
	for k in KEYS:
		var edge: bool = inp.get(k, false) and not prev.get(k, false)
		pr[k] = edge
		if edge and k in BUFFERED:
			buf[k] = BUF  # нажатие запоминается, даже если сейчас боец занят или замер от удара
	prev = inp'''),
    ('''	anim += 1
	if inv > 0:
		inv -= 1''', '''	anim += 1
	for k in BUFFERED:
		pr[k] = buf.get(k, 0) > 0
		if pr[k]:
			buf[k] -= 1
	if inv > 0:
		inv -= 1'''),
    ('''			dodge_t = 0
			if dir != 0:
				facing = dir
			start_atk(light_key(inp, dir, true))''', '''			dodge_t = 0
			buf["atk"] = 0
			if dir != 0:
				facing = dir
			start_atk(light_key(inp, dir, true))'''),
    ('''	var grav := true
	if not atk.is_empty():
		grav = step_attack(inp, dir, g)''', '''	var grav := true
	# попал — восстановление удара можно отменить прыжком или уклонением
	if not atk.is_empty() and not atk.hit.is_empty() and atk.t > atk.m.s + atk.m.a and (pr.j or pr.sh):
		atk = {}
	if not atk.is_empty():
		grav = step_attack(inp, dir, g)'''),
    ('''		if pr.u or pr.j:
			vel = Vector2(-wall_side * 3.5, -ch.djump)''', '''		if pr.j:
			buf["j"] = 0
			vel = Vector2(-wall_side * 3.5, -ch.djump)'''),
    ('''	else:
		if pr.u or pr.j:
			jump(dir)''', '''	else:
		if pr.j:
			jump(dir)'''),
    ('''			air_drift(dir, 0.55)
			if pr.d and vel.y > -3:
				ff = true
	if grav:''', '''			air_drift(dir, 0.8)
			if pr.d and vel.y > -3:
				ff = true
	# короткий прыжок: отпустил кнопку на подъёме — прыжок обрывается
	if hop_cut and vel.y < 0 and not inp.get("j", false) and not cpu:
		vel.y *= 0.5
		hop_cut = false
	if vel.y >= 0:
		hop_cut = false
	if grav:'''),
    ('''	if on_ground:
		vel.y = -ch.jump
		on_ground = false
		ff = false
		dash_t = 0''', '''	buf["j"] = 0
	if on_ground:
		vel.y = -ch.jump
		on_ground = false
		ff = false
		dash_t = 0
		hop_cut = true'''),
    ('''		air_dodge_used = true
		var v := Vector2(''', '''		air_dodge_used = true
		hop_cut = false
		var v := Vector2('''),
    ('''	dash_t = 0
	game.puff(pos, 5)
	game.sfx("dodge")''', '''	dash_t = 0
	buf["sh"] = 0
	game.puff(pos, 5)
	game.sfx("dodge")'''),
    ('''	if dir != 0:
		facing = dir
	start_atk(light_key(inp, dir, g))''', '''	if dir != 0:
		facing = dir
	buf["atk"] = 0
	start_atk(light_key(inp, dir, g))'''),
    ('''		used_up = true
		k = "rec"
	start_atk(k)''', '''		used_up = true
		k = "rec"
	buf["spc"] = 0
	start_atk(k)'''),
    ('''	if g:
		vel.x *= 0.8
	else:
		air_drift(dir, 0.3)''', '''	if g:
		vel.x *= 0.88
	else:
		air_drift(dir, 0.45)'''),
    ('''	for k in ["atk", "spc", "sh"]:
		if o.get(k, false) and ai_last.get(k, false):
			o[k] = false''', '''	if o.get("u", false) and not o.get("spc", false):
		o["j"] = true  # ИИ прыгает «вверх», как с включённым прыжком на стрелку
	for k in ["atk", "spc", "sh", "j"]:
		if o.get(k, false) and ai_last.get(k, false):
			o[k] = false'''),
])

patch('scripts/game.gd', [
    ('''	{"l": [KEY_A], "r": [KEY_D], "u": [KEY_W], "d": [KEY_S], "atk": [KEY_F], "spc": [KEY_G], "sh": [KEY_H]},''',
     '''	{"l": [KEY_A], "r": [KEY_D], "u": [KEY_W], "d": [KEY_S], "j": [KEY_SPACE], "atk": [KEY_F], "spc": [KEY_G], "sh": [KEY_H]},'''),
    ('''	{"l": [KEY_LEFT], "r": [KEY_RIGHT], "u": [KEY_UP], "d": [KEY_DOWN],''',
     '''	{"l": [KEY_LEFT], "r": [KEY_RIGHT], "u": [KEY_UP], "d": [KEY_DOWN], "j": [KEY_KP_0, KEY_CTRL],'''),
    ('''		o.j = bt.call(JOY_BUTTON_A) or bt.call(JOY_BUTTON_Y)''',
     '''		o.j = o.j or bt.call(JOY_BUTTON_A) or bt.call(JOY_BUTTON_Y)'''),
    ('''	return o


## Оба набора клавиш''', '''	if settings.tap_jump:
		o.j = o.j or o.u
	return o


## Оба набора клавиш'''),
    ('var settings := {"volume": 80, "fullscreen": false, "shake": true, "rumble": true}',
     'var settings := {"volume": 80, "fullscreen": false, "shake": true, "rumble": true, "tap_jump": false}'),
    ('var _cam_xf := Transform2D.IDENTITY\n', '''var _cam_xf := Transform2D.IDENTITY
var cam_prev := Vector2(640, 380)
var cam_z_prev := 1.0
'''),
    ('''func _physics_process(_d: float) -> void:
	frame += 1''', '''func _physics_process(_d: float) -> void:
	frame += 1
	# запоминаем состояние до тика: отрисовка плавно идёт между прошлым и текущим тиком
	for f in fighters:
		f.prev_pos = f.pos
	cam_prev = cam_pos
	cam_z_prev = cam_z'''),
    ('''		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_action("ok", 0)''', '''		KEY_ENTER, KEY_KP_ENTER:
			_action("ok", 0)'''),
    ('''		"set_rumble":
			settings.rumble = not settings.rumble''', '''		"set_tapjump":
			settings.tap_jump = not settings.tap_jump
		"set_rumble":
			settings.rumble = not settings.rumble'''),
    ('''		["Вибрация геймпада", "set_rumble"],
		["Управление", "controls"],''', '''		["Вибрация геймпада", "set_rumble"],
		["Прыжок кнопкой вверх", "set_tapjump"],
		["Управление", "controls"],'''),
    ('''	draw_panel(Rect2(cx - 380, 125, 760, 500))''', '''	draw_panel(Rect2(cx - 380, 122, 760, 540))'''),
    ('''		var r := Rect2(cx - 270, 165 + i * 72, 540, 52)
		button(r, items[i][0], items[i][1], " " if i < 4 else "")
		if i < 4:''', '''		var r := Rect2(cx - 270, 160 + i * 66, 540, 50)
		button(r, items[i][0], items[i][1], " " if i < 5 else "")
		if i < 5:'''),
    ('''{"set_fullscreen": "fullscreen", "set_shake": "shake", "set_rumble": "rumble"}''',
     '''{"set_fullscreen": "fullscreen", "set_shake": "shake", "set_rumble": "rumble", "set_tapjump": "tap_jump"}'''),
    ('''		["Прыжок", "W", "Стрелка вверх", "A"],''', '''		["Прыжок (держи — выше)", "Пробел", "Num0 или Ctrl", "A"],
		["Прицел вверх", "W", "Стрелка вверх", "Стик вверх"],'''),
    ('''	var off := Vector2(randf_range(-sh, sh), randf_range(-sh, sh)) * 0.5
	_cam_xf = Transform2D(0, Vector2(cam_z, cam_z), 0, vs / 2 + off - cam_pos * cam_z)''',
     '''	var off := Vector2(randf_range(-sh, sh), randf_range(-sh, sh)) * 0.5
	var t := Engine.get_physics_interpolation_fraction()
	var cz := lerpf(cam_z_prev, cam_z, t)
	_cam_xf = Transform2D(0, Vector2(cz, cz), 0, vs / 2 + off - cam_prev.lerp(cam_pos, t) * cz)'''),
    ('''	for f in fighters:
		draw_fighter(f, true)
	draw_parts()''', '''	for f in fighters:
		var real: Vector2 = f.pos
		if f.prev_pos.distance_to(real) < 150:  # после респауна не «пролетаем» через экран
			f.pos = f.prev_pos.lerp(real, t)
		draw_fighter(f, true)
		f.pos = real
	draw_parts()'''),
])
print('ok')
