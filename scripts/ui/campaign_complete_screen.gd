class_name CampaignCompleteScreen
extends Control
## After the last campaign level: "Parabéns!" over the volcano's sky, with
## fireworks, a star lighting up for each of the levels won, and wizards
## marching across the bottom; then the credits (who made the game, and that
## its art and sound are generated in code) rise in on a wooden panel.
## Animation in place of text, as the user asked. Reached from the last
## level's result screen and, once every level is won, from the level
## select.

const MAIN_MENU_SCENE_PATH := "res://scenes/main/main_menu.tscn"
const WIZARD_FRAMES_PATH := "res://resources/sprite_frames/wizard.tres"
const TITLE := "Parabéns!"
const TITLE_FONT_SIZE := 72
const TITLE_OUTLINE_SIZE := 12
const TITLE_COLOUR := Color(1.0, 0.9, 0.55)
const TITLE_BOB_PIXELS := 6.0
const TITLE_BOB_SECONDS := 1.1
const STAR_SIZE := Vector2(40, 40)
const STAR_UNLIT := Color(0.25, 0.22, 0.2, 0.8)
const STAR_DELAY_SECONDS := 0.12
const STAR_POP_SECONDS := 0.3
## [icon, line] of the credits, one per row; as short as they can be.
const CREDITS: Array = [
	["campaign", "Um jogo de Thiago"],
	["editor_play", "Feito com Claude"],
	["editor_brick", "Arte e som gerados por código"],
]
const CREDITS_FONT_SIZE := 20
const CREDITS_DELAY_SECONDS := 2.6
const CREDITS_RISE_PIXELS := 40.0
const CREDITS_RISE_SECONDS := 0.6
const CORNER_MARGIN := 12
## Wizards marching along the bottom: how many, how big, how fast.
const MARCHERS := 7
const MARCHER_SCALE := 0.3
const MARCHER_SPACING := 90.0
const MARCHER_SPEED := 60.0
const MARCHER_GROUND_OFFSET := 70.0
const FIREWORK_SECONDS := 0.55
const FIREWORK_SPARKS := 90
const FIREWORK_COLOURS: Array[Color] = [
	Color(1.0, 0.85, 0.35), Color(1.0, 0.5, 0.3), Color(0.6, 0.85, 1.0), Color(0.75, 1.0, 0.55), Color(1.0, 0.6, 0.9),
]

var _title: Label
var _stars: Array[TextureRect] = []
var _credits: Control
var _marchers: Array[AnimatedSprite2D] = []
var _firework_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	AudioManager.play_music_track(&"menu_theme")
	AudioManager.play_sound(&"level_won")
	var background := LevelBackground.new()
	background.environment = LevelEnvironment.by_kind(LevelEnvironment.Kind.VOLCANO)
	add_child(background)
	_add_marchers()

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 26)
	centre.add_child(column)
	_title = _make_title()
	column.add_child(_title)
	column.add_child(_make_stars())
	_credits = _make_credits()
	column.add_child(_credits)
	_add_buttons()
	_animate.call_deferred()


func _process(delta: float) -> void:
	_march(delta)
	_firework_timer -= delta
	if _firework_timer <= 0.0:
		_firework_timer = _rng.randf_range(0.35, 0.9)
		_launch_firework()


## The buttons to go on, for tests and the keyboard.
func get_back_button() -> Button:
	return find_child("BackButton", true, false) as Button


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_to(Campaign.SELECT_SCENE_PATH)


func _make_title() -> Label:
	var title := Label.new()
	title.text = TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", TITLE_COLOUR)
	title.add_theme_constant_override("outline_size", TITLE_OUTLINE_SIZE)
	return title


## One star per campaign level, unlit until the animation reaches it.
func _make_stars() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.tooltip_text = "%d fases" % Campaign.LEVEL_COUNT
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	for index in Campaign.LEVEL_COUNT:
		var holder := Control.new()
		holder.custom_minimum_size = STAR_SIZE
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(holder)
		var star := TextureRect.new()
		star.texture = UiStyle.icon("star")
		star.size = STAR_SIZE
		star.pivot_offset = STAR_SIZE / 2.0
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		star.modulate = STAR_UNLIT
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(star)
		_stars.append(star)
	return row


## The credits on a wooden panel: an icon and a short line per row.
func _make_credits() -> Control:
	var holder := Control.new()
	var panel := PanelContainer.new()
	panel.name = "Credits"
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)
	for credit in CREDITS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		rows.add_child(row)
		var icon := TextureRect.new()
		icon.texture = UiStyle.icon(credit[0])
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var label := Label.new()
		label.text = credit[1]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", CREDITS_FONT_SIZE)
		row.add_child(label)
	holder.add_child(panel)
	# The holder keeps the panel's room in the column while the panel rises
	# into place inside it (a container would hold it still).
	holder.custom_minimum_size = panel.get_combined_minimum_size()
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.modulate.a = 0.0
	return holder


func _add_buttons() -> void:
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	buttons.offset_right = -CORNER_MARGIN
	buttons.offset_bottom = -CORNER_MARGIN
	add_child(buttons)
	var menu := UiStyle.make_icon_button("editor_menu", "Menu")
	menu.name = "MenuButton"
	menu.pressed.connect(_go_to.bind(MAIN_MENU_SCENE_PATH))
	buttons.add_child(menu)
	var back := UiStyle.make_text_button("Fases", true)
	back.name = "BackButton"
	back.icon = UiStyle.icon("campaign")
	back.pressed.connect(_go_to.bind(Campaign.SELECT_SCENE_PATH))
	buttons.add_child(back)


func _animate() -> void:
	_title.pivot_offset = _title.size / 2.0
	_title.scale = Vector2.ZERO
	var title_in := create_tween()
	title_in.tween_property(_title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	title_in.tween_callback(_bob_title)
	for index in _stars.size():
		var star := _stars[index]
		var tween := create_tween()
		tween.tween_interval(0.5 + index * STAR_DELAY_SECONDS)
		tween.tween_callback(func() -> void: star.modulate = Color.WHITE; star.scale = Vector2.ONE * 1.6)
		tween.tween_property(star, "scale", Vector2.ONE, STAR_POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var panel := _credits.get_child(0) as Control
	panel.position.y = CREDITS_RISE_PIXELS
	var credits_in := create_tween().set_parallel()
	credits_in.tween_property(panel, "position:y", 0.0, CREDITS_RISE_SECONDS).set_delay(CREDITS_DELAY_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	credits_in.tween_property(panel, "modulate:a", 1.0, CREDITS_RISE_SECONDS).set_delay(CREDITS_DELAY_SECONDS)


func _bob_title() -> void:
	var rest := _title.position.y
	var tween := create_tween().set_loops()
	tween.tween_property(_title, "position:y", rest - TITLE_BOB_PIXELS, TITLE_BOB_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_title, "position:y", rest, TITLE_BOB_SECONDS).set_trans(Tween.TRANS_SINE)


## A line of wizards walking along the bottom, coming back in from the left
## as each leaves on the right.
func _add_marchers() -> void:
	var frames := load(WIZARD_FRAMES_PATH) as SpriteFrames
	if frames == null:
		return
	for index in MARCHERS:
		var wizard := AnimatedSprite2D.new()
		wizard.sprite_frames = frames
		wizard.scale = Vector2.ONE * MARCHER_SCALE
		wizard.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wizard.position.x = -index * MARCHER_SPACING
		wizard.play(&"walk")
		wizard.frame = index % maxi(frames.get_frame_count(&"walk"), 1)
		add_child(wizard)
		_marchers.append(wizard)


func _march(delta: float) -> void:
	var width := get_viewport_rect().size.x
	var ground := get_viewport_rect().size.y - MARCHER_GROUND_OFFSET
	var span := MARCHERS * MARCHER_SPACING
	for wizard in _marchers:
		wizard.position.y = ground
		wizard.position.x += MARCHER_SPEED * delta
		if wizard.position.x > width + MARCHER_SPACING:
			wizard.position.x -= width + span


## A burst of sparks somewhere in the upper half of the screen.
func _launch_firework() -> void:
	var view := get_viewport_rect().size
	var sparks := CPUParticles2D.new()
	sparks.position = Vector2(_rng.randf_range(0.1, 0.9) * view.x, _rng.randf_range(0.08, 0.45) * view.y)
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = FIREWORK_SPARKS
	sparks.lifetime = FIREWORK_SECONDS * 2.0
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 140.0
	sparks.initial_velocity_max = 300.0
	sparks.gravity = Vector2(0, 160)
	sparks.damping_min = 40.0
	sparks.damping_max = 80.0
	sparks.scale_amount_min = 3.0
	sparks.scale_amount_max = 6.0
	var colour: Color = FIREWORK_COLOURS[_rng.randi() % FIREWORK_COLOURS.size()]
	var fade := Gradient.new()
	fade.set_color(0, colour)
	fade.set_color(1, Color(colour, 0.0))
	sparks.color_ramp = fade
	sparks.z_index = -1
	add_child(sparks)
	move_child(sparks, 1)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)


func _go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
