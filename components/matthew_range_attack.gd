extends RangeAttackComponent
class_name MatthewRangeAttack

# No exports needed — reads GameState.matthew_crit_mult directly

func _get_crit_mult() -> float:
	return GameState.matthew_crit_mult
