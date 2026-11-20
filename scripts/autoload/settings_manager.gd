extends Node

signal settings_changed

const SETTINGS_PATH := "user://settings.json"

# 0 = PERFORMANCE, 1 = CINEMATIC (Default!)
var graphics_preset: int = 1
var master_volume: float = 0.85
var music_volume: float = 0.62
var sfx_volume: float = 0.88
var vo_volume: float = 0.95
var screen_shake_scale: float = 1.0
var show_subtitles: bool = true
var skip_intro: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_audio()
	if not OS.has_feature("web") and not OS.has_feature("android") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		graphics_preset = 1
		return
	var txt := FileAccess.get_file_as_string(SETTINGS_PATH)
	var data = JSON.parse_string(txt)
	if typeof(data) == TYPE_DICTIONARY:
		var raw_p := int(data.get("graphics_preset", 1))
		graphics_preset = 0 if raw_p <= 0 else 1
		master_volume = clampf(float(data.get("master_volume", 0.85)), 0.0, 1.0)
		music_volume = clampf(float(data.get("music_volume", 0.62)), 0.0, 1.0)
		sfx_volume = clampf(float(data.get("sfx_volume", 0.88)), 0.0, 1.0)
		vo_volume = clampf(float(data.get("vo_volume", 0.95)), 0.0, 1.0)
		screen_shake_scale = clampf(float(data.get("screen_shake_scale", 1.0)), 0.0, 1.5)
		show_subtitles = bool(data.get("show_subtitles", true))
		skip_intro = bool(data.get("skip_intro", false))

func save_settings() -> void:
	var data := {
		"graphics_preset": graphics_preset,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"vo_volume": vo_volume,
		"screen_shake_scale": screen_shake_scale,
		"show_subtitles": show_subtitles,
		"skip_intro": skip_intro,
	}
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
	apply_audio()
	settings_changed.emit()

func apply_audio() -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(master_volume, 0.0001)))

func apply_to_environment(env: Environment) -> void:
	if env == null:
		return
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.28
	env.glow_enabled = true
	env.glow_bloom = 0.20
	env.glow_hdr_threshold = 0.92
	env.glow_hdr_scale = 1.4
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.06
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.14

	# Always disable heavy GPU killers (SSIL + 3D Froxel Volumetric Fog) -> silky 60+ FPS!
	env.ssil_enabled = false
	env.volumetric_fog_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.11, 0.14, 0.21)
	env.fog_density = 0.009

	if OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("mobile") or graphics_preset == 0:
		env.ssr_enabled = false
		env.ssao_enabled = false
		env.glow_intensity = 0.85
		return

	# CINEMATIC (Fast 60+ FPS on Desktop): Crisp fast SSR wet street reflections + Lightweight SSAO + ACES Bloom!
	env.ssr_enabled = true
	env.ssr_max_steps = 18
	env.ssr_fade_in = 0.12
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.30
	env.ssao_enabled = true
	env.ssao_radius = 0.95
	env.ssao_intensity = 1.15
	env.glow_intensity = 1.02

func get_preset_name() -> String:
	return "CINEMATIC" if graphics_preset >= 1 else "PERFORMANCE"

func cycle_preset() -> void:
	graphics_preset = 0 if graphics_preset >= 1 else 1
	save_settings()

func toggle_fullscreen() -> void:
	if OS.has_feature("web") or OS.has_feature("android"):
		return
	var cur := DisplayServer.window_get_mode()
	if cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
