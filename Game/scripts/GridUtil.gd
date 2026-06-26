class_name GridUtil

const TILE_SIZE := 1.0
const COLS := 19  # x: 0..18
const ROWS := 30  # z: 0..29

static func cell_to_world(cx: int, cz: int, y: float = 0.0) -> Vector3:
	return Vector3(cx * TILE_SIZE, y, cz * TILE_SIZE)

static func world_to_cell(w: Vector3) -> Vector2i:
	return Vector2i(roundi(w.x / TILE_SIZE), roundi(w.z / TILE_SIZE))

static func clamp_col(cx: int) -> int:
	return clampi(cx, 0, COLS - 1)

static func clamp_row(cz: int) -> int:
	return clampi(cz, 0, ROWS - 1)

static func in_bounds(cx: int, cz: int) -> bool:
	return cx >= 0 and cx < COLS and cz >= 0 and cz < ROWS

# 직각 한 칸 스텝: 맨해튼 거리를 줄이는 4방향 중, 남은 델타가 큰 축 우선.
static func step_toward(from: Vector2i, target: Vector2i) -> Vector2i:
	var dx := target.x - from.x
	var dz := target.y - from.y
	if dx == 0 and dz == 0:
		return Vector2i.ZERO
	if absi(dx) >= absi(dz):
		return Vector2i(signi(dx), 0)
	return Vector2i(0, signi(dz))
