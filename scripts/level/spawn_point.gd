class_name SpawnPoint
extends Marker2D
## Level entrance: releases a fixed number of lemmings, one every
## spawn_interval seconds, at its own position.
##
## Self-contained: it knows nothing about the level, its counters or its
## rules. Whoever owns the level calls start() with how many to release and
## how often, and listens to lemming_spawned / all_lemmings_spawned. What it
## spawns, where the spawned nodes are parented and the label shown above it
## are all exported, so the same scene works for any spawnable character.

signal lemming_spawned(lemming: LemmingController)
signal all_lemmings_spawned

## Scene instantiated for every spawn.
@export var lemming_scene: PackedScene = preload("res://scenes/characters/lemming.tscn")
## Node the spawned lemmings are added to. Empty means this node's parent.
@export var spawn_container: NodePath
## Text shown above the entrance.
@export var label_text: String = "ENTRADA"

## The hatch art (docs/art_pipeline.md, "Entrada e saída"): pixel (24, 32),
## the middle of the hatch's bottom edge, sits on the origin, where the
## lemmings appear and drop out.
const ART_OFFSET := Vector2(-24, -32)
const ART_ANIMATIONS := {
	&"open": ["entrance_open", 5, 10.0, false],
	&"idle": ["entrance_idle", 4, 6.0, true],
}

@onready var _spawn_timer: Timer = $SpawnTimer
@onready var _label: Label = $Label

var _total_lemmings: int = 0
var _spawned_count: int = 0


func _ready() -> void:
	add_to_group("spawn_points")
	_label.text = label_text
	_spawn_timer.timeout.connect(_spawn_lemming)
	_add_art()


## The hatch opens once, then idles open. Behind the lemmings dropping out.
func _add_art() -> void:
	var art := PortalSprite.make(ART_ANIMATIONS, ART_OFFSET)
	art.z_index = -1
	add_child(art)
	art.animation_finished.connect(func() -> void: art.play(&"idle"))
	art.play(&"open")


func start(spawn_interval: float, total_lemmings: int) -> void:
	assert(total_lemmings > 0, "SpawnPoint requires a positive total_lemmings")
	assert(spawn_interval > 0.0, "SpawnPoint requires a positive spawn_interval")
	_total_lemmings = total_lemmings
	_spawned_count = 0
	_spawn_timer.wait_time = spawn_interval
	_spawn_lemming()
	_spawn_timer.start()


## Releases no more lemmings (the level was ended early).
func stop() -> void:
	_spawn_timer.stop()
	_total_lemmings = _spawned_count


func get_spawned_count() -> int:
	return _spawned_count


func _spawn_lemming() -> void:
	if _spawned_count >= _total_lemmings:
		_spawn_timer.stop()
		return

	var lemming: LemmingController = lemming_scene.instantiate()
	# Positioned before entering the tree: the lemming measures fall distance
	# from where it first appears, so moving it afterwards reads as a fall.
	lemming.global_position = global_position
	_get_container().add_child(lemming)
	_spawned_count += 1
	lemming_spawned.emit(lemming)

	if _spawned_count >= _total_lemmings:
		_spawn_timer.stop()
		all_lemmings_spawned.emit()


func _get_container() -> Node:
	if spawn_container.is_empty():
		return get_parent()
	return get_node(spawn_container)
