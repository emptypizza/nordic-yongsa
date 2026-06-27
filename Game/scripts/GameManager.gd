extends Node3D

enum State { PLAYING, WIN, LOSE }
var _state := State.PLAYING

var _grail: Grail
var _player: Player
var _enemies: Array[Enemy] = []
var _companions: Array[Node3D] = []
var _board: Board
var _logs: Array[Log] = []
var _coins: int = 0
var _best: int = 0
# 스폰 난이도는 StageState.config()에서 스테이지별로 채운다(_apply_stage_config).
var _max_enemies := 6
const MIN_ENEMY_SPAWN_DISTANCE := 10
const SPAWN_DISTANCE_BAND := 6
var _spawn_interval := 2.5
var _strong_chance := 0.15
var _enemy_speed_mul := 1.0
var _spawn_timer := 0.0
var _hud: Hud
var _camera: Camera3D
const CAMERA_OFFSET := Vector3(0, 12, -8.5)
const CAMERA_LOOK_AHEAD := 8.5  # Look ahead on +z so portrait framing keeps action lower.

func _ready() -> void:
	randomize()  # 적 스폰 위치 + 일반몹 종류가 매 실행마다 달라지게 시드 초기화
	_apply_stage_config()
	_best = SaveManager.get_best()
	AudioManager.play_bgm("gameplay")
	_setup_input()
	_build_environment()
	_build_board()
	_spawn_logs()

	_hud = Hud.new()
	add_child(_hud)
	_hud.hop_requested.connect(func(dir: Vector2i) -> void: _player.try_hop(dir.x, dir.y))
	_hud.retry_pressed.connect(_restart)
	_hud.menu_pressed.connect(func() -> void: get_tree().change_scene_to_file("res://StageSelect.tscn"))
	_hud.hero_selected.connect(_on_hero_selected)

	_spawn_actors()

func _spawn_actors() -> void:
	_grail = Grail.new()
	add_child(_grail)
	_grail.reached_goal.connect(_on_win)
	_grail.died.connect(_on_lose)
	_grail.health_changed.connect(_hud.set_health)

	_player = Player.new()
	add_child(_player)

	_spawn_companions()

	_hud.set_health(_grail.hp, _grail.max_hp)  # 초기값

const CROW_GLB := "res://scripts/glbs/Crow.glb"

func _spawn_companions() -> void:
	# 마차(Grail)를 호위하며 함께 전진하는 동행(코스메틱). 마차에 붙여 위치를 따라가게 한다.
	# 비선택 영웅 2명(Healer/Wizard) + Crow → 일반 몬스터를 고블린 스프라이트로 되돌려도
	# 5개 glb(플레이어=Warrior, 강한 적=Boogeyman, 동행=Healer/Wizard/Crow)가 모두 화면에 보인다.
	_companions.clear()
	var escorts: Array[String] = []
	var heroes := HeroRoster.all()
	var active := HeroRoster.active_index()
	for i in heroes.size():
		if i != active:
			escorts.append(heroes[i].glb)
	escorts.append(CROW_GLB)  # 까마귀 동행(마차 뒤)
	var offsets := [Vector3(-1.15, 0.0, -0.25), Vector3(1.15, 0.0, -0.25), Vector3(0.0, 0.0, -1.35)]
	for j in escorts.size():
		if j >= offsets.size():
			break
		var built := CharacterMesh.build(escorts[j], 1.15, ["Idle", "Idle01"])
		if built.is_empty():
			continue
		var pivot: Node3D = built["pivot"]
		pivot.position = offsets[j]
		pivot.rotation.y = PI  # 전진(+z)을 바라보게
		if built.get("anim") != null:
			CharacterMesh.play_loop(built["anim"], ["Walk01", "Idle01", "Idle"])
		_grail.add_child(pivot)
		_companions.append(pivot)

# 영웅 카드 탭 → 활성 영웅 라이브 교체. 플레이어 메시·동행을 다시 만들고 HUD 하이라이트를 옮긴다.
func _on_hero_selected(index: int) -> void:
	if index == HeroRoster.active_index():
		return
	HeroRoster.set_active_index(index)
	AudioManager.sfx("power_up")
	if is_instance_valid(_player):
		_player.rebuild_visual()
	_respawn_companions()
	_hud.refresh_hero_cards()

func _respawn_companions() -> void:
	for c in _companions:
		if is_instance_valid(c):
			c.queue_free()
	_companions.clear()
	if is_instance_valid(_grail):
		_spawn_companions()

func _apply_stage_config() -> void:
	# 선택된 스테이지의 난이도를 스폰 파라미터에 반영(보드는 동일, 적 압박만 달라진다).
	var cfg := StageState.config()
	_spawn_interval = float(cfg.get("spawn_interval", _spawn_interval))
	_max_enemies = int(cfg.get("max_enemies", _max_enemies))
	_strong_chance = float(cfg.get("strong_chance", _strong_chance))
	_enemy_speed_mul = float(cfg.get("enemy_speed_mul", _enemy_speed_mul))

func _build_environment() -> void:
	# 따뜻한 한낮 하늘 + 부드러운 앰비언트 (mokup1.png의 러시·밝은 무드).
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.62, 0.92)
	sky_mat.sky_horizon_color = Color(0.78, 0.88, 0.95)
	sky_mat.ground_horizon_color = Color(0.70, 0.82, 0.72)
	sky_mat.ground_bottom_color = Color(0.45, 0.62, 0.42)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.7
	env.ambient_light_energy = 1.1
	# 살짝 따뜻한 톤맵·약한 블룸으로 발광 포탈/성배가 빛나 보이게.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.3
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.rotation_degrees = Vector3(-50, -40, 0)
	add_child(sun)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 11.0  # 직교 가시 폭(KeepAspect=Width 기준). mokup처럼 보드 폭·전방 레인을 더 보이게 확대.
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.position = Vector3(GridUtil.COLS / 2.0, 0, 0) + CAMERA_OFFSET
	add_child(_camera)
	_camera.current = true

func _build_board() -> void:
	# 레인 타입별 색 타일 + 다리 + 가장자리 숲 + 빛나는 포탈을 Board가 코드-빌드.
	_board = Board.new()
	add_child(_board)

func _spawn_logs() -> void:
	# 강 레인마다 통나무 여러 개를 흩뿌려 흐르게 한다(레인별 방향/속도/위상).
	for z in GridUtil.ROWS:
		if not LaneConfig.is_water(z):
			continue
		var dir := LaneConfig.river_dir(z)
		var speed := LaneConfig.river_speed(z)
		# 레인 폭(+여유)에 통나무를 균등 분포 → 어느 칸에서도 곧 탈 통나무가 온다.
		var count := 4
		var spacing := float(GridUtil.COLS + 4) / float(count)
		for i in count:
			var span := 2.4 + float((z + i) % 2) * 0.6
			var start_x := -2.0 + float(i) * spacing + float(z % 3) * 1.3
			var log := Log.new()
			log.init(z, dir, speed, span, start_x)
			add_child(log)
			_logs.append(log)

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
	var found := false
	for guard in 24:
		var ang := randf() * TAU
		var dist := MIN_ENEMY_SPAWN_DISTANCE + randf() * SPAWN_DISTANCE_BAND
		var cx := GridUtil.clamp_col(grail_cell.x + roundi(cos(ang) * dist))
		var cz := GridUtil.clamp_row(grail_cell.y + roundi(sin(ang) * dist))
		cell = Vector2i(cx, cz)
		var manhattan := absi(cx - grail_cell.x) + absi(cz - grail_cell.y)
		if manhattan >= MIN_ENEMY_SPAWN_DISTANCE:
			found = true
			break

	if not found:
		# 24회 랜덤 시도가 모두 실패하면(성배가 보드 가장자리·모서리라 clamp가 후보를
		# MIN_DIST 안쪽으로 당김) 결정론적 fallback. 보드(19×30)는 z축 여유만으로
		# 어디서든 MIN_DIST 확보 가능: z 여유가 큰 방향으로 MIN_DIST만큼 떨어뜨린다.
		var gz := grail_cell.y
		var zdir := 1 if gz <= GridUtil.ROWS - 1 - MIN_ENEMY_SPAWN_DISTANCE else -1
		var fcz := GridUtil.clamp_row(gz + zdir * MIN_ENEMY_SPAWN_DISTANCE)
		var fcx := grail_cell.x
		# clamp으로 z 거리가 모자라면 보드 폭이 넓은 쪽으로 x축에서 남은 거리를 보충.
		var deficit := MIN_ENEMY_SPAWN_DISTANCE - absi(fcz - gz)
		if deficit > 0:
			var xdir := 1 if grail_cell.x <= (GridUtil.COLS - 1) / 2 else -1
			fcx = GridUtil.clamp_col(grail_cell.x + xdir * deficit)
		cell = Vector2i(fcx, fcz)

	var enemy := Enemy.new()
	# 강한 적(Boogeyman glb) 비율은 스테이지 난이도(_strong_chance)에 따른다. 나머지는 일반 몬스터.
	var hp: int = randi_range(2, 3) if randf() < _strong_chance else 1
	enemy.init(_grail, cell, hp)
	enemy.speed_mul = _enemy_speed_mul
	add_child(enemy)
	_enemies.append(enemy)

func _process(delta: float) -> void:
	if _state != State.PLAYING:
		return

	var focus := (_grail.position + _player.position) * 0.5
	var desired := focus + CAMERA_OFFSET
	_camera.position = _camera.position.lerp(desired, 1.0 - exp(-5.0 * delta))
	var look_target := focus + Vector3(0, 0, CAMERA_LOOK_AHEAD)
	_camera.look_at(look_target, Vector3.UP)

	_resolve_water(delta)
	_update_progress_hud()

	_spawn_timer += delta
	if _spawn_timer >= _spawn_interval and _enemies.size() < _max_enemies:
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
				_award_coin()
				continue
			e.knockback(sep)
			_player.knockback(-sep)
			continue  # 방금 넉백된 적은 이 프레임에 성배 피해 X

		# 적 ↔ 성배: 피해가 실제로 들어갔을 때만 적 소멸 (+ death 파티클).
		if e.position.distance_to(_grail.position) < 0.6:
			if _grail.take_damage():
				AudioManager.sfx("hit")  # 마차 피격
				_spawn_death_fx(e.global_position)  # queue_free 전에 위치 확보
				e.queue_free()
				_enemies.remove_at(i)
				_award_coin()
			else:
				# 성배 무적 중 — 공짜 처치/FX 대신 적을 튕겨낸다(무적 끝나면 재충돌).
				e.knockback(e.position - _grail.position)

func _spawn_death_fx(pos: Vector3) -> void:
	# 폭발 플래시: 발광 구가 순간 커지며 사라진다.
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	flash.mesh = sphere
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.82, 0.35)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.55, 0.15)
	fm.emission_energy_multiplier = 3.2
	flash.material_override = fm
	flash.position = pos + Vector3(0, 0.4, 0)
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector3.ONE * 2.8, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(fm, "emission_energy_multiplier", 0.0, 0.2)
	tw.tween_callback(flash.queue_free)

	# 발광 파편 버스트.
	var fx := CPUParticles3D.new()
	fx.emitting = true
	fx.one_shot = true
	fx.amount = 14
	fx.lifetime = 0.45
	fx.position = pos + Vector3(0, 0.3, 0)
	var shard := BoxMesh.new()
	shard.size = Vector3(0.12, 0.12, 0.12)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(1.0, 0.7, 0.25)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.5, 0.12)
	smat.emission_energy_multiplier = 1.4
	shard.surface_set_material(0, smat)
	fx.mesh = shard
	fx.spread = 60.0
	fx.initial_velocity_min = 2.5
	fx.initial_velocity_max = 4.5
	fx.gravity = Vector3(0, -7, 0)
	add_child(fx)

	var timer := get_tree().create_timer(0.9)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(fx):
			fx.queue_free()
	)

func _award_coin() -> void:
	_coins += 1
	_hud.set_coins(_coins)
	AudioManager.sfx("coin", 0.08)  # 약간의 피치 변주로 연타가 단조롭지 않게
	SaveManager.add_coins(1)        # 누적은 라운드 종료 시 commit()으로 디스크 반영

func _update_progress_hud() -> void:
	# 스코어 = 성배마차가 전진한 행 수. BEST는 세션 최고.
	var score := _grail.get_cz()
	if score > _best:
		_best = score
	_hud.set_score(score, _best)

# 플레이어가 물에 빠진 상태면 통나무에 태우거나(드리프트) 익사 처리한다.
func _resolve_water(delta: float) -> void:
	if _player.is_hopping():
		return
	var pcx := _player.cx
	var pcz := _player.cz
	if not LaneConfig.is_drown_cell(pcx, pcz):
		return
	var carrier := _log_at(_player.position.x, pcz)
	if carrier != null:
		_player.ride(carrier.drift_dx(delta))
		# 통나무에 실려 보드 밖으로 나가면 익사.
		if _player.position.x < -0.6 or _player.position.x > float(GridUtil.COLS - 1) + 0.6:
			_drown_player(pcz)
	else:
		_drown_player(pcz)

func _log_at(world_x: float, cz: int) -> Log:
	for log in _logs:
		if log.cz == cz and log.covers_x(world_x):
			return log
	return null

func _drown_player(cz: int) -> void:
	_spawn_splash_fx(_player.global_position)
	AudioManager.sfx("splash")
	var safe := _safe_row_below(cz)
	_player.splash_reset(_player.cx, safe)

func _spawn_splash_fx(pos: Vector3) -> void:
	# 익사 첨벙: 파란 물방울이 위로 튀었다 떨어진다.
	var fx := CPUParticles3D.new()
	fx.emitting = true
	fx.one_shot = true
	fx.amount = 16
	fx.lifetime = 0.5
	fx.position = pos + Vector3(0, 0.1, 0)
	var drop := SphereMesh.new()
	drop.radius = 0.07
	drop.height = 0.14
	fx.mesh = drop
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.75, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy_multiplier = 0.8
	fx.mesh.surface_set_material(0, mat)
	fx.spread = 55.0
	fx.initial_velocity_min = 2.5
	fx.initial_velocity_max = 4.5
	fx.gravity = Vector3(0, -9, 0)
	add_child(fx)
	var timer := get_tree().create_timer(0.9)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(fx):
			fx.queue_free()
	)

func _safe_row_below(cz: int) -> int:
	for z in range(cz - 1, -1, -1):
		if not LaneConfig.is_water(z):
			return z
	return 0

func _on_win() -> void:
	if _state != State.PLAYING:
		return
	_state = State.WIN
	AudioManager.stop_bgm()
	AudioManager.sfx("win")
	SaveManager.mark_stage_cleared(StageState.current)
	_finalize_run()
	_hud.show_result("ARRIVED!", Color(0.3, 0.8, 0.3))
	_freeze_actors()

func _on_lose() -> void:
	if _state != State.PLAYING:
		return
	_state = State.LOSE
	AudioManager.stop_bgm()
	AudioManager.sfx("lose")
	_finalize_run()
	_hud.show_result("MISSION FAILED", Color(1, 0.24, 0))
	_freeze_actors()

func _finalize_run() -> void:
	# 신기록 갱신 + 라운드 누적 코인을 디스크에 반영.
	var score := _grail.get_cz()
	if SaveManager.report_score(score):
		_best = score
	SaveManager.commit()

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
	_coins = 0
	AudioManager.play_bgm("gameplay")
	_hud.hide_result()
	_hud.set_coins(0)
	_hud.set_score(0, _best)
	_spawn_actors()

	# Snap the camera onto the freshly reset actors so it doesn't slide in.
	var focus := (_grail.position + _player.position) * 0.5
	_camera.position = focus + CAMERA_OFFSET
