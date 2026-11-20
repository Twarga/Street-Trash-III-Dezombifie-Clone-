class_name CityBuilder
extends Node3D

signal world_alert(title: String, sub: String)

var explosion_system: ExplosionSystem = null
var horde_manager: HordeManager = null

var garage_shutter_anim: AnimationPlayer = null
var gear_nodes: Array[Node3D] = []
var weapon_crates: Array[Dictionary] = []
var turret_kits: Array[Node3D] = []
var supply_drops: Array[Node3D] = []
var world_medkits: Array[Node3D] = []
var extraction_pad_pos := Vector3(0.0, 0.0, -148.0)
var extraction_ring_mat: StandardMaterial3D = null
var extraction_light: OmniLight3D = null
var _searchlight_l: SpotLight3D = null
var _searchlight_r: SpotLight3D = null
var _fire_lights: Array[OmniLight3D] = []
var _flare_lights: Array[OmniLight3D] = []
var _boss_triggers: Array[Dictionary] = []
var _district_ambushes: Array[Dictionary] = []
var _supply_drop_timer: float = 48.0
var _pbr_cache: Dictionary = {}

func _enable_fade(lgt: Light3D, begin_d: float = 28.0, fade_len: float = 12.0) -> void:
	lgt.shadow_enabled = false
	lgt.distance_fade_enabled = true
	lgt.distance_fade_begin = begin_d
	lgt.distance_fade_length = fade_len

func build_city(is_endless: bool) -> void:
	_build_ground_and_streets()
	_build_safe_house_garage()
	_build_city_blocks_and_neon()
	_build_gas_365_plaza()
	_build_neon_alley_courtyard()
	_build_subway_floodlight_lot()
	_build_industrial_cargo_yard()
	_build_main_avenue_props()
	_build_highrise_extraction()
	_build_reflection_probes()
	_spawn_weapon_crates_and_medkits()
	_district_ambushes = [
		{"name": "GAS 365 HORDE ALERT!", "pos": Vector3(-28.0, 0, -34.0), "rad": 14.0, "fired": false, "spawns": ["charger", "spitter", "sprinter", "sprinter", "shambler", "shambler"]},
		{"name": "NEON ALLEY AMBUSH!", "pos": Vector3(28.0, 0, -34.0), "rad": 14.0, "fired": false, "spawns": ["spitter", "spitter", "sprinter", "sprinter", "bruiser", "shambler"]},
		{"name": "INDUSTRIAL SWARM BREACH!", "pos": Vector3(28.0, 0, -92.0), "rad": 14.0, "fired": false, "spawns": ["charger", "charger", "bloater", "spitter", "sprinter", "sprinter"]},
	]
	if not is_endless:
		_spawn_campaign_gears()
		_boss_triggers = [
			{"pos": Vector3(-32.0, 0.0, -92.0), "rad": 16.0, "fired": false, "spawn": Vector3(-38.0, 0.0, -96.0)},
			{"pos": Vector3(0.0, 0.0, -132.0), "rad": 16.0, "fired": false, "spawn": Vector3(0.0, 0.0, -152.0)},
		]

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in range(_fire_lights.size()):
		var fl := _fire_lights[i]
		if is_instance_valid(fl):
			fl.light_energy = 4.5 + sin(t * 14.0 + float(i) * 1.7) * 0.85 + cos(t * 23.0 + float(i)) * 0.40
	for i in range(_flare_lights.size()):
		var fl := _flare_lights[i]
		if is_instance_valid(fl):
			fl.light_energy = 3.2 + sin(t * 26.0 + float(i) * 2.3) * 0.95
	if _searchlight_l and _searchlight_r:
		_searchlight_l.rotation_degrees.y = -25.0 + sin(t * 0.85) * 32.0
		_searchlight_r.rotation_degrees.y = 25.0 + cos(t * 0.72) * 32.0
	for g in gear_nodes:
		if is_instance_valid(g): g.rotation.y += delta * 2.2
	for wc in weapon_crates:
		var n: Node3D = wc["node"]
		if is_instance_valid(n): n.rotation.y += delta * 1.4
	for tk in turret_kits:
		if is_instance_valid(tk): tk.rotation.y += delta * 1.8
	for sd in supply_drops:
		if is_instance_valid(sd): sd.rotation.y += delta * 1.2
	for mk in world_medkits:
		if is_instance_valid(mk): mk.rotation.y += delta * 1.8

	# Dynamic Timed Supply Drops for continuous mid-run excitement!
	if GameManager.run_active and not GameManager.intro_playing and not get_tree().paused:
		_supply_drop_timer -= delta
		if _supply_drop_timer <= 0.0 and supply_drops.size() < 2:
			_supply_drop_timer = 58.0
			_spawn_random_supply_drop()

	if extraction_ring_mat:
		var ready := GameManager.gears >= GameManager.gears_required
		var col := Color(0.22, 1.0, 0.42) if ready else Color(1.0, 0.35, 0.12)
		extraction_ring_mat.albedo_color = col; extraction_ring_mat.emission = col
		extraction_ring_mat.emission_energy_multiplier = 4.2 + sin(t * 5.0) * 1.2 if ready else 1.5
		if extraction_light:
			extraction_light.light_color = col; extraction_light.light_energy = 7.0 if ready else 2.6

func _spawn_random_supply_drop() -> void:
	var spots := [
		Vector3(0.0, 0.15, -34.0),
		Vector3(-28.0, 0.15, -30.0),
		Vector3(28.0, 0.15, -34.0),
		Vector3(0.0, 0.15, -92.0),
		Vector3(-28.0, 0.15, -92.0),
		Vector3(28.0, 0.15, -92.0),
	]
	var pos: Vector3 = spots[randi() % spots.size()]
	var root := Node3D.new(); root.position = pos
	var chest := _spawn_kenney("surv_chest.glb", Vector3.ZERO, 0.0, 2.2)
	if chest:
		chest.get_parent().remove_child(chest)
		root.add_child(chest)
	# Tall visible glowing red flare smoke beam rising from the drop crate
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new(); bm.top_radius = 0.06; bm.bottom_radius = 0.20; bm.height = 10.0
	beam.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.25, 0.15, 0.55); bmat.emission_enabled = true; bmat.emission = Color(1.0, 0.22, 0.12); bmat.emission_energy_multiplier = 4.5
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = bmat; beam.position = Vector3(0, 5.0, 0)
	root.add_child(beam)
	var lgt := OmniLight3D.new(); lgt.position = Vector3(0, 1.4, 0)
	lgt.light_color = Color(1.0, 0.30, 0.14); lgt.light_energy = 5.0; lgt.omni_range = 12.0
	_enable_fade(lgt, 30.0, 12.0); root.add_child(lgt)
	add_child(root); supply_drops.append(root)
	AudioManager.play_sfx("gear_pickup", 0.72, 0.85, 0.9)
	world_alert.emit("SUPPLY DROP INBOUND!", "")

func check_world_triggers(player_pos: Vector3) -> void:
	# 1. Gear Pickups (also triggers a tense mini-swarm!)
	for i in range(gear_nodes.size() - 1, -1, -1):
		var g := gear_nodes[i]
		if is_instance_valid(g) and player_pos.distance_to(g.global_position) < GameManager.get_pickup_radius() + 0.6:
			var gp := g.global_position
			g.queue_free(); gear_nodes.remove_at(i)
			GameManager.add_gear(false)
			if horde_manager:
				for k in ["sprinter", "sprinter", "spitter", "charger"]:
					var ang := randf() * TAU
					horde_manager.spawn_zombie(k, gp + Vector3(cos(ang) * 14.0, 0.0, sin(ang) * 14.0))

	# 2. Street Weapon Crate Pickups
	for i in range(weapon_crates.size() - 1, -1, -1):
		var wc: Dictionary = weapon_crates[i]
		var n: Node3D = wc["node"]
		if is_instance_valid(n) and player_pos.distance_to(n.global_position) < maxf(2.5, GameManager.get_pickup_radius()):
			GameManager.unlock_weapon(str(wc["weapon_id"]), true)
			AudioManager.play_sfx("gear_pickup", 0.95, 1.15, 0.9)
			n.queue_free(); weapon_crates.remove_at(i)

	# 3. Deployable Automated Sentry Turret Kits!
	for i in range(turret_kits.size() - 1, -1, -1):
		var tk := turret_kits[i]
		if is_instance_valid(tk) and player_pos.distance_to(tk.global_position) < maxf(2.5, GameManager.get_pickup_radius()):
			var tp := tk.global_position
			tk.queue_free(); turret_kits.remove_at(i)
			if horde_manager: horde_manager.spawn_sentry_turret(tp)
			world_alert.emit("SENTRY TURRET DEPLOYED!", "")

	# 4. Dynamic Supply Drop Crates!
	for i in range(supply_drops.size() - 1, -1, -1):
		var sd := supply_drops[i]
		if is_instance_valid(sd) and player_pos.distance_to(sd.global_position) < maxf(2.6, GameManager.get_pickup_radius()):
			var sp := sd.global_position
			sd.queue_free(); supply_drops.remove_at(i)
			GameManager.heal_player(55.0)
			GameManager.add_xp(140.0)
			var chaos_list := ["hmg", "autoshotgun", "flamethrower"]
			var cw: String = chaos_list[randi() % chaos_list.size()]
			GameManager.chaos_weapon_id = cw; GameManager.chaos_weapon_timer = 25.0
			GameManager.weapon_changed.emit(cw, true)
			AudioManager.play_sfx("gear_pickup", 1.05, 1.2, 0.95)
			world_alert.emit("SUPPLY DROP: OVERDRIVE!", "")
			if horde_manager:
				for k in ["sprinter", "sprinter", "charger", "spitter", "bloater"]:
					var ang := randf() * TAU
					horde_manager.spawn_zombie(k, sp + Vector3(cos(ang) * 15.0, 0.0, sin(ang) * 15.0))

	# 5. Landmark Medkits
	for i in range(world_medkits.size() - 1, -1, -1):
		var mk: Node3D = world_medkits[i]
		if is_instance_valid(mk) and GameManager.hp < GameManager.max_hp and player_pos.distance_to(mk.global_position) < maxf(2.4, GameManager.get_pickup_radius()):
			GameManager.heal_player(50.0)
			AudioManager.play_sfx("pickup_health", 0.95, 1.05, 0.85)
			mk.queue_free(); world_medkits.remove_at(i)

	# 6. District Ambush Alarms!
	for da in _district_ambushes:
		if not da["fired"] and player_pos.distance_to(da["pos"] as Vector3) < float(da["rad"]):
			da["fired"] = true
			world_alert.emit(str(da["name"]), "")
			AudioManager.play_sfx("zombie_groan_1", 0.72, 0.85, 0.9)
			if horde_manager:
				var center: Vector3 = da["pos"]
				for k in da["spawns"]:
					var ang := randf() * TAU
					horde_manager.spawn_zombie(str(k), center + Vector3(cos(ang) * randf_range(11.0, 17.0), 0.0, sin(ang) * randf_range(11.0, 17.0)))

	# 7. Boss Milestone Triggers
	for bt in _boss_triggers:
		if not bt["fired"] and player_pos.distance_to(bt["pos"] as Vector3) < float(bt["rad"]):
			bt["fired"] = true
			if horde_manager: horde_manager.spawn_zombie("boss", bt["spawn"])

	# 8. Extraction Pad Activation
	if GameManager.mode == GameManager.GameMode.ESCAPE and GameManager.gears >= GameManager.gears_required and not GameManager.holdout_active:
		if player_pos.distance_to(extraction_pad_pos) < 5.5:
			GameManager.start_extraction_holdout()

# ---- Grounded Physical Light Source Fixtures (ZERO Floating Invisible Lights!) ----
func _add_streetlamp_with_bulb(pos: Vector3, rot_y: float, col: Color, lamp_sc: PackedScene) -> void:
	var root := Node3D.new(); root.position = pos; root.rotation_degrees.y = rot_y
	add_child(root)
	if lamp_sc:
		root.add_child(lamp_sc.instantiate())
	# Visible glowing glass bulb housing mounted right on the streetlamp head!
	var bulb := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.45, 0.16, 0.78)
	bulb.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1, 1, 1); bmat.emission_enabled = true; bmat.emission = col; bmat.emission_energy_multiplier = 6.5
	bulb.material_override = bmat
	bulb.position = Vector3(0.0, 6.25, 1.85)
	root.add_child(bulb)

	var sl := SpotLight3D.new()
	sl.position = Vector3(0.0, 6.10, 1.85)
	sl.rotation_degrees.x = -85.0
	sl.light_color = col; sl.light_energy = 7.8; sl.spot_range = 24.0; sl.spot_angle = 68.0
	_enable_fade(sl, 30.0, 12.0)
	root.add_child(sl)

func _add_wall_sconce(pos: Vector3, rot_y: float, col: Color) -> void:
	var root := Node3D.new(); root.position = pos; root.rotation_degrees.y = rot_y
	add_child(root)
	var hood := MeshInstance3D.new(); var hm := BoxMesh.new(); hm.size = Vector3(0.46, 0.16, 0.42)
	hood.mesh = hm; hood.material_override = _make_photoreal_pbr("rust_metal", Color(0.22, 0.24, 0.28))
	hood.position = Vector3(0, 0.18, 0.18); root.add_child(hood)
	var bulb := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.14; sm.height = 0.28
	bulb.mesh = sm
	var bmat := StandardMaterial3D.new(); bmat.albedo_color = Color(1, 1, 1); bmat.emission_enabled = true; bmat.emission = col; bmat.emission_energy_multiplier = 6.0
	bulb.material_override = bmat; bulb.position = Vector3(0, 0.0, 0.22); root.add_child(bulb)
	var lgt := OmniLight3D.new(); lgt.position = Vector3(0, -0.1, 0.45)
	lgt.light_color = col; lgt.light_energy = 4.2; lgt.omni_range = 14.0
	_enable_fade(lgt, 26.0, 10.0); root.add_child(lgt)

func _add_road_flare(pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var tube := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.04; cm.bottom_radius = 0.04; cm.height = 0.36
	tube.mesh = cm
	var tmat := StandardMaterial3D.new(); tmat.albedo_color = Color(0.85, 0.12, 0.10)
	tube.material_override = tmat; tube.position = Vector3(0, 0.05, 0); tube.rotation_degrees = Vector3(82, 25, 0)
	root.add_child(tube)
	var tip := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.09; sp.height = 0.18
	tip.mesh = sp
	var em := StandardMaterial3D.new(); em.albedo_color = Color(1, 0.85, 0.8); em.emission_enabled = true; em.emission = Color(1.0, 0.14, 0.10); em.emission_energy_multiplier = 8.0
	tip.material_override = em; tip.position = Vector3(0.08, 0.08, 0.16); root.add_child(tip)
	var lgt := OmniLight3D.new(); lgt.position = Vector3(0.08, 0.32, 0.16)
	lgt.light_color = Color(1.0, 0.18, 0.12); lgt.light_energy = 3.4; lgt.omni_range = 9.0
	_enable_fade(lgt, 22.0, 10.0); root.add_child(lgt); _flare_lights.append(lgt)

func _add_vending_machine(pos: Vector3, rot_y: float, col: Color) -> void:
	var root := Node3D.new(); root.position = pos; root.rotation_degrees.y = rot_y; add_child(root)
	var cab := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.15, 2.05, 0.85)
	cab.mesh = bm; cab.material_override = _make_photoreal_pbr("rust_metal", Color(0.24, 0.28, 0.34))
	cab.position = Vector3(0, 1.02, 0); root.add_child(cab)
	var front := MeshInstance3D.new(); var fm := QuadMesh.new(); fm.size = Vector2(0.88, 1.25)
	front.mesh = fm
	var fmat := StandardMaterial3D.new(); fmat.albedo_color = col; fmat.emission_enabled = true; fmat.emission = col; fmat.emission_energy_multiplier = 2.6
	front.material_override = fmat; front.position = Vector3(0, 1.22, 0.44); root.add_child(front)
	var lgt := OmniLight3D.new(); lgt.position = Vector3(0, 1.25, 0.85)
	lgt.light_color = col; lgt.light_energy = 2.4; lgt.omni_range = 7.5
	_enable_fade(lgt, 20.0, 8.0); root.add_child(lgt)
	_add_collider_box(pos + Vector3(0, 1.0, 0), Vector3(1.15, 2.0, 0.95))

func _make_photoreal_pbr(pbr_name: String, tint: Color = Color.WHITE, tri_scale: float = 0.25, rough_mult: float = 1.0, metal: float = 0.05, norm_strength: float = 1.35) -> StandardMaterial3D:
	var key := "%s_%s_%.2f_%.2f_%.2f" % [pbr_name, tint.to_html(), tri_scale, rough_mult, metal]
	if _pbr_cache.has(key):
		return _pbr_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint; m.metallic = metal; m.roughness = rough_mult
	m.uv1_triplanar = true; m.uv1_world_triplanar = true; m.uv1_scale = Vector3.ONE * tri_scale
	var base_p := "res://assets/textures/pbr/%s" % pbr_name
	if ResourceLoader.exists(base_p + "_albedo.jpg"): m.albedo_texture = load(base_p + "_albedo.jpg")
	if ResourceLoader.exists(base_p + "_normal.jpg"):
		m.normal_enabled = true; m.normal_texture = load(base_p + "_normal.jpg"); m.normal_scale = norm_strength
	if ResourceLoader.exists(base_p + "_rough.jpg"): m.roughness_texture = load(base_p + "_rough.jpg")
	_pbr_cache[key] = m
	return m

func _make_pbr_mat(prefix: String, _uv_scale: Vector3 = Vector3.ONE, rough_scale: float = 1.0) -> StandardMaterial3D:
	if prefix == "asphalt":
		return _make_photoreal_pbr("wet_asphalt", Color(0.74, 0.78, 0.84), 0.16, 0.30 * rough_scale, 0.14, 1.4)
	elif prefix == "sidewalk":
		return _make_photoreal_pbr("grimy_concrete", Color(0.80, 0.82, 0.86), 0.24, 0.72 * rough_scale, 0.05, 1.3)
	elif prefix == "brick":
		return _make_photoreal_pbr("urban_brick", Color(0.78, 0.68, 0.64), 0.28, 0.86 * rough_scale, 0.04, 1.45)
	return _make_photoreal_pbr("grimy_concrete", Color(0.75, 0.76, 0.78), 0.25, 0.78, 0.05, 1.2)

func _add_collider_box(pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new(); sb.collision_layer = 1
	var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = size
	cs.shape = bx; sb.position = pos; sb.add_child(cs); add_child(sb)

func _add_wet_puddle(pos: Vector3, sz: Vector2) -> void:
	var m := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = sz; m.mesh = pm
	var mat := StandardMaterial3D.new()
	var gtex := GradientTexture2D.new(); gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5); gtex.fill_to = Vector2(0.5, 0.02)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.08, 0.11, 0.15, 0.55), Color(0.08, 0.11, 0.15, 0.25), Color(0.08, 0.11, 0.15, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.58, 1.0]); gtex.gradient = g
	mat.albedo_texture = gtex; mat.roughness = 0.03; mat.metallic = 0.35; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat; m.position = Vector3(pos.x, 0.022, pos.z); add_child(m)

func _add_3d_window(pos: Vector3, rot_y: float, is_warm: bool) -> void:
	var root := Node3D.new(); root.position = pos; root.rotation_degrees.y = rot_y; add_child(root)
	var frame := MeshInstance3D.new(); var fm := BoxMesh.new(); fm.size = Vector3(1.85, 1.65, 0.20)
	frame.mesh = fm; frame.material_override = _make_photoreal_pbr("rust_metal", Color(0.22, 0.24, 0.28), 0.8, 0.65, 0.35, 0.6)
	root.add_child(frame)
	var glass := MeshInstance3D.new(); var gm := QuadMesh.new(); gm.size = Vector2(1.52, 1.32); glass.mesh = gm
	var gmat := StandardMaterial3D.new()
	if is_warm:
		gmat.albedo_color = Color(1.0, 0.72, 0.30); gmat.emission_enabled = true; gmat.emission = Color(1.0, 0.68, 0.28); gmat.emission_energy_multiplier = 2.0
	else:
		gmat.albedo_color = Color(0.28, 0.52, 0.68); gmat.emission_enabled = true; gmat.emission = Color(0.32, 0.78, 0.96); gmat.emission_energy_multiplier = 1.6
	gmat.roughness = 0.08; gmat.metallic = 0.22; glass.material_override = gmat; glass.position = Vector3(0, 0, 0.115)
	root.add_child(glass)

func _build_ground_and_streets() -> void:
	var road_mat := _make_pbr_mat("asphalt", Vector3.ONE, 0.92)
	_add_collider_box(Vector3(0.0, -0.25, -80.0), Vector3(122.0, 0.5, 200.0))

	var ground_mesh := MeshInstance3D.new(); var gp := PlaneMesh.new(); gp.size = Vector2(120.0, 198.0)
	ground_mesh.mesh = gp; ground_mesh.material_override = road_mat; ground_mesh.position = Vector3(0.0, 0.0, -80.0)
	add_child(ground_mesh)

	var ymat := StandardMaterial3D.new(); ymat.albedo_color = Color(0.92, 0.68, 0.14); ymat.roughness = 0.38
	for seg in [[8.0, -16.0], [-52.0, -74.0], [-110.0, -128.0]]:
		var z0: float = seg[0]; var z1: float = seg[1]
		for sx in [-0.18, 0.18]:
			var ln := MeshInstance3D.new(); var lp := PlaneMesh.new(); lp.size = Vector2(0.15, absf(z0 - z1))
			ln.mesh = lp; ln.material_override = ymat; ln.position = Vector3(sx, 0.016, (z0 + z1) * 0.5); add_child(ln)

	for cz in [-34.0, -92.0]:
		for seg in [[-48.0, -12.0], [12.0, 48.0]]:
			var x0: float = seg[0]; var x1: float = seg[1]
			for sz in [-0.18, 0.18]:
				var ln := MeshInstance3D.new(); var lp := PlaneMesh.new(); lp.size = Vector2(absf(x1 - x0), 0.15)
				ln.mesh = lp; ln.material_override = ymat; ln.position = Vector3((x0 + x1) * 0.5, 0.016, cz + sz); add_child(ln)

	var wmat := StandardMaterial3D.new(); wmat.albedo_color = Color(0.82, 0.84, 0.86); wmat.roughness = 0.44
	for cz in [-18.0, -50.0, -76.0, -108.0, -130.0]:
		for cx in range(-7, 8, 2):
			var st := MeshInstance3D.new(); var sp := PlaneMesh.new(); sp.size = Vector2(0.85, 2.8)
			st.mesh = sp; st.material_override = wmat; st.position = Vector3(float(cx), 0.018, cz); add_child(st)
	for cz in [-34.0, -92.0]:
		for cx in [-11.5, 11.5]:
			for dz in range(-7, 8, 2):
				var st := MeshInstance3D.new(); var sp := PlaneMesh.new(); sp.size = Vector2(2.8, 0.85)
				st.mesh = sp; st.material_override = wmat; st.position = Vector3(cx, 0.018, cz + float(dz)); add_child(st)

	for p in [
		[Vector3(-2.5, 0, -8.0), Vector2(6.5, 7.0)], [Vector3(0.0, 0, -34.0), Vector2(10.0, 10.0)],
		[Vector3(-28.0, 0, -34.0), Vector2(11.0, 9.0)], [Vector3(28.0, 0, -34.0), Vector2(10.0, 8.5)],
		[Vector3(0.0, 0, -92.0), Vector2(10.0, 10.0)], [Vector3(-30.0, 0, -92.0), Vector2(11.0, 9.0)],
		[Vector3(0.0, 0, -144.0), Vector2(14.0, 12.0)],
	]:
		_add_wet_puddle(p[0], p[1])

	var sw_mat := _make_pbr_mat("sidewalk")
	for seg in [[12.0, -15.0], [-53.0, -73.0], [-111.0, -129.0]]:
		var z0: float = seg[0]; var z1: float = seg[1]
		for sx in [-10.6, 10.6]:
			var sw := MeshInstance3D.new(); var sb := BoxMesh.new(); sb.size = Vector3(3.8, 0.14, absf(z0 - z1))
			sw.mesh = sb; sw.material_override = sw_mat; sw.position = Vector3(sx, 0.07, (z0 + z1) * 0.5); add_child(sw)

	_add_collider_box(Vector3(0.0, 4.0, 13.5), Vector3(114.0, 8.0, 1.5))
	_add_collider_box(Vector3(0.0, 4.0, -172.5), Vector3(114.0, 8.0, 1.5))
	_add_collider_box(Vector3(-52.5, 4.0, -80.0), Vector3(1.5, 8.0, 190.0))
	_add_collider_box(Vector3(50.5, 4.0, -80.0), Vector3(1.5, 8.0, 190.0))
	_add_collider_box(Vector3(-31.0, 4.0, -152.0), Vector3(2.0, 8.0, 44.0))
	_add_collider_box(Vector3(31.0, 4.0, -152.0), Vector3(2.0, 8.0, 44.0))

func _build_safe_house_garage() -> void:
	var garage := Node3D.new(); garage.position = Vector3(0, 0, 9.5); add_child(garage)
	if ResourceLoader.exists("res://assets/models/garage_shutter.glb"):
		var sh := (load("res://assets/models/garage_shutter.glb") as PackedScene).instantiate()
		garage.add_child(sh); garage_shutter_anim = _find_anim(sh)
	var back := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(5.6, 4.0, 4.0)
	back.mesh = bm; back.material_override = _make_pbr_mat("sidewalk"); back.position = Vector3(0, 2.0, 2.2); garage.add_child(back)
	# Visible garage interior ceiling fluorescent tube!
	var tube := MeshInstance3D.new(); var tm := BoxMesh.new(); tm.size = Vector3(2.6, 0.12, 0.25)
	tube.mesh = tm; var tmat := StandardMaterial3D.new(); tmat.albedo_color = Color(1, 0.94, 0.8); tmat.emission_enabled = true; tmat.emission = Color(1, 0.88, 0.65); tmat.emission_energy_multiplier = 5.0
	tube.material_override = tmat; tube.position = Vector3(0, 3.6, 0.8); garage.add_child(tube)
	var warm_in := OmniLight3D.new(); warm_in.position = Vector3(0, 3.2, 0.8)
	warm_in.light_color = Color(1.0, 0.88, 0.65); warm_in.light_energy = 5.5; warm_in.omni_range = 12.0
	_enable_fade(warm_in); garage.add_child(warm_in)

	if ResourceLoader.exists("res://assets/ui/title_logo.png"):
		var sign_m := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(6.4, 3.0); sign_m.mesh = qm
		var sm := StandardMaterial3D.new(); var tex: Texture2D = load("res://assets/ui/title_logo.png")
		sm.albedo_texture = tex; sm.emission_enabled = true; sm.emission_texture = tex
		sm.emission_energy_multiplier = 2.0; sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sign_m.material_override = sm; sign_m.position = Vector3(0, 5.2, -0.25); sign_m.rotation_degrees.y = 180.0
		garage.add_child(sign_m)

func _build_block_quadrant(cx: float, cz: float, sx: float, sz: float, face_main_side: int) -> void:
	var brick_mat := _make_pbr_mat("brick")
	var bh := 13.0
	var b := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(sx, bh, sz)
	b.mesh = bm; b.material_override = brick_mat; b.position = Vector3(cx, bh * 0.5, cz); add_child(b)
	_add_collider_box(Vector3(cx, 4.0, cz), Vector3(sx, 8.0, sz))

	var occ := OccluderInstance3D.new(); var ob := BoxOccluder3D.new(); ob.size = Vector3(sx - 0.6, bh - 0.5, sz - 0.6)
	occ.occluder = ob; occ.position = b.position; add_child(occ)

	var face_x := cx - float(face_main_side) * (sx * 0.5 + 0.05)
	var win_rot := -90.0 if face_main_side == 1 else 90.0
	var wz := cz + sz * 0.5 - 4.0
	var idx := 0
	while wz > cz - sz * 0.5 + 3.0:
		_add_3d_window(Vector3(face_x, 3.0, wz), win_rot, (idx % 2 == 0))
		_add_3d_window(Vector3(face_x, 6.6, wz), win_rot, (idx % 2 == 1))
		if idx % 2 == 0:
			_spawn_kenney("urb_balcony-ladder-bottom.glb", Vector3(face_x - float(face_main_side) * 0.4, 0.2, wz - 2.0), win_rot, 2.2)
		wz -= 8.5; idx += 1

	for z_face in [cz - sz * 0.5 - 0.05, cz + sz * 0.5 + 0.05]:
		var zrot := 180.0 if z_face < cz else 0.0
		var wx := cx - sx * 0.5 + 6.0
		while wx < cx + sx * 0.5 - 5.0:
			_add_3d_window(Vector3(wx, 3.2, z_face), zrot, int(absf(wx)) % 2 == 0)
			wx += 10.0

	_spawn_kenney("comm_building-c.glb" if face_main_side < 0 else "comm_building-f.glb", Vector3(cx, 0.0, cz), 90.0 if face_main_side < 0 else -90.0, 4.8)

func _mount_neon_sign(tex_name: String, pos: Vector3, rot_y: float, col: Color, sz: Vector2 = Vector2(5.6, 1.8)) -> void:
	var path := "res://assets/textures/%s" % tex_name
	if not ResourceLoader.exists(path): return
	var sm := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = sz; sm.mesh = qm
	var mat := StandardMaterial3D.new(); var tex: Texture2D = load(path)
	mat.albedo_texture = tex; mat.emission_enabled = true; mat.emission_texture = tex; mat.emission_energy_multiplier = 2.2
	sm.material_override = mat; sm.position = pos; sm.rotation_degrees.y = rot_y; add_child(sm)
	var lgt := OmniLight3D.new()
	var fwd := Vector3(sin(deg_to_rad(rot_y)), 0.0, cos(deg_to_rad(rot_y)))
	lgt.position = pos + fwd * 1.6
	lgt.light_color = col; lgt.light_energy = 4.6; lgt.omni_range = 16.0
	_enable_fade(lgt); add_child(lgt)

func _build_city_blocks_and_neon() -> void:
	_build_block_quadrant(-32.5, -1.5, 40.0, 27.0, -1)
	_build_block_quadrant(32.5, -1.5, 40.0, 27.0, 1)
	_build_block_quadrant(-32.5, -63.0, 40.0, 20.0, -1)
	_build_block_quadrant(32.5, -63.0, 40.0, 20.0, 1)
	_build_block_quadrant(-32.5, -120.0, 40.0, 18.0, -1)
	_build_block_quadrant(32.5, -120.0, 40.0, 18.0, 1)

	_mount_neon_sign("neon_vapes.png", Vector3(12.4, 4.2, -3.0), -90.0, Color(0.28, 1.0, 0.55))
	_mount_neon_sign("neon_open.png", Vector3(12.4, 4.0, -11.0), -90.0, Color(1.0, 0.30, 0.16), Vector2(4.0, 1.8))
	_mount_neon_sign("sign_coffee.png", Vector3(-12.4, 4.3, -6.0), 90.0, Color(1.0, 0.68, 0.24))
	_mount_neon_sign("sign_thrift.png", Vector3(-12.4, 4.3, -63.0), 90.0, Color(0.28, 0.94, 1.0))
	_mount_neon_sign("sign_barber.png", Vector3(12.4, 4.3, -63.0), -90.0, Color(1.0, 0.30, 0.58))
	_mount_neon_sign("neon_club.png", Vector3(12.4, 4.4, -120.0), -90.0, Color(0.28, 0.80, 1.0))

	# Storefront Awnings & Physical Wall Sconces along blocks!
	_spawn_kenney("comm_detail-awning-wide.glb", Vector3(-12.2, 2.8, -6.0), 90.0, 2.5)
	_spawn_kenney("comm_detail-awning-wide.glb", Vector3(12.2, 2.8, -3.0), -90.0, 2.5)
	_add_wall_sconce(Vector3(-12.4, 3.2, 3.0), 90.0, Color(1.0, 0.72, 0.34))
	_add_wall_sconce(Vector3(12.4, 3.2, -57.0), -90.0, Color(1.0, 0.70, 0.32))
	_add_wall_sconce(Vector3(-12.4, 3.2, -68.0), 90.0, Color(0.30, 0.90, 1.0))

	# Iconic Burning Broken Storefront under OPEN sign!
	_add_fire_particles(Vector3(11.6, 1.4, -11.0))
	var open_f := OmniLight3D.new(); open_f.position = Vector3(10.5, 2.0, -11.0)
	open_f.light_color = Color(1.0, 0.44, 0.10); open_f.light_energy = 5.8; open_f.omni_range = 16.0
	_enable_fade(open_f); add_child(open_f); _fire_lights.append(open_f)

func _build_gas_365_plaza() -> void:
	# DENSELY PACKED GAS 365 STATION — Turn LEFT at Z = -34!
	var gx := -31.0; var gz := -34.0

	var pad := MeshInstance3D.new(); var pm := BoxMesh.new(); pm.size = Vector3(34.0, 0.14, 30.0)
	pad.mesh = pm; pad.material_override = _make_pbr_mat("sidewalk"); pad.position = Vector3(gx, 0.05, gz); add_child(pad)

	# Giant Glowing GAS 365 / 6.66$ Pylon RIGHT ON MAIN AVE CORNER
	var pole := MeshInstance3D.new(); var pom := CylinderMesh.new(); pom.top_radius = 0.25; pom.bottom_radius = 0.32; pom.height = 10.5
	pole.mesh = pom; pole.material_override = _make_photoreal_pbr("rust_metal", Color(0.32, 0.34, 0.38))
	pole.position = Vector3(-13.8, 5.25, -20.5); add_child(pole)
	if ResourceLoader.exists("res://assets/textures/neon_gas365.png"):
		var sign_m := MeshInstance3D.new(); var sqm := BoxMesh.new(); sqm.size = Vector3(3.0, 5.6, 0.42); sign_m.mesh = sqm
		var smat := StandardMaterial3D.new(); var gtex: Texture2D = load("res://assets/textures/neon_gas365.png")
		smat.albedo_texture = gtex; smat.emission_enabled = true; smat.emission_texture = gtex; smat.emission_energy_multiplier = 2.5
		sign_m.material_override = smat; sign_m.position = Vector3(-13.8, 7.6, -20.5); sign_m.rotation_degrees.y = 35.0; add_child(sign_m)
		var pl := OmniLight3D.new(); pl.position = Vector3(-12.2, 7.4, -20.5)
		pl.light_color = Color(1.0, 0.36, 0.22); pl.light_energy = 5.5; pl.omni_range = 18.0
		_enable_fade(pl); add_child(pl)

	# Canopy + Red Trim + 4 VISIBLE RECESSED FLUORESCENT CEILING LIGHT TUBES!
	var canopy := MeshInstance3D.new(); var cm := BoxMesh.new(); cm.size = Vector3(18.0, 0.9, 13.0)
	canopy.mesh = cm; canopy.material_override = _make_photoreal_pbr("rust_metal", Color(0.24, 0.26, 0.30))
	canopy.position = Vector3(gx + 2.0, 5.4, gz); add_child(canopy)

	var trim := MeshInstance3D.new(); var tm := BoxMesh.new(); tm.size = Vector3(18.3, 0.32, 13.3); trim.mesh = tm
	var tmat := StandardMaterial3D.new(); tmat.albedo_color = Color(0.95, 0.16, 0.14); tmat.emission_enabled = true; tmat.emission = Color(1.0, 0.20, 0.14); tmat.emission_energy_multiplier = 2.8
	trim.material_override = tmat; trim.position = Vector3(gx + 2.0, 5.8, gz); add_child(trim)

	var col_mat := _make_photoreal_pbr("grimy_concrete", Color(0.55, 0.56, 0.60))
	for px in [gx - 4.5, gx + 8.5]:
		for pz in [gz - 4.5, gz + 4.5]:
			var col := MeshInstance3D.new(); var clm := BoxMesh.new(); clm.size = Vector3(0.65, 5.4, 0.65)
			col.mesh = clm; col.material_override = col_mat; col.position = Vector3(px, 2.7, pz); add_child(col)
			_add_collider_box(Vector3(px, 2.0, pz), Vector3(0.75, 4.0, 0.75))

	var tube_mat := StandardMaterial3D.new(); tube_mat.albedo_color = Color(1, 1, 1); tube_mat.emission_enabled = true; tube_mat.emission = Color(0.84, 1.0, 0.96); tube_mat.emission_energy_multiplier = 6.5
	for lx in [gx - 2.0, gx + 6.0]:
		for lz in [gz - 2.5, gz + 2.5]:
			var tube := MeshInstance3D.new(); var tbm := BoxMesh.new(); tbm.size = Vector3(3.2, 0.10, 0.35)
			tube.mesh = tbm; tube.material_override = tube_mat; tube.position = Vector3(lx, 4.92, lz); add_child(tube)
		var fl := SpotLight3D.new(); fl.position = Vector3(lx, 4.85, gz); fl.rotation_degrees.x = -90.0
		fl.light_color = Color(0.84, 1.0, 0.96); fl.light_energy = 10.5; fl.spot_range = 24.0; fl.spot_angle = 72.0
		_enable_fade(fl, 34.0, 14.0); add_child(fl)

	# Concrete Pump Islands + 4 Chain-Exploding Fuel Pumps!
	for px in [gx - 1.5, gx + 5.5]:
		var isl := MeshInstance3D.new(); var im := BoxMesh.new(); im.size = Vector3(1.9, 0.24, 8.2)
		isl.mesh = im; isl.material_override = col_mat; isl.position = Vector3(px, 0.18, gz); add_child(isl)
		for pz in [gz - 2.4, gz + 2.4]:
			var pump := ExplodableCar.new(); pump.position = Vector3(px, 0.26, pz); add_child(pump)
			pump.setup("res://assets/models/kenney/surv_barrel.glb", explosion_system, false, 1.9, Vector3(1.1, 2.0, 1.1), 26.0, 11.0, false, Color(0.95, 0.16, 0.12))
			var pbox := MeshInstance3D.new(); var pbm := BoxMesh.new(); pbm.size = Vector3(0.9, 1.8, 0.7); pbox.mesh = pbm
			var pbmat := StandardMaterial3D.new(); pbmat.albedo_color = Color(0.95, 0.18, 0.14); pbmat.emission_enabled = true; pbmat.emission = Color(1.0, 0.25, 0.16); pbmat.emission_energy_multiplier = 1.6
			pbox.material_override = pbmat; pbox.position = Vector3(0, 0.95, 0); pump.add_child(pbox)

	# Convenience Store (Mart) + Awning + 3D Windows + Glowing Soda Vending Machine + Fuel Tank
	var mart := MeshInstance3D.new(); var mm := BoxMesh.new(); mm.size = Vector3(7.0, 5.4, 20.0)
	mart.mesh = mm; mart.material_override = _make_pbr_mat("brick"); mart.position = Vector3(-47.5, 2.7, gz); add_child(mart)
	_add_collider_box(Vector3(-47.5, 2.5, gz), Vector3(7.0, 5.0, 20.0))
	_mount_neon_sign("sign_gas365.png", Vector3(-43.8, 4.2, gz), 90.0, Color(0.32, 1.0, 0.48), Vector2(6.5, 2.0))
	_add_3d_window(Vector3(-43.9, 2.0, gz - 5.5), 90.0, true)
	_add_3d_window(Vector3(-43.9, 2.0, gz + 5.5), 90.0, true)
	_spawn_kenney("comm_detail-awning-wide.glb", Vector3(-43.5, 3.2, gz), 90.0, 2.8)
	_add_vending_machine(Vector3(-43.2, 0.12, gz + 8.5), 90.0, Color(0.24, 0.86, 1.0))
	_spawn_kenney("ind_detail-tank.glb", Vector3(-43.0, 0.14, gz - 13.0), 0.0, 4.0)

	# DENSE GAS STATION FORECOURT CLUTTER: 4 Queued Vehicles (with headlights!), Tires, Cones, Crates, Flares, Explosive Barrels!
	for cv in [
		[Vector3(gx + 2.0, 0, gz + 3.0), 12.0, "kenney/car_suv.glb", false, false, true],
		[Vector3(gx - 5.2, 0, gz - 2.0), -8.0, "kenney/car_sedan.glb", false, false, true],
		[Vector3(gx + 9.5, 0, gz - 9.5), 38.0, "kenney/car_taxi.glb", true, false, false],
		[Vector3(gx - 1.0, 0, gz - 12.0), 82.0, "kenney/car_van.glb", false, false, false],
	]:
		var ec := ExplodableCar.new(); ec.position = cv[0]; ec.rotation_degrees.y = float(cv[1]); add_child(ec)
		ec.setup("res://assets/models/%s" % cv[2], explosion_system, bool(cv[3]), 1.65, Vector3(2.05, 1.6, 4.6), 95.0, 7.6, true, Color.WHITE, bool(cv[4]), bool(cv[5]))

	for tp in [Vector3(-19.0, 0.12, -23.0), Vector3(-40.0, 0.12, -44.0), Vector3(-20.0, 0.12, -46.0)]:
		_spawn_kenney("car_debris-tire.glb", tp, tp.x * 11.0, 2.2)
		_spawn_kenney("car_cone.glb", tp + Vector3(1.5, 0, 0.8), 0.0, 2.0)
	_spawn_kenney("urb_detail-barrier-strong-damaged.glb", Vector3(-16.5, 0.0, -45.0), 25.0, 2.3)
	_spawn_kenney("urb_detail-dumpster-closed.glb", Vector3(-42.5, 0.12, -22.0), 0.0, 2.2)
	_spawn_kenney("surv_box-large.glb", Vector3(-41.5, 0.12, -42.0), 15.0, 2.0)
	_add_road_flare(Vector3(-17.5, 0.0, -34.0))
	_add_fire_particles(Vector3(gx - 6.0, 0.3, gz + 9.5))
	var gf := OmniLight3D.new(); gf.position = Vector3(gx - 6.0, 1.4, gz + 9.5); gf.light_color = Color(1.0, 0.44, 0.10); gf.light_energy = 5.2; gf.omni_range = 15.0
	_enable_fade(gf); add_child(gf); _fire_lights.append(gf)

func _build_neon_alley_courtyard() -> void:
	# DENSELY PACKED EAST TURN @ Z = -34: BAKERY & CLUB NEON COURTYARD!
	_mount_neon_sign("neon_bakery.png", Vector3(24.0, 4.4, -15.4), 180.0, Color(1.0, 0.88, 0.46), Vector2(6.4, 2.0))
	_mount_neon_sign("neon_club.png", Vector3(36.0, 4.6, -52.6), 0.0, Color(0.28, 0.84, 1.0), Vector2(5.6, 2.0))
	_spawn_kenney("comm_detail-awning-wide.glb", Vector3(24.0, 3.0, -15.6), 180.0, 2.8)
	_spawn_kenney("urb_detail-awning-wide.glb", Vector3(36.0, 3.0, -52.4), 0.0, 2.8)

	# Grounded Physical Wall Sconces + Vending Machines + Street Trees (NO floating tree lights!)
	_add_wall_sconce(Vector3(18.0, 3.4, -15.4), 180.0, Color(1.0, 0.72, 0.32))
	_add_wall_sconce(Vector3(44.0, 3.4, -52.6), 0.0, Color(0.32, 0.88, 1.0))
	_add_vending_machine(Vector3(20.0, 0.0, -16.5), 180.0, Color(1.0, 0.32, 0.55))
	_add_vending_machine(Vector3(46.0, 0.0, -40.0), -90.0, Color(0.28, 1.0, 0.52))
	_spawn_kenney("urb_tree-large.glb", Vector3(21.0, 0.0, -23.0), 42.0, 2.7)
	_spawn_kenney("urb_tree-park-large.glb", Vector3(39.0, 0.0, -45.0), 110.0, 2.7)

	# Strobing Police Cruiser + Abandoned Sports Car + Overturned Delivery Truck + Spilled Crates!
	var cop := ExplodableCar.new(); cop.position = Vector3(27.0, 0.0, -33.0); cop.rotation_degrees.y = -62.0
	add_child(cop); cop.setup("res://assets/models/kenney/car_police.glb", explosion_system, false, 1.65, Vector3(2.05, 1.6, 4.6), 95.0, 7.6, true, Color.WHITE, true, true)
	var spc := ExplodableCar.new(); spc.position = Vector3(38.0, 0.0, -25.0); spc.rotation_degrees.y = 140.0
	add_child(spc); spc.setup("res://assets/models/kenney/car_sedan-sports.glb", explosion_system, false, 1.65, Vector3(2.05, 1.6, 4.6), 85.0, 7.4, true, Color(0.82, 0.14, 0.12), false, true)
	var dlv := ExplodableCar.new(); dlv.position = Vector3(19.0, 0.0, -43.0); dlv.rotation_degrees.y = 28.0
	add_child(dlv); dlv.setup("res://assets/models/kenney/car_delivery.glb", explosion_system, true, 1.6)

	# Cafe Benches, Barricade Lanes, Spilled Crates/Pallets, Road Flares & Burning Dumpster!
	for bp in [[26.0, -18.0, 180.0], [32.0, -18.0, 180.0], [32.0, -49.0, 0.0]]:
		_spawn_kenney("urb_detail-bench.glb", Vector3(bp[0], 0.0, bp[1]), bp[2], 2.2)
	for cp in [Vector3(22.0, 0, -40.0), Vector3(23.5, 0, -38.5), Vector3(34.0, 0, -36.0), Vector3(44.0, 0, -34.0)]:
		_spawn_kenney("surv_box.glb", cp, cp.x * 13.0, 1.8)
	_spawn_kenney("urb_pallet.glb", Vector3(24.0, 0.0, -42.5), 22.0, 2.0)
	_spawn_kenney("urb_detail-barrier-type-a.glb", Vector3(16.0, 0.0, -28.0), 75.0, 2.2)
	_spawn_kenney("urb_detail-barrier-strong-damaged.glb", Vector3(42.0, 0.0, -38.0), -20.0, 2.2)
	_add_road_flare(Vector3(17.5, 0.0, -34.0))
	_add_road_flare(Vector3(34.0, 0.0, -41.0))

	_spawn_kenney("urb_detail-dumpster-open.glb", Vector3(44.5, 0.0, -26.0), -90.0, 2.3)
	_add_fire_particles(Vector3(44.5, 1.2, -26.0))
	var df := OmniLight3D.new(); df.position = Vector3(44.5, 1.8, -26.0); df.light_color = Color(1.0, 0.44, 0.10); df.light_energy = 5.2; df.omni_range = 15.0
	_enable_fade(df); add_child(df); _fire_lights.append(df)

	for rbp in [Vector3(24.0, 0.0, -39.0), Vector3(39.0, 0.0, -33.0), Vector3(31.0, 0.0, -24.0)]:
		var rb := ExplodableCar.new(); rb.position = rbp; add_child(rb)
		rb.setup("res://assets/models/kenney/surv_barrel.glb", explosion_system, false, 1.85, Vector3(0.95, 1.35, 0.95), 22.0, 7.6, false, Color(0.96, 0.14, 0.12))

func _build_subway_floodlight_lot() -> void:
	# DENSE MILITARY QUARANTINE CHECKPOINT + SUBWAY FLOODLIGHT LOT @ Z = -92 WEST!
	var sx := -31.0; var sz := -92.0

	# Twin Tall Stadium Floodlight Towers with VISIBLE glowing 4-lamp heads!
	for fp in [Vector3(-17.0, 0.0, -78.0), Vector3(-45.0, 0.0, -106.0)]:
		var pole := MeshInstance3D.new(); var pm := CylinderMesh.new(); pm.top_radius = 0.18; pm.bottom_radius = 0.24; pm.height = 11.0
		pole.mesh = pm; pole.material_override = _make_photoreal_pbr("rust_metal", Color(0.28, 0.30, 0.34))
		pole.position = fp + Vector3(0, 5.5, 0); add_child(pole)
		var head := MeshInstance3D.new(); var hm := BoxMesh.new(); hm.size = Vector3(2.4, 1.4, 0.38); head.mesh = hm
		var hmat := StandardMaterial3D.new(); hmat.albedo_color = Color(1, 1, 1); hmat.emission_enabled = true; hmat.emission = Color(0.94, 0.98, 1.0); hmat.emission_energy_multiplier = 6.5
		head.material_override = hmat; head.position = fp + Vector3(0, 10.6, 0); add_child(head)
		var sl := SpotLight3D.new(); sl.position = fp + Vector3(0, 10.2, 0)
		sl.look_at_from_position(sl.position, Vector3(sx, 0.0, sz), Vector3.UP)
		sl.light_color = Color(0.94, 0.98, 1.0); sl.light_energy = 14.0; sl.spot_range = 42.0; sl.spot_angle = 62.0
		_enable_fade(sl, 36.0, 14.0); add_child(sl)

	# Sunken Subway Entrance + Twin Physical Globe Streetlamps!
	var sub_l := MeshInstance3D.new(); var sm := BoxMesh.new(); sm.size = Vector3(8.5, 1.2, 0.35)
	sub_l.mesh = sm; sub_l.material_override = _make_photoreal_pbr("grimy_concrete", Color(0.55, 0.57, 0.60))
	sub_l.position = Vector3(sx - 4.0, 0.6, sz - 2.6); add_child(sub_l)
	var sub_r := sub_l.duplicate(); sub_r.position = Vector3(sx - 4.0, 0.6, sz + 2.6); add_child(sub_r)
	for gz in [sz - 2.6, sz + 2.6]:
		var post := MeshInstance3D.new(); var pcm := CylinderMesh.new(); pcm.top_radius = 0.06; pcm.bottom_radius = 0.08; pcm.height = 2.0
		post.mesh = pcm; post.material_override = _make_photoreal_pbr("rust_metal", Color(0.24, 0.26, 0.30))
		post.position = Vector3(sx, 1.1, gz); add_child(post)
		var globe := MeshInstance3D.new(); var gm := SphereMesh.new(); gm.radius = 0.28; gm.height = 0.56; globe.mesh = gm
		var gmat := StandardMaterial3D.new(); gmat.albedo_color = Color(0.88, 1.0, 0.92); gmat.emission_enabled = true; gmat.emission = Color(0.75, 1.0, 0.88); gmat.emission_energy_multiplier = 5.0
		globe.material_override = gmat; globe.position = Vector3(sx, 2.25, gz); add_child(globe)

	# Military Quarantine Checkpoint: Fortified Fences, Strobing Ambulance + Police Car, Crate Stacks, Flares!
	var amb := ExplodableCar.new(); amb.position = Vector3(-22.0, 0.0, -84.0); amb.rotation_degrees.y = -32.0
	add_child(amb); amb.setup("res://assets/models/kenney/car_ambulance.glb", explosion_system, false, 1.6, Vector3(2.1, 1.8, 4.8), 105.0, 7.8, true, Color.WHITE, true, true)
	var cop := ExplodableCar.new(); cop.position = Vector3(-38.0, 0.0, -82.0); cop.rotation_degrees.y = 55.0
	add_child(cop); cop.setup("res://assets/models/kenney/car_police.glb", explosion_system, false, 1.65, Vector3(2.05, 1.6, 4.6), 95.0, 7.6, true, Color.WHITE, true, false)
	var trk := ExplodableCar.new(); trk.position = Vector3(-24.0, 0.0, -101.0); trk.rotation_degrees.y = 40.0
	add_child(trk); trk.setup("res://assets/models/kenney/car_delivery.glb", explosion_system, true, 1.6)

	for fpos in [[Vector3(-18.0, 0, -96.0), 10.0], [Vector3(-28.0, 0, -106.0), 0.0], [Vector3(-42.0, 0, -98.0), 90.0], [Vector3(-47.0, 0, -86.0), 90.0]]:
		_spawn_kenney("surv_fence-fortified.glb", fpos[0], fpos[1], 2.6)
	for bp in [Vector3(-20.0, 0, -91.0), Vector3(-35.0, 0, -102.0), Vector3(-41.0, 0, -88.0)]:
		_spawn_kenney("surv_box-large.glb", bp, bp.x * 9.0, 2.2)
		_add_collider_box(bp + Vector3(0, 1.0, 0), Vector3(1.8, 2.0, 1.8))
	_add_road_flare(Vector3(-17.0, 0.0, -92.0))
	_add_road_flare(Vector3(-34.0, 0.0, -86.0))
	for rbp in [Vector3(-26.0, 0, -90.0), Vector3(-37.0, 0, -96.0)]:
		var rb := ExplodableCar.new(); rb.position = rbp; add_child(rb)
		rb.setup("res://assets/models/kenney/surv_barrel.glb", explosion_system, false, 1.85, Vector3(0.95, 1.35, 0.95), 22.0, 7.8, false, Color(0.96, 0.14, 0.12))

func _build_industrial_cargo_yard() -> void:
	# DENSE MULTI-LANE INDUSTRIAL CARGO MAZE @ Z = -92 EAST!
	_spawn_kenney("ind_detail-tank.glb", Vector3(43.0, 0.0, -80.0), 0.0, 4.2)
	_spawn_kenney("ind_chimney-medium.glb", Vector3(44.0, 0.0, -104.0), 0.0, 3.8)
	_spawn_kenney("urb_scaffolding-structure.glb", Vector3(22.0, 0.0, -78.0), 0.0, 2.5)
	_add_wall_sconce(Vector3(24.0, 3.6, -73.4), 180.0, Color(1.0, 0.65, 0.24))
	_add_wall_sconce(Vector3(38.0, 3.6, -110.6), 0.0, Color(1.0, 0.65, 0.24))

	# Parked Burning Firetruck + Garbage Truck + Cargo Van!
	var ft := ExplodableCar.new(); ft.position = Vector3(30.0, 0.0, -92.0); ft.rotation_degrees.y = -115.0
	add_child(ft); ft.setup("res://assets/models/kenney/car_firetruck.glb", explosion_system, true, 1.55)
	var gt := ExplodableCar.new(); gt.position = Vector3(20.0, 0.0, -102.0); gt.rotation_degrees.y = 32.0
	add_child(gt); gt.setup("res://assets/models/kenney/car_garbage-truck.glb", explosion_system, false, 1.55, Vector3(2.2, 2.0, 5.2), 120.0, 8.2, true, Color(0.24, 0.42, 0.26), false, true)
	var vn := ExplodableCar.new(); vn.position = Vector3(38.0, 0.0, -83.0); vn.rotation_degrees.y = -48.0
	add_child(vn); vn.setup("res://assets/models/kenney/car_van.glb", explosion_system, false, 1.65)

	# Shipping Crate Tactical Lanes + Explosive Barrel Chains!
	for cp in [Vector3(19.0, 0, -86.0), Vector3(28.0, 0, -82.0), Vector3(36.0, 0, -99.0), Vector3(44.0, 0, -92.0)]:
		_spawn_kenney("surv_box-large.glb", cp, cp.z * 5.0, 2.3)
		_add_collider_box(cp + Vector3(0, 1.0, 0), Vector3(1.9, 2.0, 1.9))
	for pp in [Vector3(24.0, 0, -94.0), Vector3(33.0, 0, -86.0), Vector3(30.0, 0, -104.0)]:
		_spawn_kenney("urb_pallet.glb", pp, pp.x * 9.0, 2.1)
		_spawn_kenney("surv_box.glb", pp + Vector3(0.4, 0.35, 0.2), 20.0, 1.6)
	_add_road_flare(Vector3(17.5, 0.0, -92.0))
	for rbp in [Vector3(22.0, 0.0, -95.0), Vector3(35.0, 0.0, -88.0), Vector3(33.0, 0.0, -98.0), Vector3(26.0, 0.0, -87.0)]:
		var rb := ExplodableCar.new(); rb.position = rbp; add_child(rb)
		rb.setup("res://assets/models/kenney/surv_barrel.glb", explosion_system, false, 1.85, Vector3(0.95, 1.35, 0.95), 22.0, 8.0, false, Color(0.96, 0.14, 0.12))

	_add_fire_particles(Vector3(40.0, 0.4, -95.0))
	var fl := OmniLight3D.new(); fl.position = Vector3(40.0, 1.8, -95.0); fl.light_color = Color(1.0, 0.44, 0.10); fl.light_energy = 5.8; fl.omni_range = 17.0
	_enable_fade(fl); add_child(fl); _fire_lights.append(fl)

func _build_main_avenue_props() -> void:
	var lamp_sc: PackedScene = load("res://assets/models/streetlamp.glb") if ResourceLoader.exists("res://assets/models/streetlamp.glb") else null
	var barrel_sc: PackedScene = load("res://assets/models/barrel_fire.glb") if ResourceLoader.exists("res://assets/models/barrel_fire.glb") else null

	# Grounded Streetlamps WITH visible glowing lamp bulbs!
	var idx := 0
	for lz in [-2.0, -20.0, -48.0, -64.0, -80.0, -108.0, -124.0]:
		var side := -1 if (idx % 2 == 0) else 1
		var col := Color(1.0, 0.72, 0.36) if (idx % 3 != 2) else Color(0.32, 0.90, 1.0)
		_add_streetlamp_with_bulb(Vector3(float(side) * 8.6, 0.14, lz), 90.0 if side == -1 else -90.0, col, lamp_sc)
		idx += 1

	# Real thin 3D overhead power cables spanning cleanly between street poles!
	var wire_mat := StandardMaterial3D.new(); wire_mat.albedo_color = Color(0.05, 0.05, 0.06); wire_mat.roughness = 0.8
	for cz in [-12.0, -48.0, -80.0, -120.0]:
		var w := MeshInstance3D.new(); var cm := CylinderMesh.new()
		cm.top_radius = 0.025; cm.bottom_radius = 0.025; cm.height = 24.0
		w.mesh = cm; w.material_override = wire_mat
		w.position = Vector3(0.0, 7.2, cz); w.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		add_child(w)
	for tz in [-22.0, -46.0, -80.0, -104.0]:
		_spawn_kenney("urb_detail-light-traffic.glb", Vector3(9.4, 0.0, tz), -90.0, 2.8)

	# Burning Barrels (real visible flame source!)
	for bp in [Vector3(-4.6, 0, 5.0), Vector3(6.8, 0, -12.0), Vector3(-6.8, 0, -62.0), Vector3(6.8, 0, -118.0), Vector3(-7.0, 0, -138.0), Vector3(7.0, 0, -138.0)]:
		if barrel_sc:
			var b: Node3D = barrel_sc.instantiate(); b.position = bp; add_child(b)
		var fl := OmniLight3D.new(); fl.position = bp + Vector3(0, 1.4, 0)
		fl.light_color = Color(1.0, 0.46, 0.10); fl.light_energy = 4.8; fl.omni_range = 14.0
		_enable_fade(fl); add_child(fl); _fire_lights.append(fl)
		_add_fire_particles(bp + Vector3(0, 0.95, 0))

	# Main Avenue Vehicles with visible Headlights & Strobing Emergency Lightbars!
	var cars := [
		{"pos": Vector3(-4.2, 0, -8.0), "yaw": 14.0, "model": "kenney/car_sedan.glb", "burn": false, "cop": false, "hl": true},
		{"pos": Vector3(4.5, 0, -18.0), "yaw": -162.0, "model": "kenney/car_taxi.glb", "burn": true, "cop": false, "hl": false},
		{"pos": Vector3(-3.8, 0, -62.0), "yaw": 18.0, "model": "kenney/car_police.glb", "burn": false, "cop": true, "hl": true},
		{"pos": Vector3(4.4, 0, -120.0), "yaw": -22.0, "model": "kenney/car_ambulance.glb", "burn": false, "cop": true, "hl": true},
	]
	for c in cars:
		var ec := ExplodableCar.new(); ec.position = c["pos"]; ec.rotation_degrees.y = float(c["yaw"])
		add_child(ec)
		ec.setup("res://assets/models/%s" % c["model"], explosion_system, bool(c["burn"]), 1.65, Vector3(2.05, 1.6, 4.6), 95.0, 7.6, true, Color.WHITE, bool(c["cop"]), bool(c["hl"]))

	# Dense Main Avenue Clutter: Vending Machines, Benches, Cones, Flares, Barricades, Explosive Barrels!
	_add_vending_machine(Vector3(-11.2, 0.14, 1.0), 90.0, Color(0.24, 0.88, 1.0))
	_add_vending_machine(Vector3(11.2, 0.14, -68.0), -90.0, Color(1.0, 0.40, 0.22))
	_add_road_flare(Vector3(-1.5, 0.0, -28.0))
	_add_road_flare(Vector3(2.0, 0.0, -86.0))
	for sz in [-6.0, -58.0, -116.0]:
		_spawn_kenney("urb_pallet.glb", Vector3(9.4, 0.14, sz), 18.0, 1.8)
		_spawn_kenney("urb_detail-bench.glb", Vector3(-10.2, 0.14, sz - 4.0), 90.0, 2.0)
		_spawn_kenney("car_cone.glb", Vector3(-7.6, 0.0, sz - 2.0), 0.0, 2.0)
		_spawn_kenney("urb_detail-barrier-strong-damaged.glb", Vector3(6.2, 0.0, sz - 5.0), -14.0, 2.1)

	for rbp in [Vector3(2.8, 0, -14.0), Vector3(-2.6, 0, -34.0), Vector3(3.2, 0, -66.0), Vector3(-2.8, 0, -96.0), Vector3(-9.0, 0, -142.0), Vector3(9.0, 0, -142.0)]:
		var rb := ExplodableCar.new(); rb.position = rbp; add_child(rb)
		rb.setup("res://assets/models/kenney/surv_barrel.glb", explosion_system, false, 1.85, Vector3(0.95, 1.35, 0.95), 22.0, 7.6, false, Color(0.96, 0.14, 0.12))

func _add_fire_particles(pos: Vector3) -> void:
	var f := UIStyle.create_fire_3d_effect(1.15); f.position = pos; add_child(f)

func _build_highrise_extraction() -> void:
	# FORTIFIED EVACUATION PERIMETER AT HIGH-RISE PLAZA!
	var tower := MeshInstance3D.new(); var tm := BoxMesh.new(); tm.size = Vector3(44.0, 36.0, 10.0)
	tower.mesh = tm; tower.material_override = _make_pbr_mat("brick"); tower.position = Vector3(0, 18.0, -174.0); add_child(tower)
	_mount_neon_sign("sign_highrise.png", Vector3(0, 11.5, -168.6), 0.0, Color(0.28, 0.96, 1.0), Vector2(14.0, 4.2))

	var ring := MeshInstance3D.new(); var cyl := CylinderMesh.new(); cyl.top_radius = 4.6; cyl.bottom_radius = 4.8; cyl.height = 0.08
	ring.mesh = cyl
	extraction_ring_mat = StandardMaterial3D.new(); extraction_ring_mat.albedo_color = Color(1.0, 0.35, 0.12)
	extraction_ring_mat.emission_enabled = true; extraction_ring_mat.emission = Color(1.0, 0.35, 0.12); extraction_ring_mat.emission_energy_multiplier = 2.5
	ring.material_override = extraction_ring_mat; ring.position = extraction_pad_pos + Vector3(0, 0.04, 0); add_child(ring)

	extraction_light = OmniLight3D.new(); extraction_light.position = extraction_pad_pos + Vector3(0, 3.6, 0); extraction_light.omni_range = 22.0
	_enable_fade(extraction_light, 38.0, 14.0); add_child(extraction_light)

	# 2 Visible Searchlight Towers on High-Rise Ledge + Fortified Perimeter Barricades & Evac Vehicles!
	for sx in [-14.0, 14.0]:
		var head := MeshInstance3D.new(); var hm := BoxMesh.new(); hm.size = Vector3(1.8, 1.0, 0.6); head.mesh = hm
		var hmat := StandardMaterial3D.new(); hmat.albedo_color = Color(1, 1, 1); hmat.emission_enabled = true; hmat.emission = Color(0.82, 0.96, 1.0); hmat.emission_energy_multiplier = 6.0
		head.material_override = hmat; head.position = Vector3(sx, 13.0, -168.5); add_child(head)

	_searchlight_l = SpotLight3D.new(); _searchlight_l.position = Vector3(-14.0, 13.0, -167.5); _searchlight_l.rotation_degrees = Vector3(-42.0, -20.0, 0.0)
	_searchlight_l.light_color = Color(0.75, 0.94, 1.0); _searchlight_l.light_energy = 11.0; _searchlight_l.spot_range = 44.0; _searchlight_l.spot_angle = 26.0
	_enable_fade(_searchlight_l, 42.0, 14.0); add_child(_searchlight_l)
	_searchlight_r = SpotLight3D.new(); _searchlight_r.position = Vector3(14.0, 13.0, -167.5); _searchlight_r.rotation_degrees = Vector3(-42.0, 20.0, 0.0)
	_searchlight_r.light_color = Color(0.75, 0.94, 1.0); _searchlight_r.light_energy = 11.0; _searchlight_r.spot_range = 44.0; _searchlight_r.spot_angle = 26.0
	_enable_fade(_searchlight_r, 42.0, 14.0); add_child(_searchlight_r)

	# Evac Defense Perimeter: Police Cruisers, Military Fences, Crate Cover, Flares & Barrel Traps!
	var p1 := ExplodableCar.new(); p1.position = Vector3(-14.0, 0, -142.0); p1.rotation_degrees.y = 36.0; add_child(p1)
	p1.setup("res://assets/models/kenney/car_police.glb", explosion_system, false, 1.65, Vector3(2.05, 1.6, 4.6), 95.0, 7.6, true, Color.WHITE, true, true)
	var p2 := ExplodableCar.new(); p2.position = Vector3(15.0, 0, -146.0); p2.rotation_degrees.y = -42.0; add_child(p2)
	p2.setup("res://assets/models/kenney/car_delivery.glb", explosion_system, true, 1.6)
	for bp in [Vector3(-12.0, 0, -154.0), Vector3(12.0, 0, -154.0), Vector3(-18.0, 0, -138.0), Vector3(18.0, 0, -138.0)]:
		_spawn_kenney("surv_fence-fortified.glb", bp, 0.0, 2.5)
		_spawn_kenney("surv_box-large.glb", bp + Vector3(0, 0, -3.5), 15.0, 2.0)
	_add_road_flare(Vector3(-6.0, 0, -148.0)); _add_road_flare(Vector3(6.0, 0, -148.0))

func _build_reflection_probes() -> void:
	for pos in [Vector3(0, 5, -34), Vector3(0, 5, -110)]:
		var rp := ReflectionProbe.new(); rp.position = pos; rp.size = Vector3(105, 22, 90)
		rp.update_mode = ReflectionProbe.UPDATE_ONCE; rp.intensity = 0.78; add_child(rp)

func _spawn_campaign_gears() -> void:
	var gear_sc: PackedScene = load("res://assets/models/pickup_gear.glb") if ResourceLoader.exists("res://assets/models/pickup_gear.glb") else null
	var locs := [
		Vector3(5.5, 0.65, -14.0), Vector3(-32.0, 0.65, -34.0), Vector3(32.0, 0.65, -34.0),
		Vector3(-32.0, 0.65, -92.0), Vector3(32.0, 0.65, -92.0), Vector3(0.0, 0.65, -132.0),
	]
	for p in locs:
		var root := Node3D.new(); root.position = p
		if gear_sc:
			var g: Node3D = gear_sc.instantiate(); g.scale = Vector3.ONE * 1.45; root.add_child(g)
		root.add_child(_make_pickup_pin(Color(0.24, 0.96, 1.0)))
		var lgt := OmniLight3D.new(); lgt.light_color = Color(0.24, 0.96, 1.0); lgt.light_energy = 3.2; lgt.omni_range = 8.0
		_enable_fade(lgt, 24.0, 10.0); root.add_child(lgt)
		add_child(root); gear_nodes.append(root)

func _make_pickup_pin(col: Color) -> Node3D:
	var pin := Node3D.new()
	var stem := MeshInstance3D.new(); var sm := CylinderMesh.new(); sm.top_radius = 0.03; sm.bottom_radius = 0.01; sm.height = 1.8; stem.mesh = sm
	var mat := StandardMaterial3D.new(); mat.albedo_color = col; mat.emission_enabled = true; mat.emission = col; mat.emission_energy_multiplier = 3.6; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stem.material_override = mat; stem.position = Vector3(0, 1.3, 0); pin.add_child(stem)
	var head := MeshInstance3D.new(); var hm := SphereMesh.new(); hm.radius = 0.24; hm.height = 0.48
	head.mesh = hm; head.material_override = mat; head.position = Vector3(0, 2.25, 0); pin.add_child(head)
	return pin

func _spawn_weapon_crates_and_medkits() -> void:
	# 5 Street Weapon Crates (all 7 weapons accessible!)
	var crates := [
		{"pos": Vector3(5.6, 0.16, -22.0), "wid": "smg"},
		{"pos": Vector3(-22.0, 0.16, -26.0), "wid": "autoshotgun"},
		{"pos": Vector3(24.0, 0.16, -40.0), "wid": "rifle"},
		{"pos": Vector3(-24.0, 0.16, -84.0), "wid": "flamethrower"},
		{"pos": Vector3(36.0, 0.16, -94.0), "wid": "hmg"},
	]
	for c in crates:
		var root := Node3D.new(); root.position = c["pos"]
		var chest := _spawn_kenney("surv_chest.glb", Vector3.ZERO, 0.0, 1.9)
		if chest: chest.get_parent().remove_child(chest); root.add_child(chest)
		root.add_child(_make_pickup_pin(Color(1.0, 0.80, 0.18)))
		var lgt := OmniLight3D.new(); lgt.position = Vector3(0, 1.0, 0); lgt.light_color = Color(1.0, 0.80, 0.18); lgt.light_energy = 2.8; lgt.omni_range = 7.0
		_enable_fade(lgt, 24.0, 10.0); root.add_child(lgt)
		add_child(root); weapon_crates.append({"node": root, "weapon_id": c["wid"]})

	# 2 Deployable Automated Sentry Turret Kits (GAS 365 + High-Rise Plaza!)
	for tp in [Vector3(-26.0, 0.16, -44.0), Vector3(-6.0, 0.16, -142.0)]:
		var root := Node3D.new(); root.position = tp
		var bx := _spawn_kenney("surv_box.glb", Vector3.ZERO, 0.0, 1.8)
		if bx: bx.get_parent().remove_child(bx); root.add_child(bx)
		root.add_child(_make_pickup_pin(Color(1.0, 0.45, 0.08)))
		var lgt := OmniLight3D.new(); lgt.position = Vector3(0, 1.0, 0); lgt.light_color = Color(1.0, 0.45, 0.08); lgt.light_energy = 3.0; lgt.omni_range = 7.5
		_enable_fade(lgt, 24.0, 10.0); root.add_child(lgt)
		add_child(root); turret_kits.append(root)

	var mk_scene: PackedScene = load("res://assets/models/pickup_medkit.glb") if ResourceLoader.exists("res://assets/models/pickup_medkit.glb") else null
	for mp in [Vector3(-34.0, 0.4, -26.0), Vector3(34.0, 0.4, -28.0), Vector3(-34.0, 0.4, -84.0), Vector3(32.0, 0.4, -84.0)]:
		var root := Node3D.new(); root.position = mp
		if mk_scene:
			var m: Node3D = mk_scene.instantiate(); m.scale = Vector3.ONE * 1.45; root.add_child(m)
		root.add_child(_make_pickup_pin(Color(0.28, 1.0, 0.42)))
		add_child(root); world_medkits.append(root)

func _spawn_kenney(rel_name: String, pos: Vector3, yaw_deg: float = 0.0, sc: float = 1.0) -> Node3D:
	var path := "res://assets/models/kenney/%s" % rel_name
	if not ResourceLoader.exists(path): return null
	var n: Node3D = (load(path) as PackedScene).instantiate()
	n.position = pos; n.rotation_degrees.y = yaw_deg; n.scale = Vector3.ONE * sc
	var tint := Color(0.58, 0.56, 0.62); var mk := "rust_metal"
	if "building" in rel_name: mk = "urban_brick"; tint = Color(0.72, 0.62, 0.58)
	elif "barrier" in rel_name or "fence" in rel_name or "bench" in rel_name: mk = "grimy_concrete"; tint = Color(0.72, 0.74, 0.78)
	elif "tree" in rel_name: tint = Color(0.54, 0.20, 0.18)
	elif "dumpster" in rel_name: tint = Color(0.36, 0.58, 0.42)
	elif "cone" in rel_name: tint = Color(0.95, 0.38, 0.10)
	elif "chest" in rel_name: tint = Color(0.95, 0.76, 0.26)
	var mat := _make_photoreal_pbr(mk, tint, 0.38 if mk == "urban_brick" else 0.55, 0.76, 0.30 if mk == "rust_metal" else 0.06, 1.35)
	_apply_mat_rec(n, mat); add_child(n)
	return n

func _apply_mat_rec(n: Node, mat: Material) -> void:
	if n is MeshInstance3D: (n as MeshInstance3D).material_override = mat
	for c in n.get_children(): _apply_mat_rec(c, mat)

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r: return r
	return null
