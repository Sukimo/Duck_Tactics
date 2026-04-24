extends CharacterBody2D
class_name BaseDuck

@export var move_speed: float =120.0
@export var max_hp: int =100
@export var selected_color: Color=Color(1.0,0.85,0.0,1.0) #yellow tint
@export var normal_color: Color= Color(1.0, 1.0,  1.0, 1.0)  #white
@export var duck_level: int =1

const HOLD_THRESHOLD: float =0.15 # seconds to distinguish click vs hold-drag

 
# Level label visual constants
const LV_OFFSET_Y  : float = -38.0   # above the health bar (-24) with a small gap
const LV_FONT_SIZE : int   = 10
const LV_COLOR     : Color = Color(1.0, 1.0, 0.3, 1.0)   # bright yellow
const LV_COLOR_MAX : Color = Color(1.0, 0.4, 0.1, 1.0)   # orange-red at lv3+
const LV_MAX       : int   = 3                             # level cap for color change

var _mouse_held: bool =false
var _hold_timer: float = 0.0
var _is_dragging: bool = false
var _drag_origin: Vector2 = Vector2.ZERO

var roster_status = DuckRoster.Status.RESTING

#node refs
@onready var sprite: Sprite2D = $Sprite2D
@onready var nav_agent: NavigationAgent2D =$NavAgent
@onready var attack_component: AttackComponent = $AttackComponent  # add child node in scene

var hp: int
var _selected: bool =false
var _has_target: bool =false #only move when a target was actually set
var _target_pos:Vector2 = Vector2.ZERO #fallback for navmesh isn't baked

func _ready() -> void:
	hp = max_hp
	nav_agent.path_desired_distance   = 4.0   # snap to each waypoint this close
	nav_agent.target_desired_distance = 8.0   # stop this close to final target
	nav_agent.avoidance_enabled       = false  # enable later for multi-duck crowds

func _draw() -> void:
	if attack_component and attack_component.has_method("draw_debug"):
		attack_component.draw_debug(self)
	_draw_level_label()

func _draw_level_label() -> void:
	var lv_text : String = "Lv" + str(duck_level)
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
		
# input
func _input(event: InputEvent) -> void:
	#drag pick-up
	if (event is InputEventMouseButton 
			and event.button_index == MOUSE_BUTTON_LEFT): 
		var world := get_global_mouse_position()
		
		#press
		if event.pressed:
			if _is_click_on_self(world):
				#start hold timer clikc or drag in _process
				_mouse_held=true
				_hold_timer=0.0
				get_viewport().set_input_as_handled()
			elif _selected:
				#clicked world while selected move command
				_move_to(world)
				_set_selected(false)
				get_viewport().set_input_as_handled()
			return
		#release
		if not event.pressed:
			if _is_dragging:
				#end drag > attempt merge
				_is_dragging=false
				z_index=0
				_has_target =false
				_try_merge_at(world)
				get_viewport().set_input_as_handled()
			elif _mouse_held:
				#release before hold threshold > treat as plain click >select
				_mouse_held =false
				_set_selected(true)
				get_viewport().set_input_as_handled()
			return
	#drag follow
	if event is InputEventMouseMotion and _is_dragging:
		global_position =get_global_mouse_position()
		get_viewport().set_input_as_handled()
		
#process
func _process(delta: float) -> void:
	if _mouse_held and not _is_dragging:
		_hold_timer += delta
		if _hold_timer >= HOLD_THRESHOLD:
			#crossed threshold > become drag
			_mouse_held=false
			_is_dragging=true
			_drag_origin = global_position
			_has_target =false #stop while dragging
			velocity = Vector2.ZERO
			z_index = 10 #render on top
			
#physics process
func _physics_process(delta: float) -> void:
	attack_component.try_attack()
	_do_movement()

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
		velocity =diff.normalized()*move_speed
		move_and_slide()
	else:
		global_position =_target_pos
		velocity =Vector2.ZERO
		_has_target = false # arrived — stop moving

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
	
#state
## Clears every piece of in-flight state so the duck is completely inert.
## Called by DuckRoster.recall_all() after every wave.
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
	_target_pos = Vector2.ZERO
	velocity    = Vector2.ZERO
 
	# NavAgent — cancel any queued path
	if is_instance_valid(nav_agent):
		nav_agent.target_position = global_position  # point at self = no movement
 
	# Attack cooldown reset so it doesn't fire instantly next deployment
	if is_instance_valid(attack_component):
		attack_component._cooldown = 0.0

#merge drop
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

#helpers
func _is_click_on_self(world_pos:Vector2) -> bool:
	#AABB check (32x32) centered on origin
	var half:=Vector2(16,16)
	var rect:= Rect2(global_position - half,half*2)
	return rect.has_point(world_pos)

func _set_selected(value:bool)->void:
	_selected=value
	if sprite:
		sprite.modulate = selected_color if _selected else normal_color

func _move_to(pos:Vector2)->void:
	_target_pos =pos
	_has_target =true
	nav_agent.target_position =pos

#public API
func get_selected()->bool:
	return _selected
func duck_type()-> String:
	return "Baseduck"
## Called externally (merge system, game manager) to reposition the duck.
func force_move(pos:Vector2)->void:
	_move_to(pos)
