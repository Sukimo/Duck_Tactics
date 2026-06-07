extends AbilityComponent
class_name GooThrowAbility

# ── Goo Throw Ability ─────────────────────────────────────────────────────────
# Attach to any BaseDuck as a child node (in scene or via AbilityManager).
# The duck periodically lobs a grape-jam projectile that lands and spawns
# a GooPuddle — a persistent slow field for enemies.
#
# Works independently of AttackComponent — own cooldown, own targeting.

@export var throw_range:    float = 220.0   # max range to lob goo (px)
@export var throw_cooldown: float = 5.0     # seconds between throws
@export var lob_speed:      float = 220.0   # projectile travel speed (px/s)
@export var lob_arc:        float = 60.0    # arc height for the lob visual
 
# Puddle config passed through to GooPuddle on spawn
@export var puddle_slow:    float = 0.4     # move_speed multiplier on mobs
@export var puddle_lifetime:float = 4.0     # seconds puddle persists
@export var puddle_radius:  float = 56.0    # collision + visual radius

const GOO_PUDDLE_SCENE := preload("res://effects/goo_puddle.tscn")
# Reuse the existing Projectile scene for the lob arc visual
const PROJECTILE_SCENE  := preload("res://projectile/Projectile.tscn")

var _cooldown: float = 0.0

# Hooks
func ability_id()->String:
	return "GooThrowAbility"
	
func on_attached(duck: BaseDuck) -> void:
	print("[GooThrowAbility] Attached to %s" % duck.name)
	
func on_detached(duck: BaseDuck) -> void:
	print("[GooThrowAbility] Detached from %s" % duck.name)

func _process(delta: float) -> void:
	if _owner_duck == null or not is_instance_valid(_owner_duck):
		return
	# Only act during battle
	if not GameState.is_state(GameState.State.BATTLE):
		return
	
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	
	var target := _find_nearest_enemy()
	if target == null:
		return
	
	var dist := _owner_duck.global_position.distance_to(target.global_position)
	if dist > throw_range:
		return
	
	_throw_goo(target)
	_cooldown = throw_cooldown
	
# Goo throwing
func _throw_goo(target: Node2D)->void:
	var start := _owner_duck.global_position
	var land := target.global_position  # aim at current pos — no prediction (goo is area, precision doesn't matter)
	
	# Lob visual: reuse Projectile but override damage to 0
	# The actual effect is the puddle spawned on landing, not the projectile
	var proj: Node = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(proj)
	
	# Tint projectile purple so it reads differently from normal attacks
	var sprite := proj.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.modulate = Color(0.6, 0.15, 0.8, 1.0)
 
	if proj.get("damage") != null:
		proj.damage = 0        # goo lob deals no direct damage
	if proj.get("speed") != null:
		proj.speed = lob_speed
	if proj.get("arc_height") != null:
		proj.arc_height = lob_arc
 
	# Connect to landing signal — spawn puddle when it arrives
	# Projectile doesn't have a signal so we use a helper node approach:
	# override: we'll use a thin wrapper that spawns puddle after travel time
	_spawn_puddle_after_delay(start, land)
 
	if proj.has_method("init"):
		proj.call("init", null, start, land)   # null target = no damage call
	
# Puddle spawn (timed to match projectile travel)
func _spawn_puddle_after_delay(start: Vector2, land: Vector2) -> void:
	var dist        := start.distance_to(land)
	var travel_time := dist / lob_speed
 
	var timer := get_tree().create_timer(travel_time)
	timer.timeout.connect(func(): _spawn_puddle_at(land))
	
func _spawn_puddle_at(world_pos: Vector2) -> void:
	if not is_instance_valid(self):
		return
	var puddle: Node = GOO_PUDDLE_SCENE.instantiate()
	get_tree().current_scene.add_child(puddle)
	puddle.global_position = world_pos
 
	# Pass config
	if puddle.get("slow_factor")    != null: puddle.slow_factor    = puddle_slow
	if puddle.get("lifetime")       != null: puddle.lifetime       = puddle_lifetime
	if puddle.get("radius")         != null: puddle.radius         = puddle_radius
	
# Targeting
func _find_nearest_enemy() -> Node2D:
	var best:      Node2D = null
	var best_dist: float  = throw_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D or not is_instance_valid(enemy):
			continue
		var d := _owner_duck.global_position.distance_to((enemy as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best      = enemy
	return best
