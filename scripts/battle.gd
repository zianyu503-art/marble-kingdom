class_name Battle
extends Node2D

## The minor map: two armies' marbles fight with real rigid-body physics
## (Godot Physics 2D) on a terrain picked from where they met on the world map.

signal finished(result: Dictionary)

const SIZE := Vector2(720, 720)
const TIME_LIMIT := 85.0
const GRASS := Color("b9d98f")
const GRASS_DARK := Color("6f9e4a")
const STONE := Color("e4e1d8")
const WATER := Color("9cc6ef")

var game: Node
var rng := RandomNumberGenerator.new()
var terrain := "field"
var fac_a: Faction
var fac_d: Faction
var units: Array = []
var corpses: Array = []
## Arrows stuck in walls: {p, d, life}
var stuck: Array = []
var projectiles: Array = []
var fx: Array = []
var texts: Array = []
var decor: Array = []
var obstacles: Array = []
var floor_rect := Rect2()
var running := false
var ended := false
var elapsed := 0.0
var king_home := Vector2(640, 360)
var banner := ""
var banner_t := 0.0
var banner_col := Color.WHITE
var title := ""
var settlement := ""
var unit_root: Node2D
var ground: Node2D
var corpse_layer: Node2D
var shadow_layer: Node2D
var static_root: Node2D
var overlay: Node2D
var start_counts := [0, 0]
## Debug counters: weapon-on-weapon clashes and weapon-on-body hits.
var stat_clash := 0
var stat_hits := 0
var stat_wall_arrows := 0
var stat_escapes := 0
var stat_shots := 0
var stat_back_shots := 0


func _ready() -> void:
	ground = Node2D.new()
	ground.draw.connect(_draw_ground)
	add_child(ground)
	corpse_layer = Node2D.new()
	corpse_layer.draw.connect(_draw_corpses)
	add_child(corpse_layer)
	shadow_layer = Node2D.new()
	shadow_layer.draw.connect(_draw_shadows)
	add_child(shadow_layer)
	static_root = Node2D.new()
	add_child(static_root)
	unit_root = Node2D.new()
	add_child(unit_root)
	overlay = Node2D.new()
	overlay.z_index = 10
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)


## info: terrain, attackers, defenders (Array of Soldier), fac_a, fac_d, title, settlement
func start(info: Dictionary) -> void:
	_clear()
	rng.randomize()
	terrain = info["terrain"]
	fac_a = info["fac_a"]
	fac_d = info["fac_d"]
	title = info.get("title", "")
	settlement = info.get("settlement", "")
	elapsed = 0.0
	ended = false
	stat_clash = 0
	stat_hits = 0
	stat_wall_arrows = 0
	stat_escapes = 0
	stat_shots = 0
	stat_back_shots = 0
	_build_terrain()
	_spawn_side(info["attackers"], fac_a, 0)
	_spawn_side(info["defenders"], fac_d, 1)
	start_counts = [_alive(0), _alive(1)]
	ground.queue_redraw()
	corpse_layer.queue_redraw()
	_show_banner("ONWARD!", Color.WHITE)
	game.sfx.play("horn")
	running = true


func _clear() -> void:
	for c in unit_root.get_children():
		c.queue_free()
	for c in static_root.get_children():
		c.queue_free()
	units.clear()
	corpses.clear()
	stuck.clear()
	projectiles.clear()
	fx.clear()
	texts.clear()
	decor.clear()
	obstacles.clear()
	floor_rect = Rect2()


# --------------------------------------------------------------- terrain

func _build_terrain() -> void:
	var t := 24.0
	_wall(Rect2(-t, -t, SIZE.x + 2 * t, t), "edge")
	_wall(Rect2(-t, SIZE.y, SIZE.x + 2 * t, t), "edge")
	_wall(Rect2(-t, 0, t, SIZE.y), "edge")
	_wall(Rect2(SIZE.x, 0, t, SIZE.y), "edge")
	for i in 140:
		decor.append({"k": "tuft", "p": Vector2(rng.randf() * SIZE.x, rng.randf() * SIZE.y), "s": rng.randf_range(0.7, 1.3)})
	for i in 30:
		decor.append({"k": "flower", "p": Vector2(rng.randf() * SIZE.x, rng.randf() * SIZE.y),
			"c": [Color("ffffff"), Color("ffd84a"), Color("f28cb1")][rng.randi() % 3]})
	match terrain:
		"forest":
			for i in 22:
				var p := Vector2(rng.randf_range(240, 480), rng.randf_range(40, 680))
				if i % 3 == 0:
					p.x = rng.randf_range(40, 680)
				_round(p, rng.randf_range(13, 22), "tree")
			for i in 40:
				decor.append({"k": "bush", "p": Vector2(rng.randf() * SIZE.x, rng.randf() * SIZE.y), "s": rng.randf_range(5, 10)})
		"mountain":
			for i in 10:
				_round(Vector2(rng.randf_range(230, 490), rng.randf_range(40, 680)), rng.randf_range(16, 32), "rock")
		"river":
			var bridges := [rng.randf_range(120, 260), rng.randf_range(440, 600)]
			var y := 0.0
			for b in bridges:
				_wall(Rect2(320, y, 80, b - 40 - y), "water")
				obstacles.append({"k": "bridge", "r": Rect2(310, b - 40, 100, 80)})
				y = b + 40
			_wall(Rect2(320, y, 80, SIZE.y - y), "water")
		"castle":
			floor_rect = Rect2(430, 80, 290, 560)
			_wall(Rect2(430, 80, 290, 18), "wall")
			_wall(Rect2(430, 622, 290, 18), "wall")
			_wall(Rect2(430, 98, 18, 150), "wall")
			_wall(Rect2(430, 318, 18, 84), "wall")
			_wall(Rect2(430, 472, 18, 150), "wall")
			_round(Vector2(439, 89), 30, "tower")
			_round(Vector2(439, 631), 30, "tower")
			_round(Vector2(439, 248), 16, "tower")
			_round(Vector2(439, 472), 16, "tower")
			king_home = Vector2(660, 360)
			obstacles.append({"k": "throne", "r": Rect2(672, 330, 40, 60)})
			for i in 260:
				decor.append({"k": "cobble", "p": Vector2(rng.randf_range(450, 715), rng.randf_range(100, 620)), "s": rng.randf_range(8, 14)})
		"town":
			floor_rect = Rect2(420, 60, 300, 600)
			var spots := [Vector2(500, 150), Vector2(620, 220), Vector2(520, 360), Vector2(640, 470), Vector2(510, 560)]
			for p in spots:
				_wall(Rect2(p - Vector2(34, 26), Vector2(68, 52)), "house")
			_wall(Rect2(420, 60, 10, 200), "fence")
			_wall(Rect2(420, 460, 10, 200), "fence")
			king_home = Vector2(600, 360)
		_:
			for i in 3:
				_round(Vector2(rng.randf_range(260, 460), rng.randf_range(80, 640)), rng.randf_range(10, 16), "rock")


func _wall(r: Rect2, kind: String) -> void:
	var b := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	b.add_child(cs)
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.4
	b.physics_material_override = mat
	static_root.add_child(b)
	if kind != "edge":
		obstacles.append({"k": kind, "r": r})


func _round(p: Vector2, r: float, kind: String) -> void:
	var b := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = r
	cs.shape = shape
	b.position = p
	b.add_child(cs)
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.5
	b.physics_material_override = mat
	static_root.add_child(b)
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(p + Vector2.from_angle(i * TAU / 9 + rng.randf() * 0.3) * r * rng.randf_range(0.9, 1.1))
	obstacles.append({"k": kind, "p": p, "rad": r, "pts": pts})


# --------------------------------------------------------------- units

func _spawn_side(soldiers: Array, f: Faction, side: int) -> void:
	var sorted := soldiers.duplicate()
	# leaders and the king stay at the back, melee in front
	sorted.sort_custom(func(a, b): return _rank(a) < _rank(b))
	var n := sorted.size()
	var rows := 10
	var inside := (terrain == "castle" or terrain == "town") and side == 1
	for i in n:
		var s: Soldier = sorted[i]
		var col := i / rows
		var row := i % rows
		var x: float
		if side == 0:
			x = 230.0 - col * 44.0
		elif inside:
			x = 500.0 + col * 40.0
		else:
			x = 490.0 + col * 44.0
		x = clampf(x, 36, 684)
		var y := 360.0 + (row - (mini(rows, n) - 1) * 0.5) * 52.0 + rng.randf_range(-6, 6)
		if s.type == "king" and side == 1 and terrain == "castle":
			x = king_home.x - 40
			y = king_home.y
		var u := Unit.new()
		u.position = Vector2(x, y)
		u.setup(s, f, self, side)
		u.linear_velocity = Vector2(1 if side == 0 else -1, 0) * 60.0
		unit_root.add_child(u)
		u.arm(unit_root)
		units.append(u)


func _rank(s: Soldier) -> int:
	match s.type:
		"king":
			return 9
		"archer", "mage":
			return 7
		"captain", "kingsguard":
			return 5
	return 0


func _alive(side: int) -> int:
	var c := 0
	for u in units:
		if not u.dead and u.side == side:
			c += 1
	return c


func nearest_enemy(me: Unit) -> Unit:
	var best: Unit = null
	var bd := INF
	for u in units:
		if u.dead or u.side == me.side:
			continue
		var d := me.global_position.distance_squared_to(u.global_position)
		if d < bd:
			bd = d
			best = u
	return best


func enemies_near(me: Unit, p: Vector2, r: float) -> Array:
	var out := []
	for u in units:
		if not u.dead and u.side != me.side and u.global_position.distance_to(p) < r + u.radius:
			out.append(u)
	return out


func fire(u: Unit, target: Unit) -> void:
	# projectiles leave the bow/staff in the direction it is pointing
	var m: Transform2D = u.weapon.muzzle()
	var from := m.origin
	var dir := m.x.normalized()
	stat_shots += 1
	if dir.dot(target.global_position - u.global_position) < 0.0:
		stat_back_shots += 1
	if u.ranged == "arrow":
		projectiles.append({"p": from, "v": dir * 560.0, "dmg": u.dmg * 2.2, "from": u, "side": u.side, "k": "arrow", "life": 1.3})
		game.sfx.play("bow", randf_range(0.9, 1.15), 0.05, -8.0)
	else:
		var fireball := u.soldier.level >= 3
		projectiles.append({"p": from, "v": dir * (260.0 if fireball else 330.0), "dmg": u.dmg * (3.0 if fireball else 2.0),
			"from": u, "side": u.side, "k": "fire" if fireball else "magic", "life": 2.2, "target": target})
		game.sfx.play("magic", randf_range(0.9, 1.2), 0.05, -6.0)


func clang(p: Vector2, weapon_on_weapon := true) -> void:
	if weapon_on_weapon:
		stat_clash += 1
	if not weapon_on_weapon:
		game.sfx.play("hit", 1.6, 0.05, -10.0)
		return
	for i in 7:
		fx.append({"p": p, "v": Vector2.from_angle(randf() * TAU) * randf_range(60, 200), "life": 0.25, "max": 0.25, "c": Color("fff2a0"), "s": 2.0})
	game.sfx.play("clang", randf_range(0.85, 1.25), 0.04, -6.0)


func on_hit(victim: Unit, from: Unit, amount: float) -> void:
	stat_hits += 1
	for i in 4:
		fx.append({"p": victim.global_position, "v": Vector2.from_angle(randf() * TAU) * randf_range(40, 160), "life": 0.35, "max": 0.35, "c": victim.color.darkened(0.2), "s": 3.0})
	if amount >= 25.0:
		texts.append({"p": victim.global_position + Vector2(randf_range(-6, 6), -victim.radius - 4), "t": str(int(amount)), "c": Color("ffe9e9"), "life": 0.7, "size": 12})
	if from and not from.dead and from.soldier.add_xp(amount * 0.003):
		_level_up(from)
	game.sfx.play("hit", randf_range(0.8, 1.3), 0.03, -4.0)


func on_unit_died(u: Unit, killer: Unit) -> void:
	corpses.append({"p": u.global_position, "r": u.radius, "c": u.color.darkened(0.55), "rot": u.rotation})
	corpse_layer.queue_redraw()
	for i in 14:
		fx.append({"p": u.global_position, "v": Vector2.from_angle(randf() * TAU) * randf_range(60, 260), "life": 0.6, "max": 0.6, "c": u.color, "s": 4.0})
	u.soldier.hp = 0.0
	units.erase(u)
	u.call_deferred("queue_free")
	game.sfx.play("death", randf_range(0.8, 1.1), 0.05)
	if killer and is_instance_valid(killer):
		var ks := killer.soldier
		ks.kills += 1
		killer.fac.kills += 1
		var gain := 1.0 + u.soldier.level * 0.5 + (2.0 if u.soldier.type in ["king", "captain"] else 0.0)
		texts.append({"p": killer.global_position + Vector2(0, -killer.radius - 14), "t": "+%sxp" % str(gain), "c": Color("d5a6ff"), "life": 0.9, "size": 11})
		if ks.add_xp(gain):
			_level_up(killer)
	var vs := u.soldier
	if vs.is_named():
		var by := _who(killer)
		game.feed("%s has been slain by %s" % [vs.display_name(), by], u.fac.color)
	if vs.type == "king":
		_show_banner("THE KING HAS FALLEN", u.fac.color)
		game.sfx.play("boom")
	_check_end()


func _who(k: Unit) -> String:
	if k == null or not is_instance_valid(k):
		return "the battlefield"
	if k.soldier.is_named():
		return k.soldier.display_name()
	return "a %s %s" % [k.fac.name, k.soldier.type]


func _level_up(u: Unit) -> void:
	var s := u.soldier
	if not s.is_named() and s.level >= 2:
		s.name = Kingdoms.random_name(game.rng)
	u.max_hp = s.max_hp(u.fac)
	u.hp = minf(u.max_hp, u.hp + s.stats()["hp"] * 0.25)
	u.dmg = s.damage(u.fac)
	texts.append({"p": u.global_position + Vector2(0, -u.radius - 22), "t": "LEVEL UP", "c": Color("ffe25a"), "life": 1.4, "size": 16})
	for i in 18:
		fx.append({"p": u.global_position, "v": Vector2.from_angle(i * TAU / 18) * 140.0, "life": 0.5, "max": 0.5, "c": Color("ffe25a"), "s": 3.0})
	if s.is_named():
		game.feed("%s has leveled up! (Lv %d)" % [s.display_name(), s.level], u.fac.color)
	game.sfx.play("levelup")


func _show_banner(t: String, c: Color) -> void:
	banner = t
	banner_col = c
	banner_t = 1.8


func _check_end() -> void:
	if ended:
		return
	var a := _alive(0)
	var d := _alive(1)
	if a == 0 or d == 0:
		_finish(1 if a == 0 else 0, false)


func _finish(winner: int, retreat: bool) -> void:
	ended = true
	if OS.get_cmdline_user_args().has("--autostart"):
		print("battle %s: weapon clashes=%d hits=%d arrows blocked by walls=%d unstuck=%d shots=%d backward=%d time=%.1fs" % [terrain, stat_clash, stat_hits, stat_wall_arrows, stat_escapes, stat_shots, stat_back_shots, elapsed])
	var wf := fac_a if winner == 0 else fac_d
	_show_banner("RETREAT!" if retreat else "VICTORY", wf.color)
	game.sfx.play("win" if not retreat else "horn")
	await get_tree().create_timer(1.6).timeout
	running = false
	var surv := [[], []]
	for u in units:
		if not u.dead:
			u.soldier.hp = u.hp
			if (u.side == 0 and fac_a.has("wisdom")) or (u.side == 1 and fac_d.has("wisdom")):
				u.soldier.add_xp(1.0)
			surv[u.side].append(u.soldier)
	finished.emit({"winner": winner, "retreat": retreat, "survivors_a": surv[0], "survivors_d": surv[1]})


func _physics_process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	if not ended and elapsed > TIME_LIMIT:
		_finish(1, true)
	for i in range(projectiles.size() - 1, -1, -1):
		var pr: Dictionary = projectiles[i]
		pr["life"] -= delta
		if pr["k"] != "arrow" and pr.has("target"):
			var tg = pr["target"]
			if is_instance_valid(tg) and not tg.dead:
				var want: Vector2 = (tg.global_position - pr["p"]).normalized() * pr["v"].length()
				pr["v"] = pr["v"].lerp(want, 0.06)
		var from_p: Vector2 = pr["p"]
		pr["p"] += pr["v"] * delta
		var hit := false
		var q := PhysicsRayQueryParameters2D.create(from_p, pr["p"], Weapon.LAYER_WALL)
		var wall := get_world_2d().direct_space_state.intersect_ray(q)
		if not wall.is_empty():
			if pr["k"] == "fire":
				var src0 = pr["from"]
				_explode(wall["position"], pr["dmg"], pr["side"], src0 if is_instance_valid(src0) and not src0.dead else null)
			elif pr["k"] == "arrow":
				stat_wall_arrows += 1
				stuck.append({"p": wall["position"], "d": pr["v"].normalized(), "life": 4.0})
				game.sfx.play("hit", 2.0, 0.05, -14.0)
			projectiles.remove_at(i)
			continue
		for u in units:
			if u.dead or u.side == pr["side"]:
				continue
			if u.global_position.distance_to(pr["p"]) < u.radius + 3.0:
				var from = pr["from"]
				var src: Unit = from if is_instance_valid(from) and not from.dead else null
				if pr["k"] == "fire":
					_explode(pr["p"], pr["dmg"], pr["side"], src)
				elif src:
					src.deal_damage(u, pr["dmg"], "ranged")
				else:
					u.take_damage(pr["dmg"], null)
				hit = true
				break
		if hit or pr["life"] <= 0.0 or not Rect2(Vector2.ZERO, SIZE).has_point(pr["p"]):
			projectiles.remove_at(i)


func _explode(p: Vector2, dmg: float, side: int, src: Unit) -> void:
	for i in 20:
		fx.append({"p": p, "v": Vector2.from_angle(randf() * TAU) * randf_range(40, 220), "life": 0.5, "max": 0.5, "c": [Color("ff7a1a"), Color("ffd84a")][i % 2], "s": 5.0})
	game.sfx.play("boom", 1.6, 0.05, -8.0)
	for u in units.duplicate():
		if not u.dead and u.side != side and u.global_position.distance_to(p) < 45.0 + u.radius:
			if src and not src.dead:
				src.deal_damage(u, dmg, "ranged")
			else:
				u.take_damage(dmg, null)


func _process(delta: float) -> void:
	banner_t = maxf(0.0, banner_t - delta)
	for i in range(fx.size() - 1, -1, -1):
		var f: Dictionary = fx[i]
		f["life"] -= delta
		f["p"] += f["v"] * delta
		f["v"] *= 0.9
		if f["life"] <= 0.0:
			fx.remove_at(i)
	for i in range(stuck.size() - 1, -1, -1):
		stuck[i]["life"] -= delta
		if stuck[i]["life"] <= 0.0:
			stuck.remove_at(i)
	for i in range(texts.size() - 1, -1, -1):
		var t: Dictionary = texts[i]
		t["life"] -= delta
		t["p"].y -= 22.0 * delta
		if t["life"] <= 0.0:
			texts.remove_at(i)
	shadow_layer.queue_redraw()
	overlay.queue_redraw()


# --------------------------------------------------------------- drawing

## Static terrain: drawn once per battle, not every frame.
func _draw_ground() -> void:
	var g := ground
	g.draw_rect(Rect2(Vector2.ZERO, SIZE), GRASS)
	if floor_rect.size.x > 0:
		g.draw_rect(floor_rect, STONE if terrain == "castle" else Color("d8c79e"))
	for d in decor:
		match d["k"]:
			"tuft":
				var p: Vector2 = d["p"]
				if floor_rect.has_point(p):
					continue
				var s: float = d["s"] * 4.0
				g.draw_line(p, p + Vector2(-s * 0.6, -s), GRASS_DARK, 1.4)
				g.draw_line(p, p + Vector2(0, -s * 1.3), GRASS_DARK, 1.4)
				g.draw_line(p, p + Vector2(s * 0.6, -s), GRASS_DARK, 1.4)
			"flower":
				if not floor_rect.has_point(d["p"]):
					g.draw_circle(d["p"], 2.2, d["c"])
			"bush":
				Ink.circle(g, d["p"], d["s"], Color("8cc463"), 1.4)
			"cobble":
				var cr := Rect2(d["p"], Vector2(d["s"], d["s"] * 0.7))
				g.draw_rect(cr, Color(0.6, 0.58, 0.55, 0.5), false, 1.0)
	for o in obstacles:
		match o["k"]:
			"water":
				var r: Rect2 = o["r"]
				g.draw_rect(r, WATER)
				for k in int(r.size.y / 26):
					var y := r.position.y + 13 + k * 26
					g.draw_arc(Vector2(r.position.x + 25, y), 7, PI * 1.1, PI * 1.9, 6, Color("5a8fc9"), 1.5)
					g.draw_arc(Vector2(r.position.x + 55, y + 10), 7, PI * 1.1, PI * 1.9, 6, Color("5a8fc9"), 1.5)
				g.draw_line(r.position, r.position + Vector2(0, r.size.y), Ink.BLACK, 2.5)
				g.draw_line(r.position + Vector2(r.size.x, 0), r.end, Ink.BLACK, 2.5)
			"bridge":
				var r: Rect2 = o["r"]
				g.draw_rect(r, Color("c79a62"))
				for k in int(r.size.x / 12):
					var x := r.position.x + k * 12
					g.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color("8a5f33"), 1.5)
				g.draw_line(r.position, r.position + Vector2(r.size.x, 0), Ink.BLACK, 3)
				g.draw_line(r.position + Vector2(0, r.size.y), r.end, Ink.BLACK, 3)
			"wall":
				Ink.box(g, o["r"], Color("cfc9bb"), 2.5)
			"house":
				var r: Rect2 = o["r"]
				Ink.box(g, r, Color("b9553f"), 2.5)
				g.draw_line(r.position + Vector2(0, r.size.y * 0.5), r.position + Vector2(r.size.x, r.size.y * 0.5), Ink.BLACK, 2)
				for k in 5:
					var x := r.position.x + (k + 0.5) * r.size.x / 5
					g.draw_line(Vector2(x, r.position.y + 3), Vector2(x, r.end.y - 3), Color(0, 0, 0, 0.25), 1)
			"fence":
				Ink.box(g, o["r"], Color("a8763f"), 2)
			"throne":
				var r: Rect2 = o["r"]
				Ink.box(g, r, Color("b33a3a"), 2)
				g.draw_rect(r.grow(-6), Color("ffcf33"), false, 2)
			"tree":
				Ink.circle(g, o["p"] + Vector2(3, 4), o["rad"], Color(0, 0, 0, 0.15), 0)
				g.draw_colored_polygon(o["pts"], Color("7fb85a"))
				var pts: PackedVector2Array = o["pts"].duplicate()
				pts.append(pts[0])
				g.draw_polyline(pts, Ink.BLACK, 2)
				g.draw_circle(o["p"] + Vector2(-o["rad"] * 0.3, -o["rad"] * 0.3), o["rad"] * 0.35, Color("9fd178"))
			"rock":
				g.draw_colored_polygon(o["pts"], Color("a7a39b"))
				var pts: PackedVector2Array = o["pts"].duplicate()
				pts.append(pts[0])
				g.draw_polyline(pts, Ink.BLACK, 2)
			"tower":
				Ink.circle(g, o["p"], o["rad"], Color("e9e6df"), 2.5)
				g.draw_arc(o["p"], o["rad"] * 0.7, 0, TAU, 20, Color(0.5, 0.5, 0.5), 1.5)
				g.draw_arc(o["p"], o["rad"] * 0.4, 0, TAU, 16, Color(0.5, 0.5, 0.5), 1.5)


## Fallen marbles; redrawn only when someone dies.
func _draw_corpses() -> void:
	for c in corpses:
		Ink.circle(corpse_layer, c["p"], c["r"], c["c"], 1.5)


func _draw_shadows() -> void:
	for u in units:
		if not u.dead:
			shadow_layer.draw_circle(u.global_position + Vector2(3, 4), u.radius, Color(0, 0, 0, 0.18))


func _draw_overlay() -> void:
	var o := overlay
	for a in stuck:
		var d: Vector2 = a["d"]
		var p0: Vector2 = a["p"] - d * 12.0
		o.draw_line(p0, a["p"] + d * 2.0, Color(0.07, 0.07, 0.09, clampf(a["life"], 0, 1)), 2)
		o.draw_line(p0, p0 + d * 4 + d.orthogonal() * 3, Color(1, 1, 1, clampf(a["life"], 0, 1)), 1.5)
	for pr in projectiles:
		var p: Vector2 = pr["p"]
		match pr["k"]:
			"arrow":
				var d: Vector2 = pr["v"].normalized()
				o.draw_line(p - d * 14, p, Ink.BLACK, 2)
				o.draw_line(p - d * 14, p - d * 10 + d.orthogonal() * 3, Color.WHITE, 1.5)
			"magic":
				o.draw_circle(p, 5, Color("b48cff"))
				o.draw_circle(p, 2.5, Color.WHITE)
			"fire":
				o.draw_circle(p, 8, Color("ff7a1a"))
				o.draw_circle(p, 4, Color("ffe066"))
	for f in fx:
		var a: float = f["life"] / f["max"]
		var c: Color = f["c"]
		c.a = a
		o.draw_circle(f["p"], f["s"] * (0.5 + a * 0.5), c)
	for u in units:
		if u.dead:
			continue
		var p: Vector2 = u.global_position
		if u.soldier.type == "king":
			Upgrades.draw_icon(o, "crown", p + Vector2(0, -u.radius - 8), 8, Color.WHITE)
		if u.hp < u.max_hp:
			var w: float = u.radius * 2.2
			var r := Rect2(p + Vector2(-w * 0.5, u.radius + 5), Vector2(w, 4))
			o.draw_rect(r.grow(1), Ink.BLACK)
			o.draw_rect(Rect2(r.position, Vector2(w * clampf(u.hp / u.max_hp, 0, 1), 4)), Color("6ee06e").lerp(Color("e04848"), 1.0 - u.hp / u.max_hp))
		if u.soldier.level > 0:
			Ink.text(o, p + Vector2(0, u.radius + 16), str(u.soldier.level), 11, Color.WHITE, 3)
		if u.soldier.is_named():
			Ink.text(o, p + Vector2(0, -u.radius - (20 if u.soldier.type == "king" else 10)), u.soldier.display_name(), 13, Color.WHITE, 4)
	for t in texts:
		var c: Color = t["c"]
		c.a = clampf(t["life"] * 2.0, 0, 1)
		Ink.text(o, t["p"], t["t"], t["size"], c, 3)
	# header
	o.draw_rect(Rect2(0, 0, SIZE.x, 30), Color(0, 0, 0, 0.45))
	Ink.text(o, Vector2(SIZE.x * 0.5, 14), title, 15, Color.WHITE, 3)
	if fac_a and fac_d:
		Ink.circle(o, Vector2(18, 15), 9, fac_a.color, 2)
		Ink.text_left(o, Vector2(32, 21), str(_alive(0)), 16, Color.WHITE, 3)
		Ink.circle(o, Vector2(SIZE.x - 18, 15), 9, fac_d.color, 2)
		var s := str(_alive(1))
		Ink.text_left(o, Vector2(SIZE.x - 34 - Ink.font().get_string_size(s, 0, -1, 16).x, 21), s, 16, Color.WHITE, 3)
	if banner_t > 0.0:
		var a := clampf(banner_t * 2.0, 0, 1)
		var c := banner_col
		c.a = a
		var sc := 1.0 + (1.8 - banner_t) * 0.06
		Ink.text(o, SIZE * 0.5 + Vector2(0, -40), banner, int(52 * sc), Color(1, 1, 1, a), 10, Color(c.darkened(0.5), a))
