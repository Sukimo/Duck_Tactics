extends BaseDuck
class_name  RangeDuck

## Duck stops chasing once inside this distance.
## Set below attack_range so it keeps a comfortable gap.
@export var preferred_range: float = 130.0
 
## If an enemy closes inside this distance during ATTACK, duck backs away.
@export var flee_range: float = 80.0
 
func duck_type()-> String:
	return "RangeDuck"

# CHASE: stop at preferred_range instead of attack_range
func _on_chase()->void:
	if not is_instance_valid(_ai_target):
		ai_state = AIState.IDLE
		return
	
	var dist := global_position.distance_to(_ai_target.global_position)
	
	if dist > leash_range:
		_ai_target = null
		ai_state = AIState.IDLE
		return
		
	if dist <= preferred_range:
		_has_target = false
		ai_state  = AIState.ATTACK
	else:
		_move_to(_ai_target.global_position)

# ATTACK: hold position; back away if enemy closes inside flee_range
func _on_attack()->void:
	if not is_instance_valid(_ai_target):
		ai_state = AIState.IDLE
		return
	
	var dist := global_position.distance_to(_ai_target.global_position)
	
	if dist > attack_component.attack_range * 1.15:
		ai_state = AIState.CHASE
		return
	
	if dist < flee_range:
		# Kite: nudge directly away from target each frame
		var away := (global_position - _ai_target.global_position).normalized()
		_move_to(global_position + away * 55.0)
	else:
		# Sweet spot — hold still and let attack_component fire
		_has_target = false
		velocity = Vector2.ZERO
