# agent-sprite-forge — Claude Code 적용 메모

이 폴더의 두 스킬(`generate2dsprite`, `generate2dmap`)은
[agent-sprite-forge](https://github.com/0x0funky/agent-sprite-forge) 를 이 repo의
Claude Code 스킬로 설치한 것이다. SKILL.md / references / scripts 는 **업스트림 원본 그대로**이며,
아래 두 가지만 이 환경에 맞춰 적용한다.

## 1) 이미지 생성 도구 매핑

원본 스킬은 Codex 내장 `image_gen` / `view_image` 를 전제로 쓴다. Claude Code에서는:

- `image_gen` (원본 마젠타 시트 생성) → 이 세션의 **`generate_image` MCP 도구**(higgsfield)를 사용.
  프롬프트에 `solid flat magenta (#FF00FF) background, no gradients, no text` 규칙을 그대로 유지한다.
- `view_image` (로컬 레퍼런스 표시) → Claude Code의 `Read` 도구로 이미지를 먼저 띄운 뒤 참조한다.
- `$CODEX_HOME/generated_images/...` 경로 → 생성된 raw PNG를 작업 폴더로 복사해서 쓴다.

스킬 워크플로(에셋 계획 → 프롬프트 직접 작성 → raw 생성 → 로컬 후처리 → QC)는 그대로 따른다.

## 2) Python 후처리 스크립트 실행

`scripts/*.py`(마젠타 제거, 프레임 분할, 정렬, 투명 PNG/GIF export, QC)는 numpy/Pillow가 필요하다.
글로벌 환경을 건드리지 않도록 이 폴더에 전용 venv를 두었다(`.venv/`, git 미추적).

SKILL.md가 `python scripts/...py` 로 안내하는 부분은 이 venv 인터프리터로 실행한다:

```bash
# 예: 스프라이트 시트 후처리
.claude/skills/.venv/bin/python \
  .claude/skills/generate2dsprite/scripts/generate2dsprite.py process \
  --input raw-sheet.png --target creature --mode idle \
  --rows 2 --cols 2 --shared-scale --align center \
  --output-dir <run-dir>
```

venv가 없으면 재생성:

```bash
cd .claude/skills && python3 -m venv .venv && \
  ./.venv/bin/python -m pip install "numpy>=1.26" "Pillow>=10.0"
```

## 사용법

Claude Code에서 자연어로 호출하면 된다. 예:

- "generate2dsprite로 4방향으로 움직이는 검사 워리어 idle 시트 만들어줘"
- "generate2dmap으로 grail escort용 4방향 그리드 보드 맵 prop pack 뽑아줘"

이 게임(Nordic — Grail Escort)의 스프라이트/맵 에셋 제작에 바로 쓸 수 있다.

## 인게임 배선 (2026-06-27)

게임이 sprite-forge 출력물을 **실제로 소비**하도록 배선해 두었다.

- `Game/scripts/Enemy.gd` → 상수 `GEN_SHEET = "res://scripts/gen/goblin/sheet-transparent.png"`.
  이 파일이 있으면 적이 **빌보드 Sprite3D**(2x2 프레임 순환)로 렌더, 없으면 프리미티브 박스로 폴백.
- 즉 아래 한 흐름으로 시트만 만들면 적이 자동으로 생성 스프라이트를 쓴다.

```bash
# 1) 마젠타 raw 시트 생성: image_gen → 이 세션에선 generate_image(higgsfield) MCP.
#    프롬프트엔 "2x2 grid, solid flat magenta #FF00FF, no text, centered, no edge crossing" 유지.
#    (※ 2026-06-27 기준 higgsfield 워크스페이스 'Out of credits' → 크레딧 충전 또는 다른 image-gen 백엔드 필요)
# 2) 후처리(마젠타 제거 → 투명 시트/프레임/GIF):
.claude/skills/.venv/bin/python \
  .claude/skills/generate2dsprite/scripts/generate2dsprite.py process \
  --input Game/scripts/gen/goblin/raw-sheet.png \
  --target creature --mode idle --rows 2 --cols 2 --shared-scale --align center \
  --output-dir Game/scripts/gen/goblin
# 3) 그러면 sheet-transparent.png 가 생기고, Godot 실행 시 적이 그 스프라이트로 바뀐다.
```

> 상태: 플러그인 설치·검증 완료, 인게임 소비 경로 배선 완료. **남은 1스텝은 이미지 생성(크레딧)뿐.**
> 검증된 후처리 파이프라인은 합성 마젠타 시트로 end-to-end 통과 확인(투명 RGBA + 4프레임 GIF + 메타).
