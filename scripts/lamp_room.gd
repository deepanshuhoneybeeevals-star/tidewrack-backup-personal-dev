extends "res://scripts/game.gd"
class_name LampRoom
## Minimal lamp-room sequence. Reuses movement, dialogue UI, HUD, and pause/save.

const LAMP_DIALOGUE := "res://data/dialogue/lamp_room.json"
const LAMP_POSITION := Vector2(640, 300)
const UNLIT_COLOR := Color("#2a2f33")
const LIT_COLOR := Color("#ffd466")

var _lamp_body: ColorRect
var _lamp_glow: Polygon2D
var _lamp_status: Label
var _lamp_item: Interactable


## Build the playable room and restore the lamp's appearance from saved flags.
func _ready() -> void:
	super._ready()
	GameState.state_changed.connect(_refresh_lamp)
	_refresh_lamp()


## Create the room and a lamp that changes from cold grey to warm gold.
func _build_room() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0b1216")
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var floor_rect := ColorRect.new()
	floor_rect.color = Color("#18252e")
	floor_rect.position = ROOM.position
	floor_rect.size = ROOM.size
	add_child(floor_rect)

	var title := Label.new()
	title.text = "Cape Marrow Light — lamp room"
	title.position = Vector2(ROOM.position.x, ROOM.position.y - 34)
	title.modulate = Color(1, 1, 1, 0.5)
	add_child(title)

	_lamp_glow = Polygon2D.new()
	var points := PackedVector2Array()
	for index in 32:
		points.append(Vector2.from_angle(TAU * index / 32.0) * 110.0)
	_lamp_glow.polygon = points
	_lamp_glow.position = LAMP_POSITION
	_lamp_glow.color = Color(1.0, 0.83, 0.4, 0.2)
	add_child(_lamp_glow)

	_lamp_body = ColorRect.new()
	_lamp_body.size = Vector2(100, 120)
	_lamp_body.position = LAMP_POSITION - _lamp_body.size * 0.5
	add_child(_lamp_body)

	_lamp_status = Label.new()
	_lamp_status.position = LAMP_POSITION + Vector2(-120, -95)
	_lamp_status.size = Vector2(240, 30)
	_lamp_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_lamp_status)


## Place the lamp interaction and a stair back to the ground floor.
func _build_interactables() -> void:
	_lamp_item = _add_interactable("Great lamp", "Relight the lamp", "",
		LAMP_POSITION, Color("#e8c9a0"))
	_lamp_item.interacted.connect(_on_lamp_interacted)
	var stair := _add_interactable("Ground-floor stair", "Return downstairs", "",
		Vector2(640, 550), Color("#3a4a54"))
	stair.interacted.connect(_on_stair_interacted)


## Return downstairs using the same guarded scene transition as the entrance.
func _on_stair_interacted(_source: Interactable) -> void:
	_transition_to("res://scenes/game.tscn")


## Relight once, persist the story flag, and play the short completion line.
func _on_lamp_interacted(_source: Interactable) -> void:
	if is_lamp_lit():
		return
	GameState.set_flag("lamp_relit", true)
	DialogueManager.start(LAMP_DIALOGUE)


## Read the canonical lamp flag, treating an absent flag as an unlit lamp.
func is_lamp_lit() -> bool:
	return bool(GameState.get_flag("lamp_relit", false))


## Keep the lamp's color, glow, status, and interaction prompt in sync with state.
func _refresh_lamp() -> void:
	var lit := is_lamp_lit()
	_lamp_body.color = LIT_COLOR if lit else UNLIT_COLOR
	_lamp_glow.visible = lit
	_lamp_status.text = "Lamp lit" if lit else "Lamp unlit"
	_lamp_status.modulate = LIT_COLOR if lit else Color(1, 1, 1, 0.6)
	_lamp_item.prompt_text = "The lamp is lit" if lit else "Relight the lamp"
