class_name RoguelikeAbility
extends RefCounted
## A character's special ability: its own slot in the tool bar, a few
## charges per stage (RoguelikeAbilitySlot), used by clicking a lemming with
## the slot selected. Each character has one (RoguelikeAbilities), on top of
## its passive bonus (RoguelikeCharacterTrait).
##
## try_use() either does the whole thing or nothing at all: a refused use
## leaves the lemming and the terrain as they were, so the slot spends a
## charge only on success. Subclasses implement _use().
##
## The abilities that act on something "in front" look up to one block
## ahead of the body (REACH_TILES): a lemming turns the instant it touches a
## wall, so asking for the wall to be touching would leave the player no
## moment to click.

## How far ahead of the leading edge a wall or an edge may be, in tiles.
const REACH_TILES := 1.0
## Half a pixel inside whatever a probe is meant to land in.
const PROBE_INSET := 0.5
## Shrinks body rectangles for overlap checks, as the lemming does, so a
## body touching a surface does not count as inside it.
const BODY_INSET := 1.0

var id: StringName = &""


## Uses the ability on the lemming. False, with nothing changed, when it
## cannot be used there and then.
func try_use(lemming: LemmingController) -> bool:
	if not _is_ready(lemming):
		return false
	return _use(lemming)


## Only a lemming walking on its own: not falling, not busy with a tool,
## not already walking into the exit.
func _is_ready(lemming: LemmingController) -> bool:
	return is_instance_valid(lemming) and lemming.state_machine.is_alive() \
		and not lemming.is_entering_exit \
		and lemming.state_machine.current_state == LemmingStateMachine.State.WALKING


func _use(_lemming: LemmingController) -> bool:
	return false


# --- Geometry shared by the abilities ---------------------------------------

static func front_edge(body: Rect2, side: int) -> float:
	return body.end.x if side > 0 else body.position.x


## Centre x of the terrain column holding the body's edge on that side.
static func edge_column_centre(lemming: LemmingController, side: int) -> float:
	var body := lemming.get_body_rect()
	var probe := Vector2(front_edge(body, side) - side * PROBE_INSET, body.get_center().y)
	return lemming.terrain.cell_rect_at(probe).get_center().x


## The column strip at column_x, as tall as the body: what a wall in front
## of the body would fill.
static func column_strip(lemming: LemmingController, column_x: float) -> Rect2:
	var body := lemming.get_body_rect()
	var tile := lemming.terrain.get_cell_size()
	return Rect2(column_x - tile.x / 2.0, body.position.y, tile.x, body.size.y).grow(-BODY_INSET)


## Centre x of the first column on that side, up to REACH_TILES columns
## past the one holding the body's edge, with terrain at body height; NAN
## if there is none. Bricks do not count: they only block from above.
static func find_wall_column(lemming: LemmingController, side: int) -> float:
	var tile_width := lemming.terrain.get_cell_size().x
	var edge_x := edge_column_centre(lemming, side)
	for step in range(1, int(REACH_TILES) + 2):
		var column_x := edge_x + side * tile_width * step
		if lemming.terrain.is_terrain_solid_in_rect(column_strip(lemming, column_x)):
			return column_x
	return NAN


## Whether the body, moved so its centre is at body_centre, is clear of
## terrain and bricks.
static func body_fits_at(lemming: LemmingController, body_centre: Vector2) -> bool:
	var body := lemming.get_body_rect()
	body.position += body_centre - body.get_center()
	return not lemming.terrain.is_solid_in_rect(body.grow(-BODY_INSET))


## Whether world_position lies on a cell inside the stage (the terrain's
## painted area), so nothing sends a lemming out past the outer wall.
static func is_inside_stage(terrain: TerrainDestructible, world_position: Vector2) -> bool:
	var cell := terrain.local_to_map(terrain.to_local(world_position))
	return terrain.get_used_rect().has_point(cell)
