class_name Constants
extends RefCounted
## Shared gameplay constants. Kept here instead of scattered magic numbers.

const TERRAIN_TILE_SIZE: float = 32.0

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
# This is what sets the terrain tile size. The character is 26x30, so a
# one-tile opening has to be at least 30 wide to take it — which is why the
# grid is 32 and not the 16 it started as. Shrinking the character to fit a
# 16px grid was tried and rejected: it made the art unreadable.
#
# LemmingController asserts this on spawn.
const BODY_TILE_CLEARANCE: float = 2.0
const MAX_BODY_WIDTH: float = TERRAIN_TILE_SIZE - 2.0 * BODY_TILE_CLEARANCE
const MAX_BODY_HEIGHT: float = 2.0 * TERRAIN_TILE_SIZE - 2.0 * BODY_TILE_CLEARANCE

const GRAVITY: float = 900.0
# Lemmings spawn 1-2s apart, so this also sets how far apart they look in a
# crowd: too slow and consecutive lemmings overlap into an unreadable blob.
# At roughly one body width every half second they stay visibly separated.
const WALK_SPEED: float = 50.0
const CLIMB_SPEED: float = 18.0
# Ladders are a deliberate route, not a struggle up a bare wall, so they are
# climbed faster than Climber climbs rock.
const LADDER_CLIMB_SPEED: float = 30.0
## How fast a lemming slides down a rope (SkillRope), in pixels per second.
const ROPE_SLIDE_SPEED: float = 60.0
# How close to a ladder's centre a lemming has to be before it grabs it.
# A walker moves under a pixel per frame, so it always passes within this;
# grabbing anywhere in the ladder's cell would snap the body sideways by up
# to half a tile.
const LADDER_GRAB_DISTANCE: float = 4.0
## How far onto the ground a lemming walks when stepping off the top of a
## ladder (past the ladder's column) or of a climbed wall (past its edge)
## before it carries on walking normally: enough for firm footing, and to be
## clear of LADDER_GRAB_DISTANCE.
const LEDGE_STEP_FOOTING: float = 6.0
## Widest gap, in pixels, a lemming steps over to climb onto what is past
## it. Wider gaps it cannot fall into count as a wall.
const MAX_STEP_OVER_GAP: float = 12.0
const FLOAT_FALL_SPEED: float = 30.0
# Raised from 60 along with the tile size: a vertical gap has to be at least
# two tiles for a 30px-tall body to pass through it (see MAX_BODY_HEIGHT),
# which is 64px, and a 60px safe fall would have killed a lemming dropping
# through the smallest legal gap in the game.
const MAX_SAFE_FALL_HEIGHT: float = 80.0
const TERMINAL_FALL_SPEED: float = 600.0

# Safety net for falling into a bottomless gap (e.g. Digger/Miner breaking
# through the only floor with nothing underneath): _land() only fires on
# landing, so without this a lemming that never hits ground again falls
# forever — never saved, never counted as lost, and the level can then
# never finish on its own since it's permanently waiting on that one lemming.
const VOID_FALL_DISTANCE: float = 500.0

# Skill tuning (dig speed, step counts, fuse length, ...) is not here on
# purpose: each skill carries its own values as exported properties (see
# scripts/skills/), so a skill can be reused and retuned without touching
# anything shared. Step sizes come from the terrain's own cell size.

# Long enough to register as a death, short enough not to hold up a level
# that is waiting on its last lemming. Level counts update immediately on
# death regardless — only the body lingers.
const DEATH_FADE_SECONDS: float = 0.35

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

# How far forward a step-up moves the body along with lifting it, so it lands
# standing on the step instead of hanging beside it. Steps are detected
# GROUND_PROBE_EPSILON ahead of the body, so a little more than that puts the
# leading edge just over the step.
const STEP_UP_FORWARD_NUDGE: float = GROUND_PROBE_EPSILON + 0.5
