extends BaseDuck
class_name MeleeDuck

func duck_type()-> String:
	return "MeleeDuck"
	
func can_move()-> bool:
	if attack_component is MeleeAttackComponent:
		return not attack_component.is_bumping()
	return true
