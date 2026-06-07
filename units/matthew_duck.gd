extends BaseDuck
class_name MatthewDuck

# Matthew's identity now lives entirely in his child AbilityComponent nodes:
#   - CritAuraAbility  (child node in matthew_duck.tscn)
#   - GooThrowAbility  (child node in matthew_duck.tscn)
#
# This script is intentionally thin — no hardcoded aura math here.
# To transfer an ability to another duck at runtime:
#   AbilityManager.transfer_ability(matthew, other_duck, "GooThrowAbility")

const LABEL_COLOR_NAME  := Color(0,0,0,1.0)
const LABEL_COLOR_LEVEL := Color(0,0,0, 1.0)
const LABEL_OFFSET_Y    := -38.0

func _ready() -> void:
	super._ready()

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
