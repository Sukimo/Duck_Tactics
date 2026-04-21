extends Node2D

func _on_button_pressed()-> void:
	SignalBus.emit_signal("slide_to_arena")
