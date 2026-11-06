class_name ExplosiveCharge
extends Node2D
## A charge of dynamite or TNT a lemming has put down (see SkillExplosive).
## Its origin is the point on the ground it rests on. It shows its fuse
## burning with the seconds left, then blows up: every terrain cell in its
## blast is destroyed (floor and concrete included), every lemming the blast
## touches dies, and an explosion plays.
##
## A node of its own rather than part of the lemming, because the lemming
## walks away and may be long gone, or dead, when it goes off.

enum Look { DYNAMITE, TNT }

const DYNAMITE_COLOUR := Color(0.80, 0.16, 0.14)
const TNT_COLOUR := Color(0.62, 0.20, 0.12)
const LABEL_COLOUR := Color(1, 0.95, 0.85)
const FUSE_COLOUR := Color(0.85, 0.82, 0.70)
const SPARK_COLOURS: Array[Color] = [Color(1, 0.9, 0.3), Color(1, 0.55, 0.15)]
## Sizes in pixels, drawn upwards from the ground point.
const DYNAMITE_STICK_SIZE := Vector2(4, 11)
const DYNAMITE_STICK_GAP := 1.0
const TNT_BOX_SIZE := Vector2(16, 11)
const FUSE_LENGTH := 5.0
const COUNTDOWN_FONT_SIZE := 10
## How often the spark at the fuse's tip changes colour, in seconds.
const SPARK_FLICKER_SECONDS := 0.08

var terrain: TerrainDestructible
var fuse_seconds: float = 3.0
var blast_radius_tiles: int = 1
var look: Look = Look.DYNAMITE
## The tool that laid it (TerrainDestructible.cell_broken's breaker).
var tool_id: StringName = &""

var _elapsed := 0.0


func _ready() -> void:
	assert(terrain != null, "ExplosiveCharge needs the terrain it will blow up")


func _physics_process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= fuse_seconds:
		_explode()


## Every cell whose offset from the charge's own cell satisfies
## dx² + dy² <= r² + 1 (see SkillExplosive.blast_radius_tiles).
func get_blast_cells() -> Array[Vector2i]:
	# The cell the charge sits in: just above the ground point.
	var centre := terrain.local_to_map(terrain.to_local(global_position + Vector2.UP))
	var reach_squared := blast_radius_tiles * blast_radius_tiles + 1
	var cells: Array[Vector2i] = []
	for dy in range(-blast_radius_tiles, blast_radius_tiles + 1):
		for dx in range(-blast_radius_tiles, blast_radius_tiles + 1):
			if dx * dx + dy * dy <= reach_squared:
				cells.append(centre + Vector2i(dx, dy))
	return cells


func _explode() -> void:
	var blast_rects: Array[Rect2] = []
	for cell in get_blast_cells():
		var centre := terrain.to_global(terrain.map_to_local(cell))
		blast_rects.append(terrain.cell_rect_at(centre))
		terrain.destroy_cell_at(centre, tool_id)
	_kill_lemmings_in(blast_rects)
	AudioManager.play_sound(&"explosion")
	var blast_radius := (blast_radius_tiles + 0.5) * terrain.get_cell_size().x
	ExplosionEffect.spawn(get_parent(), global_position + Vector2.UP * terrain.get_cell_size().y / 2.0, blast_radius)
	queue_free()


func _kill_lemmings_in(blast_rects: Array[Rect2]) -> void:
	for node in get_tree().get_nodes_in_group("lemmings"):
		var lemming := node as LemmingController
		if lemming == null or not lemming.state_machine.is_alive():
			continue
		var body := lemming.get_body_rect()
		for rect in blast_rects:
			if rect.intersects(body):
				lemming.die(LemmingController.DeathCause.EXPLOSION)
				break


func _draw() -> void:
	var top := _draw_body()
	var fuse_tip := top + Vector2(2, -FUSE_LENGTH)
	draw_line(top, fuse_tip, FUSE_COLOUR, 1.0)
	var spark := SPARK_COLOURS[int(_elapsed / SPARK_FLICKER_SECONDS) % SPARK_COLOURS.size()]
	draw_circle(fuse_tip, 1.5, spark)
	var seconds_left := ceili(maxf(fuse_seconds - _elapsed, 0.0))
	draw_string(ThemeDB.fallback_font, fuse_tip + Vector2(-3, -3), str(seconds_left), HORIZONTAL_ALIGNMENT_LEFT, -1, COUNTDOWN_FONT_SIZE, LABEL_COLOUR)


## Draws the charge itself standing on the ground point and returns where
## its fuse starts.
func _draw_body() -> Vector2:
	if look == Look.TNT:
		var box := Rect2(Vector2(-TNT_BOX_SIZE.x / 2.0, -TNT_BOX_SIZE.y), TNT_BOX_SIZE)
		draw_rect(box, TNT_COLOUR)
		draw_rect(box, Color.BLACK, false, 1.0)
		draw_string(ThemeDB.fallback_font, box.position + Vector2(1, 9), "TNT", HORIZONTAL_ALIGNMENT_LEFT, TNT_BOX_SIZE.x, 7, LABEL_COLOUR)
		return Vector2(0, box.position.y)
	# Three sticks taped together.
	var total_width := DYNAMITE_STICK_SIZE.x * 3 + DYNAMITE_STICK_GAP * 2
	for stick in 3:
		var x := -total_width / 2.0 + stick * (DYNAMITE_STICK_SIZE.x + DYNAMITE_STICK_GAP)
		draw_rect(Rect2(Vector2(x, -DYNAMITE_STICK_SIZE.y), DYNAMITE_STICK_SIZE), DYNAMITE_COLOUR)
	draw_rect(Rect2(Vector2(-total_width / 2.0, -DYNAMITE_STICK_SIZE.y * 0.6), Vector2(total_width, 2)), Color(0.2, 0.2, 0.2))
	return Vector2(0, -DYNAMITE_STICK_SIZE.y)
