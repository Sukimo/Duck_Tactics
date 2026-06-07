extends Node
# Autoload as "AbilityManager"
# Runtime API for attaching, detaching, and transferring AbilityComponents.
# Abilities added via Inspector (child nodes in .tscn) work automatically
# through AbilityComponent._ready() — you only need this for runtime operations.

# Preloads — add new ability scenes here as you create them
const ABILITY_SCENE: Dictionary ={
	"GooThrowAbility": preload("res://abilities/goo_throw_ability.gd"),
	"CritAuraAbility": preload("res://abilities/crit_aura_ability.gd"),
}

# Public API
## Attach a new ability to a duck by string ID.
## Example: AbilityManager.add_ability(some_duck, "GooThrowAbility")
func add_ability(duck: BaseDuck, ability_id: String)->AbilityComponent:
	if not ABILITY_SCENE.has(ability_id):
		push_warning("[AbilityManager] Unknown ability: %s" % ability_id)
		return null
	if get_ability(duck, ability_id) != null:
		push_warning("[AbilityManager] %s already has %s" % [duck.name, ability_id])
		return null
		
	var script: GDScript =ABILITY_SCENE[ability_id]
	var node := Node.new()
	node.set_script(script)
	node.name = ability_id
	duck.add_child(node)
	return node as AbilityComponent

## Remove an ability from a duck by string ID.
## Example: AbilityManager.remove_ability(some_duck, "GooThrowAbility")
func remove_ability(duck: BaseDuck, ability_id: String)->void:
	var ability := get_ability(duck, ability_id)
	if ability_id == null:
		push_warning("[AbilityManager] %s does not have %s" % [duck.name, ability_id])
		return
	ability.queue_free()
	
## Move an ability from one duck to another.
## The original node is freed; a fresh one is created on the target.
## Example: AbilityManager.transfer_ability(matthew, other_duck, "GooThrowAbility")
func transfer_ability(from_duck: BaseDuck, to_duck: BaseDuck ,ability_id: String)->AbilityComponent:
	if not is_instance_valid(from_duck) or not is_instance_valid(to_duck):
		push_warning("[AbilityManager] transfer_ability: invalid duck reference")
		return null
	
	var existing := get_ability(from_duck,ability_id)
	if existing == null:
		push_warning("[AbilityManager] %s does not have %s — nothing to transfer" \
			% [from_duck.name, ability_id])
		return null
		
	existing.queue_free()
	return add_ability(to_duck,ability_id)
		
## Returns the AbilityComponent node if the duck has this ability, else null.
func get_ability(duck: BaseDuck, ability_id: String) -> AbilityComponent:
	if  not is_instance_valid(duck):
		return null
	for child in duck.get_children():
		if child is AbilityComponent:
			var ab := child as AbilityComponent
			if ab.ability_id() == ability_id:
				return ab
	return null
	
## Returns all AbilityComponent nodes on a duck.
func get_all_abilities(duck: BaseDuck) -> Array[AbilityComponent]:
	var result: Array[AbilityComponent] = []
	for child in duck.get_children():
		if child is AbilityComponent:
			result.append(child as AbilityComponent)
	return result
	
## Returns true if the duck currently has the named ability.
func has_ability(duck: BaseDuck, ability_id: String) -> bool:
	return get_ability(duck, ability_id) != null
 
