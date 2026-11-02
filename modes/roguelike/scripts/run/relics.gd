class_name RoguelikeRelics
extends RefCounted
## Run-wide upgrades won from cards. Tool upgrades work by registering tuned
## copies of the tool templates with SkillManager (the core's own way of
## retuning a tool), so they apply to every lemming. SkillManager is global,
## so the run keeps the original templates and puts them back when it ends
## (restore_templates), and the normal levels never see an upgraded tool.

const SHARP_BLADES := &"sharp_blades"
const LONG_BRIDGE := &"long_bridge"
const LONG_LADDERS := &"long_ladders"
const SHORT_FUSE := &"short_fuse"
const EXTRA_POCKET := &"extra_pocket"
const SPARE_PARACHUTE := &"spare_parachute"

const DIG_SPEED_FACTOR := 1.5
const BRIDGE_EXTRA_PIECES := 6
const LADDER_EXTRA_PIECES := 4
const SHORT_FUSE_SECONDS := 2.0

const DEFINITIONS := {
	SHARP_BLADES: {"title": "Lâminas afiadas", "description": "Pá, Picareta e Britadeira cavam 50% mais rápido.", "icon": "digger"},
	LONG_BRIDGE: {"title": "Ponte longa", "description": "Toda ponte tem 6 peças a mais.", "icon": "bridge"},
	LONG_LADDERS: {"title": "Escada comprida", "description": "A Escada vertical tem 4 peças a mais (paredões mais altos).", "icon": "ladder_vertical"},
	SHORT_FUSE: {"title": "Pavio curto", "description": "Dinamite e TNT explodem em 2s em vez de 3s.", "icon": "dynamite"},
	EXTRA_POCKET: {"title": "Bolso extra", "description": "+1 espaço na barra de ferramentas.", "icon": "block"},
	SPARE_PARACHUTE: {"title": "Paraquedas reserva", "description": "O primeiro boneco de cada fase já sai com paraquedas.", "icon": "floater"},
}

## Copies of every template as they were before the run touched them.
var _original_templates: Dictionary = {}


static func get_title(relic_id: StringName) -> String:
	return DEFINITIONS[relic_id].title


static func get_description(relic_id: StringName) -> String:
	return DEFINITIONS[relic_id].description


static func get_icon(relic_id: StringName) -> String:
	return DEFINITIONS[relic_id].icon


## Remembers the current templates. Call once when the run starts.
func save_templates() -> void:
	_original_templates.clear()
	for skill_id in SkillManager.get_skill_ids():
		_original_templates[skill_id] = SkillManager.create_skill(skill_id)


## Registers the templates the owned relics call for, starting from the
## originals each time so upgrades never stack twice.
func apply_templates(owned: Array[StringName]) -> void:
	assert(not _original_templates.is_empty(), "save_templates() must run before apply_templates()")
	for skill_id in _original_templates:
		var template: SkillBase = _original_templates[skill_id].create_instance()
		_upgrade(template, owned)
		SkillManager.register_skill(template)


func restore_templates() -> void:
	for skill_id in _original_templates:
		SkillManager.register_skill(_original_templates[skill_id])


func _upgrade(template: SkillBase, owned: Array[StringName]) -> void:
	if owned.has(SHARP_BLADES):
		if template is SkillDigger:
			(template as SkillDigger).dig_speed *= DIG_SPEED_FACTOR
		elif template is SkillSideDigger:
			(template as SkillSideDigger).dig_speed *= DIG_SPEED_FACTOR
	if owned.has(LONG_BRIDGE) and template is SkillBridge:
		(template as SkillBridge).max_pieces += BRIDGE_EXTRA_PIECES
	# Only the vertical ladder: it builds just as many pieces as the wall needs,
	# while a longer diagonal ladder overshoots a platform and drops the
	# lemming from higher up (see RoguelikeEngineerTrait).
	if owned.has(LONG_LADDERS) and template is SkillLadderVertical:
		(template as SkillLadderVertical).max_pieces += LADDER_EXTRA_PIECES
	if owned.has(SHORT_FUSE) and template is SkillExplosive:
		(template as SkillExplosive).fuse_seconds = SHORT_FUSE_SECONDS
