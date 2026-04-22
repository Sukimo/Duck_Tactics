extends Node
# Autoload as "DuckRoster"

signal roster_changed

enum Status { RESTING, DEPLOYED, DEAD }

# Internal list — always use the public API below, never modify directly
var _ducks: Array[BaseDuck] = []

# ── Public API ─────────────────────────────────────────────────────────

## Purge any freed nodes from the list (call before any query if needed)
func _purge_invalid() -> void:
	_ducks = _ducks.filter(func(d): return is_instance_valid(d))

## Add a duck to the roster (spawned from reward, etc.)
func add(duck: BaseDuck) -> void:
	if _ducks.has(duck):
		return
	duck.roster_status = Status.RESTING
	_ducks.append(duck)
	emit_signal("roster_changed")

## Remove a duck entirely (queue_free handled externally)
func remove(duck: BaseDuck) -> void:
	_ducks.erase(duck)
	emit_signal("roster_changed")

## Change a duck's status
func set_status(duck: BaseDuck, status: Status) -> void:
	duck.roster_status = status
	if status == Status.DEAD:
		duck.visible = false
		duck.process_mode = Node.PROCESS_MODE_DISABLED
	elif status == Status.RESTING:
		duck.process_mode = Node.PROCESS_MODE_INHERIT
		duck.visible = true
	elif status == Status.DEPLOYED:
		duck.visible = true
		duck.process_mode = Node.PROCESS_MODE_INHERIT
	emit_signal("roster_changed")

## Deploy a duck to a world position (Resting → Deployed)
func deploy(duck: BaseDuck, world_pos: Vector2) -> void:
	set_status(duck, Status.DEPLOYED)
	duck.global_position = world_pos

## Mark duck as dead (called from BaseDuck.die())
func mark_dead(duck: BaseDuck) -> void:
	set_status(duck, Status.DEAD)

## After battle: send all surviving deployed ducks back to resting
func recall_all() -> void:
	_purge_invalid()
	for duck in get_deployed():
		if duck.has_method("rest_state"):
			duck.reset_state()
		set_status(duck, Status.RESTING)
	emit_signal("roster_changed")

## Clear dead ducks from roster and free them
func clear_dead() -> void:
	_purge_invalid()
	var dead := get_dead()
	for duck in dead:
		_ducks.erase(duck)
		if is_instance_valid(duck):
			duck.queue_free()
	emit_signal("roster_changed")

# ── Queries ────────────────────────────────────────────────────────────

func get_all() -> Array[BaseDuck]:
	_purge_invalid()
	return _ducks.duplicate()

func get_resting() -> Array[BaseDuck]:
	return _ducks.filter(func(d): return is_instance_valid(d) and d.roster_status == Status.RESTING)

func get_deployed() -> Array[BaseDuck]:
	return _ducks.filter(func(d): return is_instance_valid(d) and d.roster_status == Status.DEPLOYED)

func get_dead() -> Array[BaseDuck]:
	return _ducks.filter(func(d): return is_instance_valid(d) and d.roster_status == Status.DEAD)

func count_resting() -> int:  return get_resting().size()
func count_deployed() -> int: return get_deployed().size()
func count_dead() -> int:     return get_dead().size()
func count_total() -> int:    return _ducks.size()
