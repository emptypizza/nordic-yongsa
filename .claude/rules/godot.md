---
description: Godot(GDScript) 프로젝트 규약 — 프로젝트 배치, 코드 빌드 액터, 프리미티브 placeholder, 헤드리스 검증.
paths:
  - "Game/scripts/**/*.gd"
  - "Game/**/*.tscn"
  - "Game/project.godot"
---

# Godot (GDScript) 프로젝트

- **프로젝트 루트는 `Game/`.** Godot 에디터로 `Game/` 폴더를 연다. 엔진은 **Godot 4.7**. 스크립트는 `Game/scripts/`에 둔다. 타입은 `class_name`으로 공유하며 별도 어셈블리/모듈 경계가 없다.
- **액터는 코드로 빌드한다.** 각 액터(`Grail`/`Player`/`Enemy`)는 `Node3D` 파생 GDScript가 `_ready()`에서 프리미티브 메시(`BoxMesh` 등)를 **자식 노드**로 생성한다. 액터별 `.tscn` 파일을 만들지 않는다(헤드리스/CLI 실행 결정성). 액터는 `GameManager`가 `.new()` + `add_child()`로 코드 생성한다.
- **표현은 프리미티브 placeholder로 끝까지 간다.** 색 입힌 프리미티브로 게임 로직이 완전히 돌아간 뒤, `.glb` lowpoly 에셋으로 **메시(자식 노드)만 교체**한다. 현재 `Player`는 이미 `Test Ch.glb` voxel 모델을 쓰고, 나머지 액터(`Grail`/`Enemy`)는 아직 프리미티브다. 에셋 파이프라인은 별도 작업.
- **씬 파일은 4개다.** `Title.tscn`(메인 씬 / 진입점), `StageSelect.tscn`, `Main.tscn`(게임 본체 — 루트 + `GameManager`), `Tests.tscn`(셀프테스트). 흐름: `Title` → `StageSelect` → `Main`.
- `project.godot`은 Godot 에디터가 키 순서를 재정렬하므로 **수동 텍스트 편집을 최소화**한다(불필요한 diff·머지 충돌 유발).
- **CLI 검증.** macOS에는 `timeout`이 없으므로 Godot의 `--quit-after` 또는 `gtimeout`을 쓴다. 설치된 Godot는 `/opt/homebrew/bin/godot`.
  - 셀프테스트(`LogicTests.gd` via `Tests.tscn`):
    `/opt/homebrew/bin/godot --headless --path Game res://Tests.tscn` → `[selftest] ALL PASS` 기대.
  - 게임 본체 헤드리스 구동:
    `/opt/homebrew/bin/godot --headless --path Game res://Main.tscn --quit-after 450` → exit 0, SCRIPT/Parse 에러 0개 기대(450프레임이면 적 스폰·전투까지 실행).
  - 게임 느낌은 에디터 F5 플레이로 확인.
