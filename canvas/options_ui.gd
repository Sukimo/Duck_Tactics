extends Control
# Bus layout this script expects (set in Godot Editor):
#   Master
#   ├── Music
#   │   └── Ambience
#   └── SFX
#       ├── UI
#       └── World

# Bus index cache
# get_bus_index returns -1 if the bus doesn't exist — all setters guard against it.
@onready var _bus_music : int = AudioServer.get_bus_index("Music")
@onready var _bus_sfx : int = AudioServer.get_bus_index("SFX")
@onready var _bus_ui : int = AudioServer.get_bus_index("UI")
@onready var _bus_world    : int = AudioServer.get_bus_index("World")

# Label refs
const _CONTENTS := "Overlay/Window/VBox/SoundSection/Contents/VBoxContainer"

@onready var _music_label : Label = get_node(_CONTENTS + "/HBmusic/ValueLabel")
@onready var _sfx_label   : Label = get_node(_CONTENTS + "/HBsfx/ValueLabel")
@onready var _ui_label    : Label = get_node_or_null(_CONTENTS + "/HBui/ValueLabel")
@onready var _world_label : Label = get_node_or_null(_CONTENTS + "/HBworld/ValueLabel")

func _ready() -> void:
	visible = false
func toggle()->void:
	visible = not visible
	
func _on_close_pressed()->void:
	visible = false
func _on_overlay_gui_input(event: InputEvent)->void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		visible = false

# Helper
func _set_bus(bus_index: int, value: float, label: Label)->void:
	if bus_index < 0: return # bus not in layout yet — silent fail
	if label:
		label.text = str(int(value))
	AudioServer.set_bus_volume_db(bus_index,linear_to_db(value/100.0))
	AudioServer.set_bus_mute(bus_index,value < 0.01)

# Slider callbacks
func _on_music_slider_value_changed(value: float )->void:
	_set_bus(_bus_music,value,_music_label)
	
func _on_sfx_slider_value_changed(value: float)->void:
	_set_bus(_bus_sfx,value,_sfx_label)

func _on_ui_slider_value_changed(value: float) -> void:
	_set_bus(_bus_ui, value, _ui_label)
 
func _on_world_slider_value_changed(value: float) -> void:
	_set_bus(_bus_world, value, _world_label)
