extends Node
## Exercise the minimal lamp sequence through real scene changes and save files.

const GAME_SCENE := "res://scenes/game.tscn"
const LAMP_SCENE := "res://scenes/lamp_room.tscn"
var failures: int = 0


## Protect the real save slot and survive scene changes made by the test.
func _ready() -> void:
	var isolated := OS.get_environment("TIDEWRACK_TEST_DATA")
	if isolated.is_empty() or not OS.get_user_data_dir().begins_with(isolated + "/"):
		printerr("Run through tests/run_tests.py to protect your real save slot.")
		get_tree().quit(1)
		return
	get_tree().current_scene = null
	call_deferred("_run")


## Record a failed assertion and continue the remaining lamp checks.
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


## Find a pause or title-menu button by its displayed caption.
func button_named(root: Node, caption: String) -> Button:
	if root is Button and root.text == caption:
		return root
	for child in root.get_children():
		var found := button_named(child, caption)
		if found != null:
			return found
	return null


## Place the player in range and dispatch Enter through the game's input path.
func interact_with(room: Node, index: int) -> void:
	room._player.position = room._interactables[index].position + Vector2(0, 60)
	room._process(0.0)
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = KEY_ENTER
	Input.parse_input_event(event)
	await get_tree().process_frame


## Verify the saved flag controls the rendered lamp properties and prompt.
func check_lamp(room: Node, lit: bool) -> void:
	check(room.scene_file_path == LAMP_SCENE, "stair or Continue reaches the lamp room")
	check(GameState.current_scene == LAMP_SCENE, "current scene tracks the lamp room")
	check(room.is_lamp_lit() == lit, "lamp reads the persisted flag")
	check(room._lamp_glow.visible == lit, "glow visibility matches the lamp flag")
	check(room._lamp_body.color == (room.LIT_COLOR if lit else room.UNLIT_COLOR), "lamp body changes between cold grey and warm gold")
	check(room._lamp_status.text == ("Lamp lit" if lit else "Lamp unlit"), "lamp status matches appearance")
	check(room._lamp_item.prompt_text == ("The lamp is lit" if lit else "Relight the lamp"), "prompt reflects saved state")


## Use the pause Save button and verify the scene and flag on disk.
func save_lamp(room: Node, lit: bool) -> void:
	room._toggle_pause()
	check(room._paused and not room._player.can_move, "pause works upstairs")
	button_named(room, "Save").pressed.emit()
	check(button_named(room, "Saved ✓") != null, "upstairs Save reports success")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	check(payload.scene == LAMP_SCENE, "Save records the lamp-room scene")
	check(payload.flags.get("lamp_relit", false) == lit, "Save records the lamp's state")


## Return to the title screen and let Continue restore the upstairs save.
func continue_lamp(room: Node, lit: bool) -> void:
	button_named(room, "Main Menu").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.new_game()
	button_named(get_tree().current_scene, "Continue").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check_lamp(get_tree().current_scene, lit)


## Run the live lamp loop, or verify a lamp save in a fresh process.
func _run() -> void:
	if "--lamp-read" in OS.get_cmdline_user_args():
		var menu := preload("res://scenes/main_menu.tscn").instantiate()
		get_tree().root.add_child(menu)
		get_tree().current_scene = menu
		button_named(menu, "Continue").pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		check_lamp(get_tree().current_scene, true)
		GameState.delete_save()
	else:
		GameState.new_game()
		GameState.set_flag("skeptic", true)
		Journal.discover("keeper_log")
		var ground := preload("res://scenes/game.tscn").instantiate()
		get_tree().root.add_child(ground)
		get_tree().current_scene = ground
		await get_tree().process_frame
		await interact_with(ground, 2)
		var room := get_tree().current_scene
		check_lamp(room, false)
		check(not DialogueManager.is_active, "stair changes scene without stale door dialogue")
		save_lamp(room, false)
		await continue_lamp(room, false)
		room = get_tree().current_scene
		await interact_with(room, 0)
		check_lamp(room, true)
		check(DialogueManager.is_active and not room._player.can_move, "relighting shows a line and locks movement")
		DialogueManager.advance()
		check(not DialogueManager.is_active and room._player.can_move, "completion line ends and restores control")
		await interact_with(room, 0)
		check(not DialogueManager.is_active and room.is_lamp_lit(), "repeat interaction does not relight or restart the line")
		save_lamp(room, true)
		await continue_lamp(room, true)
		room = get_tree().current_scene
		check(GameState.get_flag("skeptic") == true and Journal.has("keeper_log"), "room changes and saves preserve prior choices and discoveries")
		await interact_with(room, 1)
		ground = get_tree().current_scene
		check(ground.scene_file_path == GAME_SCENE and GameState.current_scene == GAME_SCENE, "return stair goes downstairs")
		await interact_with(ground, 2)
		room = get_tree().current_scene
		check_lamp(room, true)
		if "--lamp-write" in OS.get_cmdline_user_args():
			save_lamp(room, true)
		else:
			GameState.new_game()
			check(not room.is_lamp_lit() and not room._lamp_glow.visible and room._lamp_body.color == room.UNLIT_COLOR, "New Game resets the lamp appearance")
			check(not GameState.has_flag("lamp_relit"), "New Game removes lamp progress")
			GameState.delete_save()
	var current := get_tree().current_scene
	get_tree().current_scene = null
	current.queue_free()
	await get_tree().process_frame
	print("Lamp-room tests: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
