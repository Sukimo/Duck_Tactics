extends AttackComponent
class_name RangeAttackComponent

const PROJECTILE_SCENE := preload("res://projectile/Projectile.tscn")
@export var projectile_speed: float = 300.0
@export var arc_height: float = 80.0

func _ready() -> void:
	super._ready()

func do_attack(target: Node2D) -> void:
	var start := _owner_node.global_position
	var t_pos := target.global_position
	#prediction shoot pos
	var travel := start.distance_to(t_pos) / projectile_speed
	var vel := Vector2.ZERO
	if target.get("velocity") != null:
		vel = target.velocity
	var predicted := t_pos + vel * travel

	# ── Crit roll using GameState globals ────────────────────────────────────
	var is_crit: bool = randf() < GameState.global_duck_crit_rate
	var mult: float = _get_crit_mult()
	var final_damage: int = int(attack_damage * mult) if is_crit else attack_damage
	if is_crit:
		print("[RangeAtk] CRIT! %d dmg (x%.1f)" % [final_damage, mult])
 
	var proj = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(proj)
	
	if proj.get("damage") != null:
		proj.damage = attack_damage
	if proj.get("speed") !=null:
		proj.speed = projectile_speed
	if proj.get("arc_height") !=null:
		proj.arc_height = arc_height
		
	if proj.has_method("init"):
		proj.call("init", target, start, predicted)

# Override in subclass (MatthewRangeAttack) to return matthew_crit_mult
func _get_crit_mult() -> float:
	return GameState.global_duck_crit_mult
