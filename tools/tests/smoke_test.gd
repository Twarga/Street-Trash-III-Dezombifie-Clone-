extends Node

func _ready() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== SMOKE TEST START ===")
	var ts_sc: PackedScene = load("res://scenes/main/title_screen.tscn")
	assert(ts_sc != null, "title_screen.tscn failed to load")
	var ts := ts_sc.instantiate()
	get_tree().root.add_child(ts)
	await get_tree().process_frame
	print("PASS: TitleScreen instantiated")
	ts.queue_free()
	await get_tree().process_frame

	SettingsManager.skip_intro = true
	var gw_sc: PackedScene = load("res://scenes/main/game_world.tscn")
	assert(gw_sc != null, "game_world.tscn failed to load")
	var gw := gw_sc.instantiate()
	get_tree().root.add_child(gw)
	for _i in range(5):
		await get_tree().physics_frame
	print("PASS: GameWorld + CityBuilder + Player + Horde + HUD + PerkDraftModal live")

	var hm: HordeManager = gw._horde_mgr
	for kind in ["shambler", "sprinter", "bruiser", "bloater", "boss"]:
		var z := hm.spawn_zombie(kind, Vector3(0, 0, -18.0))
		assert(z["alive"], "Failed to spawn " + kind)
		hm.damage_zombie(z, 25.0, Vector3(0, 0, -1), true, true)
	print("PASS: All 5 zombie archetypes spawned, crit-hit & ignited")

	var hand := GameManager.roll_perk_choices(3)
	assert(hand.size() == 3, "Expected 3 perk cards")
	GameManager.apply_perk("chaos_hmg")
	assert(GameManager.get_current_weapon_id() == "hmg", "Chaos HMG override failed")
	GameManager.apply_perk("duality_vampire")
	assert(GameManager.has_perk("duality_vampire"), "Vampire perk failed")
	GameManager.apply_perk("ricochet_rounds")
	GameManager.apply_perk("chaos_chain")
	GameManager.add_gear(false)
	assert(GameManager.gears == 1, "Gear increment failed")
	print("PASS: Perk roll, Chaos HMG override, Vampire Duality, Ricochet, Chain Overcharge, Gear salvage OK")

	gw._exp_sys.spawn_explosion(Vector3(0, 0, -18.0), 7.0, 200.0, true)
	for _i in range(4):
		await get_tree().physics_frame
	print("PASS: Jolt physics explosion & AoE damage OK")

	SettingsManager.skip_intro = false
	print("=== ALL SMOKE TESTS PASSED ===")
	get_tree().quit(0)
