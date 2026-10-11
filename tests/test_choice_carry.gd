extends Node
## Run only with an isolated XDG_DATA_HOME; this exercises the real save slot.

const INTRO := "res://data/dialogue/keeper_intro.json"
var failures: int = 0
var last_text: String = ""
var last_choices: Array = []


func _ready() -> void:
	var isolated := OS.get_environment("TIDEWRACK_TEST_DATA")
	if isolated.is_empty() or not OS.get_user_data_dir().begins_with(isolated + "/"):
		printerr("Run through tests/run_tests.py to protect your real save slot (Linux).")
		get_tree().quit(1)
		return
	# Keep the runner alive while exercising real scene transitions.
	get_tree().current_scene = null
	DialogueManager.line_shown.connect(func(_speaker: String, text: String, choices: Array):
		last_text = text
		last_choices = choices)
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func finish_dialogue() -> void:
	for step in 20:
		if not DialogueManager.is_active:
			return
		if not last_choices.is_empty():
			DialogueManager.choose(0)
		else:
			DialogueManager.advance()
	check(false, "dialogue should terminate")


func _run() -> void:
	if "--journal-write" in OS.get_cmdline_user_args():
		test_journal_restart_write()
		get_tree().quit(1 if failures else 0)
		return
	if "--journal-read" in OS.get_cmdline_user_args():
		await test_journal_restart_read()
		get_tree().quit(1 if failures else 0)
		return
	# Actual authored graph -> choice -> disk -> fresh state -> load.
	GameState.new_game()
	check(DialogueManager.start(INTRO, "logbook"), "keeper graph starts")
	DialogueManager.advance()
	DialogueManager.advance()
	DialogueManager.choose(0)
	check(GameState.get_flag("skeptic") == true, "skeptic choice reaches GameState")
	DialogueManager.advance()
	DialogueManager.advance()
	DialogueManager.choose(1)
	DialogueManager.advance()
	check(GameState.flags.has("trusted_edith"), "quiet is recorded, not absent")
	check(GameState.get_flag("trusted_edith") == false, "quiet remains false")
	check(GameState.save_game(), "save succeeds")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	check(payload.flags.get("skeptic") == true, "skeptic is on disk")
	check(payload.flags.has("trusted_edith") and payload.flags.trusted_edith == false, "false is on disk")
	GameState.new_game()
	check(GameState.flags.is_empty(), "New Game clears choices")
	check(GameState.load_game(), "saved game loads")
	check(GameState.get_flag("skeptic") == true, "load restores skeptic")
	print("SAVE ROUND TRIP: skeptic and quiet checked")
	DialogueManager.start(INTRO, "logbook")
	DialogueManager.advance()
	DialogueManager.advance()
	check(last_choices.is_empty(), "reread remembers stance instead of asking again")
	check(last_text.begins_with("Fog does strange work"), "reread follows skeptic response")
	finish_dialogue()
	test_keyboard_bindings()
	test_choice_matrix()
	test_legacy_saves()
	test_journal()
	await test_menu_flow()
	GameState.delete_save()
	print("Choice and journal tests: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)


func test_choice_matrix() -> void:
	for stance in 2:
		for disclosure in 2:
			GameState.new_game()
			DialogueManager.start(INTRO, "logbook")
			DialogueManager.advance()
			DialogueManager.advance()
			check(last_choices.size() == 2, "new game asks for stance")
			DialogueManager.choose(-1)
			DialogueManager.choose(99)
			check(GameState.flags.is_empty(), "invalid choice leaves flags untouched")
			DialogueManager.advance()
			check(last_choices.size() == 2, "advance cannot bypass a choice")
			DialogueManager.choose(stance)
			check(GameState.get_flag("skeptic") == (stance == 0), "skeptic is exclusive")
			check(GameState.get_flag("believer") == (stance == 1), "believer is exclusive")
			DialogueManager.advance()
			DialogueManager.advance()
			check(last_choices.size() == 2, "absent disclosure still prompts")
			DialogueManager.choose(disclosure)
			DialogueManager.advance()
			var expected := GameState.flags.duplicate(true)
			check(GameState.save_game(), "matrix save")
			GameState.new_game()
			check(GameState.load_game(), "matrix load")
			check(GameState.flags == expected, "all chosen flags survive load")
			for reread in 2:
				DialogueManager.start(INTRO, "logbook")
				DialogueManager.advance()
				DialogueManager.advance()
				check(last_choices.is_empty(), "saved stance skips choice")
				check(last_text.begins_with("Fog does strange work" if stance == 0 else "You look toward"), "saved stance response")
				DialogueManager.advance()
				DialogueManager.advance()
				check(last_choices.is_empty(), "saved disclosure skips choice, even false")
				check(last_text.begins_with("You should raise Tom" if disclosure == 0 else "You'll keep this"), "saved disclosure response")
				DialogueManager.advance()
				check(not DialogueManager.is_active, "remembered graph terminates")
				check(GameState.flags == expected, "rereading does not mutate decisions")


func test_legacy_saves() -> void:
	for stance in ["skeptic", "believer"]:
		var legacy_flags := {stance: true, "trusted_edith": false, "future_flag": "preserved"}
		write_save({"version": 1, "scene": "res://scenes/game.tscn", "flags": legacy_flags})
		GameState.new_game()
		check(GameState.load_game(), "legacy v1 loads")
		DialogueManager.start(INTRO, "logbook")
		DialogueManager.advance()
		DialogueManager.advance()
		check(last_choices.is_empty(), "single-stance legacy save is remembered")
		check(last_text.begins_with("Fog does strange work" if stance == "skeptic" else "You look toward"), "legacy response matches")
		finish_dialogue()
		check(GameState.flags == legacy_flags, "legacy and unknown flags are preserved")
	# Old builds could set both true. Never invent which was most recent.
	for new_stance in 2:
		write_save({"version": 1, "flags": {"skeptic": true, "believer": true, "trusted_edith": false}})
		check(GameState.load_game(), "ambiguous legacy save loads")
		DialogueManager.start(INTRO, "logbook")
		DialogueManager.advance()
		DialogueManager.advance()
		check(last_choices.size() == 2, "ambiguous legacy stance asks again")
		DialogueManager.choose(new_stance)
		check(GameState.get_flag("skeptic") == (new_stance == 0), "rechoice repairs skeptic")
		check(GameState.get_flag("believer") == (new_stance == 1), "rechoice repairs believer")
		finish_dialogue()


func write_save(payload: Dictionary) -> void:
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()


func button_named(root: Node, caption: String) -> Button:
	if root is Button and root.text == caption:
		return root
	for child in root.get_children():
		var found := button_named(child, caption)
		if found != null:
			return found
	return null


func test_menu_flow() -> void:
	GameState.new_game()
	var game := preload("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	# Interact through the actual world object and choose via actual UI buttons.
	game._interactables[0].interact()
	check(Journal.entries() == ["keeper_log"], "world logbook discovers exactly one log")
	DialogueManager.advance()
	DialogueManager.advance()
	var box := game.get_node("DialogueBox")
	box._process(100.0)
	var skeptic := button_named(box, "She was tired and seeing things.")
	check(skeptic != null and not skeptic.disabled, "skeptic UI choice enabled after reveal")
	skeptic.pressed.emit()
	await get_tree().process_frame
	DialogueManager.advance()
	DialogueManager.advance()
	box._process(100.0)
	button_named(box, "Keep it to yourself for now.").pressed.emit()
	DialogueManager.advance()
	game._toggle_pause()
	button_named(game, "Save").pressed.emit()
	check(button_named(game, "Saved ✓") != null, "pause Save reports success")
	var expected := GameState.flags.duplicate(true)
	button_named(game, "Main Menu").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.new_game() # Mimic fresh-process memory; Continue must read disk.
	var menu := get_tree().current_scene
	var continue_button := button_named(menu, "Continue")
	check(continue_button != null and not continue_button.disabled, "Continue is available")
	continue_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	game = get_tree().current_scene
	check(game.scene_file_path == "res://scenes/game.tscn", "Continue opens saved scene")
	check(GameState.flags == expected, "Continue restores decisions")
	check(Journal.entries() == ["keeper_log"], "Continue restores log before interacting again")
	game._interactables[0].interact()
	check(Journal.entries() == ["keeper_log"], "world logbook discovers exactly one log")
	DialogueManager.advance()
	DialogueManager.advance()
	check(last_choices.is_empty() and last_text.begins_with("Fog does strange work"), "world interaction after Continue remembers skeptic")
	finish_dialogue()
	game.queue_free()
	get_tree().current_scene = null
	await get_tree().process_frame


func test_keyboard_bindings() -> void:
	for binding in [["ui_accept", KEY_ENTER], ["ui_accept", KEY_SPACE], ["ui_cancel", KEY_ESCAPE],
		["ui_left", KEY_LEFT], ["ui_right", KEY_RIGHT], ["ui_up", KEY_UP], ["ui_down", KEY_DOWN]]:
		var key := InputEventKey.new()
		key.keycode = binding[1]
		check(InputMap.action_has_event(binding[0], key), "keyboard binding: %s / %s" % binding)


func test_journal() -> void:
	check(get_node_or_null("/root/Journal") != null, "Journal is an autoload")
	GameState.new_game()
	check(Journal.entries().is_empty(), "New Game clears the journal")
	var discoveries: Array = []
	var on_discovery := func(id: String): discoveries.append(id)
	Journal.entry_added.connect(on_discovery)
	# Nearby interactions are not documents; only marked nodes record a log.
	for entry in ["door", "radio"]:
		DialogueManager.start(INTRO, entry)
		finish_dialogue()
	check(Journal.entries().is_empty(), "radio and stairs do not discover logs")
	DialogueManager.start(INTRO, "logbook")
	check(Journal.has("keeper_log"), "opening the authored log discovers it")
	finish_dialogue()
	DialogueManager.start(INTRO, "logbook")
	finish_dialogue()
	check(discoveries == ["keeper_log"], "rereading emits discovery only once")
	# Exercise multiple IDs without inventing another document in game content.
	Journal.discover("test_second_log")
	Journal.discover("test_second_log")
	Journal.discover("")
	Journal.discover("   ")
	check(Journal.entries() == ["keeper_log", "test_second_log"], "entries stay unique and ordered")
	var snapshot := Journal.entries()
	snapshot.clear()
	check(Journal.entries().size() == 2, "entries returns a copy")
	check(GameState.save_game(), "journal save succeeds")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	check(payload.journal_entries == ["keeper_log", "test_second_log"], "journal IDs are on disk")
	GameState.new_game()
	check(Journal.entries().is_empty(), "New Game clears discovered logs")
	Journal.discover("unsaved_other_session")
	discoveries.clear()
	check(GameState.load_game(), "journal save loads")
	check(Journal.entries() == ["keeper_log", "test_second_log"], "load replaces rather than merges journals")
	check(discoveries.is_empty(), "restoring entries does not announce fresh discoveries")
	Journal.discover("keeper_log")
	check(discoveries.is_empty(), "restored entry cannot be discovered twice")
	write_save({"version": 1, "flags": {"skeptic": true}})
	check(GameState.load_game(), "pre-journal save loads")
	check(Journal.entries().is_empty(), "pre-journal save clears stale session entries")
	check(GameState.get_flag("skeptic") == true, "pre-journal story flags remain intact")
	for invalid in [null, "keeper_log", 42, {"keeper_log": true}]:
		Journal.discover("stale")
		write_save({"version": 1, "journal_entries": invalid})
		check(GameState.load_game(), "malformed journal field does not break loading")
		check(Journal.entries().is_empty(), "malformed journal field becomes empty")
	write_save({"version": 1, "journal_entries": ["future_log", null, 2, "", "  ", "keeper_log", "future_log"]})
	check(GameState.load_game(), "mixed journal list loads")
	check(Journal.entries() == ["future_log", "keeper_log"], "valid IDs survive in order; invalid and duplicate values are ignored")
	GameState.delete_save()
	check(not GameState.load_game(), "missing save returns false")
	check(Journal.entries() == ["future_log", "keeper_log"], "failed load does not clear the journal")
	Journal.entry_added.disconnect(on_discovery)


func test_journal_restart_write() -> void:
	GameState.new_game()
	DialogueManager.start(INTRO, "logbook")
	finish_dialogue()
	Journal.discover("test_second_log")
	check(GameState.save_game(), "cross-process save succeeds")
	print("JOURNAL RESTART: saved keeper log and second test entry")


func test_journal_restart_read() -> void:
	check(Journal.entries().is_empty(), "fresh process has no journal in memory")
	var menu := preload("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	button_named(menu, "Continue").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().current_scene.scene_file_path == "res://scenes/game.tscn", "fresh-process Continue opens saved scene")
	check(Journal.entries() == ["keeper_log", "test_second_log"], "fresh-process Continue restores all entries in order")
	check(GameState.get_flag("skeptic") == true, "fresh-process Continue still restores choices")
	var game := get_tree().current_scene
	game._interactables[0].interact()
	finish_dialogue()
	check(Journal.entries() == ["keeper_log", "test_second_log"], "post-restart reread does not duplicate entries")
	game.queue_free()
	get_tree().current_scene = null
	await get_tree().process_frame
	GameState.delete_save()
	print("JOURNAL RESTART: Continue verified in a separate process")
