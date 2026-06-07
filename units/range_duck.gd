extends BaseDuck
class_name RangeDuck

@export var preferred_range: float = 130.0
@export var flee_range:      float = 80.0

func duck_type() -> String:
	return "RangeDuck"

# CHASE: stop at preferred_range from target, measured from duck position
func _on_chase() -> void:
	if not _is_valid_target(_ai_target):
		_ai_target = null
		ai_state   = AIState.RETURN_HOME
		return

	# Leash still measured from home — consistent with base behavior
	var dist_from_home := _home_pos.distance_to(_ai_target.global_position)
	if dist_from_home > leash_range:
		_ai_target = null
		ai_state   = AIState.RETURN_HOME
		return

	var dist := global_position.distance_to(_ai_target.global_position)
	if dist <= preferred_range:
		_has_target = false
		velocity    = Vector2.ZERO
		ai_state    = AIState.ATTACK
	else:
		_move_to(_ai_target.global_position)

# ATTACK: hold position, back away if enemy closes inside flee_range
func _on_attack() -> void:
	if not _is_valid_target(_ai_target):
		_ai_target = null
		ai_state   = AIState.RETURN_HOME
		return

	var dist_from_home := _home_pos.distance_to(_ai_target.global_position)
	if dist_from_home > leash_range:
		_ai_target = null
		ai_state   = AIState.RETURN_HOME
		return

	var dist := global_position.distance_to(_ai_target.global_position)

	if dist > attack_component.attack_range * 1.15:
		ai_state = AIState.CHASE
		return

	if dist < flee_range:
		# Kite: back away from target
		var away := (global_position - _ai_target.global_position).normalized()
		_move_to(global_position + away * 55.0)
	else:
		# Sweet spot — hold still
		_has_target = false
		velocity    = Vector2.ZERO
