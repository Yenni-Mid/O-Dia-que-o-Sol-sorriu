extends Node
## Diretor de Ambientes Sonoros em Camadas:
## Mistura vento noturno, grilos, tensão de interiores e subsolo (esgoto) conforme posição e horário,
## além de disparar sons pontuais aleatórios (coruja, corvo e goteira subterrânea).

const SILENT_DB: float = -52.0
const FADE_SPEED_DB: float = 18.0

var _wind_player: AudioStreamPlayer
var _crickets_player: AudioStreamPlayer
var _indoor_player: AudioStreamPlayer
var _sewer_player: AudioStreamPlayer
var _oneshot_player: AudioStreamPlayer

var _db_wind: float = SILENT_DB
var _db_crickets: float = SILENT_DB
var _db_indoor: float = SILENT_DB
var _db_sewer: float = SILENT_DB

var _oneshot_timer: float = 12.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wind_player = _make_loop_player("OutdoorWind", AudioManager.get_wind_stream())
	_crickets_player = _make_loop_player("OutdoorCrickets", AudioManager.get_night_crickets_stream())
	_indoor_player = _make_loop_player("IndoorDark", AudioManager.get_indoor_dark_stream())
	_sewer_player = _make_loop_player("SewerDrone", AudioManager.get_sewer_drone_stream())

	_oneshot_player = AudioStreamPlayer.new()
	_oneshot_player.name = "OneShotAmbPlayer"
	add_child(_oneshot_player)
	_oneshot_timer = randf_range(10.0, 18.0)


func _make_loop_player(node_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = node_name
	p.stream = stream
	p.volume_db = SILENT_DB
	add_child(p)
	return p


func _process(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	var is_night: bool = bool(dn.call("is_nighttime")) if (dn != null and dn.has_method("is_nighttime")) else true
	var hour: float = float(dn.call("get_hour")) if (dn != null and dn.has_method("get_hour")) else 21.0

	var zone: String = _get_zone(player.global_position) if player != null else "outdoor"

	var t_wind: float = SILENT_DB
	var t_crickets: float = SILENT_DB
	var t_indoor: float = SILENT_DB
	var t_sewer: float = SILENT_DB

	if zone == "underground":
		t_indoor = -36.0
		t_sewer = -13.0
	elif zone == "indoor":
		t_wind = -27.0
		t_crickets = -36.0 if is_night else SILENT_DB
		t_indoor = -16.0
	else:
		if is_night:
			t_wind = -15.0
			var dawn_fade: float = clampf((hour - 5.0), 0.0, 1.0) if (hour >= 5.0 and hour < 6.0) else 0.0
			t_crickets = lerpf(-19.0, -34.0, dawn_fade)
			t_indoor = -38.0
		else:
			t_wind = -17.0
			t_indoor = -44.0

	if get_tree().paused:
		t_wind = maxf(SILENT_DB, t_wind - 10.0) if t_wind > SILENT_DB else SILENT_DB
		t_crickets = maxf(SILENT_DB, t_crickets - 10.0) if t_crickets > SILENT_DB else SILENT_DB
		t_indoor = maxf(SILENT_DB, t_indoor - 10.0) if t_indoor > SILENT_DB else SILENT_DB
		t_sewer = maxf(SILENT_DB, t_sewer - 10.0) if t_sewer > SILENT_DB else SILENT_DB

	_db_wind = _step_channel(_wind_player, _db_wind, t_wind, delta)
	_db_crickets = _step_channel(_crickets_player, _db_crickets, t_crickets, delta)
	_db_indoor = _step_channel(_indoor_player, _db_indoor, t_indoor, delta)
	_db_sewer = _step_channel(_sewer_player, _db_sewer, t_sewer, delta)

	if not get_tree().paused and player != null:
		_oneshot_timer -= delta
		if _oneshot_timer <= 0.0:
			_oneshot_timer = randf_range(14.0, 26.0)
			_trigger_zone_oneshot(zone, player.global_position, is_night, hour)


func _step_channel(p: AudioStreamPlayer, cur_db: float, target_db: float, delta: float) -> float:
	if p == null or p.stream == null:
		return SILENT_DB
	var next_db: float = move_toward(cur_db, target_db, FADE_SPEED_DB * delta)
	p.volume_db = next_db
	if target_db > -48.0:
		if not p.playing:
			p.play()
	elif next_db <= -50.0 and p.playing:
		p.stop()
	return next_db


func _trigger_zone_oneshot(zone: String, pos: Vector3, is_night: bool, hour: float) -> void:
	if _oneshot_player == null or _oneshot_player.playing:
		return
	var stream: AudioStream = null
	var vol: float = -14.0
	if zone == "underground":
		stream = AudioManager.get_sewer_drip_stream()
		vol = randf_range(-13.0, -8.0)
	elif zone == "outdoor":
		if pos.x > 34.0 or (hour >= 5.0 and hour < 7.0):
			stream = AudioManager.get_crow_stream()
			vol = randf_range(-15.0, -11.0)
		elif is_night:
			stream = AudioManager.get_owl_stream()
			vol = randf_range(-17.0, -12.0)

	if stream != null:
		_oneshot_player.stream = stream
		_oneshot_player.volume_db = vol
		_oneshot_player.pitch_scale = randf_range(0.86, 1.14)
		_oneshot_player.play()


func _get_zone(pos: Vector3) -> String:
	if pos.y < -1.2:
		return "underground"
	# Casa Principal (TwoStoryHouse)
	if pos.x >= -8.0 and pos.x <= 8.0 and pos.z >= -7.0 and pos.z <= 7.0:
		return "indoor"
	# Mini-Mercado
	if pos.x >= -25.5 and pos.x <= -17.5 and pos.z >= -7.5 and pos.z <= 7.0:
		return "indoor"
	# Casa Vizinha
	if pos.x >= 17.5 and pos.x <= 25.5 and pos.z >= -7.0 and pos.z <= 7.5:
		return "indoor"
	# Loja do Posto de Gasolina
	if pos.x >= -57.0 and pos.x <= -46.0 and pos.z >= -6.0 and pos.z <= 4.0:
		return "indoor"
	# Escola Municipal Aurora Solar
	if pos.x >= -24.0 and pos.x <= 22.0 and pos.z >= -72.0 and pos.z <= -48.0:
		return "indoor"
	# Capela do Sol Sorridente
	if pos.x >= 44.0 and pos.x <= 60.0 and pos.z >= -21.0 and pos.z <= -3.0:
		return "indoor"
	# Abrigo Inicial
	if pos.x >= -3.2 and pos.x <= 3.2 and pos.z >= 15.5 and pos.z <= 25.2:
		return "indoor"
	return "outdoor"
