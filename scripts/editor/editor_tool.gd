class_name EditorTool
extends RefCounted
## The level editor's paint tools and their player-facing names. Kept apart
## from both the toolbar (which lists them) and the controller (which applies
## them) so neither has to know about the other.

enum Kind { BLOCK, CONCRETE, LADDER, BRICK, ERASER, ENTRANCE, EXIT }

const DISPLAY_NAMES := {
	Kind.BLOCK: "Terra",
	Kind.CONCRETE: "Concreto",
	Kind.LADDER: "Escada",
	Kind.BRICK: "Ponte",
	Kind.ERASER: "Borracha",
	Kind.ENTRANCE: "Entrada",
	Kind.EXIT: "Saída",
}


static func get_display_name(kind: Kind) -> String:
	return DISPLAY_NAMES[kind]


## Tools that keep painting while the mouse is dragged. Entrance and exit
## are single objects, so dragging them would only make them jitter around.
static func paints_on_drag(kind: Kind) -> bool:
	return kind != Kind.ENTRANCE and kind != Kind.EXIT
