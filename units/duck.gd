extends CharacterBody2D

@export var move_speed: float =120.0
@export var selected_color: Color=Color(1.0,0.85,0.0,1.0) #yellow tint
@export var normal_color: Color= Color(1.0, 1.0,  1.0, 1.0)  #white

#node refs
@onready var sprite: Sprite2D = $Sprite2D
@onready var nav_agent: NavigationAgent2D =$NavAgent

var _selected: bool =false
var _has_target: bool =false #only move when a target was actually set
var _target_pos:Vector2 = Vector2.ZERO #fallback for navmesh isn't baked

func _ready() -> void:
	nav_agent.path_desired_distance   = 4.0   # snap to each waypoint this close
	nav_agent.target_desired_distance = 8.0   # stop this close to final target
	nav_agent.avoidance_enabled       = false  # enable later for multi-duck crowds
	
	set_process_input(true)
	set_physics_process(true)

# input
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton 
			and event.button_index == MOUSE_BUTTON_LEFT 
			and event.pressed):
		return
		
	var click_world:= get_global_mouse_position()
		
	#player click this duck?
	if _is_click_on_self(click_world):
		_set_selected(true)
		get_viewport().set_input_as_handled()
		return
		
	#click as move 
	if _selected:
		_move_to(click_world)
		_set_selected(false)
		get_viewport().set_input_as_handled()

#physics process
func _physics_process(delta: float) -> void:
	if not _has_target:
		return
	
	#navPath
	if not nav_agent.is_navigation_finished():
		var next: Vector2 = nav_agent.get_next_path_position()
		# FIX: if next == our position the navmesh gave nothing useful; fall back
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

## Called externally (merge system, game manager) to reposition the duck.
func force_move(pos:Vector2)->void:
	_move_to(pos)

## Called by Projectile.gd on hit.  Add health / merge logic here later.
func take_damage(amount: int) -> void:
	print("[Duck] %s took %d damage" % [name, amount])
	# TODO: health -= amount  →  check death  →  trigger merge event
