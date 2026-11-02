class_name RoguelikeCharacterTrait
extends Node2D
## What makes a lemming one of the roguelike's characters: its look (its
## own sprites, every animation recoloured with an accessory, from
## tools/build_character_variants.py) and its special ability. Added
## as a child of a spawned LemmingController; the lemming itself does not
## know about it. Abilities work through the lemming's generic hooks
## (skill_about_to_apply, max_safe_fall_height, has_floater_skill) and
## through what RoguelikeStageSession asks the trait.
##
## Each character is a subclass overriding the hooks it needs.

## One SpriteFrames per character, with the same animations as the
## lemming's own.
const SPRITE_FRAMES_PATH := "res://resources/sprite_frames/%s.tres"

var character_id: StringName = &""
var colour: Color = Color.WHITE
var lemming: LemmingController = null


## Called once, right after the trait is added to its lemming.
func attach(target: LemmingController) -> void:
	lemming = target
	lemming.skill_about_to_apply.connect(_on_skill_about_to_apply)
	_wear_own_sprites()
	_on_attached()


## Swaps the lemming's sprites for this character's, keeping whatever
## animation is playing. They replaced a tint and a gem over the head, which
## the user found unclear.
func _wear_own_sprites() -> void:
	var path := SPRITE_FRAMES_PATH % character_id
	if not ResourceLoader.exists(path):
		return
	var sprite := lemming.animated_sprite
	var playing := sprite.animation
	sprite.sprite_frames = load(path)
	if sprite.sprite_frames.has_animation(playing):
		sprite.play(playing)


# --- Hooks for the characters -----------------------------------------------

func _on_attached() -> void:
	pass


## The lemming's own copy of a tool, before it takes effect: tune it here.
func _on_skill_about_to_apply(_skill: SkillBase) -> void:
	pass


## Extra charges this lemming adds to every tool item it collects.
func get_pickup_bonus() -> int:
	return 0


## Whether clicking this lemming with no usable tool selected does
## something of its own (see RoguelikeTinkererTrait).
func can_use_own_ability() -> bool:
	return false


func use_own_ability() -> bool:
	return false
