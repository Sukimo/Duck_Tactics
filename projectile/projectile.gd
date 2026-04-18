extends Area2D

@export var speed: float = 300.0
@export var damage: int  = 10

var _target:Node2D = null
var _direction: Vector2 =Vector2.ZERO

#set up (called by spawner)
func init(target:Node2D,start_pos:Vector2)->void:
	global_position =start_pos
	_target =target

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#if target was freed(died), remove projectile
	if not is_instance_valid(_target):
		queue_free()
		return
	_direction =(_target.global_position - global_position).normalized()
	global_position += _direction*speed*delta
	look_at(_target.global_position)
	
	#Hit dection: close enough?
	if global_position.distance_to(_target.global_position) <10.0:
		_on_hit()

func _on_hit()-> void:
	#call take_damage if duck implements it
	if _target.has_method("take_damage"):
		_target.take_damage(damage)
	else:
		print("[Projectile] hit %s for %d damage (no take_damage method)" % [_target.name, damage])
	queue_free()
