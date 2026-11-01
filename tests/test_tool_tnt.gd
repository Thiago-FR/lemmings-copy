extends "res://tests/explosive_tool_test.gd"
## Automated check of the TNT (SkillTnt). Run via:
##   godot --headless res://tests/test_tool_tnt.tscn
## See explosive_tool_test.gd for the layout and what is checked. The blast
## is the 5x5 square around the charge's cell without its four corners, so
## it goes through both floor rows under the charge.


func _get_test_name() -> String:
	return "TNT"


func _make_tool() -> SkillExplosive:
	return SkillTnt.new()


func _expected_offsets() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if absi(dx) == 2 and absi(dy) == 2:
				continue
			offsets.append(Vector2i(dx, dy))
	return offsets
