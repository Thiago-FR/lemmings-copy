class_name RoguelikeProfile
extends RefCounted
## What the roguelike keeps from one run to the next: the coin vault,
## which characters are unlocked and what the player has discovered for the
## compendium (entry ids from RoguelikeDiscovery). Coins left at the end of a run go into the
## vault (deposit); the character screen spends them to unlock characters
## (buy). Saved in its own file, apart from the game's settings, so deleting
## the mode's save never touches the volumes or the display.

const DEFAULT_PATH := "user://roguelike_profile.cfg"
const SECTION := "profile"

var vault_coins := 0
var unlocked: Array[StringName] = []
var discovered: Array[String] = []
## The best runs, best first: {"score", "character", "stage" (reached, 1 to
## stage_count()), "won", "date" (YYYY-MM-DD)}. At most RANKING_SIZE.
var ranking: Array[Dictionary] = []

const RANKING_SIZE := 10
var _path := DEFAULT_PATH


## The profile on disk, or a fresh one (only the starter unlocked) if there
## is none yet. path is for tests, which must not touch the player's save.
static func load_from(path: String = DEFAULT_PATH) -> RoguelikeProfile:
	var profile := RoguelikeProfile.new()
	profile._path = path
	var file := ConfigFile.new()
	if file.load(path) == OK:
		profile.vault_coins = int(file.get_value(SECTION, "vault_coins", 0))
		for entry in file.get_value(SECTION, "ranking", []):
			if entry is Dictionary:
				profile.ranking.append(entry)
		for entry in file.get_value(SECTION, "discovered", []):
			if not profile.discovered.has(String(entry)):
				profile.discovered.append(String(entry))
		for character in file.get_value(SECTION, "unlocked", []):
			var id := StringName(character)
			if RoguelikeCharacters.DEFINITIONS.has(id) and not profile.unlocked.has(id):
				profile.unlocked.append(id)
	if not profile.unlocked.has(RoguelikeCharacters.STARTER):
		profile.unlocked.push_front(RoguelikeCharacters.STARTER)
	return profile


func save() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "vault_coins", vault_coins)
	var names: Array[String] = []
	for character in unlocked:
		names.append(String(character))
	file.set_value(SECTION, "unlocked", names)
	file.set_value(SECTION, "discovered", discovered)
	file.set_value(SECTION, "ranking", ranking)
	file.save(_path)


func is_unlocked(character: StringName) -> bool:
	return unlocked.has(character)


func can_buy(character: StringName) -> bool:
	return not is_unlocked(character) and vault_coins >= RoguelikeCharacters.get_price(character)


## Unlocks a character for its price. False, and nothing spent, if it is
## already unlocked or the vault cannot pay.
func buy(character: StringName) -> bool:
	if not can_buy(character):
		return false
	vault_coins -= RoguelikeCharacters.get_price(character)
	unlocked.append(character)
	save()
	return true


## The coins left at the end of a run.
func deposit(coins: int) -> void:
	assert(coins >= 0, "Cannot deposit a negative amount")
	vault_coins += coins
	save()


## Records a finished run in the ranking, kept best first and cut to
## RANKING_SIZE. Returns its position (0 is the best), or -1 when it did not
## make it. Ties go below the runs already there.
func record_run(score: int, character: StringName, stage: int, won: bool) -> int:
	var entry := {
		"score": score,
		"character": String(character),
		"stage": stage,
		"won": won,
		"date": Time.get_date_string_from_system(),
	}
	var position := ranking.size()
	for index in ranking.size():
		if score > int(ranking[index].score):
			position = index
			break
	if position >= RANKING_SIZE:
		return -1
	ranking.insert(position, entry)
	if ranking.size() > RANKING_SIZE:
		ranking.resize(RANKING_SIZE)
	save()
	return position


## Whether the compendium shows an entry: discovered, or, for a character,
## unlocked.
func is_discovered(entry_id: String) -> bool:
	if discovered.has(entry_id):
		return true
	for character in unlocked:
		if entry_id == RoguelikeDiscovery.character(character):
			return true
	return false


## Records a discovery, saved at once (they are few, and a run can end by
## closing the game). Returns whether it was new.
func discover(entry_id: String) -> bool:
	if is_discovered(entry_id):
		return false
	discovered.append(entry_id)
	save()
	return true


func discover_all(entry_ids: Array[String]) -> void:
	var added := false
	for entry_id in entry_ids:
		if not is_discovered(entry_id):
			discovered.append(entry_id)
			added = true
	if added:
		save()
