extends Node
## Journal — ordered, unique IDs of discovered logs. Autoloaded as `Journal`.
##
## Dialogue nodes opt in with "journal_entry". GameState owns save/load and
## New Game reset. The reader UI belongs to a later milestone.

signal entry_added(id: String)

var _entries: Array[String] = []


## Record a nonblank log ID once and announce the new discovery.
func discover(id: String) -> void:
	if id.strip_edges().is_empty() or id in _entries:
		return
	_entries.append(id)
	entry_added.emit(id)


## Return a copy of discovered log IDs in discovery order.
func entries() -> Array[String]:
	return _entries.duplicate()


## Report whether a log ID has already been discovered.
func has(id: String) -> bool:
	return id in _entries


## Remove all discovered logs from the current session.
func clear() -> void:
	_entries.clear()


## Replace session state on load, including for old saves with no journal.
## Loading is not discovery: do not emit entry_added for restored entries.
func restore(saved_entries: Variant) -> void:
	_entries.clear()
	if typeof(saved_entries) != TYPE_ARRAY:
		return
	for id in saved_entries:
		if typeof(id) == TYPE_STRING and not id.strip_edges().is_empty() and id not in _entries:
			_entries.append(id)
