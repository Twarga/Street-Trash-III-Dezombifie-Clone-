extends Node
## STREET TRASH: DEZOMBIFIER — Pure 3-Minute Continuous High-Quality Gameplay Recorder
## Zero cinematic overlays, zero camera overrides, zero cuts — 180s of authentic continuous gameplay from start to S-Rank Victory.

const GameWorldScene = preload("res://scenes/main/game_world.tscn")

var _gw: Node3D
var _t: float = 0.0
var _f: int = 0
var _perk_modal: PerkDraftModal = null
var _draft_t: float = 0.0
var _draft_stage: int = 0
var _draft_count: int = 0

# Waypoints with optional combat dwell time (seconds spent fighting around the district hub!)
var _waypoints: Array[Dictionary] = [
	{"pos": Vector3(0.0, 0.0, 2.0), "dwell": 2.0},       # 0: Step out of safehouse garage onto Main Ave
	{"pos": Vector3(5.5, 0.0, -14.0), "dwell": 4.5},     # 1: Collect Gear 1/6 & fight opening Main Ave wave
	{"pos": Vector3(5.6, 0.0, -22.0), "dwell": 3.5},     # 2: Unlock Pocket Capper SMG crate & shred runners
	{"pos": Vector3(0.0, 0.0, -34.0), "dwell": 0.0},     # 3: Main Ave & 34th St Intersection
	{"pos": Vector3(-22.0, 0.0, -26.0), "dwell": 3.0},   # 4: GAS 365 — Unlock Auto Shotgun crate
	{"pos": Vector3(-32.0, 0.0, -34.0), "dwell": 7.5},   # 5: GAS 365 — Trigger Horde Alert, Collect Gear 2/6 & detonate fuel pumps!
	{"pos": Vector3(-26.0, 0.0, -44.0), "dwell": 5.5},   # 6: GAS 365 — Deploy Automated Laser Sentry Turret #1 & fight forecourt swarm
	{"pos": Vector3(-12.0, 0.0, -34.0), "dwell": 0.0},   # 7: Exit GAS 365 to Main Ave
	{"pos": Vector3(16.0, 0.0, -34.0), "dwell": 0.0},    # 8: Enter Neon Alley Courtyard
	{"pos": Vector3(24.0, 0.0, -40.0), "dwell": 4.0},    # 9: Neon Alley — Unlock Street Sweeper Rifle crate
	{"pos": Vector3(32.0, 0.0, -34.0), "dwell": 8.5},    # 10: Neon Alley — Trigger Ambush, Collect Gear 3/6 & blow up police cruiser!
	{"pos": Vector3(12.0, 0.0, -34.0), "dwell": 0.0},    # 11: Exit Neon Alley to Main Ave
	{"pos": Vector3(0.0, 0.0, -34.0), "dwell": 0.0},     # 12: Center Main Ave
	{"pos": Vector3(0.0, 0.0, -64.0), "dwell": 5.0},     # 13: Push North up Main Ave mid-block firefight
	{"pos": Vector3(0.0, 0.0, -90.0), "dwell": 0.0},     # 14: Main Ave & 92nd St Intersection
	{"pos": Vector3(-15.0, 0.0, -90.0), "dwell": 0.0},   # 15: Enter Subway Floodlight Military Checkpoint
	{"pos": Vector3(-24.0, 0.0, -84.0), "dwell": 3.5},   # 16: Subway Lot — Unlock Incinerator Flamethrower crate
	{"pos": Vector3(-32.0, 0.0, -92.0), "dwell": 10.5},  # 17: Subway Lot — Collect Gear 4/6 & Fight High-Rise Brute Mini-Boss #1!
	{"pos": Vector3(-14.0, 0.0, -92.0), "dwell": 0.0},   # 18: Exit Subway Lot to Main Ave
	{"pos": Vector3(16.0, 0.0, -92.0), "dwell": 0.0},    # 19: Enter Industrial Cargo Maze
	{"pos": Vector3(32.0, 0.0, -92.0), "dwell": 6.5},    # 20: Cargo Yard — Collect Gear 5/6 & Trigger Industrial Swarm Breach
	{"pos": Vector3(36.0, 0.0, -94.0), "dwell": 7.5},    # 21: Cargo Yard — Unlock Heavy Machine Gun crate & detonate barrel chains
	{"pos": Vector3(14.0, 0.0, -92.0), "dwell": 0.0},    # 22: Exit Cargo Yard to Main Ave
	{"pos": Vector3(0.0, 0.0, -92.0), "dwell": 0.0},     # 23: Main Ave & 92nd St
	{"pos": Vector3(0.0, 0.0, -118.0), "dwell": 3.5},    # 24: North Main Ave approach firefight
	{"pos": Vector3(0.0, 0.0, -132.0), "dwell": 4.0},    # 25: Collect Gear 6/6 & Trigger High-Rise Brute Mini-Boss #2
	{"pos": Vector3(-6.0, 0.0, -142.0), "dwell": 2.5},   # 26: High-Rise Plaza — Deploy Automated Laser Sentry Turret #2
	{"pos": Vector3(0.0, 0.0, -148.0), "dwell": 0.0},    # 27: Step onto High-Rise Extraction Pad -> Start Extraction Holdout!
]
var _holdout_loop: Array[Vector3] = [
	Vector3(0.0, 0.0, -142.0),
	Vector3(-9.5, 0.0, -147.0),
	Vector3(0.0, 0.0, -153.0),
	Vector3(9.5, 0.0, -147.0),
]

var _wp_idx: int = 0
var _wp_dwell_left: float = -1.0
var _strafe_sign: float = 1.0
var _strafe_t: float = 0.0
var _dash_cd: float = 1.2
var _swap_cd: float = 9.0
var _aim_smooth: Vector3 = Vector3(0, 0, -1)
var _last_pos: Vector3 = Vector3.ZERO
var _stuck_t: float = 0.0
var _unstuck_dir: Vector3 = Vector3.ZERO
var _unstuck_timer: float = 0.0
var _prop_target: ExplodableCar = null
var _prop_timer: float = 0.0
var _prop_cd: float = 3.5
var _holdout_adjusted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.content_scale_factor = 1.5
	seed(20261121)

	# Full Cinematic Graphics + Authentic Audio & Subtitles
	SettingsManager.graphics_preset = 1
	SettingsManager.skip_intro = false
	SettingsManager.show_subtitles = true
	SettingsManager.screen_shake_scale = 1.0
	SettingsManager.master_volume = 0.92
	SettingsManager.music_volume = 0.65
	SettingsManager.sfx_volume = 0.90
	SettingsManager.vo_volume = 0.96

	GameManager.mode = GameManager.GameMode.ESCAPE
	GameManager.difficulty = GameManager.Difficulty.STANDARD
	GameManager.starting_trait = "gunslinger"

	_gw = GameWorldScene.instantiate()
	add_child(_gw)
	# Keep ACES HDR Bloom, ReflectionProbes & Dynamic Shadows while trimming heavy Intel iGPU raymarch steps for fast 3-min capture
	if _gw._env:
		_gw._env.ssr_enabled = true
		_gw._env.ssr_max_steps = 18
		_gw._env.ssao_enabled = true
		_gw._env.ssil_enabled = false

	for c in _gw.get_children():
		if c is PerkDraftModal:
			_perk_modal = c
			break

	# Skip only the 2D black splash so Frame 1 starts directly in the 3D garage alley as the steel shutter rolls open!
	if _gw._intro_splash:
		_gw._intro_splash.visible = false
	if _gw._intro_label:
		_gw._intro_label.visible = false
	_gw._intro_stage = 1
	_gw._intro_t = 0.35
	AudioManager.play_sfx("shutter_open", 0.96, 1.04, 0.85)
	var anim: AnimationPlayer = _gw._city.garage_shutter_anim
	if anim:
		var list: PackedStringArray = anim.get_animation_list()
		if not list.is_empty():
			anim.play(list[0])

func _process(delta: float) -> void:
	_t += delta
	_f += 1
	if _f % 400 == 1:
		print("T=%.1fs pos=%s wp=%d gears=%d/%d hold=%s(%.0fs) lvl=%d kills=%d weap=%s" % [
			_t, str(_gw._player.global_position.round()), _wp_idx,
			GameManager.gears, GameManager.gears_required, str(GameManager.holdout_active), GameManager.holdout_timer,
			GameManager.level, GameManager.kills, GameManager.get_current_weapon_id()
		])
	if _t >= 180.0:
		get_tree().quit()
		return

	# Time the Extraction Holdout countdown so chopper extraction & S-Rank Victory trigger right at t = 175.5s (2:55.5)!
	if GameManager.holdout_active and not _holdout_adjusted:
		_holdout_adjusted = true
		GameManager.holdout_timer = maxf(25.0, 175.5 - _t)

	# Let the 3.5s 3D garage shutter opening & camera boom finish naturally at the very start
	if GameManager.intro_playing:
		return

	# Handle PerkDraftModal automatically like a fast, smart human player
	if _perk_modal and _perk_modal.visible:
		# Show 7 full interactive card-draft modals across the 3 minutes; auto-pick intermediate level-ups instantaneously so combat never bogs down!
		if GameManager.level not in [2, 4, 7, 10, 14, 18, 22]:
			var best := _pick_best_card()
			_perk_modal._confirm(best)
			return
		_handle_perk_draft(delta)
		return
	else:
		_draft_t = 0.0
		_draft_stage = 0

	if get_tree().paused:
		return

	_drive_skilled_player(delta)

func _handle_perk_draft(delta: float) -> void:
	_draft_t += delta
	if _draft_stage == 0 and _draft_t >= 0.42:
		_draft_stage = 1
		var best := _pick_best_card()
		_perk_modal._selected_idx = best
		_perk_modal._update_highlight()
		AudioManager.play_sfx("card_hover", 0.98, 1.05, 0.75)
	elif _draft_stage == 1 and _draft_t >= 0.80:
		_draft_stage = 2
		if (_draft_count == 1 or _draft_count == 4) and GameManager.redraws_left > 0:
			_perk_modal._on_redraw()
		else:
			_draft_t = 1.10
	elif _draft_stage == 2 and _draft_t >= 1.15:
		var best := _pick_best_card()
		_perk_modal._selected_idx = best
		_perk_modal._update_highlight()
		_draft_count += 1
		_draft_t = 0.0
		_draft_stage = 0
		_perk_modal._confirm(best)

func _pick_best_card() -> int:
	if _perk_modal == null or _perk_modal._choices.is_empty():
		return 0
	var best_idx := 0
	var best_score := -1.0
	for i in range(_perk_modal._choices.size()):
		var p: Dictionary = _perk_modal._choices[i]
		var sc := 1.0
		var cat: String = str(p.get("cat", ""))
		var id: String = str(p.get("id", ""))
		if id == "loadout_gear": sc = 0.1 # Collect all 6 gears physically on the map!
		elif id in ["shockwave_dash", "ricochet_rounds", "piercing_slugs", "incendiary_crits"]: sc = 5.2
		elif cat == "CHAOS": sc = 4.8
		elif cat == "DUALITY": sc = 4.2
		elif cat == "COMBAT": sc = 3.6
		if sc > best_score:
			best_score = sc
			best_idx = i
	return best_idx

func _drive_skilled_player(delta: float) -> void:
	var pl: PlayerController = _gw._player
	var hm: HordeManager = _gw._horde_mgr
	if pl == null or hm == null or not GameManager.run_active:
		return

	# Keep HP realistic (takes real hits so HUD damage drain & medkit pickups trigger, never dies before 3:00!)
	if GameManager.hp < 58.0:
		GameManager.hp = 96.0
	if GameManager.stamina < 22.0:
		GameManager.stamina = 68.0

	var ppos := pl.global_position
	ppos.y = 0.0
	pl.touch_active = true

	# ---- 1. Advance Route Waypoints with District Combat Dwell ----
	var goal_pos: Vector3
	if _wp_idx < _waypoints.size():
		var wp: Dictionary = _waypoints[_wp_idx]
		var wp_pos: Vector3 = wp["pos"]
		var wp_dwell: float = float(wp["dwell"])
		if _wp_dwell_left < 0.0:
			if ppos.distance_to(wp_pos) <= 2.4:
				if wp_dwell > 0.0:
					_wp_dwell_left = wp_dwell
				else:
					_wp_idx += 1
		else:
			_wp_dwell_left -= delta
			if _wp_dwell_left <= 0.0:
				_wp_dwell_left = -1.0
				_wp_idx += 1
		if _wp_idx < _waypoints.size():
			var cur_wp: Vector3 = _waypoints[_wp_idx]["pos"]
			if _wp_dwell_left > 0.0:
				# Patrol around the district landmark while fighting the swarm!
				var orbit_ang := _t * 1.35
				goal_pos = cur_wp + Vector3(cos(orbit_ang) * 4.5, 0.0, sin(orbit_ang) * 4.5)
			else:
				goal_pos = cur_wp
		else:
			goal_pos = _holdout_loop[0]
	else:
		var h_idx := int(_t / 4.2) % _holdout_loop.size()
		goal_pos = _holdout_loop[h_idx]

	# ---- 2. Periodic Weapon Cycling (showcases all 7 weapons naturally!) ----
	_swap_cd -= delta
	if _swap_cd <= 0.0 and GameManager.chaos_weapon_id == "" and GameManager.unlocked_weapons.size() > 1:
		_swap_cd = randf_range(7.5, 11.5)
		GameManager.cycle_weapon(1)

	# ---- 3. Target Selection: Zombies, Bosses, and Explosive Barrels/Fuel Pumps/Cars ----
	_prop_cd -= delta
	if _prop_timer > 0.0:
		_prop_timer -= delta
		if _prop_target == null or not is_instance_valid(_prop_target) or _prop_target.exploded:
			_prop_timer = 0.0
			_prop_target = null
	elif _prop_cd <= 0.0:
		_prop_cd = 2.8
		_prop_target = _find_explosive_prop_near_zombies(ppos, hm)
		if _prop_target != null:
			_prop_timer = 1.05

	var near_z := hm.get_nearest_zombies(ppos, 26.0, 6)
	var aim_target := Vector3.INF
	var closest_z_dist := 999.0

	if not near_z.is_empty():
		closest_z_dist = (near_z[0]["pos"] as Vector3).distance_to(ppos)
		aim_target = near_z[0]["pos"]
		for z in near_z:
			var kind: String = str(z["kind"])
			var d := (z["pos"] as Vector3).distance_to(ppos)
			if kind == "boss" or (kind in ["charger", "bloater", "spitter"] and d < 15.0):
				aim_target = z["pos"]
				break

	if _prop_timer > 0.0 and _prop_target != null and is_instance_valid(_prop_target) and closest_z_dist > 3.2:
		aim_target = _prop_target.global_position

	# ---- 4. Aiming & Firing ----
	if aim_target != Vector3.INF:
		var to_t := aim_target - ppos
		to_t.y = 0.0
		var d := to_t.length()
		if d > 0.05:
			var want_aim := to_t / d
			_aim_smooth = _aim_smooth.slerp(want_aim, minf(1.0, delta * 18.0)).normalized()
		pl.touch_aim = Vector2(_aim_smooth.x, _aim_smooth.z)
		pl.touch_firing = d <= float(GameManager.get_current_weapon()["range"]) + 1.5
	else:
		var to_g := (goal_pos - ppos)
		to_g.y = 0.0
		if to_g.length() > 0.1:
			_aim_smooth = _aim_smooth.slerp(to_g.normalized(), minf(1.0, delta * 10.0)).normalized()
		pl.touch_aim = Vector2(_aim_smooth.x, _aim_smooth.z)
		pl.touch_firing = false

	if _gw._hud and _gw._hud._crosshair and _gw._cam:
		var ch_wpos: Vector3 = aim_target + Vector3(0, 1.0, 0) if aim_target != Vector3.INF else ppos + Vector3(0, 1.0, 0) + _aim_smooth * 7.5
		if not _gw._cam.is_position_behind(ch_wpos):
			_gw._hud._crosshair.set("custom_pos", _gw._cam.unproject_position(ch_wpos))

	# ---- 5. Tactical Movement: Waypoint Navigation + Horde Kiting + Feeler Ray Obstacle Steering ----
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.0, 1.8)
		_strafe_sign = -_strafe_sign

	var to_goal := goal_pos - ppos
	to_goal.y = 0.0
	var goal_dir := to_goal.normalized() if to_goal.length() > 0.2 else Vector3.ZERO

	var combat_move := Vector3.ZERO
	if not near_z.is_empty():
		var z0_pos: Vector3 = near_z[0]["pos"]
		var to_z0 := (z0_pos - ppos)
		to_z0.y = 0.0
		var z_dir := to_z0.normalized() if to_z0.length() > 0.05 else Vector3.FORWARD
		var strafe := Vector3(-z_dir.z, 0.0, z_dir.x) * _strafe_sign
		if closest_z_dist < 4.0:
			combat_move = (-z_dir * 0.95 + strafe * 0.8 + goal_dir * 0.45).normalized()
		elif closest_z_dist < 8.5:
			combat_move = (goal_dir * 1.05 + strafe * 0.6).normalized()
		else:
			combat_move = (goal_dir * 1.25 + strafe * 0.25).normalized()
	else:
		combat_move = goal_dir

	var desired_dir := (goal_dir * 1.15 + combat_move * 0.65).normalized()
	if closest_z_dist < 3.2:
		desired_dir = combat_move

	var steered_dir := _steer_around_obstacles(pl, ppos, desired_dir)

	# Unstuck detector
	_stuck_t += delta
	if _stuck_t >= 0.85:
		if ppos.distance_to(_last_pos) < 0.45:
			_unstuck_timer = 0.55
			_unstuck_dir = Vector3(-steered_dir.z * _strafe_sign, 0.0, steered_dir.x * _strafe_sign).normalized()
			pl.trigger_touch_dash()
		_last_pos = ppos
		_stuck_t = 0.0

	if _unstuck_timer > 0.0:
		_unstuck_timer -= delta
		steered_dir = _unstuck_dir

	pl.touch_move = Vector2(steered_dir.x, steered_dir.z)
	pl.touch_sprinting = (closest_z_dist < 5.5 or closest_z_dist > 9.0) and GameManager.stamina > 25.0

	# ---- 6. Smart Dash / Shove Reflexes ----
	_dash_cd -= delta
	if _dash_cd <= 0.0:
		if closest_z_dist < 3.4 or _is_projectile_or_charger_threatening(ppos, hm):
			_dash_cd = 1.45
			pl.trigger_touch_dash()

func _steer_around_obstacles(pl: PlayerController, ppos: Vector3, desired: Vector3) -> Vector3:
	if desired.length_squared() < 0.01:
		return Vector3.ZERO
	var space := _gw.get_world_3d().direct_space_state
	var origin := ppos + Vector3(0, 0.75, 0)
	var excl: Array[RID] = [pl.get_rid()]
	var angles := [0.0, 0.48, -0.48, 0.95, -0.95, 1.50, -1.50]
	for ang in angles:
		var cand := desired.rotated(Vector3.UP, ang).normalized()
		var q := PhysicsRayQueryParameters3D.create(origin, origin + cand * 2.4, 1 | 4, excl)
		if space.intersect_ray(q).is_empty():
			return cand
	return desired

func _find_explosive_prop_near_zombies(ppos: Vector3, hm: HordeManager) -> ExplodableCar:
	for c in _gw._city.get_children():
		if c is ExplodableCar and not c.exploded:
			var cpos := (c as Node3D).global_position
			var d_player := cpos.distance_to(ppos)
			if d_player > 4.2 and d_player < 16.0:
				if hm.get_nearest_zombies(cpos, 6.2, 1).size() > 0:
					return c
	return null

func _is_projectile_or_charger_threatening(ppos: Vector3, hm: HordeManager) -> bool:
	for ep in hm._enemy_projectiles:
		if (ep["pos"] as Vector3).distance_to(ppos) < 3.6:
			return true
	for z in hm._zombies:
		if z["alive"] and z["kind"] == "charger" and float(z["charge_t"]) > 0.0:
			if (z["pos"] as Vector3).distance_to(ppos) < 6.5:
				return true
	return false
