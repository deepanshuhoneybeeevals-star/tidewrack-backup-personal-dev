extends Node
## Exercise keyboard input through Godot's input dispatch, including GUI focus.

var failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func button_named(root: Node, caption: String) -> Button:
	if root is Button and root.text == caption:
		return root
	for child in root.get_children():
		var found := button_named(child, caption)
		if found != null:
			return found
	return null


func escape(echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	Input.parse_input_event(event)
	await get_tree().process_frame


func overlay_count(game: Node) -> int:
	var count := 0
	for child in game.get_children():
		if child is CanvasLayer and child.get_node_or_null("PauseOverlay") != null:
			count += 1
	return count


func _run() -> void:
	var game := preload("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	for cycle in 3:
		await escape()
		check(game._paused and not game._player.can_move, "Escape pauses and locks movement")
		check(overlay_count(game) == 1, "exactly one pause overlay exists")
		await escape(true)
		check(game._paused and overlay_count(game) == 1, "held Escape does not toggle repeatedly")
		await escape()
		check(not game._paused and game._player.can_move, "second Escape resumes movement")
		check(overlay_count(game) == 0, "second Escape removes the pause overlay")
	await escape()
	var resume := button_named(game, "Resume")
	check(resume != null, "Resume button exists")
	if resume != null:
		resume.pressed.emit()
	await get_tree().process_frame
	check(not game._paused and game._player.can_move and overlay_count(game) == 0, "Resume follows the same cleanup path")
	await escape()
	button_named(game, "Settings").pressed.emit()
	await get_tree().process_frame
	await escape()
	check(button_named(game, "Back") == null, "Escape closes nested Settings")
	check(game._paused and not game._player.can_move and overlay_count(game) == 1, "closing Settings leaves the game paused")
	await escape()
	check(not game._paused and overlay_count(game) == 0, "next Escape dismisses the pause overlay")
	DialogueManager.start("res://data/dialogue/keeper_intro.json", "door")
	await escape()
	check(DialogueManager.is_active and not game._player.can_move and overlay_count(game) == 0, "Escape cannot pause during dialogue")
	DialogueManager.advance()
	check(game._player.can_move, "dialogue completion restores movement")
	game.queue_free()
	await get_tree().process_frame
	print("Pause-menu tests: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
