class_name BloodDecalManager
extends Node3D

const MAX_DECALS := 160
var _use_quads: bool = false
var _pool: Array[Node3D] = []
var _idx: int = 0
var _blood_tex: Array[Texture2D] = []
var _acid_tex: Texture2D
var _scorch_tex: Texture2D
var _acid_zones: Array[Dictionary] = []
var _quad_mesh: PlaneMesh

func _ready() -> void:
	_use_quads = OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("mobile")
	for i in range(1, 5):
		var p := "res://assets/textures/blood_%d.png" % i
		if ResourceLoader.exists(p):
			_blood_tex.append(load(p))
	if ResourceLoader.exists("res://assets/textures/acid_decal.png"):
		_acid_tex = load("res://assets/textures/acid_decal.png")
	if ResourceLoader.exists("res://assets/textures/scorch_decal.png"):
		_scorch_tex = load("res://assets/textures/scorch_decal.png")

	if _use_quads:
		_quad_mesh = PlaneMesh.new()
		_quad_mesh.size = Vector2(1.0, 1.0)
		for i in range(MAX_DECALS):
			var mi := MeshInstance3D.new()
			mi.mesh = _quad_mesh
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.25
			mi.material_override = mat
			mi.visible = false
			add_child(mi)
			_pool.append(mi)
	else:
		for i in range(MAX_DECALS):
			var d := Decal.new()
			d.visible = false
			d.cull_mask = 1
			add_child(d)
			_pool.append(d)

func _process(delta: float) -> void:
	for i in range(_acid_zones.size() - 1, -1, -1):
		_acid_zones[i]["time"] -= delta
		if _acid_zones[i]["time"] <= 0.0:
			_acid_zones.remove_at(i)

func _place(tex: Texture2D, col: Color, pos: Vector3, scale_val: float, em_energy: float) -> void:
	if tex == null:
		return
	var node := _pool[_idx]
	var y_off := 0.024 + float(_idx % 16) * 0.0008
	_idx = (_idx + 1) % MAX_DECALS
	if _use_quads:
		var mi := node as MeshInstance3D
		var mat := mi.material_override as StandardMaterial3D
		mat.albedo_texture = tex
		mat.albedo_color = col
		mat.emission_enabled = em_energy > 0.0
		mat.emission_texture = tex if em_energy > 0.0 else null
		mat.emission = col
		mat.emission_energy_multiplier = em_energy
		mi.scale = Vector3(scale_val, 1.0, scale_val)
		mi.global_position = Vector3(pos.x, y_off, pos.z)
		mi.rotation.y = randf() * TAU
		mi.visible = true
	else:
		var d := node as Decal
		d.texture_albedo = tex
		d.texture_emission = tex if em_energy > 0.0 else null
		d.emission_energy = em_energy
		d.modulate = col
		d.size = Vector3(scale_val, 1.4, scale_val)
		d.global_position = Vector3(pos.x, 0.05, pos.z)
		d.rotation.y = randf() * TAU
		d.visible = true

func spawn_blood(pos: Vector3, scale_val: float = 1.6) -> void:
	if _blood_tex.is_empty():
		return
	_place(_blood_tex[randi() % _blood_tex.size()], Color(0.85, 0.12, 0.14, 0.92), pos, scale_val, 0.0)

func spawn_scorch(pos: Vector3, scale_val: float = 5.5) -> void:
	_place(_scorch_tex, Color(0.12, 0.10, 0.10, 0.95), pos, scale_val, 0.0)

func spawn_acid_pool(pos: Vector3, radius: float = 2.6, duration: float = 6.5) -> void:
	_place(_acid_tex, Color(0.45, 1.0, 0.25, 0.90), pos, radius * 2.1, 2.8)
	_acid_zones.append({"pos": Vector3(pos.x, 0.0, pos.z), "radius": radius, "time": duration})

func is_in_acid(pos: Vector3) -> bool:
	for z in _acid_zones:
		var zp: Vector3 = z["pos"]
		var dx := pos.x - zp.x
		var dz := pos.z - zp.z
		var r: float = z["radius"]
		if dx * dx + dz * dz <= r * r:
			return true
	return false
