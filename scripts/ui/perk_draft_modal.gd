class_name PerkDraftModal
extends CanvasLayer

var _root: Control
var _cards_row: HBoxContainer
var _redraw_btn: Button
var _skip_btn: Button
var _choices: Array[Dictionary] = []
var _selected_idx: int = 1
var _card_panels: Array[PanelContainer] = []
var _holo_mats: Array[ShaderMaterial] = []

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	GameManager.level_up_triggered.connect(_open_draft)

func _process(_delta: float) -> void:
	if not visible:
		return
	var vps := get_viewport().get_visible_rect().size
	var muv := get_viewport().get_mouse_position() / Vector2(maxf(1.0, vps.x), maxf(1.0, vps.y))
	for i in range(_holo_mats.size()):
		var mat := _holo_mats[i]
		mat.set_shader_parameter("mouse_uv", muv)
		mat.set_shader_parameter("hover_amount", 1.0 if i == _selected_idx else 0.12)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.024, 0.04, 0.88)
	_root.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	_root.add_child(vbox)

	var hdr_box := VBoxContainer.new()
	hdr_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hdr_box)

	var sub_tag := Label.new()
	sub_tag.text = ""
	sub_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(sub_tag, 14, Color(0.28, 0.96, 1.0), false, 3)
	hdr_box.add_child(sub_tag)

	var title := Label.new()
	title.text = "CHOOSE A PERK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(title, 34, Color(1.0, 0.20, 0.18), true, 6)
	hdr_box.add_child(title)

	_cards_row = HBoxContainer.new()
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override("separation", 18)
	vbox.add_child(_cards_row)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 20)
	vbox.add_child(footer)

	var hint := Label.new()
	hint.text = "1-3 / click"
	UIStyle.style_label(hint, 14, Color(0.75, 0.82, 0.90), false, 2)
	footer.add_child(hint)

	_redraw_btn = UIStyle.make_tactical_button("REDRAW 3 [R]", Color(0.22, 0.82, 1.0), 34, 13, false)
	_redraw_btn.custom_minimum_size = Vector2(140, 34)
	_redraw_btn.pressed.connect(_on_redraw)
	footer.add_child(_redraw_btn)

	_skip_btn = UIStyle.make_tactical_button("SKIP [X]", Color(0.65, 0.68, 0.75), 34, 13, false)
	_skip_btn.custom_minimum_size = Vector2(90, 34)
	_skip_btn.pressed.connect(_on_skip)
	footer.add_child(_skip_btn)

func _open_draft(_lvl: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	visible = true
	_roll_and_render()

func _roll_and_render() -> void:
	_choices = GameManager.roll_perk_choices(3)
	_selected_idx = mini(1, _choices.size() - 1)
	_redraw_btn.text = "REDRAW %d [R]" % GameManager.redraws_left
	_redraw_btn.disabled = GameManager.redraws_left <= 0

	for c in _cards_row.get_children():
		c.queue_free()
	_card_panels.clear()
	_holo_mats.clear()

	for i in range(_choices.size()):
		var p: Dictionary = _choices[i]
		var card := _build_card(p, i)
		_cards_row.add_child(card)
		_card_panels.append(card)
		# Staggered AAA fly-in overshoot!
		card.modulate.a = 0.0
		card.scale = Vector2(0.78, 0.78)
		card.pivot_offset = card.custom_minimum_size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "modulate:a", 1.0, 0.22).set_delay(float(i) * 0.06)
		tw.tween_property(card, "scale", Vector2(1.04, 1.04) if i == _selected_idx else Vector2(0.96, 0.96), 0.28).set_delay(float(i) * 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_card(p: Dictionary, idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(224, 310)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var cat_col: Color = GameData.CATEGORY_COLORS.get(p["cat"], Color.WHITE)
	var rar_col: Color = GameData.RARITY_COLORS.get(p["rarity"], Color.WHITE)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.062, 0.088, 0.98)
	sb.border_width_left = 2; sb.border_width_right = 2; sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = rar_col
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	sb.shadow_color = Color(rar_col.r, rar_col.g, rar_col.b, 0.38)
	sb.shadow_size = 0
	sb.content_margin_left = 10; sb.content_margin_right = 10; sb.content_margin_top = 10; sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	# Category & Rarity Ribbon
	var hdr := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = cat_col
	hsb.corner_radius_top_right = 2; hsb.corner_radius_bottom_left = 2
	hsb.content_margin_left = 10; hsb.content_margin_right = 10; hsb.content_margin_top = 4; hsb.content_margin_bottom = 4
	hdr.add_theme_stylebox_override("panel", hsb)
	vb.add_child(hdr)

	var hrow := HBoxContainer.new()
	hdr.add_child(hrow)
	var hcat := Label.new()
	hcat.text = p["cat"]
	hcat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.style_label(hcat, 13, Color(0.04, 0.04, 0.06), true, 0)
	hrow.add_child(hcat)
	var hrar := Label.new()
	hrar.text = p["rarity"]
	UIStyle.style_label(hrar, 10, Color(0.04, 0.04, 0.06), false, 0)
	hrow.add_child(hrar)

	# Holographic Comic Illustration
	var art_frame := PanelContainer.new()
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color(0.02, 0.02, 0.03)
	asb.border_width_left = 2; asb.border_width_right = 2; asb.border_width_top = 2; asb.border_width_bottom = 2
	asb.border_color = Color(cat_col.r, cat_col.g, cat_col.b, 0.65)
	art_frame.add_theme_stylebox_override("panel", asb)
	vb.add_child(art_frame)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(204, 130)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var art_path: String = GameData.CATEGORY_ART.get(p["cat"], "")
	if ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	var holo_s := 0.72 if p["rarity"] in ["EPIC", "CHAOS", "DUALITY"] else 0.40
	var hmat := UIStyle.make_holo_material(rar_col, holo_s)
	art.material = hmat
	_holo_mats.append(hmat)
	art_frame.add_child(art)

	# Bold Grindhouse Title
	var nm := Label.new()
	nm.text = p["name"]
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(nm, 18, Color(1.0, 0.99, 0.96), true, 4)
	vb.add_child(nm)

	# Exact Stat Delta / Modifier Text
	var desc := Label.new()
	desc.text = GameManager.format_perk_delta(p).replace("->", " > ")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.style_label(desc, 12, Color(0.55, 0.98, 0.75) if not p.get("special", false) else Color(0.95, 0.90, 0.72), false, 2)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(desc)


	_ignore_mouse_recursive(vb)
	panel.mouse_entered.connect(func():
		_selected_idx = idx
		AudioManager.play_sfx("card_hover", 0.95, 1.05, 0.45)
		_update_highlight()
	)
	panel.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_confirm(idx)
	)
	return panel

func _update_highlight() -> void:
	for i in range(_card_panels.size()):
		var p := _card_panels[i]
		var is_sel := (i == _selected_idx)
		p.pivot_offset = p.custom_minimum_size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "scale", Vector2(1.04, 1.04) if is_sel else Vector2(0.96, 0.96), 0.12).set_trans(Tween.TRANS_BACK)
		tw.tween_property(p, "modulate", Color(1.06, 1.06, 1.08, 1.0) if is_sel else Color(0.76, 0.78, 0.84, 1.0), 0.12)

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_selected_idx = posmod(_selected_idx - 1, _choices.size())
		AudioManager.play_sfx("card_hover", 0.95, 1.05, 0.45)
		_update_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_selected_idx = posmod(_selected_idx + 1, _choices.size())
		AudioManager.play_sfx("card_hover", 0.95, 1.05, 0.45)
		_update_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_confirm(_selected_idx)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_redraw"):
		_on_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_skip"):
		_on_skip()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_1 and _choices.size() >= 1: _confirm(0)
		elif event.keycode == KEY_2 and _choices.size() >= 2: _confirm(1)
		elif event.keycode == KEY_3 and _choices.size() >= 3: _confirm(2)

func _confirm(idx: int) -> void:
	if idx < 0 or idx >= _choices.size(): return
	AudioManager.play_sfx("card_confirm", 0.98, 1.04, 0.85)
	var id: String = _choices[idx]["id"]
	visible = false
	get_tree().paused = false
	GameManager.apply_perk(id)
	GameManager.finish_draft()

func _on_redraw() -> void:
	if GameManager.redraws_left <= 0: return
	GameManager.redraws_left -= 1
	AudioManager.play_sfx("card_redraw", 0.95, 1.08, 0.75)
	_roll_and_render()

func _on_skip() -> void:
	AudioManager.play_sfx("card_hover", 0.8, 0.9, 0.6)
	visible = false
	get_tree().paused = false
	GameManager.finish_draft()

func _ignore_mouse_recursive(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse_recursive(c)
