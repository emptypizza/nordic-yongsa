extends Node

# 전역 사운드 허브 (autoload). BGM 1채널(루프) + SFX 폴리포니 풀.
# 에셋: res://audio/*.wav (newexperment 오디오에서 편입). 헤드리스(Dummy 드라이버)에서도
# play()는 안전한 no-op이라 셀프테스트/CLI 구동에 영향이 없다.
#
# 사용:
#   AudioManager.play_bgm("gameplay")  # 또는 "lobby"
#   AudioManager.sfx("coin")           # 논리 이벤트명 → 파일
# 설정(볼륨/뮤트)은 SaveManager가 있으면 _ready에서 읽어 적용한다.

const BGM := {
	"lobby": "res://audio/bgm_lobby_loop.wav",
	"gameplay": "res://audio/bgm_lana_gameplay_loop.wav",
}

# 논리 이벤트명 → SFX 파일. 게임 코드는 파일명이 아니라 의미로 부른다.
const SFX := {
	"button": "res://audio/sfx_btn_click.wav",
	"hover": "res://audio/sfx_btn_hover.wav",
	"coin": "res://audio/sfx_orb_get.wav",
	"coin_alt": "res://audio/sfx_orb_get_alt.wav",
	"hop": "res://audio/sfx_tap.wav",
	"swipe": "res://audio/sfx_swipe.wav",
	"hit": "res://audio/sfx_wall_hit.wav",
	"shield_break": "res://audio/sfx_shield_break.wav",
	"shield_on": "res://audio/sfx_shield_on.wav",
	"power_up": "res://audio/sfx_power_up.wav",
	"splash": "res://audio/sfx_player_death.wav",
	"death": "res://audio/sfx_player_death.wav",
	"win": "res://audio/sfx_stage_clear.wav",
	"lose": "res://audio/sfx_warning.wav",
}

const SFX_VOICES := 8  # 동시 재생 가능한 SFX 수(코인 연타 등 겹침 대비)

var _bgm_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _stream_cache: Dictionary = {}
var _current_bgm := ""

var _muted := false
var _bgm_volume_db := -6.0
var _sfx_volume_db := -2.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 일시정지 중에도 사운드 동작

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	# WAV 임포트 기본 loop=Disabled라 finished에서 직접 되감아 안정적으로 루프.
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)

	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)

	_apply_settings_from_save()

func _apply_settings_from_save() -> void:
	var save := get_node_or_null("/root/SaveManager")
	if save != null and save.has_method("get_audio_settings"):
		var s: Dictionary = save.get_audio_settings()
		_muted = bool(s.get("muted", false))
		_bgm_volume_db = float(s.get("bgm_db", _bgm_volume_db))
		_sfx_volume_db = float(s.get("sfx_db", _sfx_volume_db))
	_refresh_volume()

func _refresh_volume() -> void:
	if _bgm_player != null:
		_bgm_player.volume_db = -80.0 if _muted else _bgm_volume_db

# ── BGM ────────────────────────────────────────────────────────
func play_bgm(name: String) -> void:
	if _current_bgm == name and _bgm_player.playing:
		return
	var stream := _load(BGM.get(name, ""))
	if stream == null:
		return
	_current_bgm = name
	_bgm_player.stream = stream
	_bgm_player.volume_db = -80.0 if _muted else _bgm_volume_db
	_bgm_player.play()

func stop_bgm() -> void:
	_current_bgm = ""
	if _bgm_player != null:
		_bgm_player.stop()

func _on_bgm_finished() -> void:
	if _current_bgm != "" and _bgm_player.stream != null:
		_bgm_player.play()  # 끝나면 처음부터 다시(루프)

# ── SFX ────────────────────────────────────────────────────────
func sfx(event: String, pitch_var: float = 0.0) -> void:
	if _muted:
		return
	var stream := _load(SFX.get(event, ""))
	if stream == null:
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = stream
	p.volume_db = _sfx_volume_db
	p.pitch_scale = 1.0 + (randf() * 2.0 - 1.0) * pitch_var if pitch_var > 0.0 else 1.0
	p.play()

# ── 설정 ───────────────────────────────────────────────────────
func set_muted(v: bool) -> void:
	_muted = v
	if v:
		stop_bgm_volume_only()
	_refresh_volume()
	_persist()

func is_muted() -> bool:
	return _muted

func toggle_muted() -> void:
	set_muted(not _muted)

func stop_bgm_volume_only() -> void:
	# 뮤트 시 재생은 유지하되 음량만 끄면, 언뮤트 때 즉시 들린다.
	if _bgm_player != null:
		_bgm_player.volume_db = -80.0

func _persist() -> void:
	var save := get_node_or_null("/root/SaveManager")
	if save != null and save.has_method("set_audio_settings"):
		save.set_audio_settings({"muted": _muted, "bgm_db": _bgm_volume_db, "sfx_db": _sfx_volume_db})

func _exit_tree() -> void:
	# 종료 시 재생/캐시 참조를 끊어 "resources still in use" 경고를 막는다.
	if _bgm_player != null:
		_bgm_player.stop()
		_bgm_player.stream = null
	for p in _sfx_pool:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	_stream_cache.clear()

# ── 내부 ───────────────────────────────────────────────────────
func _load(path: String) -> AudioStream:
	if path == "":
		return null
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		_stream_cache[path] = null
		return null
	var stream := load(path) as AudioStream
	_stream_cache[path] = stream
	return stream
