extends Node

# 영속 저장 허브 (autoload). user://save.json에 진행 상태를 보관한다.
# BEST 스코어·누적 코인·영웅 레벨·활성 영웅·해금 스테이지·사운드 설정.
# 헤드리스/CI에서도 user://는 쓰기 가능하므로 안전하다.

const SAVE_PATH := "user://save.json"
const VERSION := 1

# 기본값 — 첫 실행/파손 시 이 형태로 시작한다.
var _data := {
	"version": VERSION,
	"best_score": 0,
	"total_coins": 0,
	"active_hero": 0,
	"hero_levels": {"ravi": 1, "sohee": 1, "aron": 1},
	"unlocked_stage": 0,   # 해금된 최고 스테이지 인덱스(0 = 첫 판만)
	"audio": {"muted": false, "bgm_db": -6.0, "sfx_db": -2.0},
}

func _ready() -> void:
	_load()

# ── 영속 I/O ───────────────────────────────────────────────────
func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	# 기본값 위에 저장값을 덮어써 누락 키를 자동 보강(스키마 진화 대비).
	for k in parsed.keys():
		if _data.has(k):
			_data[k] = parsed[k]
	# 중첩 dict는 키 단위 머지.
	if typeof(parsed.get("audio")) == TYPE_DICTIONARY:
		for k in parsed["audio"]:
			_data["audio"][k] = parsed["audio"][k]
	if typeof(parsed.get("hero_levels")) == TYPE_DICTIONARY:
		for k in parsed["hero_levels"]:
			_data["hero_levels"][k] = parsed["hero_levels"][k]

func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()

# ── 스코어 / 코인 ──────────────────────────────────────────────
func get_best() -> int:
	return int(_data["best_score"])

func report_score(score: int) -> bool:
	# 신기록이면 갱신·저장하고 true.
	if score > int(_data["best_score"]):
		_data["best_score"] = score
		save()
		return true
	return false

func get_total_coins() -> int:
	return int(_data["total_coins"])

func add_coins(n: int) -> void:
	_data["total_coins"] = int(_data["total_coins"]) + n
	# 코인은 빈번하므로 즉시 디스크 쓰기는 하지 않고, 라운드 종료(commit)에서 저장.

func commit() -> void:
	save()

# ── 영웅 ───────────────────────────────────────────────────────
func get_active_hero() -> int:
	return int(_data["active_hero"])

func set_active_hero(i: int) -> void:
	_data["active_hero"] = i
	save()

func get_hero_level(id: String) -> int:
	return int(_data["hero_levels"].get(id, 1))

func set_hero_level(id: String, lv: int) -> void:
	_data["hero_levels"][id] = lv
	save()

# ── 스테이지 해금 ──────────────────────────────────────────────
func get_unlocked_stage() -> int:
	return int(_data["unlocked_stage"])

func mark_stage_cleared(index: int) -> void:
	# 다음 스테이지를 해금(최고치만 갱신).
	var next: int = index + 1
	if next > int(_data["unlocked_stage"]):
		_data["unlocked_stage"] = next
		save()

# ── 사운드 설정 ────────────────────────────────────────────────
func get_audio_settings() -> Dictionary:
	return _data["audio"].duplicate()

func set_audio_settings(s: Dictionary) -> void:
	for k in s:
		_data["audio"][k] = s[k]
	save()
