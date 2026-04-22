extends CharacterBody2D
class_name BaseMob

@export var move_speed: float = 80.0
@export var max_hp: int = 60

var hp: int
var _current_target:Node2D = null

@onready var attack_component: AttackComponent = $AttackComponent

func _ready() -> void:
	hp = max_hp

func _physics_process(_delta: float) -> void:
	_current_target =_find_nearest_duck()
	attack_component.try_attack(_current_target)
	if attack_component.has_method("is_bumping") and attack_component.is_bumping():
		return
	_move_toward_nearest_duck()

func _move_toward_nearest_duck() -> void:
	if _current_target == null:
		velocity = Vector2.ZERO
		return
	# Stop at attack range edge so it doesn't walk through the duck
	var dist := global_position.distance_to(_current_target.global_position)
	if dist > attack_component.attack_range * 0.85:
		velocity = (_current_target.global_position - global_position).normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _find_nearest_duck() -> Node2D:
	var best: Node2D = null
	var best_dist: float = INF
	for duck in get_tree().get_nodes_in_group("ducks"):
		if not is_instance_valid(duck) or not duck is Node2D:
			continue
		#skip dead ducks
		if duck.get("roster_status") !=null:
			if duck.roster_status == DuckRoster.Status.DEAD:
				continue
		var d := global_position.distance_to((duck as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = duck
	return best

func take_damage(amount: int) -> void:
	hp -= amount
	if has_node("HealthBar"):
		$HealthBar.update(hp, max_hp)
	if hp <= 0:
		die()

func die() -> void:
	print("[Mob] %s died" % name)
	queue_free()

func mob_type() -> String:
	return "BaseMob"
