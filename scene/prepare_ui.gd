extends Control
# Attach to a CanvasLayer node called "PrepUI"
const MAX_SLOT:int= 8

var slot_ducks: Array= []
var _slot_panels: Array= []
var _dragging_duck: BaseDuck = null
var _drag_from_slot: int =-1

@onready var slot_bar : HBoxContainer =$SlotBar

func _ready() -> void:
	slot_ducks.resize(MAX_SLOT)
	slot_ducks.fill(null)
	
	#build slot panels dynamically
	for i in MAX_SLOT:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(48,48)
		slot_bar.add_child(panel)
		_slot_panels.append(panel)
		
	GameState.state_changed.connect(_on_state_chenged)
	visible =false

func _on_state_chenged(s: GameState.State)->void:
	visible = s == GameState.State.PREP
	
#public API

## Called by WaveManager/GameState when entering PREP
## Pass all ducks currently in the player's roster
func populate(ducks:Array)-> void:
	#clear old
	slot_ducks.fill(null)
	_update_slot_visuals()
	
	var i:=0
	for duck in ducks:
		if i>= MAX_SLOT:
			break
		slot_ducks[i] =duck
		duck.visible =false  # hide from world until placed
	_update_slot_visuals()
	
## Called when prep timer expires — teleport unplaced ducks to default spots
func place_remaining()->void:
	var default_positions : Array = _default_positions()
	var pos_idx := 0
	for i in MAX_SLOT:
		var duck = slot_ducks[i]
		if duck != null and is_instance_valid(duck):
			duck.visible =true
			duck.global_position = default_positions[pos_idx % default_positions.size()]
			pos_idx += 1
			slot_ducks[i]=null
	_update_slot_visuals()
	
# drag from slot
func _gui_input_on_slot(event: InputEvent, slot_idx: int)->void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and slot_ducks[slot_idx] !=null: 
			_start_drag(slot_idx)
			
func _start_drag(slot_idx: int)->void:
	_dragging_duck = slot_ducks[slot_idx]
	_drag_from_slot =slot_idx
	slot_ducks[slot_idx] = null
	_update_slot_visuals()
	_dragging_duck.visible =true
	_dragging_duck.global_position =get_viewport().get_mouse_position()
	# hand off dragging to the duck's own input (already in duck.gd)
	# duck.gd will call _try_merge_at or just drop on world

func _input(event: InputEvent) -> void:
	if _dragging_duck == null:
		return
	if event is InputEventMouseMotion:
		_dragging_duck.global_position = get_viewport().get_mouse_position()
	if event is InputEventMouseButton and not event.pressed:
		_on_drop()

func _on_drop()->void:
	if _dragging_duck == null:
		return
	# Duck stays where it landed — duck.gd handles merge logic already
	_dragging_duck =null
	_drag_from_slot = -1

#visuals
func _update_slot_visuals()->void: 
	for i in MAX_SLOT:
		var panel : Panel = _slot_panels[i]
		var duck =slot_ducks[i]
		# Tint: filled = yellow, empty =dark
		var style:= StyleBoxFlat.new()
		style.bg_color =Color(0.9,0.8,0.1) if duck != null else Color(0.2,0.2,0.2,)
		style.border_width_bottom=2
		style.border_color = Color(0,0,0)
		panel.add_theme_stylebox_override("panel",style)
		
func _default_positions() -> Array:
	return [Vector2(300, 200), Vector2(350, 200), Vector2(400, 200), Vector2(450, 200),
		Vector2(300, 280), Vector2(350, 280), Vector2(400, 280), Vector2(450, 280),
		]
