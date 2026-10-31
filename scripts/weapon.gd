class_name Weapon
extends RigidBody2D

## A weapon held by a marble. It is its own rigid body, driven by force and
## torque toward a target pose in the marble's hand (an "active" grip): it
## follows the marble's spin, thrusts or swings at nearby enemies, and when
## something blocks it the weapon really stops, pushes back on its marble,
## then recovers. When the marble dies the grip is released and it drops.

const INK := Color(0.07, 0.07, 0.09)
const STEEL := Color(0.86, 0.88, 0.92)
const DARK_STEEL := Color(0.55, 0.57, 0.62)
const WOOD := Color("8a5428")
const GOLD := Color("f2c230")
const LAYER_WALL := 1
const LAYER_BODY := 2
const LAYER_WEAPON := 4

## Attack style per weapon: thrust (poke along the shaft) or swing (arc).
const STYLE := {
	"spear": "thrust", "halberd": "thrust", "pitchfork": "thrust",
	"sword": "swing", "greatsword": "swing", "axe": "swing", "hammer": "swing", "stick": "swing",
	"bone": "swing",
	"bow": "aim", "staff": "aim", "crossbow": "aim", "lute": "aim", "darkstaff": "aim",
}
const COOLDOWN := {"thrust": 0.85, "swing": 1.1}

var holder: Unit
var kind := ""
var style := ""
var parts: Array = []
var hold_angle := 0.5
var hand_local := Vector2.ZERO
var length := 20.0
var dropped := false
var target_pos := Vector2.ZERO
var target_rot := 0.0
var attack_t := -1.0
var attack_cd := 0.0
var aim := 0.0
var swing_dir := 1.0
## Ranged weapons turn toward their target before they may fire.
var aiming := false


func setup(u: Unit, k: String, l: float, w: float, hand: Vector2) -> void:
	holder = u
	kind = k
	style = STYLE.get(k, "")
	length = l
	hand_local = hand
	attack_cd = randf_range(0.2, 0.8)
	gravity_scale = 0.0
	mass = 0.22 * u.mass
	linear_damp = 1.0
	angular_damp = 1.0
	collision_layer = LAYER_WEAPON
	collision_mask = LAYER_WALL | LAYER_BODY | LAYER_WEAPON
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.5
	mat.friction = 0.2
	physics_material_override = mat
	_build(k, l, w)
	for p in parts:
		if p.get("solid", true):
			var cs := CollisionShape2D.new()
			var shape := ConvexPolygonShape2D.new()
			shape.points = p["poly"]
			cs.shape = shape
			add_child(cs)
	add_collision_exception_with(u)
	global_position = u.to_global(hand)
	rotation = u.rotation + hold_angle
	target_pos = global_position
	target_rot = rotation
	body_shape_entered.connect(_on_hit)


## Weapon parts are built from the grip (origin) outward along +x.
func _build(k: String, l: float, w: float) -> void:
	match k:
		"sword", "greatsword":
			parts.append(_part(_rect(-5, -1.5, 6, 3), WOOD))
			parts.append(_part(_rect(1, -w * 0.5 - 4, 3, w + 8), GOLD if k == "greatsword" else DARK_STEEL))
			parts.append(_part([Vector2(4, -w * 0.5), Vector2(l - 5, -w * 0.5), Vector2(l, 0), Vector2(l - 5, w * 0.5), Vector2(4, w * 0.5)], STEEL))
		"spear":
			parts.append(_part(_rect(-8, -1.8, l - 2, 3.6), WOOD))
			parts.append(_part([Vector2(l - 10, -4.5), Vector2(l + 2, 0), Vector2(l - 10, 4.5)], STEEL))
		"halberd":
			parts.append(_part(_rect(-8, -1.8, l + 2, 3.6), WOOD))
			parts.append(_part([Vector2(l - 14, -2), Vector2(l - 11, -11), Vector2(l - 3, -10), Vector2(l - 4, -2)], STEEL))
			parts.append(_part([Vector2(l - 6, -3), Vector2(l + 4, 0), Vector2(l - 6, 3)], STEEL))
		"axe":
			parts.append(_part(_rect(-4, -2, l, 4), WOOD))
			parts.append(_part([Vector2(l - 12, -2), Vector2(l - 9, -11), Vector2(l - 1, -12), Vector2(l + 2, -4), Vector2(l - 1, -2)], STEEL))
		"hammer":
			parts.append(_part(_rect(-4, -2, l - 6, 4), WOOD))
			parts.append(_part(_rect(l - 10, -9, 12, 18), DARK_STEEL))
		"pitchfork":
			parts.append(_part(_rect(-6, -1.8, l - 4, 3.6), WOOD))
			parts.append(_part(_rect(l - 10, -7, 3, 14), DARK_STEEL))
			for y in [-7.0, -1.2, 4.6]:
				parts.append(_part(_rect(l - 8, y, 9, 2.4), DARK_STEEL))
		"bow":
			var pts: Array = []
			for i in 7:
				var a := lerpf(-1.2, 1.2, i / 6.0)
				pts.append(Vector2(-6, 0) + Vector2(cos(a), sin(a)) * 12.0)
			parts.append({"poly": PackedVector2Array(pts), "col": WOOD, "solid": false, "line": true})
			parts.append(_part(_rect(0, -4, 6, 8), WOOD))
		"crossbow":
			parts.append(_part(_rect(-4, -2.5, l + 4, 5), WOOD))
			parts.append(_part(_rect(l - 4, -10, 3.5, 20), DARK_STEEL))
			parts.append({"poly": PackedVector2Array([Vector2(l - 3, -10), Vector2(l - 9, 0), Vector2(l - 3, 10)]), "col": INK, "solid": false, "line": true})
		"lute":
			parts.append(_part(_rect(-2, -1.8, l, 3.6), WOOD))
			var body: Array = []
			for i in 10:
				body.append(Vector2(-6, 0) + Vector2.from_angle(i * TAU / 10) * Vector2(7.0, 6.0))
			parts.append(_part(body, Color("c98a3a")))
		"darkstaff":
			parts.append(_part(_rect(-6, -1.8, l, 3.6), Color("3a2c22")))
			var skull: Array = []
			for i in 8:
				skull.append(Vector2(l - 1, 0) + Vector2.from_angle(i * TAU / 8) * 5.5)
			parts.append(_part(skull, Color(0.93, 0.92, 0.86)))
		"bone":
			parts.append(_part(_rect(-2, -2, l, 4), Color(0.93, 0.92, 0.86)))
			parts.append(_part(_rect(l - 4, -4, 5, 8), Color(0.93, 0.92, 0.86)))
		"staff":
			parts.append(_part(_rect(-6, -1.8, l, 3.6), WOOD))
			var orb: Array = []
			for i in 8:
				orb.append(Vector2(l - 2, 0) + Vector2.from_angle(i * TAU / 8) * 5.0)
			parts.append(_part(orb, Color("a77bff")))
		_:
			parts.append(_part(_rect(-4, -2, l, 4), WOOD))


func _part(pts: Array, col: Color) -> Dictionary:
	return {"poly": PackedVector2Array(pts), "col": col}


func _rect(x: float, y: float, w: float, h: float) -> Array:
	return [Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]


func _physics_process(delta: float) -> void:
	if dropped or not is_instance_valid(holder) or holder.dead:
		return
	attack_cd -= delta
	var tgt: Unit = holder.target
	var has_tgt := tgt != null and is_instance_valid(tgt) and not tgt.dead
	aiming = style == "aim" and has_tgt
	if attack_t < 0.0 and attack_cd <= 0.0 and style != "" and style != "aim" and has_tgt:
		var reach := holder.radius + length + tgt.radius + 18.0
		if holder.global_position.distance_to(tgt.global_position) < reach:
			attack_t = 0.0
			swing_dir = 1.0 if randf() < 0.5 else -1.0
	if has_tgt:
		var lead := tgt.global_position + (tgt.linear_velocity * 0.25 if style == "aim" else Vector2.ZERO)
		aim = (lead - holder.global_position).angle()
	_update_pose(delta)


## Works out where the weapon should be this frame (thrust/swing animation).
func _update_pose(delta: float) -> void:
	var c := holder.global_position
	var r := holder.radius
	if aiming:
		# hold the bow/staff out in front, pointed at the target
		target_pos = c + Vector2.from_angle(aim) * r * 0.9
		target_rot = aim
		return
	if attack_t < 0.0:
		target_pos = holder.to_global(hand_local)
		target_rot = holder.rotation + hold_angle
		return
	attack_t += delta
	var ext := 0.0
	var off := 0.0
	if style == "thrust":
		# wind up (pull back), jab, recover
		if attack_t < 0.15:
			ext = lerpf(0.0, -8.0, attack_t / 0.15)
		elif attack_t < 0.23:
			ext = lerpf(-8.0, length * 0.65, (attack_t - 0.15) / 0.08)
		elif attack_t < 0.5:
			ext = lerpf(length * 0.65, 0.0, (attack_t - 0.23) / 0.27)
		else:
			_end_attack()
			return
		var hand := c + Vector2.from_angle(aim + 0.35) * r * 0.85
		target_rot = aim
		target_pos = hand + Vector2.from_angle(aim) * ext
	else:
		# raise to one side, sweep across the target, recover
		if attack_t < 0.18:
			off = lerpf(0.0, -1.3, attack_t / 0.18)
		elif attack_t < 0.32:
			off = lerpf(-1.3, 1.3, (attack_t - 0.18) / 0.14)
		elif attack_t < 0.55:
			off = lerpf(1.3, 0.0, (attack_t - 0.32) / 0.23)
		else:
			_end_attack()
			return
		var a := aim + off * swing_dir
		target_rot = a
		target_pos = c + Vector2.from_angle(a + 0.6 * swing_dir) * r * 0.85


## True when the ranged weapon points at the target closely enough to shoot.
func ready_to_fire() -> bool:
	return aiming and absf(wrapf(rotation - aim, -PI, PI)) < 0.26


## Where projectiles leave the weapon, and their direction.
func muzzle() -> Transform2D:
	var d := Vector2.from_angle(rotation)
	var tip := 8.0 if kind == "bow" else (length + 2.0 if kind == "crossbow" else length)
	return Transform2D(rotation, global_position + d * tip)


## Starts a thrust or swing right away (used by the lunge skill).
func start_attack() -> void:
	if style == "thrust" or style == "swing":
		attack_t = 0.0
		swing_dir = 1.0 if randf() < 0.5 else -1.0


func _end_attack() -> void:
	attack_t = -1.0
	attack_cd = COOLDOWN.get(style, 1.0) * randf_range(0.85, 1.2)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if dropped or not is_instance_valid(holder) or holder.dead:
		return
	var p := state.transform.origin
	var e := target_pos - p
	if e.length() > 90.0:
		# knocked far away (e.g. wedged behind a wall): snap back into the hand
		state.transform = Transform2D(target_rot, target_pos)
		state.linear_velocity = holder.linear_velocity
		return
	var want_v := holder.linear_velocity + e * 40.0
	var f := (want_v - state.linear_velocity) * mass * 30.0
	f = f.limit_length(mass * 22000.0)
	state.apply_central_force(f)
	# the push on the weapon is felt by the marble holding it
	holder.apply_central_force(-f * 0.4)
	var ea := wrapf(target_rot - state.transform.get_rotation(), -PI, PI)
	var follow := holder.angular_velocity if attack_t < 0.0 and not aiming else 0.0
	var inertia := 1.0 / maxf(state.inverse_inertia, 0.000001)
	state.apply_torque(clampf((follow + ea * 30.0 - state.angular_velocity) * 30.0, -900.0, 900.0) * inertia)


func _on_hit(_rid: RID, body: Node, body_shape_index: int, _local: int) -> void:
	if dropped or not is_instance_valid(holder) or holder.dead:
		return
	if body is Unit:
		var u := body as Unit
		if u.dead or u.side == holder.side:
			return
		if body_shape_index == 0:
			var tip_speed := absf(angular_velocity) * length * 0.7
			var rel := (linear_velocity - u.linear_velocity).length() + tip_speed
			holder.deal_damage(u, holder.dmg * clampf(0.25 + rel / 650.0, 0.25, 1.1), "melee")
		else:
			holder.battle.clang(global_position, true)
	elif body is Weapon:
		var w := body as Weapon
		if not w.dropped and is_instance_valid(w.holder) and w.holder.side != holder.side:
			holder.battle.clang(global_position, true)


## Releases the grip: the weapon flies off a little and lies on the ground.
func drop() -> void:
	if dropped:
		return
	dropped = true
	collision_layer = 0
	collision_mask = LAYER_WALL
	linear_damp = 4.0
	angular_damp = 4.0
	apply_central_impulse(Vector2.from_angle(randf() * TAU) * 30.0 * mass)
	modulate = Color(0.8, 0.8, 0.8)


func _draw() -> void:
	for p in parts:
		var poly: PackedVector2Array = p["poly"]
		if p.get("line", false):
			draw_polyline(poly, INK, 5.0)
			draw_polyline(poly, p["col"], 3.0)
			draw_line(poly[0], poly[poly.size() - 1], INK, 1.0)
			continue
		draw_colored_polygon(poly, p["col"])
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, INK, 1.8)
