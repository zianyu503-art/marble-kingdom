class_name Weapon
extends RigidBody2D

## A weapon held by a marble. It is its own rigid body, pinned to the marble's
## hand with a PinJoint2D and kept in its grip angle by a torque spring, so it
## swings and gets knocked aside on impact, then recovers. When the marble
## dies the joint is removed and the weapon drops to the ground.

const INK := Color(0.07, 0.07, 0.09)
const STEEL := Color(0.86, 0.88, 0.92)
const DARK_STEEL := Color(0.55, 0.57, 0.62)
const WOOD := Color("8a5428")
const GOLD := Color("f2c230")
const LAYER_WALL := 1
const LAYER_BODY := 2
const LAYER_WEAPON := 4
const HIT_COOLDOWN := 0.25

var holder: Unit
var joint: PinJoint2D
var parts: Array = []
var hold_angle := 0.4
var length := 20.0
var dropped := false
var hit_times := {}


func setup(u: Unit, kind: String, l: float, w: float, hand: Vector2) -> void:
	holder = u
	length = l
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
	_build(kind, l, w)
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
	body_shape_entered.connect(_on_hit)


## Called once both bodies are in the tree.
func attach(root: Node, hand_global: Vector2) -> void:
	joint = PinJoint2D.new()
	joint.global_position = hand_global
	joint.softness = 0.0
	joint.disable_collision = true
	root.add_child(joint)
	joint.node_a = joint.get_path_to(holder)
	joint.node_b = joint.get_path_to(self)


## Weapon parts are built from the grip (origin) outward along +x.
func _build(kind: String, l: float, w: float) -> void:
	match kind:
		"sword", "greatsword":
			parts.append(_part(_rect(-5, -1.5, 6, 3), WOOD))
			parts.append(_part(_rect(1, -w * 0.5 - 4, 3, w + 8), GOLD if kind == "greatsword" else DARK_STEEL))
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


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if dropped or not is_instance_valid(holder):
		return
	# torque spring toward the grip angle; impacts knock the weapon away and it swings back
	var want := holder.rotation + hold_angle
	var err := wrapf(want - rotation, -PI, PI)
	var rel_av := state.angular_velocity - holder.angular_velocity
	var inertia := 1.0 / maxf(state.inverse_inertia, 0.000001)
	state.apply_torque((err * 260.0 - rel_av * 22.0) * inertia)


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
			holder.deal_damage(u, holder.dmg * clampf(0.4 + rel / 360.0, 0.4, 1.8), "melee")
		else:
			holder.battle.clang(global_position, true)
	elif body is Weapon:
		var w := body as Weapon
		if not w.dropped and is_instance_valid(w.holder) and w.holder.side != holder.side:
			holder.battle.clang(global_position, true)


## Breaks the grip: the weapon flies off a little and lies on the ground.
func drop() -> void:
	if dropped:
		return
	dropped = true
	if joint and is_instance_valid(joint):
		joint.queue_free()
	collision_layer = 0
	collision_mask = LAYER_WALL
	linear_damp = 4.0
	angular_damp = 4.0
	apply_central_impulse(Vector2.from_angle(randf() * TAU) * 30.0 * mass)
	modulate = Color(0.8, 0.8, 0.8)


func _physics_process(_delta: float) -> void:
	queue_redraw()


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
