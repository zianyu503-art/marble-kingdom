extends Node2D

## Arena: pick any units for two sides, their level, upgrades and the terrain,
## then watch them fight with the normal battle system.

signal back_to_menu

const TYPES := ["fighter", "footman", "spearman", "knight", "berserker", "hammerman", "archer", "crossbowman",
	"mage", "monk", "bard", "necromancer", "farmer", "kingsguard", "captain", "king", "bandit", "villager"]
const UPS := ["sharp", "regen", "giant", "haste", "vitality", "armor", "vampirism", "spectral", "dash", "thorns", "volley", "whirl"]
const TERRAINS := ["field", "forest", "mountain", "river", "castle", "town", "lake"]
const MAX_UNITS := 60

static var cfg := {}

var sfx: Sfx
var rng := RandomNumberGenerator.new()
var setup_ui: Control
var fight_ui: Control
var side_ui: Array = []
var terrain_opt: OptionButton
var fight_btn: Button
var warn: Label
var battle: Battle
var box: SubViewportContainer
var hud: Node2D
var facs: Array = []
var rosters: Array = []
var feed_lines: Array = []
var result := {}
var speed := 1.0


func setup(sound: Sfx) -> void:
	sfx = sound
	rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if cfg.is_empty():
		cfg = {"terrain": 0, "sides": [_default_side(0), _default_side(1)]}
	_build_setup()


func _default_side(i: int) -> Dictionary:
	return {"color": i, "level": 0, "ups": {}, "units": {"fighter": 6, "spearman": 4, "archer": 4, "captain": 1}}


# --------------------------------------------------------------- setup screen

func _build_setup() -> void:
	setup_ui = Control.new()
	setup_ui.size = Vector2(1280, 720)
	add_child(setup_ui)
	var bg := ColorRect.new()
	bg.size = setup_ui.size
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/territory.gdshader")
	mat.set_shader_parameter("map_size", Vector2(1280, 720))
	bg.material = mat
	setup_ui.add_child(bg)
	var title := _label("ARENA", 40, Color("ffd84a"))
	title.position = Vector2(560, 6)
	setup_ui.add_child(title)
	side_ui.clear()
	for i in 2:
		side_ui.append(_build_side(i, Vector2(16 + i * 632, 62)))

	var bar := HBoxContainer.new()
	bar.position = Vector2(16, 660)
	bar.add_theme_constant_override("separation", 10)
	setup_ui.add_child(bar)
	bar.add_child(_label("Terrain", 18, Color.WHITE))
	terrain_opt = OptionButton.new()
	for t in TERRAINS:
		terrain_opt.add_item(t.capitalize())
	terrain_opt.select(cfg["terrain"])
	bar.add_child(terrain_opt)
	for b in [["Copy A → B", "copy"], ["Random", "random"], ["Clear", "clear"], ["Menu", "menu"]]:
		var btn := Button.new()
		btn.text = b[0]
		var act: String = b[1]
		btn.pressed.connect(func(): _action(act))
		bar.add_child(btn)
	warn = _label("", 16, Color("ffb0a0"))
	bar.add_child(warn)
	fight_btn = Button.new()
	fight_btn.text = "  FIGHT!  "
	fight_btn.add_theme_font_size_override("font_size", 26)
	fight_btn.position = Vector2(1080, 650)
	fight_btn.size = Vector2(184, 56)
	fight_btn.pressed.connect(_fight)
	setup_ui.add_child(fight_btn)
	_refresh()


func _build_side(i: int, pos: Vector2) -> Dictionary:
	var sd: Dictionary = cfg["sides"][i]
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = Vector2(616, 580)
	setup_ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_child(_label("Side %s" % ["A", "B"][i], 22, Color.WHITE))
	var col := OptionButton.new()
	for k in Kingdoms.LIST:
		col.add_item(k["name"] + " Kingdom")
	col.select(sd["color"])
	col.item_selected.connect(func(_x): _refresh())
	top.add_child(col)
	var total := _label("", 18, Color.WHITE)
	top.add_child(total)
	v.add_child(top)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	var spins := {}
	for t in TYPES:
		var h := HBoxContainer.new()
		var l := _label(t.capitalize(), 15, Color.WHITE)
		l.custom_minimum_size = Vector2(96, 0)
		h.add_child(l)
		var sp := SpinBox.new()
		sp.max_value = 40
		sp.value = sd["units"].get(t, 0)
		sp.value_changed.connect(func(_x): _refresh())
		h.add_child(sp)
		grid.add_child(h)
		spins[t] = sp
	v.add_child(grid)
	var lv := HBoxContainer.new()
	lv.add_child(_label("Level", 18, Color.WHITE))
	var lvl := SpinBox.new()
	lvl.max_value = 10
	lvl.value = sd["level"]
	lv.add_child(lvl)
	v.add_child(lv)
	v.add_child(_label("Upgrades", 18, Color.WHITE))
	var ugrid := GridContainer.new()
	ugrid.columns = 4
	var checks := {}
	for u in UPS:
		var c := CheckBox.new()
		c.text = Upgrades.ALL[u]["title"]
		c.tooltip_text = Upgrades.ALL[u]["desc"]
		c.button_pressed = sd["ups"].get(u, false)
		ugrid.add_child(c)
		checks[u] = c
	v.add_child(ugrid)
	return {"panel": panel, "color": col, "spins": spins, "level": lvl, "checks": checks, "total": total}


func _read_cfg() -> void:
	cfg["terrain"] = terrain_opt.selected
	for i in 2:
		var s: Dictionary = side_ui[i]
		var units := {}
		for t in TYPES:
			if s["spins"][t].value > 0:
				units[t] = int(s["spins"][t].value)
		var ups := {}
		for u in UPS:
			if s["checks"][u].button_pressed:
				ups[u] = true
		cfg["sides"][i] = {"color": s["color"].selected, "level": int(s["level"].value), "ups": ups, "units": units}


func _refresh() -> void:
	var ok := true
	var msg := ""
	for i in 2:
		var s: Dictionary = side_ui[i]
		var n := 0
		for t in TYPES:
			n += int(s["spins"][t].value)
		s["total"].text = "   %d / %d marbles" % [n, MAX_UNITS]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Kingdoms.LIST[s["color"].selected]["color"].darkened(0.45)
		sb.border_color = Color(0.08, 0.08, 0.1)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(12)
		s["panel"].add_theme_stylebox_override("panel", sb)
		if n == 0:
			ok = false
			msg = "Each side needs at least one marble"
		elif n > MAX_UNITS:
			ok = false
			msg = "At most %d marbles per side" % MAX_UNITS
	fight_btn.disabled = not ok
	warn.text = msg


func _action(act: String) -> void:
	sfx.play("click")
	match act:
		"menu":
			back_to_menu.emit()
			return
		"copy":
			var a: Dictionary = side_ui[0]
			var b: Dictionary = side_ui[1]
			for t in TYPES:
				b["spins"][t].value = a["spins"][t].value
			b["level"].value = a["level"].value
			for u in UPS:
				b["checks"][u].button_pressed = a["checks"][u].button_pressed
		"random", "clear":
			for s in side_ui:
				for t in TYPES:
					s["spins"][t].value = 0
				for u in UPS:
					s["checks"][u].button_pressed = false
				s["level"].value = 0
				if act == "random":
					var pool := TYPES.duplicate()
					pool.shuffle()
					for k in rng.randi_range(3, 6):
						s["spins"][pool[k]].value = rng.randi_range(1, 8) if pool[k] != "king" else 1
					s["level"].value = rng.randi_range(0, 4)
					for u in UPS:
						s["checks"][u].button_pressed = rng.randf() < 0.2
	_refresh()


# --------------------------------------------------------------- fight

func _fight() -> void:
	_read_cfg()
	setup_ui.queue_free()
	_start_fight()


func _start_fight() -> void:
	sfx.play("horn")
	feed_lines.clear()
	result = {}
	facs.clear()
	rosters.clear()
	for i in 2:
		var sd: Dictionary = cfg["sides"][i]
		var f := Faction.new()
		f.id = i
		var base: Dictionary = Kingdoms.LIST[sd["color"]]
		f.name = base["name"]
		f.color = base["color"]
		if i == 1 and sd["color"] == cfg["sides"][0]["color"]:
			f.name += " II"
			f.color = f.color.darkened(0.35)
		for u in sd["ups"]:
			f.add_upgrade(u)
		facs.append(f)
		var list: Array = []
		for t in sd["units"]:
			for k in sd["units"][t]:
				var s := Soldier.create(t, i)
				s.set_level(sd["level"])
				if t in ["king", "captain"] or s.level >= 2:
					s.name = Kingdoms.random_name(rng) + (" " + Kingdoms.roman(rng.randi_range(1, 12)) if t == "king" else "")
				s.hp = s.max_hp(f)
				list.append(s)
		rosters.append(list)

	fight_ui = Control.new()
	fight_ui.size = Vector2(1280, 720)
	fight_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fight_ui)
	var bg := ColorRect.new()
	bg.color = Color("15161b")
	bg.size = fight_ui.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_ui.add_child(bg)
	box = SubViewportContainer.new()
	box.position = Vector2(280, 0)
	box.size = Vector2(720, 720)
	box.stretch = true
	box.process_mode = Node.PROCESS_MODE_PAUSABLE
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 720)
	box.add_child(vp)
	fight_ui.add_child(box)
	battle = Battle.new()
	battle.game = self
	battle.time_limit = 600.0
	vp.add_child(battle)
	battle.finished.connect(_on_finished)
	hud = Node2D.new()
	hud.draw.connect(_draw_hud)
	fight_ui.add_child(hud)
	var bar := HBoxContainer.new()
	bar.position = Vector2(1010, 670)
	bar.add_theme_constant_override("separation", 4)
	fight_ui.add_child(bar)
	for b in [["⏸", -1.0], ["1x", 1.0], ["2x", 2.0], ["4x", 4.0]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		var v: float = b[1]
		btn.pressed.connect(func(): _set_speed(v) if v > 0 else _toggle_pause())
		bar.add_child(btn)
	var bar2 := HBoxContainer.new()
	bar2.position = Vector2(12, 670)
	bar2.add_theme_constant_override("separation", 6)
	fight_ui.add_child(bar2)
	for b in [["Rematch", "rematch"], ["Edit", "edit"], ["Menu", "menu"]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		var act: String = b[1]
		btn.pressed.connect(func(): _after(act))
		bar2.add_child(btn)
	_set_speed(speed)
	battle.start({"terrain": TERRAINS[cfg["terrain"]], "attackers": rosters[0], "defenders": rosters[1],
		"fac_a": facs[0], "fac_d": facs[1], "title": "ARENA  ·  %s vs %s  ·  %s" % [facs[0].name, facs[1].name, TERRAINS[cfg["terrain"]].capitalize()]})


func _after(act: String) -> void:
	sfx.play("click")
	get_tree().paused = false
	if act == "menu":
		back_to_menu.emit()
		return
	fight_ui.queue_free()
	fight_ui = null
	if act == "rematch":
		_start_fight()
	else:
		_build_setup()


func _on_finished(r: Dictionary) -> void:
	result = r
	var all: Array = rosters[0] + rosters[1]
	all.sort_custom(func(a, b): return a.kills > b.kills)
	result["mvp"] = all[0] if all.size() > 0 and all[0].kills > 0 else null
	sfx.play("win")


func _set_speed(v: float) -> void:
	speed = v
	get_tree().paused = false
	Engine.time_scale = v
	if Game.low_power():
		Engine.physics_ticks_per_second = int(120 * minf(v, 2.0))
		Engine.max_physics_steps_per_frame = 4
	else:
		Engine.physics_ticks_per_second = int(240 * v)
		Engine.max_physics_steps_per_frame = 12 * int(v)


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused


## Battle reports kills and level-ups through this (same as Game.feed).
func feed(text: String, col: Color) -> void:
	feed_lines.append({"t": text, "c": col})
	if feed_lines.size() > 12:
		feed_lines.pop_front()


func _process(_delta: float) -> void:
	if hud:
		hud.queue_redraw()


func _draw_hud() -> void:
	if not battle:
		return
	for i in 2:
		var x := 12.0 if i == 0 else 1012.0
		var f: Faction = facs[i]
		var alive := 0
		var hp := 0.0
		var max_hp := 0.0
		for u in battle.units:
			if not u.dead and u.side == i:
				alive += 1
				hp += u.hp
				max_hp += u.max_hp
		Ink.box(hud, Rect2(x, 12, 256, 40), f.color, 2)
		Ink.text(hud, Vector2(x + 128, 32), f.display(), 18, Color.WHITE, 4)
		Ink.text_left(hud, Vector2(x, 82), "Alive  %d / %d" % [alive, rosters[i].size()], 18, Color.WHITE, 3)
		Ink.text_left(hud, Vector2(x, 108), "Kills  %d" % f.kills, 18, Color.WHITE, 3)
		var full := maxf(1.0, max_hp) if alive > 0 else 1.0
		hud.draw_rect(Rect2(x, 120, 256, 12), Color(0.2, 0.2, 0.25))
		hud.draw_rect(Rect2(x, 120, 256 * clampf(hp / full, 0, 1), 12), f.color)
		var ups: Array = cfg["sides"][i]["ups"].keys()
		Ink.text_left(hud, Vector2(x, 156), "Level %d" % cfg["sides"][i]["level"], 15, Color(0.85, 0.85, 0.9), 3)
		var y := 178.0
		for u in ups:
			Ink.text_left(hud, Vector2(x, y), "• " + Upgrades.ALL[u]["title"], 14, Color(0.85, 0.85, 0.9), 3)
			y += 18.0
	var y2 := 640.0
	for k in range(feed_lines.size() - 1, maxi(-1, feed_lines.size() - 9), -1):
		var l: Dictionary = feed_lines[k]
		Ink.text_left(hud, Vector2(12, y2), l["t"].left(42), 12, l["c"].lightened(0.3), 3)
		y2 -= 16.0
	if not result.is_empty():
		var w: Faction = facs[result["winner"]]
		var r := Rect2(420, 230, 440, 200)
		hud.draw_rect(r, Color(0, 0, 0, 0.7))
		hud.draw_rect(r, w.color, false, 4)
		Ink.text(hud, r.position + Vector2(220, 50), "%s WINS!" % w.display().to_upper(), 30, Color.WHITE, 8, w.color.darkened(0.5))
		var surv: Array = result["survivors_a"] if result["winner"] == 0 else result["survivors_d"]
		Ink.text(hud, r.position + Vector2(220, 100), "%d marbles left standing" % surv.size(), 18, Color.WHITE, 4)
		var mvp: Soldier = result.get("mvp")
		if mvp:
			var nm := mvp.display_name() if mvp.is_named() else "a %s %s" % [facs[mvp.faction].name, mvp.type]
			Ink.text(hud, r.position + Vector2(220, 140), "MVP: %s  (%d kills)" % [nm, mvp.kills], 16, Color("ffe25a"), 4)
		Ink.text(hud, r.position + Vector2(220, 176), "Rematch / Edit / Menu — bottom left", 13, Color(0.8, 0.8, 0.85), 3)


func _label(t: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.1))
	l.add_theme_constant_override("outline_size", 6)
	return l
