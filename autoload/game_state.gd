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
	STORY_END,
	WIN
}

signal state_changed(new_state: State)

var current: State = State .REST
var lives: int = 3
var endless_mode: bool= false

# ── Global crit stats (shared by all duck attack components) ──────────────────
var global_duck_crit_rate: float = 0.05  # 5% base — Matthew aura adds to this
var global_duck_crit_mult: float = 2.0   # default multiplier for all ducks
var matthew_crit_mult:     float = 10.0  # Matthew's personal multiplier

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
	endless_mode = false
	current =State.REST
	global_duck_crit_rate = 0.05
	global_duck_crit_mult  =2.0 
