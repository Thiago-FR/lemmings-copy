class_name CampaignMenu
extends RefCounted
## The campaign's menu ("Fases"): a GameMenu wired to the campaign's saved
## games. A new or loaded game opens the level select on it; in a level
## the menu also goes back to the level select (ESCOLHER FASE).


## Opens the menu over the current screen. in_game: over a level.
static func open(tree: SceneTree, in_game: bool) -> GameMenu:
	Campaign.adopt_legacy_save()
	var menu := GameMenu.new(Campaign.SAVE_MODE, "Fases", in_game)
	menu.name = "CampaignMenu"
	if in_game:
		menu.add_button("Escolher fase", "star", GameManager.go_to_scene.bind(Campaign.SELECT_SCENE_PATH))
	menu.new_game_chosen.connect(_play)
	menu.load_chosen.connect(_play)
	menu.main_menu_requested.connect(GameManager.go_to_main_menu)
	tree.current_scene.add_child(menu)
	return menu


static func _play(slot: int) -> void:
	Campaign.use_save_slot(slot)
	GameManager.go_to_scene(Campaign.SELECT_SCENE_PATH)
