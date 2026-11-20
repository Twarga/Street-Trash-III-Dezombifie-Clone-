extends Node

const SAVE_PATH := "user://save.json"

var best_score: int = 0
var best_escape_time_left: float = 0.0
var total_kills: int = 0
var total_runs: int = 0
var escapes_completed: int = 0
var highest_streak: int = 0
var unlocked_traits: Array[String] = ["street_rat"]
var seen_perks: Array[String] = []
var seen_weapons: Array[String] = ["pistol"]
var seen_enemies: Array[String] = ["shambler"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save()

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return
	best_score = int(data.get("best_score", 0))
	best_escape_time_left = float(data.get("best_escape_time_left", 0.0))
	total_kills = int(data.get("total_kills", 0))
	total_runs = int(data.get("total_runs", 0))
	escapes_completed = int(data.get("escapes_completed", 0))
	highest_streak = int(data.get("highest_streak", 0))
	unlocked_traits.clear()
	for t in data.get("unlocked_traits", ["street_rat"]):
		unlocked_traits.append(str(t))
	if not unlocked_traits.has("street_rat"):
		unlocked_traits.append("street_rat")
	seen_perks.clear()
	for p in data.get("seen_perks", []):
		seen_perks.append(str(p))
	seen_weapons.clear()
	for w in data.get("seen_weapons", ["pistol"]):
		seen_weapons.append(str(w))
	seen_enemies.clear()
	for e in data.get("seen_enemies", ["shambler"]):
		seen_enemies.append(str(e))

func save_data() -> void:
	var data := {
		"best_score": best_score,
		"best_escape_time_left": best_escape_time_left,
		"total_kills": total_kills,
		"total_runs": total_runs,
		"escapes_completed": escapes_completed,
		"highest_streak": highest_streak,
		"unlocked_traits": unlocked_traits,
		"seen_perks": seen_perks,
		"seen_weapons": seen_weapons,
		"seen_enemies": seen_enemies,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))

func mark_seen_perk(id: String) -> void:
	if not seen_perks.has(id):
		seen_perks.append(id)

func mark_seen_weapon(id: String) -> void:
	if not seen_weapons.has(id):
		seen_weapons.append(id)

func mark_seen_enemy(id: String) -> void:
	if not seen_enemies.has(id):
		seen_enemies.append(id)

func record_run(score: int, kills: int, max_streak: int, escaped: bool, time_left: float) -> Array[String]:
	total_runs += 1
	total_kills += kills
	if score > best_score:
		best_score = score
	if max_streak > highest_streak:
		highest_streak = max_streak
	if escaped:
		escapes_completed += 1
		if time_left > best_escape_time_left:
			best_escape_time_left = time_left
	var newly_unlocked: Array[String] = []
	if total_kills >= 50 and not unlocked_traits.has("gunslinger"):
		unlocked_traits.append("gunslinger")
		newly_unlocked.append("GUNSLINGER (+15% Fire Rate)")
	if total_kills >= 150 and not unlocked_traits.has("juggernaut"):
		unlocked_traits.append("juggernaut")
		newly_unlocked.append("JUGGERNAUT (+35 Max HP)")
	if (escapes_completed >= 1 or total_kills >= 300) and not unlocked_traits.has("scavenger"):
		unlocked_traits.append("scavenger")
		newly_unlocked.append("SCAVENGER (+2 Redraws & +15% XP)")
	save_data()
	return newly_unlocked
