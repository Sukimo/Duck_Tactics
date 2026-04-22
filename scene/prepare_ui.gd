extends Control
# Attach to a CanvasLayer node called "PrepUI"

const MAX_SLOT:int= 8
const SLOT_SCENE:= "res://canvas/slot.tscn"

var slot_ducks: Array= []
var _slot_panels: Array= []
#click to place state
var _selected_duck: BaseDuck =null
var _selected_slot: int =-1

@onready var slot_bar : HBoxContainer =$SlotBar

var slot_scene: PackedScene = null

func _ready() -> void:
	if ResourceLoader.exists(SLOT_SCENE):
		slot_scene  =load(SLOT_SCENE)
	else:
		push_warning("[PrepUI] Slot scene not found at: " + SLOT_SCENE)
	
	slot_ducks.resize(MAX_SLOT)
	slot_ducks.fill(null)
	
	#build slot panels dynamically
	for i in MAX_SLOT:
		var panel : Panel =slot_scene.instantiate() if slot_scene else Panel.new()
		#bind index correctly for each slot
		panel.gui_input.connect(func(event): _on_slot_input(event,i))
		slot_bar.add_child(panel)
		_slot_panels.append(panel)
		
	GameState.state_changed.connect(_on_state_changed)
	visible =false
	DuckRoster.roster_changed.connect(_update_slot_visuals)
	_update_slot_visuals()

func _on_state_changed(s: GameState.State)->void:
	visible = s == GameState.State.PREP
	if not visible:
		_cancel_selection()

#public API
## Called by WaveManager/GameState when entering PREP
## Pass all ducks currently in the player's roster
func populate(ducks:Array)-> void:
	#clear old
	slot_ducks.fill(null)
	var i:=0
	for duck in ducks:
		if i>= MAX_SLOT:
			break
		slot_ducks[i] =duck
		duck.visible =false  # hide from world until placed
		i +=1
	_update_slot_visuals()
	
## Called when prep timer expires — teleport unplaced ducks to default spots
func place_remaining()->void:
	_cancel_selection()
	var default_positions : Array = _default_positions()
	var pos_idx := 0
	for i in MAX_SLOT:
		var duck = slot_ducks[i]
		if duck != null and is_instance_valid(duck):
			DuckRoster.deploy(duck,default_positions[pos_idx % default_positions.size()])
			pos_idx += 1
			slot_ducks[i]=null
	_update_slot_visuals()
	
#slot click
func _on_slot_input(event: InputEvent,slot_idx: int)->void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
		
	if event.button_index == MOUSE_BUTTON_LEFT:
		if slot_ducks[slot_idx] ==null:
			return
		# select this slot (or deselect if clicking same slot again)
		if _selected_slot == slot_idx:
			_cancel_selection()
		else:
			_select_slot(slot_idx)
		get_viewport().set_input_as_handled()
	
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_selection()
		get_viewport().set_input_as_handled() 

# world click to place
func _input(event: InputEvent) -> void:
	if _selected_duck == null: return
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			#check click land on slot panel?
			if _click_is_on_slot_bar(event.position):
				return
			#place duck at world pos
			var world_pos :Vector2 = get_viewport().get_canvas_transform().affine_inverse()\
				* event.position
			_place_duck(_selected_duck,world_pos)
			get_viewport().set_input_as_handled()
			
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_selection()
			get_viewport().set_input_as_handled()
			
#helper
func _select_slot(slot_idx:int)-> void:
	_selected_slot = slot_idx
	_selected_duck = slot_ducks[slot_idx]
	print("[PrepUI] Selected slot %d (%s)" % [slot_idx, _selected_duck.name])
	_update_slot_visuals()

func _cancel_selection()->void:
	_selected_duck =null
	_selected_slot = -1
	_update_slot_visuals()

func _place_duck(duck: BaseDuck, world_pos: Vector2)->void:
	DuckRoster.deploy(duck,world_pos) # handles visible + process_mode
	slot_ducks[_selected_slot] =null
	print("[PrepUI] Placed %s at %s" % [duck.name, world_pos])
	_cancel_selection()

func _click_is_on_slot_bar(screen_pos: Vector2)-> bool:
	var rect := slot_bar.get_global_rect()
	return rect.has_point(screen_pos)

#visuals
func _update_slot_visuals()->void: 
	if _slot_panels.is_empty(): 
		return
		
	for i in MAX_SLOT:
		var panel : Panel = _slot_panels[i]
		var tex : TextureRect = panel.get_node("TextureRect")
		var duck =slot_ducks[i]
		
		# Tint: filled = yellow, empty =dark
		var style:= StyleBoxFlat.new()
		if i == _selected_slot:
			style.bg_color =Color(0.2,0.8,1.0) #selected
		elif duck != null:
			style.bg_color =Color(0.3,0.3,0.3) #filled
		else:
			style.bg_color = Color(0.15,0.15,0.15) #empty
		style.border_width_bottom=2
		style.border_color = Color(0,0,0)
		panel.add_theme_stylebox_override("panel",style)
		
		#duck icon
		if duck != null and is_instance_valid(duck):
			var sprite := duck.get_node_or_null("Sprite2D") as Sprite2D
			tex.texture  =sprite.texture if sprite else null
		else:
			tex.texture =null
		
func _default_positions() -> Array:
	return [Vector2(300, 200), Vector2(350, 200), Vector2(400, 200), Vector2(450, 200),
		Vector2(300, 280), Vector2(350, 280), Vector2(400, 280), Vector2(450, 280),
		]
