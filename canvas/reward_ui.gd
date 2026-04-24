extends Control
# Attach to RewardUI node (CanvasLayer child, same level as PrepUI)
# Add to main.tscn under CanvasLayer as RewardUI

const REWARD_TIME   : float = 15.0
const CARD_SCENES   : Array[String] = [
	"res://units/ducks/melee_duck.tscn",
	"res://units/ducks/range_duck.tscn",
	"res://units/ducks/melee_duck_lv2.tscn",
	"res://units/ducks/range_duck_lv2.tscn",
]

const SPECIAL_OFFER_MATTHEW : String = "res://units/ducks/matthew_duck.tscn"
const SPECIAL_OFFER_CRIT    : String = "__crit_upgrade__"  # pseudo-path, not a scene


# Brown palette matching your mockup
const COLOR_PANEL_BG    := Color(0.72, 0.46, 0.30)   # warm brown
const COLOR_CARD_NORMAL := Color(0.55, 0.34, 0.20)   # darker brown card
const COLOR_CARD_SELECT := Color(0.40, 0.22, 0.10)   # darkest = selected highlight
const COLOR_CARD_HOVER  := Color(0.65, 0.42, 0.25)   # hover

@onready var card_row     : HBoxContainer = $Panel/VBox/CardRow
@onready var timer_label  : Label         = $Panel/VBox/TimerLabel
@onready var title_label  : Label         = $Panel/VBox/Title

var _countdown  : float = REWARD_TIME
var _active     : bool  = false
var _chosen     : int   = 0          # default card index
var _offers     : Array[String] = [] # 3 scene paths picked this reward
var _cards      : Array[PanelContainer] = []

# ── Public API ────────────────────────────────────────────────────────────────

## Called by WaveManager (or wherever _give_reward runs) to open the UI
func show_reward(offer_paths: Array[String]) -> void:
	_offers = offer_paths
	_chosen = 0
	_countdown = REWARD_TIME
	_active = true
	visible = true
	_build_cards()
	_refresh_cards()

# ── Godot callbacks ───────────────────────────────────────────────────────────

func _ready() -> void:
	GameState.state_changed.connect(_on_state_changed)
	_apply_panel_style()
	visible = false

func _process(delta: float) -> void:
	if not _active:
		return
	_countdown -= delta
	timer_label.text = str(ceili(_countdown))
	if _countdown <= 0.0:
		_confirm()

# ── Build UI ──────────────────────────────────────────────────────────────────

func _apply_panel_style() -> void:
	var panel := $Panel as PanelContainer
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.corner_radius_top_left    = 8
	style.corner_radius_top_right   = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right= 8
	style.content_margin_left   = 20.0
	style.content_margin_right  = 20.0
	style.content_margin_top    = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)

	# Style title
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_font_size_override("font_size", 13)
	timer_label.add_theme_color_override("font_color", Color(1, 1, 0.6))

func _build_cards() -> void:
	# Clear old cards
	for child in card_row.get_children():
		child.queue_free()
	_cards.clear()

	card_row.add_theme_constant_override("separation", 16)

	for i in _offers.size():
		var card := _make_card(i)
		card_row.add_child(card)
		_cards.append(card)

func _make_card(idx: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(110, 130)

	# Inner VBox
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Duck icon
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(64, 64)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_load_duck_texture(tex, _offers[idx])
	vbox.add_child(tex)

	# Duck name label
	var lbl := Label.new()
	lbl.text = _duck_display_name(_offers[idx])
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(lbl)

	# Click to select
	var btn_area := card  # use card's gui_input
	btn_area.gui_input.connect(func(event): _on_card_input(event, idx))
	btn_area.mouse_entered.connect(func(): _on_card_hover(idx, true))
	btn_area.mouse_exited.connect(func():  _on_card_hover(idx, false))

	return card

# ── Card interaction ──────────────────────────────────────────────────────────

func _on_card_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_chosen = idx
		_refresh_cards()
		# Double-click = confirm immediately
		if event.double_click:
			_confirm()

func _on_card_hover(idx: int, hovered: bool) -> void:
	if idx == _chosen:
		return
	var style := _card_style(COLOR_CARD_HOVER if hovered else COLOR_CARD_NORMAL)
	_cards[idx].add_theme_stylebox_override("panel", style)

func _refresh_cards() -> void:
	for i in _cards.size():
		var col := COLOR_CARD_SELECT if i == _chosen else COLOR_CARD_NORMAL
		_cards[i].add_theme_stylebox_override("panel", _card_style(col))

func _card_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left     = 6
	s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left  = 6
	s.corner_radius_bottom_right = 6
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.border_color = Color(1, 1, 1, 0.25)
	s.content_margin_left   = 8.0
	s.content_margin_right  = 8.0
	s.content_margin_top    = 8.0
	s.content_margin_bottom = 8.0
	return s

# ── Confirm pick ──────────────────────────────────────────────────────────────

func _confirm() -> void:
	_active = false
	visible = false

	var chosen_path : String = _offers[_chosen]
	var scene := load(chosen_path) as PackedScene
	if scene == null:
		push_warning("[RewardUI] Could not load: " + chosen_path)
		return
	
	if chosen_path == SPECIAL_OFFER_CRIT:
		GameState.global_duck_crit_rate += 0.05
		print("[RewardUI] Team crit +5%%  → %.0f%%" % (GameState.global_duck_crit_rate * 100))
		WaveManager.on_reward_confirmed()
		return
	
	var duck : Node = scene.instantiate()
	get_tree().current_scene.add_child(duck)
	if duck is BaseDuck:
		DuckRoster.add(duck as BaseDuck)
		print("[RewardUI] Player picked: %s" % chosen_path)

	# Tell WaveManager reward is done → slide back to rest
	WaveManager.on_reward_confirmed()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _load_duck_texture(tex: TextureRect, scene_path: String) -> void:
	# Try to grab the Sprite2D texture from the packed scene without instantiating fully
	if scene_path == SPECIAL_OFFER_CRIT: return
	if not ResourceLoader.exists(scene_path):
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return
	var state := packed.get_state()
	for i in state.get_node_count():
		if state.get_node_type(i) == "Sprite2D":
			for p in state.get_node_property_count(i):
				if state.get_node_property_name(i, p) == "texture":
					var t = state.get_node_property_value(i, p)
					if t is Texture2D:
						tex.texture = t
					return

func _duck_display_name(scene_path: String) -> String:
	if scene_path == SPECIAL_OFFER_CRIT:
		return "Crit Rate +5%"
	var file : String = scene_path.get_file().get_basename()
	return file.replace("_", " ").capitalize()

func _on_state_changed(s: GameState.State) -> void:
	if s == GameState.State.REWARD:
		_open_reward()
	elif visible:
		visible = false
		_active = false

func _open_reward() -> void:
	var offers: Array[String] = []
	if GameState.endless_mode and WaveManager.wave_index %3 ==0:
		offers = [SPECIAL_OFFER_MATTHEW,SPECIAL_OFFER_CRIT,CARD_SCENES[randi()%CARD_SCENES.size()]]
	else:
		var pool := CARD_SCENES.duplicate()
		pool.shuffle()
		for i in min(3, pool.size()):
			offers.append(pool[i])
			
	show_reward(offers)
	
