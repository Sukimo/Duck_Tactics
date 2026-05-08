extends Node
# Autoload as "WaveManager"
# Responsibility: phase orchestration only.
# Data  → WaveData
# Spawn → SpawnManager

signal wave_started(wave_number: int)
signal wave_cleared
signal all_waves_cleared
signal spawn_edges_ready(edges: Array)

const PREP_TIME   : float = 15.0

# WaveData is a plain script — not an autoload, loaded once here
const WaveData = preload("res://autoload/wave_data.gd")

var wave_index    : int  = 0
var _endless_loop : int  = 0
var _timer        : Timer

# Game bootstrap
func start_game() -> void:
	wave_index = 0
	_endless_loop = 0
	_spawn_starter_duck()
	GameState.change(GameState.State.SLIDE_TO_ARENA)
	_begin_prep()

func _spawn_starter_duck() -> void:
	for scene in WaveData.STARTER_DUCKS:
		var duck : Node = (scene as PackedScene).instantiate()
		get_tree().current_scene.add_child(duck)
		if duck is BaseDuck:
			DuckRoster.add(duck as BaseDuck)

# Camera handshake callbacks
func on_arrived_at_arena() -> void:
	_begin_prep()

func on_arrived_at_rest() -> void:
	GameState.change(GameState.State.REST)

# Phases
func _begin_prep() -> void:
	GameState.change(GameState.State.PREP)

	# Emit edges so ArenaZone can draw spawn arrows
	var endless_arg : int = _endless_loop if GameState.endless_mode else -1
	var edges := WaveData.get_edges(wave_index, endless_arg)
	emit_signal("spawn_edges_ready", edges)
	
	# Hand roster to PrepUI
	var prep_ui  = get_tree().current_scene.get_node_or_null("CanvasLayer/PrepUI")
	var rest_zone = get_tree().current_scene.get_node_or_null("RestZone")
	if prep_ui:
		var roster : Array = []
		if rest_zone and rest_zone.has_method("get_battle_roster"):
			roster = rest_zone.get_battle_roster()
			rest_zone.clear_staging()
		if roster.is_empty():
			roster = DuckRoster.get_resting()
		prep_ui.populate(roster)
		
	_timer.wait_time = PREP_TIME
	_timer.one_shot  = true
	_timer.start()

func begin_battle() -> void:
	# Place any ducks still sitting in slots
	var prep_ui = get_tree().current_scene.get_node_or_null("CanvasLayer/PrepUI")
	if prep_ui:
		prep_ui.place_remaining()
		
	# Reset duck state
	for duck in DuckRoster.get_all():
		if is_instance_valid(duck):
			duck.reset_state()
	
	GameState.change(GameState.State.BATTLE)
	emit_signal("wave_started", wave_index + 1)
	
	# Hand patterns to SpawnManager and let it run
	var endless_arg: int = -1
	if GameState.endless_mode:
		endless_arg = _endless_loop
		_endless_loop += 1
	SpawnManager.run(WaveData.get_patterns(wave_index,endless_arg))

func _begin_reward() -> void:
	GameState.change(GameState.State.REWARD)
	emit_signal("wave_cleared")

# SpawnManager signal handlers 
func _on_all_enemies_dead()->void:
	if not GameState.is_state(GameState.State.BATTLE):
		return
	
	var rest_zone = get_tree().current_scene.get_node_or_null("RestZone")
	if rest_zone and rest_zone.has_method("snapshot_deployed"):
		rest_zone.snapshot_deployed()
	
	DuckRoster.recall_all()
	wave_index += 1
	DuckRoster.clear_dead()
	
	# Story end
	if not GameState.endless_mode and wave_index >= WaveData.STORY_WAVE_COUNT:
		_gift_matthew()
		GameState.change(GameState.State.STORY_END)
		emit_signal("all_waves_cleared")
		return
	
	# Endless special reward
	if GameState.endless_mode and wave_index % WaveData.SPECIAL_REWARD_EVERY == 0:
		GameState.change(GameState.State.REWARD)
		emit_signal("wave_cleared")
		return
		
	_begin_reward()

func _on_duck_wipe()->void:
	if not GameState.is_state(GameState.State.BATTLE):
		return
	
	SpawnManager.abort()
	GameState.lives -= 1
	print("[WaveManager] Duck wipe! Lives left: %d" % GameState.lives)
	
	DuckRoster.recall_all()
	DuckRoster.clear_dead()
	
	if GameState.lives <= 0:
		GameState.change(GameState.State.GAME_OVER)
	else:
		GameState.change(GameState.State.SLIDE_TO_REST)
		SignalBus.emit_signal("slide_to_rest")

# Prep timer
func _on_phase_timer_timeout() -> void:
	match GameState.current:
		GameState.State.PREP:
			begin_battle()

func _on_roster_changed() -> void:
	if not GameState.is_state(GameState.State.PREP):
		return
	if DuckRoster.count_resting() == 0 and _timer.time_left > 0.5:
		_fast_forward_prep()

func _fast_forward_prep() -> void:
	_timer.start(5.0)
	print("[WaveManager] All ducks placed! Fast-forwarding to 5s.")

func get_time_left() -> float:
	if _timer and not _timer.is_stopped():
		return _timer.time_left
	return 0.0
	
# Reward / endless
func on_reward_confirmed() -> void:
	GameState.change(GameState.State.SLIDE_TO_REST)
	SignalBus.emit_signal("slide_to_rest")

func enter_endless() -> void:
	GameState.endless_mode = true
	_endless_loop = 0
	print("[WaveManager] Entering endless mode!")
	GameState.change(GameState.State.SLIDE_TO_REST)
	SignalBus.emit_signal("slide_to_rest")

# Helpers
func _gift_matthew() -> void:
	var duck : Node = WaveData.MATTHEW_SCENE.instantiate()
	get_tree().current_scene.add_child(duck)
	if duck is BaseDuck:
		DuckRoster.add(duck as BaseDuck)
		print("[WaveManager] Matthew gifted to player!")

# Ready
func _ready() -> void:
	_timer = Timer.new()
	_timer.timeout.connect(_on_phase_timer_timeout)
	add_child(_timer)
	
	SpawnManager.all_enemies_dead.connect(_on_all_enemies_dead)
	SpawnManager.duck_wipe.connect(_on_duck_wipe)
	DuckRoster.roster_changed.connect(_on_roster_changed)
