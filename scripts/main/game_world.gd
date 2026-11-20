extends Node3D

const TouchControlsScript = preload("res://scripts/ui/touch_controls.gd")

var _env: Environment
var _cam: Camera3D
var _player: PlayerController
var _city: CityBuilder
var _decal_mgr: BloodDecalManager
var _exp_sys: ExplosionSystem
var _proj_sys: ProjectileSystem
var _horde_mgr: HordeManager
var _hud: GameHUD
var _rain: CPUParticles3D
var _vfx_juice: VFXJuice
var _postfx_mat: ShaderMaterial
var _ca_val: float = 0.0012
var _hurt_val: float = 0.0

var _intro_layer: CanvasLayer
var _intro_splash: Control
var _intro_label: Label
var _intro_t: float = 0.0
var _intro_stage: int = 0

func _ready() -> void:
	GameManager.start_new_run()
	_setup_environment()
	_setup_systems()
	SettingsManager.settings_changed.connect(func(): SettingsManager.apply_to_environment(_env))
	if SettingsManager.skip_intro or GameManager.mode == GameManager.GameMode.ENDLESS:
		_finish_intro_immediately()
	else:
		_start_cinematic_intro()

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.012, 0.016, 0.028)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.32, 0.36, 0.48)
	_env.ambient_light_energy = 1.20
	SettingsManager.apply_to_environment(_env)
	we.environment = _env
	add_child(we)

	# Cool Moonlight Rim Light (low energy so neon + fires + flashlight dominate!)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	moon.light_color = Color(0.32, 0.48, 0.72)
	moon.light_energy = 1.08
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 55.0
	add_child(moon)

func _setup_systems() -> void:
	_decal_mgr = BloodDecalManager.new()
	add_child(_decal_mgr)

	_vfx_juice = VFXJuice.new()
	add_child(_vfx_juice)

	_exp_sys = ExplosionSystem.new()
	_exp_sys.vfx_juice = _vfx_juice
	_exp_sys.decal_manager = _decal_mgr
	add_child(_exp_sys)

	_horde_mgr = HordeManager.new()
	_horde_mgr.decal_manager = _decal_mgr
	_horde_mgr.explosion_system = _exp_sys
	_horde_mgr.vfx_juice = _vfx_juice
	add_child(_horde_mgr)
	_exp_sys.horde_manager = _horde_mgr

	_city = CityBuilder.new()
	_city.explosion_system = _exp_sys
	_city.horde_manager = _horde_mgr
	add_child(_city)
	_city.build_city(GameManager.mode == GameManager.GameMode.ENDLESS)

	_proj_sys = ProjectileSystem.new()
	_proj_sys.horde_manager = _horde_mgr
	_proj_sys.explosion_system = _exp_sys
	_proj_sys.decal_manager = _decal_mgr
	add_child(_proj_sys)

	_cam = Camera3D.new()
	_cam.fov = 48.0
	_cam.far = 140.0
	add_child(_cam)

	_player = PlayerController.new()
	_player.position = Vector3(0, 0, 10.2)
	_player.projectile_system = _proj_sys
	_player.horde_manager = _horde_mgr
	_player.camera = _cam
	_player.vfx_juice = _vfx_juice
	_vfx_juice.player_ref = _player
	add_child(_player)

	_horde_mgr.player_ref = _player
	_exp_sys.player_ref = _player
	_proj_sys.player_ref = _player

	# Atmospheric Falling Rain / Ash Streaks tracking player
	_rain = CPUParticles3D.new()
	_rain.amount = 140
	_rain.lifetime = 0.9
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(18.0, 1.0, 18.0)
	_rain.direction = Vector3(0.08, -1.0, 0.04)
	_rain.spread = 3.0
	_rain.initial_velocity_min = 18.0
	_rain.initial_velocity_max = 24.0
	var rm := BoxMesh.new()
	rm.size = Vector3(0.012, 0.45, 0.012)
	var rmat := StandardMaterial3D.new()
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(0.55, 0.78, 0.95, 0.14)
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.material = rmat
	_rain.mesh = rm
	add_child(_rain)

	# UI Layers
	_hud = GameHUD.new()
	_hud.camera_ref = _cam
	_hud.city_ref = _city
	_hud.horde_ref = _horde_mgr
	add_child(_hud)
	_horde_mgr.damage_popup.connect(_hud.spawn_damage_popup)
	_city.world_alert.connect(func(t, s): _hud.show_banner(t, s, 2.2))
	_setup_postfx()

	var tc: CanvasLayer = TouchControlsScript.new()
	tc.player_ref = _player
	add_child(tc)
	add_child(PerkDraftModal.new())
	add_child(PauseAndSummaryUI.new())

func _start_cinematic_intro() -> void:
	GameManager.intro_playing = true
	AudioManager.start_music("explore")
	_hud.visible = false

	_intro_layer = CanvasLayer.new()
	_intro_layer.layer = 25
	add_child(_intro_layer)

	_intro_splash = Control.new()
	_intro_splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_layer.add_child(_intro_splash)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.03, 1.0)
	_intro_splash.add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	_intro_splash.add_child(vb)

	var pres := Label.new()
	pres.text = "PIX-TRO  //  MASH PANDA  //  MISFIRE"
	pres.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pres.add_theme_font_size_override("font_size", 22)
	pres.add_theme_color_override("font_color", Color(0.95, 0.72, 0.18))
	vb.add_child(pres)

	if ResourceLoader.exists("res://assets/ui/title_logo.png"):
		var lg := TextureRect.new()
		lg.texture = load("res://assets/ui/title_logo.png")
		lg.custom_minimum_size = Vector2(620, 320)
		lg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vb.add_child(lg)

	_intro_label = Label.new()
	_intro_label.text = "PRESS [SPACE / CLICK] TO SKIP INTRO"
	_intro_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_intro_label.offset_left = -330; _intro_label.offset_right = -20; _intro_label.offset_top = -42; _intro_label.offset_bottom = -16
	_intro_label.add_theme_font_size_override("font_size", 14)
	_intro_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	_intro_layer.add_child(_intro_label)

	# Side-view Alley Shot facing the Garage Shutter & Burning Barrel!
	_cam.global_position = Vector3(0.0, 2.3, 0.5)
	_cam.look_at(Vector3(0.0, 2.0, 9.5), Vector3.UP)
	_intro_t = 0.0
	_intro_stage = 0

	AudioManager.play_vo("vo_intro_1", "Anyone who hasn't been turned into a brain-munching freak down there should head to the High-Rise in the quarantine zone. Extraction procedures are now operational.", true)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.intro_playing:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("dash") or event.is_action_pressed("shoot") or event.is_action_pressed("pause"):
			_finish_intro_immediately()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _postfx_mat:
		_ca_val = lerpf(_ca_val, 0.0012, minf(1.0, delta * 8.0))
		_hurt_val = maxf(0.0, _hurt_val - delta * 1.9)
		var chaos_on := 1.0 if (GameManager.chaos_weapon_id != "" or not GameManager.active_chaos_buffs.is_empty()) else 0.0
		_postfx_mat.set_shader_parameter("ca_strength", _ca_val)
		_postfx_mat.set_shader_parameter("hurt_vignette", _hurt_val)
		_postfx_mat.set_shader_parameter("chaos_glow", chaos_on)
	if _rain and _player:
		_rain.global_position = _player.global_position + Vector3(0, 15.0, 0)
	if GameManager.intro_playing:
		_update_intro(delta)
	elif GameManager.run_active and _player:
		_city.check_world_triggers(_player.global_position)

func _update_intro(delta: float) -> void:
	_intro_t += delta
	if _intro_stage == 0:
		# Hold retro splash for 1.8s then fade into 3D alley
		if _intro_t >= 1.8:
			_intro_splash.modulate.a = maxf(0.0, 1.0 - (_intro_t - 1.8) * 1.6)
		if _intro_t >= 2.5:
			_intro_splash.visible = false
			_intro_stage = 1
			_intro_t = 0.0
			# Roll steel garage shutter open!
			AudioManager.play_sfx("shutter_open", 0.96, 1.04, 0.85)
			if _city.garage_shutter_anim:
				var list := _city.garage_shutter_anim.get_animation_list()
				if not list.is_empty():
					_city.garage_shutter_anim.play(list[0])
	elif _intro_stage == 1:
		# Survivor steps out of lit garage into rainy neon street
		if _intro_t > 0.7:
			_player.position = _player.position.move_toward(Vector3(0, 0, 5.5), delta * 3.0)
		if _intro_t >= 2.4:
			_intro_stage = 2
			_intro_t = 0.0
	elif _intro_stage == 2:
		# Smooth cinematic boom up into the 52 deg oblique gameplay camera!
		var p := clampf(_intro_t / 1.5, 0.0, 1.0)
		var ep := ease(p, -2.0)
		var start_p := Vector3(0.0, 2.3, 0.5)
		var end_p := _player.global_position + Vector3(0.0, 15.5, 11.8)
		_cam.global_position = start_p.lerp(end_p, ep)
		_cam.look_at(_player.global_position + Vector3(0, 0.8, 0), Vector3.UP)
		if p >= 1.0:
			_finish_intro_immediately()

func _finish_intro_immediately() -> void:
	GameManager.intro_playing = false
	if _intro_layer and is_instance_valid(_intro_layer):
		_intro_layer.queue_free()
	_player.position = Vector3(0, 0, 4.5)
	_cam.global_position = _player.global_position + Vector3(0.0, 15.5, 11.8)
	_cam.look_at(_player.global_position + Vector3(0, 0.8, 0), Vector3.UP)
	_hud.visible = true
	AudioManager.start_music("explore")

	# Spawn initial street zombies ahead so action starts immediately!
	for i in range(6):
		_horde_mgr.spawn_zombie("shambler", Vector3(randf_range(-5.5, 5.5), 0.0, -10.0 - float(i) * 2.5))
	_horde_mgr.spawn_zombie("spitter", Vector3(-3.5, 0.0, -28.0))
	_horde_mgr.spawn_zombie("spitter", Vector3(-26.0, 0.0, -34.0))
	_horde_mgr.spawn_zombie("bruiser", Vector3(-32.0, 0.0, -38.0))
	_horde_mgr.spawn_zombie("spitter", Vector3(28.0, 0.0, -34.0))
	_horde_mgr.spawn_zombie("spitter", Vector3(-28.0, 0.0, -92.0))

	if GameManager.mode == GameManager.GameMode.ESCAPE:
		_hud.show_banner("DAY 54", "COLLECT 6 GEARS & REACH THE HIGH-RISE BEFORE NUCLEAR STRIKE!", 4.5)
		AudioManager.play_vo("vo_intro_2", "See that timer ticking down? That's how long you have to find six gears and reach the High-Rise before the city gets a nuclear makeover. No pressure, I guess.", true)
	else:
		_hud.show_banner("ENDLESS OUTBREAK", "SURVIVE INFINITE WAVES & STACK PERK SYNERGIES!", 4.0)

func _setup_postfx() -> void:
	if not ResourceLoader.exists("res://assets/shaders/screen_postfx.gdshader"):
		return
	var pl := CanvasLayer.new()
	pl.layer = 4
	add_child(pl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_postfx_mat = ShaderMaterial.new()
	_postfx_mat.shader = load("res://assets/shaders/screen_postfx.gdshader")
	cr.material = _postfx_mat
	pl.add_child(cr)
	GameManager.postfx_kick.connect(func(amt): _ca_val = maxf(_ca_val, amt))
	GameManager.player_damaged.connect(func(_d): _hurt_val = 0.95)
