extends Node
class_name AbilityComponent

# ── Base class for all detachable abilities ───────────────────────────────────
# Add as child node to any BaseDuck in scene or at runtime via AbilityManager.
# Override the hooks you need — ignore the rest.
 
var _owner_duck: BaseDuck = null

func _ready() -> void:
	var p := get_parent()
	if p is BaseDuck:
		_owner_duck = p as BaseDuck
		on_attached(_owner_duck)
	else:  
		push_warning("[AbilityComponent] %s must be child of BaseDuck, got %s" % [name, p.name])
 
func _exist_tree()->void:
	if is_instance_valid(_owner_duck):
		on_detached(_owner_duck)
		
# Hooks — override in subclasses
## Called once when ability is attached (node enters tree under a duck)
func on_attached(duck: BaseDuck) -> void:
	pass
 
## Called once when ability is removed (node exits tree)
func on_detached(duck: BaseDuck) -> void:
	pass
 
## Called by duck's AttackComponent after every successful hit lands on a target
## Override to add on-hit effects (slow, poison, etc.)
func on_hit(target: Node2D, damage: int) -> void:
	pass
 
## Called every physics frame while duck is alive — for aura/tick effects
func on_physics_tick(delta: float) -> void:
	pass
 
## Unique string ID — used by AbilityManager to find/remove by type
func ability_id() -> String:
	return "AbilityComponent"
