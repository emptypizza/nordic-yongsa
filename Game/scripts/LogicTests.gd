extends Node

var _fail := 0

func _ready() -> void:
	# StepToward: 대각선 절대 없음(둘 중 한 축만 ±1)
	_check("step-diag-x-major", GridUtil.step_toward(Vector2i(0, 0), Vector2i(3, 1)) == Vector2i(1, 0))
	_check("step-diag-z-major", GridUtil.step_toward(Vector2i(0, 0), Vector2i(1, 3)) == Vector2i(0, 1))
	_check("step-neg", GridUtil.step_toward(Vector2i(5, 5), Vector2i(5, 2)) == Vector2i(0, -1))
	_check("step-same", GridUtil.step_toward(Vector2i(2, 2), Vector2i(2, 2)) == Vector2i.ZERO)

	# cell_to_world / world_to_cell 왕복
	var w := GridUtil.cell_to_world(3, 7, 0.5)
	_check("cell2world-x", is_equal_approx(w.x, 3.0))
	_check("cell2world-z", is_equal_approx(w.z, 7.0))
	_check("world2cell", GridUtil.world_to_cell(w) == Vector2i(3, 7))

	# 경계 클램프
	_check("clamp-col", GridUtil.clamp_col(99) == GridUtil.COLS - 1 and GridUtil.clamp_col(-5) == 0)
	_check("clamp-row", GridUtil.clamp_row(99) == GridUtil.ROWS - 1 and GridUtil.clamp_row(-5) == 0)

	# LaneConfig: 시작/포탈 안전지대는 항상 잔디(물 아님)
	_check("lane-start-safe", not LaneConfig.is_water(0) and not LaneConfig.is_water(2))
	_check("lane-goal-safe", not LaneConfig.is_water(GridUtil.ROWS - 1))
	# 강 밴드는 물, 그 사이 잔디는 물 아님
	_check("lane-river", LaneConfig.is_water(6) and LaneConfig.is_water(17))
	_check("lane-nonriver", not LaneConfig.is_water(10))
	# 다리: 중앙 칸은 안전, 가장자리 강 칸은 익사
	var c := LaneConfig.bridge_center()
	_check("bridge-center-safe", not LaneConfig.is_drown_cell(c, 6))
	_check("bridge-edge-drown", LaneConfig.is_drown_cell(0, 6))
	# 잔디 행은 어떤 칸도 익사 아님
	_check("grass-no-drown", not LaneConfig.is_drown_cell(0, 10) and not LaneConfig.is_drown_cell(c, 10))
	# 통나무 래핑: +방향 통나무가 우측 경계를 넘으면 좌측으로 재진입
	var lg := Log.new()
	lg.init(6, 1, 2.0, 2.6, float(GridUtil.COLS - 1) + 5.0)
	lg._process(0.001)
	_check("log-wrap", lg.position.x < 0.0)
	lg.free()

	# 통나무 커버 판정 + 드리프트 부호
	var lg2 := Log.new()
	lg2.init(6, 1, 1.5, 2.6, 5.0)  # x=5 중앙, 길이 2.6(반=1.3, 여유 0.15)
	_check("log-cover-center", lg2.covers_x(5.0))
	_check("log-cover-edge", lg2.covers_x(5.0 + 1.3))
	_check("log-cover-far-no", not lg2.covers_x(5.0 + 2.0))
	_check("log-drift-pos", lg2.drift_dx(1.0) > 0.0)
	lg2.dir = -1
	_check("log-drift-neg", lg2.drift_dx(1.0) < 0.0)
	lg2.free()

	# 강 레인: 방향 교차 + 속도 양수
	_check("river-dir-alt", LaneConfig.river_dir(6) == 1 and LaneConfig.river_dir(7) == -1)
	_check("river-speed-pos", LaneConfig.river_speed(6) >= 1.0 and LaneConfig.river_speed(17) >= 1.0)

	# 익사 셀: 강의 비-다리 칸만(양쪽 강 밴드), 다리 칸은 안전
	var bc := LaneConfig.bridge_center()
	_check("drown-river-noncenter", LaneConfig.is_drown_cell(2, 6) and LaneConfig.is_drown_cell(GridUtil.COLS - 1, 17))
	_check("drown-bridge-safe", not LaneConfig.is_drown_cell(bc, 6) and not LaneConfig.is_drown_cell(bc, 17))

	# 일반 몬스터 스프라이트 시트 4종이 모두 존재하고 Texture2D로 로드되는지
	var spr_ok := Enemy.GEN_SHEETS.size() == 4
	for p in Enemy.GEN_SHEETS:
		var tex: Texture2D = load(p) if ResourceLoader.exists(p) else null
		if tex == null:
			spr_ok = false
	_check("enemy-sprites-load", spr_ok)

	# 영웅 로스터 데이터: 3명, 포트레이트는 빈값이거나 실제 존재, 역할 아이콘은 정의된 셋 중 하나
	var roster_ok := HeroRoster.all().size() == 3
	for h in HeroRoster.all():
		if h.portrait_path != "" and not ResourceLoader.exists(h.portrait_path):
			roster_ok = false
		if not (h.role_icon in ["sword", "heart", "staff"]):
			roster_ok = false
	_check("hero-roster-data", roster_ok)

	# Board 장식 해시 결정성: 같은 입력→같은 출력(리플레이 안정), 다른 입력→보통 다른 출력
	_check("board-hash-deterministic",
		Board._hash2(3, 7) == Board._hash2(3, 7) and Board._hash2(3, 7) != Board._hash2(4, 7))

	# HUD: 영웅 카드가 항상 로스터 수만큼 생성되는지
	var hud := Hud.new()
	add_child(hud)
	_check("hud-hero-cards", hud.hero_card_count() == HeroRoster.count())
	hud.free()

	print("[selftest] ALL PASS" if _fail == 0 else "[selftest] %d FAIL" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)

func _check(test_name: String, ok: bool) -> void:
	print("[selftest] %s: %s" % [test_name, "PASS" if ok else "FAIL"])
	if not ok:
		_fail += 1
