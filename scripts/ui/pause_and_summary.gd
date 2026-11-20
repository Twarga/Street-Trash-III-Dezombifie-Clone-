class_name PauseAndSummaryUI
extends CanvasLayer

var _pause_root: Control
var _summary_root: Control
var _sum_fx: ColorRect
var _sum_title: Label
var _sum_sub: Label
var _sum_rule: ColorRect
var _sum_rank: Label
var _sum_score_big: Label
var _sum_stat_vals: Dictionary = {}
var _sum_unlock: Label
var _retry_btn: Button
var _preset_btn: Button
var _fs_btn: Button
var _vol_btn: Button

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pause()
	_build_summary()
	GameManager.player_died.connect(func(reason): _show_summary(false, reason))
	GameManager.victory_triggered.connect(func(): _show_summary(true, "EXTRACTED FROM QUARANTINE ZONE"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not GameManager.is_drafting and not _summary_root.visible and not GameManager.intro_playing:
			_toggle_pause()

func _unhandled_input(event: InputEvent) -> void:
	if _summary_root.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_R:
				_retry_run()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_ESCAPE:
				_quit_to_menu()
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and not GameManager.is_drafting and not _summary_root.visible and not GameManager.intro_playing:
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _retry_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _quit_to_menu() -> void:
	get_tree().paused = false
	AudioManager.stop_music()
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")

func _toggle_pause() -> void:
	var will_pause := not _pause_root.visible
	_pause_root.visible = will_pause
	get_tree().paused = will_pause
	if will_pause:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_pause_labels()
		_pause_root.modulate.a = 0.0
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_pause_root, "modulate:a", 1.0, 0.16)

func _refresh_pause_labels() -> void:
	UIStyle.set_menu_item_text(_preset_btn, "GRAPHICS   < %s >" % SettingsManager.get_preset_name())
	if _fs_btn:
		var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		UIStyle.set_menu_item_text(_fs_btn, "DISPLAY    < %s >" % ("FULLSCREEN" if is_fs else "WINDOWED"))
	UIStyle.set_menu_item_text(_vol_btn, "AUDIO      %s" % UIStyle.format_bar(SettingsManager.master_volume, 8))

func _build_pause() -> void:
	_pause_root = Control.new()
	_pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_root.visible = false
	add_child(_pause_root)

	# Sleek left-edge cinematic dark gradient blade (leaves paused 3D street visible on right!)
	var scrim := TextureRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.015, 0.015, 0.022, 0.94), Color(0.015, 0.015, 0.022, 0.78), Color(0.01, 0.01, 0.018, 0.12)])
	grad.offsets = PackedFloat32Array([0.0, 0.38, 1.0])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.0, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	scrim.texture = gtex
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pause_root.add_child(scrim)

	var vb := VBoxContainer.new()
	vb.position = Vector2(68, 120)
	vb.custom_minimum_size = Vector2(400, 0)
	vb.add_theme_constant_override("separation", 8)
	_pause_root.add_child(vb)

	var ttl := Label.new()
	ttl.text = "PAUSED"
	UIStyle.style_label(ttl, 54, Color(1.0, 0.18, 0.16), true, 8)
	vb.add_child(ttl)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(220, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.color = Color(0.95, 0.18, 0.16, 0.90)
	vb.add_child(rule)

	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 12); vb.add_child(sp)

	var resume := UIStyle.make_game_menu_item("RESUME", Color(1.0, 0.20, 0.16), 34, true)
	resume.pressed.connect(_toggle_pause)
	vb.add_child(resume)

	_preset_btn = UIStyle.make_game_menu_item("GRAPHICS:  CINEMATIC", Color(1.0, 0.70, 0.16), 26, true)
	_preset_btn.pressed.connect(func():
		SettingsManager.cycle_preset()
		_refresh_pause_labels()
	)
	vb.add_child(_preset_btn)

	if not OS.has_feature("web") and not OS.has_feature("android"):
		_fs_btn = UIStyle.make_game_menu_item("DISPLAY:  FULLSCREEN", Color(0.25, 0.88, 1.0), 26, true)
		_fs_btn.pressed.connect(func():
			SettingsManager.toggle_fullscreen()
			_refresh_pause_labels()
		)
		vb.add_child(_fs_btn)

	_vol_btn = UIStyle.make_game_menu_item("AUDIO", Color(0.95, 0.96, 1.0), 26, true)
	_vol_btn.pressed.connect(func():
		var nv := SettingsManager.master_volume + 0.15
		if nv > 1.05: nv = 0.0
		SettingsManager.master_volume = clampf(nv, 0.0, 1.0)
		SettingsManager.save_settings()
		_refresh_pause_labels()
	)
	vb.add_child(_vol_btn)

	var restart := UIStyle.make_game_menu_item("RESTART RUN", Color(1.0, 0.62, 0.14), 28, true)
	restart.pressed.connect(_retry_run)
	vb.add_child(restart)

	var menu := UIStyle.make_game_menu_item("QUIT TO TITLE", Color(0.75, 0.78, 0.85), 26, true)
	menu.pressed.connect(_quit_to_menu)
	vb.add_child(menu)

func _build_summary() -> void:
	_summary_root = Control.new()
	_summary_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_summary_root.visible = false
	add_child(_summary_root)

	# Full-screen animated crimson/emerald cinematic death wash (ZERO box/modal!)
	_sum_fx = ColorRect.new()
	_sum_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://assets/shaders/menu_atmosphere.gdshader"):
		var sm := ShaderMaterial.new()
		sm.shader = load("res://assets/shaders/menu_atmosphere.gdshader")
		sm.set_shader_parameter("rain_intensity", 0.45)
		sm.set_shader_parameter("ember_intensity", 0.85)
		sm.set_shader_parameter("tint_color", Color(0.95, 0.08, 0.06, 0.42))
		_sum_fx.material = sm
	else:
		_sum_fx.color = Color(0.06, 0.01, 0.015, 0.86)
	_summary_root.add_child(_sum_fx)

	var dark_wash := ColorRect.new()
	dark_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_wash.color = Color(0.02, 0.01, 0.015, 0.68)
	_summary_root.add_child(dark_wash)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_summary_root.add_child(center)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(760, 0)
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)

	# Massive Grindhouse Impact Headline
	_sum_title = Label.new()
	_sum_title.text = "YOU ARE DEAD"
	_sum_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_sum_title, 82, Color(0.96, 0.14, 0.12), true, 10)
	vb.add_child(_sum_title)

	_sum_sub = Label.new()
	_sum_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_sum_sub, 15, Color(0.86, 0.88, 0.92, 0.78), false, 3)
	vb.add_child(_sum_sub)

	_sum_rule = ColorRect.new()
	_sum_rule.custom_minimum_size = Vector2(520, 2)
	_sum_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sum_rule.color = Color(0.95, 0.16, 0.14, 0.90)
	vb.add_child(_sum_rule)

	# Clean Floating Horizontal Arcade Telemetry Strip (Rank + Key Numbers, ZERO box!)
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 42)
	vb.add_child(strip)

	# Stamped Rank Column
	var rk_col := VBoxContainer.new()
	rk_col.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_child(rk_col)
	var rk_t := Label.new(); rk_t.text = "RANK"; rk_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(rk_t, 12, Color(0.65, 0.68, 0.75), false, 2)
	rk_col.add_child(rk_t)
	_sum_rank = Label.new(); _sum_rank.text = "A"; _sum_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_sum_rank, 72, Color(1.0, 0.84, 0.16), true, 8)
	rk_col.add_child(_sum_rank)

	# Clean vertical divider
	var vdiv := ColorRect.new(); vdiv.custom_minimum_size = Vector2(1, 76); vdiv.color = Color(1, 1, 1, 0.18)
	strip.add_child(vdiv)

	# Floating stat columns
	for pair in [["SCORE", "score"], ["KILLS", "kills"], ["STREAK", "streak"], ["GEARS", "gears"], ["ACC", "acc"]]:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		strip.add_child(col)
		var lbl := Label.new(); lbl.text = pair[0]; lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyle.style_label(lbl, 12, Color(0.62, 0.66, 0.74), false, 2)
		col.add_child(lbl)
		var val := Label.new(); val.text = "0"; val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyle.style_label(val, 30, Color(1.0, 1.0, 1.0), true, 4)
		col.add_child(val)
		_sum_stat_vals[pair[1]] = val

	_sum_score_big = _sum_stat_vals["score"]

	_sum_unlock = Label.new()
	_sum_unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sum_unlock.visible = false
	UIStyle.style_label(_sum_unlock, 15, Color(1.0, 0.84, 0.20), false, 3)
	vb.add_child(_sum_unlock)

	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 14); vb.add_child(sp)

	# Pure Typographic Console/Arcade Bottom Actions (NO web buttons!)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 56)
	vb.add_child(btns)

	_retry_btn = UIStyle.make_game_menu_item("RETRY  [SPACE]", Color(1.0, 0.20, 0.16), 34, false)
	_retry_btn.pressed.connect(_retry_run)
	btns.add_child(_retry_btn)

	var menu_btn := UIStyle.make_game_menu_item("MAIN MENU  [ESC]", Color(0.80, 0.84, 0.90), 28, false)
	menu_btn.pressed.connect(_quit_to_menu)
	btns.add_child(menu_btn)

func _show_summary(escaped: bool, subtitle: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_summary_root.visible = true

	var accent := Color(0.28, 1.0, 0.48) if escaped else Color(0.96, 0.14, 0.12)
	if _sum_fx.material is ShaderMaterial:
		(_sum_fx.material as ShaderMaterial).set_shader_parameter("tint_color", Color(0.10, 0.95, 0.42, 0.35) if escaped else Color(0.95, 0.08, 0.06, 0.45))
	_sum_title.text = "EXTRACTED" if escaped else "YOU ARE DEAD"
	_sum_title.add_theme_color_override("font_color", accent)
	_sum_rule.color = accent
	_sum_sub.text = subtitle.to_upper()

	var rank := GameManager.compute_rank(escaped)
	_sum_rank.text = rank
	var acc := 100.0 * float(GameManager.shots_hit) / float(maxi(1, GameManager.shots_fired))
	(_sum_stat_vals["score"] as Label).text = str(GameManager.score)
	(_sum_stat_vals["kills"] as Label).text = str(GameManager.kills)
	(_sum_stat_vals["streak"] as Label).text = str(GameManager.max_kill_streak)
	(_sum_stat_vals["gears"] as Label).text = "%d/%d" % [GameManager.gears, GameManager.gears_required]
	(_sum_stat_vals["acc"] as Label).text = "%.0f%%" % acc

	var unlocks := SaveManager.record_run(GameManager.score, GameManager.kills, GameManager.max_kill_streak, escaped, GameManager.time_remaining)
	if not unlocks.is_empty():
		_sum_unlock.text = "NEW TRAIT UNLOCKED: " + ", ".join(unlocks)
		_sum_unlock.visible = true
	else:
		_sum_unlock.visible = false

	# Smooth dramatic fade-in + title slam while paused!
	_summary_root.modulate.a = 0.0
	_sum_title.pivot_offset = Vector2(380, 48)
	_sum_title.scale = Vector2(1.35, 1.35)
	_sum_rank.pivot_offset = Vector2(40, 44)
	_sum_rank.scale = Vector2(2.2, 2.2)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(_summary_root, "modulate:a", 1.0, 0.38)
	tw.tween_property(_sum_title, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sum_rank, "scale", Vector2.ONE, 0.42).set_delay(0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_retry_btn.grab_focus()
