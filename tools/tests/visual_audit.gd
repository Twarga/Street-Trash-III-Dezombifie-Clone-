extends Node

func _ready() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/st_shots")
	# 1. Title Screen
	var ts := (load("res://scenes/main/title_screen.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(ts)
	for _i in range(8):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/st_shots/01_title_screen.png")
	print("Saved 01_title_screen.png")
	ts.queue_free()
	await get_tree().process_frame

	# 2. Live Gameplay on Neon Strip (with action!)
	SettingsManager.skip_intro = true
	var gw := (load("res://scenes/main/game_world.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(gw)
	for _i in range(6):
		await get_tree().physics_frame
	# Move player slightly down the neon strip near VAPES/COFFEE & burning car!
	gw._player.position = Vector3(0.0, 0.0, -14.0)
	gw._player._aim_dir = Vector3(0.15, 0.0, -1.0).normalized()
	gw._cam.global_position = gw._player.global_position + Vector3(0.0, 15.5, 11.8)
	gw._cam.look_at(gw._player.global_position + Vector3(0, 0.8, -2.0), Vector3.UP)
	# Spawn lively horde & blood & muzzle tracers
	gw._horde_mgr.spawn_zombie("shambler", Vector3(-2.5, 0, -21.0))
	gw._horde_mgr.spawn_zombie("sprinter", Vector3(2.2, 0, -19.5))
	gw._horde_mgr.spawn_zombie("bruiser", Vector3(0.4, 0, -23.0))
	gw._horde_mgr.spawn_zombie("bloater", Vector3(-3.8, 0, -24.0))
	gw._decal_mgr.spawn_blood(Vector3(1.2, 0, -18.0), 2.2)
	gw._decal_mgr.spawn_blood(Vector3(-1.8, 0, -20.5), 1.9)
	GameManager.kill_streak = 14
	GameManager.streak_mult = 1.14
	GameManager.score = 4250
	GameManager.gears = 2
	GameManager.stats_updated.emit()
	gw._player._fire_weapon(false, false)
	gw._vfx_juice.spawn_kill_burst(Vector3(1.0, 0, -19.0), "shambler", true, false)
	gw._vfx_juice.spawn_xp_orbs(Vector3(1.0, 0, -19.0), 4, 40.0)
	gw._hud.spawn_damage_popup(Vector3(0.5, 1.8, -19.5), 94, true)
	GameManager.multikill_triggered.emit("CARNAGE!!", 8)
	for _i in range(12):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/st_shots/02_gameplay_neon_street.png")
	print("Saved 02_gameplay_neon_street.png")

	# 3. 3-Card Comic Perk Draft Modal!
	GameManager.level_up_triggered.emit(4)
	for _i in range(8):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/st_shots/03_perk_draft_modal.png")
	print("Saved 03_perk_draft_modal.png")

	SettingsManager.skip_intro = false
	get_tree().quit(0)
