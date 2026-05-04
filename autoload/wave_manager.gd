extends Node
# Autoload as "WaveManager"

signal wave_started(wave_number: int)
signal wave_cleared
signal all_waves_cleared
signal spawn_edges_ready(edges: Array)

const PREP_TIME   : float = 15.0
const REWARD_TIME : float = 4.0

const ARENA_W      : float = 800.0
const ARENA_H      : float = 450.0
const SPAWN_MARGIN : float = 8.0

const SPECIAL_REWARD_EVERY : int = 3

# ── Preload ALL scenes ────────────────────────────────────────────────────
const MATTHEW_SCENE    := preload("res://units/ducks/matthew_duck.tscn")
const MELEE_MOB_SCENE  := preload("res://enemies/mob/melee_mob.tscn")
const RANGE_MOB_SCENE  := preload("res://enemies/mob/range_mob.tscn")
const MELEE_DUCK_SCENE := preload("res://units/ducks/melee_duck.tscn")
const RANGE_DUCK_SCENE := preload("res://units/ducks/range_duck.tscn")

# ── Wave data — ใช้ PackedScene แทน string ───────────────────────────────
const WAVE_DATA : Array = [
	{ "enemies": [
		{ "scene": MELEE_MOB_SCENE, "count": 3, "interval": 1.2, "edge": "left" }
	]},
	{ "enemies": [
		{ "scene": MELEE_MOB_SCENE, "count": 3, "interval": 1.0, "edge": "left"  },
		{ "scene": RANGE_MOB_SCENE, "count": 2, "interval": 1.5, "edge": "right" }
	]},
	{ "enemies": [
		{ "scene": MELEE_MOB_SCENE, "count": 5, "interval": 0.8, "edge": "left" },
		{ "scene": RANGE_MOB_SCENE, "count": 3, "interval": 1.2, "edge": "top"  }
	]},
]

const ENDLESS_BASE : Dictionary = {
	"enemies": [
		{ "scene": MELEE_MOB_SCENE, "count": 4, "interval": 0.8, "edge": "left"  },
		{ "scene": RANGE_MOB_SCENE, "count": 3, "interval": 1.0, "edge": "right" }
	]
}

const STARTER_DUCKS : Array = [
	MELEE_DUCK_SCENE,
	RANGE_DUCK_SCENE,
	MELEE_DUCK_SCENE,
]

const STORY_WAVE_COUNT : int = 3

var wave_index    : int  = 0
var _endless_loop : int  = 0
var _timer        : Timer
var _spawn_queue  : Array = []
var _spawn_timer  : Timer
var _active_edges : Array = []

func start_game() -> void:
	wave_index = 0
	_endless_loop = 0
	_spawn_starter_duck()
	GameState.change(GameState.State.SLIDE_TO_ARENA)
	_begin_prep()

func _spawn_starter_duck() -> void:
	for scene in STARTER_DUCKS:
		var duck : Node = (scene as PackedScene).instantiate()
		get_tree().current_scene.add_child(duck)
		if duck is BaseDuck:
			DuckRoster.add(duck as BaseDuck)

func on_arrived_at_arena() -> void:
	_begin_prep()

func begin_battle() -> void:
	var prep_ui = get_tree().current_scene.get_node_or_null("CanvasLayer/PrepUI")
	if prep_ui:
		prep_ui.place_remaining()
		
	#reset duck
	for duck in DuckRoster.get_all():
		if is_instance_valid(duck):
			duck.reset_state()
	
	GameState.change(GameState.State.BATTLE)
	emit_signal("wave_started", wave_index + 1)
	_build_spawn_queue()
	_kick_spawn_timer()

func on_arrived_at_rest() -> void:
	GameState.change(GameState.State.REST)

func _begin_prep() -> void:
	GameState.change(GameState.State.PREP)
	_collect_active_edges()
	emit_signal("spawn_edges_ready", _active_edges.duplicate())
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

func _begin_reward() -> void:
	GameState.change(GameState.State.REWARD)
	emit_signal("wave_cleared")

# ── Spawn ─────────────────────────────────────────────────────────────────
func _collect_active_edges() -> void:
	_active_edges.clear()
	var data : Dictionary = _get_wave_data()
	for entry in data["enemies"]:
		var edge : String = entry.get("edge", "left")
		if not _active_edges.has(edge):
			_active_edges.append(edge)

func _get_wave_data() -> Dictionary:
	if GameState.endless_mode:
		return _scale_endless()
	return WAVE_DATA[wave_index]

func _build_spawn_queue() -> void:
	_spawn_queue.clear()
	var data : Dictionary = _get_wave_data()
	for entry in data["enemies"]:
		var edge : String = entry.get("edge", "left")
		for _i in entry["count"]:
			_spawn_queue.append({
				"scene": entry["scene"],
				"delay": entry["interval"],
				"edge":  edge
			})

func _scale_endless() -> Dictionary:
	var loop        := _endless_loop
	_endless_loop   += 1
	var melee_count : int   = 4 + loop * 2
	var range_count : int   = 3 + loop
	var interval    : float = max(0.4, 0.8 - loop * 0.05)
	return {
		"enemies": [
			{ "scene": MELEE_MOB_SCENE, "count": melee_count, "interval": interval,       "edge": "left"  },
			{ "scene": RANGE_MOB_SCENE, "count": range_count, "interval": interval + 0.2, "edge": "right" }
		]
	}

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
	_do_spawn(entry["scene"], entry["edge"])
	if not _spawn_queue.is_empty():
		_kick_spawn_timer()

func _do_spawn(scene: PackedScene, edge: String) -> void:
	var mob : Node = scene.instantiate()
	get_tree().current_scene.add_child(mob)
	if mob is Node2D:
		(mob as Node2D).global_position = _edge_spawn_pos(edge)

func _edge_spawn_pos(edge: String) -> Vector2:
	match edge:
		"left":  return Vector2(-SPAWN_MARGIN, randf_range(60.0, ARENA_H - 60.0))
		"right": return Vector2(ARENA_W + SPAWN_MARGIN, randf_range(60.0, ARENA_H - 60.0))
		"top":   return Vector2(randf_range(60.0, ARENA_W - 60.0), -SPAWN_MARGIN)
		_:       return Vector2(-SPAWN_MARGIN, randf_range(60.0, ARENA_H - 60.0))

func _check_enemies_dead() -> void:
	if not GameState.is_state(GameState.State.BATTLE):
		return
	if DuckRoster.count_deployed() == 0:
		_on_all_duck_dead()
		return
	if not _spawn_queue.is_empty():
		return
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is CharacterBody2D:
			alive += 1
	if alive == 0:
		_on_wave_cleared()

func _on_all_duck_dead() -> void:
	if not GameState.is_state(GameState.State.BATTLE):
		return
	_spawn_queue.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	GameState.lives -= 1
	print("[WaveManager] Duck wipe! Lives left: %d" % GameState.lives)
	DuckRoster.recall_all()
	DuckRoster.clear_dead()
	if GameState.lives <= 0:
		GameState.change(GameState.State.GAME_OVER)
	else:
		GameState.change(GameState.State.SLIDE_TO_REST)
		SignalBus.emit_signal("slide_to_rest")

func _on_wave_cleared() -> void:
	if not GameState.is_state(GameState.State.BATTLE):
		return
	var rest_zone = get_tree().current_scene.get_node_or_null("RestZone")
	if rest_zone and rest_zone.has_method("snapshot_deployed"):
		rest_zone.snapshot_deployed()
	DuckRoster.recall_all()
	wave_index += 1
	DuckRoster.clear_dead()
	if not GameState.endless_mode and wave_index >= STORY_WAVE_COUNT:
		_gift_matthew()
		GameState.change(GameState.State.STORY_END)
		emit_signal("all_waves_cleared")
		return
	if GameState.endless_mode and wave_index % SPECIAL_REWARD_EVERY == 0:
		GameState.change(GameState.State.REWARD)
		emit_signal("wave_cleared")
		return
	_begin_reward()

func enter_endless() -> void:
	GameState.endless_mode = true
	_endless_loop = 0
	print("[WaveManager] Entering endless mode!")
	GameState.change(GameState.State.SLIDE_TO_REST)
	SignalBus.emit_signal("slide_to_rest")

func _gift_matthew() -> void:
	var duck : Node = MATTHEW_SCENE.instantiate()
	get_tree().current_scene.add_child(duck)
	if duck is BaseDuck:
		DuckRoster.add(duck as BaseDuck)
		print("[WaveManager] Matthew gifted to player!")

func _on_phase_timer_timeout() -> void:
	match GameState.current:
		GameState.State.PREP:
			begin_battle()

func _on_roster_changed() -> void:
	if not GameState.is_state(GameState.State.PREP):
		return
	if DuckRoster.count_resting() == 0:
		if _timer and _timer.time_left > 5.0:
			_fast_forward_prep()

func _fast_forward_prep() -> void:
	if GameState.is_state(GameState.State.PREP) and _timer.time_left > 5.0:
		_timer.start(5.0)
		print("[WaveManager] All ducks placed! Fast-forwarding to 5s.")

func get_time_left() -> float:
	if _timer and not _timer.is_stopped():
		return _timer.time_left
	return 0.0

func on_reward_confirmed() -> void:
	GameState.change(GameState.State.SLIDE_TO_REST)
	SignalBus.emit_signal("slide_to_rest")

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
	DuckRoster.roster_changed.connect(_on_roster_changed)
