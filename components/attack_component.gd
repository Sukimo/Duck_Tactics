extends Node
class_name AttackComponent

@export var attack_range: float = 60.0
@export var attack_damage: int = 10
@export var attack_speed: float = 1.0  # attacks/sec
@export var target_group: Array[String] = []  # "enemies" or "ducks"

var _cooldown: float = 0.0
var _owner_node: Node2D = null

func _ready() -> void:
	_owner_node = get_parent() as Node2D

func _process(delta: float) -> void:
	_cooldown -= delta

func try_attack(target: Node2D = null) -> void:
	if _cooldown > 0.0:
		return
	var t := target if target != null else _find_nearest()
	if t == null:
		return
	var dist = _owner_node.global_position.distance_to(t.global_position)
	if dist <= attack_range:
		do_attack(t)
		_cooldown = 1.0 / attack_speed

# Override in children
func do_attack(target: Node2D) -> void:
	pass

func _find_nearest() -> Node2D:
	var best: Node2D = null
	var best_dist: float = attack_range
	for group in target_group:
		for unit in get_tree().get_nodes_in_group(group):
			if not unit is Node2D:
				continue
			if not is_instance_valid(unit):
				continue
			var d := _owner_node.global_position.distance_to((unit as Node2D).global_position)
			if d <= best_dist:
				best_dist = d
				best = unit
	return best
