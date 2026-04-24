extends MeleeAttackComponent
class_name MobMeleeAttackComponent
 
# Mobs use the same bump mechanic but bypass the duck crit system.
# Override _on_contact to call deal_damage directly (no crit roll).
func _on_contact() -> void:
	_state = BumpState.RETURNING
	if is_instance_valid(_pending_target):
		deal_damage(_pending_target, attack_damage, false)
		_flash_pos = _pending_target.global_position
		_flash_active = true
		_flash_timer = flash_duration
	_pending_target = null
 
