extends AttackComponent
class_name MeleeAttackComponent

## How long the flash box stays visible (seconds)
@export var flash_duration: float = 0.15
@export var flash_color: Color = Color(1, 0.2, 0.2, 0.6)  # red-ish
@export var flash_size: Vector2 = Vector2(32, 32)

var _flash_timer: float = 0.0
var _flash_pos: Vector2 = Vector2.ZERO
var _flash_active: bool = false

func do_attack(target: Node2D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)

	# trigger flash at target position
	_flash_pos = target.global_position
	_flash_active = true
	_flash_timer = flash_duration

	print("[Melee] %s hit %s for %d" % [_owner_node.name, target.name, attack_damage])

func _process(delta: float) -> void:
	super._process(delta)  # keep cooldown ticking

	if _flash_active:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_active = false
		_owner_node.queue_redraw()  # tell owner to redraw every frame

func draw_debug(canvas: Node2D) -> void:
	if not _flash_active:
		return

	# fade out over lifetime
	var t: float = clamp(_flash_timer / flash_duration, 0.0, 1.0)
	var alpha: float = t * flash_color.a
	var col := Color(flash_color.r, flash_color.g, flash_color.b, alpha)

	# draw in local space of owner
	var local_pos: Vector2 = canvas.to_local(_flash_pos)
	var half := flash_size / 2.0
	canvas.draw_rect(Rect2(local_pos - half, flash_size), col)
	canvas.draw_rect(Rect2(local_pos - half, flash_size), Color(1, 1, 1, t * 0.8), false, 1.5)
