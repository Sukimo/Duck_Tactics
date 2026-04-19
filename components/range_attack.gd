extends AttackComponent
class_name RangeAttackComponent

const PROJECTILE_SCENE := "res://projectile/Projectile.tscn"
@export var projectile_speed: float = 300.0
@export var arc_height: float = 80.0

var _projectile_scene: PackedScene = null

func _ready() -> void:
	super._ready()
	if ResourceLoader.exists(PROJECTILE_SCENE):
		_projectile_scene = load(PROJECTILE_SCENE)

func do_attack(target: Node2D) -> void:
	if _projectile_scene == null:
		return
	var start := _owner_node.global_position
	var t_pos := target.global_position
	#prediction shoot pos
	var travel := start.distance_to(t_pos) / projectile_speed
	var vel := Vector2.ZERO
	if target.get("velocity") != null:
		vel = target.velocity
	var predicted := t_pos + vel * travel

	var proj = _projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	
	if proj.get("damage") != null:
		proj.damage = attack_damage
	if proj.get("speed") !=null:
		proj.speed = projectile_speed
	if proj.get("arc_height") !=null:
		proj.arc_height = arc_height
		
	if proj.has_method("init"):
		proj.call("init", target, start, predicted)
