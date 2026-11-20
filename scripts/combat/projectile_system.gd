class_name ProjectileSystem
extends Node3D

var horde_manager: Node = null
var explosion_system: ExplosionSystem = null
var decal_manager: BloodDecalManager = null
var player_ref: Node = null

var _bullets: Array[Dictionary] = []
var _bolts: Array[Dictionary] = []
var _tracer_mesh: BoxMesh
var _flame_mesh: SphereMesh

func _ready() -> void:
	_tracer_mesh = BoxMesh.new()
	_tracer_mesh.size = Vector3(0.08, 0.08, 1.15)
	_flame_mesh = SphereMesh.new()
	_flame_mesh.radius = 0.28
	_flame_mesh.height = 0.56

func spawn_projectile(origin: Vector3, dir: Vector3, weapon: Dictionary, is_crit: bool, dmg: float, pierce: int, bounces: int, explosive: bool) -> void:
	var is_flame: bool = weapon.get("is_flame", false)
	var m := MeshInstance3D.new()
	m.mesh = _flame_mesh if is_flame else _tracer_mesh
	var col: Color = weapon["color"]
	if explosive:
		col = Color(1.0, 0.35, 0.05)
	elif is_crit:
		col = Color(1.0, 0.96, 0.35)
	elif bounces > 0:
		col = Color(0.95, 1.0, 0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 7.5 if not is_flame else 5.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if is_flame:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.85
	m.material_override = mat
	m.position = origin
	add_child(m)
	if dir.length_squared() > 0.001:
		m.look_at(origin + dir, Vector3.UP)

	_bullets.append({
		"node": m,
		"pos": origin,
		"dir": dir.normalized(),
		"speed": float(weapon["speed"]),
		"dist": 0.0,
		"max_dist": float(weapon["range"]),
		"dmg": dmg,
		"is_crit": is_crit,
		"pierce": pierce,
		"bounces": bounces,
		"explosive": explosive,
		"is_flame": is_flame,
		"hit_ids": {},
	})

func spawn_chain_bolt(a: Vector3, b: Vector3) -> void:
	var m := MeshInstance3D.new()
	var d := a.distance_to(b)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.11, 0.11, maxf(0.1, d))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.95, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.95, 1.0)
	mat.emission_energy_multiplier = 9.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat
	m.mesh = bm
	add_child(m)
	m.global_position = (a + b) * 0.5 + Vector3(0, 0.9, 0)
	if d > 0.05:
		m.look_at(b + Vector3(0, 0.9, 0), Vector3.UP)
	_bolts.append({"node": m, "t": 0.14})

func _physics_process(delta: float) -> void:
	for i in range(_bolts.size() - 1, -1, -1):
		_bolts[i]["t"] -= delta
		if _bolts[i]["t"] <= 0.0:
			if is_instance_valid(_bolts[i]["node"]):
				_bolts[i]["node"].queue_free()
			_bolts.remove_at(i)

	if _bullets.is_empty():
		return
	var space := get_world_3d().direct_space_state
	for i in range(_bullets.size() - 1, -1, -1):
		var b: Dictionary = _bullets[i]
		var step: float = b["speed"] * delta
		var p0: Vector3 = b["pos"]
		var p1: Vector3 = p0 + b["dir"] * step
		var remove_me := false

		# 1. Check World Obstacles & Explodable Cars (Layer 1 & 4)
		var q := PhysicsRayQueryParameters3D.create(p0, p1, 1 | 4)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var collider = hit["collider"]
			var hpos: Vector3 = hit["position"]
			var hnorm: Vector3 = hit["normal"]
			if collider and collider.has_method("take_bullet_damage"):
				var mult := 2.2 if (b["is_crit"] and GameManager.has_perk("incendiary_crits")) else 1.0
				collider.take_bullet_damage(b["dmg"] * mult)
			if b["explosive"] and explosion_system:
				explosion_system.spawn_explosion(hpos, 3.2, b["dmg"] * 0.85, false)
			if b["bounces"] > 0 and not b["is_flame"]:
				b["bounces"] -= 1
				var ndir: Vector3 = b["dir"].bounce(Vector3(hnorm.x, 0.0, hnorm.z).normalized()).normalized()
				b["dir"] = ndir
				p1 = hpos + ndir * 0.25
				if is_instance_valid(b["node"]):
					b["node"].look_at(p1 + ndir, Vector3.UP)
				AudioManager.play_sfx("hit_armor", 1.4, 1.75, 0.4)
			else:
				remove_me = true

		# 2. Check Zombies via Spatial Hash Grid (Zero tunneling!)
		if not remove_me and horde_manager and horde_manager.has_method("check_projectile_hit"):
			var hit_enemies: Array = horde_manager.check_projectile_hit(p0, p1, 0.55 if b["is_flame"] else 0.28, b["hit_ids"])
			for z in hit_enemies:
				b["hit_ids"][z["uid"]] = true
				GameManager.shots_hit += 1
				var ignite: bool = b["is_flame"] or (b["is_crit"] and GameManager.has_perk("incendiary_crits"))
				var killed: bool = horde_manager.damage_zombie(z, b["dmg"], b["dir"], b["is_crit"], ignite)
				# Hit and Run stamina gain
				var stam_gain := GameManager.get_stat_sum("stamina_on_hit")
				if stam_gain > 0.0:
					GameManager.stamina = minf(GameManager.max_stamina, GameManager.stamina + stam_gain)
				# Vampire lifesteal
				if GameManager.has_perk("duality_vampire"):
					GameManager.heal_player(1.6 if not b["is_crit"] else 3.2)
				# Explosive bullets (Get Cooked)
				if b["explosive"] and explosion_system:
					explosion_system.spawn_explosion(z["pos"], 3.0, b["dmg"] * 0.8, false)
				# Chain Overcharge lightning arcs on kill!
				if killed and GameManager.has_chaos_buff("chain"):
					var nearby: Array = horde_manager.get_nearest_zombies(z["pos"], 7.5, 2, z["uid"])
					for nz in nearby:
						spawn_chain_bolt(z["pos"], nz["pos"])
						horde_manager.damage_zombie(nz, b["dmg"] * 0.85, (nz["pos"] - z["pos"]).normalized(), false, false)
				if b["pierce"] > 0:
					b["pierce"] -= 1
				else:
					remove_me = true
					break

		b["pos"] = p1
		b["dist"] += step
		if b["dist"] >= b["max_dist"]:
			remove_me = true

		if remove_me:
			if is_instance_valid(b["node"]):
				b["node"].queue_free()
			_bullets.remove_at(i)
		else:
			if is_instance_valid(b["node"]):
				b["node"].position = p1
				if b["is_flame"]:
					var sc: float = 1.0 + (float(b["dist"]) / float(b["max_dist"])) * 2.6
					b["node"].scale = Vector3.ONE * sc
