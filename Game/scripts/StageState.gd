extends Node

# 선택된 스테이지와 난이도 파라미터를 보관하는 autoload.
# StageSelect가 current를 정하고 Main으로 전환 → GameManager가 config()를 읽어 적용한다.
# 보드 레이아웃(LaneConfig)은 스테이지와 무관하게 결정론적으로 유지(셀프테스트 안정성).
# 스테이지 간 차이는 적 스폰 난이도(간격/동시수/강적 비율)로 준다.

# 각 스테이지: 표시명 + 난이도. spawn_interval↓, max_enemies↑, strong_chance↑ 일수록 어렵다.
const STAGES := [
	{
		"name": "평원의 길",
		"spawn_interval": 3.0,
		"max_enemies": 4,
		"strong_chance": 0.10,
		"enemy_speed_mul": 1.0,
	},
	{
		"name": "협곡 추격",
		"spawn_interval": 2.3,
		"max_enemies": 6,
		"strong_chance": 0.18,
		"enemy_speed_mul": 1.1,
	},
	{
		"name": "마룡의 행렬",
		"spawn_interval": 1.7,
		"max_enemies": 8,
		"strong_chance": 0.28,
		"enemy_speed_mul": 1.2,
	},
]

var current := 0

func count() -> int:
	return STAGES.size()

func select(index: int) -> void:
	current = clampi(index, 0, STAGES.size() - 1)

func config() -> Dictionary:
	return STAGES[clampi(current, 0, STAGES.size() - 1)]

func stage_name(index: int) -> String:
	return String(STAGES[clampi(index, 0, STAGES.size() - 1)]["name"])
