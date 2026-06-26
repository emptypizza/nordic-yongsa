extends Node3D

enum State { PLAYING, WIN, LOSE }
var _state := State.PLAYING

var _grail: Grail
var _player: Player
var _enemies: Array[Enemy] = []
const MAX_ENEMIES := 6
const MIN_ENEMY_SPAWN_DISTANCE := 10
const SPAWN_DISTANCE_BAND := 6
const SPAWN_INTERVAL := 2.5
var _spawn_timer := 0.0
var _hud: Hud
var _camera: Camera3D
var _camera_offset := Vector3(0, 11, -8)
const CAMERA_LOOK_AHEAD := 7.0  # Look ahead on +z so portrait framing keeps action lower.

func _ready() -> void:
	_setup_input()
	_build_environment()
	_build_ground()

	_hud = Hud.new()
	add_child(_hud)
	_hud.hop_requested.connect(func(dir: Vector2i) -> void: _player.try_hop(dir.x, dir.y))
	_hud.retry_pressed.connect(_restart)
	_hud.menu_pressed.connect(func() -> void: get_tree().change_scene_to_file("res://StageSelect.tscn"))

	_spawn_actors()

func _spawn_actors() -> void:
	_grail = Grail.new()
	add_child(_grail)
	_grail.reached_goal.connect(_on_win)
	_grail.died.connect(_on_lose)
	_grail.health_changed.connect(_hud.set_health)

	_player = Player.new()
	add_child(_player)

	_hud.set_health(_grail.hp, _grail.max_hp)  # 초기값

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.6, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.4)
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -40, 0)
	add_child(sun)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 7.0  # 직교 가시 폭(KeepAspect=Width 기준). 작을수록 줌인.
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.position = Vector3(GridUtil.COLS / 2.0, 11, -8)
	add_child(_camera)
	_camera.current = true

func _build_ground() -> void:
	for x in GridUtil.COLS:
		for z in GridUtil.ROWS:
			var tile := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(1, 1)
			tile.mesh = plane
			var even := (x + z) % 2 == 0
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.55, 0.75, 0.45) if even else Color(0.5, 0.7, 0.4)
			tile.material_override = mat
			tile.position = GridUtil.cell_to_world(x, z, 0.0)
			add_child(tile)

func _setup_input() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])

func _add_key_action(action_name: String, keys: Array) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action_name, ev)

func _spawn_enemy() -> void:
	var grail_cell := Vector2i(_grail.cx, _grail.get_cz())
	var cell := grail_cell
	for guard in 24:
		var ang := randf() * TAU
		var dist := MIN_ENEMY_SPAWN_DISTANCE + randf() * SPAWN_DISTANCE_BAND
		var cx := GridUtil.clamp_col(grail_cell.x + roundi(cos(ang) * dist))
		var cz := GridUtil.clamp_row(grail_cell.y + roundi(sin(ang) * dist))
		cell = Vector2i(cx, cz)
		var manhattan := absi(cx - grail_cell.x) + absi(cz - grail_cell.y)
		if manhattan >= MIN_ENEMY_SPAWN_DISTANCE:
			break

	var enemy := Enemy.new()
	var hp: int = 1 if randf() < 0.7 else randi_range(2, 3)
	enemy.init(_grail, cell, hp)
	add_child(enemy)
	_enemies.append(enemy)

func _process(delta: float) -> void:
	if _state != State.PLAYING:
		return

	var focus := (_grail.position + _player.position) * 0.5
	var desired := focus + _camera_offset
	_camera.position = _camera.position.lerp(desired, 1.0 - exp(-5.0 * delta))
	var look_target := focus + Vector3(0, 0, CAMERA_LOOK_AHEAD)
	_camera.look_at(look_target, Vector3.UP)

	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL and _enemies.size() < MAX_ENEMIES:
		_spawn_timer = 0.0
		_spawn_enemy()

	for i in range(_enemies.size() - 1, -1, -1):
		var e := _enemies[i]

		# Enemy vs player: 1 damage; 살아남은 적은 넉백+기절.
		if e.stun <= 0.0 and e.position.distance_to(_player.position) < 0.6:
			var sep := e.position - _player.position
			if e.take_hit():
				_spawn_death_fx(e.global_position)
				e.queue_free()
				_enemies.remove_at(i)
				_player.knockback(-sep)
				continue
			e.knockback(sep)
			_player.knockback(-sep)
			continue  # 방금 넉백된 적은 이 프레임에 성배 피해 X

		# 적 ↔ 성배: HP -1, 적 소멸
		if e.position.distance_to(_grail.position) < 0.6:
			_grail.take_damage()
			e.queue_free()
			_enemies.remove_at(i)

func _spawn_death_fx(pos: Vector3) -> void:
	var fx := CPUParticles3D.new()
	fx.emitting = true
	fx.one_shot = true
	fx.amount = 10
	fx.lifetime = 0.4
	fx.position = pos
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 0.12)
	fx.mesh = box
	fx.initial_velocity_min = 2.0
	fx.initial_velocity_max = 4.0
	fx.gravity = Vector3(0, -6, 0)
	add_child(fx)

	var timer := get_tree().create_timer(0.8)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(fx):
			fx.queue_free()
	)

func _on_win() -> void:
	if _state != State.PLAYING:
		return
	_state = State.WIN
	_hud.show_result("ARRIVED!", Color(0.3, 0.8, 0.3))
	_freeze_actors()

func _on_lose() -> void:
	if _state != State.PLAYING:
		return
	_state = State.LOSE
	_hud.show_result("MISSION FAILED", Color(1, 0.24, 0))
	_freeze_actors()

func _freeze_actors() -> void:
	_grail.set_process(false)
	_player.set_process(false)
	for en in _enemies:
		en.set_process(false)

func _restart() -> void:
	# In-place reset instead of reload_current_scene(): keep the
	# WorldEnvironment / DirectionalLight / camera / ground so the directional
	# light is never destroyed and recreated. On the Compatibility (mobile)
	# renderer, recreating the light on scene reload can drop its shadow on
	# subsequent plays; reusing the same light avoids that.
	# NOTE: unverified on a real device — the emulator (ANGLE/SwiftShader) and
	# desktop GL-over-Metal render no directional shadows at all, so this could
	# not be confirmed against the reported symptom here.
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	if is_instance_valid(_grail):
		_grail.queue_free()
	if is_instance_valid(_player):
		_player.queue_free()

	_state = State.PLAYING
	_spawn_timer = 0.0
	_hud.hide_result()
	_spawn_actors()

	# Snap the camera onto the freshly reset actors so it doesn't slide in.
	var focus := (_grail.position + _player.position) * 0.5
	_camera.position = focus + _camera_offset
