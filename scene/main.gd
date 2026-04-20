# Scene/main.gd
extends Node2D

@onready var hud_label : Label = $CanvasLayer/HUD/Label

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
