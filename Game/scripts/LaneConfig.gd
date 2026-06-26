class_name LaneConfig

# 행(z)마다 레인 타입을 결정하는 결정론적 설정.
# 헤드리스 셀프테스트/리플레이 안정성을 위해 RNG를 쓰지 않고 고정 밴드로 배치한다.
# z=0 시작(보드 하단), z=ROWS-1 포탈(상단). mokup1.png의 "잔디 + 강 밴드 + 길" 구성을 모사.

enum LaneType { GRASS, RIVER, PATH }

# [start, end] inclusive. 강 2개 밴드(가운데 가로지르는 파란 강), 흙길 2개 밴드.
const RIVER_BANDS := [Vector2i(6, 7), Vector2i(17, 18)]
const PATH_BANDS := [Vector2i(12, 12), Vector2i(24, 24)]

# 다리(마차/플레이어가 강을 건너는 통나무 다리) = 보드 중앙 ±BRIDGE_HALF 칸.
const BRIDGE_HALF := 1

static func _in_band(cz: int, bands: Array) -> bool:
	for b in bands:
		if cz >= b.x and cz <= b.y:
			return true
	return false

static func lane_type(cz: int) -> int:
	# 시작/포탈 안전지대는 항상 잔디.
	if cz <= 2 or cz >= GridUtil.ROWS - 2:
		return LaneType.GRASS
	if _in_band(cz, RIVER_BANDS):
		return LaneType.RIVER
	if _in_band(cz, PATH_BANDS):
		return LaneType.PATH
	return LaneType.GRASS

static func is_water(cz: int) -> bool:
	return lane_type(cz) == LaneType.RIVER

static func bridge_center() -> int:
	return GridUtil.COLS / 2

static func is_bridge_col(cx: int) -> bool:
	return absi(cx - bridge_center()) <= BRIDGE_HALF

# 플레이어가 익사하는 셀: 강 레인이면서 다리 칸이 아닌 곳.
static func is_drown_cell(cx: int, cz: int) -> bool:
	return is_water(cz) and not is_bridge_col(cx)

# 강 레인의 통나무 드리프트 방향(+1/-1): z 짝/홀로 좌우 교차.
static func river_dir(cz: int) -> int:
	return 1 if (cz % 2 == 0) else -1

# 강 레인의 통나무 속도(u/s): 레인마다 살짝 다르게.
static func river_speed(cz: int) -> float:
	return 1.0 + float(cz % 3) * 0.35
