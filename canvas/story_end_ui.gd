extends Control

func _ready() -> void:
	GameState.state_changed.connect(_on_state_changed)
	visible = false

func _on_state_changed(s:GameState.State)->void:
	visible = s ==GameState.State.STORY_END
	
func _on_yes_pressed()->void:
	visible =false
	WaveManager.enter_endless()
	
func _on_no_pressed()->void:
	get_tree().reload_current_scene() # get_tree().quit() for win


func _on_no_button_pressed() -> void:
	pass # Replace with function body.
