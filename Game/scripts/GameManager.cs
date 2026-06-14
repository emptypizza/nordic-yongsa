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
