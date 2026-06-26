class_name HeroRoster

# 영웅 로스터 (mokup1.png 하단 카드: 라비 / 소희 / 아론).
# 목업 단계에서는 이름·테마색·레벨만. 능력 전환은 후속 작업.

class Hero:
	var id: String
	var name: String
	var color: Color
	var level: int
	func _init(p_id: String, p_name: String, p_color: Color, p_level: int) -> void:
		id = p_id
		name = p_name
		color = p_color
		level = p_level

static func all() -> Array:
	return [
		Hero.new("ravi", "라비", Color(0.45, 0.62, 0.95), 1),   # 흰머리 검사(파란 망토) = Test Ch
		Hero.new("sohee", "소희", Color(0.95, 0.55, 0.72), 1),  # 핑크 마법/힐러
		Hero.new("aron", "아론", Color(0.85, 0.45, 0.28), 1),   # 붉은 전사
	]

# 플레이어가 현재 조작하는 기본 영웅(흰머리 검사 = Test Ch.glb).
static func active_index() -> int:
	return 0
