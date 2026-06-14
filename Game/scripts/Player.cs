using Godot;

namespace Nordic;

public partial class Player : Node3D
{
    public int Cx { get; private set; } = GridUtil.Cols / 2 + 1;
    public int Cz { get; private set; } = 0;

    private bool _hopping;
    private int _moveToken;

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
        else if (Input.IsActionPressed("move_left")) TryHop(1, 0);
        else if (Input.IsActionPressed("move_right")) TryHop(-1, 0);
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
        int moveToken = ++_moveToken;
        Vector3 target = GridUtil.CellToWorld(Cx, Cz, 0.5f);
        Tween tween = CreateTween();
        tween.TweenProperty(this, "position", target, 0.12f).SetTrans(Tween.TransitionType.Sine);
        tween.TweenCallback(Callable.From(() =>
        {
            if (moveToken == _moveToken)
                _hopping = false;
        }));
    }

    public void Knockback(Vector3 awayDir)
    {
        if (awayDir.LengthSquared() < 0.0001f) return;

        Vector3 pushed = Position + awayDir.Normalized() * GridUtil.TileSize;
        Vector2I cell = GridUtil.WorldToCell(pushed);
        Cx = GridUtil.ClampCol(cell.X);
        Cz = GridUtil.ClampRow(cell.Y);
        _hopping = true;
        int moveToken = ++_moveToken;

        Vector3 target = GridUtil.CellToWorld(Cx, Cz, 0.5f);
        Tween tween = CreateTween();
        tween.TweenProperty(this, "position", target, 0.15f).SetTrans(Tween.TransitionType.Sine);
        tween.TweenCallback(Callable.From(() =>
        {
            if (moveToken == _moveToken)
                _hopping = false;
        }));
    }
}
