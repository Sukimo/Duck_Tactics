extends BaseDuck
class_name MatthewDuck

# Matthew adds his aura to the global crit rate on spawn, removes it on death
@export var aura_crit_bonus: float = 0.10   # +10% to GameState.global_duck_crit_rate

const LABEL_COLOR_NAME  := Color(0,0,0,1.0)
const LABEL_COLOR_LEVEL := Color(0,0,0, 1.0)
const LABEL_OFFSET_Y    := -38.0

func _ready() -> void:
	super._ready()
	GameState.global_duck_crit_rate += aura_crit_bonus
	print("[Matthew] Aura ON — global crit rate → %.0f%%" \
		% (GameState.global_duck_crit_rate * 100))

func _exit_tree() -> void:
	GameState.global_duck_crit_rate = maxf(
		0.0, GameState.global_duck_crit_rate - aura_crit_bonus
	)
	print("[Matthew] Aura OFF — global crit rate → %.0f%%" \
		% (GameState.global_duck_crit_rate * 100))

func _draw() -> void:
	super._draw()
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-24, LABEL_OFFSET_Y),
		"Matthew",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		LABEL_COLOR_NAME
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-10, LABEL_OFFSET_Y + 13),
		"Lv.%d" % duck_level,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		LABEL_COLOR_LEVEL
	)

func _process(delta: float) -> void:
	super._process(delta)
	queue_redraw()

func duck_type() -> String:
	return "MatthewDuck"
