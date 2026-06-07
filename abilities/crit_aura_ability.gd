extends AbilityComponent
class_name CritAuraAbility

# ── Crit Aura Ability ─────────────────────────────────────────────────────────
# Originally hardcoded in matthew_duck.gd — now a standalone transferable node.
# Attach to any BaseDuck to give the whole team a global crit rate bonus.
# Remove/transfer to move the aura to a different duck.

@export var crit_bonus: float = 0.10   # +10% to GameState.global_duck_crit_rate

func ability_id() -> String:
	return "CritAuraAbility"

func on_attached(duck: BaseDuck) -> void:
	GameState.global_duck_crit_rate += crit_bonus
	print("[CritAuraAbility] ON  — %s  global crit → %.0f%%" \
		% [duck.name, GameState.global_duck_crit_rate * 100])

func on_detached(duck: BaseDuck) -> void:
	GameState.global_duck_crit_rate = maxf(
		0.0, GameState.global_duck_crit_rate - crit_bonus
	)
	print("[CritAuraAbility] OFF — %s  global crit → %.0f%%" \
		% [duck.name, GameState.global_duck_crit_rate * 100])
		
