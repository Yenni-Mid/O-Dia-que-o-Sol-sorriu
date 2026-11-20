extends Node
## Gerenciador global de áudio com assets reais (Taira Komori) e síntese procedural de fallback.
## Usa um pool de vozes para SFX (sons não se cortam), canais dedicados para passos/batimento
## e fornece getters para o AmbientSoundDirector e atores 3D.

const MIX_RATE: int = 22050
const SFX_POOL_SIZE: int = 8
const SUN_DRONE_DB: float = -11.0
const WIND_DB: float = -19.0
const SILENT_DB: float = -48.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _step_player: AudioStreamPlayer
var _heart_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _sun_drone_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _sun_tween: Tween
var _wind_tween: Tween

var _stream_footstep: AudioStream
var _stream_ignite: AudioStream
var _stream_extinguish: AudioStream
var _stream_door: AudioStream
var _stream_alert: AudioStream
var _stream_heartbeat: AudioStream
var _stream_sun_drone: AudioStream
var _stream_wind: AudioStream
var _stream_hurt: AudioStream
var _stream_pickup: AudioStream
var _stream_ui_click: AudioStream
var _stream_paper: AudioStream
var _stream_whisper: AudioStream
var _stream_breath: AudioStream
var _stream_shadow_hum: AudioStream
var _stream_lunatic_step: AudioStream
var _stream_glass_break: AudioStream
var _stream_unlock: AudioStream
var _stream_locked: AudioStream
var _stream_bell_alarm: AudioStream
var _stream_vhs_static: AudioStream
var _stream_phase_chime: AudioStream
var _stream_metal_cut: AudioStream
var _stream_wood_break: AudioStream
var _stream_radio_static: AudioStream

var _stream_night_crickets: AudioStream
var _stream_indoor_dark: AudioStream
var _stream_sewer_drone: AudioStream
var _stream_fire_loop: AudioStream
var _stream_owl: AudioStream
var _stream_crow: AudioStream
var _stream_sewer_drip: AudioStream
var _stream_dawn_warning: AudioStream
var _stream_menu_hover: AudioStream
var _stream_menu_confirm: AudioStream
var _stream_menu_back: AudioStream
var _stream_dialogue_blip: AudioStream

var _heartbeat_intensity: float = 0.0
var _heartbeat_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in range(SFX_POOL_SIZE):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = "SFXVoice%d" % i
		add_child(voice)
		_sfx_pool.append(voice)

	_step_player = _make_channel("StepPlayer", 0.0)
	_heart_player = _make_channel("HeartPlayer", -10.0)
	_ambience_player = _make_channel("AmbiencePlayer", -6.0)
	_sun_drone_player = _make_channel("SunDronePlayer", SILENT_DB)
	_wind_player = _make_channel("WindPlayer", SILENT_DB)

	_build_procedural_streams()
	_load_external_audio_overrides()


func _exit_tree() -> void:
	if _sun_tween != null and _sun_tween.is_valid():
		_sun_tween.kill()
	if _wind_tween != null and _wind_tween.is_valid():
		_wind_tween.kill()
	_sun_tween = null
	_wind_tween = null
	for ch: Node in get_children():
		if ch is AudioStreamPlayer:
			var ap: AudioStreamPlayer = ch as AudioStreamPlayer
			ap.stop()
			ap.stream = null


func _make_channel(channel_name: String, volume: float) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = channel_name
	p.volume_db = volume
	add_child(p)
	return p


func _process(delta: float) -> void:
	if get_tree().paused or _heartbeat_intensity <= 0.05:
		if _heart_player != null and _heart_player.playing:
			_heart_player.stop()
		return
	var level: float = clampf(_heartbeat_intensity, 0.0, 1.0)
	if _heart_player != null:
		_heart_player.volume_db = lerpf(-16.0, -4.0, level)
		_heart_player.pitch_scale = lerpf(0.92, 1.16, level)
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0:
		_heartbeat_timer = lerpf(1.4, 0.72, level)
		if _stream_heartbeat != null and _heart_player != null and not _heart_player.playing:
			_heart_player.stream = _stream_heartbeat
			_heart_player.play()


# --------------------------------------------------------------------------- API pública

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null or _sfx_pool.is_empty():
		return
	var voice: AudioStreamPlayer = _get_free_voice()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	voice.play()


func play_footstep(volume_db: float = -10.0, pitch: float = 1.0) -> void:
	if _step_player == null or _stream_footstep == null:
		return
	_step_player.stream = _stream_footstep
	_step_player.volume_db = volume_db
	_step_player.pitch_scale = pitch * randf_range(0.92, 1.08)
	_step_player.play()


func play_lantern_ignite() -> void:
	play_sfx(_stream_ignite, -5.0)


func play_lantern_extinguish() -> void:
	play_sfx(_stream_extinguish, -6.0)


func play_door_creak() -> void:
	play_sfx(_stream_door, -6.0, randf_range(0.9, 1.1))


func play_enemy_alert() -> void:
	play_sfx(_stream_alert, -5.0)


func play_hurt() -> void:
	play_sfx(_stream_hurt, -4.0, randf_range(0.9, 1.05))


func play_pickup() -> void:
	play_sfx(_stream_pickup, -7.0)


func play_ui_click() -> void:
	play_sfx(_stream_ui_click, -10.0, randf_range(0.96, 1.04))


func play_menu_hover() -> void:
	play_sfx(_stream_menu_hover if _stream_menu_hover != null else _stream_ui_click, -7.5, randf_range(0.97, 1.03))


func play_menu_confirm() -> void:
	play_sfx(_stream_menu_confirm if _stream_menu_confirm != null else _stream_ignite, -4.5, 1.0)


func play_menu_back() -> void:
	play_sfx(_stream_menu_back if _stream_menu_back != null else _stream_ui_click, -6.5, 0.94)


func play_dialogue_blip(pitch_base: float = 1.0) -> void:
	play_sfx(_stream_dialogue_blip if _stream_dialogue_blip != null else _stream_ui_click, -15.5, pitch_base * randf_range(0.92, 1.08))


func play_paper() -> void:
	play_sfx(_stream_paper, -8.0)


func play_whisper() -> void:
	play_sfx(_stream_whisper, -11.0, randf_range(0.85, 1.1))


func play_breath() -> void:
	play_sfx(_stream_breath, -8.0, randf_range(0.92, 1.08))


func get_door_stream() -> AudioStream:
	return _stream_door


func get_alert_stream() -> AudioStream:
	return _stream_alert


func get_whisper_stream() -> AudioStream:
	return _stream_whisper


func get_shadow_hum_stream() -> AudioStream:
	return _stream_shadow_hum


func get_lunatic_step_stream() -> AudioStream:
	return _stream_lunatic_step


func play_glass_break() -> void:
	play_sfx(_stream_glass_break, -3.0, randf_range(0.92, 1.08))


func get_glass_break_stream() -> AudioStream:
	return _stream_glass_break


func play_unlock() -> void:
	play_sfx(_stream_unlock, -5.0)


func play_locked() -> void:
	play_sfx(_stream_locked, -6.0)


func play_bell_alarm() -> void:
	play_sfx(_stream_bell_alarm, -4.0)


func get_bell_alarm_stream() -> AudioStream:
	return _stream_bell_alarm


func get_vhs_static_stream() -> AudioStream:
	return _stream_vhs_static


func play_phase_chime() -> void:
	play_sfx(_stream_phase_chime, -4.0)


func play_dawn_warning() -> void:
	play_sfx(_stream_dawn_warning, -5.0)


func play_metal_cut() -> void:
	play_sfx(_stream_metal_cut, -4.0)


func play_wood_break() -> void:
	play_sfx(_stream_wood_break, -3.5)


func get_radio_static_stream() -> AudioStream:
	return _stream_radio_static


func get_wind_stream() -> AudioStream:
	return _stream_wind


func get_night_crickets_stream() -> AudioStream:
	return _stream_night_crickets


func get_indoor_dark_stream() -> AudioStream:
	return _stream_indoor_dark


func get_sewer_drone_stream() -> AudioStream:
	return _stream_sewer_drone


func get_fire_loop_stream() -> AudioStream:
	return _stream_fire_loop


func get_owl_stream() -> AudioStream:
	return _stream_owl


func get_crow_stream() -> AudioStream:
	return _stream_crow


func get_sewer_drip_stream() -> AudioStream:
	return _stream_sewer_drip


func set_master_volume(linear: float) -> void:
	var clamped: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(0, clamped <= 0.005)
	if clamped > 0.005:
		AudioServer.set_bus_volume_db(0, linear_to_db(clamped))


func set_sun_drone_active(active: bool) -> void:
	_sun_tween = _fade_loop(_sun_drone_player, _stream_sun_drone, active, SUN_DRONE_DB, _sun_tween)


func set_wind_active(active: bool) -> void:
	_wind_tween = _fade_loop(_wind_player, _stream_wind, active, WIND_DB, _wind_tween)


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


func stop_all_tension() -> void:
	set_sun_drone_active(false)
	set_heartbeat_intensity(0.0)


# --------------------------------------------------------------------------- Internos

func _get_free_voice() -> AudioStreamPlayer:
	for voice: AudioStreamPlayer in _sfx_pool:
		if not voice.playing:
			return voice
	var stolen: AudioStreamPlayer = _sfx_pool[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_pool.size()
	return stolen


func _fade_loop(player: AudioStreamPlayer, stream: AudioStream, active: bool, target_db: float, previous: Tween) -> Tween:
	if player == null or stream == null:
		return previous
	if previous != null and previous.is_valid():
		previous.kill()
	var tw: Tween = create_tween()
	if active:
		if not player.playing:
			player.stream = stream
			player.volume_db = SILENT_DB
			player.play()
		tw.tween_property(player, "volume_db", target_db, 0.7)
	else:
		if not player.playing:
			tw.kill()
			return null
		tw.tween_property(player, "volume_db", SILENT_DB, 0.9)
		tw.tween_callback(player.stop)
	return tw


func _load_audio(res_path: String, fallback: AudioStream, loop_enabled: bool = false) -> AudioStream:
	if not ResourceLoader.exists(res_path):
		return fallback
	var loaded: AudioStream = ResourceLoader.load(res_path) as AudioStream
	if loaded == null:
		return fallback
	if loaded is AudioStreamMP3:
		(loaded as AudioStreamMP3).loop = loop_enabled
	return loaded


func _load_external_audio_overrides() -> void:
	_stream_wind = _load_audio("res://assets/audio/amb_night_wind.mp3", _stream_wind, true)
	_stream_night_crickets = _load_audio("res://assets/audio/amb_night_crickets.mp3", _stream_wind, true)
	_stream_indoor_dark = _load_audio("res://assets/audio/amb_indoor_dark.mp3", _stream_shadow_hum, true)
	_stream_sewer_drone = _load_audio("res://assets/audio/amb_sewer_drone.mp3", _stream_shadow_hum, true)
	_stream_fire_loop = _load_audio("res://assets/audio/amb_fire_loop.mp3", _stream_wind, true)
	_stream_sun_drone = _load_audio("res://assets/audio/amb_sun_drone.mp3", _stream_sun_drone, true)
	_stream_owl = _load_audio("res://assets/audio/amb_owl.mp3", null, false)
	_stream_crow = _load_audio("res://assets/audio/amb_crow.mp3", null, false)
	_stream_sewer_drip = _load_audio("res://assets/audio/sfx_sewer_drip.mp3", null, false)
	_stream_dawn_warning = _load_audio("res://assets/audio/sfx_dawn_warning.mp3", _stream_phase_chime, false)

	_stream_door = _load_audio("res://assets/audio/sfx_door_creak.mp3", _stream_door, false)
	_stream_unlock = _load_audio("res://assets/audio/sfx_unlock.mp3", _stream_unlock, false)
	_stream_locked = _load_audio("res://assets/audio/sfx_locked.mp3", _stream_locked, false)
	_stream_glass_break = _load_audio("res://assets/audio/sfx_glass_break.mp3", _stream_glass_break, false)
	_stream_bell_alarm = _load_audio("res://assets/audio/sfx_hell_bell.mp3", _stream_bell_alarm, false)
	_stream_alert = _load_audio("res://assets/audio/sfx_enemy_alert.mp3", _stream_alert, false)
	_stream_whisper = _load_audio("res://assets/audio/sfx_whisper.mp3", _stream_whisper, false)
	_stream_heartbeat = _load_audio("res://assets/audio/sfx_heartbeat.mp3", _stream_heartbeat, false)
	_stream_wood_break = _load_audio("res://assets/audio/sfx_wood_break.mp3", _stream_wood_break, false)
	_stream_metal_cut = _load_audio("res://assets/audio/sfx_metal_cut.mp3", _stream_metal_cut, false)
	_stream_paper = _load_audio("res://assets/audio/sfx_paper.mp3", _stream_paper, false)
	_stream_pickup = _load_audio("res://assets/audio/sfx_pickup.mp3", _stream_pickup, false)
	_stream_ui_click = _load_audio("res://assets/audio/sfx_ui_click.mp3", _stream_ui_click, false)
	_stream_radio_static = _load_audio("res://assets/audio/sfx_radio_static.mp3", _stream_radio_static, true)
	_stream_vhs_static = _load_audio("res://assets/audio/sfx_vhs_static.mp3", _stream_vhs_static, true)
	_stream_hurt = _load_audio("res://assets/audio/sfx_hurt.mp3", _stream_hurt, false)
	_stream_ignite = _load_audio("res://assets/audio/sfx_lantern_ignite.mp3", _stream_ignite, false)


func _build_procedural_streams() -> void:
	_stream_footstep = _synth_wave(0.09, 95.0, 45.0, 0.55, false)
	_stream_ignite = _synth_wave(0.18, 520.0, 180.0, 0.85, false)
	_stream_extinguish = _synth_wave(0.24, 300.0, 90.0, 0.9, false)
	_stream_door = _synth_wave(0.32, 140.0, 210.0, 0.2, false)
	_stream_alert = _synth_wave(0.28, 370.0, 185.0, 0.25, false)
	_stream_heartbeat = _synth_wave(0.16, 58.0, 38.0, 0.1, false)
	_stream_sun_drone = _synth_wave(1.5, 112.0, 116.0, 0.35, true)
	_stream_hurt = _synth_wave(0.22, 140.0, 55.0, 0.6, false)
	_stream_pickup = _synth_wave(0.20, 420.0, 880.0, 0.05, false)
	_stream_ui_click = _synth_wave(0.04, 900.0, 600.0, 0.3, false)
	_stream_paper = _synth_noise_burst(0.28, 0.55, 11)
	_stream_whisper = _synth_noise_burst(1.3, 0.35, 23)
	_stream_wind = _synth_noise_loop(4.0, 0.025, 31)
	_stream_breath = _synth_noise_burst(0.45, 0.25, 41)
	_stream_shadow_hum = _synth_wave(2.0, 56.0, 62.0, 0.45, true)
	_stream_lunatic_step = _synth_wave(0.11, 72.0, 32.0, 0.6, false)
	_stream_glass_break = _synth_noise_burst(0.32, 0.85, 53)
	_stream_unlock = _synth_wave(0.16, 620.0, 940.0, 0.15, false)
	_stream_locked = _synth_wave(0.12, 130.0, 90.0, 0.4, false)
	_stream_bell_alarm = _synth_wave(1.1, 440.0, 415.0, 0.08, false)
	_stream_vhs_static = _synth_noise_loop(2.5, 0.65, 67)
	_stream_phase_chime = _synth_wave(1.4, 98.0, 65.0, 0.2, false)
	_stream_metal_cut = _synth_wave(0.24, 960.0, 320.0, 0.72, false)
	_stream_wood_break = _synth_noise_burst(0.36, 0.45, 79)
	_stream_radio_static = _synth_noise_loop(2.2, 0.42, 91)
	_stream_menu_hover = _synth_menu_hover()
	_stream_menu_confirm = _synth_menu_confirm()
	_stream_menu_back = _synth_wave(0.15, 340.0, 185.0, 0.08, false)
	_stream_dialogue_blip = _synth_dialogue_blip()


func _synth_dialogue_blip() -> AudioStreamWAV:
	var duration: float = 0.036
	var count: int = int(duration * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var ph: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / float(maxi(1, count - 1))
		var attack: float = clampf(t * 16.0, 0.0, 1.0)
		var decay: float = pow(1.0 - t, 1.9)
		var env: float = attack * decay
		var freq: float = lerpf(320.0, 270.0, t)
		ph += TAU * freq / float(MIX_RATE)
		var tri: float = 2.0 * absf(fposmod(ph / TAU, 1.0) * 2.0 - 1.0) - 1.0
		samples[i] = (sin(ph) * 0.65 + tri * 0.35) * env * 0.28
	return _to_wav(samples, false)


func _synth_menu_hover() -> AudioStreamWAV:
	var duration: float = 0.075
	var count: int = int(duration * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var p1: float = 0.0
	var p2: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / float(maxi(1, count - 1))
		var attack: float = clampf(t * 24.0, 0.0, 1.0)
		var decay: float = pow(1.0 - t, 2.4)
		var env: float = attack * decay
		var f1: float = lerpf(580.0, 420.0, t)
		var f2: float = lerpf(1160.0, 840.0, t)
		p1 += TAU * f1 / float(MIX_RATE)
		p2 += TAU * f2 / float(MIX_RATE)
		var click_transient: float = (1.0 - clampf(t * 12.0, 0.0, 1.0)) * sin(p2 * 1.5) * 0.35
		samples[i] = (sin(p1) * 0.65 + sin(p2) * 0.25 + click_transient) * env * 0.55
	return _to_wav(samples, false)


func _synth_menu_confirm() -> AudioStreamWAV:
	var duration: float = 0.56
	var count: int = int(duration * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var ph_root: float = 0.0
	var ph_fifth: float = 0.0
	var ph_oct: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1710
	var flare_LP: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / float(maxi(1, count - 1))
		var attack: float = clampf(t * 28.0, 0.0, 1.0)
		var decay: float = pow(1.0 - t, 1.65)
		var env: float = attack * decay
		ph_root += TAU * 220.0 / float(MIX_RATE)
		ph_fifth += TAU * 329.63 / float(MIX_RATE)
		ph_oct += TAU * 440.0 / float(MIX_RATE)
		flare_LP = lerpf(flare_LP, rng.randf_range(-1.0, 1.0), 0.18)
		var flare_env: float = pow(1.0 - clampf(t * 2.2, 0.0, 1.0), 2.2)
		var chord: float = sin(ph_root) * 0.48 + sin(ph_fifth) * 0.34 + sin(ph_oct) * 0.22
		samples[i] = (chord * env + flare_LP * flare_env * 0.24) * 0.62
	return _to_wav(samples, false)


func _synth_wave(duration: float, freq_start: float, freq_end: float, noise_mix: float, loop_enabled: bool) -> AudioStreamWAV:
	var sample_count: int = int(duration * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	var phase: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(freq_start * 100.0 + duration * 1000.0)

	for i: int in range(sample_count):
		var t: float = float(i) / float(maxi(1, sample_count - 1))
		var env: float = 1.0 if loop_enabled else pow(1.0 - t, 1.8)
		var freq: float = lerpf(freq_start, freq_end, t)
		phase += TAU * freq / float(MIX_RATE)
		var tone: float = sin(phase) * 0.65 + sin(phase * 1.5) * 0.35
		var noise: float = rng.randf_range(-1.0, 1.0)
		samples[i] = lerpf(tone, noise, noise_mix) * env * 0.45
	return _to_wav(samples, loop_enabled)


## Ruído filtrado curto com modulação de amplitude (papel / sussurros).
func _synth_noise_burst(duration: float, smoothing: float, seed_val: int) -> AudioStreamWAV:
	var count: int = int(duration * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	var state: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / float(maxi(1, count - 1))
		state = lerpf(state, rng.randf_range(-1.0, 1.0), smoothing)
		var syllables: float = 0.55 + 0.45 * sin(t * TAU * duration * 5.0 + sin(t * 17.0) * 2.0)
		var env: float = sin(t * PI)
		samples[i] = state * syllables * env * 0.6
	return _to_wav(samples, false)


## Ruído marrom em loop sem emenda audível (vento com rajadas).
func _synth_noise_loop(duration: float, smoothing: float, seed_val: int) -> AudioStreamWAV:
	var count: int = int(duration * float(MIX_RATE))
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(count)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	var state: float = 0.0
	var peak: float = 0.0001
	for i: int in range(count):
		state = lerpf(state, rng.randf_range(-1.0, 1.0), smoothing)
		raw[i] = state
		peak = maxf(peak, absf(state))

	var fade: int = mini(count / 4, 6000)
	var out_count: int = count - fade
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(out_count)
	for i: int in range(out_count):
		var v: float = raw[i]
		if i < fade:
			var w: float = float(i) / float(fade)
			v = lerpf(raw[out_count + i], raw[i], w)
		var gust: float = 0.65 + 0.35 * sin(TAU * 2.0 * float(i) / float(out_count))
		samples[i] = (v / peak) * gust * 0.5
	return _to_wav(samples, true)


func _to_wav(samples: PackedFloat32Array, loop_enabled: bool) -> AudioStreamWAV:
	var count: int = samples.size()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	for i: int in range(count):
		var pcm: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
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
		wav.loop_end = count
	return wav
