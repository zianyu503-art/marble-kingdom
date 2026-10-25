class_name Plinko
extends Node2D

## Upgrade lottery: a marble in the kingdom's colour drops through pegs
## (RigidBody2D with gravity) and the bin it lands in is the chosen option.

signal chosen(index: int)

const SIZE := Vector2(720, 720)
const PAPER := Color("efe1bd")
const BIN_TOP := 590.0

var game: Node
var options: Array = []
var fac: Faction
var heading := ""
var subheading := ""
var marble: RigidBody2D
var pegs: Array = []
var peg_glow := {}
var landed := -1
var still_time := 0.0
var flash := 0.0
var root: Node2D


func start(f: Faction, head: String, sub: String, opts: Array) -> void:
	fac = f
	heading = head
	subheading = sub
	options = opts
	landed = -1
	still_time = 0.0
	if root:
		root.queue_free()
	root = Node2D.new()
	add_child(root)
	pegs.clear()
	peg_glow.clear()
	_wall(Rect2(-20, 0, 20, SIZE.y))
	_wall(Rect2(SIZE.x, 0, 20, SIZE.y))
	_wall(Rect2(0, SIZE.y - 14, SIZE.x, 30))
	var n := options.size()
	var bw := SIZE.x / n
	for i in range(1, n):
		_wall(Rect2(i * bw - 4, BIN_TOP, 8, SIZE.y - BIN_TOP))
	var row := 0
	var y := 150.0
	while y < 560.0:
		var off := 30.0 if row % 2 == 0 else 0.0
		var x := 30.0 + off
		while x < SIZE.x - 20:
			_peg(Vector2(x, y))
			x += 60.0
		y += 52.0
		row += 1
	marble = RigidBody2D.new()
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 15.0
	cs.shape = c
	marble.add_child(cs)
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.45
	mat.friction = 0.2
	marble.physics_material_override = mat
	marble.contact_monitor = true
	marble.max_contacts_reported = 4
	marble.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	marble.position = Vector2(SIZE.x * 0.5 + randf_range(-160, 160), 95)
	marble.linear_velocity = Vector2(randf_range(-60, 60), 0)
	marble.body_entered.connect(_on_marble_hit)
	root.add_child(marble)
	game.sfx.play("drum")


func _wall(r: Rect2) -> void:
	var b := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = r.size
	cs.shape = s
	cs.position = r.get_center()
	b.add_child(cs)
	root.add_child(b)


func _peg(p: Vector2) -> void:
	var b := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var s := CircleShape2D.new()
	s.radius = 7.0
	cs.shape = s
	b.position = p
	b.add_child(cs)
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.5
	b.physics_material_override = mat
	b.set_meta("peg", pegs.size())
	root.add_child(b)
	pegs.append(p)


func _on_marble_hit(body: Node) -> void:
	if body.has_meta("peg"):
		peg_glow[body.get_meta("peg")] = 1.0
		game.sfx.play("peg", randf_range(0.9, 1.4), 0.03, -4.0)


func _physics_process(delta: float) -> void:
	if marble == null or landed >= 0 or not is_instance_valid(marble):
		return
	if marble.linear_velocity.length() < 8.0:
		still_time += delta
		if still_time > 1.0 and marble.position.y < BIN_TOP:
			marble.apply_central_impulse(Vector2(randf_range(-80, 80), -60))
			still_time = 0.0
	else:
		still_time = 0.0
	if marble.position.y > BIN_TOP + 40 and marble.linear_velocity.length() < 40.0:
		landed = clampi(int(marble.position.x / (SIZE.x / options.size())), 0, options.size() - 1)
		flash = 1.0
		game.sfx.play("win")
		await get_tree().create_timer(1.5).timeout
		chosen.emit(landed)


func _process(delta: float) -> void:
	for k in peg_glow.keys():
		peg_glow[k] = maxf(0.0, peg_glow[k] - delta * 3.0)
	flash = maxf(0.0, flash - delta)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), PAPER)
	for i in 60:
		var p := Vector2(fmod(i * 137.0, SIZE.x), fmod(i * 241.0, SIZE.y))
		draw_circle(p, 18 + (i % 5) * 6, Color(0.6, 0.45, 0.25, 0.04))
	if fac == null:
		return
	draw_rect(Rect2(0, 0, SIZE.x, 76), fac.color.darkened(0.15))
	draw_line(Vector2(0, 76), Vector2(SIZE.x, 76), Ink.BLACK, 3)
	Ink.text(self, Vector2(SIZE.x * 0.5, 26), heading, 26, Color.WHITE, 6)
	Ink.text(self, Vector2(SIZE.x * 0.5, 58), subheading, 15, Color.WHITE, 4)
	for i in pegs.size():
		var g: float = peg_glow.get(i, 0.0)
		Ink.circle(self, pegs[i], 7.0, Color("8a6a45").lerp(fac.color.lightened(0.3), g), 2)
	var n := options.size()
	var bw := SIZE.x / n
	for i in n:
		var r := Rect2(i * bw, BIN_TOP, bw, SIZE.y - BIN_TOP)
		var col := Color("e6d3a3")
		if i == landed:
			col = col.lerp(fac.color.lightened(0.4), 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02) * flash)
		draw_rect(r, col)
		draw_rect(r, Ink.BLACK, false, 3)
		var o: Dictionary = options[i]
		Upgrades.draw_icon(self, o["icon"], r.position + Vector2(bw * 0.5, 34), 18, fac.color)
		Ink.text(self, r.position + Vector2(bw * 0.5, 72), o["title"], 16, Color.WHITE, 4)
		_wrap(o["desc"], r.position + Vector2(bw * 0.5, 96), bw - 16)
	if marble and is_instance_valid(marble):
		var p := marble.position
		draw_circle(p + Vector2(3, 4), 15, Color(0, 0, 0, 0.2))
		Ink.circle(self, p, 15, fac.color, 2.5)
		draw_circle(p + Vector2(-5, -5), 5, fac.color.lightened(0.45))


func _wrap(t: String, top: Vector2, width: float) -> void:
	var words := t.split(" ")
	var line := ""
	var y := top.y
	var f := Ink.font()
	for w in words:
		var test := (line + " " + w).strip_edges()
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > width and line != "":
			Ink.text(self, Vector2(top.x, y), line, 12, Color(0.15, 0.12, 0.1), 0)
			y += 15
			line = w
		else:
			line = test
	Ink.text(self, Vector2(top.x, y), line, 12, Color(0.15, 0.12, 0.1), 0)
