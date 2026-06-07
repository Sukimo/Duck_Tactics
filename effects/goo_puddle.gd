extends Area2D
class_name GooPuddle

# Spawned by GooThrowAbility on projectile landing.
# Slows any BaseMob that enters, restores speed on exit or expiry.

@export var slow_factor:   float = 0.4   # multiplier applied to move_speed (0.4 = 60% slow)
@export var lifetime:      float = 4.0   # seconds before puddle disappears
@export var radius:        float = 56.0  # visual + collision radius (px)

# Palette - group purple
const COLOR_FILL   := Color(0.38, 0.10, 0.52, 0.55)
const COLOR_EDGE   := Color(0.60, 0.20, 0.75, 0.90)
const COLOR_BUBBLE := Color(0.75, 0.40, 0.90, 0.70)

var _elapsed: float = 0.0
var _affected: Dictionary = {} # mob → original_speed

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= lifetime:
		_expire()
		
func _draw() -> void:
	var t       :float = clamp(_elapsed / lifetime, 0.0, 1.0)
	var alpha   := (1.0 - t) * 0.85          # fades out over lifetime
	var r_now   := radius * (0.85 + 0.15 * (1.0 - t))   # shrinks slightly
 
	# Base fill
	var fill := Color(COLOR_FILL.r, COLOR_FILL.g, COLOR_FILL.b, COLOR_FILL.a * alpha)
	draw_circle(Vector2.ZERO, r_now, fill)
 
	# Edge ring
	var edge := Color(COLOR_EDGE.r, COLOR_EDGE.g, COLOR_EDGE.b, COLOR_EDGE.a * alpha)
	draw_arc(Vector2.ZERO, r_now, 0.0, TAU, 48, edge, 2.5)
 
	# Two small bubble dots for visual interest
	var bub := Color(COLOR_BUBBLE.r, COLOR_BUBBLE.g, COLOR_BUBBLE.b, COLOR_BUBBLE.a * alpha)
	draw_circle(Vector2(-r_now * 0.35, -r_now * 0.25), r_now * 0.12, bub)
	draw_circle(Vector2( r_now * 0.40,  r_now * 0.10), r_now * 0.08, bub)
 
func _on_body_entered(body: Node)->void:
	if not body is BaseMob: return
	var mob := body as BaseMob
	if _affected.has(mob): return
	_affected[mob] = mob.move_speed
	mob.move_speed *= slow_factor
	
func _on_body_exited(body: Node) -> void:
	_restore_speed(body)

func _restore_speed(body: Node) -> void:
	if not body is BaseMob:
		return
	var mob := body as BaseMob
	if not _affected.has(mob):
		return
	if is_instance_valid(mob):
		mob.move_speed = _affected[mob]
	_affected.erase(mob)

func _expire() -> void:
	# Restore all still-affected mobs before freeing
	for mob in _affected.keys():
		if is_instance_valid(mob):
			mob.move_speed = _affected[mob]
	_affected.clear()
	queue_free()
