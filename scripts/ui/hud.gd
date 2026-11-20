class_name GameHUD
extends CanvasLayer

var camera_ref: Camera3D = null
var city_ref: CityBuilder = null
var horde_ref: HordeManager = null

var _portrait: TextureRect
var _portrait_frame: PanelContainer
var _tex_ok: Texture2D
var _tex_hurt: Texture2D
var _hp_bar: ColorRect
var _hp_txt: Label
var _st_bar: ColorRect
var _xp_bar: ColorRect
var _hp_ghost: float = 1.0
var _boss_ghost: float = 1.0
var _lvl_lbl: Label
var _score_lbl: Label
var _streak_box: PanelContainer
var _streak_num: Label
var _streak_mult: Label
var _last_streak: int = 0
var _chaos_box: HBoxContainer

var _timer_lbl: Label
var _banner_box: VBoxContainer
var _banner_lbl: Label
var _banner_sub: Label
var _banner_t: float = 0.0
var _multikill_lbl: Label
var _multikill_t: float = 0.0
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ColorRect

var _gear_lbl: Label
var _weapon_frame: PanelContainer
var _weapon_icon: TextureRect
var _weapon_name: Label
var _weapon_chaos_bar: ColorRect
var _weapon_slots_lbl: Label
var _next_lvl_lbl: Label

var _subtitle_panel: PanelContainer
var _subtitle_lbl: Label
var _waypoints_layer: Control
var _popups_layer: Control
var _popups: Array[Dictionary] = []
var _crosshair: Control
var _hit_t: float = 0.0
var _hit_crit: bool = false
var _recoil_spread: float = 0.0

class TacticalCrosshair extends Control:
	var spread: float = 0.0
	var hit_alpha: float = 0.0
	var hit_crit: bool = false
	var custom_pos: Vector2 = Vector2.INF
	func _draw() -> void:
		var c := custom_pos if custom_pos != Vector2.INF else get_local_mouse_position()
		var gap := 7.0 + spread
		var ln := 9.0
		var col := Color(0.95, 0.98, 1.0, 0.88)
		var out := Color(0.0, 0.0, 0.0, 0.85)
		# Outer dark outline + crisp white prongs
		for pair in [
			[Vector2(-gap - ln, 0), Vector2(-gap, 0)],
			[Vector2(gap, 0), Vector2(gap + ln, 0)],
			[Vector2(0, -gap - ln), Vector2(0, -gap)],
			[Vector2(0, gap), Vector2(0, gap + ln)],
		]:
			draw_line(c + pair[0], c + pair[1], out, 4.0)
			draw_line(c + pair[0], c + pair[1], col, 2.0)
		draw_circle(c, 2.2, Color(1.0, 0.28, 0.22, 0.95))
		# Dynamic X Hitmarker!
		if hit_alpha > 0.01:
			var hc := Color(1.0, 0.85, 0.15, hit_alpha) if not hit_crit else Color(1.0, 0.20, 0.15, hit_alpha)
			var w := 3.5 if hit_crit else 2.2
			var s0 := 5.0
			var s1 := 14.0 if hit_crit else 10.5
			for diag in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
				draw_line(c + diag * s0, c + diag * s1, hc, w)

func _ready() -> void:
	layer = 6
	if ResourceLoader.exists("res://assets/ui/survivor_portrait.png"):
		_tex_ok = load("res://assets/ui/survivor_portrait.png")
	if ResourceLoader.exists("res://assets/ui/survivor_hurt.png"):
		_tex_hurt = load("res://assets/ui/survivor_hurt.png")
	_build_ui()

	GameManager.stats_updated.connect(_refresh)
	GameManager.weapon_changed.connect(_on_weapon_changed)
	GameManager.player_damaged.connect(_on_player_damaged)
	GameManager.boss_spawned.connect(_on_boss_spawned)
	GameManager.boss_hp_changed.connect(_on_boss_hp)
	GameManager.boss_defeated.connect(func(): _boss_box.visible = false)
	GameManager.extraction_started.connect(func(): show_banner("EXTRACTION INBOUND!", "HOLD THE HIGH-RISE PAD FOR 90 SECONDS!", 4.5))
	GameManager.hit_marker.connect(_on_hit_marker)
	GameManager.multikill_triggered.connect(_on_multikill)
	AudioManager.subtitle_changed.connect(_on_subtitle)
	_on_weapon_changed(GameManager.get_current_weapon_id(), false)
	_refresh()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_waypoints_layer = Control.new()
	_waypoints_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_waypoints_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_waypoints_layer)

	_popups_layer = Control.new()
	_popups_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popups_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_popups_layer)

	# ---- TOP LEFT: Video-Accurate Portrait (red border + LV inside) + Green/Yellow/Cyan Bars ----
	var tl := VBoxContainer.new()
	tl.position = Vector2(14, 12)
	tl.add_theme_constant_override("separation", 10)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	tl.add_child(top_row)

	_portrait_frame = PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.05, 0.02, 0.02, 0.92)
	psb.set_border_width_all(2)
	psb.border_color = Color(0.88, 0.12, 0.12, 0.95)
	_portrait_frame.add_theme_stylebox_override("panel", psb)
	top_row.add_child(_portrait_frame)

	var p_wrap := Control.new()
	p_wrap.custom_minimum_size = Vector2(50, 56)
	_portrait_frame.add_child(p_wrap)
	_portrait = TextureRect.new()
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.texture = _tex_ok
	p_wrap.add_child(_portrait)
	var lv_tint := ColorRect.new()
	lv_tint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lv_tint.offset_top = -18
	lv_tint.color = Color(0.55, 0.02, 0.02, 0.78)
	p_wrap.add_child(lv_tint)
	_lvl_lbl = Label.new()
	_lvl_lbl.text = "LV1"
	_lvl_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_lvl_lbl.offset_top = -20
	_lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_lvl_lbl, 14, Color(1.0, 1.0, 1.0), true, 3)
	p_wrap.add_child(_lvl_lbl)

	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 6)
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_child(bars)

	# Row 1: Green Heart + Lime-Green HP Bar (matches video!)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 6)
	bars.add_child(r1)
	var ic_hp := Label.new()
	ic_hp.text = "HP"
	UIStyle.style_label(ic_hp, 12, Color(0.55, 0.95, 0.20), false, 2)
	r1.add_child(ic_hp)
	_hp_bar = UIStyle.make_skew_bar(176, 10, Color(0.45, 0.85, 0.14), Color(0.75, 1.0, 0.30), Color(0.18, 0.32, 0.08, 0.7))
	(_hp_bar.material as ShaderMaterial).set_shader_parameter("skew_amount", 0.0)
	r1.add_child(_hp_bar)
	_hp_txt = Label.new()
	_hp_txt.visible = false
	r1.add_child(_hp_txt)

	# Row 2: Yellow Bolt + Yellow Stamina Bar
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	bars.add_child(r2)
	var ic_st := Label.new()
	ic_st.text = "ST"
	UIStyle.style_label(ic_st, 12, Color(0.95, 0.90, 0.16), false, 2)
	r2.add_child(ic_st)
	_st_bar = UIStyle.make_skew_bar(176, 8, Color(0.86, 0.80, 0.12), Color(1.0, 0.96, 0.42), Color(0.30, 0.28, 0.05, 0.7))
	(_st_bar.material as ShaderMaterial).set_shader_parameter("skew_amount", 0.0)
	r2.add_child(_st_bar)

	# Row 3: Cyan Chevron + Wide Cyan XP Bar
	var r3 := HBoxContainer.new()
	r3.add_theme_constant_override("separation", 6)
	bars.add_child(r3)
	var ic_xp := Label.new()
	ic_xp.text = "XP"
	UIStyle.style_label(ic_xp, 13, Color(0.20, 0.82, 1.0), false, 2)
	r3.add_child(ic_xp)
	_xp_bar = UIStyle.make_skew_bar(248, 7, Color(0.12, 0.76, 0.98), Color(0.55, 0.96, 1.0), Color(0.06, 0.26, 0.36, 0.7))
	(_xp_bar.material as ShaderMaterial).set_shader_parameter("skew_amount", 0.0)
	r3.add_child(_xp_bar)

	var xp_sub := HBoxContainer.new()
	xp_sub.alignment = BoxContainer.ALIGNMENT_END
	bars.add_child(xp_sub)
	_score_lbl = Label.new()
	_score_lbl.visible = false
	xp_sub.add_child(_score_lbl)
	_next_lvl_lbl = Label.new()
	_next_lvl_lbl.text = "LV.2"
	UIStyle.style_label(_next_lvl_lbl, 11, Color(0.28, 0.88, 1.0, 0.9), true, 2)
	xp_sub.add_child(_next_lvl_lbl)

	# Video-Accurate Kill Streak (red KILL STREAK header + big white number + tiny mult, NO box!)
	_streak_box = PanelContainer.new()
	_streak_box.visible = false
	_streak_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tl.add_child(_streak_box)
	var sk_vb := VBoxContainer.new()
	sk_vb.add_theme_constant_override("separation", 0)
	_streak_box.add_child(sk_vb)
	var sk_hdr := Label.new()
	sk_hdr.text = "KILL STREAK"
	UIStyle.style_label(sk_hdr, 12, Color(0.95, 0.16, 0.16), true, 3)
	sk_vb.add_child(sk_hdr)
	var sk_row := HBoxContainer.new()
	sk_row.add_theme_constant_override("separation", 6)
	sk_vb.add_child(sk_row)
	_streak_num = Label.new()
	UIStyle.style_label(_streak_num, 26, Color(1.0, 1.0, 1.0), true, 4)
	sk_row.add_child(_streak_num)
	_streak_mult = Label.new()
	UIStyle.style_label(_streak_mult, 13, Color(0.92, 0.94, 0.98), true, 3)
	_streak_mult.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sk_row.add_child(_streak_mult)

	_chaos_box = HBoxContainer.new()
	_chaos_box.add_theme_constant_override("separation", 8)
	tl.add_child(_chaos_box)

	# ---- TOP CENTER: Bold White Timer (no box) + Brief Objective Text ----
	var tc := VBoxContainer.new()
	tc.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tc.offset_left = -240; tc.offset_right = 240; tc.offset_top = 10
	tc.add_theme_constant_override("separation", 4)
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tc)

	_timer_lbl = Label.new()
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_timer_lbl, 28, Color(0.98, 0.99, 1.0), true, 5)
	tc.add_child(_timer_lbl)

	_boss_box = VBoxContainer.new()
	_boss_box.visible = false
	_boss_box.add_theme_constant_override("separation", 2)
	tc.add_child(_boss_box)
	_boss_name = Label.new()
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_boss_name, 13, Color(1.0, 0.25, 0.20), true, 3)
	_boss_box.add_child(_boss_name)
	_boss_bar = UIStyle.make_skew_bar(300, 9, Color(0.95, 0.12, 0.14), Color(1.0, 0.45, 0.18), Color(1.0, 0.35, 0.20, 0.6))
	_boss_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss_box.add_child(_boss_bar)

	_banner_box = VBoxContainer.new()
	_banner_box.visible = false
	_banner_box.add_theme_constant_override("separation", 0)
	tc.add_child(_banner_box)
	_banner_lbl = Label.new()
	_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_banner_lbl, 20, Color(1.0, 1.0, 1.0), true, 4)
	_banner_box.add_child(_banner_lbl)
	_banner_sub = Label.new()
	_banner_sub.visible = false

	_multikill_lbl = Label.new()
	_multikill_lbl.visible = false
	_multikill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multikill_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_multikill_lbl.offset_left = -200; _multikill_lbl.offset_right = 200
	_multikill_lbl.offset_top = 86
	UIStyle.style_label(_multikill_lbl, 22, Color(1.0, 0.84, 0.16), true, 5)
	root.add_child(_multikill_lbl)

	# ---- TOP RIGHT: Video-Accurate Dual Red-Bordered Black Boxes (Gears + Weapon Silhouette) ----
	var tr_vb := VBoxContainer.new()
	tr_vb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr_vb.offset_left = -240; tr_vb.offset_right = -14; tr_vb.offset_top = 12
	tr_vb.add_theme_constant_override("separation", 4)
	tr_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr_vb)

	var tr := HBoxContainer.new()
	tr.alignment = BoxContainer.ALIGNMENT_END
	tr.add_theme_constant_override("separation", 6)
	tr_vb.add_child(tr)

	var red_box := StyleBoxFlat.new()
	red_box.bg_color = Color(0.02, 0.01, 0.01, 0.86)
	red_box.set_border_width_all(2)
	red_box.border_color = Color(0.88, 0.10, 0.10, 0.96)
	red_box.content_margin_left = 6; red_box.content_margin_right = 6; red_box.content_margin_top = 4; red_box.content_margin_bottom = 4

	var gear_panel := PanelContainer.new()
	gear_panel.custom_minimum_size = Vector2(56, 56)
	gear_panel.add_theme_stylebox_override("panel", red_box)
	tr.add_child(gear_panel)
	var gv := VBoxContainer.new()
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	gv.add_theme_constant_override("separation", 0)
	gear_panel.add_child(gv)
	var g_icon := TextureRect.new()
	g_icon.custom_minimum_size = Vector2(28, 28)
	g_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/ui/icon_gear.png"):
		g_icon.texture = load("res://assets/ui/icon_gear.png")
	gv.add_child(g_icon)
	_gear_lbl = Label.new()
	_gear_lbl.text = "0/6"
	_gear_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_gear_lbl, 14, Color(1.0, 1.0, 1.0), true, 3)
	gv.add_child(_gear_lbl)

	_weapon_frame = PanelContainer.new()
	_weapon_frame.custom_minimum_size = Vector2(146, 56)
	_weapon_frame.add_theme_stylebox_override("panel", red_box.duplicate())
	_weapon_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_weapon_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_weapon_frame.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: GameManager.cycle_weapon(1))
	tr.add_child(_weapon_frame)
	var wv := VBoxContainer.new()
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	wv.add_theme_constant_override("separation", 2)
	_weapon_frame.add_child(wv)
	_weapon_icon = TextureRect.new()
	_weapon_icon.custom_minimum_size = Vector2(112, 38)
	_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wv.add_child(_weapon_icon)
	_weapon_name = Label.new()
	_weapon_name.visible = false
	wv.add_child(_weapon_name)
	_weapon_chaos_bar = UIStyle.make_skew_bar(124, 4, Color(1.0, 0.48, 0.08), Color(1.0, 0.88, 0.35), Color(1.0, 0.65, 0.15, 0.5))
	_weapon_chaos_bar.visible = false
	_weapon_chaos_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wv.add_child(_weapon_chaos_bar)

	_weapon_slots_lbl = Label.new()
	_weapon_slots_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIStyle.style_label(_weapon_slots_lbl, 11, Color(0.88, 0.90, 0.94, 0.80), false, 3)
	tr_vb.add_child(_weapon_slots_lbl)

	# ---- BOTTOM: Video-Accurate Clean White Subtitles (NO box!) ----
	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle_panel.offset_left = -360; _subtitle_panel.offset_right = 360
	_subtitle_panel.offset_top = -46; _subtitle_panel.offset_bottom = -14
	_subtitle_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_subtitle_panel.visible = false
	root.add_child(_subtitle_panel)
	_subtitle_lbl = Label.new()
	_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.style_label(_subtitle_lbl, 15, Color(1.0, 1.0, 1.0), false, 4)
	_subtitle_panel.add_child(_subtitle_lbl)

	_crosshair = TacticalCrosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)

func show_banner(title: String, sub: String, dur: float = 3.5) -> void:
	_banner_lbl.text = title
	_banner_box.visible = true
	_banner_t = minf(dur, 2.2)
	_banner_box.modulate.a = 0.0
	create_tween().tween_property(_banner_box, "modulate:a", 1.0, 0.25)

func _on_multikill(txt: String, tier: int) -> void:
	_multikill_lbl.text = txt
	_multikill_lbl.visible = true
	_multikill_t = 1.1
	var col := Color(1.0, 0.85, 0.16) if tier < 5 else (Color(1.0, 0.42, 0.08) if tier < 12 else Color(1.0, 0.16, 0.35))
	UIStyle.style_label(_multikill_lbl, 26 if tier >= 8 else 20, col, true, 5)
	_multikill_lbl.pivot_offset = Vector2(200, 14)
	_multikill_lbl.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(_multikill_lbl, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_hit_marker(is_crit: bool) -> void:
	_hit_t = 0.22 if is_crit else 0.14
	_hit_crit = is_crit
	_recoil_spread = minf(16.0, _recoil_spread + (6.5 if is_crit else 3.2))

func _on_player_damaged(_dmg: float) -> void:
	_portrait_frame.pivot_offset = Vector2(20, 20)
	_portrait_frame.scale = Vector2(1.12, 1.12)
	create_tween().tween_property(_portrait_frame, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)

func spawn_damage_popup(world_pos: Vector3, amount: int, is_crit: bool) -> void:
	if camera_ref == null or _popups.size() > 26:
		return
	var lbl := Label.new()
	lbl.text = "%d!" % amount if is_crit else str(amount)
	UIStyle.style_label(lbl, 18 if is_crit else 12, Color(1.0, 0.88, 0.18) if is_crit else Color(0.95, 0.96, 0.98), is_crit, 5 if is_crit else 3)
	_popups_layer.add_child(lbl)
	_popups.append({"lbl": lbl, "wpos": world_pos + Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.35, 0.35)), "t": 0.0, "dur": 0.78 if is_crit else 0.48, "crit": is_crit})

func _on_weapon_changed(weapon_id: String, is_chaos: bool) -> void:
	var w: Dictionary = GameData.WEAPONS[weapon_id]
	if ResourceLoader.exists(w["icon"]):
		_weapon_icon.texture = load(w["icon"])
	_weapon_name.text = w["name"]
	_weapon_chaos_bar.visible = is_chaos
	if GameManager.run_active and not GameManager.intro_playing:
		show_banner(str(w["name"]).to_upper(), "", 1.1)

func _on_boss_spawned(bname: String, hp: float, max_hp: float) -> void:
	_boss_name.text = bname
	_boss_ghost = 1.0
	(_boss_bar.material as ShaderMaterial).set_shader_parameter("fill_ratio", 1.0)
	(_boss_bar.material as ShaderMaterial).set_shader_parameter("ghost_ratio", 1.0)
	_boss_box.visible = true
	show_banner("BOSS CONTAINMENT BREACH!", bname, 3.2)

func _on_boss_hp(hp: float, max_hp: float) -> void:
	var r := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	(_boss_bar.material as ShaderMaterial).set_shader_parameter("fill_ratio", r)

func _on_subtitle(txt: String) -> void:
	_subtitle_lbl.text = txt
	_subtitle_panel.visible = txt != ""

func _refresh() -> void:
	var hp_r := clampf(GameManager.hp / maxf(1.0, GameManager.max_hp), 0.0, 1.0)
	var st_r := clampf(GameManager.stamina / maxf(1.0, GameManager.max_stamina), 0.0, 1.0)
	var xp_r := clampf(GameManager.xp / maxf(1.0, GameManager.xp_to_next), 0.0, 1.0)
	(_hp_bar.material as ShaderMaterial).set_shader_parameter("fill_ratio", hp_r)
	(_st_bar.material as ShaderMaterial).set_shader_parameter("fill_ratio", st_r)
	(_st_bar.material as ShaderMaterial).set_shader_parameter("ghost_ratio", st_r)
	(_xp_bar.material as ShaderMaterial).set_shader_parameter("fill_ratio", xp_r)
	(_xp_bar.material as ShaderMaterial).set_shader_parameter("ghost_ratio", xp_r)
	_hp_txt.text = "%d/%d" % [int(ceil(GameManager.hp)), int(GameManager.max_hp)]
	_lvl_lbl.text = "LV%d" % GameManager.level
	if _next_lvl_lbl: _next_lvl_lbl.text = "LV.%d" % (GameManager.level + 1)
	_score_lbl.text = "%d" % GameManager.score
	_portrait.texture = _tex_hurt if (hp_r < 0.40 and _tex_hurt) else _tex_ok

	if GameManager.kill_streak >= 2:
		_streak_box.visible = true
		_streak_num.text = "%d" % GameManager.kill_streak
		_streak_mult.text = "%.2f" % GameManager.streak_mult
		if GameManager.kill_streak > _last_streak:
			_streak_box.pivot_offset = Vector2(20, 12)
			_streak_box.scale = Vector2(1.18, 1.18)
			create_tween().tween_property(_streak_box, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
		_last_streak = GameManager.kill_streak
	else:
		_streak_box.visible = false
		_last_streak = 0

	if GameManager.mode == GameManager.GameMode.ESCAPE:
		if GameManager.holdout_active:
			_timer_lbl.text = "HOLD %02d:%02d" % [int(GameManager.holdout_timer) / 60, int(GameManager.holdout_timer) % 60]
			_timer_lbl.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
		else:
			_timer_lbl.text = "%02d:%02d" % [int(GameManager.time_remaining) / 60, int(GameManager.time_remaining) % 60]
			var urgent := GameManager.time_remaining <= 120.0
			_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.20, 0.18) if urgent else Color(0.98, 0.99, 1.0))
		_gear_lbl.text = "%d/%d" % [GameManager.gears, GameManager.gears_required]
		_gear_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45) if GameManager.gears >= GameManager.gears_required else Color(1.0, 1.0, 1.0))
	else:
		_timer_lbl.text = "%02d:%02d" % [int(GameManager.elapsed_time) / 60, int(GameManager.elapsed_time) % 60]
		_gear_lbl.text = "INF"

	if _weapon_slots_lbl:
		if GameManager.chaos_weapon_id != "":
			_weapon_slots_lbl.text = "CHAOS: %s" % str(GameData.WEAPONS[GameManager.chaos_weapon_id]["name"]).to_upper()
		else:
			var parts: PackedStringArray = []
			for i in range(GameManager.unlocked_weapons.size()):
				var wid: String = GameManager.unlocked_weapons[i]
				var nm: String = str(GameData.WEAPONS[wid]["name"]).split(" ")[-1].to_upper()
				parts.append("[%d %s]" % [i + 1, nm] if i == GameManager.current_weapon_idx else "%d %s" % [i + 1, nm])
			_weapon_slots_lbl.text = "  ".join(parts) + "  (Q/E)"

	if GameManager.chaos_weapon_timer > 0.0:
		var cr := clampf(GameManager.chaos_weapon_timer / 30.0, 0.0, 1.0)
		(_weapon_chaos_bar.material as ShaderMaterial).set_shader_parameter("fill_ratio", cr)
		(_weapon_chaos_bar.material as ShaderMaterial).set_shader_parameter("ghost_ratio", cr)

	for c in _chaos_box.get_children():
		c.queue_free()
	for b in GameManager.active_chaos_buffs.keys():
		var lbl := Label.new()
		lbl.text = "%s %.0fs" % [str(b).to_upper(), float(GameManager.active_chaos_buffs[b])]
		UIStyle.style_label(lbl, 11, Color(1.0, 0.75, 0.25), false, 3)
		_chaos_box.add_child(lbl)

func _process(delta: float) -> void:
	# Smooth delayed white damage-trail drain on HP & Boss HP!
	var hp_r := clampf(GameManager.hp / maxf(1.0, GameManager.max_hp), 0.0, 1.0)
	_hp_ghost = move_toward(_hp_ghost, hp_r, delta * 0.42) if _hp_ghost > hp_r else hp_r
	(_hp_bar.material as ShaderMaterial).set_shader_parameter("ghost_ratio", _hp_ghost)
	if _boss_box.visible:
		var br: float = (_boss_bar.material as ShaderMaterial).get_shader_parameter("fill_ratio")
		_boss_ghost = move_toward(_boss_ghost, br, delta * 0.35) if _boss_ghost > br else br
		(_boss_bar.material as ShaderMaterial).set_shader_parameter("ghost_ratio", _boss_ghost)

	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0: _banner_box.visible = false
	if _multikill_t > 0.0:
		_multikill_t -= delta
		_multikill_lbl.modulate.a = clampf(_multikill_t * 2.0, 0.0, 1.0)
		if _multikill_t <= 0.0: _multikill_lbl.visible = false

	# Update Dynamic Reticle
	_hit_t = maxf(0.0, _hit_t - delta)
	_recoil_spread = maxf(0.0, _recoil_spread - delta * 28.0)
	var ch := _crosshair as TacticalCrosshair
	ch.visible = not get_tree().paused and not GameManager.intro_playing and not (OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available())
	ch.spread = _recoil_spread
	ch.hit_alpha = clampf(_hit_t * 5.0, 0.0, 1.0)
	ch.hit_crit = _hit_crit
	ch.queue_redraw()

	# Floating damage numbers
	for i in range(_popups.size() - 1, -1, -1):
		var p: Dictionary = _popups[i]
		p["t"] += delta
		var lbl: Label = p["lbl"]
		if p["t"] >= p["dur"]:
			lbl.queue_free()
			_popups.remove_at(i)
		elif camera_ref:
			var wp: Vector3 = p["wpos"] + Vector3(0, ease(p["t"] / p["dur"], 0.4) * 2.2, 0)
			if not camera_ref.is_position_behind(wp):
				lbl.position = camera_ref.unproject_position(wp) - Vector2(30, 14)
				lbl.modulate.a = 1.0 - pow(p["t"] / p["dur"], 2.0)

	_update_waypoints()

func _update_waypoints() -> void:
	for c in _waypoints_layer.get_children():
		c.queue_free()
	if camera_ref == null or city_ref == null or GameManager.intro_playing:
		return
	var vps := get_viewport().get_visible_rect().size
	var targets: Array[Dictionary] = []
	if GameManager.mode == GameManager.GameMode.ESCAPE:
		if GameManager.gears < GameManager.gears_required:
			var best_g: Node3D = null
			var best_d := 99999.0
			var ref_p := camera_ref.global_position
			for g in city_ref.gear_nodes:
				if is_instance_valid(g):
					var d := g.global_position.distance_to(ref_p)
					if d < best_d:
						best_d = d; best_g = g
			if best_g != null:
				targets.append({"pos": best_g.global_position, "txt": "GEAR %dm" % int(best_d), "col": Color(0.25, 0.96, 1.0)})
		else:
			var ed := int(city_ref.extraction_pad_pos.distance_to(camera_ref.global_position))
			targets.append({"pos": city_ref.extraction_pad_pos + Vector3(0, 1.5, 0), "txt": "EXTRACT %dm" % ed, "col": Color(0.25, 1.0, 0.45)})
	if city_ref and not city_ref.weapon_crates.is_empty():
		var best_w: Node3D = null
		var best_wd := 65.0
		var ref_p := camera_ref.global_position
		for wc in city_ref.weapon_crates:
			var wn: Node3D = wc["node"]
			if is_instance_valid(wn):
				var d := wn.global_position.distance_to(ref_p)
				if d < best_wd:
					best_wd = d; best_w = wn
		if best_w != null:
			targets.append({"pos": best_w.global_position + Vector3(0, 1.8, 0), "txt": "GUN %dm" % int(best_wd), "col": Color(1.0, 0.82, 0.18)})
	if city_ref and not city_ref.supply_drops.is_empty():
		for sd in city_ref.supply_drops:
			if is_instance_valid(sd):
				var dd := int(sd.global_position.distance_to(camera_ref.global_position))
				targets.append({"pos": sd.global_position + Vector3(0, 2.5, 0), "txt": "DROP %dm" % dd, "col": Color(1.0, 0.30, 0.18)})
	if city_ref and not city_ref.turret_kits.is_empty():
		for tk in city_ref.turret_kits:
			if is_instance_valid(tk):
				var td := int(tk.global_position.distance_to(camera_ref.global_position))
				if td < 50:
					targets.append({"pos": tk.global_position + Vector3(0, 2.0, 0), "txt": "TURRET %dm" % td, "col": Color(1.0, 0.52, 0.10)})
	if horde_ref:
		var best_m: Node3D = null
		var md := 26.0
		for mk in horde_ref.get_active_medkits():
			if is_instance_valid(mk):
				var d := mk.global_position.distance_to(camera_ref.global_position)
				if d < md:
					md = d; best_m = mk
		if best_m != null:
			targets.append({"pos": best_m.global_position, "txt": "MEDKIT", "col": Color(0.28, 1.0, 0.40)})

	for t in targets:
		var wp: Vector3 = t["pos"]
		var sp := camera_ref.unproject_position(wp)
		if camera_ref.is_position_behind(wp):
			sp = vps - sp
		sp.x = clampf(sp.x, 30.0, vps.x - 80.0)
		sp.y = clampf(sp.y, 70.0, vps.y - 60.0)
		var lbl := Label.new()
		lbl.text = t["txt"]
		lbl.modulate.a = 0.85
		lbl.position = sp - Vector2(40, 8)
		UIStyle.style_label(lbl, 11, t["col"], false, 3)
		_waypoints_layer.add_child(lbl)
