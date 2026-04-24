extends StaticBody2D
# tunables
@export var attack_rang: float = 200.0 #pixels
@export var attack_delay: float = 2.0 
@export var projectile_dmg: int = 10
@export var projectile_speed: float = 300.0 # match projectile.gd speed
##Toggle attack-range dubug circle
@export var debug_range_visible: bool = true
##ground waring circle shows before fires (sec.)
@export var windup_time: float = 0.6

@export var debug_color: Color = Color(1,0,0,0.25) 
@export var windup_color:Color = Color(1,0.6,0,0.55) #orange

#get projcetile pack scene (prefab) 
const PROJECTILE_SCENE := preload("res://projectile/Projectile.tscn")

#node refs
@onready var attack_timer: Timer = $AttackTimer
@onready var spawn_pooint: Node2D = $ProjectileSpawn

#state
var _current_target: Node2D =null

#Windup state
var _windup_active: bool =false
var _windup_elapsed:float = 0.0
var _windup_pos: Vector2 =Vector2.ZERO # predicted land pos in world space
var _windup_target: Node2D =null

func _ready() -> void:
	attack_timer.wait_time = attack_delay
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()

#draw debug circle
func _draw() -> void:
	# 1) Attack range circle (toggled by debug_range_visible)
	if debug_range_visible:
		draw_circle(Vector2.ZERO,attack_rang,debug_color)
		draw_arc(Vector2.ZERO,attack_rang,0.0,TAU,64,Color(1,0,0,0.8),1.5)
	
	# 2) Windup ground warning circle
	# _windup_pos is in world space; convert to local for _draw
	if _windup_active:
		var local_pos:Vector2 = to_local(_windup_pos)
		# Pulse: grows from 0 to 24px radius over windup_time
		var t:float = clamp(_windup_elapsed/windup_time,0.0,1.0)
		var radius: float = lerp(4.0,24.0,t)
		# Fade alpha in then flash at end
		var alpha:float = lerp(0.3,0.9,t)
		var col:Color =Color(windup_color.r,windup_color.g,windup_color.b,alpha)
		draw_circle(local_pos,radius,col)
		draw_arc(local_pos,radius,0.0,TAU,32,Color(1,0.8,0,1.0),2.0)

func _process(delta: float) -> void:
	_current_target  =_find_nearest_duck()
	
	#trick windup animation
	if _windup_active:
		_windup_elapsed += delta
		if _windup_elapsed >= windup_time:
			_windup_active=false
			
		if is_instance_valid(_windup_target):
			_fire_projectile(_windup_target,_windup_pos)
		else:
			_windup_target = null
	
	queue_redraw() #circle

func take_damage(amount: int) -> void:
	print("[StructureEnemy] %s took %d damage" % [name, amount])
	

#timer callback
func _on_attack_timer_timeout()->void:
	if _current_target == null or not is_instance_valid(_current_target):
		return
	_begin_windup(_current_target)

#windup 
func _begin_windup(target: Node2D)->void:
	var start: Vector2 =spawn_pooint.global_position
	var duck_pos: Vector2 = (target as Node2D).global_position
	
	var dist: float = start.distance_to(duck_pos)
	var travel_time:float = dist/projectile_speed
	
	var duck_vel: Vector2 = Vector2.ZERO
	if target.get("velocity") != null:
		duck_vel = target.velocity
	
	var predicted_pos: Vector2 = duck_pos + duck_vel* travel_time
	
	#start windup
	_windup_active =true
	_windup_elapsed =0.0
	_windup_pos = predicted_pos
	_windup_target =target
	
	print("[StructureEnemy] Windup → landing at %s in %.1fs" % [predicted_pos, windup_time])

#fire: called after windup completes
func _fire_projectile(target:Node2D, land_pos: Vector2)->void:
	if not is_instance_valid(target):
		return #duck died during windup
	 
	var proj:Node = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(proj)
	
	if proj.get("damage") != null:
		proj.damage = projectile_dmg
	
	if proj.has_method("init"):
		proj.call("init",target,spawn_pooint.global_position,land_pos)
	
	print("[StructureEnemy] Fired → dmg=%d  land=%s" % [projectile_dmg, land_pos])
	
#helpers	
func _find_nearest_duck()->Node2D:
	var best: Node2D =null
	var best_dist:float =attack_rang
	
	#scan all node in group(tag) "ducks"
	for duck in get_tree().get_nodes_in_group("ducks"):
		if not duck is Node2D:
			continue
		var dist := global_position.distance_to((duck as Node2D).global_position)
		if dist <= best_dist:
			best_dist = dist
			best = duck
	return best

func _fire_at(target:Node2D)->void:
	# Predict where the duck will be when the projectile lands
	var start: Vector2 = spawn_pooint.global_position
	var duck_pos:Vector2 = (target as Node2D).global_position
	
	#How long will it take the projectile to travel this distance?
	var dist: float = start.distance_to(duck_pos)
	var travel_time: float = dist /300.0 ## match projectile.gd speed
	
	# Where will the duck be after travel_time seconds?
	# CharacterBody2D exposes .velocity — use it for prediction
	var duck_vel: Vector2 = Vector2.ZERO
	if target.get("velocity") != null:
		duck_vel = target.velocity 
	
	var predicted_pos: Vector2 = duck_pos + duck_vel*travel_time
	
	var proj:Node = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(proj)
	
	if proj.has_method("init"):
		proj.damage = projectile_dmg
		proj.call("init", target, start, predicted_pos)
	
	print("[StructureEnemy] Fired → predicted pos %s  (travel %.2fs)" % [predicted_pos, travel_time])
	
#public: toggle debug circle vsibility
func set_debug_visible(value:bool)->void:
	set_process(value) # stops _process / queue_redraw loop when false
	if not value:
		queue_redraw() # clear canvas item
