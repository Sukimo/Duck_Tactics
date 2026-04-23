extends Node
#Autoload as "GameState"

enum State{
	REST,
	SLIDE_TO_ARENA,
	PREP,
	BATTLE,
	REWARD,
	SLIDE_TO_REST,
	GAME_OVER,
	WIN
}

signal state_changed(new_state: State)

var current: State = State .REST
var lives: int = 3

func change(new_state: State)->void:
	if current ==null:
		return
	current = new_state
	print("[GameState] → %s" % State.keys()[new_state])
	emit_signal("state_changed", new_state)

func is_state(s:State)->bool:
	return current == s 
	
func reset() ->void: 
	lives = 3
	current =State.REST
