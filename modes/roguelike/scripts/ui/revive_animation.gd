class_name RoguelikeReviveAnimation
extends CanvasLayer
## A phoenix feather bringing a lemming back, shown instead of a message
## (the user: "aviso não, animação"): over a dimmed screen the feather rises
## and spins, bursts into fire, and the lemming's portrait is reborn out of
## the flames, glowing, before everything fades. A click skips it. Emits
## finished, then frees itself. One per lemming brought back, one after
## the other.

signal finished

const LAYER := 25
const BACKDROP_COLOUR := Color(0.05, 0.02, 0.02, 0.6)
const FEATHER_PATH := "res://assets/sprites/ui/cards/rescue_phoenix.png"
const ART_SIZE := Vector2(128, 128)
const RISE_SECONDS := 0.5
const BURST_SECONDS := 0.45
const REBORN_SECONDS := 0.5
const HOLD_SECONDS := 0.55
const FADE_SECONDS := 0.3
const RISE_PIXELS := 60.0
const SPARK_COUNT := 36
const SPARK_SPEED := Vector2(120.0, 320.0)
const SPARK_SIZE := 5.0
const SPARK_COLOURS: Array[Color] = [Color(1.0, 0.85, 0.3), Color(1.0, 0.55, 0.15), Color(0.95, 0.25, 0.1), Color(1.0, 0.97, 0.75)]

var _characters: Array[StringName] = []
var _backdrop: ColorRect
var _feather: TextureRect
var _portrait: TextureRect
var _fire: Control
var _sparks: Array = []
var _burst_age := -1.0
var _skipped := false


func _init(characters: Array[StringName]) -> void:
	assert(not characters.is_empty(), "Nobody to bring back")
	_characters = characters.duplicate()
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = BACKDROP_COLOUR
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)
	_fire = Control.new()
	_fire.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fire.draw.connect(_draw_fire)
	add_child(_fire)
	_feather = _make_art(load(FEATHER_PATH))
	_portrait = _make_art(null)
	_play_next()


func _make_art(texture: Texture2D) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.size = ART_SIZE
	art.pivot_offset = ART_SIZE / 2.0
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	return art


func _centre() -> Vector2:
	return _backdrop.size / 2.0 - ART_SIZE / 2.0


func _play_next() -> void:
	if _characters.is_empty() or _skipped:
		_finish()
		return
	var character: StringName = _characters.pop_front()
	AudioManager.play_sound(&"parachute")
	var start := _centre() + Vector2(0, RISE_PIXELS)
	_feather.position = start
	_feather.rotation = -0.6
	_feather.scale = Vector2.ONE * 0.6
	_feather.modulate = Color.WHITE
	_portrait.texture = RoguelikeCharacters.get_portrait(character)
	_portrait.position = _centre()
	_portrait.scale = Vector2.ONE * 0.2
	_portrait.modulate = Color(2.5, 1.6, 0.8, 0.0)

	var tween := create_tween()
	tween.tween_property(_feather, "position", _centre(), RISE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_feather, "rotation", TAU * 1.5, RISE_SECONDS)
	tween.parallel().tween_property(_feather, "scale", Vector2.ONE, RISE_SECONDS)
	tween.tween_callback(_burst)
	tween.tween_property(_feather, "modulate", Color(3.0, 1.5, 0.5, 0.0), BURST_SECONDS * 0.5)
	tween.parallel().tween_property(_feather, "scale", Vector2.ONE * 1.6, BURST_SECONDS * 0.5)
	tween.tween_property(_portrait, "modulate", Color(2.5, 1.6, 0.8, 1.0), REBORN_SECONDS * 0.4)
	tween.parallel().tween_property(_portrait, "scale", Vector2.ONE * 1.15, REBORN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_portrait, "modulate", Color.WHITE, REBORN_SECONDS * 0.6)
	tween.parallel().tween_property(_portrait, "scale", Vector2.ONE, REBORN_SECONDS * 0.6)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(_portrait, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(_play_next)


## Sparks thrown out of the feather in every direction, slowing and fading.
func _burst() -> void:
	AudioManager.play_sound(&"sacrifice")
	_sparks.clear()
	var origin := _centre() + ART_SIZE / 2.0
	for _spark in SPARK_COUNT:
		var angle := randf() * TAU
		_sparks.append([origin, Vector2.RIGHT.rotated(angle) * randf_range(SPARK_SPEED.x, SPARK_SPEED.y), SPARK_COLOURS.pick_random()])
	_burst_age = 0.0


func _process(delta: float) -> void:
	if _burst_age < 0.0:
		return
	_burst_age += delta
	if _burst_age > BURST_SECONDS * 2.0:
		_burst_age = -1.0
	_fire.queue_redraw()


func _draw_fire() -> void:
	if _burst_age < 0.0:
		return
	var life := clampf(1.0 - _burst_age / (BURST_SECONDS * 2.0), 0.0, 1.0)
	# A warm glow behind the rebirth.
	var glow := Color(1.0, 0.55, 0.15, 0.35 * life)
	var origin := _centre() + ART_SIZE / 2.0
	_fire.draw_circle(origin, ART_SIZE.x * (0.6 + 0.4 * (1.0 - life)), glow)
	for spark in _sparks:
		var travel: Vector2 = spark[1] * _burst_age * (1.0 - _burst_age / (BURST_SECONDS * 4.0))
		var colour: Color = spark[2]
		colour.a = life
		var position: Vector2 = spark[0] + travel + Vector2(0, -40.0 * _burst_age)
		_fire.draw_rect(Rect2(position - Vector2.ONE * SPARK_SIZE / 2.0, Vector2.ONE * SPARK_SIZE * life), colour)


func _on_backdrop_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		_skipped = true
		_finish()


func _finish() -> void:
	if is_queued_for_deletion():
		return
	finished.emit()
	queue_free()
