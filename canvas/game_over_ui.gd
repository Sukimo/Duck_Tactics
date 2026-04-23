extends Control 

@onready var lives_laber : Label = $Panel/VBox/LivesLabel
@onready var retry_btn : Button = $Panel/VBox/RetryButton
@onready var quit_btn : Button = $Panel/VBox/QuitButton

func _ready() -> void:
	GameState.state_changed.connect(_on_state_changed)
	visible = false

func _on_state_changed(s:GameState.State)->void:
	visible = s == GameState.State.GAME_OVER
	if visible:
		lives_laber.text = "Out of lives!\nNo ducks remain..."
		
func _on_retry_pressed()->void:
	GameState.reset()
	DuckRoster.clear_dead()
	for d in DuckRoster.get_all():
		d.queue_free()
	DuckRoster._ducks.clear()
	get_tree().reload_current_scene()
	
func _on_quit_pressed()->void:
	get_tree().quit() # on web this just freezes — consider hiding instead
