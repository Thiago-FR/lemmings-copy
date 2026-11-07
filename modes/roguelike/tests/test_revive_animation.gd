extends Node
## The phoenix feather card shown as an animation, not a message. Run via:
##   godot --headless res://modes/roguelike/tests/test_revive_animation.tscn
## Exits 0 when every check passes, 1 otherwise.
##
## Checked: picking the feather card with a lemming lost plays the revive
## animation, the lost lemming is back in the troop, and the shop opens once
## the animation is over; picking it with nobody lost plays no animation.

const RUN_SCENE := preload("res://modes/roguelike/scenes/roguelike_run.tscn")
const PROFILE_PATH := "user://test_revive_animation.cfg"
const ANIMATION_TIMEOUT_SECONDS := 6.0

var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var run: RoguelikeRunController = RUN_SCENE.instantiate()
	run.profile_path = PROFILE_PATH
	run.use_save_slots = false
	add_child(run)
	await get_tree().process_frame
	run._on_character_chosen(RoguelikeCharacters.WIZARD)
	await get_tree().process_frame
	run.state.fallen.append(RoguelikeCharacters.WIZARD)
	var troop_before := run.state.troop.size()

	run._on_card_chosen(RoguelikeCard.make(RoguelikeCard.Kind.REVIVE))
	await get_tree().process_frame
	var animation := run.find_children("*", "CanvasLayer", false, false).filter(func(node: Node) -> bool: return node is RoguelikeReviveAnimation)
	_expect(animation.size() == 1, "picking the feather with a lemming lost played no revive animation")
	_expect(run.state.troop.size() == troop_before + 1, "the lost lemming is not back in the troop")
	var waited := 0.0
	while _screen_title(run) != "Loja" and waited < ANIMATION_TIMEOUT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_expect(_screen_title(run) == "Loja", "the shop did not open after the animation (%s)" % _screen_title(run))

	run._on_card_chosen(RoguelikeCard.make(RoguelikeCard.Kind.REVIVE))
	await get_tree().process_frame
	var none := run.find_children("*", "CanvasLayer", false, false).filter(func(node: Node) -> bool: return node is RoguelikeReviveAnimation and not node.is_queued_for_deletion())
	_expect(none.is_empty(), "a feather with nobody lost played the animation")

	remove_child(run)
	run.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	if _failures.is_empty():
		print("Revive animation: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("  FAIL: %s" % failure)
	print("Revive animation: FAIL")
	get_tree().quit(1)


func _screen_title(run: Node) -> String:
	for child in run.get_children():
		if child is RoguelikeOverlayScreen and not child.is_queued_for_deletion():
			return ((child as RoguelikeOverlayScreen).content.get_child(0) as Label).text
	return "(no screen)"


func _expect(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)
