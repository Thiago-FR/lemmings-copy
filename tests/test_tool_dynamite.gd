extends "res://tests/explosive_tool_test.gd"
## Automated check of the dynamite (SkillDynamite). Run via:
##   godot --headless res://tests/test_tool_dynamite.tscn
## See explosive_tool_test.gd for the layout and what is checked. The blast
## is the 3x3 square around the charge's cell.


func _get_test_name() -> String:
	return "Dynamite"


func _make_tool() -> SkillExplosive:
	return SkillDynamite.new()


func _expected_offsets() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			offsets.append(Vector2i(dx, dy))
	return offsets
