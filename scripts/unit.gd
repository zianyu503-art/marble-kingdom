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
## Skills (see Skills.INFO) and their state.
var skills: Array = []
var skill_cd := {}
var stun_t := 0.0
var buff_t := 0.0
var whirl_t := 0.0
var bash_t := 0.0
var bash_target: Unit = null
var convert_t := 0.0
var convert_target: Unit = null


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
	skills = Skills.for_soldier(s, f)
	for sk in skills:
		skill_cd[sk] = randf_range(1.0, Skills.INFO[sk]["cd"])

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
	if stun_t > 0.0:
		# stunned: no steering, the marble just tumbles
		state.apply_torque(-state.angular_velocity * 2.0 / maxf(state.inverse_inertia, 0.000001))
		return
	state.apply_central_force(steer * drive * mass * (1.25 if buff_t > 0.0 else 1.0))
	var want := spin * spin_dir * (3.5 if whirl_t > 0.0 else 1.0)
	state.apply_torque((want - state.angular_velocity) * 6.0 / maxf(state.inverse_inertia, 0.000001))


func _physics_process(delta: float) -> void:
	if dead:
		return
	# only redraw while the look changes (hit flash, spectral sword); the body
	# itself is static and just rotates with the node transform
	if flash > 0.0 or fac.has("spectral"):
		queue_redraw()
	flash = maxf(0.0, flash - delta * 6.0)
	stun_t = maxf(0.0, stun_t - delta)
	buff_t = maxf(0.0, buff_t - delta)
	whirl_t = maxf(0.0, whirl_t - delta)
	if stun_t > 0.0:
		return
	_tick_skills(delta)
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
		var aimed := _aimed()
		if ranged_cd <= 0.0 and aimed and has_los and target and is_instance_valid(target) and not target.dead:
			if global_position.distance_to(target.global_position) < 460.0:
				battle.fire(self, target)
				ranged_cd = stats["cd"] * randf_range(0.85, 1.15)
	if fac.has("spectral"):
		spectral_angle += delta * 7.0
		var tip := global_position + Vector2.from_angle(spectral_angle) * (radius + 22.0)
		for u in battle.enemies_near(self, tip, 10.0):
			deal_damage(u, dmg * 0.5, "spectral")


func _aimed() -> bool:
	return weapon != null and is_instance_valid(weapon) and weapon.ready_to_fire()


func _target_ok() -> bool:
	return target != null and is_instance_valid(target) and not target.dead


# --------------------------------------------------------------- skills

func _tick_skills(delta: float) -> void:
	_tick_bash(delta)
	_tick_convert(delta)
	for sk in skills:
		skill_cd[sk] -= delta
		if skill_cd[sk] <= 0.0 and _cast(sk):
			skill_cd[sk] = Skills.INFO[sk]["cd"] * randf_range(0.9, 1.15)


## Tries to use a skill now; returns false when the situation doesn't fit.
func _cast(sk: String) -> bool:
	var d := INF
	if _target_ok():
		d = global_position.distance_to(target.global_position)
	match sk:
		"whirlwind":
			if d > 130.0:
				return false
			whirl_t = 1.6
		"bash":
			var reach := radius + target.radius if _target_ok() else 0.0
			if d > reach + 55.0 or d < reach - 2.0:
				return false
			apply_central_impulse((target.global_position - global_position).normalized() * 430.0 * mass)
			bash_t = 0.35
			bash_target = target
		"lunge", "dash":
			if d < 70.0 or d > (180.0 if sk == "lunge" else 230.0) or not has_los:
				return false
			apply_central_impulse((target.global_position - global_position).normalized() * (520.0 if sk == "lunge" else 450.0) * mass)
			if sk == "lunge" and weapon and is_instance_valid(weapon):
				weapon.start_attack()
		"slam":
			var r := 115.0 if soldier.type == "king" else 90.0
			var hits: Array = battle.enemies_near(self, global_position, r)
			if hits.size() < (1 if soldier.type == "king" and hp < max_hp * 0.6 else 2):
				return false
			for u in hits:
				deal_damage(u, dmg * 0.7, "skill")
				u.stun(1.0)
				u.apply_central_impulse((u.global_position - global_position).normalized() * 320.0 * u.mass)
			battle.shockwave(global_position, r, Skills.INFO["slam"]["col"])
			if soldier.type == "king":
				battle.skill_text(self, "ROYAL SLAM!", Color("ffd84a"))
				battle.stat_skill("slam")
				return true
		"warcry":
			if d > 260.0:
				return false
			var allies: Array = battle.allies_near(self, global_position, 170.0)
			if allies.size() < 3:
				return false
			for u in allies:
				u.buff_t = 5.0
			battle.shockwave(global_position, 170.0, Skills.INFO["warcry"]["col"])
		"volley":
			if d > 460.0 or not has_los or not _aimed():
				return false
			battle.fire_spread(self, target, 5, 0.32)
		"convert":
			if d > 270.0 or not has_los or convert_t > 0.0 or target.soldier.type in Skills.UNCONVERTIBLE or target.soldier.level >= 3:
				return false
			convert_t = 1.3
			convert_target = target
		"heal":
			var healed := false
			for u in battle.allies_near(self, global_position, 150.0):
				if u.hp < u.max_hp:
					u.hp = minf(u.max_hp, u.hp + 9.0)
					battle.heal_fx(u)
					healed = true
			if healed:
				battle.stat_skill("heal")
			return healed
		"raise":
			var n: int = battle.raise_skeletons(self, 220.0, 2)
			if n == 0:
				return false
		_:
			return false
	var title: String = Skills.INFO[sk]["title"]
	if title != "":
		battle.skill_text(self, title, Skills.INFO[sk]["col"])
	battle.stat_skill(sk)
	return true


func _tick_bash(delta: float) -> void:
	if bash_t <= 0.0:
		return
	bash_t -= delta
	if bash_target and is_instance_valid(bash_target) and not bash_target.dead:
		if global_position.distance_to(bash_target.global_position) < radius + bash_target.radius + 6.0:
			deal_damage(bash_target, dmg * 0.6, "skill")
			bash_target.stun(0.9)
			bash_target.apply_central_impulse((bash_target.global_position - global_position).normalized() * 380.0 * bash_target.mass)
			battle.clang(bash_target.global_position, true)
			bash_t = 0.0


func _tick_convert(delta: float) -> void:
	if convert_t <= 0.0:
		return
	convert_t -= delta
	var ok := convert_target != null and is_instance_valid(convert_target) and not convert_target.dead \
			and convert_target.side != side and global_position.distance_to(convert_target.global_position) < 320.0
	if not ok:
		convert_t = 0.0
		convert_target = null
	elif convert_t <= 0.0:
		battle.convert(convert_target, self)
		convert_target = null


func stun(t: float) -> void:
	stun_t = maxf(stun_t, t)
	convert_t = 0.0


## Moves this marble to the other side (monk conversion).
func switch_side(new_fac: Faction, new_side: int) -> void:
	fac = new_fac
	side = new_side
	color = new_fac.color
	soldier.faction = new_fac.id
	target = null
	convert_t = 0.0
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
		if (ranged != "" or stats.get("support", false)) and has_los and goal.length() < 200.0:
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
	elif (ranged != "" or stats.get("support", false)) and has_los and goal.length() < 300.0:
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
	if kind == "melee" or kind == "spectral":
		if now - float(hit_times.get(key, -10.0)) < HIT_COOLDOWN / Engine.time_scale:
			return
	hit_times[key] = now
	if buff_t > 0.0:
		amount *= 1.35
	if whirl_t > 0.0:
		amount *= 1.4
	var dealt := other.take_damage(amount, self)
	if fac.lifesteal() > 0.0:
		hp = minf(max_hp, hp + dealt * fac.lifesteal())


## Returns the damage actually applied.
func take_damage(amount: float, from: Unit) -> float:
	if dead:
		return 0.0
	var a := maxf(2.0, amount - fac.armor() - float(stats.get("armor", 0.0)))
	hp -= a
	flash = 1.0
	if from and is_instance_valid(from):
		apply_central_impulse((global_position - from.global_position).normalized() * a * 2.2 * mass)
		if fac.has("thorns") and not from.dead:
			# reflect part of the damage back (no attacker, so it can't bounce again)
			from.take_damage(a * 0.2 * fac.count("thorns"), null)
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
		"monk":
			draw_circle(Vector2.ZERO, radius * 0.55, Color("8a6a45"))
			draw_arc(Vector2.ZERO, radius * 0.55, 0, TAU, 16, INK, 1.2)
		"bard":
			draw_colored_polygon(PackedVector2Array([Vector2(-radius * 0.5, -radius * 0.2), Vector2(radius * 0.5, -radius * 0.2), Vector2(0, -radius * 0.75)]), Color("2f6d3a"))
			draw_line(Vector2(0, -radius * 0.75), Vector2(radius * 0.5, -radius * 1.1), Color("e04848"), 2.0)
		"necromancer":
			draw_circle(Vector2.ZERO, radius * 0.6, Color("26202e"))
			draw_circle(Vector2(radius * 0.18, -radius * 0.15), radius * 0.1, Color("b78cff"))
			draw_circle(Vector2(radius * 0.18, radius * 0.15), radius * 0.1, Color("b78cff"))
		"skeleton":
			for k in 3:
				var x := -radius * 0.35 + k * radius * 0.3
				draw_line(Vector2(x, -radius * 0.5), Vector2(x, radius * 0.5), Color(0.95, 0.94, 0.88), 2.0)
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
