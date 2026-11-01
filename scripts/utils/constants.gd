class_name Constants
extends RefCounted
## Shared gameplay constants. Kept here instead of scattered magic numbers.

const TERRAIN_TILE_SIZE: float = 16.0

# The single most important invariant in this project. Digging skills carve
# whole tiles, so every opening a lemming must pass through is tile-aligned
# and tile-sized. The body therefore has to be strictly smaller than that
# opening, with room to spare on each side.
#
# Both halves of this matter, and both were wrong before:
#   - A body wider than one tile needs the carve to clear two columns to fit
#     at all, which only happened when it happened to straddle a boundary.
#   - A body exactly one tile wide wedges against both walls of a one-tile
#     shaft and stops dead even under full gravity, because there is no room
#     for the physics engine to separate it from either side.
# Together those produced the original symptom: the hole got dug, and the
# lemming sometimes went through it and sometimes did not.
#
# LemmingController asserts this on spawn, and the placeholder art is
# generated at exactly these dimensions so the two cannot drift apart.
const BODY_TILE_CLEARANCE: float = 2.0
const MAX_BODY_WIDTH: float = TERRAIN_TILE_SIZE - 2.0 * BODY_TILE_CLEARANCE
const MAX_BODY_HEIGHT: float = 2.0 * TERRAIN_TILE_SIZE - 2.0 * BODY_TILE_CLEARANCE

const GRAVITY: float = 900.0
# Lemmings spawn 1-2s apart, so this also sets how far apart they look in a
# crowd: too slow and consecutive lemmings overlap into an unreadable blob.
# At one body width (16px) per ~0.3s they stay visibly separated.
const WALK_SPEED: float = 50.0
const CLIMB_SPEED: float = 18.0
const FLOAT_FALL_SPEED: float = 30.0
const MAX_SAFE_FALL_HEIGHT: float = 60.0
const TERMINAL_FALL_SPEED: float = 600.0

# Safety net for falling into a bottomless gap (e.g. Digger/Miner breaking
# through the only floor with nothing underneath): _land() only fires on
# landing, so without this a lemming that never hits ground again falls
# forever — never saved, never counted as lost, and the level can then
# never finish on its own since it's permanently waiting on that one lemming.
const VOID_FALL_DISTANCE: float = 500.0

# One tile per step, matching the invariant above: a half-tile step would
# place two consecutive steps inside the same cell, so the staircase the
# lemming climbs and the staircase actually built would drift apart.
const BUILDER_STEP_WIDTH: float = TERRAIN_TILE_SIZE
const BUILDER_STEP_HEIGHT: float = TERRAIN_TILE_SIZE
const BUILDER_MAX_STEPS: int = 12
const BUILDER_STEP_INTERVAL_SECONDS: float = 0.3

# Digger/Basher/Miner advance exactly one terrain tile per step (rather than
# a smaller sub-tile amount) so each tick's carve always targets a fresh
# cell instead of re-checking one it already cleared, which would otherwise
# look like "nothing left to dig" after a single tile.
const DIGGER_DIG_INTERVAL_SECONDS: float = 0.15
const DIGGER_STEP_HEIGHT: float = TERRAIN_TILE_SIZE

const BASHER_DIG_INTERVAL_SECONDS: float = 0.15
const BASHER_STEP_WIDTH: float = TERRAIN_TILE_SIZE
const BASHER_MAX_DURATION_SECONDS: float = 6.0

const MINER_DIG_INTERVAL_SECONDS: float = 0.2
const MINER_STEP_WIDTH: float = TERRAIN_TILE_SIZE
const MINER_STEP_HEIGHT: float = TERRAIN_TILE_SIZE

const BOMBER_FUSE_SECONDS: float = 5.0
const BOMBER_EXPLOSION_RADIUS: float = 24.0

const LEMMING_COLLISION_LAYER: int = 1
const TERRAIN_COLLISION_LAYER: int = 2

# CharacterBody2D can rest a fraction of a pixel short of the collision
# boundary (safe_margin/floor snap slack). Without this, a probe placed
# exactly at the collision shape's edge (see LemmingController.get_body_rect)
# can land in the empty cell just outside the lemming instead of the solid
# one it's standing/facing against, which made Digger/Basher/Miner/Builder
# silently find "nothing there" on their very first tick.
const GROUND_PROBE_EPSILON: float = 2.0

# Obstructions up to this tall are walked up onto automatically (a Builder
# step, the lip left by Digger/Miner) instead of being treated as a wall
# that needs Climber. One terrain tile, matching the original game not
# needing a skill for a single step.
const STEP_MAX_HEIGHT: float = TERRAIN_TILE_SIZE
