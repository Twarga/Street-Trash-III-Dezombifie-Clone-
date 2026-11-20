class_name ExplodableCar
extends StaticBody3D

@export var max_hp: float = 95.0
@export var start_burning: bool = false

var hp: float = 95.0
var exploded: bool = false
var explosion_system: ExplosionSystem = null
var blast_radius: float = 7.4
var blast_damage: float = 260.0
var spawn_wreck: bool = true

var _intact_node: Node3D = null
var _fire_light: OmniLight3D = null
var _fire_particles: CPUParticles3D = null
var _burn_fuse: float = -1.0
var _is_emergency: bool = false
var _lightbar_l: MeshInstance3D = null
var _lightbar_r: MeshInstance3D = null
var _police_omni: OmniLight3D = null
var _headlight_spot: SpotLight3D = null

func setup(model_path: String, exp_sys: ExplosionSystem, burning: bool = false, model_scale: float = 1.0, col_size: Vector3 = Vector3(2.05, 1.6, 4.6), custom_hp: float = 95.0, b_rad: float = 7.4, use_wreck: bool = true, tint: Color = Color.WHITE, emergency_lights: bool = false, headlights_on: bool = false) -> void:
	explosion_system = exp_sys
	start_burning = burning
	max_hp = custom_hp
	hp = minf(45.0, custom_hp) if burning else max_hp
	blast_radius = b_rad
	spawn_wreck = use_wreck
	collision_layer = 4
	collision_mask = 1 | 2

	if ResourceLoader.exists(model_path):
		_intact_node = (load(model_path) as PackedScene).instantiate()
		_intact_node.scale = Vector3.ONE * model_scale
		var car_tint: Color = tint
		if car_tint == Color.WHITE and "kenney/" in model_path:
			if "taxi" in model_path: car_tint = Color(0.72, 0.52, 0.08)
			elif "police" in model_path: car_tint = Color(0.14, 0.20, 0.34)
			elif "firetruck" in model_path: car_tint = Color(0.62, 0.10, 0.08)
			elif "ambulance" in model_path: car_tint = Color(0.45, 0.46, 0.48)
			elif "sedan" in model_path: car_tint = Color(0.46, 0.12, 0.10)
			elif "suv" in model_path: car_tint = Color(0.16, 0.28, 0.24)
			elif "delivery" in model_path or "van" in model_path: car_tint = Color(0.32, 0.30, 0.26)
			else: car_tint = Color(0.30, 0.30, 0.34)
		if car_tint != Color.WHITE:
			var tm := StandardMaterial3D.new()
			tm.albedo_color = car_tint
			tm.metallic = 0.45
			tm.roughness = 0.42
			tm.uv1_triplanar = true
			tm.uv1_world_triplanar = true
			tm.uv1_scale = Vector3.ONE * 0.6
			if ResourceLoader.exists("res://assets/textures/pbr/rust_metal_albedo.jpg"):
				tm.albedo_texture = load("res://assets/textures/pbr/rust_metal_albedo.jpg")
			if ResourceLoader.exists("res://assets/textures/pbr/rust_metal_normal.jpg"):
				tm.normal_enabled = true
				tm.normal_texture = load("res://assets/textures/pbr/rust_metal_normal.jpg")
				tm.normal_scale = 0.9
			_apply_tint(_intact_node, tm)
		add_child(_intact_node)

	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = col_size
	cs.shape = bx
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)

	_is_emergency = emergency_lights
	if emergency_lights and _intact_node:
		_attach_emergency_lightbar()
	if headlights_on and _intact_node:
		_attach_headlights()
	if burning:
		_ignite_car()

func _process(delta: float) -> void:
	if exploded:
		return
	if _fire_light:
		_fire_light.light_energy = 4.6 + sin(Time.get_ticks_msec() * 0.018) * 1.1
	if _is_emergency and _police_omni:
		var ph := int(Time.get_ticks_msec() * 0.007 + global_position.x) % 2
		_police_omni.light_color = Color(1.0, 0.08, 0.12) if ph == 0 else Color(0.12, 0.42, 1.0)
		if _lightbar_l and _lightbar_r:
			(_lightbar_l.material_override as StandardMaterial3D).emission_energy_multiplier = 7.0 if ph == 0 else 0.5
			(_lightbar_r.material_override as StandardMaterial3D).emission_energy_multiplier = 7.0 if ph == 1 else 0.5
	if _burn_fuse > 0.0:
		_burn_fuse -= delta
		if _burn_fuse <= 0.0:
			_detonate()

func take_bullet_damage(amount: float) -> void:
	if exploded:
		return
	hp -= amount
	AudioManager.play_sfx("hit_armor", 0.75, 0.95, 0.45)
	if hp <= max_hp * 0.55 and _fire_light == null:
		_ignite_car()
	if hp <= 0.0:
		_detonate()

func _ignite_car() -> void:
	if _fire_light != null:
		return
	_fire_light = OmniLight3D.new()
	_fire_light.position = Vector3(0, 1.5, -1.3)
	_fire_light.light_color = Color(1.0, 0.42, 0.08)
	_fire_light.light_energy = 4.5
	_fire_light.omni_range = 10.5
	_fire_light.shadow_enabled = false
	_fire_light.distance_fade_enabled = true; _fire_light.distance_fade_begin = 26.0; _fire_light.distance_fade_length = 10.0
	add_child(_fire_light)

	var fire_fx := UIStyle.create_fire_3d_effect(1.55)
	fire_fx.position = Vector3(0, 1.05, -1.25)
	add_child(fire_fx)
	if not start_burning:
		_burn_fuse = 2.2

func _detonate() -> void:
	if exploded:
		return
	exploded = true
	if _intact_node:
		_intact_node.queue_free()
	if _police_omni:
		_police_omni.queue_free(); _police_omni = null
	if _headlight_spot:
		_headlight_spot.queue_free(); _headlight_spot = null
	if spawn_wreck and ResourceLoader.exists("res://assets/models/car_wreck.glb"):
		var wreck := (load("res://assets/models/car_wreck.glb") as PackedScene).instantiate()
		add_child(wreck)
	if _fire_light:
		_fire_light.light_energy = 2.2
		_fire_light.omni_range = 7.0
	if explosion_system:
		explosion_system.spawn_explosion(global_position, blast_radius, blast_damage, spawn_wreck)

func _apply_tint(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		n.material_override = mat
	for c in n.get_children():
		_apply_tint(c, mat)

func _attach_emergency_lightbar() -> void:
	var bar := Node3D.new()
	bar.position = Vector3(0.0, 1.72, 0.0)
	_intact_node.add_child(bar)
	var pod := BoxMesh.new(); pod.size = Vector3(0.42, 0.14, 0.22)
	_lightbar_l = MeshInstance3D.new(); _lightbar_l.mesh = pod; _lightbar_l.position = Vector3(-0.24, 0, 0)
	var ml := StandardMaterial3D.new(); ml.albedo_color = Color(1, 0.1, 0.1); ml.emission_enabled = true; ml.emission = Color(1, 0.1, 0.12); ml.emission_energy_multiplier = 6.0
	_lightbar_l.material_override = ml; bar.add_child(_lightbar_l)
	_lightbar_r = MeshInstance3D.new(); _lightbar_r.mesh = pod; _lightbar_r.position = Vector3(0.24, 0, 0)
	var mr := StandardMaterial3D.new(); mr.albedo_color = Color(0.1, 0.35, 1); mr.emission_enabled = true; mr.emission = Color(0.12, 0.45, 1.0); mr.emission_energy_multiplier = 6.0
	_lightbar_r.material_override = mr; bar.add_child(_lightbar_r)

	_police_omni = OmniLight3D.new()
	_police_omni.position = Vector3(0.0, 2.25, 0.0)
	_police_omni.light_energy = 5.5; _police_omni.omni_range = 16.0
	_police_omni.shadow_enabled = false
	_police_omni.distance_fade_enabled = true; _police_omni.distance_fade_begin = 28.0; _police_omni.distance_fade_length = 12.0
	add_child(_police_omni)

func _attach_headlights() -> void:
	var lm := BoxMesh.new(); lm.size = Vector3(0.26, 0.14, 0.08)
	var hmat := StandardMaterial3D.new(); hmat.albedo_color = Color(1.0, 0.96, 0.85); hmat.emission_enabled = true; hmat.emission = Color(1.0, 0.94, 0.78); hmat.emission_energy_multiplier = 5.0
	var tmat := StandardMaterial3D.new(); tmat.albedo_color = Color(1.0, 0.12, 0.10); tmat.emission_enabled = true; tmat.emission = Color(1.0, 0.10, 0.08); tmat.emission_energy_multiplier = 3.5
	for sx in [-0.52, 0.52]:
		var hl := MeshInstance3D.new(); hl.mesh = lm; hl.material_override = hmat; hl.position = Vector3(sx, 0.62, 1.48)
		_intact_node.add_child(hl)
		var tl := MeshInstance3D.new(); tl.mesh = lm; tl.material_override = tmat; tl.position = Vector3(sx, 0.62, -1.48)
		_intact_node.add_child(tl)
	_headlight_spot = SpotLight3D.new()
	_headlight_spot.position = Vector3(0.0, 0.85, 2.3)
	_headlight_spot.rotation_degrees = Vector3(-12.0, 180.0, 0.0)
	_headlight_spot.light_color = Color(1.0, 0.92, 0.74); _headlight_spot.light_energy = 6.5; _headlight_spot.spot_range = 16.0; _headlight_spot.spot_angle = 44.0
	_headlight_spot.shadow_enabled = false
	_headlight_spot.distance_fade_enabled = true; _headlight_spot.distance_fade_begin = 26.0; _headlight_spot.distance_fade_length = 10.0
	add_child(_headlight_spot)
