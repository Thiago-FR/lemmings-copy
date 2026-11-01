class_name SpawnPoint
extends Marker2D
## Spawns lemmings into the level at a fixed rate until total_lemmings have
## been created. LevelManager calls start() once the level's LevelData is known.

signal lemming_spawned(lemming: LemmingController)
signal all_lemmings_spawned

const LEMMING_SCENE: PackedScene = preload("res://scenes/characters/lemming.tscn")

@onready var _spawn_timer: Timer = $SpawnTimer

var _total_lemmings: int = 0
var _spawned_count: int = 0


func _ready() -> void:
	add_to_group("spawn_points")


func start(spawn_rate: float, total_lemmings: int) -> void:
	assert(total_lemmings > 0, "SpawnPoint requires a positive total_lemmings")
	_total_lemmings = total_lemmings
	_spawned_count = 0
	_spawn_timer.wait_time = spawn_rate
	_spawn_lemming()
	_spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	_spawn_lemming()


func _spawn_lemming() -> void:
	if _spawned_count >= _total_lemmings:
		_spawn_timer.stop()
		return

	var lemming: LemmingController = LEMMING_SCENE.instantiate()
	lemming.global_position = global_position
	get_parent().add_child(lemming)
	_spawned_count += 1
	lemming_spawned.emit(lemming)

	if _spawned_count >= _total_lemmings:
		_spawn_timer.stop()
		all_lemmings_spawned.emit()
