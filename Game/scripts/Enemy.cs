using Godot;

namespace Nordic;

public partial class Enemy : Node3D
{
    public float Speed = 1.6f;
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
