extends CharacterBody2D
class_name BaseMob

@export var move_speed: float = 80.0
@export var max_hp: int = 60
## Distance at which mob notices a duck and begins chasing.
@export var aggro_range: float = 600.0   # mobs are aggressive — large radius
## If the target exceeds this distance the mob finds a new one.
@export var leash_range: float = 700.0

enum AIState { CHASE, ATTACK }
var ai_state:       AIState = AIState.CHASE
var _current_target: Node2D = null

var hp: int

@onready var attack_component: AttackComponent = $AttackComponent

func _ready() -> void:
	hp = max_hp

func _physics_process(_delta: float) -> void:
	_tick_ai()
	attack_component.try_attack(_current_target)
	_do_movement()

# AI tick
func _tick_ai()->void:
	# Validate current target every tick — dead ducks stay in memory
	if not _is_valid_target(_current_target):
		_current_target = _find_nearest_duck()
		if ai_state == AIState.ATTACK:
			ai_state == AIState.CHASE
 
	match ai_state:
		AIState.CHASE:
			_on_chase()
		AIState.ATTACK:
			_on_attack()

# Target validation 
func _is_valid_target(target: Variant) -> bool:
	if not is_instance_valid(target):
		return false
	# Dead ducks are not freed — check roster status explicitly
	if target.get("roster_status") != null:
		if target.roster_status == DuckRoster.Status.DEAD:
			return false
	return true

#  State hooks (override in subclasses for different mob behavior)
func _on_chase():
	if not is_instance_valid(_current_target):
		return
	var dist := global_position.distance_to(_current_target.global_position)
	if dist > leash_range:
		_current_target = _find_nearest_duck()
		return
	if dist <= attack_component.attack_range:
		ai_state = AIState.ATTACK
		
func _on_attack():
	if not is_instance_valid(_current_target):
		ai_state = AIState.CHASE
		return
	var dist := global_position.distance_to(_current_target.global_position)
	# Hysteresis: small buffer so mob doesn't flicker at the boundary
	if dist > attack_component.attack_range * 1.15:
		ai_state = AIState.CHASE

# Movement
func _do_movement()->void:
	if ai_state == AIState.ATTACK:
		# Option 1: stop completely while attacking
		velocity = Vector2.ZERO
		return 
	# CHASE: move toward target
	if not is_instance_valid(_current_target):
		velocity = Vector2.ZERO
		return
	
	var dist := global_position.distance_to(_current_target.global_position)
	if dist > attack_component.attack_range * 0.85:
		velocity = (_current_target.global_position - global_position).normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

# Targeting
func _find_nearest_duck() -> Node2D:
	var best: Node2D = null
	var best_dist: float = INF
	for duck in get_tree().get_nodes_in_group("ducks"):
		if not is_instance_valid(duck) or not duck is Node2D:
			continue
		# Skip dead ducks
		if duck.get("roster_status") != null:
			if duck.roster_status == DuckRoster.Status.DEAD:
				continue
			# Skip resting ducks — they're in RestZone, not in battle
			if duck.roster_status == DuckRoster.Status.RESTING:
				continue
		var d := global_position.distance_to((duck as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = duck
	return best

# Damage / death
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
