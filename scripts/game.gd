extends Node2D
## Главная сцена: меню, бой, камера, эффекты, интерфейс.

const Fighter = preload("res://scripts/fighter.gd")
const PCOL := [Color("ff4d6d"), Color("4dabff")]
const LVL_NAMES := ["Лёгкий", "Средний", "Сложный"]
const SKY := "res://assets/arenas/panorama/Panorama_Sky_%s-512x512.png"
const LAYOUT_NAMES := {"classic": "3 платформы", "twin": "2 платформы", "steps": "4 платформы", "flat": "без платформ"}
const ARENAS := [
	{"name": "Ясный день", "sky": "04", "layout": "classic", "tint": Color("9fc6ff")},
	{"name": "Золотой закат", "sky": "21", "layout": "twin", "tint": Color("ffb347")},
	{"name": "Розовые облака", "sky": "07", "layout": "steps", "tint": Color("f2a7d8")},
	{"name": "Фиолетовая буря", "sky": "11", "layout": "classic", "tint": Color("a98bff")},
	{"name": "Изумрудное небо", "sky": "14", "layout": "twin", "tint": Color("6fe3a6")},
	{"name": "Полночь", "sky": "15", "layout": "flat", "tint": Color("8fa3d9")},
	{"name": "Алый горизонт", "sky": "19", "layout": "steps", "tint": Color("ff7a6b")},
	{"name": "Тихое утро", "sky": "08", "layout": "classic", "tint": Color("cfe3f0")},
]
const PORT := 24545
const MENU_BG := "res://assets/ui/title_bg.png"
const BINDS := [
	{"l": [KEY_A], "r": [KEY_D], "u": [KEY_W], "d": [KEY_S], "j": [KEY_SPACE], "atk": [KEY_F], "spc": [KEY_G], "sh": [KEY_H]},
	{"l": [KEY_LEFT], "r": [KEY_RIGHT], "u": [KEY_UP], "d": [KEY_DOWN], "j": [KEY_KP_0, KEY_CTRL],
		"atk": [KEY_KP_1, KEY_COMMA], "spc": [KEY_KP_2, KEY_PERIOD], "sh": [KEY_KP_3, KEY_SLASH]},
]

var state := "title"
var sel := [0, 1]
var vs_cpu := true
var stocks := 3
var lvl := 1
var fighters: Array = []
var previews: Array = []
var projs: Array = []
var parts: Array = []
var shake := 0.0
var cam_pos := Vector2(640, 380)
var cam_z := 1.0
var countdown := 0
var winner = null
var over_t := 0
var frame := 0
var font: Font
var font_head: Font
var ui := {}
var panel_sb: StyleBoxTexture
const UI_NAMES := ["btn_normal", "btn_selected", "btn_pressed", "panel", "toggle_off", "toggle_on", "slider_empty",
	"knob", "arrow_left", "arrow_right", "tag_p1", "tag_p2", "banner_left", "banner_right", "bar_empty_p1", "bar_fill_p1",
	"bar_empty_p2", "bar_fill_p2", "vs", "hex_normal", "hex_p1", "hex_p2"]
var arena := 0
var arena_tex := {}
var toast := ""
var toast_t := 0
var stick_latch := {}
var sounds := {}
var players: Array = []
var next_player := 0
var autotest := false
var textures := {}
var vfx := {}
var _cam_xf := Transform2D.IDENTITY
var cam_prev := Vector2(640, 380)
var cam_z_prev := 1.0
const VFX_NAMES := ["spark", "ring", "spike", "line", "circle", "slash", "swirl", "dust", "burst"]
var menu_bg: CanvasTexture
var portraits: Array = []
var ui_btns: Array = []
var ui_sel := 0
var settings := {"volume": 80, "fullscreen": false, "shake": true, "rumble": true, "tap_jump": false}
var show_controls := false
var net_mode := ""  # "", "host", "client"
var my_slot := 0
var match_no := 0
var remote_input := {}
var net_events: Array = []
var lobby_status := ""
var host_ips: Array = []
var ip_edit: LineEdit
var net_test := false
# режим разработчика (F1) и тренировка
const DUMMY_MODES := [["stand", "Стоит"], ["jump", "Прыгает"], ["dodge", "Уклоняется"], ["attack", "Бьёт"], ["cpu", "CPU"]]
var dev := false
var dev_cubes := false
var dev_slow := false
var dev_freeze := false
var dev_step := false
var training := false
var dummy_mode := 0
var train_pct := 0


func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Segoe UI", "Arial", "Noto Sans"])
	sf.font_weight = 800
	font = sf
	if ResourceLoader.exists("res://assets/fonts/Oswald-SemiBold.ttf"):
		font = load("res://assets/fonts/Oswald-SemiBold.ttf")
	font_head = load("res://assets/fonts/RussoOne-Regular.ttf") if ResourceLoader.exists("res://assets/fonts/RussoOne-Regular.ttf") else font
	for n in UI_NAMES:
		ui[n] = load("res://assets/ui/%s.png" % n)
	panel_sb = StyleBoxTexture.new()
	panel_sb.texture = ui.panel
	panel_sb.set_texture_margin_all(110)
	var err := Fighter.load_chars()
	if err != "":
		print("ОШИБКА ДАННЫХ: ", err)
	_load_char_textures()
	for set_name in ["selina", "crimson"]:
		for n in VFX_NAMES:
			vfx[set_name + "/" + n] = load("res://assets/vfx/%s/%s.png" % [set_name, n])
	Input.joy_connection_changed.connect(_on_joy_connection)
	set_arena(0)
	_build_sounds()
	_make_previews()
	menu_bg = CanvasTexture.new()
	menu_bg.diffuse_texture = load(MENU_BG)
	menu_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # пиксель-арт
	for c in Fighter.CHARS:
		var pf = Fighter.new(self, 0, c, false, 1)
		pf.on_ground = true
		pf.inv = 0
		portraits.append(pf)
	_load_settings()

	var layer := CanvasLayer.new()
	add_child(layer)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "IP хоста"
	ip_edit.add_theme_font_size_override("font_size", 22)
	ip_edit.add_theme_font_override("font", font)
	var le_sb := StyleBoxFlat.new()
	le_sb.bg_color = Color(0.06, 0.03, 0.06, 0.92)
	le_sb.border_color = Color(0.75, 0.72, 0.8)
	le_sb.set_border_width_all(2)
	le_sb.content_margin_left = 14
	ip_edit.add_theme_stylebox_override("normal", le_sb)
	var le_focus: StyleBoxFlat = le_sb.duplicate()
	le_focus.border_color = Color("e0245e")
	ip_edit.add_theme_stylebox_override("focus", le_focus)
	ip_edit.size = Vector2(380, 56)
	ip_edit.visible = false
	ip_edit.text_submitted.connect(func(t): net_join(t))
	layer.add_child(ip_edit)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(func(_id): _net_lost("Соперник отключился"))
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(func(): _net_lost("Хост отключился"))

	# сетевой автотест: -- --net-host   и   -- --net-join=127.0.0.1
	var args := OS.get_cmdline_user_args()
	if "--net-host" in args:
		net_test = true
		autotest = true
		net_host()
	for arg in args:
		if arg.begins_with("--screen="):
			_go(arg.get_slice("=", 1))
			show_controls = "--controls" in args
		if arg.begins_with("--net-join="):
			net_test = true
			autotest = true
			net_join(arg.get_slice("=", 1))
	if "--autotest" in OS.get_cmdline_user_args():
		autotest = true
		vs_cpu = true
		training = "--training" in OS.get_cmdline_user_args()
		dev_cubes = "--cubes" in OS.get_cmdline_user_args()
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--arena="):
				set_arena(int(arg.get_slice("=", 1)))
		start_match()
		fighters[0].cpu = true


func _load_char_textures() -> void:
	for c in Fighter.CHARS:
		if c.has("sprite"):
			for an in c.sprite.anims.values():
				if textures.has(an[0]) or not ResourceLoader.exists(an[0]):
					continue
				# пиксель-арт без размытия, остальная графика сглаженная
				var ct := CanvasTexture.new()
				ct.diffuse_texture = load(an[0])
				ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if c.sprite.get("smooth", false) else CanvasItem.TEXTURE_FILTER_NEAREST
				textures[an[0]] = ct
		if c.has("portrait") and not textures.has(c.portrait[0]):
			textures[c.portrait[0]] = load(c.portrait[0])


## Перечитать data/chars/*.cfg — новые цифры сразу действуют на арене.
func reload_data() -> void:
	var err := Fighter.load_chars()
	_load_char_textures()
	toast = "Ошибка: " + err if err != "" else "Данные бойцов перечитаны"
	toast_t = 300 if err != "" else 120
	if autotest:
		print(toast)
	sfx("block" if err != "" else "tick")


# ---------------- цикл ----------------

func _physics_process(_d: float) -> void:
	var dev_ok := net_mode == "" and state == "fight"
	Engine.time_scale = 0.25 if dev_slow and dev_ok else 1.0
	if (dev or training) and net_mode == "" and Engine.get_physics_frames() % 30 == 0 and Fighter.data_changed():
		reload_data()
	if dev_freeze and dev_ok and not dev_step:
		# стоп-кадр: игра стоит, отрисовка без дрожания
		for f in fighters:
			f.prev_pos = f.pos
		cam_prev = cam_pos
		cam_z_prev = cam_z
		return
	dev_step = false
	frame += 1
	# запоминаем состояние до тика: отрисовка плавно идёт между прошлым и текущим тиком
	for f in fighters:
		f.prev_pos = f.pos
	cam_prev = cam_pos
	cam_z_prev = cam_z
	match state:
		"menu":
			for p in previews:
				if p:
					p.anim += 1
		"fight":
			if net_mode == "client":
				_client_step()
			else:
				tick()
		"over":
			if net_mode == "client":
				_client_step()
			else:
				over_t += 1
				for f in fighters:
					f.update({})
				update_camera()
	if net_mode == "host" and (state == "fight" or state == "over") and not multiplayer.get_peers().is_empty():
		net_state.rpc(_make_snap())
	net_events.clear()
	update_parts()
	if toast_t > 0:
		toast_t -= 1
	shake = maxf(0.0, shake * 0.88 - 0.1)
	if autotest:
		_autotest_step()


func _process(_d: float) -> void:
	queue_redraw()


func tick() -> void:
	if countdown > 0:
		countdown -= 1
		if countdown % 60 == 0:
			sfx("go" if countdown == 0 else "count")
	for f in fighters:
		var inp := {}
		if countdown <= 0:
			if training and f.id == 1:
				inp = f.dummy_input(other(f), DUMMY_MODES[dummy_mode][0], lvl)
			elif f.cpu:
				inp = f.ai_input(other(f), lvl)
			elif net_mode == "host":
				inp = read_local() if f.id == 0 else remote_input
			else:
				inp = read_input(f.id)
		f.update(inp)

	# удары
	for a in fighters:
		if a.dead or not a.is_active():
			continue
		var b: Rect2 = a.box_of(a.atk.m)
		for d in fighters:
			if d == a or d.dead or a.atk.hit.has(d):
				continue
			if b.intersects(d.hurtbox()):
				a.atk.hit.append(d)
				var dir := signf(d.pos.x - a.pos.x)
				if dir == 0:
					dir = a.facing
				do_hit(a, d, a.atk.m, a.ch.power * (1.0 + 0.6 * a.atk.c / Fighter.CHARGE_MAX), dir, true)

	# снаряды
	for pj in projs:
		pj.x += pj.vx
		pj.life -= 1
		pj.spin += 0.3
		if Fighter.MAIN.has_point(Vector2(pj.x, pj.y)):
			pj.life = 0
			burst(Vector2(pj.x, pj.y), pj.col, 6, 3.0)
			continue
		for d in fighters:
			if d != pj.owner and not d.dead and d.hurtbox().grow(pj.r).has_point(Vector2(pj.x, pj.y)):
				if do_hit(pj.owner, d, pj.m, pj.owner.ch.power, signf(pj.vx), false):
					pj.life = 0
					break
	for i in projs.size():
		for j in range(i + 1, projs.size()):
			var p: Dictionary = projs[i]
			var q: Dictionary = projs[j]
			if p.owner != q.owner and p.life > 0 and q.life > 0 and Vector2(p.x, p.y).distance_to(Vector2(q.x, q.y)) < p.r + q.r:
				p.life = 0
				q.life = 0
				burst(Vector2(p.x, p.y), Color.WHITE, 10, 4.0)
				sfx("block")
	projs = projs.filter(func(x): return x.life > 0)

	# вылет за границы
	for f in fighters:
		if not f.dead and (f.pos.x < Fighter.BLAST_L or f.pos.x > Fighter.BLAST_R or f.pos.y > Fighter.BLAST_B or f.pos.y < Fighter.BLAST_T):
			ko(f)
	update_camera()


func other(f):
	for g in fighters:
		if g != f:
			return g
	return null


func read_input(i: int) -> Dictionary:
	var o := {}
	var b: Dictionary = BINDS[i]
	for k in b:
		var on := false
		for key in b[k]:
			if Input.is_physical_key_pressed(key):
				on = true
		o[k] = on
	var pads := Input.get_connected_joypads()
	if i < pads.size():
		var dev: int = pads[i]
		var ax := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		var ay := Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
		var bt := func(n): return Input.is_joy_button_pressed(dev, n)
		o.l = o.l or ax < -0.4 or bt.call(JOY_BUTTON_DPAD_LEFT)
		o.r = o.r or ax > 0.4 or bt.call(JOY_BUTTON_DPAD_RIGHT)
		o.u = o.u or ay < -0.6 or bt.call(JOY_BUTTON_DPAD_UP)
		o.j = o.j or bt.call(JOY_BUTTON_A) or bt.call(JOY_BUTTON_Y)
		o.d = o.d or ay > 0.6 or bt.call(JOY_BUTTON_DPAD_DOWN)
		o.atk = o.atk or bt.call(JOY_BUTTON_X)
		o.spc = o.spc or bt.call(JOY_BUTTON_B)
		o.sh = o.sh or bt.call(JOY_BUTTON_LEFT_SHOULDER) or bt.call(JOY_BUTTON_RIGHT_SHOULDER) \
			or Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.5 or Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	if settings.tap_jump:
		o.j = o.j or o.u
	return o


## Оба набора клавиш + первый геймпад — для онлайна, где на компьютере один игрок.
func read_local() -> Dictionary:
	var a := read_input(0)
	var b := read_input(1)
	for k in b:
		a[k] = a.get(k, false) or b[k]
	return a


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		for i in ui_btns.size():
			if ui_btns[i].r.has_point(e.position):
				ui_sel = i
	elif e is InputEventMouseButton:
		if e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			for i in ui_btns.size():
				if ui_btns[i].r.has_point(e.position):
					ui_sel = i
					_ui_activate(ui_btns[i].id, 1)
					return
	elif e is InputEventKey:
		if e.pressed and not e.echo:
			_on_key(e.physical_keycode)
	elif e is InputEventJoypadButton:
		if e.pressed:
			_on_pad_button(pad_player(e.device), e.button_index)
	elif e is InputEventJoypadMotion and (e.axis == JOY_AXIS_LEFT_X or e.axis == JOY_AXIS_LEFT_Y):
		# в меню стик работает как крестовина: одно срабатывание на наклон
		var dir := 0
		if e.axis_value > 0.6:
			dir = 1
		elif e.axis_value < -0.6:
			dir = -1
		var key: int = e.device * 2 + int(e.axis == JOY_AXIS_LEFT_Y)
		if dir != stick_latch.get(key, 0):
			stick_latch[key] = dir
			if dir != 0:
				var b := JOY_BUTTON_DPAD_RIGHT if dir > 0 else JOY_BUTTON_DPAD_LEFT
				if e.axis == JOY_AXIS_LEFT_Y:
					b = JOY_BUTTON_DPAD_DOWN if dir > 0 else JOY_BUTTON_DPAD_UP
				_on_pad_button(pad_player(e.device), b)


## Геймпад N управляет игроком N (первый подключённый — игрок 1).
func pad_player(device: int) -> int:
	return clampi(Input.get_connected_joypads().find(device), 0, 1)


func _on_key(k: int) -> void:
	if _dev_key(k):
		return
	match k:
		KEY_A:
			_action("left", 0)
		KEY_D:
			_action("right", 0)
		KEY_LEFT:
			_action("left", 1)
		KEY_RIGHT:
			_action("right", 1)
		KEY_W:
			_action("up", 0)
		KEY_UP:
			_action("up", 1)
		KEY_S:
			_action("down", 0)
		KEY_DOWN:
			_action("down", 1)
		KEY_Q:
			_action("prev", 0)
		KEY_E:
			_action("next", 0)
		KEY_C:
			_action("opt1", 0)
		KEY_V:
			_action("opt2", 0)
		KEY_ENTER, KEY_KP_ENTER:
			_action("ok", 0)
		KEY_ESCAPE, KEY_BACKSPACE:
			_action("back", 0)
		KEY_R:
			_action("opt1", 0)


## Клавиши режима разработчика (F1–F6) и тренировки (T R - = 0). true — клавиша обработана.
func _dev_key(k: int) -> bool:
	var fight := state == "fight" and net_mode == ""
	match k:
		KEY_F1:
			dev = not dev
		KEY_F2:
			dev_cubes = not dev_cubes
		KEY_F3:
			if not fight:
				return false
			dev_slow = not dev_slow
		KEY_F4:
			if not fight:
				return false
			dev_freeze = not dev_freeze
		KEY_F5:
			if not fight:
				return false
			dev_freeze = true
			dev_step = true
		KEY_F6:
			if net_mode != "":
				return false
			reload_data()
			return true
		_:
			if not (training and fight):
				return false
			match k:
				KEY_T:
					dummy_mode = (dummy_mode + 1) % DUMMY_MODES.size()
				KEY_R:
					for f in fighters:
						f.spawn(f.start_pos())
						f.inv = 0
					projs.clear()
				KEY_MINUS, KEY_KP_SUBTRACT:
					_set_train_pct(train_pct - 10)
				KEY_EQUAL, KEY_KP_ADD:
					_set_train_pct(train_pct + 10)
				KEY_0:
					_set_train_pct(0)
				_:
					return false
	sfx("tick")
	return true


func _set_train_pct(p: int) -> void:
	train_pct = clampi(p, 0, 300)
	var d = fighters[1]
	d.base_pct = train_pct
	if not d.dead:
		d.percent = train_pct


func _on_pad_button(pl: int, b: int) -> void:
	# в бою кнопки заняты атаками — меню открывает только Start
	if state == "fight" and b != JOY_BUTTON_START:
		return
	match b:
		JOY_BUTTON_DPAD_LEFT:
			_action("left", pl)
		JOY_BUTTON_DPAD_RIGHT:
			_action("right", pl)
		JOY_BUTTON_DPAD_UP:
			_action("up", pl)
		JOY_BUTTON_DPAD_DOWN:
			_action("down", pl)
		JOY_BUTTON_LEFT_SHOULDER:
			_action("prev", pl)
		JOY_BUTTON_RIGHT_SHOULDER:
			_action("next", pl)
		JOY_BUTTON_Y:
			_action("opt1", pl)
		JOY_BUTTON_X:
			_action("opt2", pl)
		JOY_BUTTON_A:
			_action("ok", pl)
		JOY_BUTTON_START:
			_action("back" if state == "fight" or state == "pause" else "ok", pl)
		JOY_BUTTON_B, JOY_BUTTON_BACK:
			_action("back", pl)


func _action(a: String, pl: int) -> void:
	match state:
		"title", "lobby", "pause", "settings":
			if state == "settings" and show_controls:
				if a == "back" or a == "ok":
					show_controls = false
				return
			match a:
				"up":
					ui_sel = posmod(ui_sel - 1, maxi(1, ui_btns.size()))
					sfx("tick")
				"down":
					ui_sel = posmod(ui_sel + 1, maxi(1, ui_btns.size()))
					sfx("tick")
				"left", "right":
					if state == "settings" and ui_sel < ui_btns.size():
						_ui_activate(ui_btns[ui_sel].id, -1 if a == "left" else 1)
				"ok":
					if ui_sel < ui_btns.size():
						_ui_activate(ui_btns[ui_sel].id, 1)
				"back":
					_ui_activate("resume" if state == "pause" else "back", 1)
		"menu":
			var online := net_mode != ""
			var can_edit := net_mode != "client"
			var slot: int = my_slot if online else pl
			var total: int = Fighter.CHARS.size() + 1
			match a:
				"left":
					sel[slot] = posmod(sel[slot] - 1, total)
				"right":
					sel[slot] = posmod(sel[slot] + 1, total)
				"prev":
					if can_edit:
						set_arena(posmod(arena - 1, ARENAS.size()))
				"next":
					if can_edit:
						set_arena(posmod(arena + 1, ARENAS.size()))
				"up":
					if can_edit:
						stocks = mini(9, stocks + 1)
				"down":
					if can_edit:
						stocks = maxi(1, stocks - 1)
				"opt1":
					if not online:
						vs_cpu = not vs_cpu
				"opt2":
					if not online:
						lvl = (lvl + 1) % 3
				"ok":
					_start_pressed()
					return
				"back":
					_net_close()
					_go("title")
					return
				_:
					return
			sfx("tick")
			_make_previews()
			if online:
				net_sel.rpc(my_slot, sel[my_slot])
				if net_mode == "host":
					net_lobby.rpc(arena, stocks)
		"fight":
			if a == "back" and net_mode == "":
				_go("pause")
		"over":
			if over_t < 40 or net_mode == "client":
				return
			if a == "ok" or a == "back":
				if net_mode == "host":
					net_to_menu.rpc()
				else:
					_go("menu")
			elif a == "opt1":
				_start_pressed()


func _go(st: String) -> void:
	state = st
	ui_sel = 0
	show_controls = false


func _ui_activate(id: String, dir: int) -> void:
	match id:
		"offline", "training":
			training = id == "training"
			_go("menu")
			_make_previews()
		"online":
			training = false
			lobby_status = ""
			_go("lobby")
		"settings":
			_go("settings")
		"exit":
			get_tree().quit()
		"host":
			net_host()
		"join":
			net_join(ip_edit.text)
		"back":
			if state == "settings":
				_save_settings()
			_net_close()
			_go("title")
		"resume":
			state = "fight"
		"tomenu":
			_go("menu")
		"controls":
			show_controls = true
		"set_volume":
			settings.volume = clampi(settings.volume + 10 * dir, 0, 100)
			_apply_settings()
		"set_fullscreen":
			settings.fullscreen = not settings.fullscreen
			_apply_settings(true)
		"set_shake":
			settings.shake = not settings.shake
		"set_tapjump":
			settings.tap_jump = not settings.tap_jump
		"set_rumble":
			settings.rumble = not settings.rumble
			_rumble_local(0.4, 0.4, 0.2)
	sfx("tick")


func _start_pressed() -> void:
	match net_mode:
		"client":
			return
		"host":
			if multiplayer.get_peers().is_empty():
				return
			var n: int = Fighter.CHARS.size()
			var picks := []
			for x in sel:
				picks.append(randi() % n if x >= n else x)
			net_start.rpc(picks, arena, stocks, match_no + 1)
		_:
			start_match()


# ---------------- настройки ----------------

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		for k in settings:
			settings[k] = cf.get_value("main", k, settings[k])
	_apply_settings(settings.fullscreen)


func _save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("main", k, settings[k])
	cf.save("user://settings.cfg")


func _apply_settings(window := false) -> void:
	AudioServer.set_bus_mute(0, settings.volume <= 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(settings.volume, 1) / 100.0))
	if window:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


# ---------------- сеть ----------------
# Хост считает всю игру, клиент шлёт ему свои кнопки и получает снимок состояния каждый кадр.

func net_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 1) != OK:
		lobby_status = "Не удалось создать игру: порт %d занят" % PORT
		return
	multiplayer.multiplayer_peer = peer
	net_mode = "host"
	my_slot = 0
	host_ips = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			host_ips.append(a)
	lobby_status = "Ждём соперника..."


func net_join(ip: String) -> void:
	ip = ip.strip_edges()
	if ip == "":
		lobby_status = "Введите IP хоста"
		return
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, PORT) != OK:
		lobby_status = "Неверный адрес"
		return
	multiplayer.multiplayer_peer = peer
	net_mode = "client"
	my_slot = 1
	lobby_status = "Подключение к %s..." % ip


func _net_close() -> void:
	if net_mode == "":
		return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	net_mode = ""
	remote_input = {}


func _net_lost(msg: String) -> void:
	if net_mode == "":
		return
	_net_close()
	_go("title")
	toast = msg
	toast_t = 240
	if net_test:
		print("NET LOST: ", msg)
		get_tree().quit()


func _on_connect_failed() -> void:
	_net_close()
	lobby_status = "Не удалось подключиться"
	if net_test:
		print("NET CONNECT FAILED")
		get_tree().quit()


func _on_peer_connected(_id: int) -> void:
	if net_mode != "host":
		return
	vs_cpu = false
	_go("menu")
	_make_previews()
	net_sel.rpc(0, sel[0])
	net_lobby.rpc(arena, stocks)
	if net_test:
		await get_tree().create_timer(0.5).timeout
		_start_pressed()


func _on_connected() -> void:
	vs_cpu = false
	_go("menu")
	_make_previews()
	net_sel.rpc(1, sel[1])


func _client_step() -> void:
	var inp: Dictionary
	if net_test and fighters.size() == 2:
		inp = fighters[1].ai_input(fighters[0], lvl)
	else:
		inp = read_local()
	net_input.rpc_id(1, inp)
	if state == "over":
		over_t += 1
	update_camera()


@rpc("any_peer", "reliable")
func net_sel(slot: int, c: int) -> void:
	sel[slot] = c
	_make_previews()


@rpc("authority", "reliable")
func net_lobby(a: int, st: int) -> void:
	set_arena(a)
	stocks = st


@rpc("authority", "reliable", "call_local")
func net_start(picks: Array, a: int, st: int, mn: int) -> void:
	sel = picks.duplicate()
	set_arena(a)
	stocks = st
	match_no = mn
	vs_cpu = false
	start_match()
	if net_test and net_mode == "host":
		fighters[0].cpu = true


@rpc("authority", "reliable", "call_local")
func net_to_menu() -> void:
	_go("menu")
	_make_previews()


@rpc("any_peer", "unreliable_ordered")
func net_input(inp: Dictionary) -> void:
	if net_mode == "host":
		remote_input = inp


func _make_snap() -> Array:
	var fs := []
	for f in fighters:
		fs.append([f.pos, f.vel, f.facing, f.on_ground, f.percent, f.stocks, f.dead, f.inv, f.hitstun, f.stun,
			f.dodge_t, f.clinging, f.helpless, f.anim, f.pct_shake, f.atk.get("k", ""), f.atk.get("t", 0), f.kos, f.dmg_dealt, f.atk.get("c", 0)])
	var ps := []
	for p in projs:
		ps.append([p.x, p.y, p.vx, p.col, p.r, p.spin, p.owner.id])
	return [fs, ps, countdown, state, winner.id if winner else -1, net_events.duplicate(), shake, match_no]


@rpc("authority", "unreliable_ordered")
func net_state(sn: Array) -> void:
	if net_mode != "client" or fighters.size() != 2 or sn[7] != match_no:
		return
	if state != "fight" and state != "over":
		return
	for i in 2:
		var f = fighters[i]
		var d: Array = sn[0][i]
		f.pos = d[0]
		f.vel = d[1]
		f.facing = d[2]
		f.on_ground = d[3]
		f.percent = d[4]
		f.stocks = d[5]
		f.dead = d[6]
		f.inv = d[7]
		f.hitstun = d[8]
		f.stun = d[9]
		f.dodge_t = d[10]
		f.clinging = d[11]
		f.helpless = d[12]
		f.anim = d[13]
		f.pct_shake = d[14]
		f.kos = d[17]
		f.dmg_dealt = d[18]
		var k: String = d[15]
		f.atk = {} if k == "" else {"k": k, "m": f.ch.moves[k], "t": d[16], "c": d[19], "hit": [], "air": false}
	projs = []
	for p in sn[1]:
		projs.append({"x": p[0], "y": p[1], "vx": p[2], "col": p[3], "r": p[4], "spin": p[5], "owner": fighters[p[6]], "life": 1})
	countdown = sn[2]
	shake = sn[6]
	if sn[3] == "over" and state != "over":
		state = "over"
		over_t = 0
		winner = fighters[sn[4]] if sn[4] >= 0 else null
	for e in sn[5]:
		callv(e[0], e[1])


func set_arena(i: int) -> void:
	arena = i
	Fighter.PLATS = Fighter.LAYOUTS[ARENAS[i].layout]
	if not arena_tex.has(i):
		# панорама 360° — повторяем по горизонтали, чтобы фон бесшовно прокручивался
		var ct := CanvasTexture.new()
		ct.diffuse_texture = load(SKY % ARENAS[i].sky)
		ct.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		arena_tex[i] = ct


func _on_joy_connection(device: int, connected: bool) -> void:
	if frame < 60 or Input.get_joy_name(device) == "":
		return  # геймпады, подключённые до запуска, не объявляем
	toast = ("Геймпад подключён: " if connected else "Геймпад отключён: ") + Input.get_joy_name(device)
	toast_t = 180


func rumble(pl: int, weak: float, strong: float, dur: float) -> void:
	if net_mode == "host" and pl == 1:
		net_events.append(["_rumble_local", [weak, strong, dur]])
	elif net_mode != "":
		if pl == my_slot:
			_rumble_local(weak, strong, dur)
	elif pl < fighters.size() and not fighters[pl].cpu:
		var pads := Input.get_connected_joypads()
		if pl < pads.size() and settings.rumble:
			Input.start_joy_vibration(pads[pl], weak, strong, dur)


func _rumble_local(weak: float, strong: float, dur: float) -> void:
	var pads := Input.get_connected_joypads()
	if pads.size() > 0 and settings.rumble:
		Input.start_joy_vibration(pads[0], weak, strong, dur)


func start_match() -> void:
	set_arena(arena)
	var n: int = Fighter.CHARS.size()
	var picks := []
	for x in sel:
		picks.append(randi() % n if x >= n else x)
	fighters = [
		Fighter.new(self, 0, Fighter.CHARS[picks[0]], false, stocks),
		Fighter.new(self, 1, Fighter.CHARS[picks[1]], vs_cpu and net_mode == "", stocks),
	]
	projs.clear()
	parts.clear()
	countdown = 200
	dev_freeze = false
	if training:
		countdown = 0
		dev = true
		fighters[1].cpu = true
		for f in fighters:
			f.respawn_inv = 20
			f.inv = 0
		_set_train_pct(train_pct)
	winner = null
	over_t = 0
	state = "fight"
	cam_pos = Vector2(640, 380)
	cam_z = 1.0


func _make_previews() -> void:
	previews = []
	for i in 2:
		if sel[i] >= Fighter.CHARS.size():
			previews.append(null)
			continue
		var p = Fighter.new(self, i, Fighter.CHARS[sel[i]], false, 1)
		p.on_ground = true
		p.inv = 0
		p.facing = 1 if i == 0 else -1
		previews.append(p)


# ---------------- бой ----------------

func do_hit(att, tgt, m: Dictionary, power: float, dir: float, freeze_att: bool) -> bool:
	if tgt.inv > 0 or tgt.dead:
		return false
	var dmg := int(round(m.dmg * power))
	var hp: Vector2 = tgt.hurtbox().get_center()
	if tgt.dodging():
		return false
	tgt.percent = mini(999, tgt.percent + dmg)
	tgt.pct_shake = 12
	var kb: float = (m.kb + tgt.percent * m.sc) * power / tgt.ch.weight
	var a := deg_to_rad(m.ang)
	tgt.vel = Vector2(cos(a) * kb * dir, -sin(a) * kb)
	if tgt.on_ground and tgt.vel.y > 0:
		tgt.vel.y *= -0.6
	tgt.on_ground = false
	tgt.atk = {}
	tgt.helpless = false
	tgt.ff = false
	tgt.dodge_t = 0
	tgt.dash_t = 0
	# по тебе попали — уклонение снова доступно; попал сам — можно догнать уклонением
	tgt.air_dodge_used = false
	tgt.dodge_cd = 0
	att.air_dodge_used = false
	tgt.hitstun = mini(80, int(kb * 1.3))
	var fr := mini(12, 3 + dmg / 2)
	tgt.freeze = fr
	if freeze_att:
		att.freeze = fr
	shake = maxf(shake, minf(18.0, kb * 0.35))
	burst(hp, att.ch.col, 8 + dmg, 3.0 + kb * 0.15)
	burst(hp, Color.WHITE, 5, 2.0 + kb * 0.1)
	ring(hp, Color.WHITE, 20.0 + kb * 1.5)
	fx(att.fx_set() + "/spark", hp, 60.0 + kb * 2.5)
	if kb > 22:
		fx(att.fx_set() + "/slash", hp, 120.0 + kb * 2.0, Color(1, 1, 1, 0.9), 14)
	sfx("smash" if kb > 22 else "hit")
	rumble(tgt.id, 0.4, minf(1.0, kb / 30.0), 0.12 + kb * 0.004)
	if freeze_att:
		rumble(att.id, 0.25, 0.0, 0.06)
	att.dmg_dealt += dmg
	tgt.last_hit = att.id
	return true


func ko(f) -> void:
	var vs := get_viewport_rect().size
	var half := vs / 2 / cam_z
	var p := Vector2(clampf(f.pos.x, cam_pos.x - half.x + 30, cam_pos.x + half.x - 30),
		clampf(f.pos.y, cam_pos.y - half.y + 30, cam_pos.y + half.y - 30))
	if not training:
		f.stocks -= 1  # в тренировке жизни бесконечные
	f.dead = true
	f.atk = {}
	f.respawn = 30 if training else 70
	if f.last_hit >= 0:
		fighters[f.last_hit].kos += 1
	burst(p, f.ch.col, 40, 12.0)
	burst(p, Color.WHITE, 20, 8.0)
	ring(p, f.ch.col, 220.0)
	var vs_set: String = fighters[f.last_hit].fx_set() if f.last_hit >= 0 else f.fx_set()
	fx(vs_set + "/burst", p, 320.0, Color.WHITE, 30)
	fx(vs_set + "/circle", p, 260.0, Color.WHITE, 24)
	ring(p, Color.WHITE, 140.0)
	shake = 28.0
	sfx("ko")
	rumble(f.id, 1.0, 1.0, 0.5)
	var alive := fighters.filter(func(x): return x.stocks > 0)
	if alive.size() <= 1:
		winner = alive[0] if alive.size() == 1 else null
		state = "over"
		over_t = 0


func update_camera() -> void:
	var vs := get_viewport_rect().size
	var m := Fighter.MAIN
	var mn := Vector2(m.position.x + 100, 250)
	var mx := Vector2(m.end.x - 100, m.position.y + 40)
	for f in fighters:
		if f.dead:
			continue
		var p := Vector2(clampf(f.pos.x, Fighter.BLAST_L + 150, Fighter.BLAST_R - 150), clampf(f.pos.y, Fighter.BLAST_T + 150, Fighter.BLAST_B - 150))
		mn = mn.min(p - Vector2(80, 140))
		mx = mx.max(p + Vector2(80, 40))
	var tz := clampf(minf(vs.x / (mx.x - mn.x + 200), vs.y / (mx.y - mn.y + 200)), 0.45, 1.25)
	cam_z = lerpf(cam_z, tz, 0.06)
	cam_pos = cam_pos.lerp((mn + mx) / 2, 0.08)


# ---------------- частицы ----------------

func burst(p: Vector2, col: Color, n: int, spd: float) -> void:
	if net_mode == "host":
		net_events.append(["burst", [p, col, n, spd]])
	for i in n:
		var a := randf() * TAU
		var s := randf_range(0.3, 1.0) * spd
		parts.append({"k": "dot", "x": p.x, "y": p.y, "vx": cos(a) * s, "vy": sin(a) * s, "life": 30, "max": 30, "col": col, "size": randf_range(2.0, 5.0)})


func ring(p: Vector2, col: Color, r: float) -> void:
	if net_mode == "host":
		net_events.append(["ring", [p, col, r]])
	parts.append({"k": "ring", "x": p.x, "y": p.y, "vx": 0.0, "vy": 0.0, "life": 18, "max": 18, "col": col, "size": r})


## Спрайтовый эффект из assets/vfx: вспыхивает, растёт и гаснет.
func fx(name: String, p: Vector2, size: float, col := Color.WHITE, life := 18) -> void:
	if net_mode == "host":
		net_events.append(["fx", [name, p, size, col, life]])
	parts.append({"k": "spr", "tex": name, "x": p.x, "y": p.y, "vx": 0.0, "vy": 0.0, "life": life, "max": life,
		"col": col, "size": size, "rot": randf_range(-0.4, 0.4)})


func puff(p: Vector2, n: int) -> void:
	if net_mode == "host":
		net_events.append(["puff", [p, n]])
	for i in n:
		parts.append({"k": "puff", "x": p.x + randf_range(-14, 14), "y": p.y - 3, "vx": randf_range(-1.6, 1.6), "vy": randf_range(-1.2, -0.2),
			"life": 22, "max": 22, "col": Color(1, 1, 1, 0.5), "size": randf_range(5.0, 9.0)})


func trail(f) -> void:
	_trail(f.pos, f.ch.col)


func _trail(p: Vector2, col: Color) -> void:
	if net_mode == "host":
		net_events.append(["_trail", [p, col]])
	parts.append({"k": "puff", "x": p.x, "y": p.y - 40, "vx": 0.0, "vy": 0.0, "life": 14, "max": 14,
		"col": Color(col, 0.5), "size": 20.0})


func update_parts() -> void:
	for p in parts:
		p.x += p.vx
		p.y += p.vy
		p.vx *= 0.92
		p.vy *= 0.92
		if p.k == "dot":
			p.vy += 0.15
		p.life -= 1
	parts = parts.filter(func(x): return x.life > 0)


# ---------------- звук ----------------

func _build_sounds() -> void:
	sounds = {
		"jump": _tone(260, 520, 0.12, "sin", 0.35),
		"jump2": _tone(380, 760, 0.14, "sin", 0.35),
		"swing": _tone(900, 300, 0.08, "sin", 0.15, 0.7),
		"hit": _tone(300, 90, 0.14, "sq", 0.35, 0.5),
		"smash": _tone(200, 40, 0.35, "sq", 0.5, 0.6),
		"block": _tone(900, 700, 0.08, "sq", 0.2),
		"break": _tone(600, 80, 0.5, "saw", 0.4, 0.3),
		"ko": _tone(160, 30, 0.9, "saw", 0.55, 0.6),
		"boom": _tone(120, 40, 0.3, "sin", 0.6, 0.4),
		"dodge": _tone(500, 1400, 0.12, "sin", 0.18, 0.5),
		"shoot": _tone(700, 1200, 0.1, "sq", 0.18),
		"tick": _tone(800, 800, 0.05, "sq", 0.12),
		"count": _tone(440, 440, 0.18, "sq", 0.25),
		"go": _tone(880, 880, 0.4, "sq", 0.3),
	}
	for i in 10:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		players.append(pl)


func _tone(f0: float, f1: float, dur: float, wave: String, vol: float, noise := 0.0) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		ph += f0 * pow(f1 / f0, t) / rate
		var s: float
		match wave:
			"sq":
				s = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
			"saw":
				s = fmod(ph, 1.0) * 2.0 - 1.0
			_:
				s = sin(ph * TAU)
		s = lerpf(s, randf() * 2.0 - 1.0, noise)
		var env := (1.0 - t) * (1.0 - t) * minf(1.0, i / 60.0)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func sfx(name: String) -> void:
	if net_mode == "host":
		net_events.append(["sfx", [name]])
	if autotest or not sounds.has(name):
		return
	var pl: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	pl.stream = sounds[name]
	pl.pitch_scale = randf_range(0.93, 1.07)
	pl.play()


# ---------------- отрисовка ----------------

func _draw() -> void:
	var vs := get_viewport_rect().size
	ui_btns.clear()
	match state:
		"title":
			draw_title(vs)
		"settings":
			draw_cover(vs, 0.5)
			draw_settings(vs)
		"lobby":
			draw_cover(vs, 0.5)
			draw_lobby(vs)
		"menu":
			draw_bg(vs)
			draw_select(vs)
		_:
			draw_battle(vs)
	ip_edit.visible = state == "lobby" and net_mode == ""
	if not ip_edit.visible and ip_edit.has_focus():
		ip_edit.release_focus()
	draw_toast(vs)


func draw_battle(vs: Vector2) -> void:
	draw_bg(vs)
	var sh := shake if settings.shake else 0.0
	var off := Vector2(randf_range(-sh, sh), randf_range(-sh, sh)) * 0.5
	var t := Engine.get_physics_interpolation_fraction()
	var cz := lerpf(cam_z_prev, cam_z, t)
	_cam_xf = Transform2D(0, Vector2(cz, cz), 0, vs / 2 + off - cam_prev.lerp(cam_pos, t) * cz)
	draw_set_transform_matrix(_cam_xf)
	draw_stage()
	for pj in projs:
		var c := Vector2(pj.x, pj.y)
		draw_circle(c, pj.r + 6, Color(pj.col, 0.25))
		draw_circle(c, pj.r, pj.col)
		draw_circle(c + Vector2(cos(pj.spin), sin(pj.spin)) * pj.r * 0.4, pj.r * 0.35, Color.WHITE)
	for f in fighters:
		var real: Vector2 = f.pos
		if f.prev_pos.distance_to(real) < 150:  # после респауна не «пролетаем» через экран
			f.pos = f.prev_pos.lerp(real, t)
		draw_fighter(f, true)
		f.pos = real
	draw_parts()
	if dev:
		draw_dev_boxes()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_offscreen(vs)
	draw_hud(vs)
	if dev:
		draw_dev_info(vs)
	if dev or training:
		draw_dev_panel()
	if countdown > 0:
		var n := ceili(countdown / 60.0) - 1
		var s := str(n) if n > 0 else "В БОЙ!"
		var k := float(countdown % 60) / 60.0
		txt(s, Vector2(vs.x / 2, vs.y / 2 + 30), int(90 + 40 * k), Color(1, 0.9, 0.3, minf(1.0, k * 3 + 0.2)), HORIZONTAL_ALIGNMENT_CENTER, 12)
	if state == "pause":
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
		txt("ПАУЗА", Vector2(vs.x / 2, vs.y / 2 - 40), 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10)
		button(Rect2(vs.x / 2 - 170, vs.y / 2, 340, 56), "Продолжить", "resume")
		button(Rect2(vs.x / 2 - 170, vs.y / 2 + 70, 340, 56), "Выйти в меню", "tomenu")
	if state == "over":
		draw_over(vs)


# ---------------- режим разработчика ----------------

## Рамки: зелёная — хёртбокс (куда бьют), красная — хитбокс (чем бьют), жёлтая — хитбокс на замахе.
func draw_dev_boxes() -> void:
	var lw := 2.0 / cam_z
	for x in [Fighter.BLAST_L, Fighter.BLAST_R]:
		draw_line(Vector2(x, Fighter.BLAST_T), Vector2(x, Fighter.BLAST_B), Color(0.3, 0.9, 1, 0.5), lw)
	for y in [Fighter.BLAST_T, Fighter.BLAST_B]:
		draw_line(Vector2(Fighter.BLAST_L, y), Vector2(Fighter.BLAST_R, y), Color(0.3, 0.9, 1, 0.5), lw)
	for f in fighters:
		if f.dead:
			continue
		var hb: Rect2 = f.hurtbox()
		var hc := Color(0.2, 1, 0.3) if f.inv <= 0 and not f.dodging() else Color(0.6, 0.6, 1)
		draw_rect(hb, Color(hc, 0.18))
		draw_rect(hb, hc, false, lw)
		draw_circle(f.pos, 3.0 / cam_z, Color.WHITE)
		if f.atk.is_empty():
			continue
		var b: Rect2 = f.box_of(f.atk.m)
		if f.is_active():
			draw_rect(b, Color(1, 0.1, 0.1, 0.35))
			draw_rect(b, Color(1, 0.2, 0.2), false, lw)
		elif f.atk.t <= f.atk.m.s:
			draw_rect(b, Color(1, 0.9, 0.2, 0.7), false, lw)


## Над панелью каждого бойца: приём, кадр и фаза, урон и состояние.
func draw_dev_info(vs: Vector2) -> void:
	for f in fighters:
		if f.dead:
			continue
		var p := Vector2(vs.x / 2 - 155 if f.id == 0 else vs.x / 2 + 155, vs.y - 108)
		var lines := []
		if not f.atk.is_empty():
			var m: Dictionary = f.atk.m
			var t: int = f.atk.t
			var total: int = m.s + m.a + m.e
			var ph := ["разгон", Color("ffd23d")]
			if f.charging():
				ph = ["заряд %d/%d" % [f.atk.c, Fighter.CHARGE_MAX], Color("ffd23d")]
			elif t > m.s + m.a:
				ph = ["восстановление", Color("8fb4ff")]
			elif t > m.s:
				ph = ["УДАР", Color("ff4040")]
			lines.append(["%s  %d/%d  %s" % [f.atk.k, t, total, ph[0]], ph[1]])
		var st := []
		for v in [["оглушён", f.hitstun], ["замер", f.freeze], ["неуязвим", f.inv], ["уклон", f.dodge_t], ["приземл.", f.land_lag]]:
			if v[1] > 0:
				st.append("%s %d" % v)
		if f.helpless:
			st.append("беспомощен")
		lines.append(["%d%%  прыжков %d  %s" % [f.percent, f.jumps, " ".join(st)], Color.WHITE])
		for i in lines.size():
			txt(lines[i][0], p + Vector2(0, -i * 22), 17, lines[i][1], HORIZONTAL_ALIGNMENT_CENTER, 4)


func draw_dev_panel() -> void:
	var on := func(b: bool): return "вкл" if b else "выкл"
	var rows := []
	if dev:
		rows.append(["F1  режим разработчика", ""])
		rows.append(["F2  кубики вместо спрайтов", on.call(dev_cubes)])
		rows.append(["F3  замедление ×0.25", on.call(dev_slow)])
		rows.append(["F4  стоп-кадр,  F5  шаг", "СТОП" if dev_freeze else ""])
		rows.append(["F6  перечитать data/chars", ""])
	else:
		rows.append(["F1  режим разработчика", "выкл"])
	if training:
		rows.append(["T  манекен", DUMMY_MODES[dummy_mode][1]])
		rows.append(["-  =  урон манекена (0 — сброс)", "%d%%" % train_pct])
		rows.append(["R  сброс позиций", ""])
	var h := 16.0 + rows.size() * 22.0 + (26.0 if training else 0.0)
	draw_rect(Rect2(12, 12, 360, h), Color(0, 0, 0, 0.6))
	var y := 34.0
	if training:
		txt("ТРЕНИРОВКА", Vector2(24, y + 2), 20, Color("ffd23d"), HORIZONTAL_ALIGNMENT_LEFT)
		y += 26
	for r in rows:
		txt(r[0], Vector2(24, y), 15, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
		txt(r[1], Vector2(360, y), 15, Color("9fe6ff"), HORIZONTAL_ALIGNMENT_RIGHT)
		y += 22


func tag_text(f) -> String:
	if training and f.id == 1:
		return "МАНЕКЕН"
	return "CPU" if f.cpu else "P%d" % (f.id + 1)


func draw_toast(vs: Vector2) -> void:
	if toast_t <= 0:
		return
	var a := minf(1.0, toast_t / 30.0)
	rbox(Rect2(vs.x / 2 - 260, 16, 520, 40), Color(0, 0, 0, 0.7 * a), Color(1, 1, 1, 0.4 * a), 10)
	txt(toast, Vector2(vs.x / 2, 43), 18, Color(1, 1, 1, a))


func draw_bg(vs: Vector2) -> void:
	# горизонт панорамы (середина картинки) ставим на 62% высоты экрана; лёгкий параллакс от камеры
	var sc := vs.y / 560.0 * (0.95 + 0.05 * cam_z)
	var src := vs / sc
	var ox := cam_pos.x * 0.25 + frame * 0.04
	var oy := 512.0 - src.y * 0.62 + (cam_pos.y - 380.0) * 0.06
	draw_texture_rect_region(arena_tex[arena], Rect2(Vector2.ZERO, vs), Rect2(ox, oy, src.x, src.y))
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.04, 0.1, 0.22))


func draw_stage() -> void:
	var m := Fighter.MAIN
	var body := PackedVector2Array([m.position, Vector2(m.end.x, m.position.y), Vector2(m.end.x, m.end.y),
		Vector2(m.end.x - 90, m.end.y + 70), Vector2(m.get_center().x + 70, m.end.y + 150),
		Vector2(m.get_center().x - 70, m.end.y + 150), Vector2(m.position.x + 90, m.end.y + 70), Vector2(m.position.x, m.end.y)])
	var tint: Color = ARENAS[arena].tint
	draw_colored_polygon(body, tint.darkened(0.72))
	for i in 6:
		var x := m.position.x + 60 + i * 110
		draw_line(Vector2(x, m.position.y + 20), Vector2(x + 30, m.position.y + 70), tint.darkened(0.82), 4)
	draw_rect(Rect2(m.position.x, m.position.y - 4, m.size.x, 16), tint.darkened(0.25))
	draw_rect(Rect2(m.position.x, m.position.y - 4, m.size.x, 4), tint.lightened(0.5))
	for p in Fighter.PLATS:
		draw_rect(Rect2(p.position.x - 2, p.position.y - 2, p.size.x + 4, 14), Color(tint, 0.25))
		draw_rect(Rect2(p.position.x, p.position.y, p.size.x, 8), tint.darkened(0.15))
		draw_rect(Rect2(p.position.x, p.position.y, p.size.x, 3), tint.lightened(0.6))


func draw_parts() -> void:
	for p in parts:
		var k: float = float(p.life) / p.max
		var c: Color = p.col
		match p.k:
			"dot":
				draw_circle(Vector2(p.x, p.y), p.size * k, Color(c, c.a * k))
			"ring":
				draw_arc(Vector2(p.x, p.y), p.size * (1.0 - k * 0.7), 0, TAU, 40, Color(c, k), 3.0 + 5.0 * k)
			"puff":
				draw_circle(Vector2(p.x, p.y), p.size * (1.4 - k * 0.6), Color(c, c.a * k))
			"spr":
				var tex: Texture2D = vfx[p.tex]
				var sz: float = p.size * (1.25 - 0.45 * k)
				var ts := tex.get_size()
				var sc := sz / maxf(ts.x, ts.y)
				draw_set_transform_matrix(_cam_xf * Transform2D(p.rot, Vector2(sc, sc), 0, Vector2(p.x, p.y)))
				draw_texture(tex, -ts / 2, Color(c, minf(1.0, k * 1.6)))
				draw_set_transform_matrix(_cam_xf)


func ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func draw_fighter(f, tag: bool) -> void:
	if f.dead:
		return
	var c: Dictionary = f.ch
	var alpha := 1.0
	if f.inv > 0 and (f.inv / 4) % 2 == 1:
		alpha = 0.45
	if f.dodging():
		alpha = 0.35
	if f.helpless:
		alpha *= 0.7
	var col: Color = c.col
	var dk: Color = c.dark
	if f.hitstun > 0 and f.anim % 6 < 3:
		col = col.lerp(Color.WHITE, 0.6)
	if f.stun > 0:
		col = col.lerp(Color(1, 1, 0.3), 0.4 + 0.3 * sin(f.anim * 0.5))
	col.a = alpha
	dk.a = alpha
	var x: float = f.pos.x
	var y: float = f.pos.y
	var s: int = f.facing
	var bob := sin(f.anim * 0.1) * 1.5 if f.on_ground and absf(f.vel.x) < 0.5 else 0.0
	var m := Fighter.MAIN

	if tag and x > m.position.x and x < m.end.x and y <= m.position.y:
		var d := m.position.y - y
		ellipse(Vector2(x, m.position.y + 2), maxf(6.0, 22.0 - d * 0.04), 5, Color(0, 0, 0, 0.3 * alpha * clampf(1.0 - d / 400.0, 0, 1)))

	var active: bool = f.is_active()
	var sprite: bool = c.has("sprite") and not dev_cubes
	if sprite:
		_draw_sprite(f, alpha)
	else:
		# «кубик»: прямоугольник по хёртбоксу, полоска показывает, куда смотрит боец
		var hb: Rect2 = f.hurtbox()
		draw_rect(hb, col)
		draw_rect(hb, dk, false, 3.0)
		draw_rect(Rect2(x + (4 if s > 0 else -16), y - 66, 12, 6), dk)

	if active:
		var b: Rect2 = f.box_of(f.atk.m)
		var k := 0.4 if sprite else 1.0
		ellipse(b.get_center(), b.size.x / 2, b.size.y / 2, Color(c.col, 0.35 * k))
		ellipse(b.get_center(), b.size.x / 3, b.size.y / 3, Color(1, 1, 1, 0.3 * k))
	if f.charging():
		var cr: float = 30.0 + 26.0 * f.atk.c / Fighter.CHARGE_MAX
		var pulse := 0.4 + 0.3 * sin(f.anim * 0.8)
		draw_arc(Vector2(x, y - 40), cr, 0, TAU, 32, Color(1, 1, 1, pulse), 3)
		draw_arc(Vector2(x, y - 40), cr * 0.7, 0, TAU, 32, Color(c.col, pulse), 2)

	if tag:
		var tc: Color = PCOL[f.id]
		var ty := y - 104 + bob
		draw_colored_polygon(PackedVector2Array([Vector2(x - 6, ty + 4), Vector2(x + 6, ty + 4), Vector2(x, ty + 11)]), tc)
		txt(tag_text(f), Vector2(x, ty), 16, tc, HORIZONTAL_ALIGNMENT_CENTER, 4)


func _draw_sprite(f, alpha: float) -> void:
	var sp: Dictionary = f.ch.sprite
	var hurt: bool = f.hitstun > 0 or f.stun > 0
	var anim := "idle"
	if hurt:
		anim = "hit"
	elif (f.dodge_t > 0 or f.dash_t > 0) and sp.anims.has("dodge"):
		anim = "dodge"
	elif not f.atk.is_empty():
		anim = "attack2" if f.atk.k in Fighter.HEAVIES else "attack"
	elif not f.on_ground:
		anim = "jump" if f.vel.y < 0 else "fall"
	elif absf(f.vel.x) > 0.8:
		anim = "run"
	if not sp.anims.has(anim):
		anim = "attack" if anim == "attack2" else "idle"
	var a: Array = sp.anims[anim]
	var n: int = a[1]
	var fr := 0
	if anim.begins_with("attack"):
		# разгон -> кадры до удара, активные -> кадр удара, восстановление -> остальные
		var m: Dictionary = f.atk.m
		var hf: int = a[3]
		var t: int = f.atk.t
		if t <= m.s:
			fr = mini(hf - 1, int(float(t) / m.s * hf))
		elif t <= m.s + m.a:
			fr = hf
		else:
			fr = mini(n - 1, hf + 1 + int(float(t - m.s - m.a) / m.e * (n - hf - 1)))
	elif anim == "dodge":
		fr = n - 1 if f.dash_t > 0 else clampi(int((22 - f.dodge_t) / 22.0 * n), 0, n - 1)
	else:
		fr = int(f.anim * a[2] / 60.0) % n
	var flash: bool = hurt and f.anim % 6 < 3
	var tex: Texture2D = textures[a[0]]
	var mod := Color(1, 1, 1, alpha)
	if flash:
		if sp.anims.has("flash"):
			tex = textures[sp.anims.flash[0]]
		else:
			mod = Color(2.2, 2.2, 2.2, alpha)
	if f.stun > 0:
		mod = Color(1.4, 1.4, 0.6, alpha)
	var fw: float = sp.fw
	var fh: float = sp.fh
	var sc: float = sp.scale
	var an: Vector2 = sp.anchor
	var src := Rect2(fr * fw, 0, fw, fh)
	var dst := Rect2(f.pos.x - an.x * sc, f.pos.y - an.y * sc, fw * sc, fh * sc)
	if f.facing < 0:
		dst = Rect2(f.pos.x - (fw - an.x) * sc, f.pos.y - an.y * sc, -fw * sc, fh * sc)
	draw_texture_rect_region(tex, dst, src, mod)


func draw_offscreen(vs: Vector2) -> void:
	for f in fighters:
		if f.dead:
			continue
		var sp: Vector2 = (f.pos - Vector2(0, 40) - cam_pos) * cam_z + vs / 2
		if sp.x > 0 and sp.x < vs.x and sp.y > 0 and sp.y < vs.y:
			continue
		var cp := Vector2(clampf(sp.x, 40, vs.x - 40), clampf(sp.y, 40, vs.y - 140))
		draw_circle(cp, 26, Color(0, 0, 0, 0.6))
		draw_arc(cp, 26, 0, TAU, 32, PCOL[f.id], 3)
		draw_circle(cp, 12, f.ch.col)
		var dir := (sp - cp).normalized()
		draw_colored_polygon(PackedVector2Array([cp + dir * 36, cp + dir.rotated(1.9) * 24, cp + dir.rotated(-1.9) * 24]), PCOL[f.id])


## Урон показывается цветом: белый -> жёлтый -> оранжевый -> красный -> тёмно-красный.
func pct_color(p: int) -> Color:
	var stops := [[0, Color("ffffff")], [40, Color("fff27a")], [80, Color("ffb347")], [120, Color("ff6a3d")],
		[160, Color("e8202a")], [210, Color("8a0a12")]]
	if p >= 210:
		return Color("8a0a12") if (frame / 6) % 2 == 0 or p < 240 else Color("ff2030")
	for i in stops.size() - 1:
		if p < stops[i + 1][0]:
			var t: float = float(p - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
			return stops[i][1].lerp(stops[i + 1][1], t)
	return stops[-1][1]


func draw_hud(vs: Vector2) -> void:
	for f in fighters:
		var w := 250.0
		var px := vs.x / 2 - w - 30 if f.id == 0 else vs.x / 2 + 30
		var py := vs.y - 96
		var j := Vector2.ZERO
		if f.pct_shake > 0:
			j = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * f.pct_shake * 0.6
		var dc := pct_color(f.percent)
		rbox(Rect2(px, py, w, 80), Color(0, 0, 0, 0.55), PCOL[f.id])
		var pc := Vector2(px + 44, py + 40) + j
		draw_circle(pc, 32, Color.BLACK)
		draw_circle(pc, 29, dc)
		if f.ch.has("portrait"):
			draw_texture_rect_region(textures[f.ch.portrait[0]], Rect2(pc - Vector2(27, 27), Vector2(54, 54)), f.ch.portrait[1])
		elif f.ch.has("sprite"):
			var sp: Dictionary = f.ch.sprite
			var an: Vector2 = sp.anchor
			draw_texture_rect_region(textures[sp.anims.idle[0]], Rect2(pc - Vector2(26, 26), Vector2(52, 52)), Rect2(an.x - 20, an.y - 52, 40, 40))
		else:
			draw_circle(pc, 18, f.ch.col)
			draw_circle(pc + Vector2(6, -4), 5, Color.WHITE)
			draw_circle(pc + Vector2(8, -4), 2.5, Color.BLACK)
		txt(f.ch.name.to_upper(), Vector2(px + 86, py + 32), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		txt(tag_text(f), Vector2(px + w - 12, py + 30), 15, PCOL[f.id], HORIZONTAL_ALIGNMENT_RIGHT)
		if training:
			txt("∞", Vector2(px + 90, py + 68), 24, f.ch.col, HORIZONTAL_ALIGNMENT_LEFT)
			continue
		for i in f.stocks:
			var sc := Vector2(px + 96 + i * 22, py + 56)
			draw_circle(sc, 8, Color.BLACK)
			draw_circle(sc, 6.5, f.ch.col)


func rbox(r: Rect2, bg: Color, border: Color, rad := 12) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(rad)
	draw_style_box(sb, r)


func txt(s: String, p: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 0) -> void:
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
	# рамка из картинки крупная — рисуем её в 0.55 масштаба, чтобы углы не налезали на содержимое
	const K := 0.55
	draw_set_transform(r.position, 0, Vector2(K, K))
	draw_style_box(panel_sb, Rect2(Vector2.ZERO, r.size / K))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


# ---------------- меню ----------------

func draw_cover(vs: Vector2, dim: float) -> void:
	var ts := menu_bg.diffuse_texture.get_size()
	var sc := maxf(vs.x / ts.x, vs.y / ts.y) * (1.04 + 0.03 * sin(frame * 0.004))
	var sz := ts * sc
	draw_texture_rect(menu_bg, Rect2((vs - sz) / 2, sz), false)
	if dim > 0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.05, 0.15, dim))


func button(r: Rect2, label: String, id: String, value := "") -> void:
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
		txt(label, Vector2(r.position.x + 52, y), 24, tc, HORIZONTAL_ALIGNMENT_LEFT, 4 if on else 0)
		txt(value, Vector2(r.end.x - 52, y), 24, tc, HORIZONTAL_ALIGNMENT_RIGHT, 4 if on else 0)


func draw_title(vs: Vector2) -> void:
	draw_cover(vs, 0.0)
	var cx := vs.x / 2
	var items := [["Играть оффлайн", "offline"], ["Тренировка", "training"], ["Играть онлайн", "online"], ["Настройки", "settings"], ["Выход", "exit"]]
	for i in items.size():
		button(Rect2(cx - 200, vs.y * 0.38 + i * 72, 400, 58), items[i][0], items[i][1])


func draw_settings(vs: Vector2) -> void:
	var cx := vs.x / 2
	txt("НАСТРОЙКИ", Vector2(cx, 100), 56, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10)
	if show_controls:
		draw_controls(vs)
		return
	draw_panel(Rect2(cx - 380, 122, 760, 540))
	var items := [
		["Громкость", "set_volume"],
		["Полный экран", "set_fullscreen"],
		["Тряска экрана", "set_shake"],
		["Вибрация геймпада", "set_rumble"],
		["Прыжок кнопкой вверх", "set_tapjump"],
		["Управление", "controls"],
		["Назад", "back"],
	]
	for i in items.size():
		var r := Rect2(cx - 270, 160 + i * 66, 540, 50)
		button(r, items[i][0], items[i][1], " " if i < 5 else "")
		if i < 5:
			var y := r.get_center().y
			if items[i][1] == "set_volume":
				var br := Rect2(r.end.x - 250, y - 9, 190, 18)
				draw_bar(br, settings.volume / 100.0, 0)
				var kn: Texture2D = ui.knob
				var ks := Vector2(26, 32)
				draw_texture_rect(kn, Rect2(Vector2(br.position.x + br.size.x * settings.volume / 100.0, y) - ks / 2, ks), false)
			else:
				var on: bool = settings[{"set_fullscreen": "fullscreen", "set_shake": "shake", "set_rumble": "rumble", "set_tapjump": "tap_jump"}[items[i][1]]]
				var tex: Texture2D = ui.toggle_on if on else ui.toggle_off
				var ts := tex.get_size()
				var th := 36.0
				draw_texture_rect(tex, Rect2(r.end.x - 56 - ts.x * th / ts.y, y - th / 2, ts.x * th / ts.y, th), false)


func draw_controls(vs: Vector2) -> void:
	var cx := vs.x / 2
	var box := Rect2(cx - 560, 125, 1120, 510)
	draw_panel(box)
	var rows := [
		["", "Игрок 1", "Игрок 2", "Геймпад"],
		["Движение", "A / D", "Стрелки", "Стик / крестовина"],
		["Прыжок (держи — выше)", "Пробел", "Num0 или Ctrl", "A"],
		["Прицел вверх", "W", "Стрелка вверх", "Стик вверх"],
		["Падение / сквозь платформу", "S", "Стрелка вниз", "Стик вниз"],
		["Лёгкая атака", "F", "Num1 или ,", "X"],
		["Тяжёлая атака (держи — заряд)", "G", "Num2 или .", "B"],
		["Уклонение", "H", "Num3 или /", "LB / RB / триггеры"],
		["Пауза", "Esc", "Esc", "Start"],
	]
	var xs := [box.position.x + 40, box.position.x + 440, box.position.x + 640, box.position.x + 840]
	for r in rows.size():
		var y := box.position.y + 50 + r * 44
		for c in 4:
			var col := Color("ffd23d") if r == 0 else (Color(1, 1, 1, 0.75) if c == 0 else Color.WHITE)
			txt(rows[r][c], Vector2(xs[c], y), 21, col, HORIZONTAL_ALIGNMENT_LEFT)
	var y2 := box.position.y + 50 + rows.size() * 44 + 10
	txt("Атаки зависят от направления. В воздухе: тяжёлая вверх — восстановление, вбок — рывок, вниз — удар по земле.", Vector2(box.position.x + 40, y2), 18, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	txt("Двойное нажатие в сторону — рывок. Зажми направление у края арены — зацепишься за стену.", Vector2(box.position.x + 40, y2 + 28), 18, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	txt("Esc / B — назад", Vector2(cx, box.end.y + 40), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 4)


func draw_lobby(vs: Vector2) -> void:
	var cx := vs.x / 2
	txt("ИГРА ПО СЕТИ", Vector2(cx, 100), 56, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10)
	draw_panel(Rect2(cx - 450, 128, 900, 490))
	if net_mode == "":
		txt("Один игрок создаёт игру, второй подключается по его IP.", Vector2(cx, 190), 19, Color(1, 1, 1, 0.85))
		txt("Нужна общая сеть: Wi-Fi дома, Radmin VPN / Hamachi или открытый порт %d." % PORT, Vector2(cx, 216), 19, Color(1, 1, 1, 0.85))
		button(Rect2(cx - 300, 240, 600, 60), "Создать игру", "host")
		ip_edit.position = Vector2(cx - 300, 330)
		ip_edit.size = Vector2(330, 58)
		button(Rect2(cx + 45, 330, 255, 58), "Подключиться", "join")
		button(Rect2(cx - 300, 520, 600, 58), "Назад", "back")
		if lobby_status != "":
			txt(lobby_status, Vector2(cx, 460), 22, Color(1, 0.8, 0.4), HORIZONTAL_ALIGNMENT_CENTER, 4)
	else:
		txt(lobby_status, Vector2(cx, 220), 30, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 6)
		if net_mode == "host":
			txt("Скажи сопернику свой IP:", Vector2(cx, 290), 22, Color.WHITE)
			for i in host_ips.size():
				txt(host_ips[i], Vector2(cx, 336 + i * 40), 32, Color("9fe6ff"), HORIZONTAL_ALIGNMENT_CENTER, 4)
		button(Rect2(cx - 300, 520, 600, 58), "Отмена", "back")


func draw_portrait(pf, c: Vector2, r: float) -> void:
	draw_set_transform(c + Vector2(0, r * 0.95) - pf.pos * 1.1, 0, Vector2(1.1, 1.1))
	draw_fighter(pf, false)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func slot_label(i: int) -> String:
	if net_mode != "":
		return "ВЫ" if i == my_slot else "СОПЕРНИК"
	if i == 1 and training:
		return "МАНЕКЕН"
	if i == 1 and vs_cpu:
		return "CPU"
	return "P%d" % (i + 1)


func chip(x: float, y: float, label: String, key: String, active: bool) -> float:
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 44
	rbox(Rect2(x, y, w, 36), Color(0.08, 0.03, 0.06, 0.9), Color(0.88, 0.14, 0.37, 0.8) if active else Color(1, 1, 1, 0.15), 6)
	txt(key, Vector2(x + 14, y + 24), 14, Color("ffd23d") if active else Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_LEFT)
	txt(label, Vector2(x + w - 14, y + 25), 18, Color.WHITE if active else Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_RIGHT)
	return w


func hex_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var ang := deg_to_rad(60.0 * i - 90.0)
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	return pts


## Портрет, обрезанный по шестиугольнику (uv берутся из прямоугольника лица на картинке).
func draw_hex_portrait(ch: Dictionary, c: Vector2, r: float, pf) -> void:
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
	var band := PackedColorArray([Color(0.02, 0, 0.02, 0), Color(0.02, 0, 0.02, 0.6), Color(0.02, 0, 0.02, 0.6), Color(0.02, 0, 0.02, 0)])
	for side in [-1, 1]:
		var x0: float = cx + side * 150
		var x1: float = cx + side * 300
		draw_polygon(PackedVector2Array([Vector2(x1, 60), Vector2(x0, 60), Vector2(x0, vs.y), Vector2(x1, vs.y)]),
			PackedColorArray([band[0], band[1], band[2], band[3]]))
	draw_rect(Rect2(cx - 150, 60, 300, vs.y - 60), Color(0.02, 0, 0.02, 0.6))

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
	var chips := [["Арена: " + ARENAS[arena].name, "Q E", can_edit]]
	if not training:
		chips.append(["Жизни: %d" % stocks, "W S", can_edit])
	if not online and not training:
		chips.append(["Соперник: " + ("CPU" if vs_cpu else "Игрок 2"), "C", true])
		if vs_cpu:
			chips.append(["Сложность: " + LVL_NAMES[lvl], "V", true])
	var total_w := 0.0
	for c in chips:
		total_w += font.get_string_size(c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + font.get_string_size(c[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 56
	var x := cx - total_w / 2
	for c in chips:
		x += chip(x, 12, c[0], c[1], c[2]) + 12
	txt("ОНЛАЙН" if online else ("ТРЕНИРОВКА" if training else "ВЫБОР БОЙЦА"), Vector2(cx, 112), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8)

	var blink := 0.6 + 0.4 * sin(frame * 0.1)
	var py: float = cells[total - 1].y + r + 70
	if net_mode == "client":
		txt("Ждём хоста...", Vector2(cx, py), 22, Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER, 5)
	else:
		txt("ENTER / A — В БОЙ", Vector2(cx, py), 22, Color(1, 0.85, 0.35, blink), HORIZONTAL_ALIGNMENT_CENTER, 5)


func draw_over(vs: Vector2) -> void:
	var k := minf(1.0, over_t / 40.0)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6 * k))
	var cx := vs.x / 2
	if winner:
		txt("ПОБЕДА!", Vector2(cx, vs.y / 2 - 110), int(60 + 30 * k), Color(1, 0.85, 0.25, k), HORIZONTAL_ALIGNMENT_CENTER, 12)
		txt("%s  (%s)" % [winner.ch.name, "CPU" if winner.cpu else "P%d" % (winner.id + 1)], Vector2(cx, vs.y / 2 - 50), 40, Color(winner.ch.col, k), HORIZONTAL_ALIGNMENT_CENTER, 8)
	else:
		txt("НИЧЬЯ", Vector2(cx, vs.y / 2 - 80), 80, Color(1, 1, 1, k), HORIZONTAL_ALIGNMENT_CENTER, 12)
	for f in fighters:
		var x := cx - 160 if f.id == 0 else cx + 160
		txt(f.ch.name, Vector2(x, vs.y / 2 + 20), 24, Color(f.ch.col, k))
		txt("Нокауты: %d" % f.kos, Vector2(x, vs.y / 2 + 52), 20, Color(1, 1, 1, k))
		txt("Нанесено урона: %d%%" % f.dmg_dealt, Vector2(x, vs.y / 2 + 78), 20, Color(1, 1, 1, k))
	if over_t > 40:
		var hint := "Ждём хоста..." if net_mode == "client" else "ENTER / A — к выбору бойцов      R / Y — реванш"
		txt(hint, Vector2(cx, vs.y / 2 + 150), 24, Color(1, 1, 1, 0.8))


# ---------------- автотест (godot --headless -- --autotest) ----------------

func _autotest_step() -> void:
	if frame % 600 == 0 and state == "fight" and fighters.size() == 2:
		var s := []
		for f in fighters:
			s.append("%s %d%% x%d pos(%d,%d)" % [f.ch.name, f.percent, f.stocks, f.pos.x, f.pos.y])
		print("[%s] t=%d  " % [net_mode, frame], " | ".join(s))
	if (state == "over" and over_t > 120) or frame > 60 * 240:
		print("AUTOTEST END state=%s winner=%s frame=%d" % [state, winner.ch.name if winner else "none", frame])
		get_tree().quit()
