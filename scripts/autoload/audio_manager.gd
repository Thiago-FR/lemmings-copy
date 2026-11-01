extends Node
## Plays music (single stream, crossfadable later) and sound effects
## (pooled players so overlapping sfx don't cut each other off).

const SFX_PLAYER_POOL_SIZE = 8

@onready var _music_player: AudioStreamPlayer = _create_player("MusicPlayer")

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player_index: int = 0


func _ready() -> void:
	for i in range(SFX_PLAYER_POOL_SIZE):
		_sfx_players.append(_create_player("SfxPlayer%d" % i))


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := _sfx_players[_next_sfx_player_index]
	_next_sfx_player_index = (_next_sfx_player_index + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func _create_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	add_child(player)
	return player
