---
tags: [Nordic, progress, handoff]
type: progress
created: 2026-06-26
---

# GDScript 마이그레이션 검증 + 게임 개선 — 진행 상황 (handoff)

> 이 문서는 세션 중단 시 무손실 재개를 위한 핸드오프 노트다.
> 작업 목표: **프로젝트 전체 파악 → 게임 프로토타입 개선** (멀티 에이전트).

## 0. 현재 상태 한 줄

C#→GDScript 마이그레이션이 **코드상 완료**되었고 **헤드리스로 깨끗하게 구동**됨을 검증 완료.
**§3 문서 동기화(items 1~5) + §4 코드 개선(items 6~7) 모두 적용·검증 완료(2026-06-26).**
멀티 에이전트(파일 단위 5개 병렬)로 처리. 변경 파일: `CLAUDE.md`, `design.md`, `.claude/rules/godot.md`,
`plan.md`, `GameManager.gd` + 본 progress.md. 헤드리스 재검증: 셀프테스트 9/9 PASS, 메인 450프레임 exit 0.
남은 후보: §4의 스폰 거리는 fallback 적용 완료. 추가 game-feel juice / 고아 `*.cs.uid` 10개 정리는 미착수.

> 주의(env 부작용): mono Godot로 헤드리스 실행 시 `project.godot`에 `[dotnet]` 섹션이 주입되고
> `renderer/rendering_method="forward_plus"`가 떨어진다. 요청 범위 밖이라 매번 `git checkout Game/project.godot`로
> 되돌렸다. 재발하니 검증 후 정리하거나 non-mono Godot 사용 고려.

## 1. 검증 완료 사실 (재확인 불필요, 위에 쌓아라)

- **툴체인 단순화 확인.** 설치된 Godot는 `4.7.stable.mono`이며 `/opt/homebrew/bin/godot` 와
  `/Applications/Godot.app` 둘 다 동일 4.7 빌드. C#이 사라졌으므로 **.NET / DOTNET_ROOT 불필요**
  (mono 빌드라도 C# 없는 GDScript 프로젝트는 .NET 없이 구동됨). `project.godot`의 `config/features`에
  C#/Mono 태그 없음.
- **헤드리스 셀프테스트 9/9 PASS:**
  `/opt/homebrew/bin/godot --headless --path Game res://Tests.tscn` → `[selftest] ALL PASS`.
- **메인 게임 헤드리스 구동 정상:**
  `/opt/homebrew/bin/godot --headless --path Game res://Main.tscn --quit-after 450` → exit 0,
  로그 2줄(배너만), SCRIPT ERROR / Parse Error 0개. 450프레임(~7.5s)이라 적 스폰·전투까지 실제 실행됨.
  (주의: macOS엔 `timeout`이 없다 — `gtimeout` 또는 godot의 `--quit-after`를 써라. 초기에 `timeout`으로
  돌렸다가 godot가 아예 실행 안 된 false negative가 있었음.)
- **씬·`project.godot`은 `.cs` 참조 clean.** `.godot/editor/*.cfg`에만 stale `.cs` 캐시 문자열
  (TitleScreen.cs 등) — 에디터 UI 상태일 뿐 런타임 무관. 에디터 "Tools → Clear Cache"로 정리 가능.
- **모든 타입 `class_name` 정상:** Grail / Enemy / Player / Hud / GridUtil 선언됨 →
  GameManager.gd의 타입 참조 전부 해소. GameManager/TitleScreen/StageSelect/WindowFit/LogicTests는
  씬·autoload 스크립트라 `class_name` 없음(정상).

## 2. 프로젝트 맵 (요약)

게임: 4방향 그리드(19×30) 위에서 자동 전진하는 성배를 검 든 용사가 호위하는 실시간 escort
(Crossy-Road 룩). 적은 격자 추격, 충돌 넉백/기절, 성배 HP 0 패배 / 끝 행 도달 승리.

| 스크립트 | class_name | 책임 | 공개 표면 |
|---|---|---|---|
| GameManager.gd | (없음) | 루트 컨트롤러: 액터 스폰, 게임 루프, 충돌 판정, 승패, 카메라 | `_ready/_process`, `_restart`(in-place reset) |
| Player.gd | Player | 용사: 입력당 1타일 hop, 넉백, glb 모델+홉 연출 | `try_hop(dx,dz)`, `knockback(dir)`, `cx/cz` |
| Enemy.gd | Enemy | 적: 격자 직각 추격, 피격/넉백, 강적 시각 구분 | `init(grail,cell,hp)`, `take_hit()`, `knockback()`, `stun/hp/speed` |
| Grail.gd | Grail | 성배: 연속 전진(≈0.667u/s), HP/무적, 신호 | signals `reached_goal/died/health_changed`, `take_damage()`, `get_cz()`, `cx/hp/max_hp` |
| Hud.gd | Hud | UI: HP바, 결과 패널, 가상 d-pad, 스와이프 | signals `hop_requested/retry_pressed/menu_pressed`, `set_health/show_result/hide_result` |
| GridUtil.gd | GridUtil | 그리드↔월드 변환, 경계 클램프, `step_toward` | 정적 메서드 일체 |
| TitleScreen.gd | (없음) | Title 씬, START → StageSelect | 코드 빌드 UI |
| StageSelect.gd | (없음) | StageSelect 씬, STAGE 1 → Main | 코드 빌드 UI |
| WindowFit.gd | (없음) | autoload: 데스크톱 창 9:16 리사이즈 | autoload |
| LogicTests.gd | (없음) | GridUtil 헤드리스 셀프테스트 | Tests.tscn |

흐름: `Title.tscn`(main scene) → `StageSelect.tscn` → `Main.tscn`(게임). `Tests.tscn`은 셀프테스트.
액터는 씬 파일 없이 GameManager가 `.new()` + `add_child()`로 코드 생성.

## 3. 문서 동기화 필요 (필수 산출물 — `.claude/rules/docs.md` 규칙. 아직 미적용)

C#→GDScript는 구조 변경이므로 같은 작업에서 문서를 갱신해야 한다. 정확한 위치:

**`CLAUDE.md`**
- `:4` `Engine: **Godot-mono (C#), 3D**` → `Engine: Godot (GDScript), 3D` (4.7).
- `:9` 경로에 `Game/scenes/` 언급 → `scenes/` 디렉터리 없음. 씬은 `Game/` 루트. 수정/삭제.

**`Game/docs/features/260614-grail-escort-prototype/design.md`**
- `:10` `Godot-mono(C#) 3D` → `Godot(GDScript) 3D`.
- `:58-65` §5 스크립트 목록 — 모든 확장자 `.cs` → `.gd`. 또한 **누락된 `WindowFit.gd`(autoload),
  `LogicTests.gd`(Tests.tscn) 추가**.
- `:98` §9 `/Applications에 Godot.app + Godot_mono.app ... .NET 10.0.107` → GDScript엔 무의미.
  실제 검증 환경(Godot 4.7, 헤드리스 셀프테스트, .NET 불필요)으로 교체.
- `:99` §9 `Godot 정확한 버전(4.x .NET 호환)` → `.NET 호환` 삭제, Godot 4.7만 참조.

**`.claude/rules/godot.md`** (파일 전체가 C# 빌드 파이프라인 설명 — 거의 전면 재작성)
- 제목 `# Godot (C#) 프로젝트` → `# Godot (GDScript) 프로젝트`.
- frontmatter `description`, 경로 glob `*.cs`/`*.csproj`, `Nordic`(asmdef/namespace), `net10.0`/
  `Godot.NET.Sdk/4.6.3`/`.NET 10 SDK`/godot#103545 불릿 → 전부 GDScript 기준으로 교체/삭제.
  엔진은 이제 **4.7**(4.6.3 아님).
- `dotnet build Game/Nordic.csproj` 검증 → 헤드리스 실행 검증으로 교체. 존재하지 않는 `tests.md` 참조 제거.
- 씬 목록 `Main.tscn + Tests.tscn만` → `Title/StageSelect/Main/Tests` 4개로 갱신(메인 씬은 Title).

**`.claude/rules/docs.md`** — clean. 변경 불필요.

**`Game/docs/.../plan.md`** — 과거 C# 구현 계획(마이그레이션으로 superseded). 게다가 게임 상수가
설계·현 코드와 다름(그리드 7×12 vs 19×30, 스폰거리 4 vs 10, 간격 1.2s vs 2.5s, 성배 auto-hop vs 연속전진).
전면 재작성보다 상단에 "superseded by GDScript 마이그레이션" 노트 추가 권장.

## 4. 동작 괴리 / 개선 후보

- **[code-ahead-of-design] 용사가 프리미티브 블록이 아니라 `Test Ch.glb` voxel 모델.**
  Player.gd:19 `load("res://scripts/Test Ch.glb")`, 홉 아크+스쿼시(:67-76), 방향 회전(:78-80).
  design §6:82(블록+검 박스), §8:94(에셋 임포트 out-of-scope)와 충돌 → **design을 코드에 맞춰 갱신**.
- **[bug/design-missing] 적↔성배 충돌 시 death 파티클 누락.**
  GameManager.gd:147-150은 `take_damage()`+`queue_free()`만. `_spawn_death_fx`(:152-171)는
  플레이어 처치 경로(:137)에만 연결. design §4:41 "적 소멸 + 파티클"에 위배 →
  성배 충돌 분기에 `_spawn_death_fx(e.global_position)` 한 줄 추가. (함수 이미 존재, 저위험 개선.)
- **[bug] 적 스폰 거리 제약이 보장되지 않음.**
  GameManager.gd:96-113 — 24회 시도 모두 실패하면 마지막 후보에 그냥 스폰(거리<10 가능).
  루프 탈출 실패 시 fallback 필요(예: 성배에서 정확히 MIN_DIST 떨어진 셀로 스냅). 저빈도/저위험.
- **컨트롤은 정상.** d-pad ◀→(1,0), move_left→+x 등은 카메라가 +z를 보므로 **화면 기준 좌우가 맞음**
  (design §3:37 의도된 매핑). 반전 버그 아님.
- **정리 후보:** 고아 `*.cs.uid` 10개(Enemy.cs.uid 등, scripts/) — 참조 없음, 삭제 안전.
  `.godot/editor` 캐시 stale `.cs`도 Clear Cache로 정리 가능.

## 5. 다음 단계 (멀티 에이전트 계획)

사용자 요청은 "모든 에이전트 활용". 적합한 것: **Explore / general-purpose / Plan / game-maker / claude**.
부적합(정직하게 제외): **claude-code-guide**(Claude Code Q&A 전용), **statusline-setup**(상태줄 설정 전용)
— Godot 게임 작업과 무관.

- [x] Phase A — 이해: Explore(맵+감사), general-purpose(설계↔코드 괴리·문서목록). **완료**(본 문서가 산출).
- [x] Phase B — 개선 계획 우선순위화(다음 할일 10개로 정리, items 1~7 선택). **완료.**
- [x] Phase C — game-maker: 성배충돌 death FX + 스폰거리 fallback 구현(`GameManager.gd`만 수정). **완료.**
      (추가 game-feel juice는 item 8로 미착수.)
- [x] Phase D — 문서 동기화 적용(items 1~5: CLAUDE.md/design.md/godot.md/plan.md). **완료.**
- [x] 마지막: 오케스트레이터 헤드리스 재검증(Tests 9/9 PASS + Main 450프레임 exit 0, 회귀 없음). **완료.**
- [ ] 미착수: item 8(추가 game-feel juice), item 9(고아 `*.cs.uid` 10개 + `.godot` 캐시 정리).

## 6. 재개 시 첫 명령(복붙용)

```bash
# 셀프테스트
/opt/homebrew/bin/godot --headless --path /Users/choimarc/gghf3/Game res://Tests.tscn
# 메인 헤드리스(적 스폰·전투 포함)
/opt/homebrew/bin/godot --headless --path /Users/choimarc/gghf3/Game res://Main.tscn --quit-after 450
```
