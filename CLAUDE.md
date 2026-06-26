# Nordic — Grail Escort (Godot prototype)

A real-time grid escort game. A sword-wielding warrior protects an auto-advancing
sacred grail across a 4-directional grid board. Engine: **Godot (GDScript), 3D** (Godot 4.7).

## Project layout

- The repo root holds meta/config (this file, shared tooling).
- **The Godot project lives in `Game/`** — `Game/project.godot`, the scene files at the
  `Game/` root (`Title.tscn`, `StageSelect.tscn`, `Main.tscn`, `Tests.tscn`), and
  `Game/scripts/`. Treat `Game/` as the Godot project root; open that folder in the editor.

## Docs policy (OVERRIDES the global vault policy)

- Planning / design / feature docs live **in the repo, NOT in the Obsidian vault**.
- Path: **`Game/docs/features/YYMMDD-title/`** — one folder per feature
  (e.g. `Game/docs/features/260614-grail-escort-prototype/`).
- Rationale: this is a shared, multi-contributor project — docs must travel with the
  code so every collaborator sees them in the repo, not in a personal vault.

## Collaboration

- Multiple people work on this repo. Keep design, plans, and code self-contained here.
- External-facing text (README, CLAUDE, CHANGELOG, commits, PRs, code comments) in English;
  planning/design docs may be in Korean to match the team.
