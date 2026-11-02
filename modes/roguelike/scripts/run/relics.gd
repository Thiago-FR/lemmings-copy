class_name RoguelikeRelics
extends RefCounted
## Run-wide upgrades won from cards, each with a level from 1 to MAX_LEVEL:
## taking the same relic again raises its level and its effect (the user's
## rule: the same card can be taken again to grow its bonus). A relic at
## MAX_LEVEL is no longer offered.
##
## Tool upgrades work by registering tuned copies of the tool templates with
## SkillManager (the core's own way of retuning a tool), so they apply to
## every lemming. SkillManager is global, so the run keeps the original
## templates and puts them back when it ends (restore_templates), and the
## normal levels never see an upgraded tool. The other relics are read
## where they act: the stage session (parachutes, walking speed, extra
## charges per item, time), the run state (coins, bar slots).

const MAX_LEVEL := 3

const SHARP_BLADES := &"sharp_blades"
const LONG_BRIDGE := &"long_bridge"
const LONG_LADDERS := &"long_ladders"
const SHORT_FUSE := &"short_fuse"
const EXTRA_POCKET := &"extra_pocket"
const SPARE_PARACHUTE := &"spare_parachute"
const COLLECTOR := &"collector"
const GREED := &"greed"
const QUICK_STEP := &"quick_step"
const HOURGLASS := &"hourglass"

## Effect per level (multiplied by the relic's level).
const DIG_SPEED_PER_LEVEL := 0.25
const BRIDGE_PIECES_PER_LEVEL := 3
const LADDER_PIECES_PER_LEVEL := 2
const FUSE_SECONDS_CUT_PER_LEVEL := 0.5
const WALK_SPEED_PER_LEVEL := 0.15
const SECONDS_PER_LEVEL := 20
## Spare parachute: how many of the first lemmings of a stage get one, by
## level; at the top level, all of them.
const PARACHUTES_BY_LEVEL := [0, 1, 2, 999]

## Title, icon (UiStyle) and the effect at each level, short: the cards and
## the side bar show it.
const DEFINITIONS := {
	SHARP_BLADES: {"title": "Lâminas afiadas", "icon": "digger", "levels": ["Cavam 25% mais rápido.", "Cavam 50% mais rápido.", "Cavam 75% mais rápido."]},
	LONG_BRIDGE: {"title": "Ponte longa", "icon": "bridge", "levels": ["+3 peças na ponte.", "+6 peças na ponte.", "+9 peças na ponte."]},
	LONG_LADDERS: {"title": "Escada comprida", "icon": "ladder_vertical", "levels": ["+2 peças na escada vertical.", "+4 peças na escada vertical.", "+6 peças na escada vertical."]},
	SHORT_FUSE: {"title": "Pavio curto", "icon": "dynamite", "levels": ["Explosivos em 2,5 s.", "Explosivos em 2 s.", "Explosivos em 1,5 s."]},
	EXTRA_POCKET: {"title": "Bolso extra", "icon": "block", "levels": ["+1 espaço na barra.", "+2 espaços na barra.", "+3 espaços na barra."]},
	SPARE_PARACHUTE: {"title": "Paraquedas reserva", "icon": "floater", "levels": ["O 1º boneco sai de paraquedas.", "Os 2 primeiros saem de paraquedas.", "Todos saem de paraquedas."]},
	COLLECTOR: {"title": "Coletor", "icon": "editor_counts", "levels": ["Cada item de ferramenta dá +1.", "Cada item de ferramenta dá +2.", "Cada item de ferramenta dá +3."]},
	GREED: {"title": "Ganância", "icon": "hud_coin", "levels": ["+1 moeda por salvo e em cada moeda do mapa.", "+2 moedas por salvo e em cada moeda do mapa.", "+3 moedas por salvo e em cada moeda do mapa."]},
	QUICK_STEP: {"title": "Passo acelerado", "icon": "hud_out", "levels": ["Andam 15% mais rápido.", "Andam 30% mais rápido.", "Andam 45% mais rápido."]},
	HOURGLASS: {"title": "Ampulheta", "icon": "hud_clock", "levels": ["+20 s em toda fase.", "+40 s em toda fase.", "+60 s em toda fase."]},
}

## Copies of every template as they were before the run touched them.
var _original_templates: Dictionary = {}


static func get_title(relic_id: StringName) -> String:
	return DEFINITIONS[relic_id].title


## The title with the level in roman numerals ("Ponte longa II").
static func get_title_at(relic_id: StringName, level: int) -> String:
	return "%s %s" % [get_title(relic_id), roman(level)]


## What the relic does at a level (1 to MAX_LEVEL).
static func get_effect(relic_id: StringName, level: int) -> String:
	var levels: Array = DEFINITIONS[relic_id].levels
	return levels[clampi(level, 1, MAX_LEVEL) - 1]


## What it does at level 1, for places that do not know a level.
static func get_description(relic_id: StringName) -> String:
	return get_effect(relic_id, 1)


static func get_icon(relic_id: StringName) -> String:
	return DEFINITIONS[relic_id].icon


static func roman(level: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(level, 0, 5)]


## Remembers the current templates. Call once when the run starts.
func save_templates() -> void:
	_original_templates.clear()
	for skill_id in SkillManager.get_skill_ids():
		_original_templates[skill_id] = SkillManager.create_skill(skill_id)


## Registers the templates the owned relics call for, starting from the
## originals each time so upgrades never stack twice. levels: relic id ->
## level (RoguelikeRunState.relic_levels).
func apply_templates(levels: Dictionary) -> void:
	assert(not _original_templates.is_empty(), "save_templates() must run before apply_templates()")
	for skill_id in _original_templates:
		var template: SkillBase = _original_templates[skill_id].create_instance()
		_upgrade(template, levels)
		SkillManager.register_skill(template)


func restore_templates() -> void:
	for skill_id in _original_templates:
		SkillManager.register_skill(_original_templates[skill_id])


func _upgrade(template: SkillBase, levels: Dictionary) -> void:
	var blades := int(levels.get(SHARP_BLADES, 0))
	if blades > 0:
		var factor := 1.0 + DIG_SPEED_PER_LEVEL * blades
		if template is SkillDigger:
			(template as SkillDigger).dig_speed *= factor
		elif template is SkillSideDigger:
			(template as SkillSideDigger).dig_speed *= factor
	var bridge := int(levels.get(LONG_BRIDGE, 0))
	if bridge > 0 and template is SkillBridge:
		(template as SkillBridge).max_pieces += BRIDGE_PIECES_PER_LEVEL * bridge
	# Only the vertical ladder: it builds just as many pieces as the wall needs,
	# while a longer diagonal ladder overshoots a platform and drops the
	# lemming from higher up (see RoguelikeEngineerTrait).
	var ladders := int(levels.get(LONG_LADDERS, 0))
	if ladders > 0 and template is SkillLadderVertical:
		(template as SkillLadderVertical).max_pieces += LADDER_PIECES_PER_LEVEL * ladders
	var fuse := int(levels.get(SHORT_FUSE, 0))
	if fuse > 0 and template is SkillExplosive:
		(template as SkillExplosive).fuse_seconds -= FUSE_SECONDS_CUT_PER_LEVEL * fuse
