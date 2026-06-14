---
tags: [Nordic, plan]
type: plan
created: 2026-06-14
---

# Grail Escort 프로토타입 구현 계획

> **실행자에게:** 태스크 단위로 진행. 각 단계는 `- [ ]` 체크박스로 추적. 코드 작업은 사용자 정책상 Codex 위임이 기본. `Game/`이 Godot 프로젝트 루트다.

**목표:** Godot 4.6.3 mono(C#)로, 4방향 그리드 위에서 자동 전진하는 성배를 검 든 용사가 호위하는 실시간 3D 프로토타입(스테이지 1개)을 만든다.

**아키텍처:** `Main.tscn`의 루트 `Node3D`에 붙은 `GameManager`가 환경/바닥/카메라/성배/용사/HUD를 **코드로** 조립한다(프리미티브 메시, .tscn 액터 파일 없음 — 메시는 각 액터의 자식 노드라 추후 `.glb`로 교체 가능). 순수 그리드 수학(`GridUtil`)은 헤드리스 셀프테스트로 검증하고, 게임 느낌은 에디터 플레이로 검증한다.

**기술 스택:** Godot 4.6.3 mono, C# / `net10.0` (`Godot.NET.Sdk/4.6.3`), .NET 10 SDK 네이티브.

**관련 문서:** `Game/docs/features/260614-grail-escort-prototype/design.md`

**설계 대비 구현 결정 1건:** 설계 §5의 `scenes/Grail.tscn` 등 액터별 씬 파일은 만들지 않는다. 각 액터는 `Node3D` 파생 C# 클래스가 `_Ready()`에서 자기 프리미티브 메시를 자식으로 생성한다(CLI/헤드리스 실행 결정성 + 추후 메시 교체 용이). 설계 §6의 "메시를 자식 노드로 분리" 의도와 일치.

**공통 변수(검증 명령에서 사용):**
```bash
GODOT="/Applications/Godot_mono.app/Contents/MacOS/Godot"
```

---

### Task 1: 프로젝트 스켈레톤 + GridUtil + 헤드리스 셀프테스트

**파일:**
- 생성: `Game/project.godot`
- 생성: `Game/Nordic.csproj`
- 생성: `Game/.gitignore`
- 생성: `Game/Main.tscn`
- 생성: `Game/Tests.tscn`
- 생성: `Game/scripts/GridUtil.cs`
- 생성: `Game/scripts/LogicTests.cs`

- [x] **Step 1: 작업 디렉터리/브랜치 준비**

```bash
cd /Users/yhjang/Dev/nordic
git init -q            # 아직 git repo 아님
git checkout -b feat/grail-escort-prototype
```

- [x] **Step 2: `Game/project.godot` 작성**

```ini
config_version=5

[application]

config/name="Nordic Grail Escort"
run/main_scene="res://Main.tscn"
config/features=PackedStringArray("4.6", "C#", "Forward Plus")

[dotnet]

project/assembly_name="Nordic"
```

- [x] **Step 3: `Game/Nordic.csproj` 작성**

`TargetFramework`는 `net10.0`을 csproj에 직접 명시한다(godot#103545 — Godot가 `net8.0`을 자동 삽입하는 버그 회피, 글로벌 `Directory.Build.props` 금지). 이 머신은 .NET 10 SDK라 네이티브로 돈다. (근거: 같은 Godot 4.6.3 + .NET 10을 쓰는 `planbattle-godot`의 검증된 설정.)

```xml
<Project Sdk="Godot.NET.Sdk/4.6.3">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <EnableDynamicLoading>true</EnableDynamicLoading>
  </PropertyGroup>
</Project>
```

- [x] **Step 4: `Game/.gitignore` 작성**

```gitignore
# Godot
.godot/
# .NET
.mono/
bin/
obj/
*.user
```

- [x] **Step 5: `Game/scripts/GridUtil.cs` 작성 (순수 그리드 수학)**

```csharp
using Godot;

namespace Nordic;

public static class GridUtil
{
    public const float TileSize = 1.0f;
    public const int Cols = 7;   // x: 0..6
    public const int Rows = 12;  // z: 0..11

    public static Vector3 CellToWorld(int cx, int cz, float y = 0f)
        => new Vector3(cx * TileSize, y, cz * TileSize);

    public static Vector2I WorldToCell(Vector3 w)
        => new Vector2I(
            Mathf.RoundToInt(w.X / TileSize),
            Mathf.RoundToInt(w.Z / TileSize));

    public static int ClampCol(int cx) => Mathf.Clamp(cx, 0, Cols - 1);
    public static int ClampRow(int cz) => Mathf.Clamp(cz, 0, Rows - 1);

    public static bool InBounds(int cx, int cz)
        => cx >= 0 && cx < Cols && cz >= 0 && cz < Rows;

    // 직각 한 칸 스텝: 맨해튼 거리를 줄이는 4방향 중, 남은 델타가 큰 축 우선.
    public static Vector2I StepToward(Vector2I from, Vector2I target)
    {
        int dx = target.X - from.X;
        int dz = target.Y - from.Y;
        if (dx == 0 && dz == 0) return Vector2I.Zero;
        if (Mathf.Abs(dx) >= Mathf.Abs(dz))
            return new Vector2I(Mathf.Sign(dx), 0);
        return new Vector2I(0, Mathf.Sign(dz));
    }
}
```

- [x] **Step 6: `Game/scripts/LogicTests.cs` 작성 (헤드리스 셀프테스트)**

```csharp
using Godot;

namespace Nordic;

public partial class LogicTests : Node
{
    private int _fail;

    public override void _Ready()
    {
        // StepToward: 대각선 절대 없음(둘 중 한 축만 ±1)
        Check("step-diag-x-major", GridUtil.StepToward(new Vector2I(0, 0), new Vector2I(3, 1)) == new Vector2I(1, 0));
        Check("step-diag-z-major", GridUtil.StepToward(new Vector2I(0, 0), new Vector2I(1, 3)) == new Vector2I(0, 1));
        Check("step-neg", GridUtil.StepToward(new Vector2I(5, 5), new Vector2I(5, 2)) == new Vector2I(0, -1));
        Check("step-same", GridUtil.StepToward(new Vector2I(2, 2), new Vector2I(2, 2)) == Vector2I.Zero);

        // CellToWorld / WorldToCell 왕복
        var w = GridUtil.CellToWorld(3, 7, 0.5f);
        Check("cell2world-x", Mathf.IsEqualApprox(w.X, 3f));
        Check("cell2world-z", Mathf.IsEqualApprox(w.Z, 7f));
        Check("world2cell", GridUtil.WorldToCell(w) == new Vector2I(3, 7));

        // 경계 클램프
        Check("clamp-col", GridUtil.ClampCol(99) == GridUtil.Cols - 1 && GridUtil.ClampCol(-5) == 0);
        Check("clamp-row", GridUtil.ClampRow(99) == GridUtil.Rows - 1 && GridUtil.ClampRow(-5) == 0);

        GD.Print(_fail == 0 ? "[selftest] ALL PASS" : $"[selftest] {_fail} FAIL");
        GetTree().Quit(_fail == 0 ? 0 : 1);
    }

    private void Check(string name, bool ok)
    {
        GD.Print($"[selftest] {name}: {(ok ? "PASS" : "FAIL")}");
        if (!ok) _fail++;
    }
}
```

- [x] **Step 7: `Game/Main.tscn` 작성 (빈 루트 — 다음 태스크에서 스크립트 부착)**

```
[gd_scene format=3]

[node name="Main" type="Node3D"]
```

- [x] **Step 8: `Game/Tests.tscn` 작성**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/LogicTests.cs" id="1"]

[node name="Tests" type="Node"]
script = ExtResource("1")
```

- [x] **Step 9: 빌드 확인**

실행:
```bash
cd /Users/yhjang/Dev/nordic && dotnet build Game/Nordic.csproj
```
예상: `Build succeeded.` (에러 0). 최초 실행 시 NuGet에서 `Godot.NET.Sdk`/`GodotSharp` 복원됨.

- [x] **Step 10: 헤드리스 셀프테스트 실행**

실행:
```bash
GODOT="/Applications/Godot_mono.app/Contents/MacOS/Godot"
"$GODOT" --headless --path /Users/yhjang/Dev/nordic/Game res://Tests.tscn
```
예상: 표준출력에 `[selftest] ... PASS` 행들 + 마지막 `[selftest] ALL PASS`, 종료코드 0.
실패 시(예: 런타임 못 찾음): `Game/Nordic.csproj`의 `TargetFramework`가 `net10.0`인지 확인한다(Godot가 `net8.0`을 끼워넣었으면 되돌린다 — godot#103545).

- [x] **Step 11: 커밋**

```bash
cd /Users/yhjang/Dev/nordic
git add Game/project.godot Game/Nordic.csproj Game/.gitignore Game/Main.tscn Game/Tests.tscn Game/scripts/GridUtil.cs Game/scripts/LogicTests.cs
git commit -m "feat(game): scaffold Godot mono project with GridUtil + headless self-test"
```

---

### Task 2: GameManager 골격 — 환경/바닥/카메라 + 성배 자동 전진

**파일:**
- 생성: `Game/scripts/Grail.cs`
- 생성: `Game/scripts/GameManager.cs`
- 수정: `Game/Main.tscn` (루트에 `GameManager` 스크립트 부착)

- [x] **Step 1: `Game/scripts/Grail.cs` 작성**

```csharp
using Godot;

namespace Nordic;

public partial class Grail : Node3D
{
    [Signal] public delegate void ReachedGoalEventHandler();
    [Signal] public delegate void DiedEventHandler();
    [Signal] public delegate void HealthChangedEventHandler(int hp, int maxHp);

    public int Cx { get; private set; } = 3;
    public int Cz { get; private set; } = 0;
    public int MaxHp { get; private set; } = 5;
    public int Hp { get; private set; }

    private const float HopInterval = 1.5f;
    private float _hopTimer;
    private bool _hopping;
    private float _invincible;
    private MeshInstance3D _mesh;

    public override void _Ready()
    {
        Hp = MaxHp;
        BuildVisual();
        Position = GridUtil.CellToWorld(Cx, Cz, 0.5f);
        EmitSignal(SignalName.HealthChanged, Hp, MaxHp);
    }

    private void BuildVisual()
    {
        _mesh = new MeshInstance3D
        {
            Mesh = new CylinderMesh { TopRadius = 0.25f, BottomRadius = 0.35f, Height = 0.7f }
        };
        _mesh.MaterialOverride = new StandardMaterial3D
        {
            AlbedoColor = new Color(1f, 0.84f, 0f),
            EmissionEnabled = true,
            Emission = new Color(1f, 0.7f, 0f),
            EmissionEnergyMultiplier = 1.5f
        };
        AddChild(_mesh);
    }

    public override void _Process(double delta)
    {
        float dt = (float)delta;

        // 위아래 bob
        _mesh.Position = new Vector3(0, Mathf.Sin(Time.GetTicksMsec() / 300f) * 0.05f, 0);

        // 무적 깜빡임
        if (_invincible > 0f)
        {
            _invincible -= dt;
            _mesh.Visible = Mathf.PosMod(Time.GetTicksMsec() / 100f, 2f) < 1f;
        }
        else
        {
            _mesh.Visible = true;
        }

        if (_hopping) return;
        _hopTimer += dt;
        if (_hopTimer >= HopInterval)
        {
            _hopTimer = 0f;
            Hop();
        }
    }

    private void Hop()
    {
        if (Cz + 1 >= GridUtil.Rows)
        {
            EmitSignal(SignalName.ReachedGoal);
            SetProcess(false);
            return;
        }
        Cz += 1;
        _hopping = true;
        Vector3 target = GridUtil.CellToWorld(Cx, Cz, 0.5f);
        Tween tween = CreateTween();
        tween.TweenProperty(this, "position", target, 0.3f).SetTrans(Tween.TransitionType.Sine);
        tween.TweenCallback(Callable.From(() => _hopping = false));
    }

    public void TakeDamage()
    {
        if (_invincible > 0f) return;
        Hp -= 1;
        _invincible = 1.0f;
        EmitSignal(SignalName.HealthChanged, Hp, MaxHp);
        if (Hp <= 0) EmitSignal(SignalName.Died);
    }
}
```

- [x] **Step 2: `Game/scripts/GameManager.cs` 작성 (이 태스크 범위: 환경/바닥/카메라/성배)**

```csharp
using Godot;
using System.Collections.Generic;

namespace Nordic;

public partial class GameManager : Node3D
{
    private enum State { Playing, Win, Lose }
    private State _state = State.Playing;

    private Grail _grail;
    private Camera3D _camera;
    private readonly Vector3 _cameraOffset = new Vector3(0, 9, -7);

    public override void _Ready()
    {
        BuildEnvironment();
        BuildGround();

        _grail = new Grail();
        AddChild(_grail);
        _grail.ReachedGoal += OnWin;
        _grail.Died += OnLose;
    }

    private void BuildEnvironment()
    {
        var we = new WorldEnvironment();
        we.Environment = new Godot.Environment
        {
            BackgroundMode = Godot.Environment.BGMode.Color,
            BackgroundColor = new Color(0.3f, 0.6f, 0.85f),
            AmbientLightSource = Godot.Environment.AmbientSource.Color,
            AmbientLightColor = new Color(0.4f, 0.4f, 0.4f)
        };
        AddChild(we);

        var sun = new DirectionalLight3D { ShadowEnabled = true };
        sun.RotationDegrees = new Vector3(-50, -40, 0);
        AddChild(sun);

        _camera = new Camera3D();
        _camera.Position = new Vector3(3, 9, -7);
        AddChild(_camera);
        _camera.Current = true;
    }

    private void BuildGround()
    {
        for (int x = 0; x < GridUtil.Cols; x++)
        for (int z = 0; z < GridUtil.Rows; z++)
        {
            var tile = new MeshInstance3D { Mesh = new BoxMesh { Size = new Vector3(1f, 0.1f, 1f) } };
            bool even = (x + z) % 2 == 0;
            tile.MaterialOverride = new StandardMaterial3D
            {
                AlbedoColor = even ? new Color(0.55f, 0.75f, 0.45f) : new Color(0.5f, 0.7f, 0.4f)
            };
            tile.Position = GridUtil.CellToWorld(x, z, -0.05f);
            AddChild(tile);
        }
    }

    public override void _Process(double delta)
    {
        if (_state != State.Playing) return;
        float dt = (float)delta;

        Vector3 focus = _grail.Position;
        Vector3 desired = focus + _cameraOffset;
        _camera.Position = _camera.Position.Lerp(desired, 1f - Mathf.Exp(-5f * dt));
        _camera.LookAt(focus, Vector3.Up);
    }

    private void OnWin()
    {
        _state = State.Win;
        GD.Print("[game] WIN");
    }

    private void OnLose()
    {
        _state = State.Lose;
        GD.Print("[game] LOSE");
    }
}
```

- [x] **Step 3: `Game/Main.tscn` 수정 (스크립트 부착)**

기존 내용을 아래로 교체:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/GameManager.cs" id="1"]

[node name="Main" type="Node3D"]
script = ExtResource("1")
```

- [x] **Step 4: 빌드 확인**

실행: `cd /Users/yhjang/Dev/nordic && dotnet build Game/Nordic.csproj`
예상: `Build succeeded.` (에러 0).

- [x] **Step 5: 헤드리스 스모크(런타임 에러 0 확인)**

실행:
```bash
GODOT="/Applications/Godot_mono.app/Contents/MacOS/Godot"
"$GODOT" --headless --path /Users/yhjang/Dev/nordic/Game res://Main.tscn --quit-after 300 2>&1 | grep -iE "SCRIPT ERROR|Cannot|NullReference" || echo "NO RUNTIME ERRORS"
```
예상: `NO RUNTIME ERRORS`. (300프레임 ≈ 5초 동안 성배가 자동 hop, 9칸 이상 전진)

- [ ] **Step 6: 에디터 플레이테스트(시각 확인)**

1. Godot_mono 에디터로 `Game/` 프로젝트 열기 → `Main.tscn` → F5(또는 ▶ Play).
2. 확인 항목:
   - 격자 바닥(7×12, 교차색)이 보이고, 발광 금색 성배가 시작 칸에 있다.
   - 성배가 약 1.5초마다 한 칸씩 앞(+z)으로 튀듯 hop 한다.
   - 카메라가 성배를 부드럽게 따라간다.
   - 성배가 끝 행 도달 시 콘솔(Output)에 `[game] WIN` 출력.
   - Output에 에러(빨강) 0건.

- [x] **Step 7: 커밋**

```bash
cd /Users/yhjang/Dev/nordic
git add Game/scripts/Grail.cs Game/scripts/GameManager.cs Game/Main.tscn
git commit -m "feat(game): grail auto-hop with ground, camera follow, win/lose stubs"
```

---

### Task 3: 용사(Player) — 4방향 그리드 hop + 키 입력

**파일:**
- 생성: `Game/scripts/Player.cs`
- 수정: `Game/scripts/GameManager.cs` (입력맵 등록 + 용사 생성)

- [x] **Step 1: `Game/scripts/Player.cs` 작성**

```csharp
using Godot;

namespace Nordic;

public partial class Player : Node3D
{
    public int Cx { get; private set; } = 4;
    public int Cz { get; private set; } = 0;

    private bool _hopping;

    public override void _Ready()
    {
        BuildVisual();
        Position = GridUtil.CellToWorld(Cx, Cz, 0.5f);
    }

    private void BuildVisual()
    {
        var body = new MeshInstance3D { Mesh = new BoxMesh { Size = new Vector3(0.5f, 0.8f, 0.5f) } };
        body.MaterialOverride = new StandardMaterial3D { AlbedoColor = new Color(0.2f, 0.5f, 0.9f) };
        AddChild(body);

        var sword = new MeshInstance3D { Mesh = new BoxMesh { Size = new Vector3(0.08f, 0.08f, 0.6f) } };
        sword.MaterialOverride = new StandardMaterial3D { AlbedoColor = new Color(0.9f, 0.9f, 0.95f) };
        sword.Position = new Vector3(0.35f, 0.1f, 0.2f);
        AddChild(sword);
    }

    public override void _Process(double delta)
    {
        if (_hopping) return;

        // 누르고 있으면 hop 완료 후 다음 프레임에 연속 hop (디자인: hold = 연속 hop)
        if (Input.IsActionPressed("move_up")) TryHop(0, 1);
        else if (Input.IsActionPressed("move_down")) TryHop(0, -1);
        else if (Input.IsActionPressed("move_left")) TryHop(-1, 0);
        else if (Input.IsActionPressed("move_right")) TryHop(1, 0);
    }

    public void TryHop(int dx, int dz)
    {
        if (_hopping) return;
        int nx = GridUtil.ClampCol(Cx + dx);
        int nz = GridUtil.ClampRow(Cz + dz);
        if (nx == Cx && nz == Cz) return; // 경계에 막힘
        Cx = nx;
        Cz = nz;
        _hopping = true;
        Vector3 target = GridUtil.CellToWorld(Cx, Cz, 0.5f);
        Tween tween = CreateTween();
        tween.TweenProperty(this, "position", target, 0.12f).SetTrans(Tween.TransitionType.Sine);
        tween.TweenCallback(Callable.From(() => _hopping = false));
    }
}
```

- [x] **Step 2: `GameManager.cs` 에 입력맵 등록 메서드 추가**

`GameManager` 클래스 안(예: `BuildGround` 아래)에 추가:
```csharp
    private static void SetupInput()
    {
        AddKeyAction("move_up", Key.W, Key.Up);
        AddKeyAction("move_down", Key.S, Key.Down);
        AddKeyAction("move_left", Key.A, Key.Left);
        AddKeyAction("move_right", Key.D, Key.Right);
    }

    private static void AddKeyAction(string name, params Key[] keys)
    {
        if (InputMap.HasAction(name)) return;
        InputMap.AddAction(name);
        foreach (Key k in keys)
            InputMap.ActionAddEvent(name, new InputEventKey { PhysicalKeycode = k });
    }
```

- [x] **Step 3: `GameManager._Ready()` 수정 — 입력 등록 + 용사 생성**

`_Ready()` 본문을 아래로 교체:
```csharp
    public override void _Ready()
    {
        SetupInput();
        BuildEnvironment();
        BuildGround();

        _grail = new Grail();
        AddChild(_grail);
        _grail.ReachedGoal += OnWin;
        _grail.Died += OnLose;

        _player = new Player();
        AddChild(_player);
    }
```

- [x] **Step 4: `GameManager` 에 `_player` 필드 추가**

`private Grail _grail;` 아래에 추가:
```csharp
    private Player _player;
```

- [x] **Step 5: 카메라 포커스를 성배·용사 중점으로 변경**

`_Process` 의 `Vector3 focus = _grail.Position;` 줄을 아래로 교체:
```csharp
        Vector3 focus = (_grail.Position + _player.Position) * 0.5f;
```

- [x] **Step 6: 빌드 확인**

실행: `cd /Users/yhjang/Dev/nordic && dotnet build Game/Nordic.csproj`
예상: `Build succeeded.` (에러 0).

- [ ] **Step 7: 에디터 플레이테스트**

1. `Main.tscn` F5.
2. 확인 항목:
   - 파란 블록 용사(+검 박스)가 성배 옆 칸에 있다.
   - WASD / 방향키로 용사가 **한 칸씩** 튀듯 이동한다.
   - 키를 누르고 있으면 연속으로 칸 이동한다.
   - 보드 경계 밖으로는 나가지 않는다(막힘).
   - Output 에러 0건.

- [x] **Step 8: 커밋**

```bash
cd /Users/yhjang/Dev/nordic
git add Game/scripts/Player.cs Game/scripts/GameManager.cs
git commit -m "feat(game): grid-hop warrior with WASD/arrow input"
```

---

### Task 4: 적(Enemy) — 격자 직각 추격 + 스폰

**파일:**
- 생성: `Game/scripts/Enemy.cs`
- 수정: `Game/scripts/GameManager.cs` (스폰 + 적 리스트)

- [ ] **Step 1: `Game/scripts/Enemy.cs` 작성**

```csharp
using Godot;

namespace Nordic;

public partial class Enemy : Node3D
{
    public float Speed = 2.5f;
    public float Stun { get; private set; }

    private Grail _grail;
    private MeshInstance3D _mesh;
    private Vector2I _cell;
    private Vector3 _targetPos;
    private bool _hasTarget;

    public void Init(Grail grail, Vector2I startCell)
    {
        _grail = grail;
        _cell = startCell;
    }

    public override void _Ready()
    {
        BuildVisual();
        Position = GridUtil.CellToWorld(_cell.X, _cell.Y, 0.4f);
        PickNextTarget();
    }

    private void BuildVisual()
    {
        _mesh = new MeshInstance3D { Mesh = new BoxMesh { Size = new Vector3(0.6f, 0.6f, 0.6f) } };
        _mesh.MaterialOverride = new StandardMaterial3D { AlbedoColor = new Color(0.5f, 0.1f, 0.1f) };
        AddChild(_mesh);

        foreach (float ex in new[] { -0.15f, 0.15f })
        {
            var eye = new MeshInstance3D { Mesh = new BoxMesh { Size = new Vector3(0.1f, 0.1f, 0.05f) } };
            eye.MaterialOverride = new StandardMaterial3D { AlbedoColor = Colors.White };
            eye.Position = new Vector3(ex, 0.1f, 0.31f);
            AddChild(eye);
        }
    }

    private void PickNextTarget()
    {
        var grailCell = new Vector2I(_grail.Cx, _grail.Cz);
        Vector2I step = GridUtil.StepToward(_cell, grailCell);
        if (step == Vector2I.Zero)
        {
            _hasTarget = false;
            return;
        }
        _cell += step;
        _targetPos = GridUtil.CellToWorld(_cell.X, _cell.Y, 0.4f);
        _hasTarget = true;
    }

    public override void _Process(double delta)
    {
        float dt = (float)delta;

        if (Stun > 0f)
        {
            Stun -= dt;
            _mesh.Rotation = new Vector3(0, GD.Randf() * 0.5f, 0); // 기절 흔들림
            return;
        }
        _mesh.Rotation = Vector3.Zero;

        if (!_hasTarget)
        {
            PickNextTarget();
            return;
        }

        Position = Position.MoveToward(_targetPos, Speed * dt);
        if (Position.DistanceTo(_targetPos) < 0.01f)
            PickNextTarget();
    }

    public void Knockback(Vector3 fromDir)
    {
        Vector3 pushed = Position - fromDir.Normalized() * 2.0f * GridUtil.TileSize;
        Vector2I cell = GridUtil.WorldToCell(pushed);
        _cell = new Vector2I(GridUtil.ClampCol(cell.X), GridUtil.ClampRow(cell.Y));
        Position = GridUtil.CellToWorld(_cell.X, _cell.Y, 0.4f);
        Stun = 1.0f;
        _hasTarget = false;
    }
}
```

- [ ] **Step 2: `GameManager` 에 적 필드/상수 추가**

`private Player _player;` 아래에 추가:
```csharp
    private readonly List<Enemy> _enemies = new();
    private const int MaxEnemies = 6;
    private const float SpawnInterval = 1.2f;
    private float _spawnTimer;
```

- [ ] **Step 3: `GameManager` 에 스폰 메서드 추가**

클래스 안에 추가:
```csharp
    private void SpawnEnemy()
    {
        var grailCell = new Vector2I(_grail.Cx, _grail.Cz);
        Vector2I cell = grailCell;
        for (int guard = 0; guard < 20; guard++)
        {
            int cx = GD.RandRange(0, GridUtil.Cols - 1);
            int cz = GD.RandRange(0, GridUtil.Rows - 1);
            cell = new Vector2I(cx, cz);
            int manhattan = Mathf.Abs(cx - grailCell.X) + Mathf.Abs(cz - grailCell.Y);
            if (manhattan >= 4) break; // 성배에서 최소 4칸 떨어져 스폰
        }

        var enemy = new Enemy();
        enemy.Init(_grail, cell);
        AddChild(enemy);
        _enemies.Add(enemy);
    }
```

- [ ] **Step 4: `GameManager._Process` 에 스폰 루프 추가**

`_Process` 의 카메라 추적 블록 **아래**(메서드 끝나기 전)에 추가:
```csharp
        _spawnTimer += dt;
        if (_spawnTimer >= SpawnInterval && _enemies.Count < MaxEnemies)
        {
            _spawnTimer = 0f;
            SpawnEnemy();
        }
```

- [ ] **Step 5: 빌드 확인**

실행: `cd /Users/yhjang/Dev/nordic && dotnet build Game/Nordic.csproj`
예상: `Build succeeded.` (에러 0).

- [ ] **Step 6: 에디터 플레이테스트**

1. `Main.tscn` F5.
2. 확인 항목:
   - 어두운 적 박스(흰 눈)가 약 1.2초 간격으로 최대 6마리까지 스폰된다.
   - 적이 성배를 향해 **격자 레인을 따라 직각으로만** 이동한다(비스듬한 직선 이동 없음 — 가로로 가다가 세로로 꺾임).
   - 성배가 이동하면 적의 경로도 갱신된다.
   - Output 에러 0건.

- [ ] **Step 7: 커밋**

```bash
cd /Users/yhjang/Dev/nordic
git add Game/scripts/Enemy.cs Game/scripts/GameManager.cs
git commit -m "feat(game): right-angle grid-pursuit enemies with spawner"
```

---

### Task 5: 충돌/전투/HP + HUD(HP 바·결과·재시작·가상 d-pad)

**파일:**
- 생성: `Game/scripts/Hud.cs`
- 수정: `Game/scripts/GameManager.cs` (충돌 판정 + HUD 연결 + 재시작)

- [ ] **Step 1: `Game/scripts/Hud.cs` 작성**

```csharp
using Godot;
using System;

namespace Nordic;

public partial class Hud : CanvasLayer
{
    public event Action<Vector2I> HopRequested;
    public event Action RetryPressed;

    private ProgressBar _hpBar;
    private Label _hpLabel;
    private Label _stageLabel;
    private Panel _resultPanel;
    private Label _resultLabel;

    public override void _Ready()
    {
        BuildTopBar();
        BuildResultPanel();
        BuildDpad();
    }

    private void BuildTopBar()
    {
        _stageLabel = new Label { Text = "STAGE 1" };
        _stageLabel.Position = new Vector2(16, 12);
        AddChild(_stageLabel);

        _hpLabel = new Label { Text = "5 / 5" };
        _hpLabel.Position = new Vector2(16, 36);
        AddChild(_hpLabel);

        _hpBar = new ProgressBar { MinValue = 0, MaxValue = 5, Value = 5, ShowPercentage = false };
        _hpBar.Position = new Vector2(90, 36);
        _hpBar.CustomMinimumSize = new Vector2(180, 18);
        AddChild(_hpBar);
    }

    private void BuildResultPanel()
    {
        _resultPanel = new Panel { Visible = false };
        _resultPanel.SetAnchorsPreset(Control.LayoutPreset.Center);
        _resultPanel.CustomMinimumSize = new Vector2(320, 160);
        _resultPanel.Position = new Vector2(-160, -80);
        AddChild(_resultPanel);

        _resultLabel = new Label { Text = "" };
        _resultLabel.HorizontalAlignment = HorizontalAlignment.Center;
        _resultLabel.SetAnchorsPreset(Control.LayoutPreset.TopWide);
        _resultLabel.Position = new Vector2(0, 24);
        _resultPanel.AddChild(_resultLabel);

        var retry = new Button { Text = "RETRY" };
        retry.CustomMinimumSize = new Vector2(140, 44);
        retry.Position = new Vector2(90, 90);
        retry.Pressed += () => RetryPressed?.Invoke();
        _resultPanel.AddChild(retry);
    }

    private void BuildDpad()
    {
        // 모바일/마우스용 가상 d-pad (좌하단). 같은 4방향 hop을 발생.
        AddDpadButton("▲", new Vector2(70, -150), new Vector2I(0, 1));
        AddDpadButton("▼", new Vector2(70, -60), new Vector2I(0, -1));
        AddDpadButton("◀", new Vector2(20, -105), new Vector2I(-1, 0));
        AddDpadButton("▶", new Vector2(120, -105), new Vector2I(1, 0));
    }

    private void AddDpadButton(string text, Vector2 offset, Vector2I dir)
    {
        var btn = new Button { Text = text };
        btn.CustomMinimumSize = new Vector2(48, 48);
        btn.SetAnchorsPreset(Control.LayoutPreset.BottomLeft);
        btn.Position = offset;
        btn.Pressed += () => HopRequested?.Invoke(dir);
        AddChild(btn);
    }

    public void SetHealth(int hp, int maxHp)
    {
        _hpBar.MaxValue = maxHp;
        _hpBar.Value = hp;
        _hpLabel.Text = $"{hp} / {maxHp}";
    }

    public void ShowResult(string title, Color color)
    {
        _resultLabel.Text = title;
        _resultLabel.AddThemeColorOverride("font_color", color);
        _resultPanel.Visible = true;
    }
}
```

- [ ] **Step 2: `GameManager` 에 `_hud` 필드 추가**

`private Camera3D _camera;` 위에 추가:
```csharp
    private Hud _hud;
```

- [ ] **Step 3: `GameManager._Ready()` 끝에 HUD 생성/연결 추가**

`_Ready()` 의 `AddChild(_player);` 아래에 추가:
```csharp
        _hud = new Hud();
        AddChild(_hud);
        _hud.HopRequested += dir => _player.TryHop(dir.X, dir.Y);
        _hud.RetryPressed += Restart;
        _grail.HealthChanged += _hud.SetHealth;
        _hud.SetHealth(_grail.Hp, _grail.MaxHp); // 초기값(연결 전 _Ready emit 보정)
```

- [ ] **Step 4: `GameManager._Process` 에 충돌 판정 추가**

`_Process` 의 스폰 블록 **아래**(메서드 끝나기 전)에 추가:
```csharp
        for (int i = _enemies.Count - 1; i >= 0; i--)
        {
            Enemy e = _enemies[i];

            // 적 ↔ 용사: 넉백 + 기절 (처치 없음)
            if (e.Stun <= 0f && e.Position.DistanceTo(_player.Position) < 0.6f)
            {
                e.Knockback(e.Position - _player.Position);
            }

            // 적 ↔ 성배: HP -1, 적 소멸
            if (e.Position.DistanceTo(_grail.Position) < 0.6f)
            {
                _grail.TakeDamage();
                e.QueueFree();
                _enemies.RemoveAt(i);
            }
        }
```

- [ ] **Step 5: `OnWin`/`OnLose` 를 HUD 결과 표시로 교체 + `Restart` 추가**

기존 `OnWin`/`OnLose` 본문 교체 및 메서드 추가:
```csharp
    private void OnWin()
    {
        _state = State.Win;
        _hud.ShowResult("ARRIVED!", new Color(0.3f, 0.8f, 0.3f));
    }

    private void OnLose()
    {
        _state = State.Lose;
        _hud.ShowResult("MISSION FAILED", new Color(1f, 0.24f, 0f));
    }

    private void Restart()
    {
        GetTree().ReloadCurrentScene();
    }
```

- [ ] **Step 6: 빌드 확인**

실행: `cd /Users/yhjang/Dev/nordic && dotnet build Game/Nordic.csproj`
예상: `Build succeeded.` (에러 0).

- [ ] **Step 7: 에디터 플레이테스트 (전체 루프)**

1. `Main.tscn` F5.
2. 확인 항목:
   - 상단에 STAGE/HP 바 표시. 좌하단 가상 d-pad 표시.
   - 적이 성배에 닿으면 HP가 1 줄고 성배가 1초 깜빡(무적), 그 적은 사라진다.
   - 용사가 적에 닿으면 적이 들어온 방향으로 튕겨나가고 1초 기절(흔들림), HP는 안 닳음.
   - d-pad 버튼으로도 용사가 칸 이동한다.
   - 성배 HP 0 → "MISSION FAILED" 패널 + RETRY. RETRY 누르면 씬 재시작.
   - 성배가 끝 행 도달 → "ARRIVED!" 패널.
   - Output 에러 0건.

- [ ] **Step 8: 커밋**

```bash
cd /Users/yhjang/Dev/nordic
git add Game/scripts/Hud.cs Game/scripts/GameManager.cs
git commit -m "feat(game): collisions, HP, knockback, HUD with result/retry and virtual d-pad"
```

---

### Task 6: 최종 튜닝 패스 + 플레이 검증 체크리스트

테스트 불가 도메인(게임 느낌)이라 수동 검증 + 값 조정만.

**파일:**
- 수정: (필요 시) `Game/scripts/GameManager.cs`, `Game/scripts/Grail.cs`, `Game/scripts/Enemy.cs` 의 튜닝 상수

- [ ] **Step 1: 풀 플레이 1회 — 난이도 감각 확인**

`Main.tscn` F5 후 한 판 끝까지(클리어 또는 실패) 플레이. 다음을 메모:
- 성배가 너무 빨리/느리게 도착하는가? (`Grail.HopInterval`, 기본 1.5초)
- 적이 너무 많아/적어 막을 수 없/너무 쉬운가? (`GameManager.MaxEnemies` 6, `SpawnInterval` 1.2초, `Enemy.Speed` 2.5)
- 용사 이동이 답답한가? (`Player` hop 트윈 0.12초)

- [ ] **Step 2: 튜닝 값 조정(필요 시에만)**

위 상수 중 어긋난 것만 수정. 한 번에 한 값씩 바꾸고 재플레이. (예: 너무 쉬우면 `MaxEnemies = 8`, `SpawnInterval = 0.9f`.)

- [ ] **Step 3: 최종 검증 체크리스트(모두 통과해야 완료)**

`Main.tscn` F5 후:
- [ ] 성배가 자동으로 끝까지 전진하고, 끝 행에서 "ARRIVED!" 표시.
- [ ] 적을 일부러 다 통과시키면 HP가 0까지 닳고 "MISSION FAILED" + RETRY.
- [ ] RETRY로 처음부터 재시작.
- [ ] 적은 항상 격자 직각으로만 추격(대각선 0).
- [ ] 용사는 WASD/방향키/d-pad로 칸 단위 이동, 경계 밖 못 나감.
- [ ] 용사 몸통 박치기로 적 넉백+기절(처치 안 됨).
- [ ] 전체 세션 Output 에러 0건.

- [ ] **Step 4: 커밋(튜닝 변경이 있었다면)**

```bash
cd /Users/yhjang/Dev/nordic
git add -A Game/scripts
git commit -m "chore(game): tune difficulty constants after playtest"
```

---

## 자체 검토 (작성자 체크)

**SPEC 커버리지(설계 § 대조):**
- §1 개요(호위/HP0 패배/실시간/1스테이지) → Task 2(성배·win/lose), Task 5(HP·결과).
- §2 그리드 7×12 → Task 1 `GridUtil`.
- §3 이동: 성배 오토홉 → Task 2 / 용사 grid hop(WASD=hop) → Task 3 / 적 연속 직각 → Task 4 + `GridUtil.StepToward`(Task 1 테스트).
- §4 충돌/전투(적↔성배 HP-1·소멸, 적↔용사 넉백+기절·처치없음) → Task 5.
- §5 스크립트 구조 → Task 1~5 (단, `GridUtil`은 정적 헬퍼로 채택, 액터 .tscn은 코드 빌드로 대체 — 상단 "구현 결정" 명시).
- §6 카메라/프리미티브 아트 → Task 2(카메라·바닥·환경), 각 액터 `BuildVisual`.
- §7 실시간 루프 → 각 `_Process`.
- §8 out-of-scope(사운드/세이브/멀티스테이지/실제 voxel) → 미포함 확인.

**Placeholder 스캔:** "TBD/TODO/나중에" 없음. 모든 코드 단계에 전체 코드 포함.

**타입 일관성 점검:** `Grail.Cx/Cz/Hp/MaxHp/TakeDamage`, 시그널 `ReachedGoal/Died/HealthChanged(int,int)`; `Player.TryHop(int,int)`; `Enemy.Init(Grail,Vector2I)/Stun/Knockback(Vector3)`; `Hud.SetHealth(int,int)/ShowResult(string,Color)/HopRequested(Vector2I)/RetryPressed`; `GridUtil.StepToward/CellToWorld/WorldToCell/ClampCol/ClampRow` — Task 간 시그니처 일치 확인.

**신규 파일 배치:** 모든 스크립트는 `Game/scripts/` 단일 어셈블리(`Nordic.csproj`), 같은 `namespace Nordic` — 상호 참조 가능. 별도 어셈블리/asmdef 경계 없음.
