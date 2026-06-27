---
tags: [Nordic, plan, visual, mokup1]
type: plan
created: 2026-06-28
---

# Mokup1 인게임 비주얼 업그레이드 계획

## 0. 목표 / 제약

- **목표**: `mokup1.png`(타깃 레퍼런스)의 밀도 높은 핸드페인트 톱다운 룩에 인게임 비주얼을 근접시킨다.
  게임 규칙(점수/코인/체력/스테이지/충돌/레인)은 **불변**, **비주얼만** 강화.
- **엔진 제약(중요)**: **Godot 4.7 노드·GDScript·Godot 리소스만** 사용. 외부 생성/런타임 금지(이번엔 higgsfield 등 미사용).
- **렌더러 제약**: 모바일(APK)은 `renderer/rendering_method.mobile="gl_compatibility"`(GLES3). 따라서
  **SSAO/SSIL/SDFGI/볼류메트릭은 모바일에서 미지원** → 데스크톱(forward_plus) 전용 효과로만 취급한다.
  **glow(블룸)·커스텀 spatial 셰이더·StandardMaterial·정점색·MultiMesh·파티클은 모바일 OK**. 업그레이드는 모바일에서 보이는 것 우선.
- **성능**: 바닥 타일 570개는 머티리얼별 MultiMesh 배칭(~7 드로우콜) 유지. 신규 장식도 MultiMesh로 묶는다.
  `Game/scripts/glbs/`의 작은 `*_N.png`는 GLB 머티리얼 참조 파일 → **삭제 금지**.

## 1. 현황 분석 (소스 기준)

| 영역 | 현재 구현 | mokup1 대비 격차 |
|---|---|---|
| 라이팅/환경 (`GameManager._build_environment`) | 절차적 하늘 + sun 1개(에너지1.3) + 앰비언트(sky 0.7/1.1) + FILMIC + glow 0.3 | 채움광 부족(동료 GLB가 어둡게 뜸), 채도/온기 약함, 블룸 약함, 접지 그림자 빈약 |
| 바닥 타일 (`Board._build_tiles`) | 1×1 평면 + 절차 텍스처(grass/path/water/plank) + even/odd 틴트 | 타일별 입체(블록) 깊이 없음, 잔디 색 변주 빈약, 흙길 가장자리 디테일 없음 |
| 강 (`Board` water 타일 + `Log`) | 정적 물 텍스처 타일(emission 약간) + 통나무 드리프트 | 흐름/물결/포말 없음(정적) — mokup은 흐르는 파란 강 + 흰 포말 |
| 가장자리 숲/소품 (`_build_edge_forest`) | 나무(빌보드)·덤불·바위·그루터기·상자·배럴·통나무더미 MultiMesh, ~25% 밀도 | mokup보다 성김. 가을 나무·이끼바위·버섯·클로버 등 다양성 부족 |
| 랜드마크 (`_build_landmarks`) | 집/대장간/상점/울타리(프리미티브 박스+지붕) 소수 | mokup은 포탈 근처 'HQ 마을' 군집(대장간 화로·상점 차양·통·짐수레·모루) 밀집 |
| 포탈 (`_build_portal`) | 빌보드 포탈 + 상승 파티클 (폴백: 석재+코어+링) | 발광/블룸 약함, 아치 주변 장식 빈약 |
| 성배마차 (`Grail`) | 빌보드 마차 + bob | mokup의 천막 디테일·바퀴 그림자 약함(빌보드라 OK, 접지감만 보강) |
| 플레이어/동료 (`Player`/`CharacterMesh`) | 기사 4방향 빌보드(L/R 버그 수정 완료) / 동료=glb | 동료 glb 어둡게 렌더(라이팅 문제), 이동 가이드 reticle 없음 |
| 이동 가이드 | HUD 텍스트 "DRAG TO MOVE"만 | mokup엔 발밑 **하이라이트 타일 + 위쪽 화살표**(reticle) |
| HUD (`Hud`) | 상단바/스코어/BEST/코인/영웅카드/일시정지, 노드 아이콘 | mokup의 별(★레벨)·왕관 BEST·둥근 패널·채도 높은 카드 톤과 차이 |

## 2. 신규/변경 공개 API·타입

- **`VisualTheme.gd`** (신규, `class_name VisualTheme`): 색/머티리얼/환경/UI 팔레트 단일 출처.
  - `const PALETTE := { grass_a, grass_b, path_a, path_b, water_deep, water_shallow, foam, stone, wood, ... }`
  - `static func sun() -> DirectionalLight3D` / `static func fill() -> DirectionalLight3D`(채움광) / `static func environment() -> Environment`
  - 목적: `GameManager._build_environment`와 `Board`가 같은 팔레트를 공유하고, 톤 조정을 한 곳에서.
- **`CharacterMesh.build_billboard(tex, world_size, fit, opts := {})`** — 선택 옵션 Dictionary 추가(**기본값은 기존 호출과 100% 호환**):
  - `shaded:bool`(기본 false), `alpha_cut:int`(기본 OPAQUE_PREPASS), `cast_shadow:bool`(기본 false), `pixel_filter:bool`(기본 false=linear; true=nearest).
  - 용도: 캐릭터/소품 빌보드에 접지 그림자(블롭/실제)·픽셀 샤프니스 선택.
- **`MoveGuide.gd`** (신규 `Node3D`): 발밑 하이라이트 타일 + 위 방향 화살표(맥동). 공개 API는 `attach(player: Player)`와
  `set_visible_enabled(enabled: bool)`만. `GameManager`가 생성해 플레이어를 따라가게 한다(시각 전용, 입력/규칙 불변).
- **불변**: `GridUtil`, `LaneConfig`, `SaveManager`, `StageState`, 점수/코인/체력/스테이지/스폰 규칙, 씬 4개 구조.

## 3. 작업 항목 (우선순위 = 모바일 임팩트순)

### A. 라이팅 / WorldEnvironment 고도화  ★최고 임팩트·저위험
- **채움광 추가**: sun 반대쪽에서 약한 `DirectionalLight3D`(shadow off, 에너지 ~0.35, 약간 차가운 색) →
  **동료 glb·캐릭터의 그늘면이 검게 죽는 문제 해결**. 앰비언트 에너지도 1.1→~1.35로.
- **온기·채도**: 톤맵 유지(FILMIC) + `adjustments_enabled`로 saturation ~1.12, brightness 미세 +. 하늘/지평 색을 mokup의
  따뜻한 채도로 재조정. sun 색 약간 더 따뜻하게, 그림자 너무 진하지 않게(`shadow_opacity`/`directional_shadow` 부드럽게).
- **블룸 강화**: `glow_intensity` 0.3→~0.55, `glow_bloom` 약간, HDR 임계값 조정 → 포탈/성배/대장간 화로/꽃 emission이 은은히 번진다.
- **(데스크톱 전용)** `ssao_enabled`로 접지 음영(모바일은 자동 무시). 모바일 접지감은 항목 D의 블롭 그림자로 보완.

### B. 흐르는 강 셰이더  ★고임팩트
- 물 레인 타일에 **커스텀 spatial `ShaderMaterial`**(GLES3 호환) 적용: 2-레이어 스크롤 노이즈로 물결,
  `TIME` 기반 흐름(레인별 `river_dir`/`river_speed`와 방향 일치), 가장자리/통나무 주변 **흰 포말 라인**, 깊이에 따른
  명도 그라데이션, 약한 specular 하이라이트. 정적 텍스처 폴백 유지(셰이더 컴파일 실패 시).
- `Board._build_tiles`의 water_a/water_b 머티리얼을 이 셰이더로 교체(인스턴싱은 MultiMesh 유지, 머티리얼 1개 공유).

### C. 타일 입체감 + 잔디/흙 리치니스  ★중임팩트
- **블록 깊이**: 잔디/길 타일을 1×1 평면 대신 **얇은 박스(높이 ~0.12)** 로 만들어 측면 어두운 색 → Crossy Road식 블록 단차.
  여전히 머티리얼별 MultiMesh 1개(평면→박스 메시만 교체)라 드로우콜 불변.
- **색 변주**: even/odd 2단계를 넘어, `_hash2(x,z)` 기반으로 잔디를 3~4 틴트로 분산(MultiMesh를 틴트별로 분리, 총 배치 수 소폭↑).
  흙길은 가장자리 행에 더 어두운 테두리 톤. 강가(잔디↔물 경계)에 젖은 흙 띠.
- **클로버/잔풀**: 꽃(`_build_flowers`)에 더해 작은 초록 잔풀 점 MultiMesh 추가(가독성 영향 없는 낮이).

### D. 소품/포탈/성배 폴리시 + 접지 그림자  ★중임팩트
- **블롭 그림자**: `CharacterMesh.build_billboard` 신옵션으로 캐릭터/나무/마차 발밑에 반투명 어두운 원판(QuadMesh+원형 알파)
  추가 → mokup처럼 바닥에 붙어 보임. 단일 머티리얼 공유.
- **가장자리 숲 다양화**: 가을 나무(주황 잎) 비율, 이끼바위, 버섯, 통나무더미 밀도↑(여전히 MultiMesh). 빈 잔디 비율은 가독성 위해 유지.
- **포탈/대장간 발광**: emission 에너지·블룸과 함께, 포탈 주변 바위·룬 장식 추가. 화로 불빛 파티클(작은 주황 점) 옵션.
- **HQ 마을 군집**: 포탈 근처(상단) 가장자리에 대장간+상점+통+짐수레+모루를 mokup처럼 모아 배치(`_build_landmarks` 확장).

### E. 이동 가이드 reticle (`MoveGuide.gd`)  ★중임팩트(UX+룩)
- 플레이어 발밑에 **하이라이트 사각 타일**(흰 외곽선, 약한 emission 맥동) + 위쪽 **상승 화살표**(부드러운 위아래 애니).
  `GameManager`가 플레이어 위치를 따라가게 업데이트. 첫 입력 후 페이드아웃 옵션(시각 전용).

### F. HUD 톤 폴리시  ★저임팩트(여유 시)
- 둥근 패널/그림자/채도 톤을 mokup에 맞춤(별 ★레벨 배지, 왕관 BEST). 기능/레이아웃 불변, 스타일만.
  `MenuUI` 공용 스타일과 일관.

## 4. 적용 순서

1. `VisualTheme.gd` 추가 → 2. **A 라이팅/환경**(GameManager) → 3. **B 물 셰이더**(Board) →
4. **C 타일 입체/색**(Board) → 5. **D 소품/포탈/그림자**(CharacterMesh 옵션 + Board) →
6. **E MoveGuide** → 7. (여유) **F HUD 톤** → 8. `design.md` 동기화 + `LogicTests` 보강.

> 각 단계마다 헤드리스 캡처(데스크톱 `-s` 스크립트)로 룩 확인 + 에뮬레이터(gl_compat) 1컷으로 모바일 룩 검증.

## 5. 검증 계획

- `godot --headless --path Game res://Tests.tscn` → `[selftest] ALL PASS` 유지(현재 31). 신규 리소스 로드/폴백 테스트 추가:
  `visualtheme-palette`(키 존재), `water-shader-loads`, `moveguide-builds`.
- `godot --headless --path Game res://Main.tscn --quit-after 400` → 파스/스크립트 에러 0, exit 0. 종료 시 BGM 리소스 누수 경고는 기존과 동일 수준인지 확인.
- 데스크톱 F5 및 헤드리스 캡처로 540×960 / 1080×1920 프레이밍 확인.
- **모바일 검증**: `gl_compatibility`에서 물 셰이더·블룸·블롭 그림자가 의도대로 보이는지 에뮬레이터(`Pixel_3a ... arm64`) 설치 후 1컷.

## 6. 범위 밖 (이번 비주얼 업그레이드)

- 외부 생성 에셋(스프라이트/3D) 신규 도입 — Godot 절차/셰이더만.
- 게임 규칙·밸런스·스테이지 수치·HUD 기능 변경.
- 실제 픽셀아트 타일셋 교체(현 절차 텍스처/셰이더로 룩 끌어올리기 우선).
- 동료 glb LOD/병합(성능 항목은 별도).

## 7. 리스크 / 메모

- **gl_compat 셰이더 호환**: 물 셰이더는 GLES3 문법 한정(파생함수/노이즈는 텍스처 또는 해석적). 컴파일 실패 시 정적 폴백.
- **블룸 과다**: emission 다수(꽃/포탈/화로) → glow 임계값으로 과발광 방지, 모바일에서 톤 확인 필수.
- **타일 박스화 비용**: 평면→박스는 정점 수 증가하나 MultiMesh라 드로우콜 불변. 모바일 프레임 확인.
- mono Godot로만 APK export 가능(`/Applications/Godot_mono.app`, 템플릿 `4.7.stable.mono`). non-mono는 빌드 버전 불일치로 실패.
