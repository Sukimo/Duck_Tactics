extends BaseDuck
class_name MeleeDuck

func can_move()-> bool:
	if attack_component is MeleeAttackComponent:
		return not attack_component.is_bumping()
	return true
