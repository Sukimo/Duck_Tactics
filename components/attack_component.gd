extends Node
class_name AttackComponent

const CRIT_LABEL_SCENE := preload( "res://effects/crit_label.tscn")

@export var attack_range: float = 60.0
@export var attack_damage: int = 10
@export var attack_speed: float = 1.0  # attacks/sec
@export var target_group: Array[String] = []  # "enemies" or "ducks"
@export var attack_sfx: AudioStream = null

var _cooldown: float = 0.0
var _owner_node: Node2D = null
var _sfx_player: AudioStreamPlayer = null

func _ready() -> void:
	_owner_node = get_parent() as Node2D
	if attack_sfx:
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.stream = attack_sfx
		_sfx_player.volume_db = 0.0
		add_child(_sfx_player)

func _play_attack_sfx() -> void:
	if _sfx_player:
		_sfx_player.play()

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

# ── Duck attack: roll crit from GameState, then call deal_damage ──────────────
# Call this from duck attack components (melee / range)
func duck_deal_damage(target: Node2D, base_amount: int, crit_mult_override: float = -1.0) -> void:
	var crit_rate: float = GameState.global_duck_crit_rate
	var crit_mult: float = crit_mult_override if crit_mult_override > 0.0 \
							else GameState.global_duck_crit_mult
	var is_crit: bool = randf() < crit_rate
	var final_amount: int = int(base_amount * crit_mult) if is_crit else base_amount
	deal_damage(target, final_amount, is_crit)
	
# ── Standard damage delivery (used by both duck and mob paths) ────────────────
# Mobs call this directly with is_crit = false
func deal_damage(target: Node2D, amount: int, is_crit: bool = false) -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("take_damage"):
		target.take_damage(amount)
	if is_crit:
		_spawn_crit_label(amount, target.global_position, true)

func _spawn_crit_label(amount: int, world_pos: Vector2, is_crit: bool) -> void:
	var lbl: Node = CRIT_LABEL_SCENE.instantiate()
	get_tree().current_scene.add_child(lbl)
	if lbl.has_method("init"):
		lbl.call("init", amount, world_pos, is_crit)

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
