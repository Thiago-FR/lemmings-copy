extends Node
## Makes the game use the whole screen without zooming it.
##
## The world is drawn at its real pixel size: on a Full HD monitor a lemming
## is 26x30 pixels and the screen simply shows more of the level (the user's
## choice; the camera scrolls when a level is bigger than the screen). The
## old setup stretched a fixed 800x450 picture to the window, which in full
## screen looked like a zoomed-in, blurry version of the small window.
##
## On dense screens (4K monitors, phones) real pixel size would be tiny, so
## everything is enlarged by a whole factor (2x, 3x...), never a fraction,
## which keeps the pixel art sharp. This works through the window's content
## scale: the project uses the canvas_items stretch mode with the "expand"
## aspect, and the content scale size is set here to the window size
## divided by the factor, so one world pixel is exactly factor screen
## pixels.
##
## Full screen or a window: F11, or the settings screen. The choice is saved
## in user://settings.cfg (section "display") and restored at start.

## A window at least this tall (in screen pixels) gets the next whole
## factor on desktop: 1080p and 1440p draw at 1x, 4K at 2x.
const PIXELS_PER_FACTOR_STEP := 1080.0
## Rounding allowance, so a 2160-pixel screen with a taskbar still gets 2x.
const FACTOR_ROUNDING := 0.25
## On phones and tablets the factor comes from the screen density instead:
## one step per this many dots per inch.
const MOBILE_DPI_PER_FACTOR := 160.0
const MAX_FACTOR := 4
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "display"
## Size of the window when not in full screen.
const WINDOWED_SIZE := Vector2i(1280, 720)


func _ready() -> void:
	get_window().size_changed.connect(_apply)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	set_fullscreen(config.get_value(SETTINGS_SECTION, "fullscreen", true), false)
	_apply()


func is_fullscreen() -> bool:
	return get_window().mode == Window.MODE_FULLSCREEN or get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN


## Switches between full screen and a centred window, and remembers it.
func set_fullscreen(fullscreen: bool, save: bool = true) -> void:
	var window := get_window()
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.size = WINDOWED_SIZE
		window.move_to_center()
	if save:
		var config := ConfigFile.new()
		config.load(SETTINGS_PATH)
		config.set_value(SETTINGS_SECTION, "fullscreen", fullscreen)
		config.save(SETTINGS_PATH)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F11:
		set_fullscreen(not is_fullscreen())
		get_viewport().set_input_as_handled()


## The whole factor everything is drawn at on this screen.
func get_pixel_factor() -> int:
	var factor: int
	if OS.has_feature("mobile"):
		factor = roundi(DisplayServer.screen_get_dpi() / MOBILE_DPI_PER_FACTOR)
	else:
		factor = floori(get_window().size.y / PIXELS_PER_FACTOR_STEP + FACTOR_ROUNDING)
	return clampi(factor, 1, MAX_FACTOR)


func _apply() -> void:
	var window := get_window()
	if window.size.x <= 0 or window.size.y <= 0:
		return
	var factor := get_pixel_factor()
	window.content_scale_size = window.size / factor
