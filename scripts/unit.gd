class_name Unit
extends RigidBody2D

## A marble fighting in a battle. The body is a circle (shape 0) plus an
## optional shield (shape 1); its weapon is a separate Weapon body pinned to
## the marble's hand. Movement uses ray-based context steering so marbles
## walk around walls instead of pushing into them.

const INK := Color(0.07, 0.07, 0.09)
const DARK_STEEL := Color(0.55, 0.57, 0.62)
const SCALE := 1.45
const HIT_COOLDOWN := 0.25
const STEER_DIRS := 16
const LOOK := 70.0

var soldier: Soldier
var fac: Faction
var battle: Node
var weapon: Weapon
var side := 0
var hp := 100.0
var max_hp := 100.0
var radius := 12.0
var dmg := 20.0
var spin := 5.0
var spin_dir := 1.0
var drive := 600.0
var ranged := ""
var ranged_cd := 0.0
var dead := false
var flash := 0.0
var target: Unit = null
var retarget := 0.0
var hit_times := {}
var spectral_angle := 0.0
var stats := {}
var color := Color.WHITE
var shield_poly := PackedVector2Array()
var steer := Vector2.ZERO
var stuck_check := 1.0
var stuck_pos := Vector2.ZERO
var escape_time := 0.0
var escape_dir := Vector2.ZERO
var has_los := true


func setup(s: Soldier, f: Faction, b: Node, sd: int) -> void:
	soldier = s
	fac = f
	battle = b
	side = sd
	stats = s.stats()
	color = f.color
	radius = s.radius(f) * SCALE
	max_hp = s.max_hp(f)
	hp = clampf(s.hp, max_hp * 0.25, max_hp)
	dmg = s.damage(f)
	spin = stats["spin"] * (1.0 + 0.2 * f.count("haste"))
	spin_dir = 1.0 if randf() < 0.5 else -1.0
	drive = 620.0 * stats["speed"] * (1.0 + s.bonus_speed) * f.speed_mult()
	ranged = stats["ranged"]
	ranged_cd = randf_range(0.3, stats["cd"] + 0.3)
	stuck_pos = position

	gravity_scale = 0.0
	mass = pow(radius / 17.0, 2.0)
	linear_damp = 2.6
	angular_damp = 0.5
	collision_layer = Weapon.LAYER_BODY
	collision_mask = Weapon.LAYER_WALL | Weapon.LAYER_BODY | Weapon.LAYER_WEAPON
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.6
	mat.friction = 0.35
	physics_material_override = mat

	var body_shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	body_shape.shape = c
	add_child(body_shape)
	if stats.get("shield", false):
		# shield on the side opposite the weapon hand
		var r := radius
		shield_poly = PackedVector2Array([Vector2(-r * 0.75, r * 0.2 - r), Vector2(-r * 0.35, -r - 6), Vector2(r * 0.35, -r - 6), Vector2(r * 0.75, r * 0.2 - r)])
		var cs := CollisionShape2D.new()
		var shape := ConvexPolygonShape2D.new()
		shape.points = shield_poly
		cs.shape = shape
		add_child(cs)
	angular_velocity = spin * spin_dir


## Creates the weapon in the marble's hand; call after the marble is in the tree.
## The weapon is driven toward its pose by force (see Weapon), not by a joint.
func arm(root: Node) -> void:
	# the hand sits on the marble's side, the weapon points forward and outward
	var hand := Vector2.from_angle(1.2) * radius * 0.92
	var l: float = stats["wlen"] * 1.3 * (1.0 + soldier.bonus_size)
	var w: float = stats["wwid"] * 1.05
	weapon = Weapon.new()
	weapon.hold_angle = 0.5
	weapon.setup(self, stats["weapon"], l, w, hand)
	root.add_child(weapon)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if dead:
		return
	state.apply_central_force(steer * drive * mass)
	var want := spin * spin_dir
	state.apply_torque((want - state.angular_velocity) * 6.0 / maxf(state.inverse_inertia, 0.000001))


func _physics_process(delta: float) -> void:
	if dead:
		return
	flash = maxf(0.0, flash - delta * 6.0)
	retarget -= delta
	if retarget <= 0.0:
		retarget = randf_range(0.2, 0.35)
		target = battle.nearest_enemy(self)
		if randf() < 0.04:
			spin_dir = -spin_dir
		_update_steer()
	_check_stuck(delta)
	if fac.regen() > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + fac.regen() * delta)
	if ranged != "":
		ranged_cd -= delta
		if ranged_cd <= 0.0 and has_los and target and is_instance_valid(target) and not target.dead:
			if global_position.distance_to(target.global_position) < 460.0:
				battle.fire(self, target)
				ranged_cd = stats["cd"] * randf_range(0.85, 1.15)
	if fac.has("spectral"):
		spectral_angle += delta * 7.0
		var tip := global_position + Vector2.from_angle(spectral_angle) * (radius + 22.0)
		for u in battle.enemies_near(self, tip, 10.0):
			deal_damage(u, dmg * 0.5, "spectral")
	queue_redraw()


func _wall_ray(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, Weapon.LAYER_WALL)
	return get_world_2d().direct_space_state.intersect_ray(q)


## Context steering: score 16 directions by how well they lead to the goal
## and how far they are free of walls, then pick the best one.
func _update_steer() -> void:
	var p := global_position
	var goal := Vector2.ZERO
	var flee := false
	if target and is_instance_valid(target) and not target.dead:
		goal = target.global_position - p
		has_los = _wall_ray(p, target.global_position).is_empty()
		if ranged != "" and has_los and goal.length() < 200.0:
			flee = true
	elif side == 1 and soldier.type == "king":
		goal = battle.king_home - p
		if goal.length() < 20.0:
			steer = Vector2.ZERO
			return
	else:
		steer = Vector2.ZERO
		return
	var t := goal.normalized()
	if flee:
		t = -t
	elif ranged != "" and has_los and goal.length() < 300.0:
		steer = t.orthogonal() * 0.5
		return
	# straight line is open: just go
	if _wall_ray(p, p + t * LOOK).is_empty() and (flee or has_los):
		steer = t
		return
	var best := t
	var best_score := -INF
	for i in STEER_DIRS:
		var d := Vector2.from_angle(i * TAU / STEER_DIRS)
		var hit := _wall_ray(p, p + d * LOOK)
		var clear: float = 1.0 if hit.is_empty() else (hit["position"].distance_to(p) - radius) / LOOK
		var score := (0.55 + 0.45 * d.dot(t)) * clear * clear + 0.15 * d.dot(steer)
		if score > best_score:
			best_score = score
			best = d
	steer = best


func _check_stuck(delta: float) -> void:
	if escape_time > 0.0:
		escape_time -= delta
		steer = escape_dir
		return
	stuck_check -= delta
	if stuck_check <= 0.0:
		stuck_check = 1.0
		var moved := global_position.distance_to(stuck_pos)
		stuck_pos = global_position
		if moved < 10.0 and steer != Vector2.ZERO and target and is_instance_valid(target) \
				and global_position.distance_to(target.global_position) > radius + target.radius + 40.0:
			escape_dir = steer.rotated(randf_range(PI * 0.5, PI * 1.5))
			escape_time = 0.6
			battle.stat_escapes += 1


func deal_damage(other: Unit, amount: float, kind: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var key := other.get_instance_id()
	if kind != "ranged" and now - float(hit_times.get(key, -10.0)) < HIT_COOLDOWN / Engine.time_scale:
		return
	hit_times[key] = now
	var dealt := other.take_damage(amount, self)
	if fac.lifesteal() > 0.0:
		hp = minf(max_hp, hp + dealt * fac.lifesteal())


## Returns the damage actually applied.
func take_damage(amount: float, from: Unit) -> float:
	if dead:
		return 0.0
	var a := maxf(2.0, amount - fac.armor())
	hp -= a
	flash = 1.0
	if from and is_instance_valid(from):
		apply_central_impulse((global_position - from.global_position).normalized() * a * 2.2 * mass)
	battle.on_hit(self, from, a)
	if hp <= 0.0:
		die(from)
	return a


func die(killer: Unit) -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	if weapon and is_instance_valid(weapon):
		weapon.drop()
	battle.on_unit_died(self, killer)


func _draw() -> void:
	if dead:
		return
	if shield_poly.size() > 0:
		draw_colored_polygon(shield_poly, color.darkened(0.35))
		var closed := shield_poly.duplicate()
		closed.append(shield_poly[0])
		draw_polyline(closed, INK, 2.0)
	draw_circle(Vector2.ZERO, radius, color)
	if stats.get("helmet", false) or fac.has("armor"):
		draw_arc(Vector2.ZERO, radius - 4.0, -1.2, 1.2, 14, DARK_STEEL, 7.0)
		draw_arc(Vector2.ZERO, radius - 0.5, -1.2, 1.2, 14, INK, 1.2)
	match soldier.type:
		"mage":
			draw_circle(Vector2.ZERO, radius * 0.45, Color("4b3a8f"))
		"farmer":
			draw_circle(Vector2.ZERO, radius * 0.5, Color("e3c26a"))
			draw_arc(Vector2.ZERO, radius * 0.5, 0, TAU, 16, INK, 1.2)
		"bandit":
			draw_arc(Vector2.ZERO, radius * 0.55, -0.9, 0.9, 10, Color("2a2a2e"), 5.0)
		"kingsguard":
			draw_line(Vector2(-radius * 0.5, 0), Vector2(radius * 0.4, 0), INK, 2.0)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 40, INK, 3.0)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, flash * 0.75))
	if fac.has("spectral"):
		var a := spectral_angle - rotation
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		var p0 := d * (radius + 8.0)
		var p1 := d * (radius + 32.0)
		draw_colored_polygon(PackedVector2Array([p0 + n * 3.5, p1, p0 - n * 3.5]), Color(0.6, 0.9, 1.0, 0.55))
