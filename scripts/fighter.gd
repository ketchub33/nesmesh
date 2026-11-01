extends RefCounted
## Боец: физика, атаки, урон и простой ИИ. Механика в духе Brawlhalla:
## 1 прыжок с земли + воздушные, уклонение вместо щита, лёгкие и заряжаемые тяжёлые атаки,
## восстановление (тяжёлая вверх в воздухе), цепляние за стены арены.

const HW := 18.0
const FH := 76.0
const GRAV := 0.65
const MAIN := Rect2(290, 500, 700, 200)
# раскладки платформ над основной ареной; текущая выбирается в game.gd по арене
const LAYOUTS := {
	"classic": [Rect2(370, 380, 170, 10), Rect2(740, 380, 170, 10), Rect2(555, 265, 170, 10)],
	"twin": [Rect2(400, 340, 200, 10), Rect2(680, 340, 200, 10)],
	"steps": [Rect2(330, 400, 150, 10), Rect2(565, 300, 150, 10), Rect2(800, 400, 150, 10), Rect2(565, 170, 150, 10)],
	"flat": [],
}
static var PLATS: Array = LAYOUTS.classic
const BLAST_L := -350.0
const BLAST_R := 1630.0
const BLAST_T := -420.0
const BLAST_B := 1050.0
const SPAWN := Vector2(640, 140)
const KEYS := ["l", "r", "u", "d", "j", "atk", "spc", "sh"]
const CHARGE_MAX := 40  # кадров заряда тяжёлой атаки
const DODGE_GROUND_CD := 40
const BUF := 6  # сколько кадров помнится нажатие (буфер ввода)
const BUFFERED := ["j", "atk", "spc", "sh"]

static var CHARS := [
	# sprite: кадры в ряд (fw×fh), anchor — точка между ног внутри кадра, anims: [файл, кадров, fps, кадр удара]
	# jumps — прыжков в воздухе (плюс один с земли)
	{"name": "Селина", "col": Color("f2c14e"), "dark": Color("2a2f5c"), "vfx": "selina",
		"speed": 7.0, "air": 6.2, "jump": 14.0, "djump": 12.5, "jumps": 2, "weight": 0.9, "power": 0.95,
		"fall": 12.0, "recover": 16.5, "acc": "",
		"portrait": ["res://assets/characters/selina/portrait.png", Rect2(120, 30, 220, 220)],
		"sprite": {"fw": 274, "fh": 164, "anchor": Vector2(80, 158), "scale": 0.56, "smooth": true, "anims": {
			"idle": ["res://assets/characters/selina/idle.png", 7, 9.0, 0],
			"run": ["res://assets/characters/selina/run.png", 8, 14.0, 0],
			"jump": ["res://assets/characters/selina/jump.png", 2, 6.0, 0],
			"fall": ["res://assets/characters/selina/fall.png", 2, 6.0, 0],
			"dodge": ["res://assets/characters/selina/dodge.png", 3, 0.0, 0],
			"attack": ["res://assets/characters/selina/attack.png", 5, 0.0, 2],
			"attack2": ["res://assets/characters/selina/attack2.png", 5, 0.0, 2],
			"hit": ["res://assets/characters/selina/hit.png", 3, 8.0, 0],
		}}},
	{"name": "Акане", "col": Color("e0245e"), "dark": Color("3a2430"), "vfx": "crimson",
		"speed": 6.4, "air": 5.8, "jump": 14.5, "djump": 13.0, "jumps": 2, "weight": 1.05, "power": 1.08,
		"fall": 13.0, "recover": 17.0, "acc": "",
		"portrait": ["res://assets/characters/crimson/portrait.png", Rect2(235, 70, 200, 200)],
		"sprite": {"fw": 255, "fh": 236, "anchor": Vector2(146, 212), "scale": 0.6, "smooth": true, "anims": {
			"idle": ["res://assets/characters/crimson/idle.png", 6, 8.0, 0],
			"run": ["res://assets/characters/crimson/run.png", 6, 12.0, 0],
			"jump": ["res://assets/characters/crimson/jump.png", 2, 6.0, 0],
			"fall": ["res://assets/characters/crimson/fall.png", 2, 6.0, 0],
			"dodge": ["res://assets/characters/crimson/dodge.png", 3, 0.0, 0],
			"attack": ["res://assets/characters/crimson/attack.png", 4, 0.0, 2],
			"attack2": ["res://assets/characters/crimson/attack2.png", 5, 0.0, 1],
			"hit": ["res://assets/characters/crimson/hit.png", 3, 8.0, 0],
		}}},
]

# s — разгон, a — активные кадры, e — восстановление; box — хитбокс относительно ног (x вперёд по взгляду)
# лёгкие: n/s/d light (земля), nair/sair/dair (воздух); тяжёлые: nsig/ssig/dsig (земля, заряд),
# rec — восстановление, sheavy — рывок в воздухе, gp — удар по земле с высоты
static var MOVES := {
	"nlight": {"s": 4, "a": 4, "e": 8, "dmg": 7, "kb": 6.0, "sc": 0.07, "ang": 70.0, "box": Rect2(-6, -112, 62, 54)},
	"slight": {"s": 5, "a": 4, "e": 9, "dmg": 8, "kb": 7.0, "sc": 0.12, "ang": 30.0, "box": Rect2(16, -62, 64, 32)},
	"dlight": {"s": 5, "a": 6, "e": 9, "dmg": 7, "kb": 6.0, "sc": 0.08, "ang": 62.0, "box": Rect2(6, -28, 72, 28)},
	"nair": {"s": 4, "a": 6, "e": 8, "dmg": 8, "kb": 6.0, "sc": 0.12, "ang": 55.0, "box": Rect2(-42, -86, 84, 84)},
	"sair": {"s": 5, "a": 5, "e": 9, "dmg": 9, "kb": 7.0, "sc": 0.16, "ang": 35.0, "box": Rect2(14, -76, 60, 50)},
	"dair": {"s": 6, "a": 6, "e": 10, "dmg": 9, "kb": 6.0, "sc": 0.10, "ang": -60.0, "box": Rect2(-26, -20, 52, 44)},
	"nsig": {"s": 14, "a": 6, "e": 24, "dmg": 16, "kb": 9.0, "sc": 0.30, "ang": 85.0, "box": Rect2(-50, -132, 100, 84), "charge": true},
	"ssig": {"s": 16, "a": 6, "e": 24, "dmg": 18, "kb": 9.0, "sc": 0.34, "ang": 38.0, "box": Rect2(14, -72, 84, 52), "charge": true},
	"dsig": {"s": 14, "a": 8, "e": 24, "dmg": 15, "kb": 8.0, "sc": 0.30, "ang": 28.0, "box": Rect2(-88, -42, 176, 42), "charge": true},
	"rec": {"s": 4, "a": 14, "e": 8, "dmg": 9, "kb": 7.0, "sc": 0.12, "ang": 80.0, "box": Rect2(-30, -104, 60, 104)},
	"sheavy": {"s": 8, "a": 12, "e": 16, "dmg": 12, "kb": 8.0, "sc": 0.24, "ang": 35.0, "box": Rect2(0, -72, 58, 58)},
	"gp": {"s": 8, "a": 14, "e": 22, "dmg": 14, "kb": 8.0, "sc": 0.26, "ang": 70.0, "box": Rect2(-38, -32, 76, 42)},
}
const HEAVIES := ["nsig", "ssig", "dsig", "rec", "sheavy", "gp"]

var game
var id := 0
var ch: Dictionary
var cpu := false
var stocks := 3
var kos := 0
var dmg_dealt := 0
var prev := {}
var ai_t := 0
var ai_last := {}

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var facing := 1
var on_ground := false
var ground_rect := Rect2()
var jumps := 2
var used_up := false
var used_side := false
var helpless := false
var atk := {}
var hitstun := 0
var freeze := 0
var inv := 0
var stun := 0
var land_lag := 0
var drop := 0
var percent := 0
var dead := false
var respawn := 0
var ff := false
var anim := 0
var pct_shake := 0
var last_hit := -1
var dodge_t := 0
var dodge_cd := 0
var air_dodge_used := false
var dash_t := 0
var tap_dir := 0
var tap_t := -100
var wall_side := 0  # 1 — стена справа от бойца, -1 — слева, 0 — нет
var clinging := false
var buf := {}
var hop_cut := false
var prev_pos := Vector2.ZERO  # позиция на прошлом тике — для плавной отрисовки


func _init(g, i: int, c: Dictionary, is_cpu: bool, st: int) -> void:
	game = g
	id = i
	ch = c
	cpu = is_cpu
	stocks = st
	facing = 1 if i == 0 else -1
	spawn(Vector2(470 if i == 0 else 810, MAIN.position.y))
	inv = 0


func spawn(p: Vector2) -> void:
	pos = p
	vel = Vector2.ZERO
	on_ground = false
	jumps = ch.jumps
	used_up = false
	used_side = false
	helpless = false
	atk = {}
	hitstun = 0
	freeze = 0
	inv = 150
	stun = 0
	land_lag = 0
	drop = 0
	percent = 0
	dead = false
	respawn = 0
	ff = false
	last_hit = -1
	dodge_t = 0
	dodge_cd = 0
	air_dodge_used = false
	dash_t = 0
	wall_side = 0
	clinging = false


func hurtbox() -> Rect2:
	return Rect2(pos.x - HW, pos.y - FH, HW * 2, FH)


func box_of(m: Dictionary) -> Rect2:
	var b: Rect2 = m.box
	var x := pos.x + b.position.x if facing > 0 else pos.x - b.position.x - b.size.x
	return Rect2(x, pos.y + b.position.y, b.size.x, b.size.y)


func is_active() -> bool:
	if atk.is_empty():
		return false
	return atk.t > atk.m.s and atk.t <= atk.m.s + atk.m.a


func charging() -> bool:
	return not atk.is_empty() and atk.get("c", 0) > 0 and atk.t == atk.m.s - 1


func fx_set() -> String:
	return ch.get("vfx", "selina")


func dodging() -> bool:
	return dodge_t > 3


func update(inp: Dictionary) -> void:
	var pr := {}
	for k in KEYS:
		var edge: bool = inp.get(k, false) and not prev.get(k, false)
		pr[k] = edge
		if edge and k in BUFFERED:
			buf[k] = BUF  # нажатие запоминается, даже если сейчас боец занят или замер от удара
	prev = inp
	if dead:
		if stocks > 0:
			respawn -= 1
			if respawn <= 0:
				spawn(SPAWN)
		return
	if pct_shake > 0:
		pct_shake -= 1
	if freeze > 0:
		freeze -= 1
		return
	anim += 1
	for k in BUFFERED:
		pr[k] = buf.get(k, 0) > 0
		if pr[k]:
			buf[k] -= 1
	if inv > 0:
		inv -= 1
	if drop > 0:
		drop -= 1
	if dodge_cd > 0 and dodge_t == 0:
		dodge_cd -= 1
	var g := on_ground
	var dir := int(inp.get("r", false)) - int(inp.get("l", false))
	clinging = false

	if hitstun > 0:
		hitstun -= 1
		vel *= 0.975
		vel.y += GRAV * 0.9
		physics()
		return
	if stun > 0:
		stun -= 1
		vel.x *= 0.85
		vel.y = minf(vel.y + GRAV, ch.fall)
		physics()
		return

	# уклонение: неуязвимость, в воздухе — полёт в выбранную сторону без гравитации
	if dodge_t > 0:
		dodge_t -= 1
		if dodge_t == 0 and on_ground:
			dodge_cd = DODGE_GROUND_CD
		if pr.atk and not on_ground:
			# отмена гравитации: из воздушного уклонения выходит наземная лёгкая атака
			dodge_t = 0
			buf["atk"] = 0
			if dir != 0:
				facing = dir
			start_atk(light_key(inp, dir, true))
			game.sfx("swing")
		else:
			if on_ground:
				vel.x *= 0.88
			else:
				vel *= 0.9
			physics()
			return

	var grav := true
	# попал — восстановление удара можно отменить прыжком или уклонением
	if not atk.is_empty() and not atk.hit.is_empty() and atk.t > atk.m.s + atk.m.a and (pr.j or pr.sh):
		atk = {}
	if not atk.is_empty():
		grav = step_attack(inp, dir, g)
	elif land_lag > 0:
		land_lag -= 1
		vel.x *= 0.7
	elif pr.sh and start_dodge(inp, dir):
		physics()
		return
	elif pr.spc and not helpless:
		heavy(inp, dir, g)
	elif pr.atk and not helpless:
		light(inp, dir, g)
	elif not g and wall_side != 0 and dir == wall_side and not helpless:
		# цепляние за стену: медленно сползаем, прыжки и восстановление обновляются
		clinging = true
		jumps = ch.jumps
		used_up = false
		used_side = false
		air_dodge_used = false
		ff = false
		if pr.j:
			buf["j"] = 0
			vel = Vector2(-wall_side * 3.5, -ch.djump)
			game.puff(pos + Vector2(wall_side * HW, -30), 4)
			game.sfx("jump2")
		else:
			vel.x = 0
			vel.y = minf(vel.y + GRAV * 0.3, 2.5)
			grav = false
	else:
		if pr.j:
			jump(dir)
		if on_ground:
			# рывок двойным нажатием в сторону
			if (pr.l or pr.r) and dir != 0:
				if tap_dir == dir and anim - tap_t < 14:
					dash_t = 12
					game.puff(pos, 4)
				tap_dir = dir
				tap_t = anim
			if dash_t > 0:
				dash_t -= 1
				vel.x = facing * ch.speed * 1.9
				if dir != 0:
					facing = dir
			elif dir != 0:
				# быстрый разгон, ещё более резкий разворот; скорость сверх нормы (после рывка) гаснет плавно
				var spd: float = ch.speed
				if absf(vel.x) > spd and signf(vel.x) == dir:
					vel.x = move_toward(vel.x, dir * spd, 0.35)
				else:
					vel.x = move_toward(vel.x, dir * spd, 2.2 if signf(vel.x) == -dir else 1.6)
				facing = dir
			else:
				# быстрая остановка с небольшим проскальзыванием
				vel.x = move_toward(vel.x, 0.0, 1.2 if absf(vel.x) <= ch.speed else 0.5)
			if pr.d and ground_rect != MAIN:
				drop = 12
				on_ground = false
		else:
			air_drift(dir, 0.8)
			if pr.d and vel.y > -3:
				ff = true
	# короткий прыжок: отпустил кнопку на подъёме — прыжок обрывается
	if hop_cut and vel.y < 0 and not inp.get("j", false) and not cpu:
		vel.y *= 0.5
		hop_cut = false
	if vel.y >= 0:
		hop_cut = false
	if grav:
		if ff and not on_ground:
			vel.y = ch.fall
		else:
			vel.y = minf(vel.y + GRAV, ch.fall * 0.72)
	physics()


func air_drift(dir: int, acc: float) -> void:
	var mx: float = ch.air
	if absf(vel.x) > mx + 0.01:
		vel.x = vel.x * 0.96 + dir * acc * 0.5
	elif dir != 0:
		vel.x = clampf(vel.x + dir * acc, -mx, mx)
	else:
		vel.x *= 0.965  # в воздухе инерция сохраняется дольше


func jump(dir: int) -> void:
	buf["j"] = 0
	if on_ground:
		vel.y = -ch.jump
		on_ground = false
		ff = false
		dash_t = 0
		hop_cut = true
		game.puff(pos, 6)
		game.sfx("jump")
	elif jumps > 0 and not helpless:
		jumps -= 1
		vel.y = -ch.djump
		ff = false
		if dir != 0:
			vel.x = dir * ch.air
		game.fx(fx_set() + "/ring", pos + Vector2(0, -6), 50.0)
		game.sfx("jump2")


func start_dodge(inp: Dictionary, dir: int) -> bool:
	if on_ground:
		if dodge_cd > 0:
			return false
		dodge_t = 20
		vel.x = dir * 12.0
	else:
		if air_dodge_used or helpless:
			return false
		air_dodge_used = true
		hop_cut = false
		var v := Vector2(dir, int(inp.get("d", false)) - int(inp.get("u", false)))
		vel = v.normalized() * 10.0 if v != Vector2.ZERO else Vector2.ZERO
		dodge_t = 22
		ff = false
	dash_t = 0
	buf["sh"] = 0
	game.puff(pos, 5)
	game.sfx("dodge")
	return true


func light_key(inp: Dictionary, dir: int, ground: bool) -> String:
	if inp.get("d", false):
		return "dlight" if ground else "dair"
	if dir != 0:
		return "slight" if ground else "sair"
	return "nlight" if ground else "nair"


func light(inp: Dictionary, dir: int, g: bool) -> void:
	if dir != 0:
		facing = dir
	buf["atk"] = 0
	start_atk(light_key(inp, dir, g))
	game.sfx("swing")


func heavy(inp: Dictionary, dir: int, g: bool) -> void:
	var k := ""
	if g:
		if inp.get("d", false):
			k = "dsig"
		elif dir != 0:
			k = "ssig"
			facing = dir
		else:
			k = "nsig"
	elif inp.get("d", false):
		k = "gp"
	elif dir != 0 and not inp.get("u", false):
		if used_side:
			return
		used_side = true
		facing = dir
		k = "sheavy"
	else:
		if used_up:
			return
		used_up = true
		k = "rec"
	buf["spc"] = 0
	start_atk(k)


func start_atk(k: String) -> void:
	dash_t = 0
	atk = {"k": k, "m": MOVES[k], "t": 0, "c": 0, "hit": [], "air": not on_ground}


func step_attack(inp: Dictionary, dir: int, g: bool) -> bool:
	var m: Dictionary = atk.m
	# заряд: пока держишь тяжёлую атаку, удар замирает перед выпадом и копит силу
	if m.get("charge", false) and atk.t == m.s - 1 and inp.get("spc", false) and atk.c < CHARGE_MAX:
		atk["c"] += 1
		vel.x *= 0.8
		return true
	atk["t"] += 1
	var t: int = atk.t
	var act: bool = t > m.s and t <= m.s + m.a
	var grav := true
	if g:
		vel.x *= 0.88
	else:
		air_drift(dir, 0.45)
	match atk.k:
		"slight":
			if t == m.s:
				vel.x = facing * 4.0
		"dlight":
			if t == m.s:
				vel.x = facing * 9.0
		"ssig":
			if t == m.s:
				vel.x = facing * 8.0
		"dsig":
			if g and t == m.s + 1:
				game.ring(pos, ch.col, 90.0)
				game.fx(fx_set() + "/dust", pos + Vector2(0, -30), 150.0)
				game.sfx("boom")
		"rec":
			if t <= m.s:
				vel.y *= 0.5
				grav = false
			elif t == m.s + 1:
				vel.y = -ch.recover
				vel.x = dir * 3.0
				on_ground = false
				ff = false
				game.sfx("jump2")
				game.ring(pos, ch.col, 40.0)
		"sheavy":
			if t <= m.s:
				vel.y *= 0.6
				grav = false
			elif act:
				vel.x = facing * 12.0
				vel.y = 0
				grav = false
				if t % 3 == 0:
					game.trail(self)
		"gp":
			if t <= m.s:
				vel.y *= 0.5
				grav = false
			elif not g and act:
				vel.y = 17.0
				grav = false
			if g and t == m.s + 1:
				game.ring(pos, ch.col, 80.0)
				game.fx(fx_set() + "/spike", pos + Vector2(0, -40), 110.0)
				game.sfx("boom")
	if t >= m.s + m.a + m.e:
		atk = {}
	return grav


func physics() -> void:
	var p0 := pos
	pos += vel
	var was := on_ground
	on_ground = false
	var landed := false
	var lr := Rect2()
	var m := MAIN
	if pos.x + HW > m.position.x and pos.x - HW < m.end.x:
		if p0.y <= m.position.y + 0.01 and pos.y >= m.position.y and vel.y >= 0:
			landed = true
			lr = m
		elif pos.y > m.position.y and pos.y - FH < m.end.y:
			if p0.y - FH >= m.end.y - 1:
				pos.y = m.end.y + FH
				vel.y = absf(vel.y) * 0.3 if hitstun > 0 else 0.0
			else:
				pos.x = m.position.x - HW if p0.x < m.get_center().x else m.end.x + HW
				vel.x = -vel.x * 0.5 if hitstun > 0 else 0.0
	if not landed and drop <= 0 and vel.y >= 0:
		for pl in PLATS:
			if p0.y <= pl.position.y + 0.01 and pos.y >= pl.position.y and pos.x > pl.position.x - 6 and pos.x < pl.end.x + 6:
				landed = true
				lr = pl
				break
	if landed:
		pos.y = lr.position.y
		if hitstun > 0 and vel.y > 7:
			vel.y = -vel.y * 0.45
			game.puff(pos, 10)
		else:
			var impact := vel.y
			vel.y = 0
			on_ground = true
			ground_rect = lr
			if hitstun > 0:
				hitstun = mini(hitstun, 8)
				vel.x *= 0.8
			if not was:
				on_land(impact)
	# касание боковой стены основной арены
	wall_side = 0
	if not on_ground and pos.y > m.position.y + 4 and pos.y - FH < m.end.y:
		if absf(pos.x + HW - m.position.x) < 2.0:
			wall_side = 1
		elif absf(pos.x - HW - m.end.x) < 2.0:
			wall_side = -1


func on_land(impact: float) -> void:
	jumps = ch.jumps
	used_up = false
	used_side = false
	air_dodge_used = false
	ff = false
	if helpless:
		helpless = false
		land_lag = 10
	if not atk.is_empty() and atk.air and atk.k != "gp":
		atk = {}
		land_lag = 6
	if impact > 6:
		game.puff(pos, 5)


# ---------------- ИИ ----------------

func ai_input(foe, lvl: int) -> Dictionary:
	if dead:
		return {}
	ai_t -= 1
	if ai_t > 0:
		return ai_last
	ai_t = [10, 6, 3][lvl] + randi() % 4
	var o := {}
	var m := MAIN
	var cx := m.get_center().x
	var under := pos.x > m.position.x - HW and pos.x < m.end.x + HW and pos.y > m.end.y
	var off := pos.x < m.position.x - 4 or pos.x > m.end.x + 4

	# возвращение на арену (у стены просто держим направление — боец цепляется и карабкается)
	if not on_ground and (off or under):
		if under:
			_go(o, -1 if pos.x < cx else 1)
		else:
			_go(o, cx - pos.x)
		if (pos.y > m.position.y - 40 or vel.y > 4) and not helpless:
			if jumps > 0 and vel.y > -2:
				o["u"] = true
			elif not used_side and absf(pos.x - cx) > m.size.x / 2 + 160 and pos.y < m.position.y + 60:
				o["spc"] = true
			elif not used_up and not under:
				o["u"] = true
				o["spc"] = true
			elif not air_dodge_used and wall_side == 0:
				o["sh"] = true
				o["u"] = true
		ai_t = 2
		return _ai_fin(o)

	if foe == null or foe.dead:
		if absf(cx - pos.x) > 40:
			_go(o, cx - pos.x)
		return _ai_fin(o)

	var dx: float = foe.pos.x - pos.x
	var dy: float = foe.pos.y - pos.y
	var adx := absf(dx)
	var fd := 1 if dx >= 0 else -1
	# уклонение от атаки соперника
	if foe.is_active() or (not foe.atk.is_empty() and adx < 110 and absf(dy) < 90):
		if randf() < [0.08, 0.25, 0.5][lvl] and (on_ground and dodge_cd == 0 or not on_ground and not air_dodge_used):
			o["sh"] = true
			if randf() < 0.5:
				_go(o, -fd)
			ai_t = 6
			return _ai_fin(o)

	if adx < 85 and absf(dy) < 75:
		if on_ground and facing != fd:
			_go(o, fd)
			ai_t = 1
			return _ai_fin(o)
		var finish: bool = foe.percent > 110 and randf() < 0.55
		var r := randf()
		if finish:
			if r < 0.5:
				_go(o, fd)
			elif r < 0.75:
				o["d"] = true
			o["spc"] = true
			ai_t = 8 + randi() % 12  # подержать — заряд
		elif r < 0.4:
			_go(o, fd)
			o["atk"] = true
		elif r < 0.6:
			o["atk"] = true
		elif r < 0.78:
			o["d"] = true
			o["atk"] = true
		elif r < 0.88:
			o["spc"] = true
		else:
			o["u"] = true
			o["atk"] = true
	elif dy < -100 and adx < 140:
		_go(o, dx)
		o["u"] = true
		if not on_ground and vel.y < 0:
			o["atk"] = true
	else:
		var tx := clampf(foe.pos.x, m.position.x + 40, m.end.x - 40)
		if absf(tx - pos.x) > 20:
			_go(o, tx - pos.x)
		if dy > 80 and on_ground and ground_rect != MAIN:
			o["d"] = true
		if dy < -60 and on_ground and randf() < 0.3:
			o["u"] = true
	return _ai_fin(o)


func _go(o: Dictionary, d: float) -> void:
	if d > 0:
		o["r"] = true
	elif d < 0:
		o["l"] = true


func _ai_fin(o: Dictionary) -> Dictionary:
	# клавиши-нажатия нужно отпускать между повторами
	if o.get("u", false) and not o.get("spc", false):
		o["j"] = true  # ИИ прыгает «вверх», как с включённым прыжком на стрелку
	for k in ["atk", "spc", "sh", "j"]:
		if o.get(k, false) and ai_last.get(k, false):
			o[k] = false
	if o.get("u", false) and ai_last.get("u", false) and not o.get("atk", false) and not o.get("spc", false):
		o["u"] = false
	ai_last = o
	return o
