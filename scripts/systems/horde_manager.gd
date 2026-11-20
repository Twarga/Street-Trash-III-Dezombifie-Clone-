class_name HordeManager
extends Node3D

signal damage_popup(world_pos: Vector3, amount: int, is_crit: bool)
signal pickup_spawned(node: Node3D, kind: String)

var player_ref: Node3D = null
var decal_manager: BloodDecalManager = null
var explosion_system: ExplosionSystem = null
var vfx_juice: VFXJuice = null

var _grid := SpatialHashGrid.new()
var _zombies: Array[Dictionary] = []
var _corpses: Array[Dictionary] = []
var _enemy_projectiles: Array[Dictionary] = []
var _turrets: Array[Dictionary] = []
var _turret_tracers: Array[Dictionary] = []
var _uid_counter: int = 1
var _medkit_scene: PackedScene
var _spawn_timer: float = 1.2
var _groan_timer: float = 2.5
var _hit_flash_mat: StandardMaterial3D
var _burn_mat: StandardMaterial3D
var _mat_cache: Dictionary = {}
var _boss_ref: Dictionary = {}
var _active_boss_uid: int = -1
var _boss_slam_vfx: Array[Dictionary] = []
var _medkits: Array[Node3D] = []

const MAX_ACTIVE_ZOMBIES := 90

func _ready() -> void:
	if ResourceLoader.exists("res://assets/models/pickup_medkit.glb"):
		_medkit_scene = load("res://assets/models/pickup_medkit.glb")

	_hit_flash_mat = StandardMaterial3D.new()
	_hit_flash_mat.albedo_color = Color(1, 1, 1)
	_hit_flash_mat.emission_enabled = true
	_hit_flash_mat.emission = Color(1.0, 0.96, 0.9)
	_hit_flash_mat.emission_energy_multiplier = 4.0

	_burn_mat = StandardMaterial3D.new()
	_burn_mat.albedo_color = Color(1.0, 0.45, 0.08)
	_burn_mat.emission_enabled = true
	_burn_mat.emission = Color(1.0, 0.35, 0.04)
	_burn_mat.emission_energy_multiplier = 3.5

func _m(key: String, col: Color, rough: float = 0.80, metal: float = 0.05, em: Color = Color.BLACK, em_e: float = 0.0) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	mat.metallic = metal
	if em_e > 0.0:
		mat.emission_enabled = true
		mat.emission = em
		mat.emission_energy_multiplier = em_e
	_mat_cache[key] = mat
	return mat

func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3, out_meshes: Array[MeshInstance3D]) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.set_meta("base_mat", mat)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.layers = 2
	parent.add_child(mi)
	out_meshes.append(mi)
	return mi

func _build_zombie_rig(kind: String, out_meshes: Array[MeshInstance3D]) -> Dictionary:
	var rig_root := Node3D.new()
	var sc := 1.0
	var skin_m := _m("z_skin_sh", Color(0.36, 0.44, 0.34), 0.85)
	var cloth_m := _m("z_cl_sh", Color(0.22, 0.24, 0.28), 0.90)
	var pants_m := _m("z_pt_sh", Color(0.14, 0.16, 0.20), 0.92)
	var eye_m := _m("z_eye_yel", Color(1.0, 0.92, 0.35), 0.2, 0.0, Color(1.0, 0.85, 0.2), 4.5)
	var torso_w := 0.44
	var torso_d := 0.26

	if kind == "sprinter":
		sc = 0.94
		skin_m = _m("z_skin_sp", Color(0.45, 0.34, 0.32), 0.82)
		cloth_m = _m("z_cl_sp", Color(0.48, 0.10, 0.10), 0.85)
		eye_m = _m("z_eye_red", Color(1.0, 0.15, 0.12), 0.2, 0.0, Color(1.0, 0.12, 0.08), 5.5)
		torso_w = 0.38
	elif kind == "bruiser":
		sc = 1.28
		skin_m = _m("z_skin_br", Color(0.32, 0.36, 0.32), 0.80)
		cloth_m = _m("z_cl_br", Color(0.10, 0.13, 0.18), 0.45, 0.55)
		pants_m = _m("z_pt_br", Color(0.08, 0.10, 0.14), 0.60, 0.35)
		eye_m = _m("z_eye_cy", Color(0.25, 0.95, 1.0), 0.2, 0.0, Color(0.22, 0.92, 1.0), 5.0)
		torso_w = 0.58; torso_d = 0.34
	elif kind == "bloater":
		sc = 1.22
		skin_m = _m("z_skin_bl", Color(0.30, 0.46, 0.22), 0.55)
		cloth_m = _m("z_cl_bl", Color(0.22, 0.36, 0.16), 0.55)
		eye_m = _m("z_eye_gr", Color(0.40, 1.0, 0.18), 0.2, 0.0, Color(0.35, 1.0, 0.15), 6.0)
		torso_w = 0.66; torso_d = 0.48
	elif kind == "spitter":
		sc = 1.02
		skin_m = _m("z_skin_st", Color(0.24, 0.38, 0.26), 0.60)
		cloth_m = _m("z_cl_st", Color(0.14, 0.22, 0.18), 0.68)
		eye_m = _m("z_eye_ac", Color(0.55, 1.0, 0.12), 0.2, 0.0, Color(0.50, 1.0, 0.10), 6.5)
		torso_w = 0.40; torso_d = 0.26
	elif kind == "charger":
		sc = 1.38
		skin_m = _m("z_skin_ch", Color(0.42, 0.16, 0.14), 0.72)
		cloth_m = _m("z_cl_ch", Color(0.18, 0.08, 0.08), 0.55, 0.35)
		eye_m = _m("z_eye_ch", Color(1.0, 0.32, 0.08), 0.1, 0.0, Color(1.0, 0.25, 0.05), 7.0)
		torso_w = 0.62; torso_d = 0.38
	elif kind == "boss":
		sc = 2.05
		skin_m = _m("z_skin_bo", Color(0.22, 0.14, 0.15), 0.65, 0.15)
		cloth_m = _m("z_cl_bo", Color(0.12, 0.08, 0.09), 0.48, 0.45)
		eye_m = _m("z_eye_mag", Color(1.0, 0.22, 0.06), 0.1, 0.0, Color(1.0, 0.18, 0.04), 7.5)
		torso_w = 0.64; torso_d = 0.38

	rig_root.scale = Vector3.ONE * sc
	var hips := Node3D.new()
	hips.position = Vector3(0.0, 0.88, 0.0)
	rig_root.add_child(hips)

	# Articulated Legs
	var thigh := CapsuleMesh.new(); thigh.radius = 0.095; thigh.height = 0.46
	var shin := CapsuleMesh.new(); shin.radius = 0.082; shin.height = 0.42
	var leg_l := Node3D.new(); leg_l.position = Vector3(-0.14, -0.04, 0.0); hips.add_child(leg_l)
	_part(leg_l, thigh, pants_m, Vector3(0, -0.21, 0), Vector3.ZERO, out_meshes)
	var shin_l := Node3D.new(); shin_l.position = Vector3(0, -0.42, 0); leg_l.add_child(shin_l)
	_part(shin_l, shin, pants_m, Vector3(0, -0.20, 0), Vector3.ZERO, out_meshes)

	var leg_r := Node3D.new(); leg_r.position = Vector3(0.14, -0.04, 0.0); hips.add_child(leg_r)
	_part(leg_r, thigh, pants_m, Vector3(0, -0.21, 0), Vector3.ZERO, out_meshes)
	var shin_r := Node3D.new(); shin_r.position = Vector3(0, -0.42, 0); leg_r.add_child(shin_r)
	_part(shin_r, shin, pants_m, Vector3(0, -0.20, 0), Vector3.ZERO, out_meshes)

	# Articulated Torso
	var torso := Node3D.new(); torso.position = Vector3(0.0, 0.08, 0.0); hips.add_child(torso)
	var chest := BoxMesh.new(); chest.size = Vector3(torso_w, 0.54, torso_d)
	_part(torso, chest, cloth_m, Vector3(0, 0.27, 0), Vector3.ZERO, out_meshes)

	# Archetype signature visual details!
	var glow_mat := eye_m
	if kind == "bruiser":
		var pad := BoxMesh.new(); pad.size = Vector3(0.20, 0.20, 0.26)
		_part(torso, pad, cloth_m, Vector3(-0.34, 0.46, 0), Vector3.ZERO, out_meshes)
		_part(torso, pad, cloth_m, Vector3(0.34, 0.46, 0), Vector3.ZERO, out_meshes)
	elif kind == "bloater":
		var sac := SphereMesh.new(); sac.radius = 0.24; sac.height = 0.48
		_part(torso, sac, glow_mat, Vector3(0.12, 0.30, 0.20), Vector3.ZERO, out_meshes)
		_part(torso, sac, glow_mat, Vector3(-0.18, 0.42, -0.14), Vector3.ZERO, out_meshes)
	elif kind == "spitter":
		var vent := SphereMesh.new(); vent.radius = 0.14; vent.height = 0.28
		_part(torso, vent, glow_mat, Vector3(0.0, 0.48, -0.16), Vector3.ZERO, out_meshes)
		_part(torso, vent, glow_mat, Vector3(0.0, 0.30, -0.18), Vector3.ZERO, out_meshes)
	elif kind == "charger":
		sc = 1.38
		skin_m = _m("z_skin_ch", Color(0.42, 0.16, 0.14), 0.72)
		cloth_m = _m("z_cl_ch", Color(0.18, 0.08, 0.08), 0.55, 0.35)
		eye_m = _m("z_eye_ch", Color(1.0, 0.32, 0.08), 0.1, 0.0, Color(1.0, 0.25, 0.05), 7.0)
		torso_w = 0.62; torso_d = 0.38
	elif kind == "boss":
		var core := BoxMesh.new(); core.size = Vector3(0.42, 0.36, 0.41)
		_part(torso, core, glow_mat, Vector3(0, 0.30, 0), Vector3.ZERO, out_meshes)

	# Head + Glowing Eyes
	var head := Node3D.new(); head.position = Vector3(0.0, 0.60, 0.04); torso.add_child(head)
	var skull := SphereMesh.new(); skull.radius = 0.165; skull.height = 0.34
	_part(head, skull, skin_m, Vector3(0, 0.14, 0), Vector3.ZERO, out_meshes)
	var eye := BoxMesh.new(); eye.size = Vector3(0.06, 0.04, 0.04)
	_part(head, eye, eye_m, Vector3(-0.065, 0.16, 0.15), Vector3.ZERO, out_meshes)
	_part(head, eye, eye_m, Vector3(0.065, 0.16, 0.15), Vector3.ZERO, out_meshes)
	if kind == "charger":
		var horn := CylinderMesh.new(); horn.top_radius = 0.01; horn.bottom_radius = 0.055; horn.height = 0.34
		_part(head, horn, eye_m, Vector3(-0.14, 0.28, 0.08), Vector3(38, 0, 28), out_meshes)
		_part(head, horn, eye_m, Vector3(0.14, 0.28, 0.08), Vector3(38, 0, -28), out_meshes)
	if kind == "bruiser":
		var helm := SphereMesh.new(); helm.radius = 0.19; helm.height = 0.24
		_part(head, helm, cloth_m, Vector3(0, 0.22, -0.01), Vector3.ZERO, out_meshes)

	# Articulated Arms (reach out & slash!)
	var arm_m := CapsuleMesh.new(); arm_m.radius = 0.072; arm_m.height = 0.56
	var arm_l := Node3D.new(); arm_l.position = Vector3(-(torso_w * 0.5 + 0.08), 0.48, 0.0); torso.add_child(arm_l)
	_part(arm_l, arm_m, skin_m, Vector3(0, -0.24, 0), Vector3.ZERO, out_meshes)
	var arm_r := Node3D.new(); arm_r.position = Vector3((torso_w * 0.5 + 0.08), 0.48, 0.0); torso.add_child(arm_r)
	_part(arm_r, arm_m, skin_m, Vector3(0, -0.24, 0), Vector3.ZERO, out_meshes)

	return {
		"root": rig_root, "hips": hips, "torso": torso, "head": head,
		"leg_l": leg_l, "leg_r": leg_r, "shin_l": shin_l, "shin_r": shin_r,
		"arm_l": arm_l, "arm_r": arm_r
	}

func spawn_zombie(kind: String, pos: Vector3) -> Dictionary:
	if not GameData.ENEMIES.has(kind):
		kind = "shambler"
	var cfg: Dictionary = GameData.ENEMIES[kind]
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.0, pos.z)
	add_child(root)

	var meshes: Array[MeshInstance3D] = []
	var rig := _build_zombie_rig(kind, meshes)
	root.add_child(rig["root"])

	var max_hp: float = float(cfg["hp"]) * GameManager.get_diff_enemy_hp_mult() * (1.0 + GameManager.elapsed_time / 760.0)
	var z := {
		"uid": _uid_counter,
		"kind": kind,
		"cfg": cfg,
		"node": root,
		"rig": rig,
		"meshes": meshes,
		"pos": Vector3(pos.x, 0.0, pos.z),
		"vel": Vector3.ZERO,
		"kb": Vector3.ZERO,
		"hp": max_hp,
		"max_hp": max_hp,
		"radius": float(cfg["radius"]),
		"flash_t": 0.0,
		"burn_t": 0.0,
		"stagger_t": 0.0,
		"atk_anim": 0.0,
		"atk_cd": 0.0,
		"shoot_cd": randf_range(1.6, 2.8),
		"slam_cd": 4.5, "charge_cd": randf_range(2.2, 3.6), "charge_windup": 0.0, "charge_t": 0.0, "charge_dir": Vector3.ZERO,
		"phase": randf() * TAU,
		"alive": true,
	}
	_uid_counter += 1
	_zombies.append(z)
	if kind == "boss":
		_active_boss_uid = z["uid"]
		_boss_ref = z
		GameManager.boss_spawned.emit(cfg["name"], max_hp, max_hp)
		AudioManager.play_vo("vo_boss", "Warning! Heavy bio-signature ahead. A High-Rise Brute just broke containment!", false)
	return z

func _animate_zombie(z: Dictionary, delta: float, move_speed: float) -> void:
	var rig: Dictionary = z["rig"]
	var kind: String = z["kind"]
	var hips: Node3D = rig["hips"]
	var torso: Node3D = rig["torso"]
	var head: Node3D = rig["head"]
	var leg_l: Node3D = rig["leg_l"]
	var leg_r: Node3D = rig["leg_r"]
	var shin_l: Node3D = rig["shin_l"]
	var shin_r: Node3D = rig["shin_r"]
	var arm_l: Node3D = rig["arm_l"]
	var arm_r: Node3D = rig["arm_r"]

	var freq := 2.4 if kind == "sprinter" else (1.45 if kind in ["bruiser", "bloater", "boss"] else 1.85)
	z["phase"] = float(z["phase"]) + delta * (1.8 + move_speed * freq)
	var ph: float = float(z["phase"])
	var s := sin(ph)
	var c := cos(ph)

	z["stagger_t"] = maxf(0.0, float(z["stagger_t"]) - delta * 6.0)
	z["atk_anim"] = maxf(0.0, float(z["atk_anim"]) - delta * 4.2)
	var stag := float(z["stagger_t"])
	var atk := sin(float(z["atk_anim"]) * PI)

	var stride_amp := clampf(move_speed / 3.8, 0.15, 1.15)
	if kind == "sprinter":
		leg_l.rotation.x = s * 1.15 * stride_amp
		leg_r.rotation.x = -s * 1.15 * stride_amp
		shin_l.rotation.x = clampf(-c * 1.3, 0.0, 1.35)
		shin_r.rotation.x = clampf(c * 1.3, 0.0, 1.35)
		hips.position.y = 0.86 + absf(s) * 0.15
		torso.rotation.x = 0.42 - stag * 0.45 + atk * 0.35
		arm_l.rotation.x = -0.95 - s * 0.85 - atk * 0.9
		arm_r.rotation.x = -0.95 + s * 0.85 - atk * 0.9
	elif kind in ["bruiser", "boss", "charger"]:
		leg_l.rotation.x = s * 0.65 * stride_amp
		leg_r.rotation.x = -s * 0.65 * stride_amp
		shin_l.rotation.x = clampf(-c * 0.65, 0.0, 0.75)
		shin_r.rotation.x = clampf(c * 0.65, 0.0, 0.75)
		hips.position.y = 0.88 + absf(s) * 0.08
		torso.rotation.z = s * 0.14
		torso.rotation.x = 0.15 - stag * 0.25 + atk * 0.5
		arm_l.rotation.x = -0.65 + s * 0.35 - atk * 1.5
		arm_r.rotation.x = -0.65 - s * 0.35 - atk * 1.5
	elif kind == "spitter":
		leg_l.rotation.x = s * 0.72 * stride_amp
		leg_r.rotation.x = -s * 0.72 * stride_amp
		shin_l.rotation.x = clampf(-c * 0.8, 0.0, 0.9)
		shin_r.rotation.x = clampf(c * 0.8, 0.0, 0.9)
		hips.position.y = 0.84 + absf(s) * 0.07
		# Spitter rears back then snaps forward when firing!
		torso.rotation.x = 0.32 - stag * 0.45 - atk * 0.55
		arm_l.rotation.x = -0.55 + atk * 0.4
		arm_r.rotation.x = -0.55 + atk * 0.4
		head.rotation.x = -0.25 - atk * 0.4
	else:
		# Classic creepy asymmetric shambler/bloater limp + outstretched arms!
		leg_l.rotation.x = s * 0.75 * stride_amp
		leg_r.rotation.x = -s * 0.55 * stride_amp
		shin_l.rotation.x = clampf(-c * 0.75, 0.0, 0.85)
		shin_r.rotation.x = clampf(c * 0.45, 0.0, 0.65)
		hips.position.y = 0.85 + absf(s) * 0.07
		torso.rotation.z = 0.12 + s * 0.16
		torso.rotation.x = 0.26 - stag * 0.52 + atk * 0.42
		arm_l.rotation.x = -1.38 + s * 0.24 - atk * 0.75
		arm_r.rotation.x = -1.25 - s * 0.28 - atk * 0.75
		head.rotation.z = -0.18 + c * 0.14

func _spawn_enemy_projectile(origin: Vector3, dir: Vector3, speed: float, dmg: float, col: Color) -> void:
	var m := MeshInstance3D.new()
	var sp := SphereMesh.new(); sp.radius = 0.20; sp.height = 0.40
	m.mesh = sp
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 6.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = origin
	var lgt := OmniLight3D.new()
	lgt.light_color = col
	lgt.light_energy = 2.8
	lgt.omni_range = 6.0
	lgt.shadow_enabled = false
	m.add_child(lgt)
	add_child(m)
	_enemy_projectiles.append({
		"node": m, "pos": origin, "vel": dir.normalized() * speed,
		"dmg": dmg, "col": col, "life": 2.8
	})

func _physics_process(delta: float) -> void:
	if not GameManager.run_active or GameManager.intro_playing or player_ref == null:
		return

	# 1. Dynamic Wave Spawning around player anywhere in the open city
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		var intensity := 1.0 + GameManager.elapsed_time / 170.0 + float(GameManager.gears) * 0.35
		if GameManager.holdout_active:
			intensity *= 1.85
		var cap := mini(MAX_ACTIVE_ZOMBIES, int(34 + intensity * 16))
		if _zombies.size() < cap:
			var burst := mini(cap - _zombies.size(), int(3 + intensity * 1.4))
			for _i in range(burst):
				_spawn_wave_member(intensity)
		_spawn_timer = clampf(1.05 / sqrt(intensity), 0.32, 1.05)

	# 2. Ambient Zombie Groans
	_groan_timer -= delta
	if _groan_timer <= 0.0 and _zombies.size() >= 3:
		_groan_timer = randf_range(2.6, 5.2)
		AudioManager.play_sfx("zombie_groan_%d" % (1 + randi() % 3), 0.85, 1.15, 0.38)

	# 3. Rebuild Spatial Hash Grid
	_grid.clear()
	for z in _zombies:
		_grid.insert(z["pos"], z)

	var ppos := player_ref.global_position
	ppos.y = 0.0
	var space := get_world_3d().direct_space_state

	# 4. Simulate Horde (Kinematics + Boids + Melee + Ranged Spitter & Boss Projectiles!)
	for i in range(_zombies.size() - 1, -1, -1):
		var z: Dictionary = _zombies[i]
		if not z["alive"]:
			continue
		var zpos: Vector3 = z["pos"]
		var to_p := ppos - zpos
		to_p.y = 0.0
		var dist := to_p.length()

		if dist > 62.0 and z["kind"] != "boss":
			if is_instance_valid(z["node"]):
				z["node"].queue_free()
			_zombies.remove_at(i)
			continue

		if z["flash_t"] > 0.0:
			z["flash_t"] -= delta
			if z["flash_t"] <= 0.0:
				_set_override_mat(z, _burn_mat if z["burn_t"] > 0.0 else null)
		if z["burn_t"] > 0.0:
			z["burn_t"] -= delta
			z["hp"] -= 16.0 * delta
			if z["burn_t"] <= 0.0 and z["flash_t"] <= 0.0:
				_set_override_mat(z, null)
			if z["hp"] <= 0.0:
				_kill_zombie(z, Vector3.UP)
				continue

		if decal_manager and z["kind"] != "bloater" and z["kind"] != "spitter" and decal_manager.is_in_acid(zpos):
			z["hp"] -= 22.0 * delta
			if z["hp"] <= 0.0:
				_kill_zombie(z, Vector3.UP)
				continue

		var desired := (to_p / maxf(dist, 0.001))
		var sep := Vector3.ZERO
		var neighbors := _grid.query_radius(zpos, 1.9)
		for nb in neighbors:
			if nb["uid"] == z["uid"]:
				continue
			var diff: Vector3 = zpos - nb["pos"]
			diff.y = 0.0
			var d2 := diff.length_squared()
			var min_d: float = z["radius"] + nb["radius"]
			if d2 > 0.0001 and d2 < min_d * min_d:
				var d := sqrt(d2)
				sep += (diff / d) * ((min_d - d) / min_d) * 2.4

		var is_spitter: bool = (z["kind"] == "spitter")
		var spd: float = float(z["cfg"]["speed"])
		var move_mult := 1.0
		if is_spitter and dist < 11.5 and dist > 6.5:
			move_mult = 0.15 # Hold range to aim and shoot!
		elif is_spitter and dist <= 6.5:
			desired = -desired * 0.65 # Kite backward slightly

		var move_dir := (desired + sep).normalized()
		if z["kind"] == "charger":
			if float(z["charge_t"]) > 0.0:
				z["charge_t"] = float(z["charge_t"]) - delta
				move_dir = z["charge_dir"]
				move_mult = 4.35
			elif float(z["charge_windup"]) > 0.0:
				z["charge_windup"] = float(z["charge_windup"]) - delta
				move_mult = 0.05
				z["atk_anim"] = 0.5
				if float(z["charge_windup"]) <= 0.0:
					z["charge_t"] = 0.72
					z["charge_dir"] = (ppos - zpos).normalized()
					AudioManager.play_sfx("dash_whoosh", 0.55, 0.72, 0.9)
			else:
				z["charge_cd"] = float(z["charge_cd"]) - delta
				if float(z["charge_cd"]) <= 0.0 and dist > 4.5 and dist < 14.0:
					z["charge_cd"] = randf_range(3.6, 5.0)
					z["charge_windup"] = 0.62
					if vfx_juice: vfx_juice.spawn_shockwave_ring(zpos + Vector3(0, 0.12, 0), 2.2, Color(1.0, 0.22, 0.08))
		var step_vec: Vector3 = (move_dir * spd * move_mult + z["kb"]) * delta
		z["kb"] = z["kb"].move_toward(Vector3.ZERO, 24.0 * delta)

		var next_pos := zpos + step_vec
		next_pos.x = clampf(next_pos.x, -56.0, 56.0)
		next_pos.z = clampf(next_pos.z, -170.0, 13.0)
		var q := PhysicsRayQueryParameters3D.create(Vector3(zpos.x, 0.7, zpos.z), Vector3(next_pos.x, 0.7, next_pos.z), 1 | 4)
		var hit := space.intersect_ray(q)
		var actual_spd := spd * move_mult
		if hit.is_empty():
			zpos = next_pos
		else:
			var nrm: Vector3 = hit["normal"]
			nrm.y = 0.0
			var tang := Vector3(-nrm.z, 0.0, nrm.x)
			if tang.dot(desired) < 0.0:
				tang = -tang
			zpos += tang * spd * 0.75 * delta
			actual_spd = spd * 0.6

		z["pos"] = zpos
		var nd: Node3D = z["node"]
		nd.position = zpos
		var face_dir := (to_p / maxf(dist, 0.001)) if is_spitter else move_dir
		if face_dir.length_squared() > 0.01:
			nd.rotation.y = lerp_angle(nd.rotation.y, atan2(face_dir.x, face_dir.z), minf(1.0, delta * 10.0))

		_animate_zombie(z, delta, actual_spd)

		# Invulnerable shockwave kills touching zombies
		var reach: float = z["radius"] + 0.65
		if dist < reach + 0.55 and GameManager.is_invulnerable():
			damage_zombie(z, 90.0 * delta * 8.0, -desired, true, false)
			continue

		# Melee Attack
		if z["atk_cd"] > 0.0:
			z["atk_cd"] -= delta
		elif dist <= reach:
			z["atk_cd"] = 0.95 if z["kind"] != "sprinter" else 0.68
			z["atk_anim"] = 1.0
			GameManager.damage_player(float(z["cfg"]["damage"]))

		# Ranged Toxic Spitter Attack!
		if is_spitter:
			z["shoot_cd"] -= delta
			if z["shoot_cd"] <= 0.0 and dist > 4.0 and dist < 17.0:
				z["shoot_cd"] = randf_range(2.2, 3.0)
				z["atk_anim"] = 1.0
				var aim := (ppos - zpos).normalized()
				_spawn_enemy_projectile(zpos + Vector3(0, 1.35, 0) + aim * 0.6, aim, 13.5, 13.0, Color(0.45, 1.0, 0.14))
				AudioManager.play_sfx("bloater_pop", 1.3, 1.55, 0.52)

		# Boss Ground-Slam + Mid-Range Fireball Volley!
		if z["kind"] == "boss":
			z["slam_cd"] -= delta
			if z["slam_cd"] <= 0.0 and dist < 8.5:
				z["slam_cd"] = 5.5
				z["atk_anim"] = 1.0
				_spawn_boss_slam(zpos)
			z["shoot_cd"] -= delta
			if z["shoot_cd"] <= 0.0 and dist >= 7.0 and dist < 24.0:
				z["shoot_cd"] = 4.2
				z["atk_anim"] = 1.0
				var base_aim := (ppos - zpos).normalized()
				for ang in [-0.24, 0.0, 0.24]:
					var d := base_aim.rotated(Vector3.UP, ang)
					_spawn_enemy_projectile(zpos + Vector3(0, 2.2, 0) + d * 1.1, d, 14.5, 18.0, Color(1.0, 0.30, 0.08))
				AudioManager.play_sfx("explosion", 1.3, 1.5, 0.45)

	# 5. Update Enemy Projectiles (dodgeable glowing acid & magma bolts!)
	for i in range(_enemy_projectiles.size() - 1, -1, -1):
		var ep: Dictionary = _enemy_projectiles[i]
		ep["life"] -= delta
		var old_p: Vector3 = ep["pos"]
		var new_p: Vector3 = old_p + (ep["vel"] as Vector3) * delta
		ep["pos"] = new_p
		if is_instance_valid(ep["node"]):
			(ep["node"] as Node3D).position = new_p
		var hit_wall := not space.intersect_ray(PhysicsRayQueryParameters3D.create(old_p, new_p, 1 | 4)).is_empty()
		var hit_player := Vector2(new_p.x - ppos.x, new_p.z - ppos.z).length() < 0.78
		if hit_player:
			GameManager.damage_player(float(ep["dmg"]))
		if hit_player or hit_wall or ep["life"] <= 0.0:
			if vfx_juice:
				vfx_juice.spawn_shockwave_ring(Vector3(new_p.x, 0.1, new_p.z), 1.4, ep["col"])
			if is_instance_valid(ep["node"]):
				(ep["node"] as Node3D).queue_free()
			_enemy_projectiles.remove_at(i)

	# 6. Smooth Death-Collapse Corpses
	for i in range(_corpses.size() - 1, -1, -1):
		var cp: Dictionary = _corpses[i]
		cp["t"] -= delta
		if is_instance_valid(cp["node"]):
			var n: Node3D = cp["node"]
			cp["fall"] = minf(1.0, float(cp["fall"]) + delta * 4.5)
			n.rotation.x = lerpf(0.0, float(cp["dir_sign"]) * 1.48, ease(float(cp["fall"]), 0.45))
			n.position.y = lerpf(0.0, 0.14, float(cp["fall"]))
		if cp["t"] <= 0.0:
			if is_instance_valid(cp["node"]):
				(cp["node"] as Node3D).queue_free()
			_corpses.remove_at(i)

	# 7. Boss Slams
	for i in range(_boss_slam_vfx.size() - 1, -1, -1):
		var sl: Dictionary = _boss_slam_vfx[i]
		sl["t"] += delta
		var p: float = sl["t"] / sl["dur"]
		if is_instance_valid(sl["node"]):
			sl["node"].scale = Vector3(lerpf(0.2, 4.5, p), 1.0, lerpf(0.2, 4.5, p))
		if p >= 1.0:
			if player_ref and player_ref.global_position.distance_to(sl["pos"]) < 4.5:
				GameManager.damage_player(28.0)
			if explosion_system:
				explosion_system.spawn_explosion(sl["pos"], 4.0, 40.0, false, Color(1.0, 0.15, 0.08))
			if is_instance_valid(sl["node"]):
				sl["node"].queue_free()
			_boss_slam_vfx.remove_at(i)

	_update_sentry_turrets(delta)

	# 8. Medkit magnet & pickup
	var pull_r := GameManager.get_pickup_radius()
	for i in range(_medkits.size() - 1, -1, -1):
		var mk := _medkits[i]
		if not is_instance_valid(mk):
			_medkits.remove_at(i)
			continue
		mk.rotation.y += delta * 2.2
		var d := mk.global_position.distance_to(ppos)
		if d < pull_r * 1.4:
			mk.global_position = mk.global_position.move_toward(Vector3(ppos.x, 0.3, ppos.z), delta * 11.0)
		if d < 1.25:
			GameManager.heal_player(35.0)
			AudioManager.play_sfx("pickup_health", 0.96, 1.05, 0.85)
			mk.queue_free()
			_medkits.remove_at(i)

func _spawn_wave_member(intensity: float) -> void:
	if player_ref == null:
		return
	var ppos := player_ref.global_position
	var ang := randf() * TAU
	var dist := randf_range(14.5, 24.0)
	var sx := clampf(ppos.x + cos(ang) * dist, -48.0, 48.0)
	var sz := clampf(ppos.z + sin(ang) * dist, -165.0, 8.0)
	# Bias spawning onto open streets/plazas rather than inside buildings
	if absf(sx) > 10.5 and not ((sz < -18.0 and sz > -50.0) or (sz < -76.0 and sz > -108.0) or sz < -130.0):
		sx = randf_range(-9.5, 9.5)
	var roll := randf()
	var kind := "shambler"
	if intensity > 1.15 and roll < 0.14:
		kind = "spitter"
	elif intensity > 1.25 and roll < 0.25:
		kind = "charger"
	elif intensity > 1.65 and roll < 0.27:
		kind = "bloater"
	elif intensity > 1.35 and roll < 0.38:
		kind = "bruiser"
	elif intensity > 1.10 and roll < 0.56:
		kind = "sprinter"
	spawn_zombie(kind, Vector3(sx, 0.0, sz))

func _spawn_boss_slam(pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0; cyl.bottom_radius = 1.0; cyl.height = 0.06
	m.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.12, 0.08, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.12, 0.08)
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = Vector3(pos.x, 0.08, pos.z)
	add_child(m)
	_boss_slam_vfx.append({"node": m, "pos": Vector3(pos.x, 0.0, pos.z), "t": 0.0, "dur": 1.0})

func check_projectile_hit(p0: Vector3, p1: Vector3, proj_r: float, exclude_uids: Dictionary) -> Array:
	var mid := (p0 + p1) * 0.5
	var seg_len := p0.distance_to(p1)
	var candidates := _grid.query_radius(mid, seg_len * 0.5 + 1.5)
	var hits: Array = []
	var seg := Vector2(p1.x - p0.x, p1.z - p0.z)
	var seg_len2 := seg.length_squared()
	for z in candidates:
		if not z["alive"] or exclude_uids.has(z["uid"]):
			continue
		var zp := Vector2(z["pos"].x, z["pos"].z)
		var ap := zp - Vector2(p0.x, p0.z)
		var t := clampf(ap.dot(seg) / maxf(seg_len2, 0.0001), 0.0, 1.0)
		var closest := Vector2(p0.x, p0.z) + seg * t
		var r: float = z["radius"] + proj_r
		if closest.distance_squared_to(zp) <= r * r:
			hits.append(z)
	return hits

func get_nearest_zombies(origin: Vector3, radius: float, max_count: int, exclude_uid: int = -1) -> Array:
	var cands := _grid.query_radius(origin, radius)
	var valid: Array = []
	for z in cands:
		if z["alive"] and z["uid"] != exclude_uid and z["pos"].distance_to(origin) <= radius:
			valid.append(z)
	valid.sort_custom(func(a, b): return a["pos"].distance_squared_to(origin) < b["pos"].distance_squared_to(origin))
	return valid.slice(0, mini(max_count, valid.size()))

func damage_zombie(z: Dictionary, raw_dmg: float, dir: Vector3, is_crit: bool, ignite: bool) -> bool:
	if not z["alive"]:
		return false
	var armor: float = float(z["cfg"]["armor"])
	var dmg := raw_dmg * armor
	z["hp"] -= dmg
	z["flash_t"] = 0.07
	z["stagger_t"] = 1.0
	_set_override_mat(z, _hit_flash_mat)
	if ignite:
		z["burn_t"] = 3.2
	var kb_res: float = float(z["cfg"]["knockback_resist"])
	z["kb"] += Vector3(dir.x, 0.0, dir.z).normalized() * (6.2 * (1.0 - kb_res))

	AudioManager.play_hit_confirm(is_crit, armor < 0.9)
	GameManager.hit_marker.emit(is_crit)
	damage_popup.emit(z["pos"] + Vector3(0, 1.65, 0), int(roundf(dmg)), is_crit)
	if vfx_juice:
		vfx_juice.spawn_hit_spray(z["pos"], dir, is_crit, armor < 0.9, z["kind"] in ["bloater", "spitter"])
	if decal_manager and randf() < 0.60:
		decal_manager.spawn_blood(z["pos"] + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), randf_range(1.1, 1.9))

	if z["uid"] == _active_boss_uid:
		GameManager.boss_hp_changed.emit(maxf(0.0, z["hp"]), z["max_hp"])

	if z["hp"] <= 0.0:
		if is_crit:
			GameManager.trigger_hitstop(0.026)
		_kill_zombie(z, dir)
		return true
	return false

func damage_in_radius(center: Vector3, radius: float, damage: float, push: bool = true) -> void:
	var cands := _grid.query_radius(center, radius + 1.0)
	for z in cands:
		if not z["alive"]:
			continue
		var d: float = (z["pos"] as Vector3).distance_to(center)
		if d <= radius:
			var falloff := clampf(1.0 - (d / radius) * 0.45, 0.35, 1.0)
			var dir: Vector3 = ((z["pos"] as Vector3) - center).normalized() if d > 0.05 else Vector3.FORWARD
			if push:
				z["kb"] += dir * 11.0 * (1.0 - float(z["cfg"]["knockback_resist"]))
			damage_zombie(z, damage * falloff, dir, false, true)

func _kill_zombie(z: Dictionary, _dir: Vector3) -> void:
	z["alive"] = false
	var idx := _zombies.find(z)
	if idx >= 0:
		_zombies.remove_at(idx)
	_set_override_mat(z, null)
	if decal_manager:
		decal_manager.spawn_blood(z["pos"], randf_range(1.9, 3.0))

	if z["kind"] == "bloater":
		AudioManager.play_sfx("bloater_pop", 0.92, 1.1, 0.9)
		if decal_manager:
			decal_manager.spawn_acid_pool(z["pos"], 2.8, 7.0)
		if explosion_system:
			explosion_system.spawn_explosion(z["pos"], 3.4, 55.0, false, Color(0.35, 1.0, 0.15))
	else:
		AudioManager.play_sfx("zombie_death", 0.88, 1.15, 0.55)

	if z["uid"] == _active_boss_uid:
		_active_boss_uid = -1
		GameManager.boss_defeated.emit()

	if _medkit_scene and not GameManager.has_perk("duality_vampire"):
		var drop_chance := 0.16 if GameManager.hp < GameManager.max_hp * 0.70 else 0.07
		if z["kind"] in ["bruiser", "spitter", "charger", "boss"]:
			drop_chance = 0.65
		if randf() < drop_chance and _medkits.size() < 10:
			var mk: Node3D = _medkit_scene.instantiate()
			mk.position = Vector3(z["pos"].x, 0.25, z["pos"].z)
			add_child(mk)
			_medkits.append(mk)
			pickup_spawned.emit(mk, "health")

	var xp_v := float(z["cfg"]["xp"])
	GameManager.register_kill(z["kind"], xp_v, int(z["cfg"]["score"]))
	if vfx_juice:
		vfx_juice.spawn_kill_burst(z["pos"], z["kind"], z["flash_t"] > 0.0, z["burn_t"] > 0.0)
		var orb_cnt := 5 if z["kind"] == "boss" else (3 if z["kind"] in ["bruiser", "bloater", "spitter"] else 2)
		vfx_juice.spawn_xp_orbs(z["pos"], orb_cnt, xp_v)
	else:
		GameManager.add_xp(xp_v)

	_corpses.append({"node": z["node"], "t": 2.8, "fall": 0.0, "dir_sign": -1.0 if randf() < 0.7 else 1.0})

func _set_override_mat(z: Dictionary, mat: Material) -> void:
	for mi in z["meshes"]:
		if is_instance_valid(mi):
			mi.material_override = mat if mat != null else mi.get_meta("base_mat", null)

func get_active_medkits() -> Array[Node3D]:
	return _medkits

func spawn_sentry_turret(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.0, pos.z)
	add_child(root)

	var base_m := StandardMaterial3D.new(); base_m.albedo_color = Color(0.24, 0.26, 0.30); base_m.metallic = 0.65; base_m.roughness = 0.42
	var acc_m := StandardMaterial3D.new(); acc_m.albedo_color = Color(1.0, 0.48, 0.08); acc_m.emission_enabled = true; acc_m.emission = Color(1.0, 0.45, 0.08); acc_m.emission_energy_multiplier = 2.8

	var tripod := MeshInstance3D.new()
	var tm := CylinderMesh.new(); tm.top_radius = 0.18; tm.bottom_radius = 0.52; tm.height = 0.85
	tripod.mesh = tm; tripod.material_override = base_m; tripod.position = Vector3(0, 0.42, 0)
	root.add_child(tripod)

	var head := Node3D.new(); head.position = Vector3(0, 0.96, 0); root.add_child(head)
	var body := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.46, 0.34, 0.68)
	body.mesh = bm; body.material_override = base_m; head.add_child(body)
	var barrel := MeshInstance3D.new(); var brm := CylinderMesh.new(); brm.top_radius = 0.05; brm.bottom_radius = 0.06; brm.height = 0.85
	barrel.mesh = brm; barrel.material_override = base_m; barrel.position = Vector3(0, 0.02, 0.65); barrel.rotation_degrees.x = 90.0
	head.add_child(barrel)
	var beacon := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.11; sp.height = 0.22
	beacon.mesh = sp; beacon.material_override = acc_m; beacon.position = Vector3(0, 0.24, 0)
	head.add_child(beacon)
	var lgt := OmniLight3D.new(); lgt.position = Vector3(0, 1.3, 0); lgt.light_color = Color(1.0, 0.52, 0.12); lgt.light_energy = 3.0; lgt.omni_range = 8.0
	lgt.shadow_enabled = false; lgt.distance_fade_enabled = true; lgt.distance_fade_begin = 24.0; lgt.distance_fade_length = 10.0
	root.add_child(lgt)

	_turrets.append({"node": root, "head": head, "pos": Vector3(pos.x, 0.0, pos.z), "life": 35.0, "fire_cd": 0.15})
	AudioManager.play_sfx("card_confirm", 0.78, 0.92, 0.95)
	if vfx_juice: vfx_juice.spawn_shockwave_ring(Vector3(pos.x, 0.12, pos.z), 3.2, Color(1.0, 0.55, 0.12))

func _update_sentry_turrets(delta: float) -> void:
	for i in range(_turrets.size() - 1, -1, -1):
		var tr: Dictionary = _turrets[i]
		tr["life"] = float(tr["life"]) - delta
		if float(tr["life"]) <= 0.0:
			if is_instance_valid(tr["node"]): (tr["node"] as Node3D).queue_free()
			_turrets.remove_at(i)
			continue
		tr["fire_cd"] = float(tr["fire_cd"]) - delta
		var tpos: Vector3 = tr["pos"]
		var targets := get_nearest_zombies(tpos, 17.5, 1)
		if not targets.is_empty():
			var z: Dictionary = targets[0]
			var dir: Vector3 = ((z["pos"] as Vector3) - tpos)
			dir.y = 0.0
			var dist := dir.length()
			if dist > 0.1:
				dir /= dist
				var hd: Node3D = tr["head"]
				hd.rotation.y = lerp_angle(hd.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 18.0))
				if float(tr["fire_cd"]) <= 0.0:
					tr["fire_cd"] = 0.145
					damage_zombie(z, 26.0 * GameManager.get_damage_mult(), dir, randf() < 0.18, false)
					AudioManager.play_sfx("smg_shot", 1.12, 1.28, 0.36)
					# Crisp glowing turret laser tracer beam!
					var beam := MeshInstance3D.new()
					var bm := BoxMesh.new(); bm.size = Vector3(0.05, 0.05, dist)
					beam.mesh = bm
					var bmat := StandardMaterial3D.new(); bmat.albedo_color = Color(1.0, 0.72, 0.20)
					bmat.emission_enabled = true; bmat.emission = Color(1.0, 0.65, 0.15); bmat.emission_energy_multiplier = 6.0
					bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					beam.material_override = bmat
					var mid := (tpos + (z["pos"] as Vector3)) * 0.5 + Vector3(0, 1.0, 0)
					beam.position = mid; beam.rotation.y = atan2(dir.x, dir.z)
					add_child(beam)
					_turret_tracers.append({"node": beam, "t": 0.06})

	for i in range(_turret_tracers.size() - 1, -1, -1):
		_turret_tracers[i]["t"] = float(_turret_tracers[i]["t"]) - delta
		if float(_turret_tracers[i]["t"]) <= 0.0:
			if is_instance_valid(_turret_tracers[i]["node"]): (_turret_tracers[i]["node"] as Node3D).queue_free()
			_turret_tracers.remove_at(i)
