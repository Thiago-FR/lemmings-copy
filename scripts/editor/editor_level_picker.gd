class_name EditorLevelPicker
extends CanvasLayer
## Developer mode, in the editor: picks one of the 15 campaign levels, as
## the level select shows them (five settings of three, numbered, the name
## in the tooltip). To open, a level with backups then asks which version:
## the current one or a backup (by the date it was replaced). To save, the
## level the drawing came from is highlighted. Emits picked(index, folder)
## (folder "" for the current version) or closes on Back / Esc.

signal picked(index: int, backup_folder: String)

enum Purpose { OPEN, SAVE }

const LAYER := 30
const BACKDROP_COLOUR := Color(0.03, 0.03, 0.06, 0.65)
const LEVEL_BUTTON_SIZE := Vector2(72, 44)
const LEVEL_FONT_SIZE := 20
const ICON_SCALE := 2.0

var _purpose: Purpose
var _highlight: int
var _column: VBoxContainer


func _init(purpose: Purpose, highlight: int = -1) -> void:
	_purpose = purpose
	_highlight = highlight
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOUR
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 14)
	margin.add_child(_column)
	_show_levels()


## The big icon on top: the scroll to open, the chest to save.
func _add_header() -> void:
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon("campaign" if _purpose == Purpose.OPEN else "level_save")
	icon.custom_minimum_size = Vector2(32, 32) * ICON_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.tooltip_text = "Abrir uma fase" if _purpose == Purpose.OPEN else "Salvar por cima de uma fase"
	_column.add_child(icon)


func _show_levels() -> void:
	_clear()
	_add_header()
	var worlds := HBoxContainer.new()
	worlds.add_theme_constant_override("separation", 12)
	_column.add_child(worlds)
	for world in Campaign.LEVEL_COUNT / Campaign.LEVELS_PER_WORLD:
		var levels := VBoxContainer.new()
		levels.add_theme_constant_override("separation", 6)
		worlds.add_child(levels)
		for index in range(world * Campaign.LEVELS_PER_WORLD, (world + 1) * Campaign.LEVELS_PER_WORLD):
			levels.add_child(_make_level_button(index))
	_add_back_button(func() -> void: queue_free())


func _make_level_button(index: int) -> Button:
	var button := UiStyle.make_text_button(str(index + 1), index == _highlight)
	button.name = "Level%02d" % (index + 1)
	button.custom_minimum_size = LEVEL_BUTTON_SIZE
	button.add_theme_font_size_override("font_size", LEVEL_FONT_SIZE)
	button.tooltip_text = Campaign.load_level_data(index).level_name
	var backups := CampaignLevelStore.list_backups(index)
	if not backups.is_empty():
		button.icon = UiStyle.icon("hud_clock")
		button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.tooltip_text += "  (%d backup%s)" % [backups.size(), "" if backups.size() == 1 else "s"]
	button.pressed.connect(func() -> void:
		if _purpose == Purpose.OPEN and not backups.is_empty():
			_show_versions(index, backups)
		else:
			_pick(index, ""))
	return button


## The level now, then each backup by the date it was replaced.
func _show_versions(index: int, backups: Array[Dictionary]) -> void:
	_clear()
	_add_header()
	var title := Label.new()
	title.text = "%d. %s" % [index + 1, Campaign.load_level_data(index).level_name]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	var current := UiStyle.make_text_button("Atual", true)
	current.name = "Current"
	current.icon = UiStyle.icon("star")
	current.pressed.connect(_pick.bind(index, ""))
	_column.add_child(current)
	for backup in backups:
		var button := UiStyle.make_text_button(backup.label)
		button.icon = UiStyle.icon("hud_clock")
		button.tooltip_text = "Versão substituída nesse dia"
		button.pressed.connect(_pick.bind(index, String(backup.folder)))
		_column.add_child(button)
	_add_back_button(_show_levels)


func _add_back_button(action: Callable) -> void:
	var back := UiStyle.make_icon_button("editor_menu", "Voltar")
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(action)
	_column.add_child(back)


func _pick(index: int, backup_folder: String) -> void:
	picked.emit(index, backup_folder)
	queue_free()


func _clear() -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()
