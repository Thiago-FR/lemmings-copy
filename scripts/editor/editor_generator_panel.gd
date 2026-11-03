class_name EditorGeneratorPanel
extends CanvasLayer
## Makes a drawing with the stage generator (BiomeStageGenerator): pick the
## setting, the size and how hard, then Generate. The drawing replaces what
## is in the editor and can be changed and saved like any other. Emits
## generate_requested(biome_id, size, tier) or closes on Back / Esc.

signal generate_requested(biome_id: StringName, size: Vector2i, tier: int)

const LAYER := 30
const BACKDROP_COLOUR := Color(0.03, 0.03, 0.06, 0.65)
const BIOME_COLUMNS := 5
const BIOME_BUTTON_SIZE := Vector2(150, 40)
## name, size in cells.
const SIZES: Array = [
	["1 tela", Vector2i(56, 30)],
	["Comprido", Vector2i(120, 32)],
	["Alto", Vector2i(46, 80)],
	["Grande", Vector2i(100, 56)],
	["Enorme", Vector2i(170, 90)],
]
const TIERS := ["Fácil", "Médio", "Difícil"]

var _biome: StringName = BiomeStageGenerator.biomes()[0].id
var _size: Vector2i = SIZES[0][1]
var _tier := 0
var _size_label: Label


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOUR
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var icon := TextureRect.new()
	icon.texture = UiStyle.icon("procedural")
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)

	var biomes := GridContainer.new()
	biomes.columns = BIOME_COLUMNS
	biomes.add_theme_constant_override("h_separation", 6)
	biomes.add_theme_constant_override("v_separation", 6)
	column.add_child(biomes)
	var biome_group := ButtonGroup.new()
	for biome in BiomeStageGenerator.biomes():
		var button := UiStyle.make_text_button(biome.name)
		button.name = "Biome_%s" % biome.id
		button.custom_minimum_size = BIOME_BUTTON_SIZE
		button.toggle_mode = true
		button.button_group = biome_group
		button.button_pressed = biome.id == _biome
		button.pressed.connect(func() -> void: _biome = biome.id)
		biomes.add_child(button)

	var sizes := HBoxContainer.new()
	sizes.alignment = BoxContainer.ALIGNMENT_CENTER
	sizes.add_theme_constant_override("separation", 6)
	column.add_child(sizes)
	var size_group := ButtonGroup.new()
	for entry in SIZES:
		var button := UiStyle.make_text_button(entry[0])
		button.toggle_mode = true
		button.button_group = size_group
		button.button_pressed = entry[1] == _size
		button.tooltip_text = "%d x %d blocos" % [entry[1].x, entry[1].y]
		button.pressed.connect(func() -> void:
			_size = entry[1]
			_size_label.text = "%d x %d" % [_size.x, _size.y])
		sizes.add_child(button)
	_size_label = Label.new()
	_size_label.text = "%d x %d" % [_size.x, _size.y]
	_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_size_label)

	var tiers := HBoxContainer.new()
	tiers.alignment = BoxContainer.ALIGNMENT_CENTER
	tiers.add_theme_constant_override("separation", 6)
	column.add_child(tiers)
	var tier_group := ButtonGroup.new()
	for index in TIERS.size():
		var button := UiStyle.make_text_button(TIERS[index])
		button.toggle_mode = true
		button.button_group = tier_group
		button.button_pressed = index == _tier
		button.pressed.connect(func() -> void: _tier = index)
		tiers.add_child(button)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var back := UiStyle.make_text_button("Voltar")
	back.name = "Back"
	back.icon = UiStyle.icon("editor_play")
	back.pressed.connect(queue_free)
	buttons.add_child(back)
	var generate := UiStyle.make_text_button("Gerar", true)
	generate.name = "Generate"
	generate.icon = UiStyle.icon("procedural")
	generate.pressed.connect(func() -> void:
		generate_requested.emit(_biome, _size, _tier)
		queue_free())
	buttons.add_child(generate)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()
