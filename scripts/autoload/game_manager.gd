extends Node

signal stats_updated
signal level_up_triggered(new_level: int)
signal gear_collected(count: int, required: int)
signal weapon_changed(weapon_id: String, is_chaos: bool)
signal chaos_buffs_updated
signal player_damaged(amount: float)
signal player_died(reason: String)
signal extraction_started
signal victory_triggered
signal boss_spawned(boss_name: String, hp: float, max_hp: float)
signal boss_hp_changed(hp: float, max_hp: float)
signal boss_defeated
signal hit_marker(is_crit: bool)
signal postfx_kick(ca_amount: float)
signal multikill_triggered(label_text: String, tier: int)

var _rapid_kills: int = 0
var _rapid_timer: float = 0.0

enum GameMode { ESCAPE, ENDLESS }
enum Difficulty { STANDARD, NIGHTMARE, HARDCORE }

var mode: GameMode = GameMode.ESCAPE
var difficulty: Difficulty = Difficulty.STANDARD
var starting_trait: String = "street_rat"

var run_active: bool = false
var intro_playing: bool = false
var is_drafting: bool = false

var hp: float = 100.0
var max_hp: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var xp: float = 0.0
var xp_to_next: float = 75.0
var level: int = 1
var pending_level_ups: int = 0

var gears: int = 0
var gears_required: int = 6
var time_remaining: float = 1080.0 # 18:00
var elapsed_time: float = 0.0
var two_min_warned: bool = false

var holdout_active: bool = false
var holdout_timer: float = 90.0

var kill_streak: int = 0
var max_kill_streak: int = 0
var streak_timer: float = 0.0
var streak_mult: float = 1.0
var score: int = 0
var kills: int = 0
var shots_fired: int = 0
var shots_hit: int = 0
var redraws_left: int = 3

var perk_stacks: Dictionary = {}
var base_weapon_id: String = "pistol"
var unlocked_weapons: Array[String] = ["pistol", "shotgun"]
var current_weapon_idx: int = 0
var _hurt_invuln: float = 0.0
var chaos_weapon_id: String = ""
var chaos_weapon_timer: float = 0.0
var active_chaos_buffs: Dictionary = {} # buff_id -> remaining_seconds

var _hitstop_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	# Unscaled hit-stop recovery
	if _hurt_invuln > 0.0:
		_hurt_invuln = maxf(0.0, _hurt_invuln - delta)
	if _hitstop_timer > 0.0:
		_hitstop_timer -= delta / maxf(Engine.time_scale, 0.01)
		if _hitstop_timer <= 0.0:
			Engine.time_scale = 1.0
	if not run_active or get_tree().paused or intro_playing:
		return
	elapsed_time += delta
	# Nuke Countdown (Escape mode)
	if mode == GameMode.ESCAPE:
		time_remaining = maxf(0.0, time_remaining - delta)
		if not two_min_warned and time_remaining <= 120.0:
			two_min_warned = true
			AudioManager.play_sfx("siren_alarm", 0.98, 1.02, 0.85)
			AudioManager.play_vo("vo_two_min", "Two minutes until nuclear strike! Move it or you're vapor!", true)
			AudioManager.set_music_stem("extraction")
		if time_remaining <= 0.0:
			end_run_defeat("CITY VAPORIZED BY NUCLEAR STRIKE")
			return
	# Extraction Holdout timer
	if holdout_active:
		holdout_timer = maxf(0.0, holdout_timer - delta)
		if holdout_timer <= 0.0:
			holdout_active = false
			run_active = false
			AudioManager.play_vo("vo_victory", "Chopper locked on! You made it out of the quarantine zone alive. Welcome back.", true)
			victory_triggered.emit()
			return
	# Health regeneration
	var regen := get_stat_sum("hp_regen")
	if regen > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + regen * delta)
	# Rapid multikill tracker
	if _rapid_kills > 0:
		_rapid_timer -= delta
		if _rapid_timer <= 0.0:
			_rapid_kills = 0
	# Kill streak decay
	if kill_streak > 0:
		streak_timer -= delta
		if streak_timer <= 0.0:
			kill_streak = 0
			streak_mult = 1.0
	# Chaos weapon timer
	if chaos_weapon_timer > 0.0:
		chaos_weapon_timer -= delta
		if chaos_weapon_timer <= 0.0:
			chaos_weapon_id = ""
			chaos_weapon_timer = 0.0
			weapon_changed.emit(base_weapon_id, false)
			_update_music_mood()
			chaos_buffs_updated.emit()
	# Chaos buff timers
	if not active_chaos_buffs.is_empty():
		var expired: Array[String] = []
		for b in active_chaos_buffs.keys():
			active_chaos_buffs[b] -= delta
			if active_chaos_buffs[b] <= 0.0:
				expired.append(b)
		if not expired.is_empty():
			for b in expired:
				active_chaos_buffs.erase(b)
			_update_music_mood()
			chaos_buffs_updated.emit()
	stats_updated.emit()

func start_new_run() -> void:
	Engine.time_scale = 1.0
	_hitstop_timer = 0.0
	run_active = true
	is_drafting = false
	perk_stacks.clear()
	active_chaos_buffs.clear()
	unlocked_weapons = ["pistol", "shotgun"]
	current_weapon_idx = 0
	base_weapon_id = "pistol"
	chaos_weapon_id = ""
	_hurt_invuln = 0.0
	chaos_weapon_timer = 0.0
	level = 1
	xp = 0.0
	xp_to_next = 60.0
	pending_level_ups = 0
	gears = 0
	gears_required = 6
	time_remaining = 1080.0
	elapsed_time = 0.0
	two_min_warned = false
	holdout_active = false
	holdout_timer = 90.0
	kill_streak = 0
	max_kill_streak = 0
	streak_timer = 0.0
	streak_mult = 1.0
	score = 0
	kills = 0
	shots_fired = 0
	shots_hit = 0
	redraws_left = 5 if starting_trait == "scavenger" else 3
	max_hp = 175.0 if starting_trait == "juggernaut" else 140.0
	hp = max_hp
	max_stamina = 100.0
	stamina = max_stamina
	SaveManager.mark_seen_weapon("pistol")
	stats_updated.emit()
	weapon_changed.emit(base_weapon_id, false)

func get_diff_enemy_hp_mult() -> float:
	match difficulty:
		Difficulty.STANDARD: return 0.82
		Difficulty.NIGHTMARE: return 1.25
		Difficulty.HARDCORE: return 1.95
	return 1.0

func get_diff_enemy_dmg_mult() -> float:
	match difficulty:
		Difficulty.STANDARD: return 0.72
		Difficulty.NIGHTMARE: return 1.15
		Difficulty.HARDCORE: return 1.85
	return 1.0

func get_perk_stacks(id: String) -> int:
	return int(perk_stacks.get(id, 0))

func has_perk(id: String) -> bool:
	return get_perk_stacks(id) > 0

func get_stat_sum(stat_name: String) -> float:
	var total := 0.0
	for p in GameData.PERKS:
		if p.get("stat", "") == stat_name:
			var st := get_perk_stacks(p["id"])
			if st > 0:
				total += float(st) * float(p.get("step", 0.0))
	return total

func get_damage_mult() -> float:
	var pct := get_stat_sum("damage")
	if has_perk("duality_glass_cannon"):
		pct += 65.0
	return 1.0 + pct / 100.0

func get_fire_rate_mult(is_sprinting: bool = false) -> float:
	var pct := get_stat_sum("fire_rate")
	if starting_trait == "gunslinger":
		pct += 15.0
	if has_perk("duality_tunnel_vision"):
		pct += 40.0
	if has_perk("adrenaline_rush") and kill_streak >= 10:
		pct += 15.0
	if has_perk("duality_blood_fuel") and is_sprinting:
		pct += 35.0
	var mult := 1.0 + pct / 100.0
	if active_chaos_buffs.has("double_rof"):
		mult *= 2.0
	return mult

func get_crit_chance(is_stationary: bool) -> float:
	var pct := 5.0 + get_stat_sum("crit_chance")
	if starting_trait == "gunslinger":
		pct += 8.0
	if is_stationary:
		pct += get_stat_sum("stationary_crit")
	return clampf(pct / 100.0, 0.0, 0.95)

func get_crit_damage_mult() -> float:
	return 1.75 + get_stat_sum("crit_damage") / 100.0

func get_move_speed() -> float:
	var pct := get_stat_sum("move_speed")
	if has_perk("adrenaline_rush") and kill_streak >= 10:
		pct += 15.0
	return 10.2 * (1.0 + pct / 100.0)

func get_xp_mult() -> float:
	var pct := get_stat_sum("xp_gain")
	if starting_trait == "scavenger":
		pct += 15.0
	return (1.0 + pct / 100.0) * streak_mult

func get_pickup_radius() -> float:
	return 3.4 * (1.0 + get_stat_sum("pickup_radius") / 100.0)

func get_armor_mult() -> float:
	var pct := get_stat_sum("armor")
	if starting_trait == "juggernaut":
		pct += 10.0
	return clampf(1.0 - pct / 100.0, 0.35, 1.0)

func unlock_weapon(wid: String, auto_equip: bool = true) -> bool:
	if not GameData.WEAPONS.has(wid):
		return false
	var is_new := not unlocked_weapons.has(wid)
	if is_new:
		unlocked_weapons.append(wid)
	SaveManager.mark_seen_weapon(wid)
	if auto_equip:
		current_weapon_idx = unlocked_weapons.find(wid)
		base_weapon_id = wid
		if chaos_weapon_id == "":
			weapon_changed.emit(base_weapon_id, false)
	stats_updated.emit()
	return is_new

func select_weapon_slot(idx: int) -> void:
	if unlocked_weapons.is_empty() or idx < 0 or idx >= unlocked_weapons.size():
		return
	if chaos_weapon_id != "":
		return
	current_weapon_idx = idx
	base_weapon_id = unlocked_weapons[idx]
	AudioManager.play_sfx("card_hover", 0.85, 1.05, 0.5)
	weapon_changed.emit(base_weapon_id, false)
	stats_updated.emit()

func cycle_weapon(dir: int) -> void:
	if unlocked_weapons.size() <= 1 or chaos_weapon_id != "":
		return
	var next_idx := posmod(current_weapon_idx + dir, unlocked_weapons.size())
	select_weapon_slot(next_idx)

func get_current_weapon_id() -> String:
	return chaos_weapon_id if chaos_weapon_id != "" else base_weapon_id

func get_current_weapon() -> Dictionary:
	return GameData.WEAPONS[get_current_weapon_id()]

func is_invulnerable() -> bool:
	return active_chaos_buffs.has("invuln")

func has_chaos_buff(id: String) -> bool:
	return active_chaos_buffs.has(id)

func add_xp(base_amount: float) -> void:
	if not run_active:
		return
	xp += base_amount * get_xp_mult()
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = roundf(xp_to_next * 1.24 + 28.0)
		pending_level_ups += 1
	if pending_level_ups > 0 and not is_drafting:
		_trigger_next_draft()
	stats_updated.emit()

func _trigger_next_draft() -> void:
	if pending_level_ups <= 0:
		return
	pending_level_ups -= 1
	is_drafting = true
	AudioManager.play_sfx("level_up", 0.98, 1.03, 0.85)
	level_up_triggered.emit(level)

func finish_draft() -> void:
	is_drafting = false
	if pending_level_ups > 0:
		_trigger_next_draft()
	stats_updated.emit()

func register_kill(enemy_id: String, xp_val: float, score_val: int) -> void:
	kills += 1
	kill_streak += 1
	if kill_streak > max_kill_streak:
		max_kill_streak = kill_streak
	streak_timer = 4.2
	streak_mult = minf(2.5, 1.0 + float(kill_streak) * 0.01)
	score += int(roundf(float(score_val) * streak_mult))
	SaveManager.mark_seen_enemy(enemy_id)
	_rapid_kills += 1
	_rapid_timer = 2.4
	var mk_map := {2: "DOUBLE KILL", 3: "TRIPLE KILL!", 5: "MULTI KILL!", 8: "CARNAGE!!", 12: "MASSACRE!!", 18: "DEZOMBIFIED!!!"}
	if mk_map.has(_rapid_kills):
		multikill_triggered.emit(mk_map[_rapid_kills], _rapid_kills)
		postfx_kick.emit(0.008)
	# Note: XP granted via physical magnetized XP orbs when VFXJuice is active; fallback handled by caller
	_update_music_mood()

func add_gear(from_perk: bool = false) -> void:
	if gears >= gears_required:
		score += 1000
		return
	gears += 1
	score += 750
	AudioManager.play_sfx("pickup_gear", 0.98, 1.04, 0.9)
	gear_collected.emit(gears, gears_required)
	var vo_map := {
		1: ["vo_gear_1", "See, I knew you could salvage something. Just five more gears left to find."],
		2: ["vo_gear_2", "Two gears down. Keep moving through the neon strip and watch those burning wrecks."],
		3: ["vo_gear_3", "Halfway there! Three gears salvaged. The infected are swarming thicker ahead."],
		4: ["vo_gear_4", "Four gears secured. Only two left before extraction clears."],
		5: ["vo_gear_5", "Five gears! One last salvage and the High-Rise gate unlocks."],
		6: ["vo_gear_6", "All six gears collected! Sprint to the High-Rise extraction plaza now!"],
	}
	if vo_map.has(gears):
		AudioManager.play_vo(vo_map[gears][0], vo_map[gears][1], gears == 6)
	stats_updated.emit()

func start_extraction_holdout() -> void:
	if holdout_active:
		return
	holdout_active = true
	holdout_timer = 90.0
	AudioManager.set_music_stem("extraction")
	AudioManager.play_sfx("siren_alarm", 0.98, 1.02, 0.9)
	AudioManager.play_vo("vo_holdout", "Extraction chopper inbound! Hold the High-Rise pad for ninety seconds!", true)
	extraction_started.emit()

func damage_player(raw_amount: float) -> void:
	if not run_active or is_invulnerable() or _hurt_invuln > 0.0:
		return
	var dmg := raw_amount * get_diff_enemy_dmg_mult() * get_armor_mult()
	if has_perk("brace_for_impact") and stamina > 0.0:
		var absorbed := minf(stamina, dmg)
		stamina -= absorbed
		dmg -= absorbed
	if dmg > 0.0:
		hp = maxf(0.0, hp - dmg)
		_hurt_invuln = 0.55
		AudioManager.play_sfx("player_hurt", 0.92, 1.08, 0.9)
		player_damaged.emit(dmg)
		postfx_kick.emit(0.014)
		if hp <= 0.0:
			end_run_defeat("OVERRUN BY THE INFECTED")
	stats_updated.emit()

func heal_player(amount: float) -> void:
	if not run_active:
		return
	hp = minf(max_hp, hp + amount)
	stats_updated.emit()

func end_run_defeat(reason: String) -> void:
	if not run_active:
		return
	run_active = false
	Engine.time_scale = 1.0
	player_died.emit(reason)

func apply_perk(perk_id: String) -> void:
	var p := GameData.get_perk_by_id(perk_id)
	if p.is_empty():
		return
	perk_stacks[perk_id] = get_perk_stacks(perk_id) + 1
	SaveManager.mark_seen_perk(perk_id)
	# Apply immediate side-effects
	if perk_id == "built_different":
		var old_max := max_hp
		max_hp = roundf(max_hp * 1.25)
		hp += (max_hp - old_max)
	elif perk_id == "health_gains":
		max_hp += 20.0
		hp = minf(max_hp, hp + 20.0)
	elif perk_id == "cardio_training":
		max_stamina = roundf(max_stamina * 1.20)
		stamina = max_stamina
	elif perk_id == "scavenger_perk":
		redraws_left += 2
		heal_player(25.0)
	elif perk_id == "loadout_gear":
		add_gear(true)
	elif perk_id == "duality_glass_cannon":
		max_hp = maxf(30.0, roundf(max_hp * 0.70))
		hp = minf(hp, max_hp)
	elif p.has("weapon"):
		unlock_weapon(str(p["weapon"]), true)
	elif p.has("chaos_weapon"):
		chaos_weapon_id = p["chaos_weapon"]
		chaos_weapon_timer = float(p.get("duration", 30.0))
		SaveManager.mark_seen_weapon(chaos_weapon_id)
		weapon_changed.emit(chaos_weapon_id, true)
		_update_music_mood()
		chaos_buffs_updated.emit()
	elif p.has("chaos_buff"):
		active_chaos_buffs[p["chaos_buff"]] = float(p.get("duration", 30.0))
		_update_music_mood()
		chaos_buffs_updated.emit()
	stats_updated.emit()

func roll_perk_choices(count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var weights: Array[float] = []
	for p in GameData.PERKS:
		var id: String = p["id"]
		if get_perk_stacks(id) >= int(p.get("max", 1)):
			continue
		if p.has("weapon") and p["weapon"] == base_weapon_id:
			continue
		if id == "loadout_gear" and (mode != GameMode.ESCAPE or gears >= gears_required):
			continue
		var w := 1.0
		match p["rarity"]:
			"COMMON": w = 1.45
			"RARE": w = 1.05
			"EPIC": w = 0.72
			"CHAOS": w = 0.85
			"DUALITY": w = 0.55
		# Pity weight for Gear if behind schedule in Escape mode
		if id == "loadout_gear" and elapsed_time > 180.0 and gears < int(elapsed_time / 140.0):
			w = 1.8
		pool.append(p)
		weights.append(w)
	var chosen: Array[Dictionary] = []
	var used_cats: Array[String] = []
	while chosen.size() < count and not pool.is_empty():
		var total := 0.0
		for i in range(pool.size()):
			var cw := weights[i] * (0.45 if used_cats.has(pool[i]["cat"]) else 1.0)
			total += cw
		var r := randf() * total
		var acc := 0.0
		var pick := 0
		for i in range(pool.size()):
			acc += weights[i] * (0.45 if used_cats.has(pool[i]["cat"]) else 1.0)
			if r <= acc:
				pick = i
				break
		chosen.append(pool[pick])
		used_cats.append(pool[pick]["cat"])
		pool.remove_at(pick)
		weights.remove_at(pick)
	return chosen

func format_perk_delta(p: Dictionary) -> String:
	if p.get("special", false):
		return p["desc"]
	var st := get_perk_stacks(p["id"])
	var step := float(p.get("step", 0.0))
	var cur := float(st) * step
	var nxt := float(st + 1) * step
	if p.get("is_int", false):
		return "%s\n%d -> %d" % [p["desc"], int(cur), int(nxt)]
	return "%s\n%.1f%% -> %.1f%%" % [p["desc"], cur, nxt]

func trigger_hitstop(duration: float = 0.032) -> void:
	if is_drafting or get_tree().paused:
		return
	Engine.time_scale = 0.12
	_hitstop_timer = maxf(_hitstop_timer, duration)

func compute_rank(escaped: bool) -> String:
	var pts := score + (12000 if escaped else 0) + int(time_remaining * 10.0 if escaped else 0.0)
	if escaped and pts >= 28000:
		return "S"
	elif escaped or pts >= 14000:
		return "A"
	elif pts >= 6500:
		return "B"
	return "C"

func _update_music_mood() -> void:
	if holdout_active or (mode == GameMode.ESCAPE and time_remaining <= 120.0):
		AudioManager.set_music_stem("extraction")
	elif chaos_weapon_id != "" or not active_chaos_buffs.is_empty():
		AudioManager.set_music_stem("chaos")
	elif kill_streak >= 3:
		AudioManager.set_music_stem("combat")
	else:
		AudioManager.set_music_stem("explore")
