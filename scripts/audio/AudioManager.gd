extends Node
## DRAA AudioManager (autoload).
## Procedural SFX (no binary assets needed): short synthesized blips for
## UI / attack / hit / countdown / victory. Buses respect user toggles.
## Voice reactions are short text-triggered stingers for now; Arabic voice
## recordings plug into play_voice() in Phase 8 without API change.

var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
const POOL := 8


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	add_child(_music_player)
	_apply_volumes()
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		sm.settings_changed.connect(_apply_volumes)


func _apply_volumes() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	var master := float(sm.get_setting("master_volume", 0.8))
	var music := float(sm.get_setting("music_volume", 0.7))
	var sfx := float(sm.get_setting("sfx_volume", 0.9))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.001)))
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	if mi >= 0:
		AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(music, 0.001)))
		AudioServer.set_bus_mute(mi, not bool(sm.get_setting("music_enabled", true)))
	if si >= 0:
		AudioServer.set_bus_volume_db(si, linear_to_db(maxf(sfx, 0.001)))
		AudioServer.set_bus_mute(si, not bool(sm.get_setting("sfx_enabled", true)))


func _tone(freq: float, duration: float, volume: float = 0.5, slide_to: float = 0.0) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / rate
		var f := freq + (slide_to - freq) * (float(i) / maxf(1.0, float(frames))) if slide_to > 0.0 else freq
		var env := 1.0 - float(i) / float(frames) # linear decay, no clicks
		var s := sin(TAU * f * t) * env * volume
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


func _play(stream: AudioStream) -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and not bool(sm.get_setting("sfx_enabled", true)):
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	_players[0].stream = stream
	_players[0].play()


func play_ui() -> void:
	_play(_tone(660.0, 0.08, 0.35))


func play_attack(element: String = "fire") -> void:
	match element:
		"ice":
			_play(_tone(880.0, 0.12, 0.4, 440.0))
		"lightning":
			_play(_tone(1200.0, 0.09, 0.4, 300.0))
		"shadow":
			_play(_tone(220.0, 0.16, 0.45, 110.0))
		_:
			_play(_tone(330.0, 0.12, 0.45, 660.0))


func play_hit(heavy: bool = false) -> void:
	_play(_tone(150.0 if heavy else 220.0, 0.14 if heavy else 0.09, 0.6, 70.0))
	_vibrate(30 if not heavy else 60)


func play_dash() -> void:
	_play(_tone(500.0, 0.1, 0.3, 900.0))


func play_countdown(final: bool = false) -> void:
	_play(_tone(880.0 if final else 440.0, 0.18 if final else 0.12, 0.5))


func play_victory() -> void:
	_play(_tone(523.0, 0.35, 0.5, 1046.0))


func play_defeat() -> void:
	_play(_tone(392.0, 0.4, 0.45, 196.0))


func play_perfect() -> void:
	# Perfect-dodge reward sting: two rising tones on separate pool voices.
	_play(_tone(660.0, 0.09, 0.4, 880.0))
	_play(_tone(990.0, 0.14, 0.4))


func play_telegraph() -> void:
	# Hazard warn ping: one high blip as the target ring appears.
	_play(_tone(1174.0, 0.12, 0.35))


func play_land() -> void:
	# Soft landing thud (squash timing cue, not a hit).
	_play(_tone(120.0, 0.09, 0.3, 60.0))


func play_voice(_line_id: String) -> void:
	# Slot for Arabic voice-over clips (Phase 8). Currently a subtle sting
	# so reactions still have audio feedback with zero binary assets.
	_play(_tone(740.0, 0.1, 0.25, 980.0))


func _vibrate(ms: int) -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and bool(sm.get_setting("vibration", true)):
		Input.vibrate_handheld(ms)
