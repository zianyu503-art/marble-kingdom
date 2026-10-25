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


## Saves a screenshot every few real seconds, then quits (smoke tests).
func _capture_loop(dir: String) -> void:
	for i in 12:
		await get_tree().create_timer(5.0, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [dir, i])
	get_tree().quit()


func _clear() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 240
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
