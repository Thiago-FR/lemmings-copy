class_name InfoButton
extends Button
## A small "i" button whose text shows only while the mouse is over it.
## Replaces the level instructions that used to sit on screen as a block of
## text covering the level.
##
## Godot's default tooltip is a single line, so a long text would run off the
## screen; this builds a wrapped one instead.

## Width the tooltip text wraps at, in pixels.
const TOOLTIP_WIDTH := 360.0


func _make_custom_tooltip(for_text: String) -> Object:
	var label := Label.new()
	label.text = for_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = TOOLTIP_WIDTH
	return label
