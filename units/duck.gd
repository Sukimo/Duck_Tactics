extends CharacterBody2D
class_name BaseDuck

@export var move_speed: float =120.0
@export var max_hp: int =100
@export var selected_color: Color=Color(1.0,0.85,0.0,1.0) #yellow tint
@export var normal_color: Color= Color(1.0, 1.0,  1.0, 1.0)  #white
@export var duck_level: int =1

## Radius in which duck notices enemies and begins chasing.
@export var aggro_range: float = 180.0
## If enemy exceeds this distance the duck gives up and returns to IDLE.
@export var leash_range: float = 260.0
## Seconds the duck obeys a player move command before resuming AI.
@export var player_order_duration: float = 2.0

# AI state machine
enum AIState { IDLE , CHASE , ATTACK , PLAYER_ORDER , RETREAT}
var ai_state: AIState = AIState.IDLE
var _ai_target: Node2D = null
var _player_order_timer: float = 0.0 

const HOLD_THRESHOLD: float = 0.15 # seconds to distinguish click vs hold-drag
 
# Level label visual constants
const LV_OFFSET_Y  : float = -38.0   # above the health bar (-24) with a small gap
const LV_FONT_SIZE : int   = 10
const LV_COLOR     : Color = Color(1.0, 1.0, 0.3, 1.0)   # bright yellow
const LV_COLOR_MAX : Color = Color(1.0, 0.4, 0.1, 1.0)   # orange-red at lv3+
const LV_MAX       : int   = 3                             # level cap for color change

# Runtime state
var hp: int
var roster_status = DuckRoster.Status.RESTING

var _selected: bool =false
var _mouse_held: bool =false
var _hold_timer: float = 0.0
var _is_dragging: bool = false
var _drag_origin: Vector2 = Vector2.ZERO
var _has_target: bool =false #only move when a target was actually set
var _target_pos:Vector2 = Vector2.ZERO #fallback for navmesh isn't baked

# Node refs
@onready var sprite: Sprite2D = $Sprite2D
@onready var nav_agent: NavigationAgent2D =$NavAgent
@onready var attack_component: AttackComponent = $AttackComponent  # add child node in scene

func _ready() -> void:
	hp = max_hp
	nav_agent.path_desired_distance   = 4.0   # snap to each waypoint this close
	nav_agent.target_desired_distance = 8.0   # stop this close to final target
	nav_agent.avoidance_enabled       = false  # enable later for multi-duck crowds

func _draw() -> void:
	if attack_component and attack_component.has_method("draw_debug"):
		attack_component.draw_debug(self)
	_draw_level_label()

func _process(delta: float) -> void:
	# Drag hold timer — must run every frame
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

func _physics_process(delta: float) -> void:
	# Attack component now receives the AI-chosen target directly
	if _is_valid_target(_ai_target):
		attack_component.try_attack(_ai_target)
	_do_movement()

# AI tick
func _tick_ai(delta: float)->void:
	if _is_dragging: return
	
	# Invalidate stale target before state logic runs
	if _ai_target != null and not _is_valid_target(_ai_target):
		_ai_target = null
		if ai_state == AIState.ATTACK or ai_state == AIState.CHASE:
			ai_state = AIState.IDLE
			
	match ai_state:
		AIState.IDLE:
			_ai_target = _find_nearest_enemy(aggro_range)
			if _ai_target:
				ai_state = AIState.CHASE
				
		AIState.CHASE:
			_on_chase()
			
		AIState.ATTACK:
			_on_attack()
			
		AIState.PLAYER_ORDER:
			_player_order_timer -= delta
			if not _has_target and _find_nearest_enemy(aggro_range) != null:
				ai_state = AIState.IDLE
				_ai_target = null
				_player_order_timer = 0.0
				return
			if _player_order_timer <= 0.0:
				ai_state = AIState.IDLE
				_ai_target = null
				
		AIState.RETREAT:
			_on_retreat()

# Target validation
# is_instance_valid alone is NOT enough — dead ducks stay in memory.
func _is_valid_target(target: Variant) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.is_queued_for_deletion():
		return false
	if target.get("roster_status") != null:
		if target.roster_status == DuckRoster.Status.DEAD:
			return false
	return true
	
# State hooks (override in subclasses)
func _on_chase()->void:
	if not _is_valid_target(_ai_target):
		_ai_target = null
		ai_state = AIState.IDLE
		return
	var dist := global_position.distance_to(_ai_target.global_position)
	if dist > leash_range:
		_ai_target = null
		ai_state = AIState.IDLE
		return
	if dist <= attack_component.attack_range:
		_has_target = false
		velocity = Vector2.ZERO
		ai_state = AIState.ATTACK
	else:
		_move_to(_ai_target.global_position)

func _on_attack()->void:
	if not is_instance_valid(_ai_target):
		_ai_target = null
		ai_state = AIState.IDLE
		return
		
	_has_target = false
	velocity = Vector2.ZERO
	var dist := global_position.distance_to(_ai_target.global_position)
	# Small hysteresis prevents state flickering at the range boundary
	if dist > attack_component.attack_range * 1.15:
		ai_state = AIState.CHASE
	
func _on_retreat()->void:
	# Base does nothing — subclasses can use this for low-HP fallback
	ai_state = AIState.IDLE

# Targeting
func _find_nearest_enemy(radius: float) -> Node2D:
	var best: Node2D = null
	var best_dist: float = radius
	for group in attack_component.target_group:
		for unit in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(unit) or not unit is Node2D:
				continue
			var d := global_position.distance_to((unit as Node2D).global_position)
			if d < best_dist:
				best_dist = d
				best = unit
	return best 

# Movement
func can_move()-> bool: return true
func _do_movement()->void:
	if not can_move() or not _has_target or _is_dragging:
		velocity =Vector2.ZERO
		return
	if not nav_agent.is_navigation_finished():
		var next: Vector2 = nav_agent.get_next_path_position()
		if next.distance_to(global_position) > 1.0:
			velocity = (next - global_position).normalized() * move_speed
			move_and_slide()
			return
	# --- Fallback: direct straight-line movement (no baked navmesh needed) ---
	var diff: Vector2 =_target_pos -global_position
	if diff.length() >8.0:
		velocity = diff.normalized()*move_speed
		move_and_slide()
	else:
		global_position =_target_pos
		velocity =Vector2.ZERO
		_has_target = false # arrived — stop moving

func _move_to(pos:Vector2)->void:
	_target_pos = pos
	_has_target = true
	nav_agent.target_position = pos

# Input handlers (called by InputManager)
func handle_press(world: Vector2)->void:
	_mouse_held = true
	_hold_timer = 0.0
	_drag_origin = global_position
	
func handle_release(world: Vector2)->void:
	if _is_dragging:
		_is_dragging = false
		z_index = 0
		_has_target = false
		_try_merge_at(world)
	elif _mouse_held:
		_mouse_held = false
		_set_selected(not _selected) # tap = toggle select
		
func handle_motion(world: Vector2)->void:
	if _is_dragging:
		global_position = world
	
func move_to_cmd(pos: Vector2)->void:
	_move_to(pos)
	ai_state = AIState.PLAYER_ORDER
	_player_order_timer = player_order_duration
	# intentionally keep _selected = true 

# Damege / death
func take_damage(amount: int) -> void:
	hp -=amount
	if has_node("HealthBar"):
		$HealthBar.update(hp,max_hp)
	#print("[Duck] %s took %d dmg (%d/%d)" % [name, amount, hp, max_hp])
	if hp <= 0:
		die()
		
func die() -> void:
	print("[Duck] %s died" % name)
	reset_state()
	DuckRoster.mark_dead(self)
	
# State reset
func reset_state()->void:
	# Input / drag
	_selected    = false
	_mouse_held  = false
	_is_dragging = false
	_hold_timer  = 0.0
	z_index      = 0
	if sprite:
		sprite.modulate = normal_color
	# Movement
	_has_target = false
	_target_pos = global_position
	velocity    = Vector2.ZERO
	# NavAgent — cancel any queued path
	if is_instance_valid(nav_agent):
		nav_agent.target_position = global_position  # point at self = no movement
		nav_agent.velocity = Vector2.ZERO
	# AI
	ai_state = AIState.IDLE
	_ai_target = null
	_player_order_timer = 0.0
	# Attack cooldown reset 
	if is_instance_valid(attack_component):
		attack_component._cooldown = 0.0
	
# Merge drop
func _try_merge_at(drop_world: Vector2)->void:
	# Find any duck under the drop point (except self)
	for duck in get_tree().get_nodes_in_group("ducks"):
		if duck == self or not duck is BaseDuck:
			continue
		var other := duck as BaseDuck
		var half := Vector2(20,20)
		var rect := Rect2(other.global_position- half,half*2)
		if rect.has_point(drop_world):
			MergeManager.try_merge(self,other)
			return
	global_position = _drag_origin

# Helpers
func _is_click_on_self(world_pos:Vector2) -> bool:
	#AABB check (32x32) centered on origin
	var half:=Vector2(16,16)
	var rect:= Rect2(global_position - half,half*2)
	return rect.has_point(world_pos)

func _set_selected(value:bool)->void:
	_selected = value
	if sprite:
		sprite.modulate = selected_color if value else normal_color

func _draw_level_label() -> void:
	var lv_text : String = "Lv" + str(duck_level) + " " + str(ai_state)
	var col     : Color  = LV_COLOR_MAX if duck_level >= LV_MAX else LV_COLOR
	var font    : Font   = ThemeDB.fallback_font
	var pos     : Vector2 = Vector2(
		-ThemeDB.fallback_font.get_string_size(lv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LV_FONT_SIZE).x * 0.5,
		LV_OFFSET_Y
	)
	# Tiny dark shadow for readability on any background
	draw_string(font, pos + Vector2(1, 1), lv_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LV_FONT_SIZE, Color(0, 0, 0, 0.7))
	draw_string(font, pos, lv_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LV_FONT_SIZE, col)
		
#public API
func get_selected()->bool: return _selected
func duck_type()-> String: return "BaseDuck"
func force_move(pos:Vector2)->void: _move_to(pos)
