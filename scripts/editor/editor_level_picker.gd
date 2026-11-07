class_name EditorLevelPicker
extends CanvasLayer
## Picks where a drawing is opened from or saved to, in three steps:
## 1. the collection (LevelCollection.all(): the free mode's drawings, and
##    in developer mode the campaign and each game mode's stages; a new
##    collection shows up here by itself);
## 2. the slot, numbered (its level's name in the tooltip; to open, empty
##    slots are greyed out; a clock marks slots with backups);
## 3. to open a slot with backups, the version: the current one or a backup
##    by the date it was replaced.
## Emits picked(collection, index, backup_folder) (folder "" for the
## current version) or just closes on Back / Esc.
##
## The slots and the versions scroll when there are more than fit on the
## screen (the panel used to run off it).

signal picked(collection: LevelCollection, index: int, backup_folder: String)

enum Purpose { OPEN, SAVE }

const LAYER := 30
const BACKDROP_COLOUR := Color(0.03, 0.03, 0.06, 0.65)
const SLOT_BUTTON_SIZE := Vector2(64, 40)
const SLOT_COLUMNS := 10
const SLOT_FONT_SIZE := 18
const ICON_SCALE := 2.0
const COLLECTION_BUTTON_SIZE := Vector2(220, 52)
## Most of the screen's height a scrolling list takes.
const LIST_MAX_SCREEN_SHARE := 0.55

var _purpose: Purpose
## The collection and slot the drawing came from, highlighted.
var _current_collection: LevelCollection
var _current_index: int
var _column: VBoxContainer


func _init(purpose: Purpose, current_collection: LevelCollection = null, current_index: int = -1) -> void:
	_purpose = purpose
	_current_collection = current_collection
	_current_index = current_index
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
	var collections := LevelCollection.all()
	if collections.size() == 1:
		_show_slots(collections[0])
	else:
		_show_collections(collections)


## The big icon on top: the scroll to open, the chest to save.
func _add_header() -> void:
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon("campaign" if _purpose == Purpose.OPEN else "level_save")
	icon.custom_minimum_size = Vector2(32, 32) * ICON_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.tooltip_text = "Abrir" if _purpose == Purpose.OPEN else "Salvar"
	_column.add_child(icon)


func _show_collections(collections: Array[LevelCollection]) -> void:
	_clear()
	_add_header()
	for collection in collections:
		var button := UiStyle.make_text_button(collection.get_display_name(), _is_current(collection))
		button.name = "Collection_%s" % collection.get_display_name()
		button.icon = UiStyle.icon(collection.get_icon_id())
		button.custom_minimum_size = COLLECTION_BUTTON_SIZE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_show_slots.bind(collection))
		if _purpose == Purpose.OPEN and not _has_any_level(collection):
			button.disabled = true
			button.tooltip_text = "Nada salvo ainda"
		_column.add_child(button)
	_add_back_button(func() -> void: queue_free())


func _show_slots(collection: LevelCollection) -> void:
	_clear()
	_add_header()
	var title := Label.new()
	title.text = collection.get_display_name()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = mini(SLOT_COLUMNS, maxi(1, collection.get_slot_count()))
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for index in collection.get_slot_count():
		if _purpose == Purpose.OPEN and not collection.has_level(index):
			continue
		grid.add_child(_make_slot_button(collection, index))
	_add_scrolling(grid)
	_add_back_button(func() -> void:
		var collections := LevelCollection.all()
		if collections.size() == 1:
			queue_free()
		else:
			_show_collections(collections))


func _make_slot_button(collection: LevelCollection, index: int) -> Button:
	var filled := collection.has_level(index)
	var button := UiStyle.make_text_button(str(index + 1), _is_current(collection) and index == _current_index)
	button.name = "Slot%02d" % (index + 1)
	button.custom_minimum_size = SLOT_BUTTON_SIZE
	button.add_theme_font_size_override("font_size", SLOT_FONT_SIZE)
	button.tooltip_text = collection.get_slot_name(index) if filled else "Vazio"
	button.disabled = _purpose == Purpose.OPEN and not filled
	var backups := collection.list_backups(index)
	if not backups.is_empty():
		button.icon = UiStyle.icon("hud_clock")
		button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.tooltip_text += "  (%d backup%s)" % [backups.size(), "" if backups.size() == 1 else "s"]
	button.pressed.connect(func() -> void:
		if _purpose == Purpose.OPEN and not backups.is_empty():
			_show_versions(collection, index, backups)
		else:
			_pick(collection, index, ""))
	return button


## The level now, then each backup by the date it was replaced.
func _show_versions(collection: LevelCollection, index: int, backups: Array[Dictionary]) -> void:
	_clear()
	_add_header()
	var title := Label.new()
	title.text = "%d. %s" % [index + 1, collection.get_slot_name(index)]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	var current := UiStyle.make_text_button("Atual", true)
	current.name = "Current"
	current.icon = UiStyle.icon("star")
	current.pressed.connect(_pick.bind(collection, index, ""))
	var versions := VBoxContainer.new()
	versions.name = "Versions"
	versions.add_theme_constant_override("separation", 14)
	versions.add_child(current)
	for backup in backups:
		var button := UiStyle.make_text_button(backup.label)
		button.icon = UiStyle.icon("hud_clock")
		button.tooltip_text = "Versão substituída nesse dia"
		button.pressed.connect(_pick.bind(collection, index, String(backup.folder)))
		versions.add_child(button)
	_add_scrolling(versions)
	_add_back_button(_show_slots.bind(collection))


## Adds a list inside a vertical scroll no taller than LIST_MAX_SCREEN_SHARE
## of the screen, as tall as the list when it fits.
func _add_scrolling(content: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_column.add_child(scroll)
	var wanted := content.get_combined_minimum_size()
	var limit := get_viewport().get_visible_rect().size.y * LIST_MAX_SCREEN_SHARE
	var scrollbar_width := scroll.get_v_scroll_bar().get_combined_minimum_size().x
	scroll.custom_minimum_size = Vector2(wanted.x + (scrollbar_width if wanted.y > limit else 0.0), minf(wanted.y, limit))


func _add_back_button(action: Callable) -> void:
	var back := UiStyle.make_icon_button("editor_menu", "Voltar")
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(action)
	_column.add_child(back)


func _has_any_level(collection: LevelCollection) -> bool:
	for index in collection.get_slot_count():
		if collection.has_level(index):
			return true
	return false


func _is_current(collection: LevelCollection) -> bool:
	return _current_collection != null and collection.get_script() == _current_collection.get_script()


func _pick(collection: LevelCollection, index: int, backup_folder: String) -> void:
	picked.emit(collection, index, backup_folder)
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
