extends Node

# Sound effects, addressed by NAME rather than by resource.
#
#   Sfx.play("coupon_cut")
#
# looks for res://audio/coupon_cut.ogg (then .wav) and plays it. If that file
# does not exist the call is a silent no-op - same rule the rest of the project
# follows for art, so the game runs correctly with an empty audio folder and
# every sound starts working the moment its file is dropped in. No code change
# is ever needed to add a sound; only to add a new EVENT.
#
# Registered as an autoload in project.godot so any script can reach it.
#
# See README for the full list of event names the game already fires.

const DIR := "res://audio/"
const EXTS := ["ogg", "wav"]

## Voices playable at once. Comfortably more than the game can trigger in a
## frame (a pickup plus a hazard plus a footfall), so a burst never cuts off
## a sound that is still ringing.
const VOICES := 12

## Small random pitch spread on repeated sounds. Without it, footsteps and
## coin pickups in quick succession sound like a machine gun rather than a
## person; with it each repeat is fractionally different.
const PITCH_JITTER := 0.06

var _cache: Dictionary = {}          # name -> AudioStream, or null if missing
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _loops: Dictionary = {}          # name -> AudioStreamPlayer, for held sounds


func _ready() -> void:
	# a fixed pool, so nothing is allocated during play
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


## Loads (and remembers) a stream by name. Caches the MISS too, so a missing
## file is looked up once rather than on every trigger.
func _stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var found: AudioStream = null
	for ext in EXTS:
		var path := DIR + sound + "." + ext
		if ResourceLoader.exists(path):
			found = load(path) as AudioStream
			break
	_cache[sound] = found
	return found


## Fires a one-shot. `volume_db` trims a sound that was mastered too hot without
## re-exporting it; `jitter` adds the pitch spread described above.
func play(sound: String, volume_db: float = 0.0, jitter: bool = true) -> void:
	var st := _stream(sound)
	if st == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = st
	p.volume_db = volume_db
	p.pitch_scale = 1.0
	if jitter:
		p.pitch_scale = 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER)
	p.play()


## Starts a held sound (the printer motor, an ambient hum) and keeps it looping
## until stop_loop. Calling it again while already running is a no-op, so it is
## safe to call every frame.
func start_loop(sound: String, volume_db: float = 0.0) -> void:
	if _loops.has(sound) and is_instance_valid(_loops[sound]) and _loops[sound].playing:
		return
	var st := _stream(sound)
	if st == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = volume_db
	p.bus = "Master"
	add_child(p)
	# loop the stream itself where the format supports being told to
	if st is AudioStreamWAV:
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	p.finished.connect(func(): if is_instance_valid(p): p.play())
	p.play()
	_loops[sound] = p


func stop_loop(sound: String) -> void:
	if not _loops.has(sound):
		return
	var p: AudioStreamPlayer = _loops[sound]
	if is_instance_valid(p):
		p.stop()
		p.queue_free()
	_loops.erase(sound)


## Background music. One track at a time; asking for the track already playing
## does nothing, so a scene can call this on every load without restarting it.
var _music := ""

func music(track: String, volume_db: float = -12.0) -> void:
	if track == _music:
		return
	if not _music.is_empty():
		stop_loop(_music)
	_music = track
	if not track.is_empty():
		start_loop(track, volume_db)


func stop_music() -> void:
	music("")
