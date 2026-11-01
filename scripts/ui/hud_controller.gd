class_name HudController
extends CanvasLayer
## Displays lemming counts, time remaining, the required save percentage and
## an "i" button that shows the level's instructions on hover. Reads everything from LevelManager via signals.
## Label text is Portuguese because it is player-facing; the code around it
## stays English like the rest of the project.

@onready var _lemmings_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/LemmingsLabel
@onready var _time_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/TimeLabel
@onready var _required_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/RequiredLabel
@onready var _info_button: InfoButton = $MarginContainer/VBoxContainer/HBoxContainer/InfoButton

var _level_manager: LevelManager


func _ready() -> void:
	_level_manager = get_tree().get_first_node_in_group("level_manager")
	assert(_level_manager != null, "HudController requires a LevelManager in the 'level_manager' group")

	_level_manager.counts_changed.connect(_on_counts_changed)
	_level_manager.time_remaining_changed.connect(_on_time_remaining_changed)

	_required_label.text = "Meta: %d%%" % round(_level_manager.level_data.required_percentage * 100.0)
	# Behind a hover button rather than written on screen: as a label the
	# instructions covered a good part of the level.
	_info_button.tooltip_text = _level_manager.level_data.instructions
	_on_counts_changed(0, 0, 0, _level_manager.level_data.total_lemmings)
	_on_time_remaining_changed(_level_manager.time_remaining)


func _on_counts_changed(saved_count: int, lost_count: int, spawned_count: int, total_count: int) -> void:
	var out_count := spawned_count - saved_count - lost_count
	_lemmings_label.text = "Na fase: %d   Salvos: %d   Perdidos: %d   Total: %d" % [out_count, saved_count, lost_count, total_count]


func _on_time_remaining_changed(seconds_remaining: float) -> void:
	var total_seconds := int(ceil(seconds_remaining))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	_time_label.text = "%02d:%02d" % [minutes, seconds]
