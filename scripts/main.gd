extends Node

## Switches between the kingdom-selection menu and a running war.

var sfx: Sfx
var screen: Node
var last_cfg := {}


func _ready() -> void:
	randomize()
	sfx = Sfx.new()
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx)
	var args := OS.get_cmdline_user_args()
	if "--skilltest" in args:
		_skill_test(args)
		return
	if "--autostart" in args:
		# used for automated smoke tests: start a 6-kingdom war at 4x speed
		var ks: Array = []
		var rng := RandomNumberGenerator.new()
		for i in 6:
			ks.append({"index": i, "king": Kingdoms.random_king_name(rng)})
		_start({"kingdoms": ks, "towns": 10, "bandits": true, "seed": 1234})
		var dir := ""
		for a in args:
			if a.begins_with("--shots="):
				dir = a.substr(8)
		if dir != "":
			screen._set_speed(4.0)
			_capture_loop(dir)
	else:
		_show_menu()


## Test: one field battle with every unit type and the skill upgrades on both
## sides; prints how often each skill fired, saves a few frames, then quits.
func _skill_test(args: PackedStringArray) -> void:
	var rng := RandomNumberGenerator.new()
	_start({"kingdoms": [{"index": 0, "king": "Test I"}, {"index": 1, "king": "Test II"}], "towns": 0, "bandits": false, "seed": 7})
	var g: Game = screen
	g.world.paused = true
	var sides: Array = []
	for fid in 2:
		var f: Faction = g.factions[fid]
		for up in ["dash", "volley", "whirl", "thorns"]:
			f.add_upgrade(up)
		f.decision_timer = 9999.0
		var list: Array = []
		for t in ["footman", "spearman", "knight", "berserker", "hammerman", "archer", "mage", "kingsguard",
				"captain", "monk", "bard", "necromancer", "crossbowman", "fighter", "fighter", "farmer"]:
			list.append(Soldier.create(t, fid))
		list.append(Soldier.create("king", fid))
		list[-1].name = "Test " + Kingdoms.roman(fid + 1)
		sides.append(g.world.spawn_army(Vector2(300 + fid * 400, 300), fid, list))
	g._start_battle(sides[0], sides[1], null)
	var dir := ""
	for a in args:
		if a.begins_with("--shots="):
			dir = a.substr(8)
	for i in 4:
		await get_tree().create_timer(3.0, true, false, true).timeout
		if dir != "":
			get_viewport().get_texture().get_image().save_png("%s/skill_%02d.png" % [dir, i])
	while g.battle.running:
		await get_tree().process_frame
	get_tree().quit()


## Saves a screenshot every few real seconds, then quits (smoke tests).
func _capture_loop(dir: String) -> void:
	if "--burst" in OS.get_cmdline_user_args():
		# wait for a field battle to be underway, then grab quick consecutive frames
		while not (screen.focus == "battle" and screen.battle.elapsed > 2.5):
			await get_tree().process_frame
		screen._set_speed(1.0)
		for i in 6:
			await get_tree().create_timer(0.12, true, false, true).timeout
			get_viewport().get_texture().get_image().save_png("%s/burst_%02d.png" % [dir, i])
		get_tree().quit()
		return
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var perf := {"cpu": 0.0, "phys": 0.0, "gpu": 0.0, "n": 0}
	var sample := func():
		perf["cpu"] += Performance.get_monitor(Performance.TIME_PROCESS)
		perf["phys"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		perf["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		perf["n"] += 1
	get_tree().process_frame.connect(sample)
	var mem0 := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var count := 36 if "--long" in OS.get_cmdline_user_args() else 12
	for i in count:
		await get_tree().create_timer(5.0, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [dir, i])
		print("mem %3ds: %.0f MB, objects %d, nodes %d" % [(i + 1) * 5, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	var n: float = maxf(1.0, perf["n"])
	print("perf: process %.2f ms  physics %.2f ms  frames %d  memory %.0f MB -> %.0f MB" % [perf["cpu"] / n * 1000.0, perf["phys"] / n * 1000.0, perf["n"], mem0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	get_tree().quit()


func _clear() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 120 if Game.low_power() else 240
	if screen:
		screen.queue_free()
		screen = null


func _show_menu() -> void:
	_clear()
	var m := preload("res://scripts/menu.gd").new()
	add_child(m)
	m.build(last_cfg, sfx)
	m.start_war.connect(_start)
	screen = m


func _start(cfg: Dictionary) -> void:
	_clear()
	last_cfg = cfg
	var g := Game.new()
	add_child(g)
	g.setup(cfg, sfx)
	g.back_to_menu.connect(_show_menu.call_deferred)
	g.play_again.connect(func():
		var c := last_cfg.duplicate()
		c["seed"] = randi() % 100000
		_start.call_deferred(c))
	screen = g
