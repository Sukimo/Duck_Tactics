extends Node
# Autoload as "WaveManager"

signal wave_started(wave_number: int)
signal wave_cleared
signal all_waves_cleared

# ── Tunables ──────────────────────────────────────────────────────────────
const PREP_TIME   : float = 5.0   # seconds before battle starts
const REWARD_TIME : float = 4.0   # seconds between waves

# Each entry = one wave. Add/edit freely.
# { enemies: [ {scene, count, interval} ] }
const WAVE_DATA : Array = [
	# Wave 1 — just melee mobs
	{ "enemies": [
		{ "scene": "res://enemies/mob/melee_mob.tscn", "count": 3, "interval": 1.2 }
	]},
	# Wave 2 — melee + 1 range
	{ "enemies": [
		{ "scene": "res://enemies/mob/melee_mob.tscn", "count": 3, "interval": 1.0 },
		{ "scene": "res://enemies/mob/range_mob.tscn",  "count": 2, "interval": 1.5 }
	]},
	# Wave 3 — more pressure
	{ "enemies": [
		{ "scene": "res://enemies/mob/melee_mob.tscn", "count": 5, "interval": 0.8 },
		{ "scene": "res://enemies/mob/range_mob.tscn",  "count": 3, "interval": 1.2 }
	]},
]

# ── State ─────────────────────────────────────────────────────────────────
enum Phase { PREP, BATTLE, REWARD }
var phase        : Phase = Phase.PREP
var wave_index   : int   = 0          # 0-based
var _timer       : Timer
var _spawn_queue : Array = []          # remaining spawns this wave
var _spawn_timer : Timer

# called by Main.tscn after scene is ready
func start_game() -> void:
	wave_index = 0
	_begin_prep()

# ── Phases ────────────────────────────────────────────────────────────────
func _begin_prep() -> void:
	phase = Phase.PREP
	print("[Wave] PREP — wave %d in %.0fs" % [wave_index + 1, PREP_TIME])
	_timer.wait_time = PREP_TIME
	_timer.one_shot  = true
	_timer.start()

func _begin_battle() -> void:
	phase = Phase.BATTLE
	emit_signal("wave_started", wave_index + 1)
	print("[Wave] BATTLE — wave %d" % (wave_index + 1))
	_build_spawn_queue()
	_kick_spawn_timer()

func _begin_reward() -> void:
	phase = Phase.REWARD
	emit_signal("wave_cleared")
	print("[Wave] REWARD — next wave in %.0fs" % REWARD_TIME)
	_give_reward()
	_timer.wait_time = REWARD_TIME
	_timer.one_shot  = true
	_timer.start()

# ── Spawning ──────────────────────────────────────────────────────────────
func _build_spawn_queue() -> void:
	_spawn_queue.clear()
	var data : Dictionary = WAVE_DATA[wave_index]
	for entry in data["enemies"]:
		var scene_path : String  = entry["scene"]
		var count      : int     = entry["count"]
		var interval   : float   = entry["interval"]
		for i in count:
			_spawn_queue.append({ "scene": scene_path, "delay": interval })

func _kick_spawn_timer() -> void:
	if _spawn_queue.is_empty():
		return
	var next = _spawn_queue[0]
	_spawn_timer.wait_time = next["delay"]
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
	var scene  : PackedScene = load(scene_path)
	var mob    : Node        = scene.instantiate()
	var parent : Node        = get_tree().current_scene
	parent.add_child(mob)
	# Spawn along left edge at random Y — adjust to your arena size
	if mob is Node2D:
		(mob as Node2D).global_position = Vector2(
			randf_range(50, 150),
			randf_range(80, 370)
		)

# ── Enemy count check ─────────────────────────────────────────────────────
# Called every second by a poll timer; no custom signal needed.
func _check_enemies_dead() -> void:
	if phase != Phase.BATTLE:
		return
	# Still spawning? not clear yet.
	if not _spawn_queue.is_empty():
		return
	var alive : int = get_tree().get_nodes_in_group("enemies").size()
	if alive == 0:
		_on_wave_cleared()

func _on_wave_cleared() -> void:
	if phase != Phase.BATTLE:   # guard double-fire
		return
	wave_index += 1
	if wave_index >= WAVE_DATA.size():
		emit_signal("all_waves_cleared")
		print("[Wave] ALL WAVES DONE — you win!")
		return
	_begin_reward()

# ── Timer callbacks ───────────────────────────────────────────────────────
func _on_phase_timer_timeout() -> void:
	match phase:
		Phase.PREP:   _begin_battle()
		Phase.REWARD: _begin_prep()

# ── Ready ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Phase timer
	_timer = Timer.new()
	_timer.timeout.connect(_on_phase_timer_timeout)
	add_child(_timer)

	# Spawn timer
	_spawn_timer = Timer.new()
	_spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(_spawn_timer)

	# Poll timer — checks if all enemies dead every 0.5s
	var poll := Timer.new()
	poll.wait_time  = 0.5
	poll.one_shot   = false
	poll.timeout.connect(_check_enemies_dead)
	add_child(poll)
	poll.start()

# reward
func _give_reward() -> void:
	# Spawn 2 random ducks near the left edge (player's side)
	var duck_pool : Array = [
		"res://units/ducks/melee_duck.tscn",
		"res://units/ducks/range_duck.tscn",
	]
	for i in 2:
		var path : String = duck_pool[randi() % duck_pool.size()]
		var scene : PackedScene = load(path)
		var duck : Node = scene.instantiate()
		get_tree().current_scene.add_child(duck)
		if duck is Node2D:
			(duck as Node2D).global_position = Vector2(
				randf_range(550, 700),  # right side — player zone
				randf_range(80, 370)
			)
	print("[Wave] Reward: 2 ducks spawned")
