class_name LevelEnvironment
extends Resource
## The setting a level takes place in: what is drawn behind it and around
## it, and the look of its blocks, entrance and exit. Kept as one resource
## so a level (or a procedural generator) picks a whole coherent setting by
## name, and a cave never gets a blue sky behind it nor a desert grass.
##
## The backdrop (LevelBackground and the rock frame of LevelBackdrop) is
## drawn from the values here. The terrain, entrance and exit only take the
## name of an art theme (terrain_theme): the same tiles and collision in
## every setting, with textures drawn by tools/build_terrain_themes.py.

## Appended to, never reordered: levels store the kind as a number.
enum Kind { SURFACE, CAVE, DESERT, CRYSTAL_CAVE, SNOWFIELD, VOLCANO }
## The silhouettes drawn in front of the gradient.
enum Skyline { HILLS, HANGING, DUNES, PEAKS }

@export var kind: Kind = Kind.SURFACE
## Background gradient, top of the screen to the bottom.
@export var sky_top: Color = Color(0.36, 0.52, 0.72)
@export var sky_bottom: Color = Color(0.78, 0.70, 0.58)
@export var skyline: Skyline = Skyline.HILLS
## Silhouettes in front of the gradient, far to near. Each scrolls slower
## than the level (parallax), the far one slowest.
@export var far_layer: Color = Color(0.42, 0.50, 0.58)
@export var near_layer: Color = Color(0.30, 0.38, 0.36)
## Snow on the tops of PEAKS (transparent: none).
@export var peak_cap: Color = Color(1, 1, 1, 0)
## Tint of the solid rock drawn outside the level's bounds.
@export var frame_tint: Color = Color(0.55, 0.50, 0.48)
## Folder under assets/sprites/terrain/themes/ (and level/themes/) with the
## blocks, entrance and exit of this setting. Empty: the default earth.
@export var terrain_theme: StringName = &""
## A disc in the sky (sun, moon), centred at a fraction of the screen.
## Radius 0: none.
@export var sun_radius: float = 0.0
@export var sun_position: Vector2 = Vector2(0.75, 0.22)
@export var sun_colour: Color = Color(1.0, 0.95, 0.75)
## Tiny lights that twinkle in place (stars, glints in a crystal cave).
@export var sparkle_count: int = 0
@export var sparkle_colour: Color = Color(1, 1, 1)
## Specks drifting across the screen (snow falling, embers rising), in
## screen pixels per second.
@export var drift_count: int = 0
@export var drift_colour: Color = Color(1, 1, 1)
@export var drift_velocity: Vector2 = Vector2(0, 30)
## Crystal shards rising from the bottom of the screen (transparent: none).
@export var shard_colour: Color = Color(1, 1, 1, 0)


static func by_kind(environment_kind: Kind) -> LevelEnvironment:
	match environment_kind:
		Kind.CAVE:
			return cave()
		Kind.DESERT:
			return desert()
		Kind.CRYSTAL_CAVE:
			return crystal_cave()
		Kind.SNOWFIELD:
			return snowfield()
		Kind.VOLCANO:
			return volcano()
	return surface()


## Open air: a dusk sky over distant hills.
static func surface() -> LevelEnvironment:
	return LevelEnvironment.new()


## Underground: no sky; dark rock walls with stalactites in the distance.
static func cave() -> LevelEnvironment:
	var environment := LevelEnvironment.new()
	environment.kind = Kind.CAVE
	environment.skyline = Skyline.HANGING
	environment.sky_top = Color(0.07, 0.06, 0.08)
	environment.sky_bottom = Color(0.18, 0.15, 0.14)
	environment.far_layer = Color(0.13, 0.11, 0.11)
	environment.near_layer = Color(0.20, 0.16, 0.14)
	environment.frame_tint = Color(0.40, 0.36, 0.34)
	return environment


## Dunes under a hot, pale sun; sandstone blocks and carved stone slabs.
static func desert() -> LevelEnvironment:
	var environment := LevelEnvironment.new()
	environment.kind = Kind.DESERT
	environment.skyline = Skyline.DUNES
	environment.sky_top = Color(0.93, 0.62, 0.36)
	environment.sky_bottom = Color(0.99, 0.88, 0.62)
	environment.far_layer = Color(0.86, 0.62, 0.40)
	environment.near_layer = Color(0.74, 0.48, 0.28)
	environment.frame_tint = Color(0.80, 0.66, 0.50)
	environment.terrain_theme = &"sand"
	environment.sun_radius = 70.0
	environment.sun_position = Vector2(0.72, 0.24)
	environment.sun_colour = Color(1.0, 0.97, 0.82)
	return environment


## A cavern of blue rock lit by glowing crystals.
static func crystal_cave() -> LevelEnvironment:
	var environment := LevelEnvironment.new()
	environment.kind = Kind.CRYSTAL_CAVE
	environment.skyline = Skyline.HANGING
	environment.sky_top = Color(0.04, 0.04, 0.10)
	environment.sky_bottom = Color(0.10, 0.12, 0.24)
	environment.far_layer = Color(0.08, 0.09, 0.18)
	environment.near_layer = Color(0.12, 0.13, 0.25)
	environment.frame_tint = Color(0.42, 0.44, 0.62)
	environment.terrain_theme = &"crystal"
	environment.sparkle_count = 70
	environment.sparkle_colour = Color(0.6, 1.0, 1.0)
	environment.shard_colour = Color(0.30, 0.75, 0.85, 0.55)
	return environment


## High mountains under a cold sky, with snow falling.
static func snowfield() -> LevelEnvironment:
	var environment := LevelEnvironment.new()
	environment.kind = Kind.SNOWFIELD
	environment.skyline = Skyline.PEAKS
	environment.sky_top = Color(0.42, 0.58, 0.80)
	environment.sky_bottom = Color(0.86, 0.91, 0.96)
	environment.far_layer = Color(0.58, 0.67, 0.80)
	environment.near_layer = Color(0.40, 0.48, 0.62)
	environment.peak_cap = Color(0.96, 0.98, 1.0)
	environment.frame_tint = Color(0.66, 0.74, 0.86)
	environment.terrain_theme = &"snow"
	environment.drift_count = 90
	environment.drift_colour = Color(1, 1, 1, 0.85)
	environment.drift_velocity = Vector2(-12, 38)
	return environment


## Black peaks against a smouldering sky, embers rising.
static func volcano() -> LevelEnvironment:
	var environment := LevelEnvironment.new()
	environment.kind = Kind.VOLCANO
	environment.skyline = Skyline.PEAKS
	environment.sky_top = Color(0.10, 0.04, 0.05)
	environment.sky_bottom = Color(0.62, 0.20, 0.08)
	environment.far_layer = Color(0.22, 0.09, 0.08)
	environment.near_layer = Color(0.12, 0.06, 0.06)
	environment.peak_cap = Color(1.0, 0.45, 0.12, 0.9)
	environment.frame_tint = Color(0.42, 0.32, 0.30)
	environment.terrain_theme = &"basalt"
	environment.sun_radius = 46.0
	environment.sun_position = Vector2(0.25, 0.20)
	environment.sun_colour = Color(1.0, 0.55, 0.30, 0.55)
	environment.drift_count = 60
	environment.drift_colour = Color(1.0, 0.62, 0.22, 0.9)
	environment.drift_velocity = Vector2(8, -34)
	return environment
