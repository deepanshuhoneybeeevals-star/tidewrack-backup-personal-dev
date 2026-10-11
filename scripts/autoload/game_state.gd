extends Node
## GameState — global save/load and story flags.
##
## Autoloaded as `GameState`. Holds the narrative flags set by dialogue
## choices and persists them to user://save.json so "Continue" works.

signal state_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## Story flags set during play, e.g. {"trusted_edith": true}.
var flags: Dictionary = {}
## Path of the scene the player should resume into.
var current_scene: String = "res://scenes/game.tscn"


## Store a story flag and notify state listeners.
func set_flag(name: String, value: Variant) -> void:
	flags[name] = value
	state_changed.emit()


## Return a story flag, or the supplied default when it is absent.
func get_flag(name: String, default: Variant = false) -> Variant:
	return flags.get(name, default)


## Distinguish an unanswered flag from one explicitly set to false.
func has_flag(name: String) -> bool:
	return flags.has(name)


## Reset story flags, discovered logs, and the starting scene.
func new_game() -> void:
	flags.clear()
	Journal.clear()
	current_scene = "res://scenes/game.tscn"
	state_changed.emit()


## Report whether the single save slot exists on disk.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Write the current scene, flags, and journal entries to the save slot.
func save_game() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"scene": current_scene,
		"flags": flags,
		"journal_entries": Journal.entries(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not open save file for writing.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


## Restore saved progress, defaulting missing legacy journal data to empty.
func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: could not open save file for reading.")
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameState: save file is corrupt.")
		return false

	var data: Dictionary = parsed
	# Future-proofing: migrate older save versions here.
	current_scene = data.get("scene", "res://scenes/game.tscn")
	var loaded_flags: Variant = data.get("flags", {})
	flags = loaded_flags if typeof(loaded_flags) == TYPE_DICTIONARY else {}
	# Optional, additive v1 field. Missing/malformed journal data is empty.
	Journal.restore(data.get("journal_entries", []))
	state_changed.emit()
	return true


## Remove the save slot without changing the current session.
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
