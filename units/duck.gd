extends CharacterBody2D

@export var move_speed: float =120.0
@export var selected_color: Color=Color(1.0,0.85,0.0,1.0) #yellow tint
@export var normal_color: Color= Color(1.0, 1.0,  1.0, 1.0)  #white

var _selected: bool =false

#node refs
@onready var sprite: Sprite2D = $Sprite2D
@onready var nav_agent: NavigationAgent2D =$NavAgent

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
	if nav_agent.is_navigation_finished():
		velocity =Vector2.ZERO
		return
	
	var next: Vector2 = nav_agent.get_next_path_position()
	var dir: Vector2 = (next- global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()

#helpers
func _is_click_on_self(world_pos:Vector2) -> bool:
	#AABB check (32x32) centered on origin
	var half:=Vector2(16,16)
	var rect:= Rect2(global_position - half,half*2)
	return rect.has_point(world_pos)

func _set_selected(value:bool)->void:
	_selected=value
	if sprite:
		sprite.modulate=selected_color if selected_color else normal_color

func _move_to(pos:Vector2)->void:
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
