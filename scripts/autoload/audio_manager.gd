extends Node

signal subtitle_changed(text: String)

var _music_players: Dictionary = {}
var _active_stem: String = "explore"
var _music_started: bool = false
var _sfx_cache: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _vo_player: AudioStreamPlayer
var _vo_queue: Array[Dictionary] = []
var _hit_combo: int = 0
var _hit_decay: float = 0.0
var _audio_clock: float = 0.0
var _sfx_last_t: Dictionary = {}

const SFX_MIN_INTERVAL := {
	"flamethrower": 0.24,
	"hit_flesh": 0.075,
	"hit_crit": 0.075,
	"hit_armor": 0.080,
	"zombie_death": 0.095,
	"card_hover": 0.085,
	"smg": 0.058,
	"hmg": 0.058,
	"shotgun": 0.080,
	"rifle": 0.065,
	"pistol": 0.065,
	"bloater_pop": 0.090,
	"explosion": 0.075,
	"zombie_groan_1": 0.45,
	"zombie_groan_2": 0.45,
	"zombie_groan_3": 0.45,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for stem in ["explore", "combat", "chaos", "extraction"]:
		var p := AudioStreamPlayer.new()
		var path := "res://assets/audio/music/music_%s.ogg" % stem
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream is AudioStreamOggVorbis:
				stream.loop = true
			p.stream = stream
		p.volume_db = -80.0
		add_child(p)
		_music_players[stem] = p
	for i in range(48):
		var sp := AudioStreamPlayer.new()
		add_child(sp)
		_sfx_pool.append(sp)
	_vo_player = AudioStreamPlayer.new()
	_vo_player.finished.connect(_on_vo_finished)
	add_child(_vo_player)
	SettingsManager.settings_changed.connect(_refresh_volumes)

func _process(delta: float) -> void:
	_audio_clock += delta
	if _hit_decay > 0.0:
		_hit_decay -= delta
		if _hit_decay <= 0.0:
			_hit_combo = 0
	if _music_started:
		# Duck music slightly by 2.5 dB when radio announcer VO is speaking so voice is crystal clear!
		var vo_duck := 0.74 if (_vo_player and _vo_player.playing) else 1.0
		var target_db := linear_to_db(maxf(SettingsManager.music_volume * vo_duck, 0.0001))
		for stem in _music_players.keys():
			var p: AudioStreamPlayer = _music_players[stem]
			var goal := target_db if stem == _active_stem else -60.0
			p.volume_db = move_toward(p.volume_db, goal, delta * 28.0)

func start_music(stem: String = "explore") -> void:
	_active_stem = stem
	if not _music_started:
		var target_db := linear_to_db(maxf(SettingsManager.music_volume, 0.0001))
		for s in _music_players.keys():
			var p: AudioStreamPlayer = _music_players[s]
			if p.stream != null:
				p.volume_db = target_db if s == _active_stem else -60.0
				p.play()
		_music_started = true

func set_music_stem(stem: String) -> void:
	if _music_players.has(stem):
		_active_stem = stem
		if not _music_started:
			start_music(stem)

func stop_music() -> void:
	for s in _music_players.keys():
		(_music_players[s] as AudioStreamPlayer).stop()
	_music_started = false

func _refresh_volumes() -> void:
	if _vo_player:
		_vo_player.volume_db = linear_to_db(maxf(SettingsManager.vo_volume, 0.0001))

func _acquire_player() -> AudioStreamPlayer:
	# Always prefer a non-playing AudioStreamPlayer so active sounds are never cut off mid-wave!
	var n := _sfx_pool.size()
	for i in range(n):
		var idx := (_sfx_idx + i) % n
		if not _sfx_pool[idx].playing:
			_sfx_idx = (idx + 1) % n
			return _sfx_pool[idx]
	var fallback := _sfx_pool[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % n
	return fallback

func play_sfx(name: String, pitch_min: float = 0.96, pitch_max: float = 1.04, vol_scale: float = 1.0) -> void:
	if name == "smg_shot":
		name = "smg"
	elif name == "gear_pickup":
		name = "pickup_gear"

	var min_iv: float = float(SFX_MIN_INTERVAL.get(name, 0.025))
	var last_t: float = float(_sfx_last_t.get(name, -999.0))
	if _audio_clock - last_t < min_iv:
		return
	_sfx_last_t[name] = _audio_clock

	var path := "res://assets/audio/sfx/%s.wav" % name
	if not _sfx_cache.has(name):
		if ResourceLoader.exists(path):
			_sfx_cache[name] = load(path)
		else:
			return
	var p := _acquire_player()
	p.stream = _sfx_cache[name]
	p.pitch_scale = clampf(randf_range(pitch_min, pitch_max), 0.85, 1.18)
	p.volume_db = linear_to_db(maxf(SettingsManager.sfx_volume * vol_scale, 0.0001))
	p.play()

func play_hit_confirm(is_crit: bool, is_armor: bool) -> void:
	_hit_combo = mini(_hit_combo + 1, 8)
	_hit_decay = 0.30
	var pitch_boost := 1.0 + float(_hit_combo) * 0.01
	if is_crit:
		play_sfx("hit_crit", pitch_boost * 0.97, pitch_boost * 1.03, 0.48)
	elif is_armor:
		play_sfx("hit_armor", 0.94, 1.06, 0.42)
	else:
		play_sfx("hit_flesh", pitch_boost * 0.95, pitch_boost * 1.03, 0.36)

func play_vo(slug: String, subtitle: String, interrupt: bool = false) -> void:
	if interrupt:
		_vo_queue.clear()
		_vo_player.stop()
	_vo_queue.append({"slug": slug, "subtitle": subtitle})
	if not _vo_player.playing:
		_play_next_vo()

func _play_next_vo() -> void:
	if _vo_queue.is_empty():
		subtitle_changed.emit("")
		return
	var item: Dictionary = _vo_queue.pop_front()
	var path := "res://assets/audio/vo/%s.ogg" % item["slug"]
	if ResourceLoader.exists(path):
		_vo_player.stream = load(path)
		_vo_player.volume_db = linear_to_db(maxf(SettingsManager.vo_volume, 0.0001))
		_vo_player.play()
		if SettingsManager.show_subtitles:
			subtitle_changed.emit(item["subtitle"])
	else:
		_play_next_vo()

func _on_vo_finished() -> void:
	_play_next_vo()
