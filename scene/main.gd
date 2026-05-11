# Scene/main.gd
extends Node2D

@onready var hud_label : Label = $CanvasLayer/HUD/Label
@onready var options_ui : Control = $CanvasLayer/OptionUI
#zone
@onready var camera: Camera2D = $Camera2D
@onready var arena_zone: Node2D = $Arena2D
@onready var rest_zone: Node2D = $RestZone
# Music streams — kept here as references so scenes don't need to know paths.
# AudioManager owns the players; main just tells it what to play.
const STREAM_REST   : AudioStream = preload("res://music/Fluffing%20a%20Duck.mp3")
const STREAM_BATTLE : AudioStream = preload("res://music/Wacky Waiting.ogg")

const SLIDE_DURATION : float = 0.6

func _ready() -> void:
	camera.global_position.x = 0.0
	WaveManager.wave_started.connect(_on_wave_started)
	WaveManager.wave_cleared.connect(_on_wave_cleared)
	WaveManager.all_waves_cleared.connect(_on_all_cleared)
	
	#signalBus
	SignalBus.slide_to_rest.connect(_slide_to_rest)
	SignalBus.slide_to_arena.connect(_slide_to_arena)
	
	#gamestate
	GameState.state_changed.connect(_on_state_changed)
	
	WaveManager.start_game()

#state reactions
func _on_state_changed(s: GameState.State)->void:
	match s:
		GameState.State.REST, GameState.State.PREP, \
		GameState.State.REWARD, GameState.State.SLIDE_TO_REST,\
		GameState.State.SLIDE_TO_ARENA:
			hud_label.text = "Global duck crit rate: %.1f%%" % GameState.global_duck_crit_rate
			AudioManager.play_music(STREAM_REST)
		GameState.State.BATTLE:
			AudioManager.play_music(STREAM_BATTLE)
		GameState.State.GAME_OVER, GameState.State.WIN, \
		GameState.State.STORY_END:
			AudioManager.stop_music()

func _on_wave_started(n: int) -> void:
	hud_label.text = "Wave %d" % n
	# AudioManager.play_world("game_wave_start")

func _on_wave_cleared() -> void:
	pass # state_changed covers this

func _on_all_cleared() -> void:
	pass # state_changed covers this
	
#camera slides
func _slide_to_rest()->void:
	#arena_zone.process_mode = Node.PROCESS_MODE_DISABLED
	rest_zone.process_mode = Node.PROCESS_MODE_INHERIT
	
	var tween := create_tween()
	tween.tween_property(camera, "global_position:x", -800.0, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(WaveManager.on_arrived_at_rest)

func _slide_to_arena()-> void:
	GameState.change(GameState.State.SLIDE_TO_ARENA)
	#rest_zone.process_mode = Node.PROCESS_MODE_DISABLED
	arena_zone.process_mode = Node.PROCESS_MODE_INHERIT
	
	var tween := create_tween()
	tween.tween_property(camera, "global_position:x", 0.0, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(WaveManager.on_arrived_at_arena)

# UI btn 
func _on_start_wave_pressed()->void:
	if GameState.is_state(GameState.State.REST):
		SignalBus.emit_signal("slide_to_arena")

func _on_options_btn_pressed()->void:
	options_ui.toggle()
