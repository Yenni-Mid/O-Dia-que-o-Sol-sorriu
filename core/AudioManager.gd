extends Node
## Gerenciador global de áudio com síntese procedural de efeitos (passos, lampião, porta, alerta, drone solar e batimento cardíaco).

const MIX_RATE: int = 22050

var _sfx_player: AudioStreamPlayer
var _step_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _sun_drone_player: AudioStreamPlayer

var _stream_footstep: AudioStreamWAV
var _stream_ignite: AudioStreamWAV
var _stream_extinguish: AudioStreamWAV
var _stream_door: AudioStreamWAV
var _stream_alert: AudioStreamWAV
var _stream_heartbeat: AudioStreamWAV
var _stream_sun_drone: AudioStreamWAV

var _heartbeat_intensity: float = 0.0
var _heartbeat_timer: float = 0.0


func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SFXPlayer"
	add_child(_sfx_player)

	_step_player = AudioStreamPlayer.new()
	_step_player.name = "StepPlayer"
	add_child(_step_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	add_child(_ambience_player)

	_sun_drone_player = AudioStreamPlayer.new()
	_sun_drone_player.name = "SunDronePlayer"
	_sun_drone_player.volume_db = -11.0
	add_child(_sun_drone_player)

	_build_procedural_streams()


func _process(delta: float) -> void:
	if _heartbeat_intensity <= 0.05:
		return
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0:
		var interval: float = lerpf(1.1, 0.48, clampf(_heartbeat_intensity, 0.0, 1.0))
		_heartbeat_timer = interval
		if _step_player != null and _stream_heartbeat != null:
			_step_player.stream = _stream_heartbeat
			_step_player.pitch_scale = 1.0
			_step_player.volume_db = lerpf(-14.0, -3.0, clampf(_heartbeat_intensity, 0.0, 1.0))
			_step_player.play()


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null or _sfx_player == null:
		return
	_sfx_player.stream = stream
	_sfx_player.pitch_scale = 1.0
	_sfx_player.volume_db = volume_db
	_sfx_player.play()


func play_footstep(volume_db: float = -10.0, pitch: float = 1.0) -> void:
	if _step_player == null or _stream_footstep == null:
		return
	_step_player.stream = _stream_footstep
	_step_player.volume_db = volume_db
	_step_player.pitch_scale = pitch
	_step_player.play()


func play_lantern_ignite() -> void:
	play_sfx(_stream_ignite, -5.0)


func play_lantern_extinguish() -> void:
	play_sfx(_stream_extinguish, -6.0)


func play_door_creak() -> void:
	play_sfx(_stream_door, -6.0)


func play_enemy_alert() -> void:
	play_sfx(_stream_alert, -5.0)


func set_sun_drone_active(active: bool) -> void:
	if _sun_drone_player == null or _stream_sun_drone == null:
		return
	if active:
		if not _sun_drone_player.playing:
			_sun_drone_player.stream = _stream_sun_drone
			_sun_drone_player.play()
	else:
		if _sun_drone_player.playing:
			_sun_drone_player.stop()


func set_heartbeat_intensity(intensity: float) -> void:
	_heartbeat_intensity = clampf(intensity, 0.0, 1.0)


func play_ambience(stream: AudioStream, volume_db: float = -6.0) -> void:
	if stream == null or _ambience_player == null:
		return
	if _ambience_player.stream == stream and _ambience_player.playing:
		return
	_ambience_player.stream = stream
	_ambience_player.volume_db = volume_db
	_ambience_player.play()


func stop_ambience() -> void:
	if _ambience_player != null and _ambience_player.playing:
		_ambience_player.stop()


func _build_procedural_streams() -> void:
	_stream_footstep = _synth_wave(0.09, 95.0, 45.0, 0.55, false)
	_stream_ignite = _synth_wave(0.18, 520.0, 180.0, 0.85, false)
	_stream_extinguish = _synth_wave(0.24, 300.0, 90.0, 0.9, false)
	_stream_door = _synth_wave(0.32, 140.0, 210.0, 0.2, false)
	_stream_alert = _synth_wave(0.28, 370.0, 185.0, 0.25, false)
	_stream_heartbeat = _synth_wave(0.16, 58.0, 38.0, 0.1, false)
	_stream_sun_drone = _synth_wave(1.5, 112.0, 116.0, 0.35, true)


func _synth_wave(duration: float, freq_start: float, freq_end: float, noise_mix: float, loop_enabled: bool) -> AudioStreamWAV:
	var sample_count: int = int(duration * float(MIX_RATE))
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(sample_count * 2)
	var phase: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(freq_start * 100.0 + duration * 1000.0)

	for i: int in range(sample_count):
		var t: float = float(i) / float(max(1, sample_count - 1))
		var env: float = 1.0 if loop_enabled else pow(1.0 - t, 1.8)
		var freq: float = lerpf(freq_start, freq_end, t)
		phase += TAU * freq / float(MIX_RATE)
		var tone: float = sin(phase) * 0.65 + sin(phase * 1.5) * 0.35
		var noise: float = rng.randf_range(-1.0, 1.0)
		var sample_val: float = lerpf(tone, noise, noise_mix) * env * 0.45
		var pcm: int = clampi(int(sample_val * 32767.0), -32768, 32767)
		bytes[i * 2] = pcm & 0xFF
		bytes[i * 2 + 1] = (pcm >> 8) & 0xFF

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop_enabled:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = sample_count
	return wav
