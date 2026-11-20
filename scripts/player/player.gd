class_name PlayerController
extends CharacterBody3D

var projectile_system: ProjectileSystem = null
var horde_manager: HordeManager = null
var camera: Camera3D = null
var vfx_juice: VFXJuice = null

var _model_root: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _shin_l: Node3D
var _shin_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _weapon_pivot: Node3D
var _weapon_socket: Node3D
var _weapon_mesh: Node3D

var _flashlight: SpotLight3D
var _beam_cone: MeshInstance3D
var _muzzle_light: OmniLight3D
var _vax_shield: MeshInstance3D
var _foot_dust: CPUParticles3D

var _aim_dir: Vector3 = Vector3(0, 0, -1)
var _use_gamepad_aim: bool = false
var touch_active: bool = false
var touch_move: Vector2 = Vector2.ZERO
var touch_aim: Vector2 = Vector2.ZERO
var touch_firing: bool = false
var touch_sprinting: bool = false

var _fire_cd: float = 0.0
var _muzzle_t: float = 0.0
var _recoil_kick: float = 0.0
var _swap_anim: float = 0.0
var _stride_phase: float = 0.0
var _idle_t: float = 0.0
var _dash_cd: float = 0.0
var _dash_timer: float = 0.0
var _dash_buffer: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
var _acid_tick: float = 0.0

var _cam_trauma: float = 0.0
var _cam_look_ahead: Vector3 = Vector3.ZERO
var _cam_offset := Vector3(0.0, 15.5, 11.8)

func _make_mat(col: Color, rough: float = 0.72, metal: float = 0.05) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m

func _add_part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.layers = 2
	parent.add_child(mi)
	return mi

func _build_kinematic_survivor() -> void:
	var m_skin := _make_mat(Color(0.84, 0.64, 0.50), 0.78, 0.0)
	var m_jacket := _make_mat(Color(0.14, 0.15, 0.18), 0.55, 0.18)
	var m_shirt := _make_mat(Color(0.74, 0.16, 0.14), 0.85, 0.0)
	var m_jeans := _make_mat(Color(0.14, 0.22, 0.36), 0.88, 0.0)
	var m_boots := _make_mat(Color(0.08, 0.07, 0.07), 0.65, 0.15)
	var m_cap := _make_mat(Color(0.76, 0.12, 0.12), 0.80, 0.0)
	var m_pack := _make_mat(Color(0.24, 0.22, 0.16), 0.85, 0.05)
	var m_belt := _make_mat(Color(0.20, 0.14, 0.09), 0.55, 0.25)

	_hips = Node3D.new()
	_hips.position = Vector3(0.0, 0.92, 0.0)
	_model_root.add_child(_hips)

	# Pelvis & Tactical Belt
	var pelv := BoxMesh.new(); pelv.size = Vector3(0.42, 0.18, 0.26)
	_add_part(_hips, pelv, m_jeans, Vector3(0, 0, 0))
	var belt := BoxMesh.new(); belt.size = Vector3(0.45, 0.07, 0.29)
	_add_part(_hips, belt, m_belt, Vector3(0, 0.07, 0))

	# Articulated Left & Right Legs (Hip -> Thigh -> Knee -> Shin -> Boot)
	var thigh_m := CapsuleMesh.new(); thigh_m.radius = 0.105; thigh_m.height = 0.48
	var shin_m := CapsuleMesh.new(); shin_m.radius = 0.088; shin_m.height = 0.44
	var boot_m := BoxMesh.new(); boot_m.size = Vector3(0.16, 0.13, 0.28)

	_leg_l = Node3D.new(); _leg_l.position = Vector3(-0.14, -0.05, 0.0); _hips.add_child(_leg_l)
	_add_part(_leg_l, thigh_m, m_jeans, Vector3(0, -0.22, 0))
	_shin_l = Node3D.new(); _shin_l.position = Vector3(0, -0.44, 0); _leg_l.add_child(_shin_l)
	_add_part(_shin_l, shin_m, m_jeans, Vector3(0, -0.20, 0))
	_add_part(_shin_l, boot_m, m_boots, Vector3(0, -0.40, 0.05))

	_leg_r = Node3D.new(); _leg_r.position = Vector3(0.14, -0.05, 0.0); _hips.add_child(_leg_r)
	_add_part(_leg_r, thigh_m, m_jeans, Vector3(0, -0.22, 0))
	_shin_r = Node3D.new(); _shin_r.position = Vector3(0, -0.44, 0); _leg_r.add_child(_shin_r)
	_add_part(_shin_r, shin_m, m_jeans, Vector3(0, -0.20, 0))
	_add_part(_shin_r, boot_m, m_boots, Vector3(0, -0.40, 0.05))

	# Articulated Upper Torso (Leather Jacket + Red Shirt + Backpack)
	_torso = Node3D.new(); _torso.position = Vector3(0.0, 0.10, 0.0); _hips.add_child(_torso)
	var chest := BoxMesh.new(); chest.size = Vector3(0.48, 0.54, 0.28)
	_add_part(_torso, chest, m_jacket, Vector3(0, 0.28, 0))
	var inner_s := BoxMesh.new(); inner_s.size = Vector3(0.22, 0.50, 0.295)
	_add_part(_torso, inner_s, m_shirt, Vector3(0, 0.28, 0.01))
	var pack := BoxMesh.new(); pack.size = Vector3(0.36, 0.42, 0.18)
	_add_part(_torso, pack, m_pack, Vector3(0, 0.30, -0.20))

	# Head + Backwards Red Street Cap + Beard/Jaw
	_head = Node3D.new(); _head.position = Vector3(0.0, 0.62, 0.02); _torso.add_child(_head)
	var skull := SphereMesh.new(); skull.radius = 0.175; skull.height = 0.36
	_add_part(_head, skull, m_skin, Vector3(0, 0.14, 0))
	var cap_dome := SphereMesh.new(); cap_dome.radius = 0.185; cap_dome.height = 0.22
	_add_part(_head, cap_dome, m_cap, Vector3(0, 0.23, -0.01))
	var cap_brim := BoxMesh.new(); cap_brim.size = Vector3(0.24, 0.04, 0.18)
	_add_part(_head, cap_brim, m_cap, Vector3(0, 0.20, -0.17))

	# Articulated Two-Handed Weapon Pivot & Arms (tracks aim + recoil + swap!)
	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(0.0, 0.42, 0.06)
	_torso.add_child(_weapon_pivot)

	var uarm := CapsuleMesh.new(); uarm.radius = 0.075; uarm.height = 0.42
	var hand_m := SphereMesh.new(); hand_m.radius = 0.068; hand_m.height = 0.13

	_arm_r = Node3D.new(); _arm_r.position = Vector3(0.28, 0.04, 0.0); _weapon_pivot.add_child(_arm_r)
	_add_part(_arm_r, uarm, m_jacket, Vector3(-0.02, -0.04, 0.18), Vector3(82, -10, 0))
	_add_part(_arm_r, hand_m, m_skin, Vector3(-0.04, -0.07, 0.36))

	_arm_l = Node3D.new(); _arm_l.position = Vector3(-0.28, 0.04, 0.0); _weapon_pivot.add_child(_arm_l)
	_add_part(_arm_l, uarm, m_jacket, Vector3(0.14, -0.05, 0.24), Vector3(84, 34, 0))
	_add_part(_arm_l, hand_m, m_skin, Vector3(0.26, -0.07, 0.44))

	_weapon_socket = Node3D.new()
	_weapon_socket.position = Vector3(0.16, -0.05, 0.42)
	_weapon_pivot.add_child(_weapon_socket)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.88, 0)
	add_child(cs)

	_model_root = Node3D.new()
	add_child(_model_root)
	_build_kinematic_survivor()

	# Footstep Dust Trail while running
	_foot_dust = CPUParticles3D.new()
	_foot_dust.amount = 18
	_foot_dust.lifetime = 0.35
	_foot_dust.emitting = false
	_foot_dust.direction = Vector3(0, 1, 0)
	_foot_dust.spread = 55.0
	_foot_dust.initial_velocity_min = 0.8
	_foot_dust.initial_velocity_max = 1.8
	_foot_dust.gravity = Vector3(0, -1.5, 0)
	var dm := SphereMesh.new(); dm.radius = 0.09; dm.height = 0.18
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.62, 0.65, 0.70, 0.32)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.material = dmat
	_foot_dust.mesh = dm
	_foot_dust.position = Vector3(0, 0.12, 0)
	add_child(_foot_dust)

	# Flashlight Cone attached to weapon pivot so it swings with aim!
	_flashlight = SpotLight3D.new()
	_flashlight.position = Vector3(0.16, 0.04, 0.45)
	_flashlight.rotation_degrees = Vector3(-16.0, 180.0, 0.0)
	_flashlight.light_color = Color(0.95, 0.98, 1.0)
	_flashlight.light_energy = 15.0
	_flashlight.spot_range = 28.0
	_flashlight.spot_angle = 30.0
	_flashlight.spot_attenuation = 0.95
	_flashlight.shadow_enabled = true
	_weapon_pivot.add_child(_flashlight)
	if ResourceLoader.exists("res://assets/shaders/flashlight_cone.gdshader"):
		_beam_cone = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.08; cm.bottom_radius = 3.8; cm.height = 13.5; cm.cap_top = false; cm.cap_bottom = false
		_beam_cone.mesh = cm
		var cmat := ShaderMaterial.new()
		cmat.shader = load("res://assets/shaders/flashlight_cone.gdshader")
		cmat.set_shader_parameter("beam_color", Color(0.84, 0.94, 1.0, 0.09))
		_beam_cone.material_override = cmat
		_beam_cone.position = Vector3(0.16, -0.05, 7.1)
		_beam_cone.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		_weapon_pivot.add_child(_beam_cone)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.position = Vector3(0.16, 0.0, 1.05)
	_muzzle_light.light_color = Color(1.0, 0.78, 0.35)
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 8.5
	_muzzle_light.shadow_enabled = false
	_weapon_pivot.add_child(_muzzle_light)

	_vax_shield = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.15; sm.height = 2.3
	_vax_shield.mesh = sm
	var sh_mat := StandardMaterial3D.new()
	sh_mat.albedo_color = Color(0.22, 0.95, 0.55, 0.20)
	sh_mat.emission_enabled = true
	sh_mat.emission = Color(0.22, 0.95, 0.55)
	sh_mat.emission_energy_multiplier = 2.2
	sh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vax_shield.material_override = sh_mat
	_vax_shield.position = Vector3(0, 1.0, 0)
	_vax_shield.visible = false
	add_child(_vax_shield)

	# Crisp white overhead marker above player (from reference video!)
	var tri_mesh := PrismMesh.new()
	tri_mesh.size = Vector3(0.26, 0.24, 0.05)
	var tri := MeshInstance3D.new()
	tri.mesh = tri_mesh
	tri.position = Vector3(0.0, 2.35, 0.0)
	tri.scale = Vector3(1.0, -1.0, 1.0)
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	tri.material_override = tmat
	add_child(tri)

	GameManager.weapon_changed.connect(_on_weapon_changed)
	GameManager.stats_updated.connect(_refresh_flashlight)
	_on_weapon_changed(GameManager.get_current_weapon_id(), false)

func _set_layer_recursive(n: Node, layer_mask: int) -> void:
	if n is MeshInstance3D:
		n.layers = layer_mask
	for c in n.get_children():
		_set_layer_recursive(c, layer_mask)

func _on_weapon_changed(weapon_id: String, _is_chaos: bool) -> void:
	if _weapon_mesh and is_instance_valid(_weapon_mesh):
		_weapon_mesh.queue_free()
	var w: Dictionary = GameData.WEAPONS[weapon_id]
	if ResourceLoader.exists(w["model"]):
		_weapon_mesh = (load(w["model"]) as PackedScene).instantiate()
		_weapon_mesh.scale = Vector3.ONE * 1.18
		_set_layer_recursive(_weapon_mesh, 2)
		_weapon_socket.add_child(_weapon_mesh)
	_swap_anim = 1.0

func _refresh_flashlight() -> void:
	if _flashlight == null:
		return
	if GameManager.has_perk("duality_tunnel_vision"):
		_flashlight.spot_angle = 19.0
		_flashlight.spot_range = 32.0
		_flashlight.light_energy = 11.0
	else:
		_flashlight.spot_angle = 30.0
		_flashlight.spot_range = 28.0
		_flashlight.light_energy = 15.0

func trigger_touch_dash() -> void:
	_dash_buffer = 0.14

func get_dash_cooldown_ratio() -> float:
	return clampf(_dash_cd / 0.72, 0.0, 1.0)

func add_camera_trauma(amount: float) -> void:
	_cam_trauma = minf(1.0, _cam_trauma + amount * SettingsManager.screen_shake_scale)

func _input(event: InputEvent) -> void:
	if not GameManager.run_active or GameManager.intro_playing or GameManager.is_drafting or get_tree().paused:
		return
	if event is InputEventMouseMotion:
		_use_gamepad_aim = false
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.25 and event.axis in [2, 3]:
		_use_gamepad_aim = true
	if event.is_action_pressed("dash"):
		_dash_buffer = 0.14

	# Instant, reliable weapon switching (1-6, Q/E, Tab, Mouse Wheel, Right-Click, LB/RB)
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.keycode
		if kc == KEY_Q: GameManager.cycle_weapon(-1)
		elif kc == KEY_E or kc == KEY_TAB: GameManager.cycle_weapon(1)
		elif kc >= KEY_1 and kc <= KEY_6: GameManager.select_weapon_slot(kc - KEY_1)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: GameManager.cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: GameManager.cycle_weapon(1)
		elif event.button_index == MOUSE_BUTTON_RIGHT: GameManager.cycle_weapon(1)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER: GameManager.cycle_weapon(-1)
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER: GameManager.cycle_weapon(1)

func _physics_process(delta: float) -> void:
	if not GameManager.run_active or GameManager.intro_playing:
		return

	_vax_shield.visible = GameManager.is_invulnerable()
	if _vax_shield.visible:
		_vax_shield.rotation.y += delta * 2.5

	# 1. Fast, Snappy Movement Input
	var in_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_move.length_squared() > 0.01:
		in_vec = touch_move
	var move_dir := Vector3(in_vec.x, 0.0, in_vec.y)
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()

	var is_moving := move_dir.length_squared() > 0.01
	var wants_sprint := (Input.is_action_pressed("sprint") or touch_sprinting) and is_moving
	var sprinting := false
	if wants_sprint:
		if GameManager.stamina > 0.5:
			sprinting = true
			GameManager.stamina = maxf(0.0, GameManager.stamina - 20.0 * delta)
		elif GameManager.has_perk("duality_blood_fuel") and GameManager.hp > 5.0:
			sprinting = true
			GameManager.hp = maxf(1.0, GameManager.hp - 10.0 * delta)
	else:
		var regen := 34.0 if GameManager.starting_trait == "street_rat" else 28.0
		GameManager.stamina = minf(GameManager.max_stamina, GameManager.stamina + regen * delta)

	# 2. Buffered Dash / Shove
	if _dash_cd > 0.0:
		_dash_cd -= delta
	if _dash_buffer > 0.0:
		_dash_buffer -= delta
		if _dash_cd <= 0.0 and GameManager.stamina >= 16.0:
			_dash_buffer = 0.0
			_dash_cd = 0.65
			_dash_timer = 0.16
			GameManager.stamina -= 16.0
			_dash_dir = move_dir if is_moving else _aim_dir
			AudioManager.play_sfx("dash_whoosh", 0.94, 1.1, 0.8)
			if GameManager.has_perk("shockwave_dash") and horde_manager:
				horde_manager.damage_in_radius(global_position, 5.2, 48.0 * GameManager.get_damage_mult(), true)
				if vfx_juice: vfx_juice.spawn_shockwave_ring(global_position, 5.4, Color(0.25, 0.95, 1.0))
				add_camera_trauma(0.28)

	var spd := GameManager.get_move_speed() * (1.42 if sprinting else 1.0)
	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * (spd * 2.4)
	else:
		var target_vel := move_dir * spd
		velocity = velocity.lerp(target_vel, minf(1.0, delta * 22.0))
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0
	global_position.x = clampf(global_position.x, -52.5, 50.5)
	global_position.z = clampf(global_position.z, -170.0, 11.5)

	# Acid hazard check
	if horde_manager and horde_manager.decal_manager and horde_manager.decal_manager.is_in_acid(global_position):
		_acid_tick -= delta
		if _acid_tick <= 0.0:
			_acid_tick = 0.45
			GameManager.damage_player(7.0)

	# 3. Tight Mouse / Twin-Stick Aiming
	var r_stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var stick_firing := false
	if touch_aim.length() > 0.18:
		_use_gamepad_aim = true
		_aim_dir = Vector3(touch_aim.x, 0.0, touch_aim.y).normalized()
		stick_firing = touch_firing
	elif r_stick.length() > 0.25:
		_use_gamepad_aim = true
		_aim_dir = Vector3(r_stick.x, 0.0, r_stick.y).normalized()
		stick_firing = true
	elif touch_active:
		_use_gamepad_aim = true
		if is_moving:
			_aim_dir = _aim_dir.lerp(move_dir.normalized(), minf(1.0, delta * 12.0)).normalized()
	elif not _use_gamepad_aim and camera != null:
		var mpos := get_viewport().get_mouse_position()
		var ray_orig := camera.project_ray_origin(mpos)
		var ray_dir := camera.project_ray_normal(mpos)
		if absf(ray_dir.y) > 0.001:
			var t := (1.15 - ray_orig.y) / ray_dir.y
			var world_pt := ray_orig + ray_dir * t
			var d := Vector3(world_pt.x - global_position.x, 0.0, world_pt.z - global_position.z)
			if d.length_squared() > 0.02:
				_aim_dir = d.normalized()

	var target_yaw := atan2(_aim_dir.x, _aim_dir.z)
	_model_root.rotation.y = lerp_angle(_model_root.rotation.y, target_yaw, minf(1.0, delta * 28.0))

	# 4. Real 60 FPS Kinematic Running, Strafing, Dash, Breathing & Recoil Animation!
	_update_kinematics(delta, sprinting)

	# 5. Firing System
	if _fire_cd > 0.0:
		_fire_cd -= delta
	if _muzzle_t > 0.0:
		_muzzle_t -= delta
		_muzzle_light.light_energy = (_muzzle_t / 0.055) * 9.0
	else:
		_muzzle_light.light_energy = 0.0

	var wants_fire := Input.is_action_pressed("shoot") or stick_firing
	if wants_fire and _fire_cd <= 0.0 and projectile_system != null:
		_fire_weapon(not is_moving, sprinting)

	# 6. Dynamic Aim Look-Ahead Camera + Trauma Shake
	if camera != null:
		var target_ahead := _aim_dir * 2.2
		_cam_look_ahead = _cam_look_ahead.lerp(target_ahead, minf(1.0, delta * 6.0))
		var base_cam := global_position + _cam_offset + _cam_look_ahead
		var shake_off := Vector3.ZERO
		if _cam_trauma > 0.0:
			var mag := _cam_trauma * _cam_trauma * 0.58
			shake_off = Vector3(randf_range(-mag, mag), randf_range(-mag * 0.5, mag * 0.5), randf_range(-mag, mag))
			_cam_trauma = maxf(0.0, _cam_trauma - delta * 2.5)
		camera.global_position = camera.global_position.lerp(base_cam, minf(1.0, delta * 10.0)) + shake_off
		camera.look_at(global_position + _cam_look_ahead * 0.6 + Vector3(0, 0.8, 0), Vector3.UP)

func _update_kinematics(delta: float, sprinting: bool) -> void:
	_idle_t += delta
	_recoil_kick = maxf(0.0, _recoil_kick - delta * 9.0)
	_swap_anim = maxf(0.0, _swap_anim - delta * 6.5)

	var h_vel := Vector3(velocity.x, 0.0, velocity.z)
	var speed := h_vel.length()
	var run_ratio := clampf(speed / 9.0, 0.0, 1.35)
	_foot_dust.emitting = speed > 4.2 or _dash_timer > 0.0

	# Compute velocity in character's local facing space (+Z = forward, +X = right)
	var fwd := _model_root.global_transform.basis.z.normalized()
	var rgt := _model_root.global_transform.basis.x.normalized()
	var local_fwd := h_vel.dot(fwd) / maxf(1.0, speed)
	var local_rgt := h_vel.dot(rgt) / maxf(1.0, speed)

	if speed > 0.4:
		_stride_phase += delta * (11.5 + speed * 0.85)
		var s := sin(_stride_phase)
		var c := cos(_stride_phase)
		var amp := minf(1.05, 0.68 * run_ratio) * (1.15 if sprinting else 1.0)
		var dir_sign := 1.0 if local_fwd >= -0.2 else -1.0

		# Energetic athletic leg stride + knee bend
		_leg_l.rotation.x = s * amp * dir_sign
		_leg_r.rotation.x = -s * amp * dir_sign
		_leg_l.rotation.z = local_rgt * 0.22 * s
		_leg_r.rotation.z = -local_rgt * 0.22 * s
		_shin_l.rotation.x = clampf(-c * amp * 1.15, 0.0, 1.25)
		_shin_r.rotation.x = clampf(c * amp * 1.15, 0.0, 1.25)

		# Hip bounce & body lean into movement!
		_hips.position.y = 0.92 + absf(s) * 0.13 * minf(1.0, run_ratio)
		_hips.rotation.y = s * 0.14 * minf(1.0, run_ratio)
		var dash_lean := 0.45 if _dash_timer > 0.0 else 0.0
		_torso.rotation.x = lerpf(_torso.rotation.x, (0.18 * local_fwd * run_ratio) + dash_lean, minf(1.0, delta * 14.0))
		_torso.rotation.z = lerpf(_torso.rotation.z, -0.16 * local_rgt * run_ratio, minf(1.0, delta * 14.0))
		_torso.rotation.y = -s * 0.10 * minf(1.0, run_ratio)
	else:
		# Smooth return to combat-ready breathing stance
		_leg_l.rotation = _leg_l.rotation.lerp(Vector3(0.08, 0, -0.06), minf(1.0, delta * 14.0))
		_leg_r.rotation = _leg_r.rotation.lerp(Vector3(-0.08, 0, 0.06), minf(1.0, delta * 14.0))
		_shin_l.rotation.x = lerpf(_shin_l.rotation.x, 0.12, minf(1.0, delta * 14.0))
		_shin_r.rotation.x = lerpf(_shin_r.rotation.x, 0.12, minf(1.0, delta * 14.0))
		_hips.position.y = 0.92 + sin(_idle_t * 3.4) * 0.025
		_hips.rotation.y = lerpf(_hips.rotation.y, 0.0, minf(1.0, delta * 12.0))
		_torso.rotation = _torso.rotation.lerp(Vector3(0.06, 0, 0), minf(1.0, delta * 12.0))

	# Weapon Recoil Kickback + Crisp Weapon Swap Dip
	var swap_pitch := -sin(_swap_anim * PI) * 0.65
	_weapon_pivot.position.z = 0.06 - _recoil_kick * 0.15
	_weapon_pivot.rotation.x = -_recoil_kick * 0.22 + swap_pitch

func _fire_weapon(is_stationary: bool, is_sprinting: bool) -> void:
	var w := GameManager.get_current_weapon()
	var rof := float(w["fire_rate"]) * GameManager.get_fire_rate_mult(is_sprinting)
	_fire_cd = 1.0 / maxf(0.5, rof)
	_muzzle_t = 0.055
	_recoil_kick = 1.0
	var origin := global_position + Vector3(0, 1.24, 0) + _aim_dir * 0.95

	var pellets := int(w["pellets"])
	var spread := deg_to_rad(float(w["spread_deg"]))
	var crit_chance := GameManager.get_crit_chance(is_stationary)
	var base_dmg := float(w["damage"]) * GameManager.get_damage_mult()
	var pierce := int(w["pierce"]) + int(GameManager.get_stat_sum("pierce"))
	var bounces := int(GameManager.get_stat_sum("ricochet"))
	var explosive := GameManager.has_chaos_buff("explosive")

	for _p in range(pellets):
		var ang := randf_range(-spread * 0.5, spread * 0.5)
		var dir := _aim_dir.rotated(Vector3.UP, ang).normalized()
		var is_crit := randf() < crit_chance
		var dmg := base_dmg * (GameManager.get_crit_damage_mult() if is_crit else 1.0)
		GameManager.shots_fired += 1
		projectile_system.spawn_projectile(origin, dir, w, is_crit, dmg, pierce, bounces, explosive)

	if vfx_juice:
		vfx_juice.spawn_muzzle_flash(origin, _aim_dir, w["color"])
		if not w.get("is_flame", false):
			vfx_juice.spawn_shell_casing(origin - _aim_dir * 0.35, _aim_dir.cross(Vector3.UP).normalized())
	AudioManager.play_sfx(w["sfx"], 0.93, 1.08, 0.72)
	add_camera_trauma(float(w["shake"]))
