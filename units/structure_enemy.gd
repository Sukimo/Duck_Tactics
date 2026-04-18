extends StaticBody2D

@export  var attack_rang: float = 200.0 #pixels
@export var attack_delay: float = 2.0 
@export var projectile_dmg: int = 10
@export var debug_color: Color = Color(1,0,0,0.25) 

#get projcetile pack scene (prefab) 
const PROJECTILE_SCENE := "res://projectile/Projectile.tscn"

#node refs
@onready var attack_timer: Timer = $AttackTimer
@onready var spawn_pooint: Node2D = $ProjectileSpawn

var _projectile_scene: PackedScene =null
var _current_target: Node2D =null

func _ready() -> void:
	#load projectile scene
	if ResourceLoader.exists(PROJECTILE_SCENE):
		_projectile_scene  =load(PROJECTILE_SCENE)
	else:
		push_warning("[StructureEnemy] Projectile scene not found at: " + PROJECTILE_SCENE)
	
	attack_timer.wait_time = attack_delay
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()

#draw debug circle
func _draw() -> void:
	draw_circle(Vector2.ZERO,attack_rang,debug_color)
	draw_arc(Vector2.ZERO,attack_rang,0.0,TAU,64,Color(1,0,0,0.8),1.5)
	
func _process(delta: float) -> void:
	_current_target  =_find_nearest_duck()
	queue_redraw() #circle

#timer callback
func _on_attack_timer_timeout()->void:
	if _current_target == null:
		return
	_fire_at(_current_target)

func _find_nearest_duck()->Node2D:
	var best: Node2D =null
	var best_dist:float =attack_rang
	
	#scan all node in group(tag) "ducks"
	for duck in get_tree().get_nodes_in_group("ducks"):
		if not duck is Node2D:
			continue
		var dist := global_position.distance_to((duck as Node2D).global_position)
		if dist <= best_dist:
			best_dist =dist
			best = duck
	return best

func _fire_at(target:Node2D)->void:
	if _projectile_scene==null:
		push_warning("[StructureEnemy] Cannot fire — projectile scene missing.")
		return
	
	var proj: Node = _projectile_scene.instantiate()
	
	#set damage before adding to tree
	if proj.has_method("init"):
		# Add to scene first so global_position works
		get_tree().current_scene.add_child(proj)
		(proj as Node2D).global_position =spawn_pooint.global_position
		proj.call("init",target,spawn_pooint.global_position)
	else:
		get_tree().current_scene.add_child(proj)
 	
	print("[StructureEnemy] Fired at %s  |  dmg=%d" % [target.name, projectile_dmg])

#public: toggle debug circle vsibility
func set_debug_visible(value:bool)->void:
	set_process(value) # stops _process / queue_redraw loop when false
	if not value:
		queue_redraw() # clear canvas item
