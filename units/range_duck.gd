extends BaseDuck
class_name  RangeDuck

const PROJECTILE_SCENE := "res://projectile/Projectile.tscn"
var _projectile_scene: PackedScene =null

func _ready() -> void:
	super._ready()
	attack_range = 200.0
	if ResourceLoader.exists(PROJECTILE_SCENE):
		_projectile_scene =load(PROJECTILE_SCENE)

func attack(target: Node2D)-> void:
	if _projectile_scene == null:
		return
	var start := global_position
	var duck_pos := target.global_position
	var dist := start.distance_to(duck_pos)
	var travel_time := dist / 300.0
	
	var target_vel := Vector2.ZERO
	if target.get("velocity") !=null:
		target_vel =target.velocity
	var predicted_pos := duck_pos + target_vel * travel_time
	
	var proj: Node = _projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	if proj.get("damage") !=null:
		proj.damage =attack_damage
	if proj.has_method("init"):
		proj.call("init", target, start,predicted_pos)
	
