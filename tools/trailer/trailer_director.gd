extends Node
## STREET TRASH: DEZOMBIFIER — Official AAA Steam Launch Trailer Director
## Single-pass deterministic 60 FPS in-engine director (11 shots across 48.0s).

const GameWorldScene = preload("res://scenes/main/game_world.tscn")

var _gw: Node3D
var _t: float = 0.0
var _stage: int = -1
var _sub_cut: int = 0

var _cinematic_cam: bool = true
var _ai_enabled: bool = false
var _cam_from: Vector3 = Vector3.ZERO
var _cam_to: Vector3 = Vector3.ZERO
var _look_from: Vector3 = Vector3.ZERO
var _look_to: Vector3 = Vector3.ZERO
var _shot_t: float = 0.0
var _shot_dur: float = 1.0
var _cam_fov: float = 46.0
var _cam_roll: float = 0.0
var _handheld: float = 0.012
var _cam_attrs: CameraAttributesPractical

var _overlay: CanvasLayer
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _flash: ColorRect
var _caption_box: PanelContainer
var _caption_title: Label
var _caption_sub: Label
var _endcard: Control
var _end_bg: TextureRect
var _end_logo: TextureRect
var _end_sub: Label
var _end_feat: Label
var _end_plat: Label
var _perk_modal: PerkDraftModal = null

var _ai_dash_cd: float = 1.1
var _ai_strafe_sign: float = 1.0
var _ai_strafe_t: float = 0.0
var _ai_anchor: Vector3 = Vector3.ZERO
var _ai_anchor_r: float = 4.5
var _ai_kite_min: float = 5.2
var _ai_kite_max: float = 11.0
var _fired_events: Dictionary = {}
var _active_boss: Dictionary = {}
var _thriller_bloater: Dictionary = {}
var _cargo_bloaters: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.content_scale_factor = 1.5
	seed(20261120)
	SettingsManager.graphics_preset = 1 # Full Cinematic SSR + SSAO + ACES Bloom!
	SettingsManager.skip_intro = true
	SettingsManager.show_subtitles = true
	SettingsManager.screen_shake_scale = 1.0
	SettingsManager.master_volume = 0.92
	SettingsManager.music_volume = 0.68
	SettingsManager.sfx_volume = 0.92
	SettingsManager.vo_volume = 0.98
	GameManager.mode = GameManager.GameMode.ESCAPE
	GameManager.difficulty = GameManager.Difficulty.STANDARD
	GameManager.starting_trait = "gunslinger"

	_gw = GameWorldScene.instantiate()
	add_child(_gw)

	for c in _gw.get_children():
		if c is PerkDraftModal:
			_perk_modal = c
			break

	_cam_attrs = CameraAttributesPractical.new()
	_cam_attrs.dof_blur_far_enabled = false
	_cam_attrs.dof_blur_near_enabled = false
	_gw._cam.attributes = _cam_attrs
	_gw._cam.far = 260.0

	_build_cinema_overlay()
	_build_endcard()
	_enter_stage(0)

func _build_cinema_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 60
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.content_scale_factor = 1.5
	add_child(_overlay)

	_bar_top = ColorRect.new()
	_bar_top.color = Color(0.01, 0.01, 0.015, 0.96)
	_bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar_top.offset_bottom = 64
	_overlay.add_child(_bar_top)

	_bar_bot = ColorRect.new()
	_bar_bot.color = Color(0.01, 0.01, 0.015, 0.96)
	_bar_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_bot.offset_top = -64
	_overlay.add_child(_bar_bot)

	_caption_box = PanelContainer.new()
	_caption_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_caption_box.offset_left = 42
	_caption_box.offset_top = -148
	_caption_box.offset_right = 760
	_caption_box.offset_bottom = -74
	_caption_box.add_theme_stylebox_override("panel", UIStyle.make_panel_box(Color(1.0, 0.22, 0.14, 0.95), Color(0.03, 0.04, 0.07, 0.88), true))
	_overlay.add_child(_caption_box)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	_caption_box.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	m.add_child(vb)

	_caption_title = Label.new()
	UIStyle.style_label(_caption_title, 27, Color(1.0, 0.98, 0.95), true, 6)
	vb.add_child(_caption_title)

	_caption_sub = Label.new()
	UIStyle.style_label(_caption_sub, 14, Color(1.0, 0.72, 0.22), false, 3)
	vb.add_child(_caption_sub)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_flash)

func _build_endcard() -> void:
	_endcard = Control.new()
	_endcard.set_anchors_preset(Control.PRESET_FULL_RECT)
	_endcard.visible = false
	_overlay.add_child(_endcard)

	var blk := ColorRect.new()
	blk.set_anchors_preset(Control.PRESET_FULL_RECT)
	blk.color = Color(0.01, 0.01, 0.02, 1.0)
	_endcard.add_child(blk)

	_end_bg = TextureRect.new()
	_end_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_end_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/ui/title_splash.png"):
		_end_bg.texture = load("res://assets/ui/title_splash.png")
	_end_bg.modulate = Color(0.68, 0.68, 0.75, 1.0)
	_endcard.add_child(_end_bg)

	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://assets/shaders/menu_atmosphere.gdshader"):
		var sm := ShaderMaterial.new()
		sm.shader = load("res://assets/shaders/menu_atmosphere.gdshader")
		sm.set_shader_parameter("rain_intensity", 0.78)
		sm.set_shader_parameter("ember_intensity", 0.98)
		fx.material = sm
	_endcard.add_child(fx)

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0.01, 0.01, 0.025, 0.48)
	_endcard.add_child(dark)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_endcard.add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)

	_end_logo = TextureRect.new()
	_end_logo.custom_minimum_size = Vector2(720, 330)
	_end_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_end_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/ui/title_logo.png"):
		_end_logo.texture = load("res://assets/ui/title_logo.png")
	vb.add_child(_end_logo)

	_end_sub = Label.new()
	_end_sub.text = "6 GEARS.   18 MINUTES.   NO MERCY."
	_end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_end_sub, 34, Color(1.0, 0.22, 0.16), true, 7)
	vb.add_child(_end_sub)

	_end_feat = Label.new()
	_end_feat.text = "36 PERK SYNERGIES  •  7 WEAPONS  •  5 OPEN DISTRICTS  •  ESCAPE & ENDLESS MODES"
	_end_feat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_end_feat, 17, Color(1.0, 0.84, 0.30, 0.96), false, 4)
	vb.add_child(_end_feat)

	_end_plat = Label.new()
	_end_plat.text = "AVAILABLE NOW ON STEAM   //   LINUX  •  WINDOWS  •  ANDROID  •  WEB"
	_end_plat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_end_plat, 21, Color(0.94, 0.97, 1.0, 0.96), true, 5)
	vb.add_child(_end_plat)

func _set_bars(on: bool) -> void:
	_bar_top.visible = on
	_bar_bot.visible = on

func _set_caption(title: String, sub: String = "", accent: Color = Color(1.0, 0.22, 0.14, 0.95)) -> void:
	if title == "":
		_caption_box.visible = false
		return
	_caption_box.visible = true
	_caption_box.add_theme_stylebox_override("panel", UIStyle.make_panel_box(accent, Color(0.03, 0.04, 0.07, 0.88), true))
	_caption_title.text = title
	_caption_sub.text = sub
	_caption_sub.visible = sub != ""
	_caption_box.modulate.a = 0.0
	_caption_box.position.x = 12.0
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(_caption_box, "modulate:a", 1.0, 0.22)
	tw.tween_property(_caption_box, "position:x", 42.0, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _do_flash(col: Color = Color(1, 0.96, 0.9, 0.72), dur: float = 0.22) -> void:
	_flash.color = col
	GameManager.postfx_kick.emit(0.015)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_flash, "color:a", 0.0, dur)

func _set_dof(on: bool, far_dist: float = 28.0, far_trans: float = 18.0, amount: float = 0.065) -> void:
	if _cam_attrs == null:
		return
	_cam_attrs.dof_blur_far_enabled = on
	_cam_attrs.dof_blur_far_distance = far_dist
	_cam_attrs.dof_blur_far_transition = far_trans
	_cam_attrs.dof_blur_amount = amount

func _set_shot(cf: Vector3, ct: Vector3, lf: Vector3, lt: Vector3, dur: float, fov: float = 46.0, roll: float = 0.0, hh: float = 0.012) -> void:
	_cinematic_cam = true
	_gw._player.camera = null
	_cam_from = cf
	_cam_to = ct
	_look_from = lf
	_look_to = lt
	_shot_t = 0.0
	_shot_dur = dur
	_cam_fov = fov
	_cam_roll = roll
	_handheld = hh
	_gw._cam.fov = fov
	_gw._cam.global_position = cf
	_gw._cam.look_at(lf, Vector3.UP)

func _set_gameplay_cam(ppos: Vector3, aim_dir: Vector2 = Vector2(0, -1), cam_off: Vector3 = Vector3(0.0, 15.5, 11.8)) -> void:
	_cinematic_cam = false
	_set_dof(false)
	var pl: PlayerController = _gw._player
	pl._cam_offset = cam_off
	pl.global_position = ppos
	pl.velocity = Vector3.ZERO
	pl.touch_active = true
	pl.touch_aim = aim_dir
	pl._aim_dir = Vector3(aim_dir.x, 0.0, aim_dir.y).normalized()
	pl.camera = _gw._cam
	_gw._cam.fov = 48.0
	_gw._cam.rotation.z = 0.0
	_gw._cam.global_position = ppos + cam_off
	_gw._cam.look_at(ppos + Vector3(0, 0.8, 0), Vector3.UP)

func _clear_zombies() -> void:
	var hm: HordeManager = _gw._horde_mgr
	for z in hm._zombies:
		if is_instance_valid(z["node"]):
			(z["node"] as Node3D).queue_free()
	hm._zombies.clear()
	for ep in hm._enemy_projectiles:
		if is_instance_valid(ep["node"]):
			(ep["node"] as Node3D).queue_free()
	hm._enemy_projectiles.clear()

func _seed_blood(center: Vector3, count: int, spread: float) -> void:
	var dm: BloodDecalManager = _gw._decal_mgr
	if dm == null:
		return
	for _i in range(count):
		dm.spawn_blood(center + Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread, spread)), randf_range(1.4, 2.8))

func _spawn_pack(center: Vector3, kinds: Array, min_r: float, max_r: float, arc_from: float = 0.0, arc_to: float = TAU) -> void:
	var hm: HordeManager = _gw._horde_mgr
	for k in kinds:
		var ang := randf_range(arc_from, arc_to)
		var r := randf_range(min_r, max_r)
		hm.spawn_zombie(str(k), center + Vector3(cos(ang) * r, 0.0, sin(ang) * r))

func _spawn_box_horde(x0: float, x1: float, z0: float, z1: float, count: int, weights: Dictionary) -> void:
	var hm: HordeManager = _gw._horde_mgr
	var total := 0.0
	for k in weights.keys():
		total += float(weights[k])
	for _i in range(count):
		var r := randf() * total
		var pick := "shambler"
		for k in weights.keys():
			r -= float(weights[k])
			if r <= 0.0:
				pick = str(k)
				break
		hm.spawn_zombie(pick, Vector3(randf_range(x0, x1), 0.0, randf_range(z0, z1)))

func _detonate_nearest_car(pos: Vector3, max_r: float = 9.0) -> void:
	var best: ExplodableCar = null
	var best_d := max_r
	for c in _gw._city.get_children():
		if c is ExplodableCar and not c.exploded:
			var d := (c as Node3D).global_position.distance_to(pos)
			if d < best_d:
				best_d = d
				best = c
	if best != null:
		best._detonate()
	else:
		_gw._exp_sys.spawn_explosion(pos, 8.5, 220.0, true)

func _equip_weapon(wid: String, is_chaos: bool = false) -> void:
	GameManager.unlock_weapon(wid, not is_chaos)
	if is_chaos:
		GameManager.chaos_weapon_id = wid
		GameManager.chaos_weapon_timer = 30.0
		GameManager.weapon_changed.emit(wid, true)
		GameManager.chaos_buffs_updated.emit()
	else:
		GameManager.chaos_weapon_id = ""
		GameManager.chaos_weapon_timer = 0.0
		GameManager.weapon_changed.emit(wid, false)
		GameManager.chaos_buffs_updated.emit()

func _set_hud_stats(streak: int, score_val: int, gears_cnt: int, time_left: float, lvl: int) -> void:
	GameManager.kill_streak = streak
	GameManager.streak_timer = 4.2
	GameManager.streak_mult = minf(2.5, 1.0 + float(streak) * 0.01)
	GameManager.score = score_val
	GameManager.gears = gears_cnt
	GameManager.time_remaining = time_left
	GameManager.level = lvl
	GameManager.xp_to_next = 999999.0
	GameManager.xp = 640000.0
	GameManager.pending_level_ups = 0
	GameManager.stats_updated.emit()

func _once(key: String) -> bool:
	if _fired_events.has(key):
		return false
	_fired_events[key] = true
	return true

func _enter_stage(st: int) -> void:
	_stage = st
	_sub_cut = 0
	var pl: PlayerController = _gw._player
	var hm: HordeManager = _gw._horde_mgr
	var hud: GameHUD = _gw._hud
	var exp_sys: ExplosionSystem = _gw._exp_sys

	GameManager.max_hp = 260.0
	GameManager.hp = 260.0
	GameManager.stamina = 100.0
	GameManager.xp_to_next = 999999.0
	GameManager.pending_level_ups = 0
	Engine.time_scale = 1.0
	_gw._env.ambient_light_energy = 1.20
	pl._refresh_flashlight()

	match st:
		0: # 0.0s - 3.5s: COLD OPEN — Garage Shutter Rolls Open into Rainy Neon Street + Radio VO!
			_clear_zombies()
			hud.visible = false
			_set_bars(true)
			_set_dof(true, 34.0, 22.0, 0.06)
			_set_caption("DAY 54  //  QUARANTINE ZONE", "18 MINUTES BEFORE NUCLEAR SANITIZATION", Color(1.0, 0.68, 0.16, 0.95))
			AudioManager.start_music("explore")
			AudioManager.play_sfx("trailer_braam", 0.98, 1.02, 0.95)
			AudioManager.play_sfx("shutter_open", 0.96, 1.02, 0.90)
			AudioManager.play_vo("vo_intro_1", "Anyone who hasn't been turned into a brain-munching freak down there should head to the High-Rise in the quarantine zone.", true)
			var anim: AnimationPlayer = _gw._city.garage_shutter_anim
			if anim:
				var list: PackedStringArray = anim.get_animation_list()
				if not list.is_empty():
					anim.play(list[0])
			pl.global_position = Vector3(0.0, 0.0, 8.8)
			pl.touch_active = true
			pl.touch_move = Vector2(0.0, -0.45)
			pl.touch_aim = Vector2(0.0, -1.0)
			pl.touch_firing = false
			_ai_enabled = false
			_seed_blood(Vector3(0, 0, -12), 12, 6.0)
			_spawn_box_horde(-6.5, 6.5, -34.0, -11.0, 24, {"shambler": 5, "sprinter": 3, "spitter": 1, "bruiser": 1, "bloater": 1})
			_set_shot(Vector3(-2.6, 1.45, 2.2), Vector3(1.8, 2.6, -9.5), Vector3(0.0, 1.35, -14.0), Vector3(-0.8, 1.5, -28.0), 3.5, 45.0, 0.0, 0.012)
			_do_flash(Color(0, 0, 0, 1), 0.65)

		1: # 3.5s - 7.2s: THRILLER SECTION — Dark Alley Flashlight Ambush (Glowing Red Eyes in Volumetric Beam!)
			_clear_zombies()
			_do_flash(Color(0.05, 0.08, 0.12, 0.85), 0.25)
			AudioManager.play_sfx("trailer_heartbeat", 0.98, 1.02, 1.0)
			AudioManager.play_sfx("zombie_groan_1", 0.82, 0.95, 0.85)
			hud.visible = false
			_set_bars(true)
			_set_dof(true, 16.0, 11.0, 0.075)
			_set_caption("ALONE IN THE DARK", "HUNTED BY THOUSANDS OF MUTATED INFECTED", Color(1.0, 0.16, 0.16, 0.95))
			# Dim ambient light so the shadow-casting SpotLight3D flashlight & glowing zombie eyes pop dramatically!
			_gw._env.ambient_light_energy = 0.42
			if pl._flashlight:
				pl._flashlight.light_energy = 24.0
				pl._flashlight.spot_angle = 27.0
				pl._flashlight.spot_range = 34.0
			_equip_weapon("shotgun", false)
			pl.global_position = Vector3(15.5, 0.0, -34.0)
			pl.touch_active = true
			pl.touch_move = Vector2(-0.22, 0.0)
			pl.touch_aim = Vector2(1.0, -0.08)
			pl.touch_firing = false
			_ai_enabled = false
			_seed_blood(Vector3(23.0, 0, -34.0), 14, 5.5)
			# Wall of creeping red-eyed Sprinters, green-sac Acid Bloaters & horned Bull Chargers emerging from the dark alley!
			for zp in [
				["sprinter", Vector3(22.5, 0, -33.2)], ["sprinter", Vector3(23.4, 0, -35.1)],
				["bloater", Vector3(24.2, 0, -33.8)], ["charger", Vector3(25.5, 0, -32.4)],
				["spitter", Vector3(24.8, 0, -35.8)], ["sprinter", Vector3(26.0, 0, -34.2)],
				["bruiser", Vector3(27.2, 0, -33.0)], ["shambler", Vector3(23.8, 0, -31.8)],
				["shambler", Vector3(25.0, 0, -36.5)], ["sprinter", Vector3(27.5, 0, -35.2)],
				["shambler", Vector3(28.5, 0, -33.8)], ["bloater", Vector3(29.2, 0, -32.2)],
				["sprinter", Vector3(29.8, 0, -35.6)], ["shambler", Vector3(31.0, 0, -34.0)]
			]:
				var z := hm.spawn_zombie(zp[0], zp[1])
				if zp[0] == "bloater" and _thriller_bloater.is_empty():
					_thriller_bloater = z
			_set_shot(Vector3(13.2, 1.38, -32.6), Vector3(14.0, 1.22, -33.1), Vector3(24.5, 1.25, -34.0), Vector3(25.5, 1.20, -34.2), 3.7, 40.0, 3.5, 0.016)

		2: # 7.2s - 11.2s: 5-DISTRICT WORLD SHOWCASE MONTAGE (3 Rapid Beat-Synced Drone Sweeps!)
			_clear_zombies()
			_do_flash(Color(1.0, 0.55, 0.2, 0.65), 0.20)
			AudioManager.play_sfx("trailer_impact", 0.98, 1.02, 0.95)
			hud.visible = false
			_set_bars(true)
			_set_dof(false)
			_ai_enabled = false
			# Sub-cut 0 (7.2 - 8.55s): GAS 365 Forecourt & Glowing 6.66$ Pylon
			_set_caption("5 INTERCONNECTED DISTRICTS", "GAS 365 FORECOURT  •  EXPLOSIVE FUEL PUMPS & MARTS", Color(0.24, 0.95, 0.52, 0.95))
			pl.global_position = Vector3(-16.0, 0.0, -24.0)
			_seed_blood(Vector3(-29, 0, -34), 14, 7.0)
			_spawn_box_horde(-41.0, -20.0, -44.0, -24.0, 26, {"shambler": 4, "sprinter": 3, "spitter": 1, "charger": 1, "bloater": 1})
			_set_shot(Vector3(-11.5, 6.8, -19.5), Vector3(-19.5, 5.2, -26.5), Vector3(-31.0, 2.2, -34.5), Vector3(-33.0, 1.8, -35.0), 1.35, 48.0, -1.5, 0.008)

		3: # 11.2s - 16.2s: LIVE BLOODY GAMEPLAY — Main Ave Horde + Boomstick Shotgun -> UZI + Shockwave Dash!
			_clear_zombies()
			_do_flash(Color(1, 1, 1, 0.65), 0.18)
			AudioManager.play_sfx("trailer_impact", 1.0, 1.04, 0.95)
			AudioManager.set_music_stem("combat")
			_set_bars(false)
			hud.visible = true
			_set_caption("RELENTLESS TWIN-STICK CARNAGE", "BOOMSTICK SHOTGUN  +  POCKET CAPPER SMG  +  SHOCKWAVE DASH", Color(1.0, 0.55, 0.14, 0.95))
			GameManager.apply_perk("shockwave_dash")
			GameManager.apply_perk("trigger_happy")
			_equip_weapon("shotgun", false)
			GameManager.unlock_weapon("smg", false)
			_set_hud_stats(24, 18450, 2, 742.0, 6)
			_set_gameplay_cam(Vector3(0.0, 0.0, -14.0), Vector2(0, -1))
			_ai_enabled = true
			_ai_anchor = Vector3(0.0, 0.0, -16.0)
			_ai_anchor_r = 4.5
			_ai_kite_min = 4.8
			_ai_kite_max = 9.5
			_seed_blood(Vector3(0, 0, -18), 18, 7.5)
			_spawn_pack(Vector3(0, 0, -16), [
				"shambler", "shambler", "sprinter", "sprinter", "spitter",
				"bloater", "bruiser", "shambler", "sprinter", "shambler",
				"sprinter", "shambler", "spitter", "bloater", "charger",
				"shambler", "sprinter", "shambler", "sprinter", "shambler",
				"bruiser", "sprinter", "shambler", "shambler", "sprinter",
				"shambler", "bloater", "sprinter", "shambler", "spitter",
				"shambler", "sprinter", "shambler", "sprinter"
			], 5.0, 14.0)

		4: # 16.2s - 20.4s: LIVE GAMEPLAY — Industrial Cargo Yard: Street Sweeper Rifle + Acid Bloater Chain Pop + Bull Charger!
			_clear_zombies()
			_do_flash(Color(0.35, 1.0, 0.25, 0.55), 0.18)
			AudioManager.play_sfx("trailer_impact", 0.96, 1.02, 0.90)
			_set_bars(false)
			hud.visible = true
			_set_caption("7 LETHAL WEAPONS  &  6 INFECTED ARCHETYPES", "PIERCING STREET SWEEPER RIFLE  •  VOLATILE ACID BLOATER CHAINS", Color(0.35, 0.98, 0.28, 0.95))
			GameManager.apply_perk("piercing_slugs")
			GameManager.apply_perk("ricochet_rounds")
			GameManager.apply_perk("incendiary_crits")
			_equip_weapon("rifle", false)
			_set_hud_stats(48, 34900, 3, 615.0, 7)
			_set_gameplay_cam(Vector3(23.5, 0.0, -90.0), Vector2(1, -0.25))
			_ai_enabled = true
			_ai_anchor = Vector3(24.5, 0.0, -91.0)
			_ai_anchor_r = 4.0
			_ai_kite_min = 5.5
			_ai_kite_max = 11.5
			_seed_blood(Vector3(28, 0, -92), 18, 7.5)
			_cargo_bloaters.clear()
			for bp in [Vector3(29.5, 0, -90.5), Vector3(31.2, 0, -93.0), Vector3(28.8, 0, -94.8)]:
				_cargo_bloaters.append(hm.spawn_zombie("bloater", bp))
			for cp in [Vector3(32.5, 0, -88.5), Vector3(33.0, 0, -95.5)]:
				var ch := hm.spawn_zombie("charger", cp)
				ch["charge_cd"] = 0.25
			_spawn_box_horde(26.5, 41.0, -101.0, -83.0, 30, {"shambler": 5, "sprinter": 3, "spitter": 1, "bruiser": 1})

		5: # 20.4s - 23.0s: 36-CARD ROGUELITE PERK SYNERGY ENGINE — Holographic Draft + Live Redraw & Confirm!
			_do_flash(Color(1.0, 0.88, 0.32, 0.55), 0.16)
			AudioManager.play_sfx("level_up", 1.0, 1.04, 0.95)
			_set_caption("36-CARD PERK SYNERGY ENGINE", "HOLOGRAPHIC DRAFT  •  DUALITY TRADE-OFFS  •  CHAOS OVERRIDES", Color(1.0, 0.78, 0.18, 0.95))
			if _perk_modal:
				_perk_modal._open_draft(8)

		6: # 23.0s - 28.2s: GAS 365 CHAOS OVERDRIVE — Auto Shotgun + Laser Sentry Turret + 5-Explosion Fuel Pump Chain Reaction!
			if _perk_modal and _perk_modal.visible:
				_perk_modal._confirm(1)
			get_tree().paused = false
			_clear_zombies()
			_do_flash(Color(1.0, 0.45, 0.12, 0.68), 0.20)
			AudioManager.play_sfx("trailer_impact", 0.95, 1.0, 0.98)
			AudioManager.set_music_stem("chaos")
			AudioManager.play_vo("vo_gear_3", "Halfway there! Three gears salvaged. The infected are swarming thicker ahead.", true)
			_set_bars(false)
			hud.visible = true
			hud.show_banner("CHAOS OVERRIDE: AUTO SHOTGUN!", "DEPLOYED AUTOMATED LASER SENTRY TURRET", 2.1)
			_set_caption("EXPLOSIVE JOLT-PHYSICS DESTRUCTION", "AUTO SHOTGUN OVERRIDE  +  LASER SENTRY TURRET  +  FUEL PUMP CHAIN", Color(1.0, 0.38, 0.10, 0.95))
			_equip_weapon("autoshotgun", true)
			_set_hud_stats(76, 54200, 4, 468.0, 9)
			_set_gameplay_cam(Vector3(-20.5, 0.0, -33.5), Vector2(-1, 0))
			_ai_enabled = true
			_ai_anchor = Vector3(-20.5, 0.0, -33.5)
			_ai_anchor_r = 3.5
			_ai_kite_min = 5.0
			_ai_kite_max = 11.0
			_seed_blood(Vector3(-28, 0, -34), 20, 8.0)
			hm.spawn_sentry_turret(Vector3(-23.2, 0.0, -30.2))
			hm.spawn_sentry_turret(Vector3(-23.2, 0.0, -37.2))
			_spawn_box_horde(-39.0, -24.0, -43.0, -25.0, 42, {"shambler": 5, "sprinter": 3, "charger": 1, "bloater": 1, "bruiser": 1, "spitter": 1})

		7: # 28.2s - 33.0s: NEON ALLEY INFERNO — Incinerator Flamethrower + Chain Overcharge + Police Cruiser Explosion!
			_clear_zombies()
			_do_flash(Color(1.0, 0.35, 0.06, 0.65), 0.18)
			AudioManager.play_sfx("trailer_impact", 0.98, 1.04, 0.95)
			_set_bars(false)
			hud.visible = true
			hud.show_banner("CHAOS OVERRIDE: INCINERATOR!", "LIQUID NAPALM  +  CHAIN OVERCHARGE", 2.0)
			_set_caption("INCINERATOR NAPALM  &  CHAIN OVERCHARGE", "IGNITE ENTIRE HORDES UNDER THE NEON ALLEY STRIP", Color(1.0, 0.42, 0.08, 0.95))
			GameManager.active_chaos_buffs["chain_lightning"] = 30.0
			_equip_weapon("flamethrower", true)
			_set_hud_stats(112, 79600, 5, 318.0, 12)
			_set_gameplay_cam(Vector3(21.5, 0.0, -33.5), Vector2(1, 0))
			_ai_enabled = true
			_ai_anchor = Vector3(22.5, 0.0, -33.5)
			_ai_anchor_r = 4.0
			_ai_kite_min = 4.0
			_ai_kite_max = 8.5
			_seed_blood(Vector3(29, 0, -34), 20, 8.0)
			_spawn_box_horde(26.0, 42.0, -43.0, -25.0, 45, {"shambler": 5, "sprinter": 4, "bloater": 2, "bruiser": 1, "charger": 1, "spitter": 1})

		8: # 33.0s - 36.8s: LOW-ANGLE ACTION CINEMATIC — Heavy Machine Gun + Fully Vaxxxed Shield vs 65-Zombie Mega-Horde!
			_clear_zombies()
			_do_flash(Color(1.0, 0.75, 0.22, 0.65), 0.18)
			AudioManager.play_sfx("trailer_impact", 0.94, 0.98, 0.98)
			AudioManager.play_sfx("trailer_riser", 0.98, 1.02, 0.85)
			hud.visible = false
			_set_bars(true)
			_set_dof(true, 32.0, 20.0, 0.055)
			_set_caption("UNLEASH PURE CHAOS", "TWIN-BARREL HEAVY MACHINE GUN  +  FULLY VAXXXED SHIELD", Color(1.0, 0.72, 0.14, 0.95))
			GameManager.active_chaos_buffs["invuln"] = 30.0
			GameManager.active_chaos_buffs["double_rof"] = 30.0
			_equip_weapon("hmg", true)
			pl.global_position = Vector3(0.0, 0.0, -56.0)
			pl.velocity = Vector3.ZERO
			_ai_enabled = true
			_ai_anchor = Vector3(0.0, 0.0, -56.5)
			_ai_anchor_r = 1.5
			_ai_kite_min = 2.5
			_ai_kite_max = 32.0
			_seed_blood(Vector3(0, 0, -66), 22, 8.0)
			_spawn_box_horde(-8.2, 8.2, -98.0, -65.0, 65, {"shambler": 6, "sprinter": 4, "bruiser": 1, "charger": 1, "bloater": 1, "spitter": 1})
			_set_shot(Vector3(2.3, 1.25, -51.2), Vector3(-1.8, 1.05, -52.6), Vector3(-0.3, 1.45, -74.0), Vector3(0.2, 1.65, -78.0), 3.8, 45.0, -1.5, 0.015)

		9: # 36.8s - 42.5s: CLIMAX — HIGH-RISE BRUTE BOSS + EXTRACTION PLAZA HOLDOUT + SEARCHLIGHTS + MASSIVE EXPLOSIONS!
			_clear_zombies()
			_do_flash(Color(1.0, 0.18, 0.12, 0.75), 0.22)
			AudioManager.play_sfx("trailer_braam", 0.95, 1.0, 1.0)
			AudioManager.set_music_stem("extraction")
			GameManager.gears = 6
			GameManager.start_extraction_holdout()
			_set_bars(false)
			hud.visible = true
			_set_caption("CLIMAX: HIGH-RISE EXTRACTION HOLDOUT", "DEFEAT THE HIGH-RISE BRUTE  &  HOLD THE PAD FOR CHOPPER EVAC", Color(1.0, 0.18, 0.16, 0.95))
			_equip_weapon("hmg", true)
			_set_hud_stats(154, 112800, 6, 84.0, 16)
			_set_gameplay_cam(Vector3(0.0, 0.0, -138.5), Vector2(0, -1), Vector3(0.0, 17.5, 13.2))
			_ai_enabled = true
			_ai_anchor = Vector3(0.0, 0.0, -139.0)
			_ai_anchor_r = 4.2
			_ai_kite_min = 6.0
			_ai_kite_max = 12.5
			_seed_blood(Vector3(0, 0, -148), 24, 9.0)
			hm.spawn_sentry_turret(Vector3(-5.2, 0.0, -143.5))
			hm.spawn_sentry_turret(Vector3(5.2, 0.0, -143.5))
			_active_boss = hm.spawn_zombie("boss", Vector3(0.0, 0.0, -149.5))
			_active_boss["slam_cd"] = 0.65
			_active_boss["shoot_cd"] = 1.25
			_spawn_box_horde(-12.5, 12.5, -162.0, -145.0, 42, {"shambler": 5, "sprinter": 4, "charger": 1, "bloater": 1, "bruiser": 1, "spitter": 1})
			exp_sys.spawn_explosion(Vector3(9.5, 0.5, -146.0), 7.5, 120.0, true)

		10: # 42.5s - 48.0s: AAA STEAM LAUNCH END CARD & TITLE SLAM!
			_clear_zombies()
			_ai_enabled = false
			_do_flash(Color(1.0, 0.28, 0.14, 0.92), 0.38)
			AudioManager.play_sfx("trailer_impact", 0.92, 0.96, 1.0)
			AudioManager.play_sfx("explosion", 0.80, 0.88, 0.95)
			AudioManager.play_vo("vo_victory", "Chopper locked on! You made it out of the quarantine zone alive. Welcome back.", true)
			hud.visible = false
			_set_bars(false)
			_set_caption("")
			_endcard.visible = true
			_end_logo.pivot_offset = Vector2(360, 165)
			_end_logo.scale = Vector2(1.52, 1.52)
			_end_sub.modulate.a = 0.0
			_end_feat.modulate.a = 0.0
			_end_plat.modulate.a = 0.0
			var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(_end_logo, "scale", Vector2.ONE, 0.44).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(_end_sub, "modulate:a", 1.0, 0.35).set_delay(0.32)
			tw.parallel().tween_property(_end_feat, "modulate:a", 1.0, 0.35).set_delay(0.62)
			tw.parallel().tween_property(_end_plat, "modulate:a", 1.0, 0.40).set_delay(0.95)

func _process(delta: float) -> void:
	_t += delta

	# Keep XP from accidentally opening PerkDraftModal outside Stage 5
	if _stage != 5:
		GameManager.xp_to_next = 999999.0
		GameManager.pending_level_ups = 0

	# Master 48.0s Stage Timeline
	if _stage == 0 and _t >= 3.5: _enter_stage(1)
	elif _stage == 1 and _t >= 7.2: _enter_stage(2)
	elif _stage == 2 and _t >= 11.2: _enter_stage(3)
	elif _stage == 3 and _t >= 16.2: _enter_stage(4)
	elif _stage == 4 and _t >= 20.4: _enter_stage(5)
	elif _stage == 5 and _t >= 23.0: _enter_stage(6)
	elif _stage == 6 and _t >= 28.2: _enter_stage(7)
	elif _stage == 7 and _t >= 33.0: _enter_stage(8)
	elif _stage == 8 and _t >= 36.8: _enter_stage(9)
	elif _stage == 9 and _t >= 42.5: _enter_stage(10)
	elif _stage == 10 and _t >= 48.0:
		get_tree().quit()
		return

	# ---- Per-Stage Choreographed Beats & Micro-Events ----
	_update_stage_events(delta)

	# ---- Autonomous Action-Hero AI (runs in both Gameplay AND Cinematic Action shots!) ----
	if _ai_enabled and not get_tree().paused:
		_drive_hero_ai(delta)

	# ---- Cinematic Camera Controller ----
	if _cinematic_cam:
		_gw._player.camera = null
		_shot_t += delta
		var p := clampf(_shot_t / maxf(0.01, _shot_dur), 0.0, 1.0)
		var ep := smoothstep(0.0, 1.0, p)
		var cam: Camera3D = _gw._cam
		if cam:
			var pos := _cam_from.lerp(_cam_to, ep)
			var look := _look_from.lerp(_look_to, ep)
			if _handheld > 0.0:
				pos += Vector3(sin(_t * 1.9) + sin(_t * 3.3) * 0.4, sin(_t * 2.4) * 0.6, cos(_t * 1.5)) * _handheld * 2.5
				look += Vector3(sin(_t * 1.3), cos(_t * 2.1) * 0.5, 0.0) * _handheld * 4.0
			cam.global_position = pos
			cam.look_at(look, Vector3.UP)
			cam.rotation.z = deg_to_rad(lerpf(_cam_roll, _cam_roll * 0.4, ep))
			if _gw._rain:
				var fwd := -cam.global_transform.basis.z
				fwd.y = 0.0
				_gw._rain.global_position = cam.global_position + fwd.normalized() * 8.0 + Vector3(0, 14.0, 0)

func _update_stage_events(_delta: float) -> void:
	var pl: PlayerController = _gw._player
	var hm: HordeManager = _gw._horde_mgr
	var exp_sys: ExplosionSystem = _gw._exp_sys

	# Stage 1 (Thriller Alley): At t=5.0s, survivor opens fire with Boomstick Shotgun & pops the lead Acid Bloater in the flashlight beam!
	if _stage == 1:
		pl.touch_aim = Vector2(1.0, sin(_t * 3.2) * 0.26).normalized()
		if _t >= 5.0:
			pl.touch_firing = true
			if _t >= 5.55 and _once("s1_pop") and not _thriller_bloater.is_empty() and _thriller_bloater.get("alive", false):
				hm.damage_zombie(_thriller_bloater, 9999.0, Vector3(1, 0, 0), true, false)

	# Stage 2 (5-District World Montage): Sub-cut B @ 8.55s (Subway Floodlight Checkpoint) & Sub-cut C @ 9.85s (High-Rise Tower)
	elif _stage == 2:
		if _t >= 8.55 and _sub_cut == 0:
			_sub_cut = 1
			_clear_zombies()
			_do_flash(Color(0.75, 0.95, 1.0, 0.55), 0.16)
			AudioManager.play_sfx("trailer_impact", 1.02, 1.06, 0.90)
			_set_caption("MILITARY QUARANTINE CHECKPOINT", "SUBWAY FLOODLIGHT LOT  &  INDUSTRIAL CARGO MAZE", Color(0.32, 0.88, 1.0, 0.95))
			pl.global_position = Vector3(-16.0, 0.0, -86.0)
			_seed_blood(Vector3(-30, 0, -92), 14, 7.0)
			_spawn_box_horde(-43.0, -21.0, -103.0, -82.0, 28, {"shambler": 4, "sprinter": 3, "bruiser": 2, "charger": 1})
			_set_shot(Vector3(-12.0, 8.2, -76.5), Vector3(-16.5, 5.8, -83.5), Vector3(-31.0, 1.4, -93.0), Vector3(-32.5, 1.2, -95.0), 1.30, 48.0, 1.5, 0.008)
		elif _t >= 9.85 and _sub_cut == 1:
			_sub_cut = 2
			_clear_zombies()
			_do_flash(Color(0.28, 0.96, 1.0, 0.55), 0.16)
			AudioManager.play_sfx("trailer_impact", 1.05, 1.10, 0.95)
			_set_caption("6 GEARS.  18 MINUTES.  REACH EXTRACTION.", "HIGH-RISE EVACUATION PLAZA  •  SWEEPING SEARCHLIGHTS", Color(0.28, 0.96, 1.0, 0.95))
			pl.global_position = Vector3(0.0, 0.0, -135.0)
			_seed_blood(Vector3(0, 0, -148), 16, 8.0)
			_spawn_box_horde(-14.0, 14.0, -162.0, -142.0, 34, {"shambler": 5, "sprinter": 3, "bruiser": 1, "bloater": 1})
			_set_shot(Vector3(-7.5, 2.5, -131.0), Vector3(5.5, 7.5, -138.0), Vector3(0.0, 4.5, -162.0), Vector3(0.0, 9.5, -168.0), 1.35, 50.0, 0.0, 0.008)

	# Stage 3 (Main Ave Shotgun -> SMG + Shockwave Dash + Burning Taxi Detonation):
	elif _stage == 3:
		if _t >= 13.4 and _once("s3_smg"):
			_equip_weapon("smg", false)
			pl.trigger_touch_dash()
			GameManager.multikill_triggered.emit("MULTI KILL!", 5)
		if _t >= 14.8 and _once("s3_car"):
			_detonate_nearest_car(Vector3(4.5, 0, -18.0), 6.0)
			GameManager.multikill_triggered.emit("CARNAGE!!", 8)

	# Stage 4 (Cargo Yard Piercing Rifle + 3-Bloater Toxic Chain Explosion + Barrel Detonation):
	elif _stage == 4:
		if _t >= 17.5 and _once("s4_b0") and _cargo_bloaters.size() > 0 and _cargo_bloaters[0].get("alive", false):
			hm.damage_zombie(_cargo_bloaters[0], 9999.0, Vector3(1, 0, 0), true, false)
		if _t >= 17.9 and _once("s4_b1") and _cargo_bloaters.size() > 1 and _cargo_bloaters[1].get("alive", false):
			hm.damage_zombie(_cargo_bloaters[1], 9999.0, Vector3(1, 0, 0), true, false)
			GameManager.multikill_triggered.emit("CARNAGE!!", 8)
		if _t >= 18.3 and _once("s4_b2") and _cargo_bloaters.size() > 2 and _cargo_bloaters[2].get("alive", false):
			hm.damage_zombie(_cargo_bloaters[2], 9999.0, Vector3(1, 0, 0), true, false)
		if _t >= 19.1 and _once("s4_barrel"):
			_detonate_nearest_car(Vector3(26.0, 0, -87.0), 6.0)
			_detonate_nearest_car(Vector3(30.0, 0, -92.0), 6.0)
			GameManager.multikill_triggered.emit("MASSACRE!!", 12)

	# Stage 5 (3-Card Holographic Perk Draft Showcase — Hover -> Redraw -> Hover -> Confirm):
	elif _stage == 5 and _perk_modal and _perk_modal.visible:
		if _t >= 20.85 and _once("s5_h0"):
			_perk_modal._selected_idx = 0
			_perk_modal._update_highlight()
			AudioManager.play_sfx("card_hover", 0.98, 1.04, 0.75)
		if _t >= 21.20 and _once("s5_h2"):
			_perk_modal._selected_idx = 2
			_perk_modal._update_highlight()
			AudioManager.play_sfx("card_hover", 1.02, 1.08, 0.75)
		if _t >= 21.55 and _once("s5_redraw"):
			_perk_modal._on_redraw()
		if _t >= 22.25 and _once("s5_h1"):
			_perk_modal._selected_idx = 1
			_perk_modal._update_highlight()
			AudioManager.play_sfx("card_hover", 1.04, 1.10, 0.80)

	# Stage 6 (GAS 365 Chaos: 5-Vehicle & Fuel-Pump Chain Reaction Explosion!):
	elif _stage == 6:
		if _t >= 24.9 and _once("s6_p1"):
			_detonate_nearest_car(Vector3(-25.5, 0, -31.6), 4.0)
		if _t >= 25.25 and _once("s6_p2"):
			_detonate_nearest_car(Vector3(-25.5, 0, -36.4), 4.0)
			GameManager.multikill_triggered.emit("CARNAGE!!", 8)
		if _t >= 25.60 and _once("s6_p3"):
			_detonate_nearest_car(Vector3(-32.5, 0, -31.6), 4.0)
		if _t >= 25.95 and _once("s6_p4"):
			_detonate_nearest_car(Vector3(-32.5, 0, -36.4), 4.0)
			_detonate_nearest_car(Vector3(-29.0, 0, -31.0), 5.0)
			pl.add_camera_trauma(0.90)
			GameManager.multikill_triggered.emit("DEZOMBIFIED!!!", 18)
		if _t >= 26.6 and _once("s6_reinforce"):
			_spawn_box_horde(-38.0, -25.0, -42.0, -26.0, 18, {"sprinter": 4, "shambler": 4, "bloater": 1})

	# Stage 7 (Neon Alley Flamethrower Inferno + Police Cruiser & Barrel Detonations):
	elif _stage == 7:
		if _t >= 30.1 and _once("s7_b1"):
			_detonate_nearest_car(Vector3(24.0, 0, -39.0), 4.5)
			GameManager.multikill_triggered.emit("MASSACRE!!", 12)
		if _t >= 31.1 and _once("s7_cop"):
			_detonate_nearest_car(Vector3(27.0, 0, -33.0), 5.0)
			pl.add_camera_trauma(0.85)
			GameManager.multikill_triggered.emit("DEZOMBIFIED!!!", 18)

	# Stage 8 (Low-Angle Main Ave HMG Mega-Horde + Police Car Detonation):
	elif _stage == 8:
		if _t >= 35.0 and _once("s8_cop"):
			_detonate_nearest_car(Vector3(-3.8, 0, -62.0), 5.5)
			exp_sys.spawn_explosion(Vector3(2.8, 0.5, -66.0), 8.0, 240.0, true)

	# Stage 9 (Climax: High-Rise Brute Boss Fight + Perimeter Police Cruiser Explosions + Boss Slain!):
	elif _stage == 9:
		if _t >= 38.6 and _once("s9_b1"):
			_detonate_nearest_car(Vector3(-9.0, 0, -142.0), 5.0)
			_detonate_nearest_car(Vector3(-14.0, 0, -142.0), 6.0)
			GameManager.multikill_triggered.emit("MASSACRE!!", 12)
		if _t >= 40.2 and _once("s9_b2"):
			_detonate_nearest_car(Vector3(9.0, 0, -142.0), 5.0)
			_detonate_nearest_car(Vector3(15.0, 0, -146.0), 6.0)
		if _t >= 41.4 and _once("s9_boss_kill"):
			if not _active_boss.is_empty() and _active_boss.get("alive", false):
				exp_sys.spawn_explosion(_active_boss["pos"], 9.5, 450.0, true, Color(1.0, 0.25, 0.08))
				hm.damage_zombie(_active_boss, 99999.0, Vector3(0, 0, -1), true, true)
			pl.add_camera_trauma(0.95)
			GameManager.multikill_triggered.emit("DEZOMBIFIED!!!", 18)

	# Stage 10 (Steam End Card Zoom + Clean Fade Out at 47.1 - 48.0s):
	elif _stage == 10:
		var et := _t - 42.5
		if _end_bg:
			_end_bg.pivot_offset = _end_bg.size * 0.5
			var z := 1.0 + clampf(et / 5.5, 0.0, 1.0) * 0.07
			_end_bg.scale = Vector2(z, z)
		if _t >= 47.0:
			_flash.color = Color(0, 0, 0, clampf((_t - 47.0) / 0.95, 0.0, 1.0))

func _drive_hero_ai(delta: float) -> void:
	var pl: PlayerController = _gw._player
	var hm: HordeManager = _gw._horde_mgr
	if pl == null or hm == null:
		return

	# Keep hero topped up & immune to accidental death during the trailer
	GameManager._hurt_invuln = 2.0
	GameManager.hp = GameManager.max_hp
	if GameManager.stamina < 45.0:
		GameManager.stamina = 95.0

	var ppos := pl.global_position
	ppos.y = 0.0
	pl.touch_active = true

	# Prioritize aiming at the High-Rise Brute Boss in Stage 9 when alive!
	var target_pos := Vector3.INF
	if _stage == 9 and not _active_boss.is_empty() and _active_boss.get("alive", false):
		target_pos = _active_boss["pos"]
	else:
		var near := hm.get_nearest_zombies(ppos, 28.0, 1)
		if not near.is_empty():
			target_pos = near[0]["pos"]

	if target_pos != Vector3.INF:
		var to_z := target_pos - ppos
		to_z.y = 0.0
		var dist := to_z.length()
		var aim_dir := to_z / maxf(0.01, dist)
		pl.touch_aim = Vector2(aim_dir.x, aim_dir.z)
		if _gw._hud and _gw._hud._crosshair and _gw._cam:
			var cw := target_pos + Vector3(0, 1.0, 0)
			if not _gw._cam.is_position_behind(cw):
				_gw._hud._crosshair.set("custom_pos", _gw._cam.unproject_position(cw))
		pl.touch_firing = true

		_ai_strafe_t -= delta
		if _ai_strafe_t <= 0.0:
			_ai_strafe_t = randf_range(0.95, 1.65)
			_ai_strafe_sign = -_ai_strafe_sign

		var strafe := Vector3(-aim_dir.z, 0.0, aim_dir.x) * _ai_strafe_sign
		var radial := Vector3.ZERO
		if dist < _ai_kite_min:
			radial = -aim_dir * 1.15
		elif dist > _ai_kite_max:
			radial = aim_dir * 0.65

		var move_v := strafe * 0.82 + radial
		var to_anchor := _ai_anchor - ppos
		to_anchor.y = 0.0
		if to_anchor.length() > _ai_anchor_r:
			move_v += to_anchor.normalized() * clampf((to_anchor.length() - _ai_anchor_r) * 0.65, 0.0, 1.5)

		if move_v.length() > 0.05:
			move_v = move_v.normalized()
			pl.touch_move = Vector2(move_v.x, move_v.z)
		else:
			pl.touch_move = Vector2.ZERO
		pl.touch_sprinting = dist < _ai_kite_min * 1.1

		_ai_dash_cd -= delta
		if _ai_dash_cd <= 0.0 and dist < 4.6 and _stage != 8:
			_ai_dash_cd = 1.85
			pl.trigger_touch_dash()
	else:
		pl.touch_firing = false
		pl.touch_move = Vector2(0.0, -0.5)
		pl.touch_aim = Vector2(0.0, -1.0)
