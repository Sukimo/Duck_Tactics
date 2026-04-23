extends Node
# Autoload as "MergeManager"

# Maps (class_name_string, level) → PackedScene path
# Extend this table as you add more duck types/levels
const MERGE_TABLE: Dictionary ={
	["MeleeDuck",1]:"res://units/ducks/melee_duck.tscn",
	["MeleeDuck", 2]: "res://units/ducks/melee_duck_lv2.tscn",
	["MeleeDuck", 3]: "res://units/ducks/melee_duck_lv3.tscn",
	["RangeDuck", 1]: "res://units/ducks/range_duck.tscn",
	["RangeDuck", 2]: "res://units/ducks/range_duck_lv2.tscn",
	["RangeDuck", 3]: "res://units/ducks/range_duck_lv3.tscn",
}

func try_merge(a: BaseDuck, b: BaseDuck)-> void:
	if a.duck_type() != b.duck_type():
		_snap_back(a)
		return
	if a.duck_level != b.duck_level:
		_snap_back(a)
		return
	
	var next_level: int= a.duck_level +1
	var key := [a.duck_type(),next_level]
	
	if not MERGE_TABLE.has(key):
		print("[Merge] No recipe for %s lv%d" % [a.duck_type(), next_level])
		_snap_back(a)
		return
	
	var spawn_pos: Vector2 = b.global_position
	
	# remove both originals from roster Before freeing
	DuckRoster.remove(a)
	DuckRoster.remove(b)
	
	# spawn merged duck
	var scene: PackedScene = load(MERGE_TABLE[key])
	var merged: Node = scene.instantiate()
	get_tree().current_scene.add_child(merged)
	
	if merged is BaseDuck:
		var m:= merged as BaseDuck
		m.global_position =spawn_pos
		m.duck_level =next_level
	
		DuckRoster.add(m)
		if b.roster_status == DuckRoster.Status.DEPLOYED:
			DuckRoster.deploy(m,spawn_pos)
			
	#destory both originals
	a.queue_free()
	b.queue_free()
	print("[Merge] %s lv%d + lv%d → lv%d" % [a.duck_type(), a.duck_level, b.duck_level, next_level])
	SignalBus.emit_signal("duck_merged",merged)
	
func _snap_back(_duck:BaseDuck)-> void:
	# Duck is already at drop position — nothing to do.
	# If you want snap-back animation, tween it back to _origin here.
	pass
