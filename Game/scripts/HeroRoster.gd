class_name HeroRoster

# 영웅 로스터 (mokup1.png 하단 카드: 라비 / 소희 / 아론).
# 목업 단계에서는 이름·테마색·레벨만. 능력 전환은 후속 작업.

class Hero:
	var id: String
	var name: String
	var color: Color
	var level: int
	var glb: String   # 인게임 메시(glbs/). CharacterMesh로 자동 fit 후 사용.
	func _init(p_id: String, p_name: String, p_color: Color, p_level: int, p_glb: String) -> void:
		id = p_id
		name = p_name
		color = p_color
		level = p_level
		glb = p_glb

static func all() -> Array:
	return [
		Hero.new("ravi", "라비", Color(0.45, 0.62, 0.95), 1, "res://scripts/glbs/Warrior 01.glb"),  # 검사/전사
		Hero.new("sohee", "소희", Color(0.95, 0.55, 0.72), 1, "res://scripts/glbs/Healer 01.glb"),  # 힐러
		Hero.new("aron", "아론", Color(0.85, 0.45, 0.28), 1, "res://scripts/glbs/Wizard 01.glb"),   # 마법사
	]

# 플레이어가 현재 조작하는 기본 영웅(라비 = Warrior).
static func active_index() -> int:
	return 0

static func active_hero() -> Hero:
	return all()[active_index()]
