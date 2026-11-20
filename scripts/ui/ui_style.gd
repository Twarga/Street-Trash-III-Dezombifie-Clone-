class_name UIStyle
extends RefCounted

static var _font_display: Font
static var _font_tech: Font
static var _font_body: Font
static var _sh_skew: Shader
static var _sh_holo: Shader
static var _sh_fire: Shader

static func font_display() -> Font:
	if _font_display == null and ResourceLoader.exists("res://assets/fonts/Anton-Regular.ttf"):
		_font_display = load("res://assets/fonts/Anton-Regular.ttf")
	return _font_display

static func font_tech() -> Font:
	if _font_tech == null and ResourceLoader.exists("res://assets/fonts/ChakraPetch-Bold.ttf"):
		_font_tech = load("res://assets/fonts/ChakraPetch-Bold.ttf")
	return _font_tech

static func font_body() -> Font:
	if _font_body == null and ResourceLoader.exists("res://assets/fonts/ChakraPetch-SemiBold.ttf"):
		_font_body = load("res://assets/fonts/ChakraPetch-SemiBold.ttf")
	return _font_body

static func style_label(lbl: Label, size: int, col: Color, display: bool = false, outline_sz: int = 4) -> void:
	var f := font_display() if display else font_tech()
	if f:
		lbl.add_theme_font_override("font", f)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	if outline_sz > 0:
		lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.96))
		lbl.add_theme_constant_override("outline_size", outline_sz)

static func make_panel_box(border_col: Color, bg_col: Color = Color(0.045, 0.052, 0.075, 0.92), accent_left: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_width_left = 3 if accent_left else 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = border_col
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 2
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(0, 0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func make_tactical_button(text: String, accent: Color, height: int = 48, fsize: int = 20, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var f := font_display() if primary else font_tech()
	if f:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.06, 0.08))

	var base_bg := accent * Color(0.88, 0.88, 0.88, 0.96) if primary else Color(0.04, 0.05, 0.07, 0.72)
	var norm := StyleBoxFlat.new()
	norm.bg_color = base_bg
	norm.border_width_left = 3
	norm.border_width_right = 0
	norm.border_width_top = 0
	norm.border_width_bottom = 0
	norm.border_color = accent
	norm.corner_radius_top_left = 2
	norm.corner_radius_top_right = 2
	norm.corner_radius_bottom_left = 2
	norm.corner_radius_bottom_right = 2
	norm.shadow_color = Color(accent.r, accent.g, accent.b, 0.25 if primary else 0.12)
	norm.shadow_size = 0
	norm.content_margin_left = 18; norm.content_margin_right = 18

	var hov := norm.duplicate()
	hov.bg_color = accent.lightened(0.12) if primary else Color(accent.r * 0.28, accent.g * 0.28, accent.b * 0.32, 0.96)
	hov.border_color = accent.lightened(0.4)
	hov.shadow_color = Color(accent.r, accent.g, accent.b, 0.55)
	hov.shadow_size = 0

	var prs := hov.duplicate()
	prs.bg_color = accent.lightened(0.35)

	var dis := norm.duplicate()
	dis.bg_color = Color(0.08, 0.08, 0.10, 0.55)
	dis.border_color = Color(0.3, 0.32, 0.36, 0.5)

	b.add_theme_stylebox_override("normal", norm)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", prs)
	b.add_theme_stylebox_override("focus", hov)
	b.add_theme_stylebox_override("disabled", dis)

	b.mouse_entered.connect(func():
		AudioManager.play_sfx("card_hover", 0.98, 1.08, 0.42)
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.02, 1.02), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	b.mouse_exited.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD)
	)
	b.pressed.connect(func():
		AudioManager.play_sfx("card_confirm", 0.96, 1.06, 0.55)
	)
	return b

static func make_skew_bar(w: float, h: float, fill_col: Color, hi_col: Color, border_col: Color) -> ColorRect:
	if _sh_skew == null and ResourceLoader.exists("res://assets/shaders/ui_skew_bar.gdshader"):
		_sh_skew = load("res://assets/shaders/ui_skew_bar.gdshader")
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(w, h)
	var mat := ShaderMaterial.new()
	mat.shader = _sh_skew
	mat.set_shader_parameter("fill_color", fill_col)
	mat.set_shader_parameter("fill_hi", hi_col)
	mat.set_shader_parameter("border_color", border_col)
	mat.set_shader_parameter("fill_ratio", 1.0)
	mat.set_shader_parameter("ghost_ratio", 1.0)
	r.material = mat
	return r

static func make_holo_material(accent: Color, sheen: float = 0.45) -> ShaderMaterial:
	if _sh_holo == null and ResourceLoader.exists("res://assets/shaders/ui_holo_card.gdshader"):
		_sh_holo = load("res://assets/shaders/ui_holo_card.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = _sh_holo
	mat.set_shader_parameter("accent_color", accent)
	mat.set_shader_parameter("sheen_strength", sheen)
	mat.set_shader_parameter("hover_amount", 0.0)
	return mat

static func create_fire_3d_effect(scale_mult: float = 1.0) -> Node3D:
	if _sh_fire == null and ResourceLoader.exists("res://assets/shaders/fire_3d.gdshader"):
		_sh_fire = load("res://assets/shaders/fire_3d.gdshader")
	var root := Node3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = _sh_fire
	mat.set_shader_parameter("speed", randf_range(2.2, 3.1))
	mat.set_shader_parameter("intensity", 3.8)

	# 3 crossed flame planes (looks rich & volumetric from any oblique angle!)
	for ang in [0.0, 60.0, 120.0]:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.15 * scale_mult, 1.55 * scale_mult)
		mi.mesh = qm
		mi.material_override = mat
		mi.position = Vector3(0, 0.72 * scale_mult, 0)
		mi.rotation_degrees.y = ang
		root.add_child(mi)

	# Rising glowing spark embers (tiny bright streaks, NOT chunky cubes!)
	var sparks := CPUParticles3D.new()
	sparks.position = Vector3(0, 0.35 * scale_mult, 0)
	sparks.amount = 18
	sparks.lifetime = 1.15
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 28.0
	sparks.initial_velocity_min = 1.6 * scale_mult
	sparks.initial_velocity_max = 4.0 * scale_mult
	sparks.gravity = Vector3(0, 0.8, 0)
	var sm := BoxMesh.new()
	sm.size = Vector3(0.055, 0.055, 0.055) * scale_mult
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(1.0, 0.72, 0.2)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.62, 0.12)
	smat.emission_energy_multiplier = 8.0
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smat
	sparks.mesh = sm
	root.add_child(sparks)
	return root

static func make_game_menu_item(label_text: String, accent: Color = Color(1.0, 0.18, 0.16), fsize: int = 34, align_left: bool = true) -> Button:
	var b := Button.new()
	b.text = "  " + label_text
	b.set_meta("base_text", label_text)
	b.flat = false
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if align_left else HORIZONTAL_ALIGNMENT_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0, int(fsize * 1.42))
	var f := font_display()
	if f:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_color_override("font_color", Color(0.76, 0.80, 0.86, 0.78))
	b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	b.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.90, 0.30))
	b.add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.02, 0.96))
	b.add_theme_constant_override("outline_size", 6)

	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 8; empty.content_margin_right = 14
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(accent.r, accent.g, accent.b, 0.38)
	hov.border_width_left = 6
	hov.border_color = Color(1.0, 1.0, 1.0, 0.95)
	hov.content_margin_left = 18; hov.content_margin_right = 18
	hov.skew = Vector2(-0.14, 0.0)

	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("focus", hov)
	b.add_theme_stylebox_override("pressed", hov)

	var sync_txt := func(active: bool):
		var bt: String = str(b.get_meta("base_text", label_text))
		b.text = ("> " + bt) if active else ("  " + bt)
	b.mouse_entered.connect(func():
		AudioManager.play_sfx("card_hover", 0.95, 1.08, 0.45)
		b.grab_focus()
		sync_txt.call(true)
	)
	b.mouse_exited.connect(func():
		sync_txt.call(b.has_focus())
	)
	b.focus_entered.connect(func(): sync_txt.call(true))
	b.focus_exited.connect(func(): sync_txt.call(false))
	b.pressed.connect(func():
		AudioManager.play_sfx("card_confirm", 0.92, 1.04, 0.62)
	)
	return b

static func set_menu_item_text(b: Button, new_text: String) -> void:
	b.set_meta("base_text", new_text)
	b.text = ("> " + new_text) if b.has_focus() else ("  " + new_text)

static func format_bar(val: float, steps: int = 8) -> String:
	var filled := clampi(int(roundf(val * float(steps))), 0, steps)
	return "[" + "=".repeat(filled) + "-".repeat(steps - filled) + "] %d%%" % int(roundf(val * 100.0))
