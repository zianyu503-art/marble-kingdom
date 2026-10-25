extends Control

## Main menu: choose which kingdoms go to war, name their kings, set options.

signal start_war(cfg: Dictionary)

var sfx: Sfx
var rng := RandomNumberGenerator.new()
var cards: Array = []
var towns_spin: SpinBox
var bandits_check: CheckBox
var seed_edit: LineEdit
var start_btn: Button
var warn: Label


func build(last: Dictionary, sound: Sfx) -> void:
	sfx = sound
	rng.randomize()
	size = Vector2(1280, 720)
	var bg := ColorRect.new()
	bg.size = size
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/territory.gdshader")
	mat.set_shader_parameter("map_size", Vector2(1280, 720))
	bg.material = mat
	add_child(bg)

	var title := Label.new()
	title.text = "MARBLE KINGDOMS"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("ffd84a"))
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.1))
	title.add_theme_constant_override("outline_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 18)
	title.size = Vector2(1280, 80)
	add_child(title)
	var sub := _outlined("Choose the kingdoms that go to war, and name their kings", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 98)
	sub.size = Vector2(1280, 30)
	add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.position = Vector2(60, 140)
	add_child(grid)
	var prev := {}
	for k in last.get("kingdoms", []):
		prev[k["index"]] = k["king"]
	for i in Kingdoms.LIST.size():
		var on := prev.has(i) if not prev.is_empty() else i < 6
		var king: String = prev.get(i, Kingdoms.random_king_name(rng))
		grid.add_child(_card(i, on, king))

	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 14)
	opts.position = Vector2(60, 590)
	add_child(opts)
	opts.add_child(_outlined("Neutral towns", 18))
	towns_spin = SpinBox.new()
	towns_spin.min_value = 0
	towns_spin.max_value = 24
	towns_spin.value = last.get("towns", 10)
	opts.add_child(towns_spin)
	bandits_check = CheckBox.new()
	bandits_check.text = "Bandits"
	bandits_check.button_pressed = last.get("bandits", true)
	opts.add_child(bandits_check)
	opts.add_child(_outlined("   Map seed", 18))
	seed_edit = LineEdit.new()
	seed_edit.text = str(rng.randi() % 100000)
	seed_edit.custom_minimum_size = Vector2(110, 0)
	opts.add_child(seed_edit)
	var dice := Button.new()
	dice.text = "New seed"
	dice.pressed.connect(func(): seed_edit.text = str(rng.randi() % 100000))
	opts.add_child(dice)
	for b in [["All", "all"], ["None", "none"], ["Random", "random"]]:
		var btn := Button.new()
		btn.text = b[0]
		var mode: String = b[1]
		btn.pressed.connect(func(): _select(mode))
		opts.add_child(btn)

	start_btn = Button.new()
	start_btn.text = "  START THE WAR  "
	start_btn.add_theme_font_size_override("font_size", 26)
	start_btn.position = Vector2(470, 640)
	start_btn.size = Vector2(340, 56)
	start_btn.pressed.connect(_start)
	add_child(start_btn)
	warn = _outlined("", 16)
	warn.position = Vector2(830, 655)
	add_child(warn)
	_refresh()


func _card(i: int, on: bool, king: String) -> Control:
	var d: Dictionary = Kingdoms.LIST[i]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(222, 0)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var check := CheckBox.new()
	check.text = d["name"] + " Kingdom"
	check.button_pressed = on
	check.add_theme_font_size_override("font_size", 17)
	check.add_theme_color_override("font_color", Color.WHITE)
	check.add_theme_color_override("font_pressed_color", Color.WHITE)
	check.add_theme_color_override("font_outline_color", Color.BLACK)
	check.add_theme_constant_override("outline_size", 5)
	check.toggled.connect(func(_b): _refresh(); sfx.play("click"))
	v.add_child(check)
	var row := HBoxContainer.new()
	var name_edit := LineEdit.new()
	name_edit.text = king
	name_edit.placeholder_text = "King's name"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_edit)
	var reroll := Button.new()
	reroll.text = "↻"
	reroll.tooltip_text = "Random name"
	reroll.pressed.connect(func(): name_edit.text = Kingdoms.random_king_name(rng))
	row.add_child(reroll)
	v.add_child(row)
	cards.append({"panel": panel, "check": check, "name": name_edit, "index": i})
	return panel


func _select(mode: String) -> void:
	for c in cards:
		match mode:
			"all":
				c["check"].button_pressed = true
			"none":
				c["check"].button_pressed = false
			"random":
				c["check"].button_pressed = false
	if mode == "random":
		var idx := range(cards.size())
		idx.shuffle()
		for i in rng.randi_range(4, 8):
			cards[idx[i]]["check"].button_pressed = true
	_refresh()


func _refresh() -> void:
	var n := 0
	for c in cards:
		var on: bool = c["check"].button_pressed
		if on:
			n += 1
		var sb := StyleBoxFlat.new()
		var col: Color = Kingdoms.LIST[c["index"]]["color"]
		sb.bg_color = col if on else col.darkened(0.65)
		sb.border_color = Color(0.08, 0.08, 0.1)
		sb.set_border_width_all(3 if on else 2)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(10)
		c["panel"].add_theme_stylebox_override("panel", sb)
		c["panel"].modulate = Color(1, 1, 1, 1.0 if on else 0.75)
	start_btn.disabled = n < 2
	warn.text = "Pick at least 2 kingdoms" if n < 2 else "%d kingdoms selected" % n


func _start() -> void:
	var ks: Array = []
	for c in cards:
		if c["check"].button_pressed:
			var nm: String = c["name"].text.strip_edges()
			if nm == "":
				nm = Kingdoms.random_king_name(rng)
			ks.append({"index": c["index"], "king": nm})
	if ks.size() < 2:
		return
	sfx.play("horn")
	start_war.emit({"kingdoms": ks, "towns": int(towns_spin.value), "bandits": bandits_check.button_pressed,
		"seed": int(seed_edit.text) if seed_edit.text.is_valid_int() else seed_edit.text.hash()})


func _outlined(t: String, sz: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.1))
	l.add_theme_constant_override("outline_size", 6)
	return l
