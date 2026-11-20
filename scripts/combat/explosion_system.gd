class_name ExplosionSystem
extends Node3D

var horde_manager: Node = null
var decal_manager: BloodDecalManager = null
var player_ref: Node = null
var vfx_juice: VFXJuice = null

var _door_scene: PackedScene
var _wheel_scene: PackedScene
var _flashes: Array[Dictionary] = []
var _debris_list: Array[Dictionary] = []

func _ready() -> void:
	if ResourceLoader.exists("res://assets/models/debris_door.glb"):
		_door_scene = load("res://assets/models/debris_door.glb")
	if ResourceLoader.exists("res://assets/models/debris_wheel.glb"):
		_wheel_scene = load("res://assets/models/debris_wheel.glb")

func _process(delta: float) -> void:
	for i in range(_flashes.size() - 1, -1, -1):
		var f: Dictionary = _flashes[i]
		f["t"] += delta
		var p: float = f["t"] / f["dur"]
		if p >= 1.0:
			if is_instance_valid(f["node"]):
				f["node"].queue_free()
			_flashes.remove_at(i)
		else:
			var sc: float = lerpf(0.5, f["max_r"], ease(p, 0.35))
			var mesh: MeshInstance3D = f["mesh"]
			mesh.scale = Vector3.ONE * sc
			var mat: StandardMaterial3D = mesh.material_override
			mat.albedo_color.a = (1.0 - p) * 0.88
			mat.emission_energy_multiplier = (1.0 - p) * 10.0
			var lgt: OmniLight3D = f["light"]
			lgt.light_energy = (1.0 - p) * f["energy"]
	for i in range(_debris_list.size() - 1, -1, -1):
		_debris_list[i]["t"] -= delta
		if _debris_list[i]["t"] <= 0.0:
			if is_instance_valid(_debris_list[i]["body"]):
				_debris_list[i]["body"].queue_free()
			_debris_list.remove_at(i)

func spawn_explosion(pos: Vector3, radius: float, damage: float, spawn_debris: bool = true, color: Color = Color(1.0, 0.45, 0.08)) -> void:
	AudioManager.play_sfx("explosion", 0.88, 1.08, 1.0 if spawn_debris else 0.65)
	if decal_manager and spawn_debris:
		decal_manager.spawn_scorch(pos, radius * 1.15)
	if player_ref and player_ref.has_method("add_camera_trauma"):
		player_ref.add_camera_trauma(0.82 if spawn_debris else 0.25)
	if vfx_juice:
		vfx_juice.spawn_shockwave_ring(pos, radius * 1.15, color)
	GameManager.postfx_kick.emit(0.018 if spawn_debris else 0.006)
	if spawn_debris:
		GameManager.trigger_hitstop(0.042)

	# Expanding HDR fireball + shockwave OmniLight
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.7, pos.z)
	add_child(root)

	var mesh := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.8
	sph.height = 1.6
	mesh.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 10.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	root.add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 16.0 if spawn_debris else 6.0
	light.omni_range = radius * 2.4
	light.shadow_enabled = false
	root.add_child(light)

	_flashes.append({"node": root, "mesh": mesh, "light": light, "t": 0.0, "dur": 0.48 if spawn_debris else 0.25, "max_r": radius * 0.75, "energy": light.light_energy})

	# Spark / Ember burst
	var pts := CPUParticles3D.new()
	pts.position = Vector3(pos.x, 0.8, pos.z)
	pts.one_shot = true
	pts.explosiveness = 0.92
	pts.amount = 38 if spawn_debris else 14
	pts.lifetime = 0.75 if spawn_debris else 0.38
	pts.direction = Vector3(0, 1, 0)
	pts.spread = 80.0
	pts.initial_velocity_min = 6.0
	pts.initial_velocity_max = 16.0 if spawn_debris else 9.0
	pts.gravity = Vector3(0, -18.0, 0)
	var pm := BoxMesh.new()
	pm.size = Vector3(0.14, 0.14, 0.14)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = color
	pmat.emission_enabled = true
	pmat.emission = color
	pmat.emission_energy_multiplier = 7.0
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.material = pmat
	pts.mesh = pm
	add_child(pts)
	pts.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(pts): pts.queue_free())

	# Native Godot 4.6 Jolt Physics Debris!
	if spawn_debris:
		for i in range(5):
			var rb := RigidBody3D.new()
			rb.mass = 8.0
			rb.collision_layer = 0
			rb.collision_mask = 1
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(0.55, 0.45, 0.55)
			cs.shape = bx
			rb.add_child(cs)
			var src := _door_scene if (i % 2 == 0) else _wheel_scene
			if src:
				var inst := src.instantiate()
				rb.add_child(inst)
			rb.position = Vector3(pos.x + randf_range(-1.0, 1.0), 1.2, pos.z + randf_range(-1.0, 1.0))
			add_child(rb)
			var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.9, 1.7), randf_range(-1.0, 1.0)).normalized()
			rb.apply_central_impulse(dir * randf_range(65.0, 115.0))
			rb.apply_torque_impulse(Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20)))
			_debris_list.append({"body": rb, "t": 5.5})

	# AoE Damage to Zombies + Player slight knockback if standing right on top
	if horde_manager and horde_manager.has_method("damage_in_radius"):
		horde_manager.damage_in_radius(pos, radius, damage, true)
	if spawn_debris and player_ref and is_instance_valid(player_ref):
		var d := pos.distance_to(player_ref.global_position)
		if d < radius * 0.65:
			GameManager.damage_player(22.0 * (1.0 - d / (radius * 0.65)))
