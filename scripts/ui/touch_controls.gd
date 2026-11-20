class_name TouchControls
extends CanvasLayer

var player_ref: PlayerController = null

var _enabled: bool = false
var _pad: Control

# Multi-touch finger tracking
var _move_finger: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_cur: Vector2 = Vector2.ZERO
var _move_vec: Vector2 = Vector2.ZERO

var _aim_finger: int = -1
var _aim_origin: Vector2 = Vector2.ZERO
var _aim_cur: Vector2 = Vector2.ZERO
var _aim_vec: Vector2 = Vector2.ZERO
var _aim_firing: bool = false

var _dash_finger: int = -1
var _dash_pressed: bool = false
var _gun_finger: int = -1

const STICK_RADIUS: float = 68.0
const KNOB_RADIUS: float = 26.0
const DASH_RADIUS: float = 34.0
const PAUSE_SIZE: Vector2 = Vector2(44.0, 34.0)

class TouchOverlay extends Control:
	var owner_layer: TouchControls
	func _draw() -> void:
		if owner_layer == null:
			return
		var vps: Vector2 = get_viewport_rect().size
		# Resting ghost positions
		var def_move := Vector2(128.0, vps.y - 122.0)
		var def_aim := Vector2(vps.x - 128.0, vps.y - 122.0)
		var dash_pos := owner_layer.get_dash_center(vps)
		var pause_rect := owner_layer.get_pause_rect(vps)

		# Left Move Stick
		var m_orig: Vector2 = owner_layer._move_origin if owner_layer._move_finger != -1 else def_move
		var m_knob: Vector2 = m_orig + owner_layer._move_vec * STICK_RADIUS
		var m_alpha: float = 0.52 if owner_layer._move_finger != -1 else 0.22
		draw_circle(m_orig, STICK_RADIUS, Color(0.05, 0.07, 0.10, m_alpha * 0.45))
		draw_arc(m_orig, STICK_RADIUS, 0.0, TAU, 36, Color(0.28, 0.94, 1.0, m_alpha), 2.0, true)
		var sprint_col := Color(1.0, 0.78, 0.18, m_alpha + 0.25) if owner_layer._move_vec.length() > 0.92 else Color(0.35, 0.96, 1.0, m_alpha + 0.22)
		draw_circle(m_knob, KNOB_RADIUS, sprint_col)

		# Right Aim + Fire Stick
		var a_orig: Vector2 = owner_layer._aim_origin if owner_layer._aim_finger != -1 else def_aim
		var a_knob: Vector2 = a_orig + owner_layer._aim_vec * STICK_RADIUS
		var a_alpha: float = 0.58 if owner_layer._aim_finger != -1 else 0.22
		var a_col := Color(1.0, 0.22, 0.20, a_alpha) if owner_layer._aim_firing else Color(0.95, 0.35, 0.25, a_alpha)
		draw_circle(a_orig, STICK_RADIUS, Color(0.10, 0.04, 0.05, a_alpha * 0.45))
		draw_arc(a_orig, STICK_RADIUS, 0.0, TAU, 36, a_col, 2.0, true)
		draw_circle(a_knob, KNOB_RADIUS, Color(1.0, 0.28, 0.22, a_alpha + 0.22))

		# Dash Button
		var d_ready: bool = true
		var d_cd_ratio: float = 0.0
		if owner_layer.player_ref:
			d_cd_ratio = clampf(owner_layer.player_ref.get_dash_cooldown_ratio(), 0.0, 1.0)
			d_ready = d_cd_ratio <= 0.01 and GameManager.stamina >= 18.0
		var d_bg := Color(0.12, 0.78, 0.95, 0.45 if owner_layer._dash_pressed else 0.28) if d_ready else Color(0.12, 0.14, 0.18, 0.28)
		var d_ring := Color(0.30, 0.96, 1.0, 0.75 if d_ready else 0.28)
		draw_circle(dash_pos, DASH_RADIUS, d_bg)
		draw_arc(dash_pos, DASH_RADIUS, 0.0, TAU, 32, d_ring, 2.2, true)
		if d_cd_ratio > 0.01:
			draw_arc(dash_pos, DASH_RADIUS + 3.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - d_cd_ratio), 28, Color(1.0, 0.80, 0.18, 0.8), 3.0, true)
		var f: Font = UIStyle.font_tech()
		if f:
			draw_string(f, dash_pos + Vector2(-19.0, 5.0), "DASH", HORIZONTAL_ALIGNMENT_CENTER, 38.0, 13, Color(1.0, 1.0, 1.0, 0.88 if d_ready else 0.45))

		# Weapon Switch Button (GUN)
		var gun_pos := owner_layer.get_gun_center(vps)
		var g_multi: bool = GameManager.unlocked_weapons.size() > 1
		draw_circle(gun_pos, 30.0, Color(0.75, 0.14, 0.14, 0.42 if g_multi else 0.18))
		draw_arc(gun_pos, 30.0, 0.0, TAU, 28, Color(1.0, 0.28, 0.24, 0.80 if g_multi else 0.25), 2.0, true)
		if f:
			draw_string(f, gun_pos + Vector2(-18.0, 5.0), "GUN", HORIZONTAL_ALIGNMENT_CENTER, 36.0, 12, Color(1.0, 1.0, 1.0, 0.90 if g_multi else 0.4))

		# Pause Button (top center-left of timer so it never overlaps gears/weapon)
		draw_rect(pause_rect, Color(0.05, 0.06, 0.09, 0.48), true)
		draw_rect(pause_rect, Color(1.0, 1.0, 1.0, 0.30), false, 1.5)
		var px: float = pause_rect.position.x + pause_rect.size.x * 0.5
		var py: float = pause_rect.position.y + pause_rect.size.y * 0.5
		draw_rect(Rect2(px - 6.0, py - 7.0, 4.0, 14.0), Color(1.0, 1.0, 1.0, 0.85), true)
		draw_rect(Rect2(px + 2.0, py - 7.0, 4.0, 14.0), Color(1.0, 1.0, 1.0, 0.85), true)

static func is_touch_platform() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

func get_dash_center(vps: Vector2) -> Vector2:
	return Vector2(vps.x - 242.0, vps.y - 78.0)

func get_gun_center(vps: Vector2) -> Vector2:
	return Vector2(vps.x - 242.0, vps.y - 160.0)

func get_pause_rect(vps: Vector2) -> Rect2:
	return Rect2(vps.x * 0.5 + 78.0, 12.0, PAUSE_SIZE.x, PAUSE_SIZE.y)

func _ready() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = is_touch_platform()
	visible = _enabled

	_pad = TouchOverlay.new()
	(_pad as TouchOverlay).owner_layer = self
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)

func _reset_sticks() -> void:
	_move_finger = -1
	_move_vec = Vector2.ZERO
	_aim_finger = -1
	_aim_vec = Vector2.ZERO
	_aim_firing = false
	_dash_finger = -1
	_dash_pressed = false
	if player_ref:
		player_ref.touch_move = Vector2.ZERO
		player_ref.touch_aim = Vector2.ZERO
		player_ref.touch_firing = false
		player_ref.touch_sprinting = false

func _process(_delta: float) -> void:
	if not _enabled:
		return
	var active_play: bool = GameManager.run_active and not GameManager.intro_playing and not GameManager.is_drafting and not get_tree().paused
	visible = active_play
	if not active_play:
		if _move_finger != -1 or _aim_finger != -1:
			_reset_sticks()
		return
	if player_ref:
		player_ref.touch_active = true
		player_ref.touch_move = _move_vec
		player_ref.touch_sprinting = _move_vec.length() > 0.92
		player_ref.touch_aim = _aim_vec
		player_ref.touch_firing = _aim_firing
	_pad.queue_redraw()

func _input(event: InputEvent) -> void:
	if not _enabled or not visible:
		return
	var vps: Vector2 = get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var ev: InputEventScreenTouch = event as InputEventScreenTouch
		if ev.pressed:
			# 1. Pause button tap
			if get_pause_rect(vps).has_point(ev.position):
				_trigger_pause()
				get_viewport().set_input_as_handled()
				return
			# 1b. Weapon switch button tap
			if ev.position.distance_to(get_gun_center(vps)) <= 42.0:
				_gun_finger = ev.index
				GameManager.cycle_weapon(1)
				get_viewport().set_input_as_handled()
				return
			# 2. Dash button tap
			if ev.position.distance_to(get_dash_center(vps)) <= DASH_RADIUS + 16.0:
				_dash_finger = ev.index
				_dash_pressed = true
				if player_ref:
					player_ref.trigger_touch_dash()
				get_viewport().set_input_as_handled()
				return
			# 3. Left half -> Move stick
			if ev.position.x < vps.x * 0.50 and _move_finger == -1 and ev.position.y > 70.0:
				_move_finger = ev.index
				_move_origin = Vector2(
					clampf(ev.position.x, STICK_RADIUS + 18.0, vps.x * 0.45),
					clampf(ev.position.y, 120.0, vps.y - STICK_RADIUS - 18.0)
				)
				_move_cur = ev.position
				_update_move_vec()
				get_viewport().set_input_as_handled()
				return
			# 4. Right half -> Aim + Fire stick
			if ev.position.x >= vps.x * 0.50 and _aim_finger == -1 and ev.position.y > 70.0:
				_aim_finger = ev.index
				_aim_origin = Vector2(
					clampf(ev.position.x, vps.x * 0.55, vps.x - STICK_RADIUS - 18.0),
					clampf(ev.position.y, 120.0, vps.y - STICK_RADIUS - 18.0)
				)
				_aim_cur = ev.position
				_update_aim_vec()
				get_viewport().set_input_as_handled()
				return
		else:
			if ev.index == _move_finger:
				_move_finger = -1
				_move_vec = Vector2.ZERO
			elif ev.index == _aim_finger:
				_aim_finger = -1
				_aim_vec = Vector2.ZERO
				_aim_firing = false
			elif ev.index == _dash_finger:
				_dash_finger = -1
				_dash_pressed = false
	elif event is InputEventScreenDrag:
		var ev: InputEventScreenDrag = event as InputEventScreenDrag
		if ev.index == _move_finger:
			_move_cur = ev.position
			_update_move_vec()
			get_viewport().set_input_as_handled()
		elif ev.index == _aim_finger:
			_aim_cur = ev.position
			_update_aim_vec()
			get_viewport().set_input_as_handled()

func _update_move_vec() -> void:
	var diff: Vector2 = _move_cur - _move_origin
	var dist: float = diff.length()
	if dist < 8.0:
		_move_vec = Vector2.ZERO
	else:
		_move_vec = diff.normalized() * minf(1.0, dist / STICK_RADIUS)

func _update_aim_vec() -> void:
	var diff: Vector2 = _aim_cur - _aim_origin
	var dist: float = diff.length()
	if dist < 12.0:
		_aim_vec = Vector2.ZERO
		_aim_firing = false
	else:
		_aim_vec = diff.normalized() * minf(1.0, dist / STICK_RADIUS)
		_aim_firing = true

func _trigger_pause() -> void:
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
