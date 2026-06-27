---
tags: [Nordic, design]
type: design
created: 2026-06-14
---

# Grail Escort 프로토타입 — 설계

원작(`game00nordic`, "Galapagos: Escort Mission")의 호송 코어 루프를 계승하되,
**Godot(GDScript) 3D + 4방향 그리드 + 검 든 용사 + 성배** 로 재구성한 프로토타입(엔진 Godot 4.7).

> **2026-06-27 업데이트 — 「길건너용사들」 비주얼 목업**: 호위 코어 위에 Crossy Road식
> 레인 시스템(잔디/강/길), 강 통나무 + frogger 횡단, 빛나는 포탈 골, 성배=마차(馬車) 비주얼,
> 영웅 로스터(라비/소희/아론), 스코어/코인, 목업형 HUD를 얹었다. `mokup1.png` 비주얼이
> 기준. 마일스톤 계획서: `260627-gilgeonneo-yongsadeul-mockup/plan.md`. 아래 설계에
> 변경 사항을 동기화했다(이 문서가 단일 진실).

## 1. 게임 개요

- 4방향 그리드 보드 위에서 **자동 전진하는 성배마차(馬車)** 를 **검 든 용사**가 호위한다.
- 보드는 **레인 밴드**(잔디 / 파란 강 / 흙길)로 구성. 강은 통나무 다리(중앙)로 안전 횡단하거나,
  떠다니는 통나무에 올라타 건넌다(Crossy Road/Frogger식). 다리 밖 물에 빠지면 **익사 → 첨벙 복귀**.
- 짐승 적들이 성배로 추격해 오고, 용사가 몸으로 받아쳐(용사·적 양쪽 **1칸 상호 넉백** + 적 기절) 막는다.
- **클리어**: 성배마차가 끝 행의 **빛나는 포탈**에 도달.
- **게임오버**: 성배 HP 0.
- **스코어** = 마차가 전진한 행 수, **BEST** 세션 최고, **코인** = 적 처치 누적.
- 영웅 로스터: **라비 / 소희 / 아론**(목업 단계는 카드 UI + 선택 하이라이트까지).
- 스테이지 1개. 실시간 진행(입력 대기 없음).

## 2. 그리드 / 좌표

- 보드 **19칸(가로 x) × 30칸(세로 z)**, 타일 1.0 유닛.
- 성배 시작 `(x=GridUtil.Cols / 2, z=0)`, 용사 시작 `(x=GridUtil.Cols / 2 + 1, z=0)`, 목표 행 `z=GridUtil.Rows - 1`.
- `GridUtil`이 그리드↔월드 좌표 변환과 경계(클램프)를 담당.

### 2.1 레인 시스템 (`LaneConfig`)

- 행(z)마다 레인 타입을 **결정론적**으로 배치(RNG 미사용 → 헤드리스 테스트/리플레이 안정).
  - `z ≤ 2` 및 `z ≥ ROWS-2`: 항상 **잔디**(시작/포탈 안전지대).
  - 강 밴드 `RIVER_BANDS = [6..7, 17..18]`, 흙길 밴드 `PATH_BANDS = [12, 24]`, 나머지 잔디.
- **다리**: 강 레인의 중앙 `±BRIDGE_HALF(=1)` 칸은 통나무 다리(안전). 성배마차·용사가 이 다리로 강을 건넌다.
- `is_drown_cell(cx,cz)` = 강 레인 AND 다리 칸 아님. 용사가 이 칸에서 통나무 위가 아니면 익사.
- 강 레인 통나무 드리프트: `river_dir(z)`(짝/홀 ±1 교차), `river_speed(z)`(레인별 1.0~1.7 u/s).

## 3. 액터별 이동 모델 (핵심)

| 액터 | 이동 | 방식 |
|---|---|---|
| **성배(Grail)** | 일정 속도(≈0.667 u/s)로 `+z` 연속 직진 | 기존 평균 속도(1타일/1.5초)는 유지하고 끊김 없이 전진. 목표 도달 시 `Win` 신호 |
| **용사(Player)** | 입력당 1타일 hop (4방향) | **방향키/WASD 한 번 누름 = 1타일 hop**(누르고 있으면 일정 간격 연속 hop), 모바일은 **스와이프/드래그**(탭=전진). 0.12s 트윈, 경계 클램프 |
| **적(Enemy)** | **연속 슬라이드 + 직각 전용** | 일정 속도로 레인을 따라 이동. **타일 중심에 도달할 때만** 성배와의 맨해튼 거리를 줄이는 4방향 중 하나로 방향 전환. **대각선 이동 절대 없음**(팩맨 유령식 격자 추적). 잡몹은 HP 1, 강한 적은 HP 2~3이며 더 크고 느리다. |

> 핵심: 성배는 마차처럼 일정 속도로 앞으로 굴러가고, 용사는 칸 단위 hop(길건너친구식), 적은 격자 레인 위 연속 이동이되 방향 전환은 타일 중심에서만 직각으로. 비스듬한 직선 돌진 금지.
>
> 입력 주: WASD/방향키는 **연속 벡터가 아니라 hop 트리거**로 처리한다(누름 이벤트 → 해당 방향 1타일 이동). 모바일 가상 조이스틱/스와이프도 같은 4방향 hop으로 양자화.
> 카메라가 +z 방향을 바라보므로 화면 좌우와 월드 x축이 반대다. 키보드와 HUD d-pad의 좌우 입력은 화면 기준으로 맞춘다(A/◀ = 화면 왼쪽, D/▶ = 화면 오른쪽).

## 4. 충돌 / 전투 (거리 기반 판정, 매 프레임)

- **적 ↔ 성배**: 근접 시 `Grail.take_damage()` 호출 — 피해가 실제로 들어갔을 때만(HP−1, 1초 무적 + 깜빡임) 적 소멸 + 파티클.
  - `take_damage()`는 피해 적용 여부를 `bool`로 돌려준다. **무적 중이면 피해를 무시하고 `false`** — 이때는 공짜 처치/파티클 없이 적을 성배 반대 방향으로 넉백한다(무적이 끝나면 재충돌해 정상적으로 피해를 입힌다).
- **적 ↔ 용사**: 근접 + 적이 기절 상태가 아니면 → 적 HP−1, 용사는 반동 넉백.
  - HP 0이 된 적은 사망하며 짧은 사망 연출 후 정리된다(+ 코인 1).
  - 살아남은 적은 **1칸 넉백 + 0.5초 기절**, 용사도 **1칸 넉백**(기절 없음) — 부딪칠 때 살짝 **대칭 상호 넉백**(2026-06-27 튜닝).
  - 넉백 거리는 충돌 순간의 연속 좌표가 아니라 각 액터의 논리 셀 중심 기준으로 계산한다.

### 4.1 강 / 통나무 (Frogger)

- 용사가 매 프레임 자기 셀이 `is_drown_cell`이고 hop 중이 아니면:
  - 그 행의 통나무(`Log`) 중 용사 x를 덮는 것이 있으면 → **탑승**(통나무 드리프트만큼 x로 실려 이동).
    실려서 보드 밖으로 나가면 익사.
  - 없으면 → **익사**: 현재 행 아래의 가장 가까운 비-강 행으로 첨벙 복귀(`splash_reset`, HP 손실 없음).
- 성배마차·적은 물 면역(마차는 마법 호위 대상, 적은 격자 추격 유지). 물/통나무는 **용사 전용 위험**.
- 적 종류: 잡몹 HP 1(기존 크기/속도), 강한 적 HP 2~3(더 큰 어두운 보라색, 약간 느림).
- HP 0 → `GameOver`. 성배 `z=GridUtil.Rows - 1` 도달 → `Win`. 패배/승리 확정 시 성배·용사·적의 진행을 정지한다.

## 5. 씬 / 스크립트 구조

```
Game/
  project.godot
  Title.tscn             # 루트 CanvasLayer + TitleScreen 코드-빌드 UI
  StageSelect.tscn       # 루트 CanvasLayer + StageSelect 코드-빌드 UI
  Main.tscn              # 루트 Node3D + 카메라/조명/보드/UI 조립
  audio/                 # (신규) 게임 사운드 WAV (BGM 2 + SFX 14). AudioManager가 res://audio/로 참조
  scripts/
    SaveManager.gd       # (신규) autoload: user://save.json 영속화(BEST·누적코인·영웅레벨·활성영웅·해금스테이지·사운드설정)
    StageState.gd        # (신규) autoload: 선택 스테이지 + 난이도(스폰간격/동시적수/강적비율/적속도). 보드는 동일, 적 압박만 변동
    AudioManager.gd      # (신규) autoload: BGM 1채널(루프) + SFX 폴리포니 풀. 논리 이벤트명→파일. 헤드리스에서 안전(no-op)
    MenuUI.gd            # (신규) Title/StageSelect 공용 스타일 헬퍼(라운드 패널/아웃라인 텍스트/그라데이션 배경)
    TitleScreen.gd       # 타이틀(게임명 + START → StageSelect + 사운드 토글). 로비 BGM, MenuUI 톤
    StageSelect.gd       # 스테이지 카드 N장(SaveManager 해금 상태로 잠금/해제) → StageState.select() 후 Main.tscn
    GameManager.gd       # 상태(Playing/Win/Lose), 스테이지 난이도 적용, 적/통나무 스폰, 물 판정, HP/스코어/코인, 영웅 라이브 교체, 사운드·세이브 훅, 재시작
    GridUtil.gd          # 그리드↔월드 변환, 경계
    LaneConfig.gd        # (신규) 레인 타입(잔디/강/길) 결정론 배치, 다리/익사/통나무 파라미터
    Board.gd             # (신규) 레인 타일(머티리얼별 MultiMesh 배칭) + 다리 + 숲(덤불/바위 MultiMesh) + 빛나는 포탈을 코드-빌드
    Log.gd               # (신규) 강 통나무 드리프트 플랫폼(래핑), 탑승 판정, 물 위 bob 시각 피드백
    HeroRoster.gd        # (신규) 영웅 데이터(라비→Warrior / 소희→Healer / 아론→Wizard). 활성영웅·레벨은 SaveManager 영속, 라이브 교체 가능
    CharacterMesh.gd     # (신규) glbs/ 복셀 캐릭터를 타일 기준으로 정규화(고정 스케일+Idle 루프), pivot 래핑 로더
    Grail.gd             # 연속 전진, HP, 무적, Win/Death 신호 — 비주얼은 성배마차(몸체+캐노피+바퀴+발광 성배) + 호위 동행 3명
    Player.gd            # 4방향 grid hop(키 입력 트리거), 넉백 충돌, 통나무 탑승(ride)/익사 복귀(splash_reset). 메시=활성 영웅 glb(pivot), rebuild_visual()로 라이브 교체
    Enemy.gd             # 연속 직각 그리드 추적(스테이지 속도배수), 충돌 판정(1칸 넉백). 메시=일반몹→스프라이트 4종 랜덤 / 강한적→Boogeyman glb, 폴백=프리미티브
    Hud.gd               # 목업 HUD: 상단(Guardian/HP바/스코어/BEST/코인/일시정지) + 하단 영웅카드(탭=라이브 교체) + 편집(코인으로 레벨업) + 스와이프/드래그 입력
    WindowFit.gd         # autoload: 데스크톱 창을 9:16으로 리사이즈(모바일/헤드리스 비활성)
    LogicTests.gd        # GridUtil + LaneConfig + Log/강 헤드리스 셀프테스트, Tests.tscn으로 실행(26/26 PASS)
```

- **autoload 4종**(project.godot 순서): `SaveManager` → `StageState` → `AudioManager` → `WindowFit`. SaveManager를 먼저 둬 AudioManager가 사운드 설정을 읽을 수 있게 한다.
- **스크래치 폴더 주의**: `Game/scripts/newexperment/`는 2D 에셋 실험용으로 `.gitignore` 처리(게임이 쓰는 오디오는 `Game/audio/`로 편입). 루트 스크린샷도 ignore.

- 화면 흐름: `Title` → `Stage Select`(스테이지 1개) → `Play` → 결과(`ARRIVED!`/`MISSION FAILED`) 패널에서 `RETRY`(같은 판 재시작) 또는 `STAGE SELECT`(선택 화면 복귀). 시작 씬은 `res://Title.tscn`이며, 화면 스크립트는 씬에 UI 자식을 저장하지 않고 `_Ready()`에서 코드로 빌드한다. 메뉴 화면(`Title`/`StageSelect`)은 `Hud`와 동일하게 `CanvasLayer` 루트 아래 중앙 정렬 `Control` 자식을 둔다.
- 적 스폰: 성배(마차)에서 최소 10칸(링 10~16칸) 떨어진 주위 그리드 레인에 스냅해 생성. 동시 적 수는 `GameManager`가 제한하고, 기본 스폰 간격은 2.5초로 둔다.
- 입력: Godot `InputMap`에 `move_left/right/up/down`(WASD + 방향키) 정의 → **누름 이벤트로 1타일 hop 트리거**(이동 중에는 입력 버퍼/무시 처리). 모바일은 HUD의 **스와이프/드래그**(짧은 드래그=탭=전진, 긴 드래그=해당 방향)가 같은 4방향 hop을 발생. 화면형 가상 d-pad는 목업 HUD(영웅 카드)와 겹쳐 제거.

## 6. 카메라 / 아트 (메시 + 프리미티브)

- **고정 각도 isometric 추적 카메라**: 성배(또는 성배·용사 중점)에 고정 오프셋, z 전진을 부드럽게 lerp 추적(길건너친구 룩).
- 타깃 디스플레이는 모바일 세로형 1080×1920 포트레이트이며, 19칸 폭 보드가 잘리지 않도록 카메라는 keep-width로 둔다.
- 카메라는 원근 → 직교(orthographic) 투영으로 전환한다. `Size`=직교 가시 폭(`KeepAspect=Width` 기준)이며, 각도/look-ahead 추적은 동일하게 유지한다. (`Size`·각도는 스크린샷 튜닝 대상)
- 데스크톱 테스트 창은 시작 시 모니터에 맞춰 9:16을 유지한 채 자동 리사이즈하고 중앙 정렬한다(`WindowFit` autoload). 모바일/헤드리스에서는 비활성화한다.
- 세로 화면용 look-ahead를 적용해 카메라가 포커스보다 +z 앞을 바라보며, 액션은 화면 하단 1/3 근처에 두고 진행 레인이 위쪽으로 길게 차도록 한다.
- **무드 라이팅**(2026-06-27): `ProceduralSkyMaterial` 한낮 하늘 + 하늘 기반 앰비언트 + 따뜻한 태양광
  + Filmic 톤맵 + 약한 블룸(발광 포탈/성배 강조). `mokup1.png`의 밝은 러시 톤.
- 캐릭터는 `glbs/` 복셀 메시, 배경/소품은 프리미티브 + 텍스처(점진 교체 중):
  - 바닥: **레인 타입별 타일**에 절차적 톱다운 텍스처(`gen/map/tiles/`: 잔디/강/흙길/널빤지, seamless)를
    albedo로 입힘. 텍스처가 없으면 기존 플랫 색으로 폴백. 강 중앙 통나무 다리 판자.
  - 가장자리 숲: 잔디 레인 좌우 2칸에 나무(원기둥+둥근 잎 2단)·덤불(구)·바위(박스)를 결정론 배치.
  - 포탈(골): 끝 행 중앙에 돌기둥 2 + 상인방 + **발광 파란 코어(맥동)** + 회전 발광 링.
  - 성배마차: 나무 짐칸 + 천 캐노피 + 굴러가는 바퀴 4 + 상단 발광 금색 성배(맥동) + 위아래 bob.
    **호위 동행 3명**(비선택 영웅 Healer/Wizard glb + Crow glb)이 마차 좌·우·뒤에 붙어 함께 전진(코스메틱, Idle 애니).
  - 통나무: x축으로 눕힌 갈색 원기둥(+밝은 결 스트라이프), 강 레인을 따라 드리프트.
  - 용사: **활성 영웅 glb**(라비=Warrior 01.glb) — `CharacterMesh`로 타일 기준 정규화, Idle 루프 +
    깡총 hop 아크+착지 스쿼시(pivot scale), 이동 방향 회전, 익사 시 첨벙 스쿼시.
    **주인공은 노란머리**: 머리카락 파츠(이름 `ha*`/`hha*`, 68개)만 `CharacterMesh.recolor_parts`로
    노란 단색 `material_override`(머리·얼굴 `h$$` 등은 제외). Player에서만 적용(동행/적 무관).
  - 적: **일반 몬스터(잡몹)는 스프라이트 4종 중 랜덤**(sprite-forge `gen/{goblin,slime,skeleton,bat}/`,
    빌보드 2x2 idle) — 잡몹마다 종류가 달라 변화를 준다. **강한 적은 `Boogeyman 01.glb`**(크고 느림, 3D 메시,
    이동 방향 회전 + 기절 흔들림). 둘 다 없으면 프리미티브 박스 폴백.

## 7. 실시간 루프

- `_Process`/`_PhysicsProcess`에서 매 프레임 갱신: 성배 연속 전진, 적 연속 이동, 충돌 판정, 카메라 추적.
- 입력 대기 없이 실시간 진행.

## 8. 구현 완료 / 범위 밖

**2026-06-27 메타·연출 패스로 완료된 항목** (기존 "범위 밖"에서 이동):
- **사운드** — `AudioManager` autoload + `Game/audio/`(BGM 2 + SFX 14). 전진/처치/피격/익사/클리어/실패/버튼에 훅. 타이틀·스테이지=로비 BGM, 인게임=게임플레이 BGM.
- **세이브/로드** — `SaveManager` autoload(`user://save.json`): BEST·누적코인·영웅레벨·활성영웅·해금스테이지·사운드설정.
- **영웅 카드 스왑/편집** — 카드 탭=활성 영웅 라이브 교체(Player 메시+동행 재구성). 편집=누적 코인으로 영웅 레벨업.
- **다중 스테이지** — `StageState`(3스테이지, 난이도=스폰압박). StageSelect에서 클리어 시 다음 스테이지 해금.
- **성능** — Board 바닥 타일 570개를 머티리얼별 MultiMesh로 배칭(드로우콜 ~7), 덤불/바위도 MultiMesh.
- **타이틀/메뉴 연출** — `MenuUI` 공용 스타일(그라데이션 배경·라운드 패널·아웃라인). 게임명 "길건너 용사들", 사운드 토글.
- **익사/통나무 손맛** — 첨벙 물 파티클 + 사운드, 통나무 bob, 레인당 통나무 4개 균등 분포.
- **death FX** — 발광 폭발 플래시 + 발광 파편 버스트(외부 에셋 무의존, voxel 톤 유지).
- **Android export** — 헤드리스 `--export-debug "Android"` → `Game/build/nordic.apk` 정상 생성(exit 0). 경고: 프로젝트 아이콘 미설정(비치명적).

**여전히 범위 밖 / 남은 과제:**
- 에셋 주의: `Game/scripts/glbs/`의 `*_N.png`(개당 ~100~200B, 약 2232개)는 **glTF가 추출한 머티리얼 팔레트 텍스처**로,
  임포트된 GLB 메시의 `StandardMaterial3D.albedo_texture`가 `res://scripts/glbs/<name>_N.png`로 **실제 참조**한다(복셀 파츠별 색).
  → **삭제 금지**(지우면 머티리얼 색이 깨짐). LFS는 `.glb` 원본만, 작은 PNG는 일반 추적.
- 성배마차/숲(나무)/포탈/통나무는 아직 프리미티브 placeholder — 실제 lowpoly/스프라이트 에셋 교체는 후속(에셋 생성 파이프라인 필요).
- glb 캐릭터 LOD/메시 병합(동시 표시가 많을 때). 동료 표시는 `GameManager._spawn_companions`로 토글 가능.
- 프로젝트 아이콘, 사운드 볼륨 슬라이더 UI, 영웅 능력차(현재 레벨은 숫자만, 스탯 미연동).

## 9. 검증 환경 (참고)

- 엔진 **Godot 4.7** (`4.7.stable.mono`). GDScript 프로젝트라 **.NET / DOTNET_ROOT 불필요**(mono 빌드라도 C# 없이 구동).
- 헤드리스 셀프테스트 `Tests.tscn` **26/26 PASS** 확인됨(GridUtil + LaneConfig + Log/강 + 적 스프라이트, `godot --headless --path Game res://Tests.tscn`).
- 메인 게임 헤드리스 구동 정상 확인됨(`godot --headless --path Game res://Main.tscn --quit-after 400`, exit 0, 스크립트/파스 에러 0). Title/StageSelect도 에러 0.
- 신규 class_name(`MenuUI`) 추가 시 글로벌 클래스 캐시가 비면 파스 에러가 날 수 있으니 `godot --headless --path Game --import`로 캐시를 갱신한다.
- 비주얼/손맛(레인·강·포탈·마차·HUD·사운드)은 에디터 F5로 확인.
