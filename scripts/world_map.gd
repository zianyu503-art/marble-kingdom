class_name WorldMap
extends Node2D

## The World Map: settlements, roaming armies and landmarks. Armies bounce
## around randomly; touching an enemy army or settlement raises `encounter`.

signal encounter(kind: String, a, b)

const SIZE := Vector2(1232, 720)
const CITY_HALF := 15.0
const TOWN_HALF := 10.0
const ARMY_SPEED := 30.0
const CITY_MIX := {"fighter": 38, "footman": 20, "spearman": 20, "archer": 15, "knight": 5, "berserker": 2}
const TOWN_TYPES := ["spearman", "archer", "berserker", "hammerman", "knight", "footman", "farmer"]


class Settlement:
	var id := 0
	var pos := Vector2.ZERO
	var kind := "town"
	var owner := -1
	var garrison: Array = []
	var produce := "fighter"
	var timer := 0.0
	var pop_t := 0.0
	var pop_text := ""

	func half() -> float:
		return CITY_HALF if kind == "city" else TOWN_HALF

	func has_king() -> bool:
		for s in garrison:
			if s.type == "king":
				return true
		return false


class Army:
	var id := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var owner := -1
	var soldiers: Array = []
	var turn := 0.0
	var immune := 0.0
	var trail: Array = []

	func radius() -> float:
		return 7.0 + sqrt(float(soldiers.size())) * 1.3

	func leader() -> Soldier:
		var best: Soldier = null
		for s in soldiers:
			if s.type == "king":
				return s
			if s.is_named() and (best == null or s.level > best.level):
				best = s
		return best


var game: Node
var rng := RandomNumberGenerator.new()
var settlements: Array = []
var armies: Array = []
var mountains: Array = []
var forests: Array = []
var roads: Array = []
var river: PackedVector2Array
var camps: Array = []
var popups: Array = []
var paused := true
var battle_marker := Vector2(-1, -1)
var next_id := 1
var camp_timer := 25.0
var bg: ColorRect
var ink_layer: Node2D
## The parchment, territories and fixed landmarks are rendered once into this
## viewport and shown as a texture; it is re-rendered only when borders change.
var bake_vp: SubViewport
var static_layer: Node2D


func _ready() -> void:
	bake_vp = SubViewport.new()
	bake_vp.size = Vector2i(SIZE)
	bake_vp.disable_3d = true
	bake_vp.transparent_bg = false
	bake_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(bake_vp)
	bg = ColorRect.new()
	bg.size = SIZE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/territory.gdshader")
	bg.material = mat
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bake_vp.add_child(bg)
	static_layer = Node2D.new()
	static_layer.draw.connect(_draw_static)
	bake_vp.add_child(static_layer)
	var baked := Sprite2D.new()
	baked.centered = false
	baked.texture = bake_vp.get_texture()
	baked.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(baked)
	ink_layer = Node2D.new()
	ink_layer.draw.connect(_draw_ink)
	add_child(ink_layer)


# --------------------------------------------------------------- generation

func generate(kingdom_count: int, town_count: int, seed_value: int) -> void:
	rng.seed = seed_value
	settlements.clear()
	armies.clear()
	mountains.clear()
	forests.clear()
	roads.clear()
	camps.clear()
	popups.clear()
	var placed: Array = []
	# capitals spread out around the map
	var caps: Array = []
	var attempts := 0
	while caps.size() < kingdom_count and attempts < 4000:
		attempts += 1
		var p := Vector2(rng.randf_range(90, SIZE.x - 90), rng.randf_range(80, SIZE.y - 80))
		var min_d := 900.0 / sqrt(float(kingdom_count)) - attempts * 0.05
		if _far(p, caps, min_d):
			caps.append(p)
	for i in caps.size():
		var s := _add_settlement(caps[i], "city", i)
		s.produce = "mix"
		placed.append(caps[i])
	for i in town_count:
		for k in 300:
			var p := Vector2(rng.randf_range(50, SIZE.x - 50), rng.randf_range(50, SIZE.y - 50))
			if _far(p, placed, 95.0):
				var s := _add_settlement(p, "town", game.NEUTRAL)
				s.produce = TOWN_TYPES[rng.randi() % TOWN_TYPES.size()]
				for j in rng.randi_range(5, 9):
					s.garrison.append(Soldier.create("villager", game.NEUTRAL))
				placed.append(p)
				break
	# river: a wobbly line across the map
	river = PackedVector2Array()
	var y0 := rng.randf_range(150, SIZE.y - 150)
	for i in 40:
		var x := -20.0 + i * (SIZE.x + 40) / 39.0
		river.append(Vector2(x, y0 + sin(i * 0.45 + rng.randf()) * 60.0 + rng.randf_range(-8, 8)))
	# roads between nearby settlements
	for s in settlements:
		var near := _nearest_settlement(s, 2)
		for o in near:
			if s.id < o.id:
				roads.append([s.pos, o.pos, rng.randf() * 10.0])
	for i in rng.randi_range(5, 8):
		var c := Vector2(rng.randf_range(40, SIZE.x - 40), rng.randf_range(40, SIZE.y - 40))
		for k in rng.randi_range(4, 9):
			var p := c + Vector2(rng.randf_range(-70, 70), rng.randf_range(-40, 40))
			if _far(p, placed, 34.0):
				mountains.append({"p": p, "s": rng.randf_range(11, 18)})
	for i in rng.randi_range(6, 10):
		var c := Vector2(rng.randf_range(40, SIZE.x - 40), rng.randf_range(40, SIZE.y - 40))
		for k in rng.randi_range(6, 14):
			var p := c + Vector2(rng.randf_range(-55, 55), rng.randf_range(-35, 35))
			if _far(p, placed, 26.0):
				forests.append({"p": p, "s": rng.randf_range(5, 8)})
	if game.bandits_enabled:
		for i in 2:
			for k in 200:
				var p := Vector2(rng.randf_range(60, SIZE.x - 60), rng.randf_range(60, SIZE.y - 60))
				if _far(p, placed, 120.0):
					camps.append(p)
					break
	update_territory()


func _far(p: Vector2, list: Array, d: float) -> bool:
	for q in list:
		if p.distance_to(q) < d:
			return false
	return true


func _add_settlement(p: Vector2, kind: String, owner: int) -> Settlement:
	var s := Settlement.new()
	s.id = next_id
	next_id += 1
	s.pos = p
	s.kind = kind
	s.owner = owner
	s.timer = rng.randf_range(0, 2)
	settlements.append(s)
	return s


func build_town(near: Vector2, owner: int) -> Settlement:
	for k in 200:
		var p := near + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(70, 150)
		if Rect2(Vector2(40, 40), SIZE - Vector2(80, 80)).has_point(p):
			var pts := settlements.map(func(s): return s.pos)
			if _far(p, pts, 70.0):
				var s := _add_settlement(p, "town", owner)
				s.produce = TOWN_TYPES[rng.randi() % TOWN_TYPES.size()]
				update_territory()
				return s
	return null


func _nearest_settlement(s: Settlement, n: int) -> Array:
	var others := settlements.filter(func(o): return o != s)
	others.sort_custom(func(a, b): return a.pos.distance_to(s.pos) < b.pos.distance_to(s.pos))
	return others.slice(0, n)


func update_territory() -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var rads := PackedFloat32Array()
	var owners := PackedFloat32Array()
	for s in settlements:
		if pts.size() >= 64:
			break
		pts.append(s.pos)
		var f: Faction = game.factions[s.owner]
		cols.append(f.color)
		rads.append(150.0 if s.kind == "city" else 85.0)
		owners.append(float(s.owner) if f.is_kingdom else -1.0)
	var m: ShaderMaterial = bg.material
	m.set_shader_parameter("count", pts.size())
	m.set_shader_parameter("pts", pts)
	m.set_shader_parameter("cols", cols)
	m.set_shader_parameter("rads", rads)
	m.set_shader_parameter("owners", owners)
	static_layer.queue_redraw()
	bake_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Which battle terrain applies at point p.
func terrain_at(p: Vector2) -> String:
	for s in settlements:
		if s.pos.distance_to(p) < s.half() + 22.0:
			return "castle" if s.kind == "city" else "town"
	for f in forests:
		if f["p"].distance_to(p) < 30.0:
			return "forest"
	for m in mountains:
		if m["p"].distance_to(p) < 30.0:
			return "mountain"
	for i in river.size() - 1:
		if Geometry2D.get_closest_point_to_segment(p, river[i], river[i + 1]).distance_to(p) < 18.0:
			return "river"
	return "field"


# --------------------------------------------------------------- armies

func spawn_army(pos: Vector2, owner: int, soldiers: Array) -> Army:
	var a := Army.new()
	a.id = next_id
	next_id += 1
	a.pos = pos
	a.owner = owner
	a.soldiers = soldiers
	a.vel = Vector2.from_angle(rng.randf() * TAU) * ARMY_SPEED
	a.turn = rng.randf_range(-0.3, 0.3)
	a.immune = 1.0
	armies.append(a)
	return a


func army_count(owner: int) -> int:
	var c := 0
	for a in armies:
		if a.owner == owner:
			c += 1
	return c


func soldier_total(owner: int) -> int:
	var c := 0
	for a in armies:
		if a.owner == owner:
			c += a.soldiers.size()
	for s in settlements:
		if s.owner == owner:
			c += s.garrison.size()
	return c


func capital(owner: int) -> Settlement:
	for s in settlements:
		if s.owner == owner and s.kind == "city":
			return s
	for s in settlements:
		if s.owner == owner:
			return s
	return null


func popup(p: Vector2, t: String, c := Color.WHITE) -> void:
	popups.append({"p": p, "t": t, "c": c, "life": 1.2})


func can_fight(o1: int, o2: int) -> bool:
	if o1 == o2:
		return false
	var n: int = game.NEUTRAL
	var b: int = game.BANDITS
	if (o1 == n or o1 == b) and (o2 == n or o2 == b):
		return false
	return true


func _process(delta: float) -> void:
	for i in range(popups.size() - 1, -1, -1):
		popups[i]["life"] -= delta
		popups[i]["p"].y -= 14.0 * delta
		if popups[i]["life"] <= 0.0:
			popups.remove_at(i)
	if not paused:
		_simulate(delta)
	ink_layer.queue_redraw()


func _simulate(delta: float) -> void:
	_produce(delta)
	_bandits(delta)
	for a in armies:
		_move(a, delta)
	_collide()


func _produce(delta: float) -> void:
	for s in settlements:
		var f: Faction = game.factions[s.owner]
		var neutral: bool = s.owner == game.NEUTRAL
		var rate := 2.6 if s.kind == "city" else (9.0 if neutral else 4.5)
		var cap := 40 if s.kind == "city" else (12 if neutral else 20)
		s.timer += delta
		if s.timer >= rate:
			s.timer = 0.0
			if s.garrison.size() < cap:
				var t: String = "villager" if neutral else s.produce
				if t == "mix":
					t = _weighted(CITY_MIX)
				s.garrison.append(Soldier.create(t, s.owner))
				s.pop_t = 1.0
				popup(s.pos + Vector2(14, -14), "+1", f.color.lightened(0.5))
		# muster a new army from a full city
		if f.is_kingdom and s.kind == "city" and s.garrison.size() >= 26 and army_count(s.owner) < 3:
			var out: Array = []
			for sol in s.garrison.duplicate():
				if sol.type in ["king", "kingsguard"]:
					continue
				out.append(sol)
				s.garrison.erase(sol)
				if out.size() >= 16:
					break
			var cap_s := Soldier.create("captain", s.owner)
			cap_s.name = Kingdoms.random_name(rng)
			out.append(cap_s)
			var a := spawn_army(s.pos, s.owner, out)
			a.immune = 2.0
			popup(s.pos + Vector2(0, -24), "MUSTER", Color.WHITE)


func _weighted(d: Dictionary) -> String:
	var total := 0
	for k in d:
		total += d[k]
	var r := rng.randi() % total
	for k in d:
		r -= d[k]
		if r < 0:
			return k
	return d.keys()[0]


func _bandits(delta: float) -> void:
	if camps.is_empty():
		return
	camp_timer -= delta
	if camp_timer <= 0.0:
		camp_timer = rng.randf_range(45, 70)
		if army_count(game.BANDITS) < 2:
			var p: Vector2 = camps[rng.randi() % camps.size()]
			var list: Array = []
			for i in rng.randi_range(8, 14):
				list.append(Soldier.create("bandit", game.BANDITS))
			var cap_s := Soldier.create("captain", game.BANDITS)
			cap_s.name = Kingdoms.random_name(rng)
			list.append(cap_s)
			spawn_army(p, game.BANDITS, list)
			game.feed("Bandits have spawned. Destroy them to receive a reward!", Color("d0d0d0"))


func _move(a: Army, delta: float) -> void:
	var f: Faction = game.factions[a.owner]
	var speed := ARMY_SPEED * f.speed_mult()
	a.immune = maxf(0.0, a.immune - delta)
	# smooth random wander: the turning rate itself drifts slowly
	a.turn = clampf(a.turn + rng.randf_range(-1.2, 1.2) * delta, -0.6, 0.6)
	a.vel = a.vel.rotated(a.turn * delta)
	if f.has("seek"):
		var tgt := _nearest_target(a)
		if tgt != Vector2.INF:
			a.vel = a.vel.lerp((tgt - a.pos).normalized() * speed, 0.02)
	a.vel = a.vel.normalized() * speed
	a.pos += a.vel * delta
	var r := a.radius()
	if a.pos.x < r and a.vel.x < 0 or a.pos.x > SIZE.x - r and a.vel.x > 0:
		a.vel.x = -a.vel.x
	if a.pos.y < r and a.vel.y < 0 or a.pos.y > SIZE.y - r and a.vel.y > 0:
		a.vel.y = -a.vel.y
	a.pos = a.pos.clamp(Vector2(r, r), SIZE - Vector2(r, r))
	a.trail.append(a.pos)
	if a.trail.size() > 26:
		a.trail.pop_front()


func _nearest_target(a: Army) -> Vector2:
	var best := Vector2.INF
	var bd := 320.0
	for o in armies:
		if o != a and can_fight(a.owner, o.owner) and o.pos.distance_to(a.pos) < bd:
			bd = o.pos.distance_to(a.pos)
			best = o.pos
	for s in settlements:
		if can_fight(a.owner, s.owner) and s.pos.distance_to(a.pos) < bd:
			bd = s.pos.distance_to(a.pos)
			best = s.pos
	return best


func _collide() -> void:
	for i in armies.size():
		var a: Army = armies[i]
		if a.immune > 0.0:
			continue
		for j in range(i + 1, armies.size()):
			var b: Army = armies[j]
			if b.immune > 0.0 or not can_fight(a.owner, b.owner):
				continue
			if a.pos.distance_to(b.pos) < a.radius() + b.radius():
				encounter.emit("army", a, b)
				return
		for s in settlements:
			var d: Vector2 = (a.pos - s.pos).abs()
			var lim: float = s.half() + a.radius() * 0.8
			if d.x > lim or d.y > lim:
				continue
			if s.owner == a.owner:
				_reinforce(a, s)
			elif not can_fight(a.owner, s.owner):
				bounce_from(a, s.pos)
			elif s.garrison.is_empty():
				encounter.emit("capture", a, s)
				return
			else:
				encounter.emit("siege", a, s)
				return


func _reinforce(a: Army, s: Settlement) -> void:
	var f: Faction = game.factions[a.owner]
	var moved := 0
	var keep := 6 if s.kind == "city" else 3
	for sol in s.garrison.duplicate():
		if a.soldiers.size() >= 40 or s.garrison.size() <= keep:
			break
		if sol.type in ["king", "kingsguard"]:
			continue
		s.garrison.erase(sol)
		a.soldiers.append(sol)
		moved += 1
	for sol in a.soldiers:
		sol.hp = sol.max_hp(f)
	if moved > 0:
		popup(a.pos + Vector2(0, -16), "+%d" % moved, f.color.lightened(0.5))
	bounce_from(a, s.pos)


func bounce_from(a: Army, p: Vector2) -> void:
	var away := a.pos - p
	if away.length() < 0.01:
		away = Vector2.from_angle(rng.randf() * TAU)
	a.vel = away.normalized().rotated(rng.randf_range(-0.5, 0.5)) * ARMY_SPEED
	a.pos += a.vel.normalized() * 6.0
	a.immune = 0.6


# --------------------------------------------------------------- drawing

## River, roads, mountains, forests and camps (baked, see bake_vp).
func _draw_static() -> void:
	var c := static_layer
	var ink := Ink.BLACK
	# river
	if river.size() > 1:
		c.draw_polyline(river, ink, 13.0, true)
		c.draw_polyline(river, Color("9cc6ef"), 9.0, true)
	# roads: dashed double lines
	for r in roads:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var n := (b - a).normalized().orthogonal() * 3.0
		var steps := int(a.distance_to(b) / 10.0)
		for k in steps:
			if k % 2 == 0:
				var p0 := a.lerp(b, float(k) / steps)
				var p1 := a.lerp(b, float(k + 1) / steps)
				c.draw_line(p0 + n, p1 + n, Color(0.35, 0.25, 0.15, 0.55), 1.3)
				c.draw_line(p0 - n, p1 - n, Color(0.35, 0.25, 0.15, 0.55), 1.3)
	for m in mountains:
		var p: Vector2 = m["p"]
		var s: float = m["s"]
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-s, s * 0.5), p + Vector2(0, -s * 0.8), p + Vector2(s, s * 0.5)]), Color(0.93, 0.86, 0.7))
		c.draw_polyline(PackedVector2Array([p + Vector2(-s, s * 0.5), p + Vector2(0, -s * 0.8), p + Vector2(s, s * 0.5)]), ink, 1.6)
		c.draw_line(p + Vector2(0, -s * 0.8), p + Vector2(s * 0.25, s * 0.5), Color(0, 0, 0, 0.35), 1.2)
	for f in forests:
		var p: Vector2 = f["p"]
		var s: float = f["s"]
		c.draw_line(p, p + Vector2(0, s * 0.9), ink, 1.4)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.7, s * 0.3), p + Vector2(0, -s), p + Vector2(s * 0.7, s * 0.3)]), Color(0.93, 0.86, 0.7))
		c.draw_polyline(PackedVector2Array([p + Vector2(-s * 0.7, s * 0.3), p + Vector2(0, -s), p + Vector2(s * 0.7, s * 0.3), p + Vector2(-s * 0.7, s * 0.3)]), ink, 1.3)
	for p in camps:
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 8), p + Vector2(0, -10), p + Vector2(12, 8)]), Color("6d5a48"))
		c.draw_polyline(PackedVector2Array([p + Vector2(-12, 8), p + Vector2(0, -10), p + Vector2(12, 8), p + Vector2(-12, 8)]), ink, 1.6)
		c.draw_line(p + Vector2(0, -10), p + Vector2(0, -18), ink, 1.5)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -18), p + Vector2(8, -15), p + Vector2(0, -12)]), Color("b03030"))


func _draw_ink() -> void:
	var c := ink_layer
	for s in settlements:
		_draw_settlement(c, s)
	for a in armies:
		var f: Faction = game.factions[a.owner]
		for k in range(0, a.trail.size(), 3):
			c.draw_circle(a.trail[k], 1.3, Color(f.color.darkened(0.3), 0.35))
	for a in armies:
		_draw_army(c, a)
	if battle_marker.x >= 0:
		var t := Time.get_ticks_msec() / 1000.0
		var r := 22.0 + fmod(t * 30.0, 22.0)
		c.draw_arc(battle_marker, r, 0, TAU, 32, Color(1, 1, 1, 1.0 - (r - 22.0) / 22.0), 3.0)
		c.draw_arc(battle_marker, 22.0, 0, TAU, 32, Color.WHITE, 2.0)
	for p in popups:
		var col: Color = p["c"]
		col.a = clampf(p["life"] * 1.5, 0, 1)
		Ink.text(c, p["p"], p["t"], 12, col, 3)


func _draw_settlement(c: CanvasItem, s: Settlement) -> void:
	var f: Faction = game.factions[s.owner]
	var h := s.half()
	var bump := 1.0 + s.pop_t * 0.0
	var r := Rect2(s.pos - Vector2(h, h) * bump, Vector2(h, h) * 2.0 * bump)
	c.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.25))
	Ink.box(c, r, f.color, 2.2)
	if s.kind == "city":
		# little keep with battlements
		var k := Rect2(s.pos + Vector2(-7, -4), Vector2(14, 11))
		c.draw_rect(k, Color(1, 1, 1, 0.85))
		c.draw_rect(k, Ink.BLACK, false, 1.2)
		for i in 3:
			c.draw_rect(Rect2(s.pos + Vector2(-7 + i * 5.5, -8), Vector2(3, 4)), Ink.BLACK)
		var label := ""
		for sol in s.garrison:
			if sol.type == "king":
				label = sol.display_name()
		if label == "" and f.is_kingdom:
			label = f.name
		Ink.text(c, s.pos + Vector2(0, -h - 10), label, 12, Color.WHITE, 4)
	else:
		Ink.text(c, s.pos + Vector2(0, -h - 6), s.produce.capitalize() if s.owner != game.NEUTRAL else "", 9, Color(1, 1, 1, 0.9), 3)
	Ink.text(c, s.pos + Vector2(0, h + 9), str(s.garrison.size()), 12, Color.WHITE, 4)


func _draw_army(c: CanvasItem, a: Army) -> void:
	var f: Faction = game.factions[a.owner]
	var r := a.radius()
	c.draw_circle(a.pos + Vector2(2, 3), r, Color(0, 0, 0, 0.25))
	Ink.circle(c, a.pos, r, f.color, 2.2)
	Ink.text(c, a.pos, str(a.soldiers.size()), 12, Color.WHITE, 4)
	var l := a.leader()
	if l:
		if l.type == "king":
			Upgrades.draw_icon(c, "crown", a.pos + Vector2(0, -r - 6), 6, Color.WHITE)
		Ink.text(c, a.pos + Vector2(0, -r - (16 if l.type == "king" else 8)), l.display_name(), 11, Color.WHITE, 3)
