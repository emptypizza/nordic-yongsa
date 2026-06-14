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
    private const int MinEnemySpawnDistance = 8;
    private const float SpawnInterval = 2.5f;
    private float _spawnTimer;
    private Hud _hud;
    private Camera3D _camera;
    private readonly Vector3 _cameraOffset = new Vector3(0, 9, -7);

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
        var candidates = new List<Vector2I>();
        for (int cx = 0; cx < GridUtil.Cols; cx++)
        for (int cz = 0; cz < GridUtil.Rows; cz++)
        {
            int manhattan = Mathf.Abs(cx - grailCell.X) + Mathf.Abs(cz - grailCell.Y);
            if (manhattan >= MinEnemySpawnDistance)
                candidates.Add(new Vector2I(cx, cz));
        }

        Vector2I cell = candidates[GD.RandRange(0, candidates.Count - 1)];
        var enemy = new Enemy();
        enemy.Init(_grail, cell);
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
        _camera.LookAt(focus, Vector3.Up);

        _spawnTimer += dt;
        if (_spawnTimer >= SpawnInterval && _enemies.Count < MaxEnemies)
        {
            _spawnTimer = 0f;
            SpawnEnemy();
        }

        for (int i = _enemies.Count - 1; i >= 0; i--)
        {
            Enemy e = _enemies[i];

            // 적 ↔ 용사: 서로 반대 방향으로 넉백, 적만 기절 (처치 없음)
            if (e.Stun <= 0f && e.Position.DistanceTo(_player.Position) < 0.6f)
            {
                Vector3 sep = e.Position - _player.Position;
                e.Knockback(sep);
                _player.Knockback(-sep);
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
}
