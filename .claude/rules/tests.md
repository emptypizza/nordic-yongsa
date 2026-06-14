---
description: 검증 게이트 — 빌드 + 헤드리스 셀프테스트. 순수 로직은 셀프테스트로 동작 고정.
paths:
  - "Game/scripts/**/*.cs"
---

# 검증 (Verification)

이 프로토타입은 결정론/네트워크가 없다 — golden hash·리플레이는 불필요(실시간 단일플레이라 `float`·`GD.Randf`를 정당하게 쓴다). 검증은 두 층이다.

- **빌드 게이트.** `dotnet build Game/Nordic.csproj` 에러 0. 모든 태스크 완료 전 통과.
- **순수 로직 셀프테스트.** 렌더링과 무관한 게임 수학(`GridUtil` — 좌표 변환, 직각 추격 `StepToward`, 경계 클램프)은 `Game/scripts/LogicTests.cs`(헤드리스 `res://Tests.tscn`)로 동작을 고정한다. **새 순수 로직을 추가하면 셀프테스트도 동반한다.**
- **게임 느낌은 수동 검증.** 이동감·충돌·난이도 등 시각/실시간 동작은 에디터 F5 플레이로 확인(자동 테스트 대상 아님).

## Completion Gates

- `dotnet build` 에러 0.
- 헤드리스 셀프테스트 `[selftest] ALL PASS`.
