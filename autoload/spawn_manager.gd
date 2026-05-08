extends Node
# Autoload as "SpawnManager"
# Owns: spawn queue, spawn timer, enemy polling, edge positions
# WaveManager calls run() and listens to signals — never touches spawn internals

signal all_spawned          # last mob in queue has been spawned
signal all_enemies_dead     # spawn done + no enemies alive = wave clear
signal duck_wipe            # all deployed ducks died mid-battle
 
const ARENA_W : float = 800.0
const ARENA_H : float = 450.0
const SPAWN_MARGIN : float = 8.0

var _spawn_queue : Array = []
var _spawn_timer : Timer
var _poll_timer : Timer
var _running : bool = false

# Public API
## Call with the resolved pattern array from WaveData.get_patterns()
func run(patterns: Array) -> void:
	_spawn_queue.clear()
	for pattern in patterns:
		var edge : String = pattern.get("edge","left")
		for _i in pattern["count"]:
			_spawn_queue.append({
				"scene": pattern["scene"],
				"delay": pattern["interval"],
				"edge": edge,
			})
	_running = true
	_kick_spawn_timer()
	
## Hard stop — clears queue and frees all live enemies
func abort() -> void:
	_running = false
	_spawn_queue.clear()
	_spawn_timer.stop()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()

# Spawn
func _kick_spawn_timer()->void:
	if _spawn_queue.is_empty():
		emit_signal("all_spawned")
		return
	_spawn_timer.wait_time = _spawn_queue[0]["delay"]
	_spawn_timer.one_shot =true
	_spawn_timer.start()
	
func _on_spawn_tick()->void:
	if not _running or _spawn_queue.is_empty():
		return
	var entry = _spawn_queue.pop_front()
	_do_spawn(entry["scene"], entry["edge"])
	if not _spawn_queue.is_empty():
		_kick_spawn_timer()
	else:
		emit_signal("all_spawned")
		
func _do_spawn(scene: PackedScene,edge: String)->void:
	var mob : Node = scene.instantiate()
	get_tree().current_scene.add_child(mob)
	if mob is Node2D:
		(mob as Node2D).global_position = _edge_spawn_pos(edge)
	
func _edge_spawn_pos(edge: String)->Vector2:
	match edge:
		"left":  return Vector2(-SPAWN_MARGIN, randf_range(60.0, ARENA_H - 60.0))
		"right": return Vector2(ARENA_W + SPAWN_MARGIN, randf_range(60.0, ARENA_H - 60.0))
		"top":   return Vector2(randf_range(60.0, ARENA_W - 60.0), -SPAWN_MARGIN)
		_:       return Vector2(-SPAWN_MARGIN, randf_range(60.0, ARENA_H - 60.0))

# battle polling
func _on_poll_tick()->void:
	if not GameState.is_state(GameState.State.BATTLE):
		return
	# Duck wipe check — all deployed ducks died
	if DuckRoster.count_deployed() == 0:
		if _running:
			_running =false
			emit_signal("duck_wipe")
		return
	# Wave clear check — queue empty and no enemies alive
	if not _spawn_queue.is_empty():
		return
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is CharacterBody2D: 
			alive += 1
	if alive == 0:
		if _running:
			_running =false
			emit_signal("all_enemies_dead")

# Ready
func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(_spawn_timer)
	
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.5
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_on_poll_tick)
	add_child(_poll_timer)
	_poll_timer.start()
