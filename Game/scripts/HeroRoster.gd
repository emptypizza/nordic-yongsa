class_name HeroRoster

# 영웅 로스터 (mokup1.png 하단 카드: 라비 / 소희 / 아론).
# 활성 영웅·레벨은 SaveManager에 영속화된다(autoload, 항상 준비됨). 카드 탭으로 라이브 교체.

class Hero:
	var id: String
	var name: String
	var color: Color
	var level: int
	var glb: String           # 인게임 메시(glbs/). CharacterMesh로 자동 fit 후 사용.
	var portrait_path: String # 카드 포트레이트용 렌더 이미지(없으면 "" → 역할 아이콘 폴백)
	var badge_color: Color    # 레벨 배지 색
	var role_icon: String     # 카드 역할 아이콘: "sword" | "heart" | "staff"
	func _init(d: Dictionary, p_level: int) -> void:
		id = d["id"]
		name = d["name"]
		color = d["color"]
		level = p_level
		glb = d["glb"]
		portrait_path = d.get("portrait", "")
		badge_color = d.get("badge", color.darkened(0.1))
		role_icon = d.get("icon", "sword")

# 불변 정의(레벨은 세이브에서 주입). 인덱스 = 카드 순서.
# portrait: 기존 GLB 렌더 PNG가 있으면 카드에 띄운다(라비=Test Ch 렌더). 없으면 역할 아이콘으로 폴백.
const DEFS := [
	{"id": "ravi", "name": "라비", "color": Color(0.45, 0.62, 0.95), "glb": "res://scripts/glbs/Warrior 01.glb",
		"portrait": "", "badge": Color(0.30, 0.45, 0.85), "icon": "sword"},
	{"id": "sohee", "name": "소희", "color": Color(0.95, 0.55, 0.72), "glb": "res://scripts/glbs/Healer 01.glb",
		"portrait": "", "badge": Color(0.85, 0.35, 0.55), "icon": "heart"},
	{"id": "aron", "name": "아론", "color": Color(0.85, 0.45, 0.28), "glb": "res://scripts/glbs/Wizard 01.glb",
		"portrait": "", "badge": Color(0.70, 0.40, 0.22), "icon": "staff"},
]

static func count() -> int:
	return DEFS.size()

static func all() -> Array:
	var out := []
	for d in DEFS:
		out.append(Hero.new(d, SaveManager.get_hero_level(d["id"])))
	return out

static func hero_at(index: int) -> Hero:
	var d = DEFS[clampi(index, 0, DEFS.size() - 1)]
	return Hero.new(d, SaveManager.get_hero_level(d["id"]))

# 플레이어가 현재 조작하는 영웅(세이브 영속). 기본 라비(0).
static func active_index() -> int:
	return clampi(SaveManager.get_active_hero(), 0, DEFS.size() - 1)

static func set_active_index(index: int) -> void:
	SaveManager.set_active_hero(clampi(index, 0, DEFS.size() - 1))

static func active_hero() -> Hero:
	return hero_at(active_index())
