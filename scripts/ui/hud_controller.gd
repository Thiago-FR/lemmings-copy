class_name HudController
extends CanvasLayer
## The bar at the top of a level: the "i" button with the level's
## instructions on hover, then each count as an icon and a number (still in
## the level, saved, lost, total), the clock and the goal (the share to
## save), each with a tooltip saying what it is. The user wants icons, not
## words, on screen. Reads everything from LevelManager via signals.

const SEPARATION := 14
## Between an icon and its number.
const ICON_GAP := 2
const MARGIN := 8

@onready var _info_button: InfoButton = $Bar/Row/InfoButton
@onready var _row: HBoxContainer = $Bar/Row

var _level_manager: LevelManager
var _out_label: Label
var _saved_label: Label
var _lost_label: Label
var _total_label: Label
var _time_label: Label
var _goal_label: Label


func _ready() -> void:
	_level_manager = get_tree().get_first_node_in_group("level_manager")
	assert(_level_manager != null, "HudController requires a LevelManager in the 'level_manager' group")
	_row.add_theme_constant_override("separation", SEPARATION)
	# Behind a hover button rather than written on screen: as a label the
	# instructions covered a good part of the level.
	_info_button.tooltip_text = _level_manager.level_data.instructions
	UiStyle.apply_slot_style(_info_button)

	_out_label = _add_counter("hud_out", "Na fase: bonecos andando agora")
	_saved_label = _add_counter("hud_saved", "Salvos")
	_lost_label = _add_counter("hud_lost", "Perdidos")
	_total_label = _add_counter("hud_troop", "Total de bonecos da fase")
	_row.add_child(VSeparator.new())
	_time_label = _add_counter("hud_clock", "Tempo restante")
	_goal_label = _add_counter("hud_goal", "Meta: quantos é preciso salvar")
	_goal_label.text = "%d%%" % round(_level_manager.level_data.required_percentage * 100.0)

	_level_manager.counts_changed.connect(_on_counts_changed)
	_level_manager.time_remaining_changed.connect(_on_time_remaining_changed)
	_on_counts_changed(0, 0, 0, _level_manager.level_data.total_lemmings)
	_on_time_remaining_changed(_level_manager.time_remaining)


## An icon followed by its number; the tooltip covers both.
func _add_counter(icon_id: String, tooltip: String) -> Label:
	var counter := HBoxContainer.new()
	counter.add_theme_constant_override("separation", ICON_GAP)
	counter.tooltip_text = tooltip
	counter.mouse_filter = Control.MOUSE_FILTER_STOP
	_row.add_child(counter)
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon(icon_id)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_child(icon)
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_child(label)
	return label


func _on_counts_changed(saved_count: int, lost_count: int, spawned_count: int, total_count: int) -> void:
	_out_label.text = str(spawned_count - saved_count - lost_count)
	_saved_label.text = str(saved_count)
	_lost_label.text = str(lost_count)
	_total_label.text = str(total_count)


func _on_time_remaining_changed(seconds_remaining: float) -> void:
	var total_seconds := int(ceil(seconds_remaining))
	_time_label.text = "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
