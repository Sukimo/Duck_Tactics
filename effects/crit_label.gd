extends Node2D
# Spawned by AttackComponent.deal_damage() when is_crit = true
# Self-destructs after animation completes — no manual cleanup needed

@export var crit_color: Color = Color(0.917, 0.597, 0.024, 1.0)   # gold
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 0.85) # white

var _label: String = ""
var _is_crit: bool = false
var _elapsed: float = 0.0

const DURATION: float  = 0.9   # seconds total lifetime
const RISE_PX: float   = 40.0  # how far it floats up
const FONT_SIZE_CRIT: int  = 16
const FONT_SIZE_NORM: int  = 12

func init(amount: int, world_pos: Vector2, is_crit: bool) -> void:
	global_position = world_pos + Vector2(randf_range(-12, 12), -20)
	_label = ("CRIT! " if is_crit else "") + str(amount)
	_is_crit = is_crit

func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = _elapsed / DURATION          # 0..1
	global_position.y -= RISE_PX * delta / DURATION
	modulate.a = 1.0 - t                        # fade out
	queue_redraw()
	if _elapsed >= DURATION:
		queue_free()

func _draw() -> void:
	var col: Color  = crit_color if _is_crit else normal_color
	var size: int   = FONT_SIZE_CRIT if _is_crit else FONT_SIZE_NORM
	var scale_t: float = clampf(1.0 - (_elapsed / DURATION) * 0.5, 0.5, 1.0)

	# Pop scale: starts at 1.3, settles to 1.0 quickly, then shrinks
	var pop: float  = 1.0
	if _elapsed < 0.12:
		pop = lerp(1.3, 1.0, _elapsed / 0.12)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-len(_label) * size * 0.3, 0),   # rough center
		_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size,
		col
	)
