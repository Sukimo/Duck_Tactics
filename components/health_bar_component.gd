extends Node2D
class_name HealthBarComponent

@export var bar_width: float = 24.0
@export var bar_height: float = 4.0
@export var offset_y: float = -24.0

@export var bg_color: Color = Color(0.8,0.1,0.1,0.9)
@export var fill_color: Color = Color(0.2,0.8,0.2,0.9)

var _hp_percent: float = 1.0

func _ready() -> void:
	call_deferred("_init_bar")

func _init_bar()-> void:
	var parent := get_parent()
	if parent.get("max_hp") !=null:
		update(parent.hp,parent.max_hp)
		
func update(current: int ,maximum: int)->void:
	_hp_percent =clampf(float(current)/float(maximum),0.0,1.0)
	queue_redraw()

func _draw()-> void:
	var bg := Rect2(Vector2(-bar_width / 2.0,offset_y),Vector2(bar_width,bar_height))
	var fill := Rect2(Vector2(-bar_width/2.0,offset_y),Vector2(bar_width*_hp_percent,bar_height))
	draw_rect(bg,bg_color)
	draw_rect(fill, fill_color)
	draw_rect(bg, Color.BLACK,false,1.0)
