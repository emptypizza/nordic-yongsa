using Godot;
using System.Collections.Generic;

namespace Nordic;

public partial class GameManager : Node3D
{
    private enum State { Playing, Win, Lose }
    private State _state = State.Playing;

    private Grail _grail;
    private Player _player;
    private readonly List<Enemy> _enemies = new();
    private const int MaxEnemies = 6;
    private const int MinEnemySpawnDistance = 10;
    private const int SpawnDistanceBand = 6;
    private const float SpawnInterval = 2.5f;
    private float _spawnTimer;
    private Hud _hud;
    private Camera3D _camera;
    private readonly Vector3 _cameraOffset = new Vector3(0, 11, -8);
    private const float CameraLookAhead = 7f; // Look ahead on +z so portrait framing keeps action lower.

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

        _hud = new Hud();
        AddChild(_hud);
        _hud.HopRequested += dir => _player.TryHop(dir.X, dir.Y);
        _hud.RetryPressed += Restart;
        _grail.HealthChanged += _hud.SetHealth;
        _hud.SetHealth(_grail.Hp, _grail.MaxHp); // 초기값(연결 전 _Ready emit 보정)
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
        _camera.KeepAspect = Camera3D.KeepAspectEnum.Width;
        _camera.Position = new Vector3(GridUtil.Cols / 2f, 11f, -8f);
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

    private void SpawnEnemy()
    {
        var grailCell = new Vector2I(_grail.Cx, _grail.Cz);
        Vector2I cell = grailCell;
        for (int guard = 0; guard < 24; guard++)
        {
            float ang = GD.Randf() * Mathf.Tau;
            float dist = MinEnemySpawnDistance + GD.Randf() * SpawnDistanceBand;
            int cx = GridUtil.ClampCol(grailCell.X + Mathf.RoundToInt(Mathf.Cos(ang) * dist));
            int cz = GridUtil.ClampRow(grailCell.Y + Mathf.RoundToInt(Mathf.Sin(ang) * dist));
            cell = new Vector2I(cx, cz);
            int manhattan = Mathf.Abs(cx - grailCell.X) + Mathf.Abs(cz - grailCell.Y);
            if (manhattan >= MinEnemySpawnDistance) break;
        }

        var enemy = new Enemy();
        int hp = GD.Randf() < 0.7f ? 1 : GD.RandRange(2, 3);
        enemy.Init(_grail, cell, hp);
        AddChild(enemy);
        _enemies.Add(enemy);
    }

    public override void _Process(double delta)
    {
        if (_state != State.Playing) return;
        float dt = (float)delta;

        Vector3 focus = (_grail.Position + _player.Position) * 0.5f;
        Vector3 desired = focus + _cameraOffset;
        _camera.Position = _camera.Position.Lerp(desired, 1f - Mathf.Exp(-5f * dt));
        Vector3 lookTarget = focus + new Vector3(0f, 0f, CameraLookAhead);
        _camera.LookAt(lookTarget, Vector3.Up);

        _spawnTimer += dt;
        if (_spawnTimer >= SpawnInterval && _enemies.Count < MaxEnemies)
        {
            _spawnTimer = 0f;
            SpawnEnemy();
        }

        for (int i = _enemies.Count - 1; i >= 0; i--)
        {
            Enemy e = _enemies[i];

            // Enemy vs player: each hit deals 1 damage; surviving enemies are knocked back and stunned.
            if (e.Stun <= 0f && e.Position.DistanceTo(_player.Position) < 0.6f)
            {
                Vector3 sep = e.Position - _player.Position;
                if (e.TakeHit())
                {
                    SpawnDeathFx(e.GlobalPosition);
                    e.QueueFree();
                    _enemies.RemoveAt(i);
                    _player.Knockback(-sep);
                    continue;
                }

                e.Knockback(sep);
                _player.Knockback(-sep);
                continue; // 방금 넉백된 적은 이 프레임에 성배 피해를 주지 않는다
            }

            // 적 ↔ 성배: HP -1, 적 소멸
            if (e.Position.DistanceTo(_grail.Position) < 0.6f)
            {
                _grail.TakeDamage();
                e.QueueFree();
                _enemies.RemoveAt(i);
            }
        }
    }

    private void SpawnDeathFx(Vector3 pos)
    {
        var fx = new CpuParticles3D
        {
            Emitting = true,
            OneShot = true,
            Amount = 10,
            Lifetime = 0.4f,
            Position = pos,
            Mesh = new BoxMesh { Size = new Vector3(0.12f, 0.12f, 0.12f) },
            InitialVelocityMin = 2f,
            InitialVelocityMax = 4f,
            Gravity = new Vector3(0, -6, 0)
        };
        AddChild(fx);

        var timer = GetTree().CreateTimer(0.8);
        timer.Timeout += () =>
        {
            if (IsInstanceValid(fx))
                fx.QueueFree();
        };
    }

    private void OnWin()
    {
        if (_state != State.Playing) return;

        _state = State.Win;
        _hud.ShowResult("ARRIVED!", new Color(0.3f, 0.8f, 0.3f));
        FreezeActors();
    }

    private void OnLose()
    {
        if (_state != State.Playing) return;

        _state = State.Lose;
        _hud.ShowResult("MISSION FAILED", new Color(1f, 0.24f, 0f));
        FreezeActors();
    }

    private void FreezeActors()
    {
        _grail.SetProcess(false);
        _player.SetProcess(false);
        foreach (Enemy en in _enemies)
            en.SetProcess(false);
    }

    private void Restart()
    {
        GetTree().ReloadCurrentScene();
    }
}
