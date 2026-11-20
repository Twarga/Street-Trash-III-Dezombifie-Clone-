extends Control

var _bg_rect: TextureRect
var _logo_rect: TextureRect
var _main_col: VBoxContainer
var _opts_col: VBoxContainer
var _opt_btns: Dictionary = {}
var _t: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.start_music("explore")
	_build_ui()

func _process(delta: float) -> void:
	_t += delta
	if _logo_rect:
		_logo_rect.position.y = 38.0 + sin(_t * 1.8) * 4.5
	if _bg_rect:
		var sc := 1.035 + sin(_t * 0.22) * 0.025
		_bg_rect.pivot_offset = _bg_rect.size * 0.5
		_bg_rect.scale = Vector2(sc, sc)

func _build_ui() -> void:
	# 1. Full-bleed breathing key art
	_bg_rect = TextureRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/ui/title_splash.png"):
		_bg_rect.texture = load("res://assets/ui/title_splash.png")
	add_child(_bg_rect)

	# 2. Live animated rain + drifting embers + cinema vignette shader overlay
	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/shaders/menu_atmosphere.gdshader"):
		var sm := ShaderMaterial.new()
		sm.shader = load("res://assets/shaders/menu_atmosphere.gdshader")
		sm.set_shader_parameter("rain_intensity", 0.65)
		sm.set_shader_parameter("ember_intensity", 0.78)
		fx.material = sm
	else:
		fx.color = Color(0.02, 0.02, 0.03, 0.45)
	add_child(fx)

	# 3. Dripping Title Logo (Upper-Left Hero)
	_logo_rect = TextureRect.new()
	_logo_rect.position = Vector2(54, 38)
	_logo_rect.size = Vector2(460, 218)
	_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/ui/title_logo.png"):
		_logo_rect.texture = load("res://assets/ui/title_logo.png")
	add_child(_logo_rect)

	# 4. Pure Borderless Typographic Main Menu (Zero web-app boxes!)
	_main_col = VBoxContainer.new()
	_main_col.position = Vector2(64, 286)
	_main_col.custom_minimum_size = Vector2(380, 0)
	_main_col.add_theme_constant_override("separation", 6)
	add_child(_main_col)

	var play_btn := UIStyle.make_game_menu_item("PLAY", Color(1.0, 0.20, 0.16), 44, true)
	play_btn.pressed.connect(func():
		GameManager.mode = GameManager.GameMode.ESCAPE
		get_tree().change_scene_to_file("res://scenes/main/game_world.tscn")
	)
	_main_col.add_child(play_btn)

	var endless_btn := UIStyle.make_game_menu_item("ENDLESS", Color(0.24, 0.90, 1.0), 34, true)
	endless_btn.pressed.connect(func():
		GameManager.mode = GameManager.GameMode.ENDLESS
		get_tree().change_scene_to_file("res://scenes/main/game_world.tscn")
	)
	_main_col.add_child(endless_btn)

	var opts_btn := UIStyle.make_game_menu_item("OPTIONS", Color(1.0, 0.80, 0.22), 34, true)
	opts_btn.pressed.connect(_show_options)
	_main_col.add_child(opts_btn)

	if not OS.has_feature("web") and not OS.has_feature("android"):
		var quit_btn := UIStyle.make_game_menu_item("QUIT", Color(0.75, 0.78, 0.84), 30, true)
		quit_btn.pressed.connect(func(): get_tree().quit())
		_main_col.add_child(quit_btn)

	# 5. Seamless In-Place Typographic Options Column (NO web modal popup!)
	_opts_col = VBoxContainer.new()
	_opts_col.position = Vector2(64, 268)
	_opts_col.custom_minimum_size = Vector2(460, 0)
	_opts_col.add_theme_constant_override("separation", 4)
	_opts_col.visible = false
	add_child(_opts_col)

	var gfx_btn := UIStyle.make_game_menu_item("GRAPHICS", Color(1.0, 0.65, 0.16), 28, true)
	gfx_btn.pressed.connect(func():
		SettingsManager.cycle_preset()
		_refresh_options()
	)
	_opts_col.add_child(gfx_btn)
	_opt_btns["gfx"] = gfx_btn

	if not OS.has_feature("web") and not OS.has_feature("android"):
		var fs_btn := UIStyle.make_game_menu_item("DISPLAY", Color(0.24, 0.90, 1.0), 28, true)
		fs_btn.pressed.connect(func():
			SettingsManager.toggle_fullscreen()
			_refresh_options()
		)
		_opts_col.add_child(fs_btn)
		_opt_btns["fs"] = fs_btn

	var diff_btn := UIStyle.make_game_menu_item("DIFFICULTY", Color(1.0, 0.26, 0.20), 28, true)
	diff_btn.pressed.connect(func():
		GameManager.difficulty = ((int(GameManager.difficulty) + 1) % 3) as GameManager.Difficulty
		_refresh_options()
	)
	_opts_col.add_child(diff_btn)
	_opt_btns["diff"] = diff_btn

	var trait_btn := UIStyle.make_game_menu_item("TRAIT", Color(0.28, 0.96, 0.52), 28, true)
	trait_btn.pressed.connect(func():
		var keys := SaveManager.unlocked_traits
		var idx := keys.find(GameManager.starting_trait)
		GameManager.starting_trait = keys[(idx + 1) % keys.size()]
		_refresh_options()
	)
	_opts_col.add_child(trait_btn)
	_opt_btns["trait"] = trait_btn

	var vol_btn := UIStyle.make_game_menu_item("VOLUME", Color(0.95, 0.96, 1.0), 26, true)
	vol_btn.pressed.connect(func():
		var nv := SettingsManager.master_volume + 0.15
		if nv > 1.05: nv = 0.0
		SettingsManager.master_volume = clampf(nv, 0.0, 1.0)
		SettingsManager.save_settings()
		_refresh_options()
	)
	_opts_col.add_child(vol_btn)
	_opt_btns["vol"] = vol_btn

	var intro_btn := UIStyle.make_game_menu_item("INTRO", Color(0.80, 0.84, 0.90), 26, true)
	intro_btn.pressed.connect(func():
		SettingsManager.skip_intro = not SettingsManager.skip_intro
		SettingsManager.save_settings()
		_refresh_options()
	)
	_opts_col.add_child(intro_btn)
	_opt_btns["intro"] = intro_btn

	var back_btn := UIStyle.make_game_menu_item("< BACK", Color(1.0, 0.22, 0.18), 30, true)
	back_btn.pressed.connect(_show_main)
	_opts_col.add_child(back_btn)

	# Minimal bottom-left record line (only if player has played before)
	if SaveManager.best_score > 0:
		var best := Label.new()
		best.text = "HIGH SCORE %d   //   KILLS %d" % [SaveManager.best_score, SaveManager.total_kills]
		best.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		best.offset_left = 64; best.offset_top = -36
		UIStyle.style_label(best, 13, Color(0.82, 0.85, 0.90, 0.58), false, 3)
		add_child(best)

	play_btn.grab_focus()
	_refresh_options()

func _show_options() -> void:
	_main_col.visible = false
	_opts_col.visible = true
	_refresh_options()
	(_opt_btns["gfx"] as Button).grab_focus()

func _show_main() -> void:
	_opts_col.visible = false
	_main_col.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if _opts_col.visible and event.is_action_pressed("pause"):
		_show_main()
		get_viewport().set_input_as_handled()

func _set_opt_label(key: String, text: String) -> void:
	if not _opt_btns.has(key): return
	UIStyle.set_menu_item_text(_opt_btns[key], text)

func _refresh_options() -> void:
	_set_opt_label("gfx", "GRAPHICS     < %s >" % SettingsManager.get_preset_name())
	if _opt_btns.has("fs"):
		var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		_set_opt_label("fs", "DISPLAY      < %s >" % ("FULLSCREEN" if is_fs else "WINDOWED"))
	var dnames := ["STANDARD", "NIGHTMARE", "HARDCORE"]
	_set_opt_label("diff", "DIFFICULTY   < %s >" % dnames[int(GameManager.difficulty)])
	var tdata: Dictionary = GameData.STARTING_TRAITS[GameManager.starting_trait]
	_set_opt_label("trait", "TRAIT        < %s >" % str(tdata["name"]))
	_set_opt_label("vol", "AUDIO        %s" % UIStyle.format_bar(SettingsManager.master_volume, 8))
	_set_opt_label("intro", "SKIP INTRO   < %s >" % ("ON" if SettingsManager.skip_intro else "OFF"))
