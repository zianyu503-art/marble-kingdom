class_name Unit
extends RigidBody2D

## A marble fighting in a battle. Its collision shapes are the marble body
## (shape 0), the weapon parts and an optional shield. The weapon is a real
## part of the rigid body: it spins with the marble, blocks other weapons,
## scrapes along walls and shoves enemies. Damage happens when a weapon part
## touches an enemy body and scales with the impact speed.
## Drawing uses exactly the same polygons as the collision shapes.

const INK := Color(0.07, 0.07, 0.09)
const STEEL := Color(0.86, 0.88, 0.92)
const DARK_STEEL := Color(0.55, 0.57, 0.62)
const WOOD := Color("8a5428")
const GOLD := Color("f2c230")
const SCALE := 1.45
const HIT_COOLDOWN := 0.25

var soldier: Soldier
var fac: Faction
var battle: Node
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
## Weapon parts: [{"poly": PackedVector2Array, "col": Color}] in local space.
var parts: Array = []
var weapon_shapes := {}
var shield_poly := PackedVector2Array()
var tip_len := 0.0


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

	gravity_scale = 0.0
	mass = pow(radius / 17.0, 2.0)
	linear_damp = 2.6
	angular_damp = 0.5
	contact_monitor = true
	max_contacts_reported = 10
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.7
	mat.friction = 0.35
	physics_material_override = mat

	var body_shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	body_shape.shape = c
	add_child(body_shape)

	_build_weapon(stats["weapon"], stats["wlen"] * SCALE * (1.0 + s.bonus_size), stats["wwid"] * SCALE)
	var idx := 1
	for p in parts:
		if p.get("solid", true):
			var cs := CollisionShape2D.new()
			var shape := ConvexPolygonShape2D.new()
			shape.points = p["poly"]
			cs.shape = shape
			add_child(cs)
			weapon_shapes[idx] = true
			idx += 1
	if stats.get("shield", false):
		var r := radius
		shield_poly = PackedVector2Array([Vector2(-r - 1, -r * 0.8), Vector2(-r - 6, -r * 0.45), Vector2(-r - 7, r * 0.45), Vector2(-r - 1, r * 0.8)])
		var cs := CollisionShape2D.new()
		var shape := ConvexPolygonShape2D.new()
		shape.points = shield_poly
		cs.shape = shape
		add_child(cs)

	body_shape_entered.connect(_on_body_shape_entered)
	angular_velocity = spin * spin_dir


## Builds the weapon out of convex parts starting at the marble's edge.
func _build_weapon(kind: String, l: float, w: float) -> void:
	var x0 := radius - 4.0
	var x1 := x0 + l
	tip_len = l + radius
	match kind:
		"sword", "greatsword":
			parts.append(_part([Vector2(x0 + 5, -w * 0.5), Vector2(x1 - 6, -w * 0.5), Vector2(x1, 0), Vector2(x1 - 6, w * 0.5), Vector2(x0 + 5, w * 0.5)], STEEL))
			parts.append(_part(_rect(x0 + 1, -w * 0.5 - 5, 5, w + 10), GOLD if kind == "greatsword" else DARK_STEEL))
		"spear":
			parts.append(_part(_rect(x0, -2.5, l - 11, 5), WOOD))
			parts.append(_part([Vector2(x1 - 13, -6), Vector2(x1, 0), Vector2(x1 - 13, 6)], STEEL))
		"halberd":
			parts.append(_part(_rect(x0, -2.5, l - 4, 5), WOOD))
			parts.append(_part([Vector2(x1 - 16, -3), Vector2(x1 - 12, -14), Vector2(x1 - 3, -12), Vector2(x1 - 4, -3)], STEEL))
			parts.append(_part([Vector2(x1 - 5, -4), Vector2(x1 + 6, 0), Vector2(x1 - 5, 4)], STEEL))
		"axe":
			parts.append(_part(_rect(x0, -3, l, 6), WOOD))
			parts.append(_part([Vector2(x1 - 14, -3), Vector2(x1 - 11, -15), Vector2(x1 - 1, -16), Vector2(x1 + 3, -6), Vector2(x1 - 1, -3)], STEEL))
		"hammer":
			parts.append(_part(_rect(x0, -3, l - 9, 6), WOOD))
			parts.append(_part(_rect(x1 - 13, -12, 15, 24), DARK_STEEL))
		"pitchfork":
			parts.append(_part(_rect(x0, -2.5, l - 10, 5), WOOD))
			parts.append(_part(_rect(x1 - 12, -9, 4, 18), DARK_STEEL))
			for y in [-8.0, -1.5, 5.0]:
				parts.append(_part(_rect(x1 - 9, y, 10, 3), DARK_STEEL))
		"bow":
			var pts: Array = []
			for i in 7:
				var a := lerpf(-1.2, 1.2, i / 6.0)
				pts.append(Vector2(x0 - 6, 0) + Vector2(cos(a), sin(a)) * 16.0)
			parts.append({"poly": PackedVector2Array(pts), "col": WOOD, "solid": false, "line": true})
			parts.append(_part(_rect(x0 + 6, -5, 5, 10), WOOD))
		"staff":
			parts.append(_part(_rect(x0, -2.5, l - 6, 5), WOOD))
			var orb: Array = []
			for i in 8:
				orb.append(Vector2(x1, 0) + Vector2.from_angle(i * TAU / 8) * 6.5)
			parts.append(_part(orb, Color("a77bff")))
		_:
			parts.append(_part(_rect(x0, -3, l, 6), WOOD))


func _part(pts: Array, col: Color) -> Dictionary:
	return {"poly": PackedVector2Array(pts), "col": col}


func _rect(x: float, y: float, w: float, h: float) -> Array:
	return [Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if dead:
		return
	var desired := Vector2.ZERO
	if target and is_instance_valid(target) and not target.dead:
		var to := target.global_position - global_position
		var d := to.length()
		if ranged != "" and d < 200.0:
			desired = -to / d
		elif ranged != "" and d < 280.0:
			desired = to.orthogonal().normalized() * 0.5
		else:
			desired = to / maxf(d, 1.0)
	elif side == 1 and soldier.type == "king":
		desired = (battle.king_home - global_position) / 100.0
	if desired.length() > 1.0:
		desired = desired.normalized()
	# a marble rolls toward its target; collisions are left to the physics engine
	state.apply_central_force(desired * drive * mass)
	# the spin is driven by torque, so weapon clashes can stall or reverse it
	var want := spin * spin_dir
	state.apply_torque((want - state.angular_velocity) * 6.0 / maxf(state.inverse_inertia, 0.000001))


func _physics_process(delta: float) -> void:
	if dead:
		return
	flash = maxf(0.0, flash - delta * 6.0)
	retarget -= delta
	if retarget <= 0.0:
		retarget = randf_range(0.3, 0.6)
		target = battle.nearest_enemy(self)
		if randf() < 0.04:
			spin_dir = -spin_dir
	if fac.regen() > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + fac.regen() * delta)
	if ranged != "":
		ranged_cd -= delta
		if ranged_cd <= 0.0 and target and is_instance_valid(target) and not target.dead:
			if global_position.distance_to(target.global_position) < 460.0:
				battle.fire(self, target)
				ranged_cd = stats["cd"] * randf_range(0.85, 1.15)
	if fac.has("spectral"):
		spectral_angle += delta * 7.0
		var tip := global_position + Vector2.from_angle(spectral_angle) * (radius + 22.0)
		for u in battle.enemies_near(self, tip, 10.0):
			deal_damage(u, dmg * 0.5, "spectral")
	queue_redraw()


func _on_body_shape_entered(_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if dead or not (body is Unit):
		return
	var other := body as Unit
	if other.dead or other.side == side:
		return
	var mine_weapon := weapon_shapes.has(local_shape_index)
	if mine_weapon and body_shape_index == 0:
		# speed of the weapon tip relative to the victim
		var tip := absf(angular_velocity) * tip_len * 0.6
		var rel := (linear_velocity - other.linear_velocity).length() + tip
		var mult := clampf(0.45 + rel / 380.0, 0.45, 1.8)
		deal_damage(other, dmg * mult, "melee")
	elif mine_weapon and body_shape_index >= 1:
		battle.clang((global_position + other.global_position) * 0.5, other.weapon_shapes.has(body_shape_index))


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
		# knockback away from the attacker
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
	battle.on_unit_died(self, killer)


func _draw() -> void:
	if dead:
		return
	for p in parts:
		var poly: PackedVector2Array = p["poly"]
		if p.get("line", false):
			draw_polyline(poly, INK, 6.0)
			draw_polyline(poly, p["col"], 3.5)
			draw_line(poly[0], poly[poly.size() - 1], INK, 1.2)
			continue
		draw_colored_polygon(poly, p["col"])
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, INK, 2.0)
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
