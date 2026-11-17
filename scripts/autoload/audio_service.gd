extends Node

## Plays streams on the Music, SFX, and Ambience buses.

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_AMBIENCE := "Ambience"

var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer


func _ready() -> void:
	_music = _make_player(BUS_MUSIC)
	_ambience = _make_player(BUS_AMBIENCE)


func play_music(stream: AudioStream) -> void:
	_play(BUS_MUSIC, _music, stream)


func play_music_path(path: String) -> void:
	play_music(_load_stream(path))


func stop_music() -> void:
	_music.stop()


func play_ambience(stream: AudioStream) -> void:
	_play(BUS_AMBIENCE, _ambience, stream)


func play_ambience_path(path: String) -> void:
	play_ambience(_load_stream(path))


func stop_ambience() -> void:
	_ambience.stop()


func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := _make_player(BUS_SFX)
	player.stream = stream
	player.finished.connect(player.queue_free)
	player.play()


func play_sfx_path(path: String) -> void:
	play_sfx(_load_stream(path))


func set_bus_volume_db(bus_name: String, volume_db: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_error("AudioService has no bus named %s." % bus_name)
		return
	AudioServer.set_bus_volume_db(index, volume_db)


func _make_player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	return player


func _play(bus_name: String, player: AudioStreamPlayer, stream: AudioStream) -> void:
	if stream == null:
		return
	if AudioServer.get_bus_index(bus_name) < 0:
		push_error("AudioService has no bus named %s." % bus_name)
		return
	player.stream = stream
	player.play()


func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_error("AudioService could not find %s." % path)
		return null
	var resource := load(path)
	if resource is AudioStream:
		return resource
	push_error("AudioService expected an audio stream at %s." % path)
	return null
