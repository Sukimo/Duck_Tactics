# Scene/main.gd
extends Node2D

@onready var hud_label : Label = $CanvasLayer/HUD/Label

@onready var camera: Camera2D = $Camera2D
@onready var arena_zone: Node2D = $Arena2D
@onready var rest_zone: Node2D = $RestZone

func _ready() -> void:
	WaveManager.wave_started.connect(_on_wave_started)
	WaveManager.wave_cleared.connect(_on_wave_cleared)
	WaveManager.all_waves_cleared.connect(_on_all_cleared)
	WaveManager.start_game()

func _on_wave_started(n: int) -> void:
	hud_label.text = "Wave %d" % n

func _on_wave_cleared() -> void:
	hud_label.text = "Wave cleared! Next wave soon..."

func _on_all_cleared() -> void:
	hud_label.text = "YOU WIN — all waves cleared!"
	
func transition_to_rest_zone()->void:
	arena_zone.process_mode = Node.PROCESS_MODE_DISABLED
	rest_zone.process_mode = Node.PROCESS_MODE_INHERIT
	
	var tween := create_tween()
	tween.tween_property(camera, "global_position:x", -800.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func transition_to_arena()-> void:
	rest_zone.process_mode = Node.PROCESS_MODE_DISABLED
	arena_zone.process_mode = Node.PROCESS_MODE_INHERIT
	
	var tween := create_tween()
	tween.tween_property(camera, "global_position:x", 0.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
