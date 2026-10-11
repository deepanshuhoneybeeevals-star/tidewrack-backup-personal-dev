extends Node
## Synthetic joypad events verify bindings and the player's actual movement code.

var failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func axis(axis_index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis_index
	event.axis_value = value
	Input.parse_input_event(event)


func button(index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)


func _run() -> void:
	var player := preload("res://scripts/player.gd").new()
	player.bounds = Rect2(0, 0, 1000, 1000)
	add_child(player)
	player.set_physics_process(false)
	await get_tree().process_frame
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		player.position = Vector2(500, 500)
		axis(JOY_AXIS_LEFT_X, direction.x)
		axis(JOY_AXIS_LEFT_Y, direction.y)
		await get_tree().process_frame
		var vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		check(vector.is_equal_approx(direction), "left stick maps to %s" % direction)
		player._physics_process(0.1)
		check(player.position.is_equal_approx(Vector2(500, 500) + direction * player.speed * 0.1), "stick moves player toward %s" % direction)
	axis(JOY_AXIS_LEFT_X, 0.25)
	axis(JOY_AXIS_LEFT_Y, 0.0)
	await get_tree().process_frame
	check(Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") == Vector2.ZERO, "stick stays idle inside deadzone")
	axis(JOY_AXIS_LEFT_X, 0.0)
	for mapping in [[JOY_BUTTON_A, "ui_accept"], [JOY_BUTTON_B, "ui_cancel"]]:
		button(mapping[0], true)
		await get_tree().process_frame
		check(Input.is_action_pressed(mapping[1]), "joypad button triggers %s" % mapping[1])
		button(mapping[0], false)
		await get_tree().process_frame
		check(not Input.is_action_pressed(mapping[1]), "joypad button releases %s" % mapping[1])
	player.queue_free()
	await get_tree().process_frame
	print("Controller-input tests: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
