class_name Game
extends Node2D

## Runs one war: the world map, battles, plinko decisions, HUD and victory.

signal back_to_menu
signal play_again

const PANEL := Rect2(0, 0, 720, 720)
const MAP_SMALL_POS := Vector2(726, 196)
const MAP_SMALL_SCALE := 0.412
const BAR_X := 1236.0
const DECISION_EVERY := 75.0

var sfx: Sfx
var rng := RandomNumberGenerator.new()
var config := {}
var factions: Array = []
var NEUTRAL := 0
var BANDITS := 0
var bandits_enabled := true
var world: WorldMap
var battle: Battle
var plinko: Plinko
var battle_box: SubViewportContainer
var plinko_box: SubViewportContainer
var hud: Node2D
var ui: CanvasLayer
var speed_label: Label
var focus := ""
var queue: Array = []
var feed_lines: Array = []
var elapsed := 0.0
var speed := 1.0
var over := false
var ranking: Array = []
var fallen: Array = []
var current := {}
var map_tween: Tween
var winner_panel: Control


func setup(cfg: Dictionary, sound: Sfx) -> void:
	config = cfg
	sfx = sound
	rng.seed = cfg.get("seed", randi())
	bandits_enabled = cfg.get("bandits", true)
	factions.clear()
	for k in cfg["kingdoms"]:
		var f := Faction.new()
		f.id = factions.size()
		var base: Dictionary = Kingdoms.LIST[k["index"]]
		f.name = base["name"]
		f.color = base["color"]
		f.king_name = k["king"]
		f.decision_timer = 22.0 + f.id * 9.0
		factions.append(f)
	NEUTRAL = factions.size()
	BANDITS = factions.size() + 1
	for d in [Kingdoms.NEUTRAL, Kingdoms.BANDITS]:
		var f := Faction.new()
		f.id = factions.size()
		f.name = d["name"]
		f.color = d["color"]
		f.is_kingdom = false
		factions.append(f)

	_build_nodes()
	world.generate(cfg["kingdoms"].size(), cfg.get("towns", 10), rng.seed)
	for i in cfg["kingdoms"].size():
		var city := world.capital(i)
		var f: Faction = factions[i]
		var king := Soldier.create("king", i)
		king.name = f.king_name
		city.garrison.append(king)
		for j in 2:
			city.garrison.append(Soldier.create("kingsguard", i))
		for j in 12:
			city.garrison.append(Soldier.create(world._weighted(WorldMap.CITY_MIX), i))
		var first: Array = []
		for j in 14:
			first.append(Soldier.create(world._weighted(WorldMap.CITY_MIX), i))
		var cap_s := Soldier.create("captain", i)
		cap_s.name = Kingdoms.random_name(rng)
		first.append(cap_s)
		world.spawn_army(city.pos, i, first).immune = 2.5
	world.update_territory()
	world.paused = false
	feed("The war begins! %d kingdoms enter the battlefield." % cfg["kingdoms"].size(), Color.WHITE)
	sfx.play("horn")
	_set_speed(1.0)


func _build_nodes() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = WorldMap.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.game = self
	add_child(world)
	world.encounter.connect(_on_encounter)

	battle_box = _make_box()
	var bvp: SubViewport = battle_box.get_child(0)
	battle = Battle.new()
	battle.game = self
	bvp.add_child(battle)
	battle.finished.connect(_on_battle_finished)

	plinko_box = _make_box()
	var pvp: SubViewport = plinko_box.get_child(0)
	plinko = Plinko.new()
	plinko.game = self
	pvp.add_child(plinko)
	plinko.chosen.connect(_on_plinko_chosen)

	hud = Node2D.new()
	hud.z_index = 50
	hud.draw.connect(_draw_hud)
	add_child(hud)

	ui = CanvasLayer.new()
	add_child(ui)
	var bar := HBoxContainer.new()
	bar.position = Vector2(1236 - 250, 4)
	bar.add_theme_constant_override("separation", 4)
	ui.add_child(bar)
	for s in [["⏸", -1.0], ["1x", 1.0], ["2x", 2.0], ["4x", 4.0]]:
		var b := Button.new()
		b.text = s[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(40, 26)
		var v: float = s[1]
		b.pressed.connect(func(): _set_speed(v) if v > 0 else _toggle_pause())
		bar.add_child(b)
	var menu_b := Button.new()
	menu_b.text = "Menu"
	menu_b.focus_mode = Control.FOCUS_NONE
	menu_b.pressed.connect(func(): back_to_menu.emit())
	bar.add_child(menu_b)
	speed_label = Label.new()
	speed_label.position = Vector2(880, 8)
	speed_label.add_theme_color_override("font_outline_color", Color.BLACK)
	speed_label.add_theme_constant_override("outline_size", 4)
	ui.add_child(speed_label)


func _make_box() -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.position = PANEL.position
	box.size = PANEL.size
	box.stretch = true
	box.visible = false
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.process_mode = Node.PROCESS_MODE_PAUSABLE
	var vp := SubViewport.new()
	vp.size = Vector2i(PANEL.size)
	vp.handle_input_locally = false
	vp.process_mode = Node.PROCESS_MODE_INHERIT
	box.add_child(vp)
	add_child(box)
	return box


# --------------------------------------------------------------- flow

func _process(delta: float) -> void:
	hud.queue_redraw()
	if get_tree().paused:
		speed_label.text = "PAUSED"
		return
	if not over:
		elapsed += delta if focus == "" else 0.0
		if focus == "":
			for f in factions:
				if f.is_kingdom and f.alive:
					f.decision_timer -= delta
					if f.decision_timer <= 0.0:
						f.decision_timer = DECISION_EVERY
						_queue_upgrade(f.id, "Royal Decision", "Periodic decision of the %s" % f.display())
			_next_focus()
	world.paused = focus != "" or over
	speed_label.text = "%dx   %02d:%02d" % [int(speed), int(elapsed) / 60, int(elapsed) % 60]
	for i in range(feed_lines.size() - 1, -1, -1):
		feed_lines[i]["life"] -= delta
		if feed_lines[i]["life"] <= 0.0:
			feed_lines.remove_at(i)


func _next_focus() -> void:
	if focus != "" or queue.is_empty() or over:
		return
	var ev: Dictionary = queue.pop_front()
	match ev["type"]:
		"upgrade":
			var f: Faction = factions[ev["fid"]]
			if not f.alive:
				_next_focus()
				return
			var ids := Upgrades.roll(rng, f, has_king(f.id))
			var opts := ids.map(func(id): return Upgrades.ALL[id])
			current = ev.duplicate()
			current["ids"] = ids
			_show("plinko")
			plinko.start(f, ev["title"], ev["sub"], opts)
		"town":
			var a: WorldMap.Army = ev["army"]
			var s: WorldMap.Settlement = ev["settlement"]
			if not world.armies.has(a) or not world.settlements.has(s):
				_next_focus()
				return
			var f: Faction = factions[a.owner]
			var ids := ["conquer", "raze", "occupy", "plunder"]
			current = ev.duplicate()
			current["ids"] = ids
			_show("plinko")
			plinko.start(f, "Town Decision", "The %s has taken a %s" % [f.display(), "city" if s.kind == "city" else "town"],
				ids.map(func(id): return Upgrades.TOWN[id]))


func _show(what: String) -> void:
	focus = what
	battle_box.visible = what == "battle"
	plinko_box.visible = what == "plinko"
	_tween_map(what != "")


func _end_focus() -> void:
	focus = ""
	world.battle_marker = Vector2(-1, -1)
	if queue.is_empty():
		battle_box.visible = false
		plinko_box.visible = false
		_tween_map(false)
	_check_eliminations()
	_next_focus()


func _tween_map(small: bool) -> void:
	if map_tween:
		map_tween.kill()
	map_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	map_tween.tween_property(world, "position", MAP_SMALL_POS if small else Vector2.ZERO, 0.35)
	map_tween.tween_property(world, "scale", Vector2.ONE * (MAP_SMALL_SCALE if small else 1.0), 0.35)


func _queue_upgrade(fid: int, title: String, sub: String) -> void:
	queue.append({"type": "upgrade", "fid": fid, "title": title, "sub": sub})


# --------------------------------------------------------------- encounters

func _on_encounter(kind: String, a, b) -> void:
	if focus != "" or over:
		return
	match kind:
		"army":
			_start_battle(a, b, null)
		"siege":
			_start_battle(a, null, b)
		"capture":
			world.paused = true
			queue.push_front({"type": "town", "army": a, "settlement": b})
			_next_focus()


func _start_battle(att: WorldMap.Army, def_army: WorldMap.Army, s: WorldMap.Settlement) -> void:
	var fa: Faction = factions[att.owner]
	var defenders: Array
	var fd: Faction
	var where: Vector2
	if s:
		defenders = s.garrison
		fd = factions[s.owner]
		where = s.pos
	else:
		defenders = def_army.soldiers
		fd = factions[def_army.owner]
		where = (att.pos + def_army.pos) * 0.5
	var terr := world.terrain_at(where)
	if s:
		terr = "castle" if s.kind == "city" else "town"
	current = {"type": "battle", "att": att, "def": def_army, "settlement": s}
	world.battle_marker = where
	_show("battle")
	battle.start({
		"terrain": terr, "attackers": att.soldiers, "defenders": defenders, "fac_a": fa, "fac_d": fd,
		"title": "%s  vs  %s  ·  %s" % [fa.display(), fd.display(), terr.capitalize()],
	})


func _on_battle_finished(r: Dictionary) -> void:
	var att: WorldMap.Army = current["att"]
	var def_army: WorldMap.Army = current["def"]
	var s: WorldMap.Settlement = current["settlement"]
	var fa: Faction = factions[att.owner]
	var fd: Faction = factions[def_army.owner if def_army else s.owner]
	_collect_fallen(att.soldiers, r["survivors_a"])
	att.soldiers = r["survivors_a"]
	if def_army:
		_collect_fallen(def_army.soldiers, r["survivors_d"])
		def_army.soldiers = r["survivors_d"]
	else:
		_collect_fallen(s.garrison, r["survivors_d"])
		s.garrison = r["survivors_d"]
	var winner: Faction = fa if r["winner"] == 0 else fd
	var loser: Faction = fd if r["winner"] == 0 else fa
	winner.battles_won += 1
	if r["retreat"]:
		feed("%s retreats from the %s." % [fa.display(), fd.display()], fa.color)
	else:
		feed("%s defeated the %s!" % [winner.display(), loser.display()], winner.color)
	for a in [att, def_army]:
		if a and a.soldiers.is_empty():
			world.armies.erase(a)
	if world.armies.has(att):
		if def_army and world.armies.has(def_army):
			world.bounce_from(att, def_army.pos)
			world.bounce_from(def_army, att.pos)
		elif s:
			world.bounce_from(att, s.pos)
		att.immune = 1.0
	if def_army and world.armies.has(def_army):
		def_army.immune = 1.0
	# rewards
	if not r["retreat"]:
		if loser.id == BANDITS and winner.is_kingdom:
			_queue_upgrade(winner.id, "Bandits Defeated!", "Reward for the %s" % winner.display())
		if s and r["winner"] == 0 and world.armies.has(att):
			queue.push_front({"type": "town", "army": att, "settlement": s})
	_end_focus()


func _collect_fallen(before: Array, after: Array) -> void:
	for sol in before:
		if not after.has(sol) and (sol.is_named() or sol.kills > 0):
			fallen.append(sol)


func _on_plinko_chosen(index: int) -> void:
	var id: String = current["ids"][index]
	if current["type"] == "town":
		_apply_town(id, current["army"], current["settlement"])
	else:
		apply_upgrade(current["fid"], id)
	_end_focus()


func _apply_town(id: String, a: WorldMap.Army, s: WorldMap.Settlement) -> void:
	var f: Faction = factions[a.owner]
	var info: Dictionary = Upgrades.TOWN[id]
	feed("%s chose %s." % [f.display(), info["title"]], f.color)
	var prev: Faction = factions[s.owner]
	match id:
		"conquer":
			s.owner = a.owner
			s.garrison.clear()
			for i in 10:
				s.garrison.append(Soldier.create(s.produce if s.produce != "mix" else "fighter", a.owner))
		"raze":
			world.settlements.erase(s)
			world.popup(s.pos, "RAZED", Color("ff9a4a"))
			sfx.play("boom")
			_queue_upgrade(a.owner, "Spoils of War", "The %s razed a settlement" % f.display())
		"occupy":
			s.owner = a.owner
			s.garrison.clear()
			for sol in a.soldiers:
				sol.hp = sol.max_hp(f)
		"plunder":
			for i in 10:
				if a.soldiers.size() < 40:
					a.soldiers.append(Soldier.create("fighter", a.owner))
	for sol in s.garrison:
		sol.faction = s.owner
	if prev.is_kingdom and id != "plunder":
		feed("The %s lost a %s." % [prev.display(), "city" if s.kind == "city" else "town"], prev.color)
	world.bounce_from(a, s.pos)
	world.update_territory()


func apply_upgrade(fid: int, id: String) -> void:
	var f: Faction = factions[fid]
	var info: Dictionary = Upgrades.ALL[id]
	feed("%s chose %s." % [f.display(), info["title"]], f.color)
	match info["kind"]:
		"buff":
			f.add_upgrade(id)
			if id in ["giant", "vitality"]:
				for sol in all_soldiers(fid):
					sol.hp = sol.max_hp(f)
		"recruit":
			var add: Array = []
			match id:
				"muster":
					for i in 12:
						add.append(Soldier.create(world._weighted(WorldMap.CITY_MIX), fid))
				"farmers":
					for i in 20:
						add.append(Soldier.create("farmer", fid))
				"archers":
					for i in 8:
						add.append(Soldier.create("archer", fid))
				"mage":
					for i in 2:
						add.append(Soldier.create("mage", fid))
				"kingsguard":
					for i in 3:
						add.append(Soldier.create("kingsguard", fid))
				"berserkers":
					for i in 6:
						add.append(Soldier.create("berserker", fid))
			_deliver(fid, add)
		"special":
			match id:
				"town":
					var c := world.capital(fid)
					var p: Vector2 = c.pos if c else _any_army_pos(fid)
					if world.build_town(p, fid):
						feed("The %s founded a new town." % f.display(), f.color)
				"declare":
					_declare_king(fid)


func _deliver(fid: int, add: Array) -> void:
	var c := world.capital(fid)
	if c:
		c.garrison.append_array(add)
		world.popup(c.pos + Vector2(0, -26), "+%d" % add.size(), factions[fid].color.lightened(0.5))
		return
	var best: WorldMap.Army = null
	for a in world.armies:
		if a.owner == fid and (best == null or a.soldiers.size() < best.soldiers.size()):
			best = a
	if best:
		best.soldiers.append_array(add)
	else:
		world.spawn_army(Vector2(rng.randf_range(100, 1100), rng.randf_range(100, 600)), fid, add)


func _any_army_pos(fid: int) -> Vector2:
	for a in world.armies:
		if a.owner == fid:
			return a.pos
	return WorldMap.SIZE * 0.5


func _declare_king(fid: int) -> void:
	var best: Soldier = null
	var holder: Array = []
	for a in world.armies:
		if a.owner == fid:
			for sol in a.soldiers:
				if best == null or sol.level > best.level or (sol.level == best.level and sol.power() > best.power()):
					best = sol
					holder = a.soldiers
	for s in world.settlements:
		if s.owner == fid:
			for sol in s.garrison:
				if best == null or sol.level > best.level or (sol.level == best.level and sol.power() > best.power()):
					best = sol
					holder = s.garrison
	if best == null:
		return
	if best.name == "":
		best.name = Kingdoms.random_name(rng)
	best.name = best.name + " " + Kingdoms.roman(rng.randi_range(1, 12))
	best.type = "king"
	best.hp = best.max_hp(factions[fid])
	for i in 2:
		holder.append(Soldier.create("kingsguard", fid))
	feed("%s has been crowned!" % best.display_name(), factions[fid].color)
	sfx.play("win")


func all_soldiers(fid: int) -> Array:
	var out: Array = []
	for a in world.armies:
		if a.owner == fid:
			out.append_array(a.soldiers)
	for s in world.settlements:
		if s.owner == fid:
			out.append_array(s.garrison)
	return out


func has_king(fid: int) -> bool:
	for sol in all_soldiers(fid):
		if sol.type == "king":
			return true
	return false


func _check_eliminations() -> void:
	var alive: Array = []
	for f in factions:
		if not f.is_kingdom or not f.alive:
			continue
		if world.soldier_total(f.id) == 0:
			f.alive = false
			f.eliminated_at = elapsed
			ranking.push_front(f)
			for s in world.settlements:
				if s.owner == f.id:
					s.owner = NEUTRAL
			for a in world.armies.duplicate():
				if a.owner == f.id:
					world.armies.erase(a)
			world.update_territory()
			feed("The %s has been eliminated!" % f.display(), f.color)
			sfx.play("boom")
		else:
			alive.append(f)
	if alive.size() == 1 and not over:
		_victory(alive[0])


func _victory(f: Faction) -> void:
	over = true
	ranking.push_front(f)
	feed("The %s is victorious!" % f.display(), f.color)
	sfx.play("win")
	_tween_map(false)
	battle_box.visible = false
	plinko_box.visible = false
	winner_panel = preload("res://scripts/victory.gd").new()
	winner_panel.build(self, f)
	ui.add_child(winner_panel)


func feed(text: String, col: Color) -> void:
	feed_lines.append({"t": text, "c": col, "life": 10.0})
	if feed_lines.size() > 7:
		feed_lines.pop_front()


# --------------------------------------------------------------- controls

static func low_power() -> bool:
	return OS.has_feature("web") or OS.has_feature("mobile") or "--lowpower" in OS.get_cmdline_user_args()


func _set_speed(v: float) -> void:
	speed = v
	get_tree().paused = false
	Engine.time_scale = v
	if low_power():
		# browsers/tablets run single-threaded: fewer physics steps, and never
		# more than a few per frame so a slow frame can't snowball into a freeze
		Engine.physics_ticks_per_second = int(120 * minf(v, 2.0))
		Engine.max_physics_steps_per_frame = 4
	else:
		Engine.physics_ticks_per_second = int(240 * v)
		Engine.max_physics_steps_per_frame = 12 * int(v)
	sfx.play("click")


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	sfx.play("click")


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE:
				_toggle_pause()
			KEY_1:
				_set_speed(1.0)
			KEY_2:
				_set_speed(2.0)
			KEY_3, KEY_4:
				_set_speed(4.0)
			KEY_M:
				sfx.muted = not sfx.muted
			KEY_ESCAPE:
				back_to_menu.emit()


# --------------------------------------------------------------- HUD

func _draw_hud() -> void:
	var c := hud
	c.draw_rect(Rect2(BAR_X, 0, 1280 - BAR_X, 720), Color("15161b"))
	var list: Array = factions.filter(func(f): return f.is_kingdom)
	list.sort_custom(func(a, b): return _strength(a) > _strength(b))
	var h := minf(46.0, 700.0 / maxf(1, list.size()))
	for i in list.size():
		var f: Faction = list[i]
		var r := Rect2(BAR_X + 4, 6 + i * h, 1280 - BAR_X - 8, h - 6)
		var col: Color = f.color if f.alive else f.color.darkened(0.7)
		Ink.box(c, r, col, 1.5)
		var n := world.soldier_total(f.id) if f.alive else 0
		Ink.text(c, r.get_center(), str(n) if f.alive else "✕", 13, Color.WHITE, 3)
		if f.alive and has_king(f.id):
			Upgrades.draw_icon(c, "crown", r.position + Vector2(r.size.x - 6, 6), 5, Color.WHITE)
	# event feed (bottom right, like the videos)
	var x0 := 728.0 if focus != "" else 820.0
	var y := 712.0
	for i in range(feed_lines.size() - 1, -1, -1):
		var l: Dictionary = feed_lines[i]
		var col: Color = l["c"].lightened(0.25)
		col.a = clampf(l["life"], 0, 1)
		var fs := 14
		var w := Ink.font().get_string_size(l["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		Ink.text_left(c, Vector2(minf(BAR_X - 8 - w, BAR_X - 8 - w) if w < BAR_X - x0 else x0, y), l["t"], fs, col, 4)
		y -= 19.0
	if focus != "" and not over:
		Ink.text(c, Vector2(726 + 254, 180), "WORLD MAP", 14, Color(1, 1, 1, 0.7), 3)


func _strength(f: Faction) -> float:
	return world.soldier_total(f.id) + (10000.0 if f.alive else f.eliminated_at)
