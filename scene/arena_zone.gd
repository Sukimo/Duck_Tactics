extends Node2D

@onready var control : Control = $Control
@onready var timer_laber : Label = $Control/TimeLabel
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameState.state_changed.connect(_on_state_changed)

func _process(delta: float) -> void:
	if GameState.is_state(GameState.State.PREP):
		var time_left = WaveManager.get_time_left()
		timer_laber.text = str(int(ceil(time_left))) + "s"
	else:
		timer_laber.text = ""

func _on_state_changed(s: GameState.State)->void:
	control.visible = (s == GameState.State.PREP)
