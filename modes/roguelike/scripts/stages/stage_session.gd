class_name RoguelikeStageSession
extends Node
## One stage of a run being played: builds the stage from its definition,
## releases the troop (each lemming becoming its character), keeps the
## run's tool bar and SkillManager's charges in step, applies the items
## the lemmings collect, and reports who got out when the stage ends.
##
## Everything goes through the core's own pieces and signals: LevelManager
## runs the level, SpawnPoint releases the lemmings, SkillManager hands out
## the tools. The session only listens and adds the roguelike's rules.

signal stage_finished(saved: Array[StringName], lost: Array[StringName])
signal sacrifice_armed_changed(armed: bool)

## Icons flying out of a picked-up item: at most this many, this far apart.
const MAX_POPS := 5
const POP_SPACING := 14.0
const EVICTED_TINT := Color(0.55, 0.55, 0.55, 1.0)

const SPAWN_INTERVAL_SECONDS := 1.5
## A new compendium discovery: the book pops up a little above the spot.
const DISCOVERY_ICON := "compendium"
const DISCOVERY_POP_OFFSET := Vector2(0, -28)

var state: RoguelikeRunState = null
## Optional: the run's relics, applied to the tool templates before the
## stage starts.
var relics: RoguelikeRelics = null
## Leave the HUD and tool bar out (tests that do not need them).
var show_ui := true
## While true, clicking a lemming sacrifices it (set_sacrifice_armed).
var sacrifice_armed := false
## Optional: where discoveries for the compendium are recorded (things
## picked up, tools and the ability used). Tests leave it out.
var profile: RoguelikeProfile = null
## The run character's ability in this stage: its charges, and whether it
## is armed (set_ability_armed). Made in _ready.
var ability_slot: RoguelikeAbilitySlot = null

var level_manager: LevelManager = null
var builder := RoguelikeStageBuilder.new()
var definition: RoguelikeStageDefinition = null

## Character id of each lemming still in the stage, by lemming.
var _characters: Dictionary = {}
var _spawned_count := 0
var _saved: Array[StringName] = []
var _lost: Array[StringName] = []
var _finished := false


func _ready() -> void:
	assert(state != null and not state.troop.is_empty(), "A stage session needs a run state with a troop")
	definition = state.get_stage_definition()
	state.prefetch_next_stage()
	if relics != null:
		relics.apply_templates(state.relic_levels)

	ability_slot = RoguelikeAbilitySlot.make(RoguelikeCharacters.get_special(state.character_id), _starting_ability_charges())
	GameManager.current_level_data = _make_level_data()
	level_manager = builder.build(definition)
	# Connected before the level enters the tree: LevelManager releases the
	# first lemming in its own _ready, and each lemming must become its
	# character (and get the click handler below) before anything else.
	for spawn_point in _children_of_type(SpawnPoint):
		spawn_point.lemming_spawned.connect(_on_lemming_spawned)
	# Also before LevelManager: the last lemming out ends the level from
	# LevelManager's handler, and it must already count as saved by then.
	for exit_point in _children_of_type(ExitPoint):
		exit_point.lemming_exited.connect(func(lemming: LemmingController) -> void: _on_lemming_resolved(lemming, true))
	for pickup in _children_of_type(RoguelikePickup):
		pickup.collected.connect(_on_pickup_collected)
	level_manager.level_completed.connect(_on_level_ended)
	level_manager.level_failed.connect(_on_level_ended)
	if show_ui:
		level_manager.add_child(RoguelikeRunHud.new(state, definition, self))
		level_manager.add_child(RoguelikeToolBar.new(state.inventory, self))
		level_manager.add_child(RoguelikeRelicBar.new(state))

	SkillManager.skill_assigned.connect(_on_skill_assigned)
	SkillManager.skill_selected.connect(_on_skill_selected)
	SkillManager.skill_refunded.connect(_on_skill_refunded)
	state.inventory.changed.connect(_sync_charges)
	add_child(level_manager)


## The level's direct children of a script class (find_children only knows
## built-in classes).
func _children_of_type(type: Variant) -> Array:
	return level_manager.get_children().filter(func(child: Node) -> bool: return is_instance_of(child, type))


func _exit_tree() -> void:
	# A stage being made on another thread must be done before the game
	# can close (it crashed at exit otherwise).
	RoguelikeStageFactory.finish_prefetches()
	if SkillManager.skill_assigned.is_connected(_on_skill_assigned):
		SkillManager.skill_assigned.disconnect(_on_skill_assigned)
	if SkillManager.skill_selected.is_connected(_on_skill_selected):
		SkillManager.skill_selected.disconnect(_on_skill_selected)
	if SkillManager.skill_refunded.is_connected(_on_skill_refunded):
		SkillManager.skill_refunded.disconnect(_on_skill_refunded)
	if state.inventory.changed.is_connected(_sync_charges):
		state.inventory.changed.disconnect(_sync_charges)


func _make_level_data() -> LevelData:
	var level_data := LevelData.new()
	level_data.level_name = definition.stage_name
	level_data.instructions = ""
	level_data.spawn_rate = SPAWN_INTERVAL_SECONDS
	level_data.total_lemmings = state.troop.size()
	# The run, not the level, decides what counts as success: any survivor
	# carries on.
	level_data.required_percentage = 0.0
	# Chosen with the terrain: open sky on the shallow stages, a cave deeper.
	level_data.environment_kind = definition.get_environment_kind()
	level_data.time_limit_seconds = definition.time_limit_seconds + RoguelikeRelics.SECONDS_PER_LEVEL * state.get_relic_level(RoguelikeRelics.HOURGLASS)
	level_data.available_skills = SkillManager.get_skill_ids()
	level_data.skill_counts = state.inventory.to_counts()
	return level_data


## The ability's own charges, plus the relic's.
func _starting_ability_charges() -> int:
	var special := RoguelikeCharacters.get_special(state.character_id)
	return RoguelikeAbilities.get_base_charges(special) + RoguelikeRelics.ABILITY_CHARGES_PER_LEVEL * state.get_relic_level(RoguelikeRelics.ABILITY_CHARGES)


## Records discoveries; a new one pops the compendium's book over where it
## happened (an animation, not a message).
func _discover(entry_ids: Array[String], where: Vector2) -> void:
	if profile == null:
		return
	var fresh := entry_ids.filter(func(entry_id: String) -> bool: return not profile.is_discovered(entry_id))
	if fresh.is_empty():
		return
	profile.discover_all(entry_ids)
	RoguelikeIconPop.spawn(level_manager, where + DISCOVERY_POP_OFFSET, DISCOVERY_ICON)


func _sync_charges() -> void:
	var counts := state.inventory.to_counts()
	for skill_id in SkillManager.get_skill_ids():
		SkillManager.set_remaining_count(skill_id, int(counts.get(skill_id, 0)))


func _on_lemming_spawned(lemming: LemmingController) -> void:
	var character: StringName = state.troop[_spawned_count]
	_spawned_count += 1
	_characters[lemming] = character
	RoguelikeCharacters.apply_to(lemming, character)
	if _spawned_count <= RoguelikeRelics.PARACHUTES_BY_LEVEL[state.get_relic_level(RoguelikeRelics.SPARE_PARACHUTE)]:
		lemming.has_floater_skill = true
	lemming.walk_speed *= 1.0 + RoguelikeRelics.WALK_SPEED_PER_LEVEL * state.get_relic_level(RoguelikeRelics.QUICK_STEP)
	lemming.clicked.connect(_on_lemming_clicked)
	lemming.died.connect(func(cause: LemmingController.DeathCause) -> void: _on_lemming_died(lemming, cause))


func _on_lemming_died(lemming: LemmingController, cause: LemmingController.DeathCause) -> void:
	_on_lemming_resolved(lemming, false)
	if cause == LemmingController.DeathCause.SACRIFICE:
		state.coins += RoguelikeRunState.COINS_PER_SACRIFICED
		_pop_icons(lemming.global_position, "hud_coin", RoguelikeRunState.COINS_PER_SACRIFICED)


func _on_lemming_resolved(lemming: LemmingController, was_saved: bool) -> void:
	if not _characters.has(lemming):
		return
	var character: StringName = _characters[lemming]
	_characters.erase(lemming)
	if was_saved:
		_saved.append(character)
	else:
		_lost.append(character)


## Runs before SkillManager's own click handler (connected first, see
## _ready). Armed, the sacrifice or the ability takes the click; they let go
## of the selected tool when armed, so SkillManager then does nothing.
func _on_lemming_clicked(lemming: LemmingController) -> void:
	if sacrifice_armed:
		sacrifice(lemming)
	elif ability_slot.armed and ability_slot.use_on(lemming):
		_discover([RoguelikeDiscovery.ability(ability_slot.get_ability_id())], lemming.get_body_rect().get_center())


## Sacrifices a lemming still in the stage: for one stuck where it can never
## get out, so the player does not have to wait for the clock. Unlimited.
func sacrifice(lemming: LemmingController) -> void:
	if not _characters.has(lemming):
		return
	lemming.die(LemmingController.DeathCause.SACRIFICE)


## Arms or disarms the sacrifice: while armed, clicking a lemming sacrifices
## it. Arming lets go of the selected tool, so the click is not also a tool
## use; selecting a tool disarms it (_on_skill_selected).
func set_sacrifice_armed(armed: bool) -> void:
	if armed == sacrifice_armed:
		return
	sacrifice_armed = armed
	if armed:
		SkillManager.selected_skill_id = ""
		ability_slot.set_armed(false)
	sacrifice_armed_changed.emit(armed)


## Arms or disarms the ability (its slot in the tool bar): while armed,
## clicking a lemming uses it on that lemming. Like the sacrifice, arming
## lets go of the selected tool and disarms the sacrifice; selecting a tool
## disarms it. It cannot be armed with no charge left.
func set_ability_armed(armed: bool) -> void:
	if armed:
		set_sacrifice_armed(false)
		SkillManager.selected_skill_id = ""
	ability_slot.set_armed(armed)


func _on_skill_selected(skill_id: String) -> void:
	if skill_id != "":
		set_sacrifice_armed(false)
		ability_slot.set_armed(false)


## Ends the stage now: whoever is still in it is sacrificed (see
## LevelManager.end_now) and the ones not released yet are lost.
func end_stage_now() -> void:
	set_sacrifice_armed(false)
	level_manager.end_now()


## A tool a lemming dropped unused for a newer one goes back to the bar.
func _on_skill_refunded(skill_id: String) -> void:
	state.inventory.add_charges(skill_id, 1)


func _on_skill_assigned(lemming: LemmingController, skill_id: String) -> void:
	state.inventory.spend(skill_id)
	_discover([RoguelikeDiscovery.tool(skill_id)], lemming.get_body_rect().get_center())


## What was picked up flies out of the item as icons, one per charge or coin
## (up to MAX_POPS): the user wants animation, not text messages.
func _on_pickup_collected(pickup: RoguelikePickup, lemming: LemmingController) -> void:
	var spec := pickup.spec
	var where := pickup.global_position
	_discover(RoguelikeDiscovery.for_pickup(spec), where)
	match spec.kind:
		RoguelikePickupSpec.Kind.TOOL:
			var amount := spec.amount + state.get_relic_level(RoguelikeRelics.COLLECTOR)
			var character_trait := RoguelikeCharacters.get_trait(lemming)
			if character_trait != null:
				amount += character_trait.get_pickup_bonus()
			_pop_icons(where, spec.tool_id, amount)
			var evicted := state.inventory.add_charges(spec.tool_id, amount)
			# A tool pushed out of a full bar drops away, greyed.
			if evicted != "":
				var dropped := RoguelikeIconPop.spawn(level_manager, where + Vector2(0, -POP_SPACING), evicted)
				if dropped != null:
					dropped.modulate = EVICTED_TINT
		RoguelikePickupSpec.Kind.REVIVE:
			state.revive_tokens += 1
			_pop_icons(where, "hud_rescue", 1)
		RoguelikePickupSpec.Kind.TIME:
			level_manager.time_remaining += spec.amount
			_pop_icons(where, "hud_clock", 1)
		RoguelikePickupSpec.Kind.CHARGE_BAG:
			state.inventory.add_one_to_each()
			for tool_id in state.inventory.get_tool_ids().slice(0, MAX_POPS):
				_pop_icons(where + Vector2(0, -POP_SPACING * 0.5), tool_id, 1)
		RoguelikePickupSpec.Kind.COINS:
			var coins := spec.amount + state.get_relic_level(RoguelikeRelics.GREED)
			state.coins += coins
			_pop_icons(where, "hud_coin", coins)
		RoguelikePickupSpec.Kind.ABILITY_CHARGE:
			# The crystal itself flies up; the slot in the bar pulses.
			ability_slot.add_charges(spec.amount)
			AudioManager.play_sound(&"select_tool")
			RoguelikeIconPop.spawn(level_manager, pickup.global_position, RoguelikeAbilities.CHARGE_ICON)
			return
	AudioManager.play_sound(&"select_tool")


## count icons in a row centred on where, each popping up and fading.
func _pop_icons(where: Vector2, icon_id: String, count: int) -> void:
	var shown := clampi(count, 1, MAX_POPS)
	for index in shown:
		var offset := (float(index) - (shown - 1) / 2.0) * POP_SPACING
		RoguelikeIconPop.spawn(level_manager, where + Vector2(offset, 0), icon_id)


func _on_level_ended(_percentage_saved: float) -> void:
	if _finished:
		return
	_finished = true
	state.last_time_left = level_manager.time_remaining
	ability_slot.set_armed(false)
	# Whoever is still out when the clock runs out does not make it, nor do
	# the ones never released (the stage was ended early).
	for lemming in _characters.keys():
		_lost.append(_characters[lemming])
	_characters.clear()
	for index in range(_spawned_count, state.troop.size()):
		_lost.append(state.troop[index])
	stage_finished.emit.call_deferred(_saved, _lost)
