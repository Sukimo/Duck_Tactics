extends CharacterBody2D
class_name BaseDuck

@export var move_speed: float =120.0
@export var max_hp: int =100
@export var selected_color: Color=Color(1.0,0.85,0.0,1.0) #yellow tint
@export var normal_color: Color= Color(1.0, 1.0,  1.0, 1.0)  #white

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
	attack_component.try_attack()
	_do_movement()
	
func can_move()-> bool: return true

func _do_movement()->void:
	if not can_move() or not _has_target:
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
	queue_free()

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
