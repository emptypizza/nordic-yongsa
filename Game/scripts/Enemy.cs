using Godot;

namespace Nordic;

public partial class Enemy : Node3D
{
    public float Speed = 1.6f;
    public int Hp;
    public float Stun { get; private set; }

    private Grail _grail;
    private MeshInstance3D _mesh;
    private Vector2I _cell;
    private Vector3 _targetPos;
    private bool _hasTarget;

    public void Init(Grail grail, Vector2I startCell, int hp)
    {
        _grail = grail;
        _cell = startCell;
        Hp = hp;
    }

    public override void _Ready()
    {
        BuildVisual();
        Position = GridUtil.CellToWorld(_cell.X, _cell.Y, 0.4f);
        PickNextTarget();
    }

    private void BuildVisual()
    {
        bool isStrong = Hp >= 2;
        float bodySize = isStrong ? 0.9f : 0.6f;
        Speed = isStrong ? 1.4f : 1.6f;

        _mesh = new MeshInstance3D { Mesh = new BoxMesh { Size = new Vector3(bodySize, bodySize, bodySize) } };
        _mesh.MaterialOverride = new StandardMaterial3D
        {
            AlbedoColor = isStrong ? new Color(0.35f, 0.12f, 0.45f) : new Color(0.5f, 0.1f, 0.1f)
        };
        AddChild(_mesh);

        float eyeOffset = isStrong ? 0.23f : 0.15f;
        float eyeY = isStrong ? 0.16f : 0.1f;
        float eyeZ = bodySize * 0.5f + 0.01f;
        Vector3 eyeSize = isStrong ? new Vector3(0.14f, 0.14f, 0.06f) : new Vector3(0.1f, 0.1f, 0.05f);

        foreach (float ex in new[] { -eyeOffset, eyeOffset })
        {
            var eye = new MeshInstance3D { Mesh = new BoxMesh { Size = eyeSize } };
            eye.MaterialOverride = new StandardMaterial3D { AlbedoColor = Colors.White };
            eye.Position = new Vector3(ex, eyeY, eyeZ);
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

    public void Knockback(Vector3 awayDir)
    {
        Vector3 pushed = Position + awayDir.Normalized() * 2.0f * GridUtil.TileSize;
        Vector2I cell = GridUtil.WorldToCell(pushed);
        _cell = new Vector2I(GridUtil.ClampCol(cell.X), GridUtil.ClampRow(cell.Y));
        Position = GridUtil.CellToWorld(_cell.X, _cell.Y, 0.4f);
        Stun = 1.0f;
        _hasTarget = false;
    }

    public bool TakeHit()
    {
        Hp--;
        return Hp <= 0;
    }
}
