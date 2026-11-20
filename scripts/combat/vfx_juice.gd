class_name VFXJuice
extends Node3D

var player_ref: Node3D = null

var _particles: Array[Dictionary] = [] # Gore droplets, sparks, brass shell casings
var _rings: Array[Dictionary] = []     # Expanding 3D shockwave rings
var _orbs: Array[Dictionary] = []      # Magnetized glowing XP orbs!
var _flashes: Array[Dictionary] = []   # 3D Star muzzle flashes

var _drop_mesh: BoxMesh
var _shell_mesh: BoxMesh
var _orb_mesh: SphereMesh
var _ring_mesh: TorusMesh
var _flash_mesh: QuadMesh

var _mat_blood: StandardMaterial3D
var _mat_acid: StandardMaterial3D
var _mat_spark: StandardMaterial3D
var _mat_fire: StandardMaterial3D
var _mat_shell: StandardMaterial3D
var _mat_orb_cyan: StandardMaterial3D
var _mat_orb_gold: StandardMaterial3D

func _ready() -> void:
	_drop_mesh = BoxMesh.new(); _drop_mesh.size = Vector3(0.11, 0.11, 0.11)
	_shell_mesh = BoxMesh.new(); _shell_mesh.size = Vector3(0.04, 0.04, 0.11)
	_orb_mesh = SphereMesh.new(); _orb_mesh.radius = 0.14; _orb_mesh.height = 0.28
	_ring_mesh = TorusMesh.new(); _ring_mesh.inner_radius = 0.84; _ring_mesh.outer_radius = 1.0
	_flash_mesh = QuadMesh.new(); _flash_mesh.size = Vector2(0.85, 0.85)

	_mat_blood = _mk_mat(Color(0.85, 0.04, 0.07), Color(0.95, 0.08, 0.10), 2.4)
	_mat_acid = _mk_mat(Color(0.32, 1.0, 0.16), Color(0.35, 1.0, 0.18), 5.0)
	_mat_spark = _mk_mat(Color(1.0, 0.9, 0.42), Color(1.0, 0.82, 0.28), 7.5)
	_mat_fire = _mk_mat(Color(1.0, 0.42, 0.05), Color(1.0, 0.38, 0.04), 6.5)
	_mat_shell = _mk_mat(Color(0.98, 0.80, 0.28), Color(0.95, 0.72, 0.20), 2.2)
	_mat_orb_cyan = _mk_mat(Color(0.22, 0.96, 1.0), Color(0.20, 0.94, 1.0), 6.5)
	_mat_orb_gold = _mk_mat(Color(1.0, 0.84, 0.18), Color(1.0, 0.78, 0.15), 7.5)

func _mk_mat(col: Color, em: Color, en: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = em
	m.emission_energy_multiplier = en
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func spawn_muzzle_flash(pos: Vector3, dir: Vector3, col: Color) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var mat := _mk_mat(col, col, 9.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for ang in [0.0, 60.0, 120.0]:
		var m := MeshInstance3D.new()
		m.mesh = _flash_mesh
		m.material_override = mat
		m.rotation_degrees = Vector3(90.0 if ang == 0.0 else 0.0, ang, randf_range(0.0, 180.0))
		root.add_child(m)
	_flashes.append({"node": root, "t": 0.05})

func spawn_shell_casing(pos: Vector3, right_dir: Vector3) -> void:
	if _particles.size() > 180:
		return
	var m := MeshInstance3D.new()
	m.mesh = _shell_mesh
	m.material_override = _mat_shell
	m.position = pos
	add_child(m)
	var v := right_dir * randf_range(2.2, 4.0) + Vector3(randf_range(-0.6, 0.6), randf_range(2.4, 3.8), randf_range(-0.6, 0.6))
	_particles.append({"node": m, "vel": v, "t": 0.0, "dur": 0.95, "bounce": true, "spin": Vector3(14, 22, 18)})

func spawn_hit_spray(pos: Vector3, dir: Vector3, is_crit: bool, is_armor: bool, is_acid: bool = false) -> void:
	var count := 9 if is_crit else 5
	var mat := _mat_spark if is_armor else (_mat_acid if is_acid else _mat_blood)
	for _i in range(count):
		if _particles.size() > 210:
			break
		var m := MeshInstance3D.new()
		m.mesh = _drop_mesh
		m.material_override = mat
		m.scale = Vector3.ONE * randf_range(0.65, 1.45 if is_crit else 1.05)
		m.position = pos + Vector3(0, 1.05, 0)
		add_child(m)
		var spread_dir := (dir + Vector3(randf_range(-0.55, 0.55), randf_range(0.25, 0.95), randf_range(-0.55, 0.55))).normalized()
		_particles.append({"node": m, "vel": spread_dir * randf_range(4.5, 11.5 if is_crit else 8.0), "t": 0.0, "dur": randf_range(0.32, 0.58), "bounce": false, "spin": Vector3(9, 12, 7)})

func spawn_kill_burst(pos: Vector3, kind: String, is_crit: bool, is_fire: bool) -> void:
	var mat := _mat_acid if kind == "bloater" else (_mat_fire if is_fire else _mat_blood)
	var count := 18 if (is_crit or kind in ["bruiser", "bloater", "boss"]) else 11
	for _i in range(count):
		if _particles.size() > 240:
			break
		var m := MeshInstance3D.new()
		m.mesh = _drop_mesh
		m.material_override = mat
		m.scale = Vector3.ONE * randf_range(0.9, 2.0)
		m.position = pos + Vector3(0, 1.0, 0)
		add_child(m)
		var v := Vector3(randf_range(-1.0, 1.0), randf_range(0.45, 1.35), randf_range(-1.0, 1.0)).normalized() * randf_range(5.0, 12.5)
		_particles.append({"node": m, "vel": v, "t": 0.0, "dur": randf_range(0.42, 0.78), "bounce": true, "spin": Vector3(10, 15, 11)})
	if is_crit or kind in ["bruiser", "bloater", "boss"]:
		var rc := Color(0.35, 1.0, 0.18) if kind == "bloater" else (Color(1.0, 0.85, 0.22) if is_crit else Color(1.0, 0.22, 0.15))
		spawn_shockwave_ring(pos, 2.8 if kind != "boss" else 6.5, rc)

func spawn_shockwave_ring(pos: Vector3, max_radius: float, col: Color) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _ring_mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(col.r, col.g, col.b, 0.92)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 7.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = Vector3(pos.x, 0.18, pos.z)
	m.scale = Vector3(0.35, 0.35, 0.35)
	add_child(m)
	_rings.append({"node": m, "mat": mat, "t": 0.0, "dur": 0.36, "max_r": max_radius})

func spawn_xp_orbs(pos: Vector3, count: int, total_xp: float) -> void:
	var xp_each := total_xp / float(maxi(1, count))
	for i in range(count):
		if _orbs.size() > 75:
			# Overflow XP directly so nothing is lost!
			GameManager.add_xp(xp_each)
			continue
		var m := MeshInstance3D.new()
		m.mesh = _orb_mesh
		var is_gold := count >= 4 and i == 0
		m.material_override = _mat_orb_gold if is_gold else _mat_orb_cyan
		m.scale = Vector3.ONE * (1.35 if is_gold else 0.9)
		m.position = pos + Vector3(0, 0.85, 0)
		add_child(m)
		var v := Vector3(randf_range(-1.0, 1.0), randf_range(0.9, 1.6), randf_range(-1.0, 1.0)).normalized() * randf_range(3.2, 5.8)
		_orbs.append({"node": m, "vel": v, "xp": xp_each, "age": 0.0})

func _process(delta: float) -> void:
	# 1. Muzzle flashes
	for i in range(_flashes.size() - 1, -1, -1):
		_flashes[i]["t"] -= delta
		if _flashes[i]["t"] <= 0.0:
			if is_instance_valid(_flashes[i]["node"]): _flashes[i]["node"].queue_free()
			_flashes.remove_at(i)

	# 2. Gore / Sparks / Brass Shells
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["t"] += delta
		var nd: MeshInstance3D = p["node"]
		if p["t"] >= p["dur"] or not is_instance_valid(nd):
			if is_instance_valid(nd): nd.queue_free()
			_particles.remove_at(i)
			continue
		var v: Vector3 = p["vel"]
		v.y -= 22.0 * delta
		nd.position += v * delta
		nd.rotation += (p["spin"] as Vector3) * delta
		if nd.position.y < 0.06:
			nd.position.y = 0.06
			if p["bounce"]:
				v.y = absf(v.y) * 0.42
				v.x *= 0.65
				v.z *= 0.65
			else:
				v = Vector3.ZERO
		p["vel"] = v
		var fade: float = 1.0 - (float(p["t"]) / float(p["dur"]))
		nd.scale = nd.scale.lerp(Vector3.ZERO, delta * 3.0 * (1.0 - fade))

	# 3. Expanding 3D Shockwave Rings
	for i in range(_rings.size() - 1, -1, -1):
		var r: Dictionary = _rings[i]
		r["t"] += delta
		var p: float = r["t"] / r["dur"]
		var nd: MeshInstance3D = r["node"]
		if p >= 1.0 or not is_instance_valid(nd):
			if is_instance_valid(nd): nd.queue_free()
			_rings.remove_at(i)
			continue
		var rad := lerpf(0.35, r["max_r"], ease(p, 0.35))
		nd.scale = Vector3(rad, 0.25, rad)
		var mat: StandardMaterial3D = r["mat"]
		mat.albedo_color.a = (1.0 - p) * 0.92
		mat.emission_energy_multiplier = (1.0 - p) * 7.5

	# 4. Magnetized Glowing XP Orbs -> WHOOSH into Player!
	if player_ref == null or not is_instance_valid(player_ref):
		return
	var ppos := player_ref.global_position + Vector3(0, 0.95, 0)
	var pull_r := GameManager.get_pickup_radius() * 3.8
	for i in range(_orbs.size() - 1, -1, -1):
		var o: Dictionary = _orbs[i]
		o["age"] += delta
		var nd: MeshInstance3D = o["node"]
		if not is_instance_valid(nd):
			_orbs.remove_at(i)
			continue
		if o["age"] < 0.28:
			var v: Vector3 = o["vel"]
			v.y -= 18.0 * delta
			nd.position += v * delta
			if nd.position.y < 0.22:
				nd.position.y = 0.22
				v.y = absf(v.y) * 0.45
			o["vel"] = v
		else:
			var d := nd.position.distance_to(ppos)
			if d < pull_r or o["age"] > 0.75:
				var spd: float = 14.0 + float(o["age"]) * 16.0
				nd.position = nd.position.move_toward(ppos, spd * delta)
			if nd.position.distance_to(ppos) < 0.95:
				GameManager.add_xp(float(o["xp"]))
				nd.queue_free()
				_orbs.remove_at(i)
