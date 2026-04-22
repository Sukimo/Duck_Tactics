extends AttackComponent
class_name MeleeAttackComponent

## Bump attack settings
@export var bump_distance: float = 18.0   # how far it slides toward enemy
@export var bump_speed: float = 400.0     # lunge speed (pixels/sec)
@export var return_speed: float = 200.0   # return speed (slower feels better)
@export var flash_duration: float = 0.12
@export var flash_color: Color = Color(1, 0.2, 0.2, 0.6)
@export var flash_size: Vector2 = Vector2(32, 32)

# bump state machine
enum BumpState { IDLE, LUNGING, RETURNING }
var _state: BumpState = BumpState.IDLE

var _origin_pos: Vector2 = Vector2.ZERO   # where duck started
var _bump_target_pos: Vector2 = Vector2.ZERO  # point near enemy
var _pending_target: Node2D = null        # who to damage on contact

# flash state
var _flash_timer: float = 0.0
var _flash_pos: Vector2 = Vector2.ZERO
var _flash_active: bool = false

func try_attack(target: Node2D = null)->void:
	if _state != BumpState.IDLE:
		return
	super.try_attack(target)

func do_attack(target: Node2D) -> void:
	_pending_target = target
	_origin_pos = _owner_node.global_position
	var dir := _owner_node.global_position.direction_to(target.global_position)
	_bump_target_pos =_origin_pos + dir * bump_distance
	_state = BumpState.LUNGING

func _process(delta: float) -> void:
	super._process(delta) # keeps _cooldown ticking
	
	match _state:
		BumpState.LUNGING:
			_owner_node.global_position = _owner_node.global_position.move_toward(
				_bump_target_pos, bump_speed * delta
			)
			if _owner_node.global_position.distance_to(_bump_target_pos) < 2.0:
				_on_contact()

		BumpState.RETURNING:
			_owner_node.global_position = _owner_node.global_position.move_toward(
				_origin_pos, return_speed * delta
			)
			if _owner_node.global_position.distance_to(_origin_pos) < 2.0:
				_owner_node.global_position = _origin_pos
				_state = BumpState.IDLE

	# flash fade
	if _flash_active:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_active = false
		_owner_node.queue_redraw()

func _on_contact() -> void:
	_state = BumpState.RETURNING
	# deal damage
	if is_instance_valid(_pending_target):
		if _pending_target.has_method("take_damage"):
			_pending_target.take_damage(attack_damage)
		_flash_pos = _pending_target.global_position
		_flash_active = true
		_flash_timer = flash_duration
		#print("[Melee] bump hit %s for %d" % [_pending_target.name, attack_damage])
	_pending_target = null

func draw_debug(canvas: Node2D) -> void:
	if not _flash_active:
		return
	var t :float = clamp(_flash_timer / flash_duration, 0.0, 1.0)
	var col := Color(flash_color.r, flash_color.g, flash_color.b, t * flash_color.a)
	var local_pos := canvas.to_local(_flash_pos)
	var half := flash_size / 2.0
	canvas.draw_rect(Rect2(local_pos - half, flash_size), col)
	canvas.draw_rect(Rect2(local_pos - half, flash_size), Color(1, 1, 1, t * 0.8), false, 1.5)

func is_bumping() -> bool:
	return _state != BumpState.IDLE
