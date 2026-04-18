extends BaseDuck
class_name MeleeDuck

func attack(target: Node2D)-> void:
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	print("[MeleeDuck] %s hit %s for %d" % [name, target.name, attack_damage])
