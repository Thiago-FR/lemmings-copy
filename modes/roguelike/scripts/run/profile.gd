class_name RoguelikeProfile
extends RefCounted
## What the roguelike keeps from one run to the next: the coin vault and
## which characters are unlocked. Coins left at the end of a run go into the
## vault (deposit); the character screen spends them to unlock characters
## (buy). Saved in its own file, apart from the game's settings, so deleting
## the mode's save never touches the volumes or the display.

const DEFAULT_PATH := "user://roguelike_profile.cfg"
const SECTION := "profile"

var vault_coins := 0
var unlocked: Array[StringName] = []
var _path := DEFAULT_PATH


## The profile on disk, or a fresh one (only the starter unlocked) if there
## is none yet. path is for tests, which must not touch the player's save.
static func load_from(path: String = DEFAULT_PATH) -> RoguelikeProfile:
	var profile := RoguelikeProfile.new()
	profile._path = path
	var file := ConfigFile.new()
	if file.load(path) == OK:
		profile.vault_coins = int(file.get_value(SECTION, "vault_coins", 0))
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
