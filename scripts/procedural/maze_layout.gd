class_name MazeLayout
extends RefCounted
## A maze stage described as rooms and the links between them, before it is
## turned into terrain. MazeStageGenerator builds one at random; a hand-made
## stage builds one with the same methods (add_open, add_wall, add_trough,
## add_stairs, add_ladder, add_tool_spot...). MazeSolver checks it can be
## won, MazePainter turns it into terrain cells. Nothing here knows about any
## game mode: items are only "spots" with a kind.
##
## Geometry (in blocks of 32px): the stage is COLUMNS x ROWS with a solid
## border, the size of a Full HD screen. Rooms sit on a grid of
## ROOM_COLUMNS x ROOM_ROWS. Room column c spans the blocks between
## SEPARATOR_COLUMNS[c] and SEPARATOR_COLUMNS[c + 1]; a separator column is
## the wall between two rooms of a band. Band r stands on floor row
## FLOOR_ROWS[r]: a slab one block thick that is also the ceiling of the band
## below. Bands are 11 rows apart, so the vertical ladder that links two bands
## is exactly 12 pieces (the tool's limit) and the staircase that links them
## going down has five 2-block steps (a fall of 64px each, within the 80px a
## lemming survives).
##
## Every link is free or closed until a tool opens it, and once open it stays
## open for every lemming (a tunnel, a ladder, a bridge, a dug hole): no link
## relies on a tool one lemming keeps to itself (the climber and the parachute
## do not help here: a climber goes up a room's wall to its ceiling and falls).
## Before a link is opened a lemming meets a wall there and turns back; no
## room has an edge a lemming can walk off to its death on its own.

const COLUMNS := 60
const ROWS := 34
const ROOM_COLUMNS := 5
const ROOM_ROWS := 3
const ROOM_COUNT := ROOM_COLUMNS * ROOM_ROWS
const SEPARATOR_COLUMNS: Array[int] = [0, 12, 24, 36, 48, 59]
const FLOOR_ROWS: Array[int] = [10, 21, 32]
## Rows above the floor a doorway (and the opening above a ladder's sill)
## leaves open.
const DOORWAY_HEIGHT := 3
## Rows of air a room always keeps above its floor; ceiling decoration only
## goes above them.
const CLEAR_HEIGHT := 3
## Steps of the staircase under a dug hole: each one 2 blocks below the
## last, one column further from the separator.
const STAIR_STEPS := 5
## The curb that keeps a room's lemmings away from the top of a ladder shaft:
## 2 blocks, so a lemming leaving the ladder never steps onto it.
const CURB_HEIGHT := 2

## Cell contents of the painted grid.
const EMPTY := 0
const EARTH := 1
const CONCRETE := 2

enum LinkKind {
	## A doorway between two rooms of a band. Free both ways.
	OPEN,
	## The separator between two rooms of a band, solid: a tunnel through it
	## (pickaxe or jackhammer for earth, only the jackhammer for concrete)
	## opens it both ways.
	WALL,
	## Down from a room to the one below: an earth patch in the floor, next
	## to a separator, over a staircase. The shovel opens it; then it is a
	## one-way drop.
	STAIRS,
	## Up from a room to the room diagonally above: a shaft against the
	## separator, which a vertical ladder climbs to the separator's sill.
	## Built, every lemming walking into it climbs.
	LADDER,
	## A bridge across a trough between two rooms of a band. Both ways.
	BRIDGE,
	## Walking into a trough (one block deep): free, one way, until a bridge
	## or a ladder out on that side covers it.
	TROUGH_FALL,
	## Out of a trough onto one side with a one-piece vertical ladder.
	TROUGH_LADDER,
}

enum SpotKind {
	## Charges of a tool (tool_id, amount). The solver counts these.
	TOOL,
	## Something good the game decides (a rescue, extra time...). The solver
	## does not count on it.
	BONUS,
}

## Room nodes are 0 .. ROOM_COUNT - 1 (id = band * ROOM_COLUMNS + column);
## each trough adds a node after them.
var node_count := ROOM_COUNT
## Link dictionaries (see _add_link).
var links: Array[Dictionary] = []
## Item spots: {"room", "kind": SpotKind, "tool_id", "amount", "required"}.
var spots: Array[Dictionary] = []
var spawn_room := -1
var exit_room := -1
## Slab material per room (the floor it stands on).
var floor_materials: Array[int] = []
## Material of each separator no link goes through: "band:separator" -> cell.
var separator_materials: Dictionary = {}
## Rooms painted as open rooms; the others are filled with rock.
var reachable_rooms: Dictionary = {}
## The intended solution: steps from MazeSolver.
var solution_steps: Array[Dictionary] = []

var _used_sides: Dictionary = {}
var _used_slots: Dictionary = {}
var _stair_rooms: Dictionary = {}


func _init() -> void:
	floor_materials.resize(ROOM_COUNT)
	floor_materials.fill(EARTH)


# --- Grid geometry ---------------------------------------------------------------

static func room_id(column: int, band: int) -> int:
	return band * ROOM_COLUMNS + column


static func room_column(room: int) -> int:
	return room % ROOM_COLUMNS


@warning_ignore("integer_division")
static func room_band(room: int) -> int:
	return room / ROOM_COLUMNS


static func is_room(node: int) -> bool:
	return node >= 0 and node < ROOM_COUNT


static func first_column(room: int) -> int:
	return SEPARATOR_COLUMNS[room_column(room)] + 1


static func last_column(room: int) -> int:
	return SEPARATOR_COLUMNS[room_column(room) + 1] - 1


## The room's interior column next to its separator on `side` (-1 left,
## +1 right).
static func side_column(room: int, side: int) -> int:
	return first_column(room) if side < 0 else last_column(room)


## Index into SEPARATOR_COLUMNS of the separator on a room's side.
static func separator_index(room: int, side: int) -> int:
	return room_column(room) + (0 if side < 0 else 1)


static func floor_row(band: int) -> int:
	return FLOOR_ROWS[band]


## Top interior row of a band: under the border for the first band, under
## the slab of the band above for the others.
static func top_row(band: int) -> int:
	return 1 if band == 0 else FLOOR_ROWS[band - 1] + 1


# --- Building a layout -------------------------------------------------------------
# Each can_* says whether the feature fits with what is already there (two
# features never share a room side or a separator slot); each add_* adds it
# and returns the link id (or -1, asserting, if it does not fit).

func can_link_side_by_side(column: int, band: int) -> bool:
	return column >= 0 and column + 1 < ROOM_COLUMNS and _is_slot_free(band, column + 1)


## A doorway between room (column, band) and the room to its right.
func add_open(column: int, band: int) -> int:
	assert(can_link_side_by_side(column, band), "Separator %d of band %d is taken" % [column + 1, band])
	var link_id := _add_link({"kind": LinkKind.OPEN, "a": room_id(column, band), "b": room_id(column + 1, band), "band": band, "separator": SEPARATOR_COLUMNS[column + 1]})
	_use_slot(band, column + 1, link_id)
	return link_id


## A solid separator between room (column, band) and the room to its right.
func add_wall(column: int, band: int, material: int) -> int:
	assert(can_link_side_by_side(column, band), "Separator %d of band %d is taken" % [column + 1, band])
	var concrete := material == CONCRETE
	var link_id := _add_link({
		"kind": LinkKind.WALL, "a": room_id(column, band), "b": room_id(column + 1, band), "two_way": true,
		"band": band, "separator": SEPARATOR_COLUMNS[column + 1], "material": material,
		"tools": (["basher"] if concrete else ["miner", "basher"]) as Array[String],
	})
	_use_slot(band, column + 1, link_id)
	return link_id


## A trough cuts the floor on both sides of the separator and, above the
## lowest band, hangs a block into the room below as its bottom: nothing built
## near that separator in either band may be in the way.
func can_trough(column: int, band: int) -> bool:
	if not can_link_side_by_side(column, band):
		return false
	if not is_side_free(room_id(column, band), 1) or not is_side_free(room_id(column + 1, band), -1):
		return false
	if band + 1 < ROOM_ROWS:
		if not is_side_free(room_id(column, band + 1), 1) or not is_side_free(room_id(column + 1, band + 1), -1):
			return false
	return true


## A trough `left_width` + 1 + `right_width` blocks wide (each side 1 or 2)
## centred on the separator right of room (column, band). Returns the
## bridge link's id.
func add_trough(column: int, band: int, left_width: int, right_width: int) -> int:
	assert(can_trough(column, band), "No room for a trough right of room (%d, %d)" % [column, band])
	assert(left_width >= 1 and left_width <= 2 and right_width >= 1 and right_width <= 2, "Trough sides are 1 or 2 blocks")
	var left := room_id(column, band)
	var right := room_id(column + 1, band)
	var separator: int = SEPARATOR_COLUMNS[column + 1]
	var first := separator - left_width
	var last := separator + right_width
	var trough := node_count
	node_count += 1
	var left_columns: Array[int] = []
	for x in range(first, separator):
		left_columns.append(x)
	var right_columns: Array[int] = []
	for x in range(separator + 1, last + 1):
		right_columns.append(x)
	var geometry := {"band": band, "separator": separator, "trough_first": first, "trough_last": last, "trough": trough}
	var bridge := _add_link(_merged(geometry, {
		"kind": LinkKind.BRIDGE, "a": left, "b": right, "two_way": true, "tools": ["bridge"] as Array[String],
		"blocked_columns": {left: left_columns, right: right_columns},
	}))
	var ladder_left := _add_link(_merged(geometry, {"kind": LinkKind.TROUGH_LADDER, "a": trough, "b": left, "side": -1, "tools": ["ladder_vertical"] as Array[String]}))
	var ladder_right := _add_link(_merged(geometry, {"kind": LinkKind.TROUGH_LADDER, "a": trough, "b": right, "side": 1, "tools": ["ladder_vertical"] as Array[String]}))
	_add_link(_merged(geometry, {"kind": LinkKind.TROUGH_FALL, "a": left, "b": trough, "disabled_by": [bridge, ladder_left] as Array[int]}))
	_add_link(_merged(geometry, {"kind": LinkKind.TROUGH_FALL, "a": right, "b": trough, "disabled_by": [bridge, ladder_right] as Array[int]}))
	_use_slot(band, column + 1, bridge)
	_use_side(left, 1, bridge)
	_use_side(right, -1, bridge)
	if band + 1 < ROOM_ROWS:
		_use_side(room_id(column, band + 1), 1, bridge)
		_use_side(room_id(column + 1, band + 1), -1, bridge)
	return bridge


func can_stairs(column: int, band: int, side: int) -> bool:
	if band + 1 >= ROOM_ROWS:
		return false
	var upper := room_id(column, band)
	var lower := room_id(column, band + 1)
	return _is_slot_free(band + 1, separator_index(upper, side)) and is_side_free(upper, side) \
		and is_side_free(lower, side) and not _stair_rooms.has(lower)


## Down from room (column, band) to the room below: an earth patch in the
## floor next to the separator on `side`, over a staircase in the room below
## that descends away from that separator.
func add_stairs(column: int, band: int, side: int) -> int:
	assert(can_stairs(column, band, side), "No room for stairs under room (%d, %d)" % [column, band])
	var upper := room_id(column, band)
	var lower := room_id(column, band + 1)
	var separator := separator_index(upper, side)
	var patch := side_column(upper, side)
	var steps: Array[int] = []
	for step in STAIR_STEPS:
		steps.append(patch - side * step)
	var link_id := _add_link({
		"kind": LinkKind.STAIRS, "a": upper, "b": lower, "tools": ["digger"] as Array[String],
		"band": band, "side": side, "separator": SEPARATOR_COLUMNS[separator],
		"column": patch, "blocked_columns": {upper: [patch], lower: steps},
	})
	_use_slot(band + 1, separator, link_id)
	_use_side(upper, side, link_id)
	_use_side(lower, side, link_id)
	_stair_rooms[lower] = true
	return link_id


func can_ladder(column: int, band: int, side: int) -> bool:
	if band + 1 >= ROOM_ROWS or column + side < 0 or column + side >= ROOM_COLUMNS:
		return false
	var lower := room_id(column, band + 1)
	var separator := separator_index(lower, side)
	return _is_slot_free(band + 1, separator) and _is_slot_free(band, separator) \
		and is_side_free(lower, side) and is_side_free(room_id(column, band), side) \
		and is_side_free(room_id(column + side, band), -side)


## Up from room (column, band + 1) to room (column + side, band): a shaft in
## the lower room's last column on `side`, against the separator, which goes
## up through the floor above to the separator's sill; the lemming steps over
## it into the upper room. The room right above the shaft keeps its lemmings
## away from the shaft with a curb.
func add_ladder(column: int, band: int, side: int) -> int:
	assert(can_ladder(column, band, side), "No room for a ladder from room (%d, %d)" % [column, band + 1])
	var lower := room_id(column, band + 1)
	var above := room_id(column, band)
	var target := room_id(column + side, band)
	var separator := separator_index(lower, side)
	var shaft := side_column(lower, side)
	var link_id := _add_link({
		"kind": LinkKind.LADDER, "a": lower, "b": target, "tools": ["ladder_vertical"] as Array[String],
		"band": band, "side": side, "separator": SEPARATOR_COLUMNS[separator],
		"column": shaft, "blocked_columns": {lower: [shaft], above: [shaft, shaft - side], target: [shaft + 2 * side]},
	})
	_use_slot(band + 1, separator, link_id)
	_use_slot(band, separator, link_id)
	_use_side(lower, side, link_id)
	_use_side(above, side, link_id)
	_use_side(target, -side, link_id)
	return link_id


func add_tool_spot(room: int, tool_id: String, amount: int, required := true) -> Dictionary:
	for spot in spots:
		if spot.room == room and spot.kind == SpotKind.TOOL and spot.tool_id == tool_id:
			spot.amount += amount
			return spot
	var spot := {"room": room, "kind": SpotKind.TOOL, "tool_id": tool_id, "amount": amount, "required": required}
	spots.append(spot)
	return spot


func add_bonus_spot(room: int) -> Dictionary:
	var spot := {"room": room, "kind": SpotKind.BONUS, "tool_id": "", "amount": 0, "required": false}
	spots.append(spot)
	return spot


## Holds a separator for a link whose kind is decided later (the generator
## builds its tree first); release_separator() frees it again.
func reserve_separator(band: int, separator: int) -> void:
	_use_slot(band, separator, -1)


func release_separator(band: int, separator: int) -> void:
	_used_slots.erase("%d:%d" % [band, separator])


func is_side_free(room: int, side: int) -> bool:
	return not _used_sides.has("%d:%d" % [room, side])


## Interior columns of a room where nothing is built: the floor a lemming
## paces on, where the entrance, the exit and items can go.
func free_floor_columns(room: int) -> Array[int]:
	var blocked := {}
	for link in links:
		for column in link.get("blocked_columns", {}).get(room, []):
			blocked[column] = true
	var columns: Array[int] = []
	for column in range(first_column(room), last_column(room) + 1):
		if not blocked.has(column):
			columns.append(column)
	return columns


func get_link(link_id: int) -> Dictionary:
	return links[link_id]


func spots_in(room: int) -> int:
	var count := 0
	for spot in spots:
		if spot.room == room:
			count += 1
	return count


func _is_slot_free(band: int, separator: int) -> bool:
	return not _used_slots.has("%d:%d" % [band, separator])


func _use_side(room: int, side: int, link_id: int) -> void:
	_used_sides["%d:%d" % [room, side]] = link_id


func _use_slot(band: int, separator: int, link_id: int) -> void:
	_used_slots["%d:%d" % [band, separator]] = link_id


## Fields every link has: kind; a, b: node ids (a is where a one-way link
## starts); two_way: an obstacle that can be opened from either end and then
## joins them both ways; tools: the tool ids that open it (empty: free);
## disabled_by: link ids whose opening removes this free link. Geometry fields
## depend on the kind (see MazePainter).
func _add_link(fields: Dictionary) -> int:
	var link := {
		"kind": LinkKind.OPEN, "a": -1, "b": -1, "two_way": false,
		"tools": [] as Array[String], "disabled_by": [] as Array[int],
	}
	link.merge(fields, true)
	link["id"] = links.size()
	links.append(link)
	return link.id


static func _merged(base: Dictionary, extra: Dictionary) -> Dictionary:
	var result := base.duplicate()
	result.merge(extra, true)
	return result
