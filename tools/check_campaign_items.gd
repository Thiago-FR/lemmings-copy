extends Node
## Lists every item of the campaign levels that has no floor under it or
## sits inside a block, checked on the real terrain (ramps and planks
## included). Prints nothing when all is well. Run via:
##   godot --headless --path . res://tools/check_campaign_items.tscn
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	get_tree().current_scene = null
	for level in range(1, 34):
		var data := Campaign.load_level_data(level - 1)
		if data.items.is_empty():
			continue
		LevelLoader.load_level(data)
		for i in 5:
			await get_tree().process_frame
		get_tree().paused = true
		var terrain := get_tree().get_first_node_in_group("terrain") as TerrainDestructible
		for node in get_tree().get_nodes_in_group("item_pickups"):
			var pickup := node as ItemPickup
			var floor_point := pickup.global_position + Vector2.DOWN * (ItemPickup.SURFACE_HEIGHT + 2)
			var body_point := pickup.global_position
			var has_floor := terrain.is_solid_at(floor_point)
			var inside := terrain.is_solid_at(body_point) or terrain.is_solid_at(pickup.global_position + Vector2.DOWN * (ItemPickup.SURFACE_HEIGHT - 2))
			if not has_floor or inside:
				print("%02d %s at (%d,%d): %s" % [level, pickup.spec.describe(), pickup.spec.column, pickup.spec.row, "INSIDE" if inside else "NO FLOOR"])
		get_tree().paused = false
	get_tree().quit()
