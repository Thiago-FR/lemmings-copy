class_name DigDropper
extends Node
## Items that turn up where a block breaks (LevelData.dig_drops). Listens to
## every terrain's cell_broken, rolls the level's DigDropTable and lays what
## comes out in the broken cell, from where it falls to the floor. Whoever
## hands items out in the level (ItemCollector, a mode's own session)
## connects to item_dropped to take the pickup like any other, and sets
## `inventory` so tool charges come from what is in the bar.

signal item_dropped(pickup: ItemPickup)

## Tools a dropped tool charge can be of; without it no tool charges drop.
var inventory: ToolInventory = null

var _level: Node
var _table: DigDropTable
var _rng := RandomNumberGenerator.new()


func _init(level: Node, table: DigDropTable) -> void:
	assert(level != null and table != null, "A dig dropper needs its level and a table")
	_level = level
	_table = table
	name = "DigDropper"
	_rng.randomize()


func _ready() -> void:
	for terrain in get_tree().get_nodes_in_group("terrain"):
		(terrain as TerrainDestructible).cell_broken.connect(_on_cell_broken.bind(terrain))


## For tests and replays: the same seed drops the same items.
func set_seed(value: int) -> void:
	_rng.seed = value


func _on_cell_broken(cell: Vector2i, material: TerrainDestructible.TerrainMaterial,
		breaker: StringName, terrain: TerrainDestructible) -> void:
	var bar_tools: Array[String] = inventory.get_tool_ids() if inventory != null else []
	var spec := _table.roll(_rng, material, bar_tools, breaker)
	if spec == null:
		return
	spec.column = cell.x
	spec.row = cell.y + 1
	var pickup := ItemPickup.make(spec)
	pickup.position = terrain.to_global(terrain.map_to_local(cell))
	pickup.falls = true
	item_dropped.emit(pickup)
	_level.add_child.call_deferred(pickup)
	AudioManager.play_sound(&"item_found")
