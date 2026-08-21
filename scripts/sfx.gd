extends Node

# Sound effects, addressed by NAME rather than by resource.
#
#   Sfx.play("coupon_cut")
#
# looks for res://audio/coupon_cut.ogg (then .mp3, .wav) and plays it. If that file
# does not exist the call is a silent no-op - same rule the rest of the project
# follows for art, so the game runs correctly with an empty audio folder and
# every sound starts working the moment its file is dropped in. No code change
# is ever needed to add a sound; only to add a new EVENT.
#
# Registered as an autoload in project.godot so any script can reach it.
#
# See README for the full list of event names the game already fires.

const DIR := "res://audio/"
# TYPED on purpose. An untyped array yields Variant elements, and a Variant
# in a ":=" expression gives the compiler nothing to infer from - an
# untyped EXTS here made `var path := DIR + sound + "." + ext` a parse
# error, which failed this script, which failed the AUTOLOAD, which made
# every Sfx call in the game a runtime error.
const EXTS: Array[String] = ["ogg", "mp3", "wav"]

## Voices playable at once. Comfortably more than the game can trigger in a
## frame (a pickup plus a hazard plus a footfall), so a burst never cuts off
## a sound that is still ringing.
const VOICES := 12

## Per-event level trim, in dB. These are real voice recordings mastered at
## full scale, but they do not all play equally often: a jump fires every
## second or so and a level-complete fires once. Without a trim the frequent
## ones fatigue and bury the music, so the mix is set here rather than by
## re-exporting audio. Anything not listed plays at 0 dB.
##
## item_pickup is deliberately near the top - it is the game's signature sound.
const LEVELS := {
	"jump": -8.0,            # most frequent sound in the game, and a long take
	"drop_through": -6.0,
	"ui_click": -5.0,
	"ui_select": -3.0,
	"item_pickup": -1.0,
	"hazard_peel": -3.0,
	"hazard_crate": -3.0,
	"hazard_soap": -3.0,
	"hazard_ice": -3.0,
	"hazard_spill": -3.0,
	"hazard_knock": -8.0,    # layers under the hazard sound, so it stays behind it
	"fall_out": -3.0,
	"player_tumble": -2.0,
}

## Passed as volume_db to use the LEVELS table instead of an explicit level.
const AUTO_DB := INF

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
		var path: String = DIR + sound + "." + ext
		if ResourceLoader.exists(path):
			found = load(path) as AudioStream
			break
	_cache[sound] = found
	return found


## Fires a one-shot. `volume_db` trims a sound that was mastered too hot without
## re-exporting it; `jitter` adds the pitch spread described above.
func play(sound: String, volume_db: float = AUTO_DB, jitter: bool = true) -> void:
	var st := _stream(sound)
	if st == null:
		return
	if _pool.is_empty():
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = st
	p.volume_db = float(LEVELS.get(sound, 0.0)) if volume_db == AUTO_DB else volume_db
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
	_set_looping(st)
	p.play()
	_loops[sound] = p


## Tells the stream itself to loop. Doing it on the RESOURCE rather than
## restarting the player on `finished` matters: a restart-on-finished leaves an
## audible gap at the seam, and the callback that used to do it was a one-line
## lambda containing an `if`, which GDScript will not parse - that took the
## whole autoload down with it, and every scene that touches Sfx along with it.
func _set_looping(st: AudioStream) -> void:
	if st is AudioStreamWAV:
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true


func stop_loop(sound: String) -> void:
	if not _loops.has(sound):
		return
	var p: AudioStreamPlayer = _loops[sound]
	if is_instance_valid(p):
		p.stop()
		p.queue_free()
	_loops.erase(sound)


## Background music, crossfaded. Asking for the track already playing does
## nothing, so a scene can call this on every load without restarting it - and
## because Sfx is an autoload it survives the scene change, so the menu track
## and the aisle track fade across each other rather than cutting.
const MUSIC_DB    := -12.0
const MUSIC_FADE  := 1.6     # seconds. Long enough to read as a mix rather
                             # than a cut, short enough not to trail into play.
const MUSIC_QUIET := -40.0   # effectively silent, without hitting the -80 cliff

var _music := ""
var _music_player: AudioStreamPlayer = null
var _fade_in: Tween = null   # kept so a fast second call can cancel it


## Deferred by one frame on purpose. A music file is the biggest asset the game
## touches, and a scene's _ready() is the worst possible place to block on one:
## if the load is slow, or the importer has not run yet, the whole scene build
## stalls or dies and the player gets a blank screen. Deferring means the UI is
## always on screen first and the music arrives when it arrives.
func music(track: String, volume_db: float = MUSIC_DB) -> void:
	if track == _music:
		return
	_music = track
	_start_music.call_deferred(track, volume_db)


func _start_music(track: String, volume_db: float) -> void:
	# a newer request landed while this one was waiting - drop this one
	if track != _music:
		return

	var outgoing := _music_player
	var incoming: AudioStreamPlayer = null

	if not track.is_empty():
		var st := _stream(track)
		if st != null:
			_set_looping(st)
			incoming = AudioStreamPlayer.new()
			incoming.stream = st
			incoming.bus = "Master"
			incoming.volume_db = MUSIC_QUIET   # starts silent, fades up
			add_child(incoming)
			incoming.play()
	_music_player = incoming

	# If the previous track is still fading IN when it gets replaced, that tween
	# is still driving its volume - two tweens on one property fight and the
	# track audibly stutters. Cancel it before handing the player to the fade out.
	if _fade_in != null and _fade_in.is_valid():
		_fade_in.kill()
	_fade_in = null

	# two independent tweens, so the two halves genuinely overlap
	if outgoing != null and is_instance_valid(outgoing):
		var fade_out := create_tween()
		fade_out.tween_property(outgoing, "volume_db", MUSIC_QUIET, MUSIC_FADE)
		fade_out.tween_callback(outgoing.queue_free)
	if incoming != null:
		_fade_in = create_tween()
		_fade_in.tween_property(incoming, "volume_db", volume_db, MUSIC_FADE)


func stop_music() -> void:
	music("")
