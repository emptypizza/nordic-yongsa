---
description: Godot(C#) 프로젝트 규약 — 프로젝트 배치, net10/Godot.NET.Sdk 설정 주의, 코드 빌드 액터, 프리미티브 placeholder.
paths:
  - "Game/scripts/**/*.cs"
  - "Game/**/*.tscn"
  - "Game/project.godot"
  - "Game/*.csproj"
---

# Godot (C#) 프로젝트

- **프로젝트 루트는 `Game/`.** Godot 에디터로 `Game/` 폴더를 연다. 스크립트는 `Game/scripts/`, 단일 어셈블리 `Nordic`(`namespace Nordic`) — 별도 asmdef/어셈블리 경계 없음.
- **`TargetFramework`는 `net10.0`을 `Game/Nordic.csproj`에 직접 명시한다.** 글로벌 `Directory.Build.props`로 두지 않는다(godot#103545 — Godot가 `net8.0`을 자동 삽입하는 버그 회피). SDK는 `Godot.NET.Sdk/4.6.3`. 이 머신은 .NET 10 SDK라 net10.0이 네이티브로 돈다(RollForward 불필요).
- **액터는 코드로 빌드한다.** 각 액터(`Grail`/`Player`/`Enemy`)는 `Node3D` 파생 C# 클래스가 `_Ready()`에서 프리미티브 메시(`BoxMesh` 등)를 **자식 노드**로 생성한다. 액터별 `.tscn` 파일을 만들지 않는다(헤드리스/CLI 실행 결정성). 씬 파일은 `Main.tscn`(루트 + `GameManager`)과 `Tests.tscn`만.
- **표현은 프리미티브 placeholder로 끝까지 간다.** 색 입힌 프리미티브로 게임 로직이 완전히 돌아간 뒤, `.glb` lowpoly 에셋으로 **메시(자식 노드)만 교체**한다. 에셋 파이프라인은 별도 작업.
- `project.godot`은 Godot 에디터가 키 순서를 재정렬하므로 **수동 텍스트 편집을 최소화**한다(불필요한 diff·머지 충돌 유발).
- **CLI 검증.** 로직은 `dotnet build Game/Nordic.csproj`로 컴파일 확인, 게임 느낌은 에디터 F5 플레이로 확인. 순수 로직은 헤드리스 셀프테스트(→ `tests.md`).
