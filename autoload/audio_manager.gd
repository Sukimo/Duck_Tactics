extends Node
# Autoload as "AudioManager"

# Owns:
#   - Music crossfade (A/B players)
#   - Ambience loop
#   - One-shot SFX pool (UI stings, wave fanfare, merge pop, etc.)
#
# Does NOT own:
#   - Unit attack SFX  → AttackComponent (local, export per scene)
#   - Crit label SFX   → crit_label.gd  (local)
#   - Projectile SFX   → projectile.gd  (local, add export when ready)

const MUSIC_FADE_IN 	: float = 1.2
const MUSIC_FADE_OUT 	: float = 0.8
const AMBIENCE_FADE 	: float = 2.0

# One-shot SFX table
# Leave value as null until you have the asset — play_sfx() guards against it.
const SFX_TABLE : Dictionary = {
	# UI
	"ui_click"         : null,   # replace: preload("res://music/ui_click.ogg")
	"ui_card_select"   : null,
	"ui_confirm"       : null,
	# Game events
	"game_merge"       : null,   # merge pop
	"game_wave_start"  : null,   # sting at battle start
	"game_wave_clear"  : null,   # fanfare after wave
	"game_duck_death"  : null,
	"game_level_up"    : null,   # duck level up on merge
}

# Node refs
@onready var _music_a : AudioStreamPlayer = $MusicA
@onready var _music_b : AudioStreamPlayer = $MusicB
@onready var _ambience : AudioStreamPlayer  = $Ambience

# Internal state
var _active   : AudioStreamPlayer = null   # currently audible music player
var _inactive : AudioStreamPlayer = null   # standby player
var _current_music_stream : AudioStream = null

func _ready() -> void:
	_music_a.bus = &"Music"
	_music_b.bus = &"Music"
	_ambience.bus = &"Ambience" # child of Music bus
	
	_music_a.volume_db = -80.0
	_music_b.volume_db = -80.0
	_ambience.volume_db = -80.0
	
	_active   = _music_a
	_inactive = _music_b
	
# Music API
## Play a music stream with crossfade.
## Calling with the same stream that is already playing is a no-op.
func play_music(stream: AudioStream, fade_in: float = MUSIC_FADE_IN,
		fade_out: float = MUSIC_FADE_OUT) -> void:
	if stream == null: 
		stop_music()
		return
	# Already playing this track — don't restart
	if _active.stream == stream and _active.playing:
		return
	
	_current_music_stream = stream
	
	# Set up the incoming player
	_inactive.stream    = stream
	_inactive.volume_db = -80.0
	_inactive.play()
	
	# Crossfade
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_active,   "volume_db", -80.0, fade_out)
	tween.tween_property(_inactive, "volume_db",   0.0, fade_in)
	
	# Stop the old player after fade completes
	var dying := _active
	tween.chain().tween_callback(func(): dying.stop())
	
		# Swap roles
	var tmp  := _active
	_active   = _inactive
	_inactive = tmp

## Stop music with optional fade.
func stop_music(fade: float = MUSIC_FADE_OUT) -> void:
	if not _active.playing:
		return
	var dying := _active
	var tween := create_tween()
	tween.tween_property(dying, "volume_db", -80.0, fade)
	tween.tween_callback(func(): dying.stop())
	_current_music_stream = null
	
## Returns true if music is currently playing.
func is_music_playing() -> bool:
	return _active.playing
	
# Ambience API
## Play an ambient loop (wind, crowd, arena drone, etc.)
## Volume is relative to the Ambience bus — keep it subtle.
func play_ambience(stream: AudioStream, volume_db: float = -6.0) -> void:
	if stream == null:
		stop_ambience()
		return
	if _ambience.stream == stream and _ambience.playing:
		return
	_ambience.stream = stream
	_ambience.volume_db = -80.0
	_ambience.play()
	var tween := create_tween()
	tween.tween_property(_ambience, "volume_db", volume_db, AMBIENCE_FADE)
 
func stop_ambience() -> void:
	var tween := create_tween()
	tween.tween_property(_ambience, "volume_db", -80.0, AMBIENCE_FADE)
	tween.tween_callback(func(): _ambience.stop())
	
# One-shot SFX API
## Fire-and-forget a sound from SFX_TABLE by key.
## bus defaults to "UI" — pass &"World" for in-game event sounds.
## pitch_variance adds a random ± offset so repeated sounds feel less robotic.
func play_sfx(key: String, bus: StringName = &"UI",
		pitch_variance: float = 0.0) -> void:
	if not SFX_TABLE.has(key):
		push_warning("[AudioManager] Unknown SFX key: '%s'" % key)
		return
	var stream : AudioStream = SFX_TABLE[key]
	if stream == null:
		return   # asset not assigned yet — silent, no spam
 
	var player := AudioStreamPlayer.new()
	player.stream      = stream
	player.bus         = bus
	player.volume_db   = 0.0
	if pitch_variance > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	add_child(player)
	player.play()
	# Self-destruct when done
	player.finished.connect(player.queue_free)
	
	## Convenience wrappers so call sites are readable.
func play_ui(key: String) -> void:
	play_sfx(key, &"UI")
 
func play_world(key: String, pitch_variance: float = 0.05) -> void:
	play_sfx(key, &"World", pitch_variance)
