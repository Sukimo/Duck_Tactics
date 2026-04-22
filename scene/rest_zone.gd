extends Node2D
# scene/rest_zone.gd
# Handles the three Rest Zone areas:
#   HealZone  (blue)  — ducks standing here regenerate HP, marked RESTING/not in battle roster
#   BattleZone (red)  — ducks dragged here get flagged for the next PrepUI populate()
#   PoolZone  (green) — default landing zone for all ducks, no special logic

# ── Heal config ───────────────────────────────────────────────────────────────
const HEAL_TICK_INTERVAL : float = 1.0   # seconds between each heal tick
const HEAL_AMOUNT        : int   = 5     # HP restored per tick

const ZONE_BOUNDS : Rect2 = Rect2(Vector2(0,0),Vector2(800, 450))

@onready var hud_label   : Label  = $Control/HUDLabel
@onready var start_btn   : Button = $Control/StartBattleButton

# Ducks currently inside each zone (CharacterBody2D that are BaseDuck)
var _ducks_in_heal   : Array[BaseDuck] = []
var _ducks_in_battle : Array[BaseDuck] = []   # flagged for next battle
var _heal_timer : float = 0.0

# ── Godot ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_style_start_button()
	DuckRoster.roster_changed.connect(_update_hud)
	GameState.state_changed.connect(_on_state_changed)
	_update_hud()

func _process(delta: float) -> void:
	if GameState.is_state(GameState.State.REST):
		_heal_timer += delta
		if _heal_timer >= HEAL_TICK_INTERVAL:
			_heal_timer = 0.0
			_do_heal_tick()
	# Always guard RestZone — enemies can wander here even mid-battle
	_push_out_intruders()

# ── Button — "Start Battle" ───────────────────────────────────────────────────

func _on_button_pressed() -> void:
	if not GameState.is_state(GameState.State.REST):
		return
	SignalBus.emit_signal("slide_to_arena")

# ── Zone signals — HealZone ───────────────────────────────────────────────────

func _on_heal_zone_body_entered(body: Node2D) -> void:
	if body is BaseDuck and not _ducks_in_heal.has(body as BaseDuck):
		_ducks_in_heal.append(body as BaseDuck)

func _on_heal_zone_body_exited(body: Node2D) -> void:
	if body is BaseDuck:
		_ducks_in_heal.erase(body as BaseDuck)

# ── Zone signals — BattleZone ─────────────────────────────────────────────────
# Ducks dragged into the red zone are remembered so WaveManager can
# use them as the battle roster (instead of all resting ducks).

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
 
		# Find the nearest edge of ZONE_BOUNDS and teleport the enemy just outside it
		# Clamp to boundary then nudge 4px outward on the closest axis
		var clamped := Vector2(
			clamp(local_pos.x, ZONE_BOUNDS.position.x, ZONE_BOUNDS.end.x),
			clamp(local_pos.y, ZONE_BOUNDS.position.y, ZONE_BOUNDS.end.y)
		)
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

# ── Heal logic ────────────────────────────────────────────────────────────────
func _do_heal_tick() -> void:
	_ducks_in_heal = _ducks_in_heal.filter(func(d): return is_instance_valid(d))
	for duck in _ducks_in_heal:
		if duck.roster_status == DuckRoster.Status.DEAD:
			continue
		if duck.hp >= duck.max_hp:
			continue
		duck.hp = min(duck.hp + HEAL_AMOUNT, duck.max_hp)
		if duck.has_node("HealthBar"):
			duck.get_node("HealthBar").update(duck.hp, duck.max_hp)
 
# ── Public API ────────────────────────────────────────────────────────────────

## Returns the ducks currently staged in BattleZone.
## WaveManager can call this instead of DuckRoster.get_resting() to populate
## PrepUI only with ducks the player intentionally dragged to the red zone.
func get_battle_roster() -> Array[BaseDuck]:
	_ducks_in_battle = _ducks_in_battle.filter(func(d): return is_instance_valid(d))
	return _ducks_in_battle.duplicate()

## Clear staging lists (called after wave starts)
func clear_staging() -> void:
	#_ducks_in_battle.clear()
	_ducks_in_heal.clear()
	
# ── Scatter resting ducks into Pool zone ──────────────────────────────────────
 
func _scatter_ducks_in_pool() -> void:
	var pool_origin := Vector2(520, 55)
	var resting := DuckRoster.get_resting()
	for i in resting.size():
		var duck := resting[i]
		if not is_instance_valid(duck):
			continue
		duck.visible = true
		duck.process_mode = Node.PROCESS_MODE_INHERIT
		var col := i % 5
		var row := i / 5
		var local_pos := pool_origin + Vector2(col * 52 + 8, row * 52 + 8)
		duck.global_position = to_global(local_pos)
 
# ── HUD ───────────────────────────────────────────────────────────────────────

func _update_hud() -> void:
	if not is_instance_valid(hud_label):
		return
	var wave_num : int = WaveManager.wave_index + 1
	var duck_count : int = DuckRoster.count_total()
	# Money: hook up GameState.money when you add an economy system
	var money : int = 0
	hud_label.text = "Wave: %d   Ducks: %d   Money: %d" % [wave_num, duck_count, money]

func _on_state_changed(s: GameState.State) -> void:
	# Show/hide rest zone UI
	var is_rest := s == GameState.State.REST
	if is_instance_valid(start_btn):
		start_btn.visible = is_rest
	if is_rest:
		_update_hud()
		# Spawn resting ducks visually into the PoolZone on return
		_scatter_ducks_in_pool()

# ── Button style (purple) ─────────────────────────────────────────────────────

func _style_start_button() -> void:
	if not is_instance_valid(start_btn):
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color          = Color(0.55, 0.20, 0.75)
	normal.corner_radius_top_left     = 10
	normal.corner_radius_top_right    = 10
	normal.corner_radius_bottom_left  = 10
	normal.corner_radius_bottom_right = 10
	normal.content_margin_left   = 16.0
	normal.content_margin_right  = 16.0
	normal.content_margin_top    = 6.0
	normal.content_margin_bottom = 6.0

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.65, 0.28, 0.88)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.42, 0.12, 0.60)

	start_btn.add_theme_stylebox_override("normal",   normal)
	start_btn.add_theme_stylebox_override("hover",    hover)
	start_btn.add_theme_stylebox_override("pressed",  pressed)
	start_btn.add_theme_font_size_override("font_size", 14)
	start_btn.add_theme_color_override("font_color",        Color.WHITE)
	start_btn.add_theme_color_override("font_hover_color",  Color.WHITE)
	start_btn.add_theme_color_override("font_pressed_color",Color(0.9, 0.9, 0.9))
