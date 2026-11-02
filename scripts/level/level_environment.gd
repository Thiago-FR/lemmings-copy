class_name LevelEnvironment
extends Resource
## The setting a level takes place in: what is drawn behind it and around
## it. Kept as one resource so a level (or a procedural generator) picks a
## whole coherent setting by name, and a cave never gets a blue sky behind
## it.
##
## Today only the backdrop depends on it (LevelBackground and the rock frame
## of LevelBackdrop); the terrain tiles are the same everywhere. When tile
## sets per setting exist, they belong here too.

enum Kind { SURFACE, CAVE }

@export var kind: Kind = Kind.SURFACE
## Background gradient, top of the screen to the bottom.
@export var sky_top: Color = Color(0.36, 0.52, 0.72)
@export var sky_bottom: Color = Color(0.78, 0.70, 0.58)
## Silhouettes in front of the gradient, far to near. Each scrolls slower
## than the level (parallax), the far one slowest.
@export var far_layer: Color = Color(0.42, 0.50, 0.58)
@export var near_layer: Color = Color(0.30, 0.38, 0.36)
## Tint of the solid rock drawn outside the level's bounds.
@export var frame_tint: Color = Color(0.55, 0.50, 0.48)


static func by_kind(environment_kind: Kind) -> LevelEnvironment:
	return cave() if environment_kind == Kind.CAVE else surface()


## Open air: a dusk sky over distant hills.
static func surface() -> LevelEnvironment:
	return LevelEnvironment.new()


## Underground: no sky; dark rock walls with stalactites in the distance.
static func cave() -> LevelEnvironment:
	var environment := LevelEnvironment.new()
	environment.kind = Kind.CAVE
	environment.sky_top = Color(0.07, 0.06, 0.08)
	environment.sky_bottom = Color(0.18, 0.15, 0.14)
	environment.far_layer = Color(0.13, 0.11, 0.11)
	environment.near_layer = Color(0.20, 0.16, 0.14)
	environment.frame_tint = Color(0.40, 0.36, 0.34)
	return environment
