extends Control

## End screen: winner banner, podium of kingdoms and the hall of heroes.


func build(game: Game, winner: Faction) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = size
	add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(290, 70)
	panel.size = Vector2(700, 580)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("efe1bd")
	sb.border_color = Color(0.08, 0.08, 0.1)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(_label("VICTORY", 44, winner.color))
	v.add_child(_label("The %s rules the land!  (%02d:%02d)" % [winner.display(), int(game.elapsed) / 60, int(game.elapsed) % 60], 20, Color(0.15, 0.12, 0.1), 0))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	v.add_child(cols)

	var podium := VBoxContainer.new()
	podium.custom_minimum_size = Vector2(300, 0)
	podium.add_child(_label("Podium", 20, Color(0.15, 0.12, 0.1), 0))
	for i in game.ranking.size():
		var f: Faction = game.ranking[i]
		var row := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.color = f.color
		sw.custom_minimum_size = Vector2(22, 22)
		row.add_child(sw)
		row.add_child(_label("  %d. %s   %d kills" % [i + 1, f.name, f.kills], 15, Color(0.15, 0.12, 0.1), 0, false))
		podium.add_child(row)
	cols.add_child(podium)

	var heroes := VBoxContainer.new()
	heroes.add_child(_label("Hall of Heroes", 20, Color(0.15, 0.12, 0.1), 0))
	var all: Array = game.fallen.duplicate()
	for f in game.factions:
		for sol in game.all_soldiers(f.id):
			if not all.has(sol):
				all.append(sol)
	all.sort_custom(func(a, b): return a.kills > b.kills)
	for i in mini(8, all.size()):
		var s: Soldier = all[i]
		if s.kills == 0:
			break
		var nm := s.display_name() if s.is_named() else "%s %s" % [game.factions[s.faction].name, s.type]
		var row := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.color = game.factions[s.faction].color
		sw.custom_minimum_size = Vector2(14, 14)
		row.add_child(sw)
		row.add_child(_label("  %s  Lv%d  %d kills%s" % [nm, s.level, s.kills, "" if game.all_soldiers(s.faction).has(s) else "  †"], 14, Color(0.15, 0.12, 0.1), 0, false))
		heroes.add_child(row)
	cols.add_child(heroes)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	var again := Button.new()
	again.text = "  Play Again  "
	again.add_theme_font_size_override("font_size", 20)
	again.pressed.connect(func(): game.play_again.emit())
	buttons.add_child(again)
	var menu := Button.new()
	menu.text = "  Main Menu  "
	menu.add_theme_font_size_override("font_size", 20)
	menu.pressed.connect(func(): game.back_to_menu.emit())
	buttons.add_child(menu)
	v.add_child(buttons)


func _label(t: String, sz: int, col: Color, outline := 8, center := true) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col if outline == 0 else Color.WHITE)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", col.darkened(0.5))
		l.add_theme_constant_override("outline_size", outline)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
