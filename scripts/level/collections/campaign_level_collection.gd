class_name CampaignLevelCollection
extends LevelCollection
## The campaign's 15 levels ("Fases"), through CampaignLevelStore (which
## keeps their scene and data files and their backups). Developer mode only.


func get_display_name() -> String:
	return "Fases"


func get_icon_id() -> String:
	return "campaign"


func get_slot_count() -> int:
	return Campaign.LEVEL_COUNT


func get_slot_name(index: int) -> String:
	return Campaign.load_level_data(index).level_name


func read(index: int) -> Dictionary:
	return CampaignLevelStore.read(index)


func write(index: int, drawing: Dictionary) -> String:
	return CampaignLevelStore.write(index, drawing)


func list_backups(index: int) -> Array[Dictionary]:
	return LevelCollection.keep_newest_backups(CampaignLevelStore.list_backups(index))


func read_backup(folder: String) -> Dictionary:
	return CampaignLevelStore.read_backup(folder)
