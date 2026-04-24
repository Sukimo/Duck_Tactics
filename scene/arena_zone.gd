extends Node2D

@onready var control : Control = $Control
@onready var timer_laber : Label = $Control/TimeLabel

# Arena size — must match BG ColorRect in arena_2d.tscn
const ARENA_W : float = 800.0
const ARENA_H : float = 450.0
 
# Visual settings for edge warning
const ARROW_COLOR      : Color = Color(1.0, 0.25, 0.1, 0.85)  # red-orange
const ARROW_PULSE_SPEED: float = 3.0   # oscillation speed
const ARROW_COUNT      : int   = 5     # arrows spread along each active edge
const ARROW_SIZE       : float = 22.0  # triangle half-size

# Which edges are active this wave (set by WaveManager signal)
var _active_edges : Array = []    # Array of String
var _pulse_t      : float = 0.0   # drives alpha pulse

func _ready() -> void:
	GameState.state_changed.connect(_on_state_changed)
	WaveManager.spawn_edges_ready.connect(_on_spawn_edges_ready)

func _on_spawn_edges_ready(edge: Array)->void:
	_active_edges = edge
	queue_redraw()

func _process(delta: float) -> void:
	if GameState.is_state(GameState.State.PREP):
		var time_left = WaveManager.get_time_left()
		timer_laber.text = str(int(ceil(time_left))) + "s"
		#pulse arrows
		_pulse_t += delta * ARROW_PULSE_SPEED
		queue_redraw()
	else:
		if timer_laber.text != "":
			timer_laber.text = ""

func _on_state_changed(s: GameState.State)->void:
	control.visible = (s == GameState.State.PREP)
	if s != GameState.State.PREP:
		_active_edges = []
	queue_redraw() 

# ── Draw spawn-edge warning arrows ───────────────────────────────────────────
func _draw() -> void:
	if not GameState.is_state(GameState.State.PREP):
		return
	if _active_edges.is_empty():
		return
 
	# Pulse: alpha goes 0.4 ↔ 1.0
	var pulse_alpha : float = 0.4 + 0.6 * (0.5 + 0.5 * sin(_pulse_t))
	var col := Color(ARROW_COLOR.r, ARROW_COLOR.g, ARROW_COLOR.b, pulse_alpha)
 
	for edge in _active_edges:
		_draw_edge_arrows(edge, col)
 
func _draw_edge_arrows(edge: String, col: Color) -> void:
	match edge:
		"left":
			# Arrows pointing RIGHT along left edge
			for i in ARROW_COUNT:
				var y := ARENA_H * (i + 1.0) / (ARROW_COUNT + 1.0)
				# Triangle pointing right: tip at x=0, base at x=-ARROW_SIZE
				var tip   := Vector2(0.0, y)
				var base1 := Vector2(-ARROW_SIZE, y - ARROW_SIZE * 0.6)
				var base2 := Vector2(-ARROW_SIZE, y + ARROW_SIZE * 0.6)
				draw_colored_polygon(PackedVector2Array([tip, base1, base2]), col)
				# Thin line on the edge itself
			draw_line(Vector2(0, 0), Vector2(0, ARENA_H), col, 3.0)
 
		"right":
			# Arrows pointing LEFT along right edge
			for i in ARROW_COUNT:
				var y := ARENA_H * (i + 1.0) / (ARROW_COUNT + 1.0)
				var tip   := Vector2(ARENA_W, y)
				var base1 := Vector2(ARENA_W + ARROW_SIZE, y - ARROW_SIZE * 0.6)
				var base2 := Vector2(ARENA_W + ARROW_SIZE, y + ARROW_SIZE * 0.6)
				draw_colored_polygon(PackedVector2Array([tip, base1, base2]), col)
			draw_line(Vector2(ARENA_W, 0), Vector2(ARENA_W, ARENA_H), col, 3.0)
 
		"top":
			# Arrows pointing DOWN along top edge
			for i in ARROW_COUNT:
				var x := ARENA_W * (i + 1.0) / (ARROW_COUNT + 1.0)
				var tip   := Vector2(x, 0.0)
				var base1 := Vector2(x - ARROW_SIZE * 0.6, -ARROW_SIZE)
				var base2 := Vector2(x + ARROW_SIZE * 0.6, -ARROW_SIZE)
				draw_colored_polygon(PackedVector2Array([tip, base1, base2]), col)
			draw_line(Vector2(0, 0), Vector2(ARENA_W, 0), col, 3.0)
