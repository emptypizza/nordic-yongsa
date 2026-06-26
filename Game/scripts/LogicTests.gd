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

	print("[selftest] ALL PASS" if _fail == 0 else "[selftest] %d FAIL" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)

func _check(test_name: String, ok: bool) -> void:
	print("[selftest] %s: %s" % [test_name, "PASS" if ok else "FAIL"])
	if not ok:
		_fail += 1
