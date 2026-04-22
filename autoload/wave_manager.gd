extends Node
# Autoload as "WaveManager"

signal wave_started(wave_number: int)
signal wave_cleared
signal all_waves_cleared

const PREP_TIME   : float = 15.0
const REWARD_TIME : float = 4.0

const WAVE_DATA : Array = [
	{ "enemies": [
		{ "scene": "res://enemies/mob/melee_mob.tscn", "count": 3, "interval": 1.2 }
	]},
	{ "enemies": [
		{ "scene": "res://enemies/mob/melee_mob.tscn", "count": 3, "interval": 1.0 },
		{ "scene": "res://enemies/mob/range_mob.tscn",  "count": 2, "interval": 1.5 }
	]},
	{ "enemies": [
		{ "scene": "res://enemies/mob/melee_mob.tscn", "count": 5, "interval": 0.8 },
		{ "scene": "res://enemies/mob/range_mob.tscn",  "count": 3, "interval": 1.2 }
	]},
]

const STARTER_DUCKS : Array = [
	"res://units/ducks/melee_duck.tscn",
	"res://units/ducks/range_duck.tscn",
	"res://units/ducks/melee_duck.tscn",
] 

var wave_index   : int   = 0
var _timer       : Timer
var _spawn_queue : Array = []
var _spawn_timer : Timer

func start_game() -> void:
	wave_index = 0
	_spawn_starter_duck()
	GameState.change(GameState.State.SLIDE_TO_ARENA)
	_begin_prep()

func _spawn_starter_duck()->void:
	for path in STARTER_DUCKS:
		var duck: Node = (load(path) as PackedScene).instantiate()
		get_tree().current_scene.add_child(duck)
		if duck is BaseDuck:
			DuckRoster.add(duck as BaseDuck)
	
# Called by Main when camera finishes sliding TO arena
func on_arrived_at_arena() -> void:
	_begin_prep()

# Called by "Ready" button or prep timer expiry
func begin_battle() -> void:
	 # Place any ducks still sitting in slots
	var prep_ui = get_tree().current_scene.get_node_or_null("CanvasLayer/PrepUI")
	if prep_ui:
		prep_ui.place_remaining()
		
	GameState.change(GameState.State.BATTLE)
	emit_signal("wave_started", wave_index + 1)
	_build_spawn_queue()
	_kick_spawn_timer()

# Called by Main when camera finishes sliding TO rest
func on_arrived_at_rest() -> void:
	GameState.change(GameState.State.REST)

# ── Phases ────────────────────────────────────────────────────────────────
func _begin_prep() -> void:
	GameState.change(GameState.State.PREP)
	#give the to PrepUI
	var prep_ui =get_tree().current_scene.get_node_or_null("CanvasLayer/PrepUI")
	if prep_ui:
		var rest_zone = get_tree().current_scene.get_node_or_null("RestZone")
		var roster : Array = []
		if rest_zone and rest_zone.has_method("get_battle_roster"):
			roster = rest_zone.get_battle_roster()
			rest_zone.clear_staging()
		if roster.is_empty():
			roster = DuckRoster.get_resting() #fallback all resting ducks
		prep_ui.populate(roster)  # only resting ducks go to slots
	
	_timer.wait_time = PREP_TIME
	_timer.one_shot  = true
	_timer.start()

func _begin_reward() -> void:
	GameState.change(GameState.State.REWARD)
	emit_signal("wave_cleared")
	_give_reward()

# ── Spawn ─────────────────────────────────────────────────────────────────
func _build_spawn_queue() -> void:
	_spawn_queue.clear()
	var data : Dictionary = WAVE_DATA[wave_index]
	for entry in data["enemies"]:
		for i in entry["count"]:
			_spawn_queue.append({ "scene": entry["scene"], "delay": entry["interval"] })

func _kick_spawn_timer() -> void:
	if _spawn_queue.is_empty():
		return
	_spawn_timer.wait_time = _spawn_queue[0]["delay"]
	_spawn_timer.one_shot  = true
	_spawn_timer.start()

func _on_spawn_tick() -> void:
	if _spawn_queue.is_empty():
		return
	var entry = _spawn_queue.pop_front()
	_do_spawn(entry["scene"])
	if not _spawn_queue.is_empty():
		_kick_spawn_timer()

func _do_spawn(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_warning("[Wave] scene not found: " + scene_path)
		return
	var mob : Node = (load(scene_path) as PackedScene).instantiate()
	get_tree().current_scene.add_child(mob)
	if mob is Node2D:
		(mob as Node2D).global_position = Vector2(
			randf_range(50, 150),
			randf_range(80, 370)
		)

func _check_enemies_dead() -> void:
	if not GameState.is_state(GameState.State.BATTLE):
		return
	if not _spawn_queue.is_empty():
		return
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is CharacterBody2D:
			alive += 1
	if alive == 0:
		_on_wave_cleared()

func _on_wave_cleared() -> void:
	if not GameState.is_state(GameState.State.BATTLE):
		return
		
	# Get the list of ducks currently in BattleZone BEFORE recalling
	var battle_keepers : Array[BaseDuck] = []
	var rest_zone = get_tree().current_scene.get_node_or_null("RestZone")
	if rest_zone and rest_zone.has_method("get_battle_roster"):
		battle_keepers = rest_zone.get_battle_roster()
	
	# Recall everyone first
	DuckRoster.recall_all()   # deployed → resting
	DuckRoster.clear_dead()   # free dead nodes
	
	# Re-deploy the BattleZone ducks so they stay in place
	for duck in battle_keepers:
		if is_instance_valid(duck):
			DuckRoster.deploy(duck,duck.global_position)
	
	wave_index += 1
	if wave_index >= WAVE_DATA.size():
		GameState.change(GameState.State.WIN)
		emit_signal("all_waves_cleared")
		return
	_begin_reward()

# ── Timer callbacks ───────────────────────────────────────────────────────
func _on_phase_timer_timeout() -> void:
	match GameState.current:
		GameState.State.PREP:
			begin_battle()

# ── Reward ────────────────────────────────────────────────────────────────
func _give_reward() -> void:
	pass # RewardUI._on_state_changed(REWARD) handles everything now

func on_reward_confirmed() -> void:
	GameState.change(GameState.State.SLIDE_TO_REST)
	SignalBus.emit_signal("slide_to_rest")

# ── Ready ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_timer = Timer.new()
	_timer.timeout.connect(_on_phase_timer_timeout)
	add_child(_timer)

	_spawn_timer = Timer.new()
	_spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(_spawn_timer)

	var poll := Timer.new()
	poll.wait_time = 0.5
	poll.one_shot  = false
	poll.timeout.connect(_check_enemies_dead)
	add_child(poll)
	poll.start()
