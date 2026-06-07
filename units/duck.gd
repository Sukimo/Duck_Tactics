extends CharacterBody2D
class_name BaseDuck

# ── Exports ───────────────────────────────────────────────────────────────────
@export var move_speed:            float = 120.0
@export var max_hp:                int   = 100
@export var selected_color:        Color = Color(1.0, 0.85, 0.0, 1.0)
@export var normal_color:          Color = Color(1.0, 1.0,  1.0, 1.0)
@export var duck_level:            int   = 1
@export var aggro_range:           float = 180.0
@export var leash_range:           float = 260.0
@export var player_order_duration: float = 2.0

# ── AI state machine ──────────────────────────────────────────────────────────
enum AIState { IDLE, CHASE, ATTACK, PLAYER_ORDER, RETURN_HOME, RETREAT }
var ai_state:            AIState = AIState.IDLE
var _ai_target:          Node2D  = null
var _player_order_timer: float   = 0.0

# ── Home position ─────────────────────────────────────────────────────────────
# Set on deploy. Aggro and leash are measured from here, not from duck position.
# Player order updates this so duck defends the new position after arriving.
var _home_pos: Vector2 = Vector2.ZERO

# ── Drag / click ──────────────────────────────────────────────────────────────
const HOLD_THRESHOLD: float = 0.15

# ── Level label ───────────────────────────────────────────────────────────────
const LV_OFFSET_Y:  float = -38.0
const LV_FONT_SIZE: int   = 10
const LV_COLOR:     Color = Color(1.0, 1.0, 0.3, 1.0)
const LV_COLOR_MAX: Color = Color(1.0, 0.4, 0.1, 1.0)
const LV_MAX:       int   = 3

# ── Range ring visuals ────────────────────────────────────────────────────────
const AGGRO_RING_COLOR:  Color = Color(1.0, 0.85, 0.0, 0.30)
const ATTACK_RING_COLOR: Color = Color(1.0, 0.25, 0.1, 0.40)
const HOME_CROSS_COLOR:  Color = Color(1.0, 1.0,  0.0, 0.55)

# ── Runtime ───────────────────────────────────────────────────────────────────
var hp:            int
var roster_status = DuckRoster.Status.RESTING

var _selected:    bool    = false
var _mouse_held:  bool    = false
var _hold_timer:  float   = 0.0
var _is_dragging: bool    = false
var _drag_origin: Vector2 = Vector2.ZERO
var _has_target:  bool    = false
var _target_pos:  Vector2 = Vector2.ZERO

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var sprite:           Sprite2D          = $Sprite2D
@onready var nav_agent:        NavigationAgent2D = $NavAgent
@onready var attack_component: AttackComponent   = $AttackComponent

# ── Godot ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	hp        = max_hp
	_home_pos = global_position
	nav_agent.path_desired_distance   = 4.0
	nav_agent.target_desired_distance = 8.0
	nav_agent.avoidance_enabled       = false

func _process(delta: float) -> void:
	if _mouse_held and not _is_dragging:
		_hold_timer += delta
		if _hold_timer >= HOLD_THRESHOLD:
			_mouse_held  = false
			_is_dragging = true
			_has_target  = false
			velocity     = Vector2.ZERO
			z_index      = 10
	_tick_ai(delta)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if _is_valid_target(_ai_target):
		attack_component.try_attack(_ai_target)
	_do_movement()

# ── AI tick ───────────────────────────────────────────────────────────────────
func _tick_ai(delta: float) -> void:
	if _is_dragging:
		return

	if _ai_target != null and not _is_valid_target(_ai_target):
		_ai_target = null
		if ai_state == AIState.ATTACK or ai_state == AIState.CHASE:
			ai_state = AIState.RETURN_HOME

	match ai_state:
		AIState.IDLE:
			# Scan from home — duck covers its assigned zone only
			_ai_target = _find_nearest_enemy_from(_home_pos, aggro_range)
			if _ai_target:
				ai_state = AIState.CHASE

		AIState.CHASE:
			_on_chase()

		AIState.ATTACK:
			_on_attack()

		AIState.PLAYER_ORDER:
			_player_order_timer -= delta
			# Early exit: arrived at destination and enemy nearby
			if not _has_target and _find_nearest_enemy_from(_home_pos, aggro_range) != null:
				ai_state = AIState.IDLE
				_ai_target = null
				_player_order_timer = 0.0
				return
			if _player_order_timer <= 0.0:
				ai_state   = AIState.IDLE
				_ai_target = null

		AIState.RETURN_HOME:
			_on_return_home()

		AIState.RETREAT:
			_on_retreat()

# ── Target validation ─────────────────────────────────────────────────────────
func _is_valid_target(target: Variant) -> bool:
	if not is_instance_valid(target):
		return false
	if target.is_queued_for_deletion():
		return false
	if target.get("roster_status") != null:
		if target.roster_status == DuckRoster.Status.DEAD:
			return false
	return true

# ── State hooks ───────────────────────────────────────────────────────────────
func _on_chase() -> void:
	if not _is_valid_target(_ai_target):
		_ai_target = null
		ai_state   = AIState.RETURN_HOME
		return

	# Leash measured from home — duck won't chase across the map
	var dist_from_home := _home_pos.distance_to(_ai_target.global_position)
	if dist_from_home > leash_range:
		_ai_target = null
		ai_state   = AIState.RETURN_HOME
		return

	var dist := global_position.distance_to(_ai_target.global_position)
	if dist <= attack_component.attack_range:
		_has_target = false
		velocity    = Vector2.ZERO
		ai_state    = AIState.ATTACK
	else:
		_move_to(_ai_target.global_position)

func _on_attack() -> void:
	if not _is_valid_target(_ai_target):
		_ai_target = null
		ai_state   = AIState.RETURN_HOME
		return

	_has_target = false
	velocity    = Vector2.ZERO

	# Enemy ran out of leash range from home — break off
	var dist_from_home := _home_pos.distance_to(_ai_target.global_position)
	if dist_from_home > leash_range:
		_ai_target = null
		ai_state   = AIState.RETURN_HOME
		return

	var dist := global_position.distance_to(_ai_target.global_position)
	if dist > attack_component.attack_range * 1.15:
		ai_state = AIState.CHASE

func _on_return_home() -> void:
	var dist_home := global_position.distance_to(_home_pos)
	if dist_home <= 8.0:
		# Snap to home, stop, go back to scanning
		global_position = _home_pos
		_has_target     = false
		velocity        = Vector2.ZERO
		ai_state        = AIState.IDLE
	else:
		# Check if a new enemy entered aggro range while walking home
		var new_target := _find_nearest_enemy_from(_home_pos, aggro_range)
		if new_target != null:
			_ai_target = new_target
			ai_state   = AIState.CHASE
		else:
			_move_to(_home_pos)

func _on_retreat() -> void:
	# Virtual — subclasses override for low-HP behavior
	ai_state = AIState.RETURN_HOME

# ── Targeting — scans from an anchor point, not duck position ─────────────────
func _find_nearest_enemy_from(anchor: Vector2, radius: float) -> Node2D:
	var best:      Node2D = null
	var best_dist: float  = radius
	for group in attack_component.target_group:
		for unit in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(unit) or not unit is Node2D:
				continue
			if unit.is_queued_for_deletion():
				continue
			var d := anchor.distance_to((unit as Node2D).global_position)
			if d < best_dist:
				best_dist = d
				best      = unit
	return best

# ── Movement ──────────────────────────────────────────────────────────────────
func can_move() -> bool:
	return true

func _do_movement() -> void:
	if not can_move() or not _has_target or _is_dragging:
		velocity = Vector2.ZERO
		return
	if not nav_agent.is_navigation_finished():
		var next := nav_agent.get_next_path_position()
		if next.distance_to(global_position) > 1.0:
			velocity = (next - global_position).normalized() * move_speed
			move_and_slide()
			return
	var diff := _target_pos - global_position
	if diff.length() > 8.0:
		velocity = diff.normalized() * move_speed
		move_and_slide()
	else:
		global_position = _target_pos
		velocity        = Vector2.ZERO
		_has_target     = false

func _move_to(pos: Vector2) -> void:
	_target_pos               = pos
	_has_target               = true
	nav_agent.target_position = pos

# ── Input handlers ────────────────────────────────────────────────────────────
func handle_press(_world: Vector2) -> void:
	_mouse_held  = true
	_hold_timer  = 0.0
	_drag_origin = global_position

func handle_release(world: Vector2) -> void:
	if _is_dragging:
		_is_dragging = false
		z_index      = 0
		_has_target  = false
		_try_merge_at(world)
	elif _mouse_held:
		_mouse_held = false
		_set_selected(not _selected)

func handle_motion(world: Vector2) -> void:
	if _is_dragging:
		global_position = world

func move_to_cmd(pos: Vector2) -> void:
	_move_to(pos)
	# Update home so duck defends the new position after arriving
	_home_pos           = pos
	ai_state            = AIState.PLAYER_ORDER
	_player_order_timer = player_order_duration

# ── Damage / death ────────────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	hp -= amount
	if has_node("HealthBar"):
		$HealthBar.update(hp, max_hp)
	if hp <= 0:
		die()

func die() -> void:
	print("[Duck] %s died" % name)
	reset_state()
	DuckRoster.mark_dead(self)

# ── State reset ───────────────────────────────────────────────────────────────
func reset_state() -> void:
	_selected    = false
	_mouse_held  = false
	_is_dragging = false
	_hold_timer  = 0.0
	z_index      = 0
	if sprite:
		sprite.modulate = normal_color
	_has_target = false
	_target_pos = global_position
	velocity    = Vector2.ZERO
	if is_instance_valid(nav_agent):
		nav_agent.target_position = global_position
		nav_agent.velocity        = Vector2.ZERO
	ai_state            = AIState.IDLE
	_ai_target          = null
	_player_order_timer = 0.0
	_home_pos           = global_position
	if is_instance_valid(attack_component):
		attack_component._cooldown = 0.0

# ── Merge ─────────────────────────────────────────────────────────────────────
func _try_merge_at(drop_world: Vector2) -> void:
	for duck in get_tree().get_nodes_in_group("ducks"):
		if duck == self or not duck is BaseDuck:
			continue
		var other := duck as BaseDuck
		var half  := Vector2(20, 20)
		if Rect2(other.global_position - half, half * 2).has_point(drop_world):
			MergeManager.try_merge(self, other)
			return
	global_position = _drag_origin

# ── Draw ──────────────────────────────────────────────────────────────────────
func _draw() -> void:
	if attack_component and attack_component.has_method("draw_debug"):
		attack_component.draw_debug(self)
	_draw_level_label()
	if _selected:
		_draw_range_rings()

func _draw_range_rings() -> void:
	# All drawing is in local space — convert home_pos
	var home_local := to_local(_home_pos)

	# Aggro ring — yellow, where enemies will be noticed
	draw_arc(home_local, aggro_range, 0.0, TAU, 64, AGGRO_RING_COLOR, 1.2)

	# Attack ring — red, where duck will stand and fire
	draw_arc(home_local, attack_component.attack_range, 0.0, TAU, 48,
		ATTACK_RING_COLOR, 1.2)

	# Home cross — marks the anchor point
	var s := 6.0
	draw_line(home_local + Vector2(-s, 0), home_local + Vector2(s, 0),
		HOME_CROSS_COLOR, 1.5)
	draw_line(home_local + Vector2(0, -s), home_local + Vector2(0, s),
		HOME_CROSS_COLOR, 1.5)

func _draw_level_label() -> void:
	var lv_text := "Lv" + str(duck_level) + " " + str(AIState.keys()[ai_state])
	var col     := LV_COLOR_MAX if duck_level >= LV_MAX else LV_COLOR
	var font    := ThemeDB.fallback_font
	var pos     := Vector2(
		-font.get_string_size(lv_text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, LV_FONT_SIZE).x * 0.5,
		LV_OFFSET_Y
	)
	draw_string(font, pos + Vector2(1, 1), lv_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LV_FONT_SIZE, Color(0, 0, 0, 0.7))
	draw_string(font, pos, lv_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LV_FONT_SIZE, col)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _is_click_on_self(world_pos: Vector2) -> bool:
	var half := Vector2(16, 16)
	return Rect2(global_position - half, half * 2).has_point(world_pos)

func _set_selected(value: bool) -> void:
	_selected = value
	if sprite:
		sprite.modulate = selected_color if value else normal_color

func get_selected() -> bool:  return _selected
func duck_type()    -> String: return "BaseDuck"
func force_move(pos: Vector2) -> void: _move_to(pos)
