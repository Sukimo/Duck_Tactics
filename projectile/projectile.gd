extends Area2D

@export var speed: float = 300.0
@export var damage: int  = 10
@export var arc_height:float =80.0 # 0 = stright line

#state
var _start_pos:Vector2 =Vector2.ZERO
var _land_pos:Vector2 =Vector2.ZERO # fixed world position, not the duck
var _target_duck: Node2D =null # only used for damage on arrival
var _travel_time: float = 0.0 # total seconds to reach land_pos
var _elapsed: float = 0.0 # seconds since spawned
var _active: bool = false

#set up (called by StructureEnemy)
func init(target:Node2D,start:Vector2,land:Vector2)->void:
	_target_duck = target
	_start_pos = start
	_land_pos = land
	global_position =start
	
	# Travel time derived from distance so speed export stays intuitive
	var dist: float =start.distance_to(land)
	_travel_time =dist/speed # e.g. 200px / 300px/s = 0.67s
	_elapsed =0.0
	_active = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not _active:
		return
	
	_elapsed+=delta
	var t:float =clamp(_elapsed/_travel_time,0.0,1.0)
	
	#lerp start to land
	var flat_pos: Vector2 =_start_pos.lerp(_land_pos,t)
	
	# Add arc offset on the Y axis (parabola peaks at t=0.5)
	# sin(t*PI) is 0 at start, 1 at midpoint, 0 at end
	var arc_offset: float = sin(t * PI) * arc_height
	global_position = flat_pos - Vector2(0,arc_offset)
	
	#rotate sprite to face direction of travel
	if t < 1.0:
		var next_t:float = clamp((t + 0.02), 0.0, 1.0)
		var next_flat := _start_pos.lerp(_land_pos, next_t)
		var next_arc  := sin(next_t * PI) * arc_height
		var next_pos  := next_flat - Vector2(0, next_arc)
		look_at(next_pos)
	
	#landed
	if t >= 1.0:
		_on_land()

func _on_land()->void:
	_active =false
	
	# Only deal damage if the duck is still close to the landing spot
	# (duck dodged = no damage)
	if is_instance_valid(_target_duck):
		var duck_dist := _land_pos.distance_to((_target_duck as Node2D).global_position)
		if duck_dist <= 32.0:
			if _target_duck.has_method("take_damage"):
				_target_duck.take_damage(damage)
			else:
				print("[Projectile] hit %s for %d (no take_damage)" % [_target_duck.name, damage])
		else:
			print("[Projectile] missed — duck moved %.0fpx away" % duck_dist)
			_spawn_miss_label(_land_pos)
	# TODO: spawn a landing dust/impact particle here
	queue_free()

func _spawn_miss_label(pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = "MISS"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))   # yellow
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.z_index = 20
	lbl.global_position = pos - Vector2(16, 16)  # rough center offset
	get_tree().current_scene.add_child(lbl)
 
	# Float up then fade out over 0.8s
	var tween := lbl.create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 40.0, 0.8)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(lbl.queue_free).set_delay(0.8)
