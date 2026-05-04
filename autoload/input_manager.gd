extends Node
# autoload/input_manager.gd

var _dragging_duck: BaseDuck = null   # track which duck is being dragged

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("Click!! mouse pos: ", event.position)
	
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return

	var world := get_viewport().get_canvas_transform().affine_inverse() \
				* get_viewport().get_mouse_position()

	# ── LEFT PRESS ────────────────────────────────────────────────────────
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var ducks := get_tree().get_nodes_in_group("ducks")

			# Hit-test: find clicked duck (reverse = top z_index wins)
			var clicked: BaseDuck = null
			for i in range(ducks.size() - 1, -1, -1):
				var duck := ducks[i] as BaseDuck
				if not is_instance_valid(duck): continue
				if duck._is_click_on_self(world):
					clicked = duck
					break

			if clicked:
				# Clicked ON a duck → start hold/drag on that duck only
				clicked.handle_press(world)
				_dragging_duck = clicked
				get_viewport().set_input_as_handled()
			else:
				# Empty space click 
				var moved := false
				for duck in ducks:
					var d := duck as BaseDuck
					if not is_instance_valid(d): continue
					if d.get_selected():
						d.move_to_cmd(world)
						d._set_selected(false)
						moved = true
						
				if moved:
						get_viewport().set_input_as_handled()
				# else: fall through to PrepUI._input()

			#get_viewport().set_input_as_handled()

		# ── LEFT RELEASE ──────────────────────────────────────────────────
		else:
			if _dragging_duck and is_instance_valid(_dragging_duck):
				_dragging_duck.handle_release(world)
				get_viewport().set_input_as_handled()
			_dragging_duck = null
		
	# ── MOUSE MOTION ──────────────────────────────────────────────────────
	elif event is InputEventMouseMotion:
		if _dragging_duck and is_instance_valid(_dragging_duck):
			_dragging_duck.handle_motion(world)
			get_viewport().set_input_as_handled()

#helpers
# Called by wave end / recall_all to clean up any in-flight drag
func clear_all_selection() -> void:
	_dragging_duck = null
	for duck in get_tree().get_nodes_in_group("ducks"):
		if is_instance_valid(duck):
			(duck as BaseDuck).reset_state()
