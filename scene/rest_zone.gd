extends Node2D
# scene/rest_zone.gd
# Handles the three Rest Zone areas:
#   HealZone  (blue)  — ducks standing here regenerate HP, marked RESTING/not in battle roster
#   BattleZone (red)  — ducks dragged here get flagged for the next PrepUI populate()
#   PoolZone  (green) — default landing zone for all ducks, no special logic

# ── Constants ───────────────────────────────────────────────────────────────
#BattleZone rect approx: x 330..510, y 30..370  (center x=420, half=90)
const BATTLE_ORIGIN: Vector2 = Vector2(335,55)
const BATTLE_COLS: int = 3

#PoolZone rect approx: x 510..810, y 30..370  (center x=660, half=150)
const POOL_ORIGIN : Vector2 = Vector2(520,55)
const POOL_COLS : int = 5

#RestZone local-space boundary for enemy push-out
const ZONE_BOUNDS : Rect2 = Rect2(Vector2(0,0),Vector2(800,450))

@onready var hud_label   : Label  = $Control/HUDLabel
@onready var start_btn   : Button = $Control/StartBattleButton

# Ducks currently inside each zone (CharacterBody2D that are BaseDuck)
var _ducks_in_heal   : Array[BaseDuck] = []
var _ducks_in_battle : Array[BaseDuck] = []   # flagged for next battle

var _last_wave_deployed : Array[BaseDuck] =[]

# ── Godot ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	DuckRoster.roster_changed.connect(_update_hud)
	GameState.state_changed.connect(_on_state_changed)
	_update_hud()

func _process(delta: float) -> void:
	_push_out_intruders()

# ── Button — "Start Battle" ───────────────────────────────────────────────────

func _on_button_pressed() -> void:
	if not GameState.is_state(GameState.State.REST):
		return
	SignalBus.emit_signal("slide_to_arena")

# ── Zone overlap signals  ───────────────────────────────────────────────────

func _on_heal_zone_body_entered(body: Node2D) -> void:
	if body is BaseDuck and not _ducks_in_heal.has(body as BaseDuck):
		_ducks_in_heal.append(body as BaseDuck)

func _on_heal_zone_body_exited(body: Node2D) -> void:
	if body is BaseDuck:
		_ducks_in_heal.erase(body as BaseDuck)

func _on_battle_zone_body_entered(body: Node2D) -> void:
	if body is BaseDuck and not _ducks_in_battle.has(body as BaseDuck):
		_ducks_in_battle.append(body as BaseDuck)

func _on_battle_zone_body_exited(body: Node2D) -> void:
	if body is BaseDuck:
		_ducks_in_battle.erase(body as BaseDuck)
		
# ── Enemy push-out (NO chasing — enemies are expelled, ducks stay put) ────────
 
func _push_out_intruders() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var e := enemy as Node2D
		var local_pos : Vector2 = to_local(e.global_position)
		if not ZONE_BOUNDS.has_point(local_pos):
			continue
 
		# Distance to each edge
		var dist_left   := local_pos.x - ZONE_BOUNDS.position.x
		var dist_right  := ZONE_BOUNDS.end.x - local_pos.x
		var dist_top    := local_pos.y - ZONE_BOUNDS.position.y
		var dist_bottom := ZONE_BOUNDS.end.y - local_pos.y
		var min_dist    :float= min(min(dist_left, dist_right), min(dist_top, dist_bottom))
 
		var push_local : Vector2 = local_pos
		if min_dist == dist_left:
			push_local.x = ZONE_BOUNDS.position.x - 4.0
		elif min_dist == dist_right:
			push_local.x = ZONE_BOUNDS.end.x + 4.0
		elif min_dist == dist_top:
			push_local.y = ZONE_BOUNDS.position.y - 4.0
		else:
			push_local.y = ZONE_BOUNDS.end.y + 4.0
 
		e.global_position = to_global(push_local)

# ── Public API ────────────────────────────────────────────────────────────────
## Called by WaveManager._on_wave_cleared() BEFORE recall_all(),
## so we can snapshot which ducks were deployed this wave.
func snapshot_deployed()-> void:
	_last_wave_deployed = DuckRoster.get_deployed().duplicate()

## Called by WaveManager._begin_prep() — returns ducks in the red zone.
func get_battle_roster() -> Array[BaseDuck]:
	_ducks_in_battle = _ducks_in_battle.filter(func(d): return is_instance_valid(d))
	return _ducks_in_battle.duplicate()

## Clear staging lists (called after wave starts)
func clear_staging() -> void:
	_ducks_in_heal.clear()

# ── On return to REST state ───────────────────────────────────────────────────
 
func _on_state_changed(s: GameState.State) -> void:
	# Show/hide rest zone UI
	var is_rest := s == GameState.State.REST
	if is_instance_valid(start_btn):
		start_btn.visible = is_rest
	if is_rest:
		_update_hud()
		_apply_heal_zone_restore()
		_place_returned_ducks_in_battle_zone()
		# Spawn resting ducks visually into the PoolZone on return
		_scatter_resting_into_pool()

# ── Heal — full restore at wave start (not per-tick) ─────────────────────────
 
func _apply_heal_zone_restore() -> void:
	_ducks_in_heal = _ducks_in_heal.filter(func(d): return is_instance_valid(d))
	for duck in _ducks_in_heal:
		if duck.roster_status == DuckRoster.Status.DEAD:
			continue
		duck.hp = duck.max_hp
		if duck.has_node("HealthBar"):
			duck.get_node("HealthBar").update(duck.hp, duck.max_hp)
	
# ── Place returned (previously deployed) ducks into BattleZone grid ──────────

func _place_returned_ducks_in_battle_zone() -> void:
	_last_wave_deployed = _last_wave_deployed.filter(func(d): return is_instance_valid(d))
	for i in _last_wave_deployed.size():
		var duck := _last_wave_deployed[i]
		# Duck is now RESTING after recall_all() — just reposition it
		var col      := i % BATTLE_COLS
		var row      := i / BATTLE_COLS
		var local_pos := BATTLE_ORIGIN + Vector2(col * 52 + 8, row * 52 + 8)
		duck.global_position = to_global(local_pos)
		duck.visible         = true
		duck.process_mode    = Node.PROCESS_MODE_INHERIT
	_last_wave_deployed.clear()
	
# ── Scatter all other resting ducks into Pool (green) zone ───────────────────
 
func _scatter_resting_into_pool() -> void:
	# Resting ducks NOT already sitting in the battle zone area
	var pool_ducks := DuckRoster.get_resting().filter(
		func(d): return is_instance_valid(d) and not _ducks_in_battle.has(d)
	)
	for i in pool_ducks.size():
		var duck      :BaseDuck = pool_ducks[i]
		var col       := i % POOL_COLS
		var row       := i / POOL_COLS
		var local_pos := POOL_ORIGIN + Vector2(col * 52 + 8, row * 52 + 8)
		duck.global_position = to_global(local_pos)
		duck.visible         = true
		duck.process_mode    = Node.PROCESS_MODE_INHERIT
		
# ── HUD ───────────────────────────────────────────────────────────────────────

func _update_hud() -> void:
	if not is_instance_valid(hud_label):
		return
	var wave_num : int = WaveManager.wave_index + 1
	var duck_count : int = DuckRoster.count_total()
	# Money: hook up GameState.money when you add an economy system
	var money : int = 0
	hud_label.text = "Wave: %d   Ducks: %d   Money: %d" % [wave_num, duck_count, money]
