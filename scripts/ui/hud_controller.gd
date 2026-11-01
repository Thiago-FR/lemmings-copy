class_name HudController
extends CanvasLayer
## Displays lemming counts, time remaining and the required save percentage
## for the active level. Reads everything from LevelManager via signals.

@onready var _lemmings_label: Label = $MarginContainer/HBoxContainer/LemmingsLabel
@onready var _time_label: Label = $MarginContainer/HBoxContainer/TimeLabel
@onready var _required_label: Label = $MarginContainer/HBoxContainer/RequiredLabel

var _level_manager: LevelManager


func _ready() -> void:
	_level_manager = get_tree().get_first_node_in_group("level_manager")
	assert(_level_manager != null, "HudController requires a LevelManager in the 'level_manager' group")

	_level_manager.counts_changed.connect(_on_counts_changed)
	_level_manager.time_remaining_changed.connect(_on_time_remaining_changed)

	_required_label.text = "Required: %d%%" % round(_level_manager.level_data.required_percentage * 100.0)
	_on_counts_changed(0, 0, 0, _level_manager.level_data.total_lemmings)
	_on_time_remaining_changed(_level_manager.time_remaining)


func _on_counts_changed(saved_count: int, lost_count: int, spawned_count: int, total_count: int) -> void:
	var out_count := spawned_count - saved_count - lost_count
	_lemmings_label.text = "Out: %d  Saved: %d  Lost: %d  Total: %d" % [out_count, saved_count, lost_count, total_count]


func _on_time_remaining_changed(seconds_remaining: float) -> void:
	var total_seconds := int(ceil(seconds_remaining))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	_time_label.text = "%02d:%02d" % [minutes, seconds]
