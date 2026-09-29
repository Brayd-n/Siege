extends Node
## Tiny sound manager: a pool of AudioStreamPlayers with per-sound throttling.

const DIR := "res://assets/audio/"
const POOL_SIZE := 16

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _last_play: Dictionary = {}
var _ambience: AudioStreamPlayer
var master_volume_db := -4.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)
	_ambience.finished.connect(func(): _ambience.play())


func _stream(name: String) -> AudioStream:
	if not _streams.has(name):
		var p := DIR + name + ".wav"
		_streams[name] = load(p) if ResourceLoader.exists(p) else null
	return _streams[name]


## Play a sound. min_gap throttles spam of the same sound (seconds, real time).
func play(name: String, volume_db: float = 0.0, pitch_var: float = 0.08, min_gap: float = 0.05) -> void:
	var s := _stream(name)
	if s == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(name, -10.0)) < min_gap:
		return
	_last_play[name] = now
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db + master_volume_db
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return


func start_ambience() -> void:
	var s := _stream("ambience")
	if s and not _ambience.playing:
		_ambience.stream = s
		_ambience.volume_db = -14.0
		_ambience.play()


func _exit_tree() -> void:
	# stop streams so nothing is still playing when the engine shuts down
	_ambience.stop()
	_ambience.stream = null
	for p in _pool:
		p.stop()
		p.stream = null
	_streams.clear()
