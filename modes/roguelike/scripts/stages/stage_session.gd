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

const SPAWN_INTERVAL_SECONDS := 1.5

var state: RoguelikeRunState = null
## Optional: the run's relics, applied to the tool templates before the
## stage starts.
var relics: RoguelikeRelics = null
## Leave the HUD and tool bar out (tests that do not need them).
var show_ui := true
## While true, clicking a lemming sacrifices it (set_sacrifice_armed).
var sacrifice_armed := false

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
	if relics != null:
		relics.apply_templates(state.relics)

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
		level_manager.add_child(RoguelikeToolBar.new(state.inventory))

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
	level_data.time_limit_seconds = definition.time_limit_seconds
	level_data.available_skills = SkillManager.get_skill_ids()
	level_data.skill_counts = state.inventory.to_counts()
	return level_data


func _sync_charges() -> void:
	var counts := state.inventory.to_counts()
	for skill_id in SkillManager.get_skill_ids():
		SkillManager.set_remaining_count(skill_id, int(counts.get(skill_id, 0)))


func _on_lemming_spawned(lemming: LemmingController) -> void:
	var character: StringName = state.troop[_spawned_count]
	_spawned_count += 1
	_characters[lemming] = character
	RoguelikeCharacters.apply_to(lemming, character)
	if _spawned_count == 1 and state.relics.has(RoguelikeRelics.SPARE_PARACHUTE):
		lemming.has_floater_skill = true
	lemming.clicked.connect(_on_lemming_clicked)
	lemming.died.connect(func(cause: LemmingController.DeathCause) -> void: _on_lemming_died(lemming, cause))


func _on_lemming_died(lemming: LemmingController, cause: LemmingController.DeathCause) -> void:
	_on_lemming_resolved(lemming, false)
	if cause == LemmingController.DeathCause.SACRIFICE:
		state.coins += RoguelikeRunState.COINS_PER_SACRIFICED
		RoguelikeFloatingText.spawn(level_manager, lemming.global_position, "+%d moeda" % RoguelikeRunState.COINS_PER_SACRIFICED)


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
## _ready). With a tool selected that has charges the click is
## SkillManager's; otherwise the lemming may have an ability of its own.
func _on_lemming_clicked(lemming: LemmingController) -> void:
	if sacrifice_armed:
		sacrifice(lemming)
		return
	var selected := SkillManager.selected_skill_id
	if selected != "" and SkillManager.get_remaining_count(selected) > 0:
		return
	var character_trait := RoguelikeCharacters.get_trait(lemming)
	if character_trait != null and character_trait.can_use_own_ability():
		character_trait.use_own_ability()


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
	sacrifice_armed_changed.emit(armed)


func _on_skill_selected(skill_id: String) -> void:
	if skill_id != "":
		set_sacrifice_armed(false)


## Ends the stage now: whoever is still in it is sacrificed (see
## LevelManager.end_now) and the ones not released yet are lost.
func end_stage_now() -> void:
	set_sacrifice_armed(false)
	level_manager.end_now()


## A tool a lemming dropped unused for a newer one goes back to the bar.
func _on_skill_refunded(skill_id: String) -> void:
	state.inventory.add_charges(skill_id, 1)


func _on_skill_assigned(_lemming: LemmingController, skill_id: String) -> void:
	state.inventory.spend(skill_id)


func _on_pickup_collected(pickup: RoguelikePickup, lemming: LemmingController) -> void:
	var spec := pickup.spec
	var text := spec.describe()
	match spec.kind:
		RoguelikePickupSpec.Kind.TOOL:
			var amount := spec.amount
			var character_trait := RoguelikeCharacters.get_trait(lemming)
			if character_trait != null:
				amount += character_trait.get_pickup_bonus()
			text = "+%d %s" % [amount, SkillManager.get_display_name(spec.tool_id)]
			var evicted := state.inventory.add_charges(spec.tool_id, amount)
			if evicted != "":
				text += " (saiu %s)" % SkillManager.get_display_name(evicted)
		RoguelikePickupSpec.Kind.REVIVE:
			state.revive_tokens += 1
		RoguelikePickupSpec.Kind.TIME:
			level_manager.time_remaining += spec.amount
		RoguelikePickupSpec.Kind.CHARGE_BAG:
			state.inventory.add_one_to_each()
	AudioManager.play_sound(&"select_tool")
	RoguelikeFloatingText.spawn(level_manager, pickup.global_position, text)


func _on_level_ended(_percentage_saved: float) -> void:
	if _finished:
		return
	_finished = true
	# Whoever is still out when the clock runs out does not make it, nor do
	# the ones never released (the stage was ended early).
	for lemming in _characters.keys():
		_lost.append(_characters[lemming])
	_characters.clear()
	for index in range(_spawned_count, state.troop.size()):
		_lost.append(state.troop[index])
	stage_finished.emit.call_deferred(_saved, _lost)
